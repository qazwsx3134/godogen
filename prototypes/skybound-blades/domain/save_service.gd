extends RefCounted
## Local save: one JSON file (Profile + current Run) written with AtomicFile, a .bak of the last
## good file, and a death tombstone. On the web, user:// is IndexedDB.
##
## Death order (implementation-plan §11): write the tombstone first, then the main file. A run
## whose id is in the tombstone never loads as alive, even from an older backup.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const SCHEMA := 1

var path: String


func _init(path_: String = "user://skybound_save.json") -> void:
	path = path_


func tombstone_path() -> String:
	return path.get_basename() + ".tombstone.json"


## state = {"profile": Dictionary, "run": Dictionary or null}
func save(state: Dictionary) -> Error:
	var current := _read(path)
	if not current.is_empty():
		var backup := AtomicFile.write_text(path + ".bak", JSON.stringify(current))
		if backup != OK:
			return backup
	var doc := state.duplicate()
	doc.schema = SCHEMA
	return AtomicFile.write_text(path, JSON.stringify(doc))


## The saved state, or {} when there is none. A dead run (tombstoned) comes back as run = null.
func load_state() -> Dictionary:
	var doc := _read(path)
	if doc.is_empty():
		doc = _read(path + ".bak")
	if doc.is_empty() or int(doc.get("schema", 0)) != SCHEMA:
		return {}
	var dead: Array = _read(tombstone_path()).get("dead_runs", [])
	if doc.get("run") is Dictionary and String(doc.run.get("id", "")) in dead:
		doc.run = null
	return doc


func mark_dead(run_id: String) -> Error:
	var tomb := _read(tombstone_path())
	var dead: Array = tomb.get("dead_runs", [])
	if not run_id in dead:
		dead.append(run_id)
	return AtomicFile.write_text(tombstone_path(), JSON.stringify({"dead_runs": dead}))


## Deletes every file this service writes (tests and "erase save").
func erase() -> void:
	for p: String in [path, path + ".bak", tombstone_path(), path + ".tmp", path + ".old"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read(p: String) -> Dictionary:
	var text := AtomicFile.read_bytes(p).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return parsed if parsed is Dictionary else {}
