extends SceneTree
## One-time authoring tool for the 三團 field: writes the item scenes scenes/squad_flag.tscn (a squad's flag and its
## ground ring), scenes/tele_marker.tscn (a telegraph shape on the ground) and scenes/part_button.tscn (a boss part
## to aim at, with its HP bar; a dark round button like the HUD's), the shared materials/ground_mark.tres, and patches:
##   main.tscn  Flags (3 flags at the squads' muster points), TeleMarkers (a pool of 3), and the boss part anchors
##              PartLegs / PartArm / PartHorns (Marker3D on the boss, adjust them in the editor)
##   hud.tscn   Parts (3 part buttons over the field)
## Item scenes that exist are skipped; main.tscn and hud.tscn only while they lack Flags / Parts.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_squads.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PushSim = preload("res://domain/push_sim.gd")
const MAIN := "res://scenes/main.tscn"
const HUD := "res://scenes/hud.tscn"
const FLAG := "res://scenes/squad_flag.tscn"
const MARKER := "res://scenes/tele_marker.tscn"
const PART := "res://scenes/part_button.tscn"
const FONT := "res://ui/fonts/NotoSansTC.ttf"
const MARKERS := 3
const SQUAD_COLORS := [Color(0.95, 0.35, 0.25), Color(0.3, 0.8, 0.95), Color(1.0, 0.82, 0.3)]
const TELE_RED := Color(1.0, 0.18, 0.12)
## Anchors on the boss (relative to Boss), read off the idle frame.
const PART_ANCHORS := [Vector3(0.0, 0.7, 0.3), Vector3(-1.7, 3.4, 0.3), Vector3(-0.4, 4.7, 0.3)]
const PART_NODES := ["PartLegs", "PartArm", "PartHorns"]


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var mark_mat: ShaderMaterial = _keep(_mark_material(), "res://materials/ground_mark.tres")
	var ok: bool = SceneBuilder.save_scene(_flag(mark_mat), FLAG).ok
	ok = ok and SceneBuilder.save_scene(_marker(mark_mat), MARKER).ok
	ok = ok and SceneBuilder.save_scene(_part_button(), PART).ok
	ok = ok and _patch_main()
	ok = ok and _patch_hud()
	quit(0 if ok else 1)


func _mark_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ground_mark.gdshader")
	return m


func _flag(mark_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "SquadFlag"
	root.set_script(load("res://scripts/squad_flag.gd"))
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	ring.mesh = plane
	ring.material_override = mark_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0.0, 0.035, 0.0)
	ring.scale = Vector3(2.4, 1.0, 5.0)
	ring.set_instance_shader_parameter(&"shape", 0.0)
	ring.set_instance_shader_parameter(&"inner_alpha", 0.06)
	ring.set_instance_shader_parameter(&"texels", Vector2(48.0, 100.0))
	SceneBuilder.add(root, SceneBuilder.unique(ring), "Ring")

	var wood := StandardMaterial3D.new()
	wood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wood.albedo_color = Color(0.3, 0.2, 0.12)
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 2.4, 0.07)
	box.material = wood
	pole.mesh = box
	pole.position = Vector3(0.0, 1.2, 0.0)
	SceneBuilder.add(root, pole, "Pole")

	var cloth_mat := StandardMaterial3D.new()
	cloth_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth_mat.albedo_color = Color.WHITE
	var cloth := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.6)
	cloth.mesh = quad
	cloth.material_override = cloth_mat
	cloth.position = Vector3(0.47, 2.08, 0.0)
	SceneBuilder.add(root, SceneBuilder.unique(cloth), "Cloth")

	var label := Label3D.new()
	label.text = "近戰團 52"
	label.font = load(FONT)
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.position = Vector3(0.0, 2.62, 0.0)
	SceneBuilder.add(root, SceneBuilder.unique(label), "FlagLabel")
	return root


