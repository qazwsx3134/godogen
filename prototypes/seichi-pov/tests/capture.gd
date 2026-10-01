extends SceneTree
## Windowed capture: renders main.tscn from preset viewer poses, saves PNGs to
## docs/evidence/ and prints per-shot primitives / draw calls against the budget.
##
##   godot --path prototypes/seichi-pov --script res://tests/capture.gd [-- --quality=low]

## Phone budget for one frame incl. the shadow pass (mid-range 2022+ phone, GL Compatibility).
const BUDGET_PRIMS := 250000
const BUDGET_DRAWS := 100
const SHOTS := [
	# name, offset(x,z), yaw, pitch, fov, card visible
	["00_title_card", Vector2.ZERO, 0.0, 14.0, 55.0, true],
	["01_center", Vector2.ZERO, 0.0, 14.0, 55.0, false],
	["02_telescope", Vector2.ZERO, 0.0, 20.0, 24.0, false],
	["03_corner_front_left", Vector2(-4.2, -3.1), 0.0, 10.0, 55.0, false],
	["04_corner_back_right", Vector2(4.2, 3.1), 0.0, 10.0, 55.0, false],
	["05_yaw_left_limit", Vector2(-4.2, 0), 60.0, 5.0, 65.0, false],
	["06_yaw_right_limit", Vector2(4.2, 0), -60.0, 5.0, 65.0, false],
	["07_pitch_up_limit", Vector2.ZERO, 0.0, 45.0, 65.0, false],
	["08_pitch_down_limit", Vector2(0, -3.1), 0.0, -35.0, 65.0, false],
]

var main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var viewer: Node3D = main.get_node("%Spot").get_viewer()
	var card: Control = main.get_node("%HUD").get_node("%InfoCard")
	var worst_prims := 0
	var worst_draws := 0
	for shot: Array in SHOTS:
		card.visible = shot[5]
		viewer.set_offset(shot[1])
		viewer.set_angles(shot[2], shot[3])
		viewer.set_fov(shot[4])
		for i in 12:
			await process_frame
		var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		worst_prims = maxi(worst_prims, prims)
		worst_draws = maxi(worst_draws, draws)
		var img := root.get_texture().get_image()
		var path := "res://docs/evidence/%s%s.jpg" % [shot[0], _suffix()]
		img.save_jpg(ProjectSettings.globalize_path(path), 0.85)
		print("%-22s prims=%7d draws=%4d fps=%5.1f -> %s" % [shot[0], prims, draws, Performance.get_monitor(Performance.TIME_FPS), path])
	print("worst prims=%d (budget %d) draws=%d (budget %d)" % [worst_prims, BUDGET_PRIMS, worst_draws, BUDGET_DRAWS])
	var ok := worst_prims <= BUDGET_PRIMS and worst_draws <= BUDGET_DRAWS
	print("BUDGET ", "OK" if ok else "EXCEEDED")
	quit(0 if ok else 1)


func _suffix() -> String:
	## high is the default tier, so its shots keep the bare name.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality=") and arg != "--quality=high":
			return "_" + arg.trim_prefix("--quality=")
	return ""
