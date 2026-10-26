extends RefCounted
## Local save: one JSON file (Profile + current Run) written with AtomicFile, a .bak of the last
## good file, and a death tombstone. On the web, user:// is IndexedDB.
##
## Death order (implementation-plan §11): write the tombstone first, then the main file. A run
## whose id is in the tombstone never loads as alive, even from an older backup.

const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const SCHEMA := 1
const SaveSchema = preload("res://domain/save_schema.gd")

var path: String
var load_source: String = ""


func _init(path_: String = "user://skybound_save.json") -> void:
	path = path_


func tombstone_path() -> String:
	return path.get_basename() + ".tombstone.json"


## state = {"profile": Dictionary, "run": Dictionary or null}
## Only a valid main file becomes the backup. One that cannot be loaded (an unknown schema, a broken run) is kept
## as .rejected instead, so a newer or hand-edited save is never lost and never pushes out the last good backup.
func save(state: Dictionary) -> Error:
	var doc := state.duplicate()
	doc.schema = SCHEMA
	if not valid(doc):
		return ERR_INVALID_DATA
	var current := _read(path)
	var raw := AtomicFile.read_bytes(path)
	if not raw.is_empty():
		var aside := path + (".bak" if valid(current) else ".rejected")
		var backup := AtomicFile.write_text(aside, raw.get_string_from_utf8())
		if backup != OK:
			return backup
	return AtomicFile.write_text(path, JSON.stringify(doc))


## The saved state, or {} when there is none. A dead run (tombstoned) comes back as run = null. The first valid file
## of main and .bak wins.
func load_state() -> Dictionary:
	load_source = ""
	var doc: Dictionary = {}
	for candidate: String in [path, path + ".old", path + ".bak", path + ".bak.old", path + ".tmp"]:
		var possible := _read(candidate)
		if valid(possible):
			doc = possible
			load_source = candidate
			break
	if doc.is_empty():
		return {}
	var tomb := _read(tombstone_path())
	var dead: Array = tomb.get("dead_runs", []) if SaveSchema.strings(tomb.get("dead_runs", [])) else []
	if doc.get("run") is Dictionary and String(doc.run.get("id", "")) in dead:
		doc.run = null
		# Recover the committed memorial and generation after a crash between journal and main.
		var recovery: Variant = tomb.get("profile")
		if SaveSchema.profile(recovery, SaveSchema.Tuning.load_default()) and int(recovery.get("generation", 0)) > int(doc.profile.get("generation", 1)):
			doc.profile = recovery.duplicate(true)
	return doc


func valid(doc: Dictionary) -> bool:
	return SaveSchema.valid(doc)


func mark_dead(run_id: String, committed_profile: Dictionary = {}) -> Error:
	var tomb := _read(tombstone_path())
	var dead: Array = tomb.get("dead_runs", []) if SaveSchema.strings(tomb.get("dead_runs", [])) else []
	if not run_id in dead:
		dead.append(run_id)
	tomb.dead_runs = dead
	if not committed_profile.is_empty():
		tomb.profile = committed_profile.duplicate(true)
	return AtomicFile.write_text(tombstone_path(), JSON.stringify(tomb))


## Deletes every file this service writes (tests and "erase save").
func erase() -> void:
	for p: String in [path, path + ".bak", path + ".bak.old", path + ".rejected", tombstone_path(), path + ".tmp", path + ".old"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _read(p: String) -> Dictionary:
	var text := AtomicFile.read_bytes(p).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	return parsed if parsed is Dictionary else {}
