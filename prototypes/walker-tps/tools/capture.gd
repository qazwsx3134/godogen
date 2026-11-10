extends SceneTree
## Screenshots of the walker standing, mid-stride and strafing. Needs a renderer (not --headless):
##   xvfb-run -a godot --path . --resolution 1280x720 --fixed-fps 60 --script res://tools/capture.gd -- <out_dir>
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := Screenshot.out_dir()
	change_scene_to_file("res://scenes/main.tscn")
	for _i: int in 40:
		await process_frame
	Screenshot.save(root, out, "1_stand")
	Input.action_press("move_forward")
	for _i: int in 50:
		await process_frame
	Screenshot.save(root, out, "2_walk")
	for _i: int in 7:
		await process_frame
	Screenshot.save(root, out, "3_walk_midstep")
	Input.action_release("move_forward")
	var walker := current_scene.get_node("Walker")
	walker.get_node("CameraRig").look(Vector2(-1.1, 0.25))  # swing the camera to the side, look a bit down
	Input.action_press("move_right")
	for _i: int in 45:
		await process_frame
	Screenshot.save(root, out, "4_strafe")
	Input.action_release("move_right")
	walker.get_node("CameraRig").look(Vector2(1.1, -0.25))  # back behind the walker
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for _i: int in 70:
		await process_frame
	Screenshot.save(root, out, "5_sprint")
	Input.action_press("jump")
	await process_frame
	Input.action_release("jump")
	for _i: int in 38:
		await process_frame
	Screenshot.save(root, out, "6_jump_apex")
	for _i: int in 40:
		await process_frame
		if walker.is_on_floor() and not walker.get_node("Gait").airborne:
			break
	for _i: int in 3:
		await process_frame
	Screenshot.save(root, out, "7_land")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	walker.global_position = Vector3(-7, 0.05, 20)  # close to the scout crowd
	walker.rotation.y = 0.0
	walker.velocity = Vector3.ZERO
	walker.get_node("CameraRig").yaw = PI
	walker.get_node("CameraRig").pitch = deg_to_rad(-8.0)
	for _i: int in 3:
		await process_frame
	walker.get_node("Gait").replant()
	for _i: int in 90:
		await process_frame
	Screenshot.save(root, out, "8_scouts")
	quit()
