extends RefCounted
## Which catalog assets a story uses, node by node, and who made them (IMPLEMENTATION.md「素材授權」).
## The 投稿檢查 (tools/art_check/) lists what is still to draw from it; 製作名單 adds the makers of
## what a story uses. A reference counts only when the id is in that collection of the catalog.

const COLLECTIONS: Array[String] = ["backgrounds", "characters", "items", "sounds", "music"]
## The 製作名單 role of each collection, unless the asset's license names its own `role`.
const ROLES: Dictionary = {"backgrounds": "背景", "characters": "立繪", "items": "線索圖", "sounds": "音效", "music": "音樂"}


## {backgrounds|items|sounds|music: {id: [node ids]}, characters: {id: {nodes: [..], expressions: {expression: [..]}}},
##  investigation: {background id: true}}. `default_pov` is the character who thinks over POV choices.
static func used(story: Dictionary, catalog: Dictionary, default_pov: String) -> Dictionary:
	var found: Dictionary = {"backgrounds": {}, "characters": {}, "items": {}, "sounds": {}, "music": {}, "investigation": {}}
	var state: Dictionary = {"pov_choice": false, "povs": {default_pov: true} if not default_pov.is_empty() else {}}
	var nodes: Dictionary = story.get("nodes", {}) if story.get("nodes") is Dictionary else {}
	for node_id: String in nodes.keys():
		_walk(nodes[node_id], node_id, found, state, catalog, false, false)
	# The game turns faces itself: a round's speakers look annoyed, the POV thinks over a choice.
	if state["pov_choice"]:
		for pov: String in state["povs"].keys():
			_face(found, catalog, pov, "thinking", "（選項時）")
	var result: Dictionary = {"investigation": found["investigation"]}
	for collection: String in COLLECTIONS:
		result[collection] = {}
		for id: String in found[collection].keys():
			if collection == "characters":
				var faces: Dictionary = {}
				for face: String in found[collection][id]["expressions"].keys():
					faces[face] = _sorted(found[collection][id]["expressions"][face])
				result[collection][id] = {"nodes": _sorted(found[collection][id]["nodes"]), "expressions": faces}
			else:
				result[collection][id] = _sorted(found[collection][id])
	return result


## 製作名單 rows of the makers of what `usage` uses: [{role, names}], in collection order, no repeats.
static func credits(catalog: Dictionary, usage: Dictionary) -> Array:
	var by_role: Dictionary = {}  # role -> {name: true}, insertion-ordered
	for collection: String in COLLECTIONS:
		for id: String in (usage.get(collection, {}) as Dictionary).keys():
			var license: Variant = ((catalog.get(collection, {}) as Dictionary).get(id, {}) as Dictionary).get("license")
			if not license is Dictionary:
				continue
			var role: String = str((license as Dictionary).get("role", ROLES[collection]))
			for name: String in authors(license):
				if not by_role.has(role):
					by_role[role] = {}
				by_role[role][name] = true
	var rows: Array = []
	for role: String in by_role.keys():
		rows.append({"role": role, "names": Array((by_role[role] as Dictionary).keys())})
	return rows


## A license's `author`: one name, or a list of names.
static func authors(license: Dictionary) -> Array[String]:
	var names: Array[String] = []
	var author: Variant = license.get("author")
	for name: Variant in (author if author is Array else [author]):
		if name is String and not (name as String).strip_edges().is_empty():
			names.append((name as String).strip_edges())
	return names


static func _walk(value: Variant, node_id: String, found: Dictionary, state: Dictionary, catalog: Dictionary,
		in_round: bool, in_investigation: bool) -> void:
	if value is Array:
		for item: Variant in value:
			_walk(item, node_id, found, state, catalog, in_round, in_investigation)
		return
	if not value is Dictionary:
		return
	var step: Dictionary = value
	var op: String = str(step.get("op", ""))
	in_round = in_round or op == "boke_round"
	in_investigation = in_investigation or op == "investigate"
	match op:
		"bg":
			_note(found, catalog, "backgrounds", str(step.get("id", "")), node_id)
		"bgm":
			_note(found, catalog, "music", str(step.get("id", "")), node_id)
		"se":
			_note(found, catalog, "sounds", str(step.get("id", "")), node_id)
		"item":
			_note(found, catalog, "items", str(step.get("id", "")), node_id)
		"char", "profile":
			_face(found, catalog, str(step.get("id", "")), str(step.get("expression", "neutral")), node_id)
		"expression":
			_face(found, catalog, str(step.get("actor", "")), str(step.get("value", "neutral")), node_id)
		"choice":
			if str(step.get("perspective", "pov")) != "director":
				state["pov_choice"] = true
	for key: String in step.keys():
		var field: Variant = step[key]
		match key:
			"bg", "background":
				_note(found, catalog, "backgrounds", str(field), node_id)
				if in_investigation and field is String:
					found["investigation"][field] = true
			"speaker":
				var face: String = "annoyed" if in_round else str(step.get("expression", "neutral"))
				for speaker: String in str(field).split("+", false):
					_face(found, catalog, speaker, face, node_id)
			"actor", "character":
				_face(found, catalog, str(field), "neutral", node_id)
			"pov":
				if field is String and (catalog.get("characters", {}) as Dictionary).has(field):
					state["povs"][field] = true
			"item", "require", "has":
				_note(found, catalog, "items", str(field), node_id)
			"items":
				if field is Array:
					for item: Variant in field:
						_note(found, catalog, "items", str(item), node_id)
		if field is Dictionary or field is Array:
			_walk(field, node_id, found, state, catalog, in_round, in_investigation)


static func _note(found: Dictionary, catalog: Dictionary, collection: String, id: String, node_id: String) -> void:
	if id.is_empty() or not (catalog.get(collection, {}) as Dictionary).has(id):
		return
	if not found[collection].has(id):
		found[collection][id] = {}
	found[collection][id][node_id] = true


static func _face(found: Dictionary, catalog: Dictionary, character_id: String, face: String, node_id: String) -> void:
	if not (catalog.get("characters", {}) as Dictionary).has(character_id):
		return
	if not found["characters"].has(character_id):
		found["characters"][character_id] = {"nodes": {}, "expressions": {}}
	var entry: Dictionary = found["characters"][character_id]
	entry["nodes"][node_id] = true
	if not entry["expressions"].has(face):
		entry["expressions"][face] = {}
	entry["expressions"][face][node_id] = true


static func _sorted(ids: Dictionary) -> Array:
	var keys: Array = ids.keys()
	keys.sort()
	return keys
