extends RefCounted
## Small persistence helpers for the debt commission VN shell.

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
	if path.is_empty():
		return false
	# DirAccess's static methods accept user:// directly. Keeping the virtual path
	# lets Godot Web route these renames through its persistent IndexedDB filesystem.
	var absolute_path: String = path
	var directory: String = absolute_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK and not DirAccess.dir_exists_absolute(directory):
		return false
	var temporary_path: String = absolute_path + ".tmp"
	var backup_path: String = absolute_path + ".bak"
	var replacement_path: String = absolute_path + ".old"
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)

	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(payload, false)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or _read_dictionary(temporary_path).is_empty():
		DirAccess.remove_absolute(temporary_path)
		return false

	var target_exists: bool = FileAccess.file_exists(absolute_path)
	if FileAccess.file_exists(replacement_path):
		DirAccess.remove_absolute(replacement_path)
	# Refresh .bak from the current primary before every overwrite. The helper
	# stages and verifies the copy before replacing .bak, so a copy failure leaves
	# both the current primary and its prior backup intact.
	if target_exists:
		if not _copy_file_atomically(absolute_path, backup_path):
			DirAccess.remove_absolute(temporary_path)
			return false
	if target_exists and DirAccess.rename_absolute(absolute_path, replacement_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return false

	if DirAccess.rename_absolute(temporary_path, absolute_path) != OK:
		if FileAccess.file_exists(replacement_path):
			DirAccess.rename_absolute(replacement_path, absolute_path)
		DirAccess.remove_absolute(temporary_path)
		return false

	# Keep the last-good copy at .bak after commit. It remains the fallback when a
	# later write is interrupted or the primary file fails validation.
	if FileAccess.file_exists(replacement_path):
		DirAccess.remove_absolute(replacement_path)
	return true


static func _read_dictionary(absolute_path: String) -> Dictionary:
	if not FileAccess.file_exists(absolute_path):
		return {}
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = file.get_var(false)
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


static func _copy_file_atomically(source_path: String, target_path: String) -> bool:
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var bytes: PackedByteArray = source.get_buffer(source.get_length())
	var read_error: Error = source.get_error()
	source.close()
	if read_error != OK:
		return false
	var temporary_backup: String = target_path + ".tmp"
	if FileAccess.file_exists(temporary_backup):
		DirAccess.remove_absolute(temporary_backup)
	var backup_file: FileAccess = FileAccess.open(temporary_backup, FileAccess.WRITE)
	if backup_file == null:
		return false
	backup_file.store_buffer(bytes)
	backup_file.flush()
	var write_error: Error = backup_file.get_error()
	backup_file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary_backup)
		return false
	var copied_file: FileAccess = FileAccess.open(temporary_backup, FileAccess.READ)
	if copied_file == null:
		DirAccess.remove_absolute(temporary_backup)
		return false
	var copied_bytes: PackedByteArray = copied_file.get_buffer(copied_file.get_length())
	var copy_error: Error = copied_file.get_error()
	copied_file.close()
	if copy_error != OK or copied_bytes != bytes:
		DirAccess.remove_absolute(temporary_backup)
		return false
	var previous_backup_path: String = target_path + ".old"
	if FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	var had_previous_backup: bool = FileAccess.file_exists(target_path)
	if had_previous_backup and DirAccess.rename_absolute(target_path, previous_backup_path) != OK:
		DirAccess.remove_absolute(temporary_backup)
		return false
	if DirAccess.rename_absolute(temporary_backup, target_path) != OK:
		if had_previous_backup and FileAccess.file_exists(previous_backup_path):
			DirAccess.rename_absolute(previous_backup_path, target_path)
		DirAccess.remove_absolute(temporary_backup)
		return false
	if had_previous_backup and FileAccess.file_exists(previous_backup_path):
		DirAccess.remove_absolute(previous_backup_path)
	return true
