extends "res://addons/proto_kit/test_kit.gd"
## Parley (.ds) adapter: the Phase 4 graph builds to the same story as phase4.dialogue, and
## graph mistakes are reported with their group and step.

const StoryBuilder = preload("res://tools/story_build/story_builder.gd")
const DS_SOURCE: String = "res://story_src/phase4.ds"
const DM_SOURCE: String = "res://story_src/phase4.dialogue"


func _init() -> void:
	_test_matches_dialogue_build()
	_test_errors_name_their_location()
	_finish("STORY BUILD PARLEY TESTS")


func _test_matches_dialogue_build() -> void:
	var from_ds: Dictionary = StoryBuilder.build(DS_SOURCE)
	var from_dm: Dictionary = StoryBuilder.build(DM_SOURCE)
	_expect(String(from_ds["error"]).is_empty(), "phase4.ds builds: %s" % from_ds["error"])
	var ds_story: Dictionary = (from_ds["story"] as Dictionary).duplicate(true)
	var dm_story: Dictionary = (from_dm["story"] as Dictionary).duplicate(true)
	ds_story.erase("generated_from")
	dm_story.erase("generated_from")
	_expect(ds_story == dm_story, "the Parley graph and the .dialogue build to the same story, version included")


func _test_errors_name_their_location() -> void:
	var graph: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DS_SOURCE))
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		_node_with(g, "text", "直接問銀時")["text_translation_key"] = ""),
		"group 'ask_first', step 0: option '直接問銀時' needs a text_translation_key")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		_node_with(g, "text", "要先問誰？")["character"] = "uid://x::新八"),
		"group 'ask_first', step 0: the DIALOGUE before options is the choice prompt and must be narration")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		_node_with(g, "description", 'profile("kagura")')["description"] = 'shake("big")'),
		"group 'kagura_aside', step 1: unsupported `do shake(big)`")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		(g["nodes"] as Array).append({"id": "node:loose", "type": "DIALOGUE", "position": "(0.0, 0.0)", "character": "", "text": "x"})),
		"DIALOGUE node node:loose is not inside a group")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		var jump: Dictionary = _node_with(g, "text", "早就說不是我了阿魯。")
		jump["type"] = "JUMP"),
		"group 'perfect_kagura', step 0: JUMP nodes are not supported")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		_node_with(g, "description", 'asked == "kagura"')["description"] = "asked"),
		"group 'perfect', step 1: a CONDITION's description must be `key == value`")
	_expect_error(_edit(graph, func(g: Dictionary) -> void:
		var prompt: String = String(_node_with(g, "text", "要先問誰？")["id"])
		var elsewhere: String = String(_node_with(g, "description", 'char("shinpachi")')["id"])
		(g["edges"] as Array).append({"id": "edge:extra", "from_node": prompt, "from_slot": 0, "to_node": elsewhere, "to_slot": 0})),
		"group 'ask_first', step 0: a choice prompt may only lead to options")


func _expect_error(result: Dictionary, fragment: String) -> void:
	_expect(String(result["error"]).contains(fragment), "error mentions '%s' (got: %s)" % [fragment, result["error"]])


func _edit(graph: Dictionary, change: Callable) -> Dictionary:
	var copy: Dictionary = graph.duplicate(true)
	change.call(copy)
	return StoryBuilder.build_text(JSON.stringify(copy), DS_SOURCE)


func _node_with(graph: Dictionary, key: String, value: String) -> Dictionary:
	for node: Dictionary in graph["nodes"]:
		if String(node.get(key, "")) == value:
			return node
	_expect(false, "test graph has a node with %s = %s" % [key, value])
	return {}
