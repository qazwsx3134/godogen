extends RefCounted
## Crash-tolerant file commit: write `path.tmp`, flush, read it back to verify, then rename it
## over `path`. An interrupted save leaves either the old file or the new one, never a torn mix.
## `const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")`
##
## Backup policy (.bak, validation, recovery) stays with each game; this is only the commit step.
## Pass user:// paths as-is. On Web, DirAccess routes virtual paths through the persistent
## IndexedDB filesystem; ProjectSettings.globalize_path would bypass it.


static func write_bytes(path: String, bytes: PackedByteArray) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var directory: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
		if dir_error != OK:
			return dir_error
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error == OK and read_bytes(temporary_path) != bytes:
		error = ERR_FILE_CORRUPT
	if error == OK:
		error = _replace(temporary_path, path)
	if error != OK:
		_remove(temporary_path)
	return error


static func write_text(path: String, text: String) -> Error:
	return write_bytes(path, text.to_utf8_buffer())


## Same byte layout as FileAccess.store_var(value, false), so FileAccess.get_var reads it back.
static func write_var(path: String, value: Variant) -> Error:
	var body: PackedByteArray = var_to_bytes(value)
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, body.size())
	bytes.append_array(body)
	return write_bytes(path, bytes)


## Empty when the file is missing or unreadable.
static func read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


static func _replace(temporary_path: String, path: String) -> Error:
	var error: Error = DirAccess.rename_absolute(temporary_path, path)
	if error == OK or not FileAccess.file_exists(path):
		return error
	# Some platforms refuse rename-over-existing: move the old file aside, commit, and put it
	# back if the commit fails.
	var aside_path: String = path + ".old"
	_remove(aside_path)
	error = DirAccess.rename_absolute(path, aside_path)
	if error != OK:
		return error
	error = DirAccess.rename_absolute(temporary_path, path)
	if error != OK:
		DirAccess.rename_absolute(aside_path, path)
		return error
	_remove(aside_path)
	return OK


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
