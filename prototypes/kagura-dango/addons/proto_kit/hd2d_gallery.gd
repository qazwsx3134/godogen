extends SceneTree
## Look at the HD-2D kit without a game: builds hd2d_demo.gd's diorama (look presets, sun, ground, pixel_card3d
## props and figures, a ground_decal warning, pixel_vfx3d rings and chunks, the shot camera, the vignette, a
## march_strip along the bottom) and saves frames as it plays (one with a camera shot). Needs a window (the Mobile or
## Forward+ renderer for the depth of field):
##   godot --path prototypes/godot-kit --resolution 720x1280 --script res://addons/proto_kit/hd2d_gallery.gd -- <out dir>

const Hd2dDemo = preload("res://addons/proto_kit/hd2d_demo.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
const CameraShot = preload("res://addons/proto_kit/camera_shot.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = Screenshot.out_dir()
	var demo: Node = Hd2dDemo.build(Vector2(root.size))
	root.add_child(demo)
	await process_frame
	for k: int in 75:
		demo.step(1.0 / 60.0)
		await process_frame
	Screenshot.save(root, out, "hd2d_rest")
	var shot := CameraShot.new()
	shot.push_m = 3.0
	shot.yaw_deg = 8.0
	shot.ease_in = 0.3
	shot.hold = 1.0
	demo.get_node(^"World/Camera").play(shot, Vector3(1.8, 0.5, 0.8))
	for k: int in 40:
		demo.step(1.0 / 60.0)
		await process_frame
	Screenshot.save(root, out, "hd2d_shot")
	quit()
