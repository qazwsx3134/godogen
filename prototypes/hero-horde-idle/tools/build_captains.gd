extends SceneTree
## One-time authoring tool for 隊長 (captains): writes scenes/captain_plate.tscn (the nameplate over a captain's head)
## and puts a pool of Progression.MAX_CAPTAINS plates into main.tscn (CaptainPlates). The plate scene is skipped
## when it exists; main.tscn only while it lacks CaptainPlates. Applied 2026-10-22.
## Run with a renderer (main.tscn holds the army preview's MultiMesh data, which --headless drops):
##   godot --path prototypes/hero-horde-idle --resolution 200x200 --script res://tools/build_captains.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const Progression = preload("res://domain/progression.gd")
const PLATE := "res://scenes/captain_plate.tscn"
const SERIF := "res://ui/fonts/NotoSerifTC-Bold.otf"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_plate(), PLATE).ok
	ok = ok and _patch_main()
	quit(0 if ok else 1)


func _plate() -> Label3D:
	var label := Label3D.new()
	label.name = "CaptainPlate"
	label.set_script(load("res://scripts/captain_plate.gd"))
	label.text = "隊長‧蘿德\n▼"
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.line_spacing = -14.0
	label.font = load(SERIF)
	label.font_size = 52
	label.outline_size = 20
	label.outline_modulate = Color(0.04, 0.08, 0.06)
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.modulate = Color(1.0, 0.86, 0.52)
	return label


func _patch_main() -> bool:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if main.get_node_or_null("CaptainPlates") != null:
		print("skip (already has CaptainPlates): main.tscn")
		main.free()
		return true
	var plates := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(plates), "CaptainPlates")
	main.move_child(plates, main.get_node("Popups").get_index())
	for k: int in Progression.MAX_CAPTAINS:
		var plate: Node3D = SceneBuilder.instance(PLATE)
		plate.position = Vector3(-1.0 + k * 0.9, 1.5, 0.6 * k)
		SceneBuilder.add(plates, plate, "Plate_%d" % (k + 1))
	return SceneBuilder.save_scene(main, "res://scenes/main.tscn", {"overwrite": true,
		"expected_refs": [PLATE, "res://scenes/name_popup.tscn", "res://scenes/hud.tscn", "res://scenes/squad_flag.tscn",
			"res://scenes/tele_marker.tscn", "res://scenes/stage.tscn"]}).ok
