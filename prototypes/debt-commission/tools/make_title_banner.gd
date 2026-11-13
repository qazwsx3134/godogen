extends SceneTree
## Builds scenes/ui/title_banner.tscn once (script scripts/title_banner.gd). The saved scene is the source
## afterwards: adjust the band, text and rule in the editor. Does nothing when the scene exists.
##   godot --headless --path . --script res://tools/make_title_banner.gd

const PATH := "res://scenes/ui/title_banner.tscn"


func _initialize() -> void:
	if ResourceLoader.exists(PATH):
		print("exists: ", PATH)
		quit(0)
		return
	var root := Control.new()
	root.name = "TitleBanner"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load("res://scripts/title_banner.gd"))
	root.editor_description = "轉場後與調查開始時的標題橫幅：Band 是半透明深色帶、Text 是標題、Rule 是下方的細線與小圓。秒數在根節點的 open_seconds／hold_seconds／fade_seconds。"

	var band := TextureRect.new()
	band.name = "Band"
	band.unique_name_in_owner = true
	_anchor(band, 0.0, 0.395, 1.0, 0.565)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.5, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.04, 0.08, 0.0), Color(0.02, 0.04, 0.08, 0.78),
		Color(0.03, 0.06, 0.12, 0.86), Color(0.02, 0.04, 0.08, 0.78), Color(0.02, 0.04, 0.08, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 8
	band.texture = texture
	root.add_child(band)

	var text := Label.new()
	text.name = "Text"
	text.unique_name_in_owner = true
	_anchor(text, 0.0, 0.395, 1.0, 0.565)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.text = "開始尋找線索"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 88)
	text.add_theme_color_override("font_color", Color(0.97, 0.96, 0.93))
	text.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.06, 0.85))
	text.add_theme_constant_override("outline_size", 8)
	text.set_meta(&"fixed_font_size", true)  # display text: not scaled for phones
	root.add_child(text)

	var rule := Control.new()
	rule.name = "Rule"
	rule.unique_name_in_owner = true
	_anchor(rule, 0.1, 0.565, 0.9, 0.565)
	rule.offset_top = -12.0
	rule.offset_bottom = 12.0
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rule)
	for side: Array in [["LineLeft", 0.0, 0.485], ["LineRight", 0.515, 1.0]]:
		var line := ColorRect.new()
		line.name = side[0]
		_anchor(line, side[1], 0.5, side[2], 0.5)
		line.offset_top = -1.5
		line.offset_bottom = 1.5
		line.color = Color(0.9, 0.92, 0.95, 0.85)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.add_child(line)
	var ring := Panel.new()
	ring.name = "Ring"
	_anchor(ring, 0.5, 0.5, 0.5, 0.5)
	ring.offset_left = -11.0
	ring.offset_right = 11.0
	ring.offset_top = -11.0
	ring.offset_bottom = 11.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle := StyleBoxFlat.new()
	circle.bg_color = Color(0.02, 0.04, 0.08, 0.9)
	circle.border_color = Color(0.9, 0.92, 0.95, 0.9)
	circle.set_border_width_all(3)
	circle.set_corner_radius_all(11)
	ring.add_theme_stylebox_override("panel", circle)
	rule.add_child(ring)

	for node: Node in root.find_children("*", "", true, false):
		node.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var count: int = packed.instantiate().find_children("*", "", true, false).size()
	if count != 6:
		printerr("expected 6 nodes under the root, got %d" % count)
		quit(1)
		return
	ResourceSaver.save(packed, PATH)
	print("saved ", PATH)
	quit(0)


func _anchor(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom
