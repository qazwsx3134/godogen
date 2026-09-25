extends SceneTree
## Writes Parley's stores at their default paths so writers pick speakers from a list:
##   godot --headless --path . --script res://tools/story_build/make_parley_stores.gd
## Characters come from data/asset_catalog.json (Parley id = catalog id, which the story build
## maps back). Existing store files are kept; rerun after adding catalog characters to append them.

const CATALOG_PATH: String = "res://data/asset_catalog.json"


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var path: String = "res://characters/character_store.tres"
	var store: ParleyCharacterStore = load(path) if ResourceLoader.exists(path) else ParleyCharacterStore.new()
	store.id = "debt_commission_characters"
	var known: Array = store.characters.map(func(c: ParleyCharacter) -> String: return c.id)
	var characters: Dictionary = catalog["characters"]
	for character_id: String in characters.keys():
		if not known.has(character_id):
			store.characters.append(ParleyCharacter.new(character_id, String(characters[character_id]["name"])))
	var ok: bool = _save(store, path)
	for extra: Array in [["res://facts/fact_store.tres", ParleyFactStore], ["res://actions/action_store.tres", ParleyActionStore]]:
		var existing: ParleyStore = load(extra[0]) if ResourceLoader.exists(extra[0]) else extra[1].new()
		if existing.id.is_empty():
			existing.id = String(extra[0]).get_file().get_basename()
		ok = _save(existing, extra[0]) and ok
	print("PARLEY STORES: %s (%d characters)" % ["written" if ok else "FAILED", store.characters.size()])
	quit(0 if ok else 1)


## Parley registers stores by UID and recurses forever on a store without one, so every store
## file gets a UID in its header. An existing UID is kept: .ds speaker refs embed it.
func _save(resource: Resource, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# ResourceLoader.get_resource_uid() does not read the header outside the editor.
	var header: RegExMatch = RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(
		FileAccess.get_file_as_string(path).get_slice("\n", 0) if FileAccess.file_exists(path) else "")
	var uid: int = ResourceUID.text_to_id(header.get_string(1)) if header else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	if ResourceSaver.save(resource, path) != OK:
		return false
	return ResourceSaver.set_uid(path, uid) == OK
