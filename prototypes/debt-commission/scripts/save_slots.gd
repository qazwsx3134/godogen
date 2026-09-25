extends RefCounted
## Small persistence helpers for the debt commission VN shell.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")

const SLOT_COUNT: int = 18
const PAGE_SIZE: int = 6
const PAGE_COUNT: int = 3


static func manual_path(base_path: String, slot_index: int) -> String:
	if slot_index < 1 or slot_index > SLOT_COUNT or base_path.is_empty():
		return ""
	var extension: String = base_path.get_extension()
	var stem: String = base_path.trim_suffix("." + extension) if not extension.is_empty() else base_path
	var result: String = "%s.manual_%02d" % [stem, slot_index]
	if not extension.is_empty():
		result += "." + extension
	return result


static func write_atomic(path: String, payload: Dictionary) -> bool:
	# An empty payload never replaces a save: the loader treats {} as unreadable.
	if path.is_empty() or payload.is_empty():
		return false
	# Refresh .bak from the current primary before every overwrite. It stays the
	# fallback when a later write is interrupted or the primary fails validation.
	if FileAccess.file_exists(path):
		var current: PackedByteArray = AtomicFile.read_bytes(path)
		if current.is_empty() or AtomicFile.write_bytes(path + ".bak", current) != OK:
			return false
	return AtomicFile.write_var(path, payload) == OK


static func _read_dictionary(absolute_path: String) -> Dictionary:
	if not FileAccess.file_exists(absolute_path):
		return {}
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = file.get_var(false)
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
