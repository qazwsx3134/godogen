extends RefCounted
## Parley's stores at their default paths, so writers pick speakers from a list. Characters come
## from every work's catalog: data/asset_catalog.json and each stories/<作品>/ (Parley id = catalog
## id, which the story build maps back and checks against that work's catalog). The store is one
## list for the whole project: an id two works name differently shows both, 「主角（本作／月亮）」.
## Existing characters keep their place and the store keeps its UID (.ds speaker refs embed it).
## Used by make_parley_stores.gd and the menu Parley：更新角色清單 (addons/story_tools).

const StoryRunner = preload("res://scripts/story_runner.gd")
const CHARACTER_STORE: String = "res://characters/character_store.tres"


## {id: display name} of every work's characters, the base work first, then works by folder name.
static func characters(packs_root: String = "res://stories/") -> Dictionary:
	var sources: Array = [["本作", "res://data/asset_catalog.json"]]
	if DirAccess.dir_exists_absolute(packs_root):
		for folder: String in DirAccess.get_directories_at(packs_root):
			var pack: Variant = JSON.parse_string(FileAccess.get_file_as_string(packs_root.path_join(folder).path_join("pack.json"))) \
				if FileAccess.file_exists(packs_root.path_join(folder).path_join("pack.json")) else null
			if pack is Dictionary:
				sources.append([str((pack as Dictionary).get("title", folder)),
					StoryRunner.catalog_path_for(packs_root.path_join(folder).path_join("x_story.json"))])
	var names: Dictionary = {}  # id -> {name: [work titles]}
	for source: Array in sources:
		var read: Dictionary = StoryRunner.read_catalog(source[1])
		for id: String in (read.get("catalog", {}).get("characters", {}) as Dictionary).keys():
			var name: String = str(read["catalog"]["characters"][id].get("name", id))
			if not names.has(id):
				names[id] = {}
			if not names[id].has(name):
				names[id][name] = []
			if not (names[id][name] as Array).has(source[0]):
				names[id][name].append(source[0])
	var result: Dictionary = {}
	for id: String in names.keys():
		var variants: Dictionary = names[id]
		if variants.size() == 1:
			result[id] = variants.keys()[0]
		else:
			result[id] = "／".join(PackedStringArray(variants.keys().map(func(n: String) -> String:
				return "%s（%s）" % [n, "、".join(PackedStringArray(variants[n]))])))
	return result


## Writes the character store (and Parley's empty fact/action stores when missing): {ok, count, added}.
static func update(store_path: String = CHARACTER_STORE, packs_root: String = "res://stories/") -> Dictionary:
	var store: ParleyCharacterStore = load(store_path) if ResourceLoader.exists(store_path) else ParleyCharacterStore.new()
	if store.id.is_empty():
		store.id = "debt_commission_characters"
	var wanted: Dictionary = characters(packs_root)
	var added: Array[String] = []
	for character: ParleyCharacter in store.characters:
		if wanted.has(character.id):
			character.name = wanted[character.id]
	var known: Array = store.characters.map(func(c: ParleyCharacter) -> String: return c.id)
	for id: String in wanted.keys():
		if not known.has(id):
			store.characters.append(ParleyCharacter.new(id, wanted[id]))
			added.append(id)
	var ok: bool = save(store, store_path)
	if store_path == CHARACTER_STORE:  # Parley also wants these two; written only when missing
		for extra: Array in [["res://facts/fact_store.tres", ParleyFactStore], ["res://actions/action_store.tres", ParleyActionStore]]:
			if not ResourceLoader.exists(extra[0]):
				var fresh: ParleyStore = extra[1].new()
				fresh.id = String(extra[0]).get_file().get_basename()
				ok = save(fresh, extra[0]) and ok
	return {"ok": ok, "count": store.characters.size(), "added": added}


## Parley registers stores by UID and recurses forever on a store without one, so every store
## file gets a UID in its header. An existing UID is kept: .ds speaker refs embed it.
static func save(resource: Resource, path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	# ResourceLoader.get_resource_uid() does not read the header outside the editor.
	var header: RegExMatch = RegEx.create_from_string('uid="(uid://[a-z0-9]+)"').search(
		FileAccess.get_file_as_string(path).get_slice("\n", 0) if FileAccess.file_exists(path) else "")
	var uid: int = ResourceUID.text_to_id(header.get_string(1)) if header else ResourceUID.INVALID_ID
	if uid == ResourceUID.INVALID_ID:
		uid = ResourceUID.create_id()
	if ResourceSaver.save(resource, path) != OK:
		return false
	return ResourceSaver.set_uid(path, uid) == OK
