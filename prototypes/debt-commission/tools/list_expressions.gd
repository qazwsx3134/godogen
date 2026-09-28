extends SceneTree
## Which faces the built stories ask for, per character, and which still have no picture:
##   godot --headless --path . --script res://tools/list_expressions.gd
## Reads every data/*_story.json: `char` expressions, line tags (`say` expression) and older
## `expression` steps. The shell
## also sets two faces itself: a round's speaker looks `annoyed`, and Shinpachi is `thinking` while
## choosing a tsukkomi. A face has a picture when the catalog character has it under `expressions`
## (`neutral` also counts the character's usual `path`). The plan of what to draw is
## docs/story-telling-game/EXPRESSIONS.md.

const CATALOG_PATH: String = "res://data/asset_catalog.json"
const IMPLICIT: Array = [["gintoki", "annoyed", "回合說話者（程式）"], ["shinpachi", "thinking", "選詞時（程式）"]]


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var used: Dictionary = {}  # character -> expression -> {story: true}
	for file: String in DirAccess.get_files_at("res://data"):
		if not file.ends_with("_story.json"):
			continue
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file))
		if not story is Dictionary:
			continue
		for node: Dictionary in ((story as Dictionary).get("nodes", {}) as Dictionary).values():
			for step: Dictionary in node.get("steps", []):
				var op: String = String(step.get("op", ""))
				if op == "char" and step.has("expression"):
					_note(used, String(step["id"]), String(step["expression"]), file)
				elif op == "expression":  # older stories
					_note(used, String(step.get("actor", "")), String(step.get("value", "")), file)
				elif op == "say" and step.has("expression"):
					for speaker: String in String(step.get("speaker", "")).split("+", false):
						_note(used, speaker, String(step["expression"]), file)
	for implicit: Array in IMPLICIT:
		_note(used, implicit[0], implicit[1], implicit[2])
	var missing: int = 0
	for character_id: String in (catalog["characters"] as Dictionary).keys():
		var info: Dictionary = catalog["characters"][character_id]
		var faces: Dictionary = info.get("expressions", {}) as Dictionary
		var lines: Array[String] = []
		for expression: String in (used.get(character_id, {}) as Dictionary).keys():
			var has_picture: bool = faces.has(expression) or (expression == "neutral" and info.has("path"))
			if not has_picture:
				missing += 1
			lines.append("  %s %s  ← %s" % ["有圖" if has_picture else "沒圖", expression,
				"、".join((used[character_id][expression] as Dictionary).keys())])
		print("%s（%s）" % [info.get("name", character_id), character_id])
		for line: String in lines:
			print(line)
		if lines.is_empty():
			print("  （故事裡沒有指定表情）")
	print("EXPRESSIONS: %d face(s) used without a picture" % missing)
	quit(0)


func _note(used: Dictionary, character_id: String, expression: String, source: String) -> void:
	if not used.has(character_id):
		used[character_id] = {}
	if not (used[character_id] as Dictionary).has(expression):
		used[character_id][expression] = {}
	used[character_id][expression][source] = true
