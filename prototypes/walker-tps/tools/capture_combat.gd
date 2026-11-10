extends SceneTree
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
func _initialize() -> void: _run.call_deferred()
func frames(count: int) -> void:
	for i: int in count: await process_frame
func _run() -> void:
	change_scene_to_file("res://scenes/battlefield.tscn")
	await frames(40)
	var out := Screenshot.out_dir()
	Screenshot.save(root,out,"briefing")
	var main := current_scene
	main.start_match()
	await frames(30)
	var walker: CharacterBody3D = main.get_node("Walker")
	var rig: Node3D = walker.get_node("CameraRig")
	var enemy: Node3D = main.get_node("Enemies/Scout0")
	var target := enemy.global_position+Vector3.UP*1.1
	var to := target-walker.global_position
	rig.yaw=atan2(-to.x,-to.z)
	rig.pitch=-0.07
	Input.action_press("aim")
	await frames(70)
	Screenshot.save(root,out,"aim")
	walker.get_node("Combat").launch_hooks(enemy.global_position+Vector3.UP*1.1)
	await frames(10)
	Screenshot.save(root,out,"twin_hooks")
	var side := Camera3D.new()
	main.add_child(side)
	side.global_position=(walker.global_position+enemy.global_position)*0.5+Vector3(12,7,-4)
	side.look_at((walker.global_position+enemy.global_position)*0.5+Vector3.UP*1.8)
	side.current=true
	await frames(3)
	Screenshot.save(root,out,"hooks_side")
	walker.get_node("CameraRig/Pitch/Arm/Camera").current=true
	side.queue_free()
	await frames(40)
	Screenshot.save(root,out,"reeled")
	walker.get_node("Combat").try_fire()
	await frames(1)
	Screenshot.save(root,out,"cannon")
	for scout: Node in main.get_node("Enemies").get_children(): scout.apply_damage(1000)
	await frames(5)
	Screenshot.save(root,out,"victory")
	quit()
