extends SceneTree
## Builds scenes/ui/pan_arrows.tscn once (script scripts/pan_arrows.gd); the saved scene is the source
## afterwards. Does nothing when the scene exists.
##   godot --headless --path . --script res://tools/make_pan_arrows.gd

const PATH := "res://scenes/ui/pan_arrows.tscn"
## name, chevron icon, anchors (l, t, r, b), offsets (l, t, r, b) for a 132 px button.
const ARROWS: Array = [
	["Left", "left", [0.0, 0.42, 0.0, 0.42], [24.0, -66.0, 156.0, 66.0], "往左看"],
	["Right", "right", [1.0, 0.42, 1.0, 0.42], [-156.0, -66.0, -24.0, 66.0], "往右看"],
	["Up", "up", [0.5, 0.17, 0.5, 0.17], [-66.0, -66.0, 66.0, 66.0], "往上看"],
	["Down", "down", [0.5, 0.72, 0.5, 0.72], [-66.0, -66.0, 66.0, 66.0], "往下看"],
]


func _initialize() -> void:
	if ResourceLoader.exists(PATH):
		print("exists: ", PATH)
		quit(0)
		return
	var root := Control.new()
	root.name = "PanArrows"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load("res://scripts/pan_arrows.gd"))
	root.editor_description = "調查時畫面邊緣的方向鈕：只顯示還能拖的方向。拖曳各鈕調位置；外觀在各鈕的 StyleBox。"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.04, 0.08, 0.5)
	normal.border_color = Color(0.92, 0.94, 0.97, 0.75)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(66)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.1, 0.16, 0.26, 0.75)
	for spec: Array in ARROWS:
		var button := Button.new()
		button.name = spec[0]
		button.unique_name_in_owner = true
		button.icon = load("res://assets/ui/gintama_icon_chevron_%s.svg" % spec[1])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text = spec[4]
		button.focus_mode = Control.FOCUS_NONE
		var a: Array = spec[2]
		var o: Array = spec[3]
		button.anchor_left = a[0]
		button.anchor_top = a[1]
		button.anchor_right = a[2]
		button.anchor_bottom = a[3]
		button.offset_left = o[0]
		button.offset_top = o[1]
		button.offset_right = o[2]
		button.offset_bottom = o[3]
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			button.add_theme_color_override(key, Color(0.97, 0.97, 0.98))
		for state: String in ["normal", "hover", "focus"]:
			button.add_theme_stylebox_override(state, normal)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover_pressed", pressed)
		root.add_child(button)
		button.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, PATH)
	print("saved ", PATH)
	quit(0)
