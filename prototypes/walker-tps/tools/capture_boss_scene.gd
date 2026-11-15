extends SceneTree
## Capture the actual Boss battlefield with the regular walker camera.
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")

func _initialize() -> void:
	_run.call_deferred()

func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/boss_battlefield.tscn")
	await _frames(40)
	var out: String = Screenshot.out_dir()
	var session: Node = current_scene.get_node("Battlefield")
	session.start_match()
	await _frames(30)
	Screenshot.save(root, out, "boss_spawn")
	var walker: CharacterBody3D = session.get_node("Walker")
	var camera_rig: Node3D = walker.get_node("CameraRig")
	camera_rig.pitch = 0.13
	await _frames(30)
	Screenshot.save(root, out, "boss_look_up")
	quit(0)
