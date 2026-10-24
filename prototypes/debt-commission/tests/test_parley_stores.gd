extends "res://addons/proto_kit/test_kit.gd"
## Parley：更新角色清單: every work's characters in one list; an id two works name differently
## shows both names; existing characters keep their place and the store keeps its UID.

const ParleyStores = preload("res://tools/story_build/parley_stores.gd")
const STORE: String = "res://tests/fixtures/_parley_test_store.tres"  # res:// like the real store (UID header)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var names: Dictionary = ParleyStores.characters("res://tests/fixtures/art_check/")
	_expect(names.has("shinpachi") and names["hero"] == "主角" and names["ghost"] == "幽靈" and names["plain"] == "路人",
		"the base work's and every work's characters: %s" % [names])
	var first: Dictionary = ParleyStores.update(STORE, "res://tests/fixtures/art_check/")
	var header: String = FileAccess.get_file_as_string(STORE).get_slice("\n", 0)
	var store: ParleyCharacterStore = load(STORE)
	var ids: Array = store.characters.map(func(c: ParleyCharacter) -> String: return c.id)
	_expect(first["ok"] and ids.has("hero") and ids.has("shinpachi") and header.contains("uid://"), "the store is written with a UID: %s" % [ids])
	var again: Dictionary = ParleyStores.update(STORE, "res://tests/fixtures/art_check/")
	_expect(again["ok"] and (again["added"] as Array).is_empty() and FileAccess.get_file_as_string(STORE).get_slice("\n", 0) == header,
		"updating again adds nothing and keeps the UID")
	_expect(ParleyStores.characters("res://tests/fixtures/packs/").get("eren") == "艾連", "another works folder")
	for path: String in [STORE, STORE + ".uid"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_finish("PARLEY STORES TESTS")
