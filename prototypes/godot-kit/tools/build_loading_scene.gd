extends SceneTree
## 製作工具：產生 addons/proto_kit/loading/loading_system.tscn。存好後直接在編輯器改，不要重跑覆蓋。
##   godot --headless --path prototypes/godot-kit -s tools/build_loading_scene.gd

func _init() -> void:
	var root := CanvasLayer.new(); root.name = "LoadingSystem"; root.layer = 100
	root.set_script(load("res://addons/proto_kit/loading/loading_system.gd"))
	var ui := Control.new(); ui.name = "Root"; ui.unique_name_in_owner = true
	ui.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(ui)
	var bg := ColorRect.new(); bg.name = "Bg"; bg.color = Color(0.07, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(bg)
	var box := VBoxContainer.new(); box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER); box.custom_minimum_size = Vector2(420, 0)
	box.offset_left = -210; box.offset_right = 210; box.offset_top = -40; box.offset_bottom = 40
	box.add_theme_constant_override("separation", 10); ui.add_child(box)
	var title := Label.new(); title.name = "Title"; title.text = "Loading..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(title)
	var bar := ProgressBar.new(); bar.name = "Bar"; bar.unique_name_in_owner = true
	bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 18); box.add_child(bar)
	var pct := Label.new(); pct.name = "Percent"; pct.unique_name_in_owner = true; pct.text = "0%"
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(pct)
	var err := Label.new(); err.name = "Error"; err.unique_name_in_owner = true
	err.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; err.modulate = Color(1, 0.45, 0.4); box.add_child(err)
	for n in _all(root):
		if n != root: n.owner = root
	var ps := PackedScene.new(); ps.pack(root)
	var path := "res://addons/proto_kit/loading/loading_system.tscn"
	print("save ", ResourceSaver.save(ps, path), " nodes ", _all(root).size(), "->", _all(load(path).instantiate()).size())
	root.free()
	quit()


func _all(n: Node) -> Array:
	var a := [n]
	for c in n.get_children(): a.append_array(_all(c))
	return a
