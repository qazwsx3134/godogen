extends SceneTree
## One-time authoring step for the PokeSurvivor-style view (docs/pokesurvivor-reference.md): adds the off-screen
## markers to street.tscn, the surge banner to hud.tscn and the reroll button to upgrades.tscn.
## Run: godot --headless --path . --script res://tools/add_poke_view.gd
## Applied 2026-10-13. Skips itself once street.tscn has Markers; after that edit the scenes directly.
const B = preload("res://addons/proto_kit/scene_builder.gd")
var failed: bool = false

func _initialize() -> void:
	build.call_deferred()

func save(node: Node, path: String, refs: Array = []) -> void:
	var result: Dictionary = B.save_scene(node, path, {"overwrite": true, "expected_refs": refs})
	failed = failed or not result.ok

func build() -> void:
	var street := B.instance("res://scenes/street.tscn")
	if street.has_node("Markers"):
		street.free()
		print("skip: already authored; edit the scenes directly")
		quit()
		return
	var markers := Node2D.new()
	markers.z_index = 9
	markers.set_script(load("res://scripts/edge_markers.gd"))
	B.add(street, markers, "Markers")
	markers.unique_name_in_owner = true
	save(street, "res://scenes/street.tscn", ["res://scripts/edge_markers.gd"])

	var hud := B.instance("res://scenes/hud.tscn")
	var banner := Label.new()
	banner.text = "下班人潮來了！"
	banner.visible = false
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_font_size_override("font_size", 30)
	banner.add_theme_color_override("font_color", Color("ffd36b"))
	banner.add_theme_color_override("font_outline_color", Color("1b1420"))
	banner.add_theme_constant_override("outline_size", 10)
	B.add(hud, banner, "Banner")
	banner.unique_name_in_owner = true
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 250.0
	banner.offset_bottom = 300.0
	save(hud, "res://scenes/hud.tscn")

	var panel := B.instance("res://scenes/upgrades.tscn")
	var column := panel.get_node("Center/Column")
	var reroll := Button.new()
	reroll.text = "重抽（剩 1 次）"
	reroll.custom_minimum_size = Vector2(220, 48)
	reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	B.add(column, reroll, "Reroll")
	reroll.unique_name_in_owner = true
	column.move_child(reroll, panel.get_node("%Options").get_index() + 1)
	save(panel, "res://scenes/upgrades.tscn")
	quit(1 if failed else 0)
