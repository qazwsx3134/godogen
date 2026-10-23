extends RefCounted
## 存檔備份: every file the game keeps for a player (each story's continue save, its 18 manual
## slots and quick slot, plus progress, settings, the UI preference and the story choice) packed
## into one JSON text the player can keep or move to another device, and checked before it
## replaces anything. Importing replaces the whole set: files the backup lacks are removed, and
## every file it replaces or removes is first copied to <file>.before_import.

const SaveSlots = preload("res://scripts/save_slots.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")

const FORMAT: String = "debt-commission-saves"
const FORMAT_VERSION: int = 1
const BEFORE_IMPORT_SUFFIX: String = ".before_import"
## A backup larger than this is not ours (a few chapters' saves are far below it).
const MAX_TEXT_LENGTH: int = 16 * 1024 * 1024


## Every user:// file a backup may hold: the saves of `stories` ({save} entries of
## data/stories.json) and the `shared` files.
static func backup_paths(stories: Array, shared: Array) -> Array[String]:
	var paths: Array[String] = []
	for story: Variant in stories:
		var base: String = str((story as Dictionary).get("save", "")) if story is Dictionary else ""
		if not base.begins_with("user://"):
			continue
		paths.append(base)
		paths.append(SaveSlots.quick_path(base))
		for slot: int in range(1, SaveSlots.SLOT_COUNT + 1):
			paths.append(SaveSlots.manual_path(base, slot))
	for path: Variant in shared:
		if str(path).begins_with("user://") and not paths.has(str(path)):
			paths.append(str(path))
	return paths


## The backup of whichever of `paths` exist.
static func export_text(paths: Array[String], exported_at: String) -> String:
	var files: Dictionary = {}
	for path: String in paths:
		if FileAccess.file_exists(path):
			files[path.trim_prefix("user://")] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	return JSON.stringify({"format": FORMAT, "version": FORMAT_VERSION, "exported_at": exported_at, "files": files}, "  ")


## {files: {user:// path: bytes}, error: ""}, or {files: {}, error: what is wrong, for the player}.
static func parse_import(text: String, allowed: Array[String]) -> Dictionary:
	if text.length() > MAX_TEXT_LENGTH:
		return _fail("檔案太大，不是這個遊戲的存檔備份。")
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary or (parsed as Dictionary).get("format") != FORMAT:
		return _fail("這不是這個遊戲的存檔備份檔。")
	var backup: Dictionary = parsed as Dictionary
	if int(backup.get("version", 0)) > FORMAT_VERSION:
		return _fail("這份備份來自較新版本的遊戲，請先更新遊戲。")
	if int(backup.get("version", 0)) != FORMAT_VERSION or not backup.get("files") is Dictionary:
		return _fail("這份存檔備份的格式不對。")
	var files: Dictionary = {}
	for name: Variant in backup["files"]:
		var path: String = "user://" + str(name)
		if not allowed.has(path):
			return _fail("備份裡有不認得的檔案：%s" % name)
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(backup["files"][name]))
		if not _readable(path, bytes):
			return _fail("備份裡的 %s 已損毀，沒有匯入任何檔案。" % name)
		files[path] = bytes
	if files.is_empty():
		return _fail("這份備份裡沒有存檔。")
	return {"files": files, "error": ""}


## Replaces the allowed set with `files`; "" on success. Nothing is written until every file
## being replaced or removed has its .before_import copy.
static func apply_import(files: Dictionary, allowed: Array[String]) -> String:
	var touched: Array[String] = []
	for path: String in allowed:
		for existing: String in [path, path + ".bak"]:
			if FileAccess.file_exists(existing):
				touched.append(existing)
	for path: String in touched:
		if AtomicFile.write_bytes(path + BEFORE_IMPORT_SUFFIX, FileAccess.get_file_as_bytes(path)) != OK:
			return "無法先備份目前的存檔，沒有匯入。"
	for path: String in touched:
		if not files.has(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for path: String in files:
		if AtomicFile.write_bytes(path, files[path]) != OK:
			return "寫入存檔失敗；匯入前的檔案留在 *%s。" % BEFORE_IMPORT_SUFFIX
	return ""


## A save holds a Dictionary written with store_var: a 4-byte little-endian length that must match
## the rest of the file (FileAccess.get_var trusts it), then the value, decoded without objects. A
## .cfg is ConfigFile text.
static func _readable(path: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	if path.ends_with(".cfg"):
		return ConfigFile.new().parse(bytes.get_string_from_utf8()) == OK
	return bytes.size() > 4 and bytes.decode_u32(0) == bytes.size() - 4 and bytes_to_var(bytes.slice(4)) is Dictionary


static func _fail(message: String) -> Dictionary:
	return {"files": {}, "error": message}