func _marker(mark_mat: Material) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = "TeleMarker"
	marker.set_script(load("res://scripts/tele_marker.gd"))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	marker.mesh = plane
	marker.material_override = mark_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The editor preview: a 重砸 circle half way through its countdown.
	marker.position = Vector3(0.0, 0.03, 0.0)
	marker.scale = Vector3(4.0, 1.0, 4.0)
	marker.set_instance_shader_parameter(&"color", TELE_RED)
	marker.set_instance_shader_parameter(&"fill", 0.5)
	marker.set_instance_shader_parameter(&"inner_alpha", 0.15)
	marker.set_instance_shader_parameter(&"texels", Vector2(80.0, 80.0))
	return marker


## A dark round HUD button with the part's name and an HP bar under it.
func _part_button() -> Button:
	var button := Button.new()
	button.name = "PartButton"
	button.set_script(load("res://scripts/part_button.gd"))
	for state: StringName in [&"normal", &"pressed", &"hover", &"focus", &"disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.16, 0.2, 0.36, 0.85)
		box.set_corner_radius_all(28)
		box.set_border_width_all(4)
		box.border_color = Color.WHITE
		button.add_theme_stylebox_override(state, box)
	button.custom_minimum_size = Vector2(108, 56)
	button.size = Vector2(108, 56)
	button.add_theme_font_size_override(&"font_size", 24)
	button.text = "角"
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.value = 70.0
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 10.0
	bar.offset_right = -10.0
	bar.offset_top = -12.0
	bar.offset_bottom = -6.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.55, 0.3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	bar.add_theme_stylebox_override(&"fill", fill)
	bar.add_theme_stylebox_override(&"background", back)
	SceneBuilder.add(button, SceneBuilder.unique(bar), "Bar")
	return button


func _patch_main() -> bool:
	var main: Node = (load(MAIN) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if main.get_node_or_null("Flags") != null:
		print("skip (already has Flags): ", MAIN)
		main.free()
		return true
	var at: int = main.get_node("Army").get_index()
	var flags := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(flags), "Flags")
	main.move_child(flags, at)
	for s: int in PushSim.SQUADS:
		var flag: Node3D = SceneBuilder.instance(FLAG)
		flag.position = Vector3(PushSim.HOME[s].x, 0.0, PushSim.HOME[s].y)
		flag.set(&"squad_index", s)
		flag.set(&"color", SQUAD_COLORS[s])
		SceneBuilder.add(flags, flag, "Flag_" + PushSim.SQUAD_NAMES[s])
	var markers := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(markers), "TeleMarkers")
	main.move_child(markers, at)
	for k: int in MARKERS:
		var marker: Node3D = SceneBuilder.instance(MARKER)
		marker.visible = false
		SceneBuilder.add(markers, marker, "Marker_%d" % (k + 1))
	var boss: Node = main.get_node("Boss")
	for p: int in PART_NODES.size():
		var anchor := Marker3D.new()
		anchor.position = PART_ANCHORS[p]
		SceneBuilder.add(boss, SceneBuilder.unique(anchor), PART_NODES[p])
	return SceneBuilder.save_scene(main, MAIN, {"overwrite": true,
		"expected_refs": [HUD, FLAG, MARKER, "res://scenes/stage.tscn"]}).ok


func _patch_hud() -> bool:
	var hud: Node = (load(HUD) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var root: Node = hud.get_node("Root")
	if root.get_node_or_null("Parts") != null:
		print("skip (already has Parts): ", HUD)
		hud.free()
		return true
	var at: int = root.get_node("Bottom").get_index()
	var parts := Control.new()
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(parts), "Parts")
	root.move_child(parts, at)
	for p: int in PART_NODES.size():
		var button: Control = SceneBuilder.instance(PART)
		button.set(&"part_index", p)
		button.position = Vector2(520, 380 + p * 110)
		SceneBuilder.add(parts, button, PART_NODES[p])
	return SceneBuilder.save_scene(hud, HUD, {"overwrite": true, "expected_refs": [PART, "res://scenes/push_report.tscn"]}).ok


func _keep(resource: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	ResourceSaver.save(resource, path)
	print("saved: ", path)
	return load(path)
