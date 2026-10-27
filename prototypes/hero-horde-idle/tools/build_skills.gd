extends SceneTree
## One-time authoring tool for the 招牌技 display: writes scenes/skill_callout.tscn (the card that slides in when an
## SSR casts its move: portrait, move, hero, effect) and scenes/name_popup.tscn (a name rising over a hero's head),
## then puts the callout into hud.tscn (Root/SkillCallout, under the banner) and a pool of popups into main.tscn
## (Popups). Item scenes that exist are skipped; hud.tscn / main.tscn only while they lack those nodes.
## Run with a renderer (main.tscn holds the army preview's MultiMesh data, which --headless drops):
##   godot --path prototypes/hero-horde-idle --resolution 200x200 --script res://tools/build_skills.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const CALLOUT := "res://scenes/skill_callout.tscn"
const POPUP := "res://scenes/name_popup.tscn"
const FONT := "res://ui/fonts/NotoSansTC.ttf"
const POPUPS := 8
const GOLD := Color(1.0, 0.85, 0.35)


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_callout(), CALLOUT).ok
	ok = ok and SceneBuilder.save_scene(_popup(), POPUP).ok
	ok = ok and _patch_hud()
	ok = ok and _patch_main()
	quit(0 if ok else 1)


func _callout() -> Control:
	var root := Control.new()
	root.name = "SkillCallout"
	root.set_script(load("res://scripts/skill_callout.gd"))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2(0, 330)
	root.size = Vector2(560, 150)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.1, 0.2, 0.9)
	box.border_color = GOLD
	box.set_border_width_all(0)
	box.border_width_top = 4
	box.border_width_bottom = 4
	box.border_width_right = 6
	box.corner_radius_top_right = 24
	box.corner_radius_bottom_right = 24
	box.content_margin_left = 20.0
	box.content_margin_right = 24.0
	box.content_margin_top = 12.0
	box.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override(&"panel", box)
	SceneBuilder.add(root, panel, "Panel")
	var row := SceneBuilder.add(panel, HBoxContainer.new(), "Row") as HBoxContainer
	row.add_theme_constant_override(&"separation", 16)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/heroes/heroes.png")
	atlas.region = Rect2(8 * 48, 4 * 48, 48, 48)
	portrait.texture = atlas
	SceneBuilder.add(row, SceneBuilder.unique(portrait), "Portrait")
	var text := SceneBuilder.add(row, VBoxContainer.new(), "Text") as VBoxContainer
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(text, SceneBuilder.unique(_label("「隕石術」", 40, GOLD)), "SkillName")
	SceneBuilder.add(text, SceneBuilder.unique(_label("SSR 法・溫嘉", 24, Color.WHITE)), "HeroLine")
	SceneBuilder.add(text, SceneBuilder.unique(_label("隕石砸向瞄準的部位", 22, Color(0.78, 0.8, 0.9))), "Desc")
	return root


func _popup() -> Label3D:
	var label := Label3D.new()
	label.name = "NamePopup"
	label.set_script(load("res://scripts/name_popup.gd"))
	label.text = "卡琳娜"
	label.font = load(FONT)
	label.font_size = 40
	label.outline_size = 10
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 3
	label.outline_render_priority = 2
	label.modulate = GOLD
	return label


func _patch_hud() -> bool:
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var root: Node = hud.get_node("Root")
	if root.get_node_or_null("SkillCallout") != null:
		print("skip (already has SkillCallout): hud.tscn")
		hud.free()
		return true
	var callout: Control = SceneBuilder.instance(CALLOUT)
	SceneBuilder.add(root, SceneBuilder.unique(callout), "SkillCallout")
	# An instance keeps only the offsets set on it: under the banner, at the left edge.
	callout.position = Vector2(0, 330)
	callout.size = Vector2(560, 150)
	root.move_child(callout, root.get_node("Bottom").get_index())
	return SceneBuilder.save_scene(hud, "res://scenes/hud.tscn", {"overwrite": true,
		"expected_refs": [CALLOUT, "res://scenes/part_button.tscn", "res://scenes/push_report.tscn"]}).ok


func _patch_main() -> bool:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if main.get_node_or_null("Popups") != null:
		print("skip (already has Popups): main.tscn")
		main.free()
		return true
	var popups := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(popups), "Popups")
	main.move_child(popups, main.get_node("Bolts").get_index() + 1)
	for k: int in POPUPS:
		var popup: Node3D = SceneBuilder.instance(POPUP)
		popup.visible = false
		SceneBuilder.add(popups, popup, "Popup_%d" % (k + 1))
	return SceneBuilder.save_scene(main, "res://scenes/main.tscn", {"overwrite": true,
		"expected_refs": [POPUP, "res://scenes/hud.tscn", "res://scenes/squad_flag.tscn", "res://scenes/tele_marker.tscn",
			"res://scenes/stage.tscn"]}).ok


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 8)
	label.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.06))
	return label
