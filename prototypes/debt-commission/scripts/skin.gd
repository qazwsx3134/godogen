extends RefCounted
## 外觀包 (skins/<id>/skin.json, contract in IMPLEMENTATION.md「外觀包」): the scenes, palette, HUD
## resources, life icon, title picture and music, and the words (terms, texts) of one work. A skin
## lists only what it changes; the rest comes from the base skin, skins/gintama/skin.json. Loading a
## skin also hands its look to ui_styles.gd under the skin's id.

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const BASE_ID: String = "gintama"
const ROOT: String = "res://skins/"

## Loaded skins by "<root><id>".
static var _cache: Dictionary = {}


## The skin `id` under `root` merged over the base skin; the base skin alone when the id is empty or
## has no skin.json. The result has every field of the base skin.
static func load_skin(id: String, root: String = ROOT) -> Dictionary:
	var key: String = root + id
	if _cache.has(key):
		return _cache[key]
	var base: Dictionary = _read(ROOT + BASE_ID + "/skin.json")
	var skin: Dictionary = base
	if not id.is_empty() and id != BASE_ID:
		var own: Dictionary = _read(root + id + "/skin.json")
		if not own.is_empty():
			skin = _merged(base, own)
			skin["id"] = id
	UI_STYLES.register_look(str(skin["id"]), skin)
	_cache[key] = skin
	return skin


## A scene of the skin by its key in `scenes` (dialogue_box, choice_sheet, menu, title, settings,
## game_over, result).
static func scene(skin: Dictionary, key: String) -> PackedScene:
	return load(str((skin.get("scenes", {}) as Dictionary).get(key, ""))) as PackedScene


## A word of the game (terms: rebut, life, power, super, whiff, thought, materials).
static func term(skin: Dictionary, key: String) -> String:
	return str((skin.get("terms", {}) as Dictionary).get(key, key))


## `text` with each {term} replaced by the skin's word.
static func words(skin: Dictionary, text: String) -> String:
	var result: String = text
	var terms: Dictionary = skin.get("terms", {}) as Dictionary
	for key: String in terms.keys():
		result = result.replace("{%s}" % key, str(terms[key]))
	return result


## The skin's static text for a `skin_text` key, with its terms filled in; "" when it has none.
static func text(skin: Dictionary, key: String) -> String:
	return words(skin, str((skin.get("texts", {}) as Dictionary).get(key, "")))


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## `over` laid on `base`; dictionaries merge key by key, anything else replaces.
static func _merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in over.keys():
		if result.get(key) is Dictionary and over[key] is Dictionary:
			result[key] = _merged(result[key], over[key])
		else:
			result[key] = over[key]
	return result
