extends "res://addons/proto_kit/test_kit.gd"
## Editor edits survive a run, and a run never writes back into the scene files.
## 1. Hash every .tscn/.tres, play a few seconds, hash again: nothing changed.
## 2. An edited static text and spacing (as if changed in the editor) show up at runtime unchanged.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1080, 1920)
	var before: Dictionary = _hashes("res://")
	_expect(before.size() > 30, "found the scene and resource files")

	var hud_scene: PackedScene = load("res://ui/hud.tscn") as PackedScene
	var edited_hud: Control = hud_scene.instantiate() as Control
	edited_hud.get_node("%RoomLabel").text = "編輯器改過"
	(edited_hud.get_node("TopBar") as MarginContainer).add_theme_constant_override(&"margin_top", 111)
	var edited := PackedScene.new()
	edited.pack(edited_hud)
	edited_hud.free()
	var probe: Control = edited.instantiate() as Control
	root.add_child(probe)
	await _frames(3)
	_expect(probe.get_node("%RoomLabel").text == "編輯器改過", "static text edited in the scene is kept until the game sets it")
	_expect((probe.get_node("TopBar") as MarginContainer).get_theme_constant(&"margin_top") == 111, "edited spacing is kept at runtime")
	probe.queue_free()

	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	main.autoplay = true
	main.auto_pick = true
	root.add_child(main)
	main.get_node("%Hero").god_mode = true
	var top_bar: MarginContainer = main.get_node("%Hud").get_node("TopBar")
	var margin: int = top_bar.get_theme_constant(&"margin_top")
	await create_timer(4.0).timeout
	_expect(top_bar.get_theme_constant(&"margin_top") == margin, "the game never rewrites HUD spacing")
	main.queue_free()
	root.get_tree().paused = false
	await _frames(3)

	var after: Dictionary = _hashes("res://")
	for path: String in before:
		_expect(after.get(path, "") == before[path], "unchanged after a run: " + path)
	_finish("PERSISTENCE TESTS")

func _hashes(dir: String) -> Dictionary:
	var result: Dictionary = {}
	for sub: String in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub == "addons":
			continue
		result.merge(_hashes(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".tscn") or file.ends_with(".tres"):
			result[dir.path_join(file)] = FileAccess.get_md5(dir.path_join(file))
	return result
