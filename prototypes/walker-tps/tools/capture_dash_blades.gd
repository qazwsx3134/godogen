extends SceneTree
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i: int in count: await process_frame
func run() -> void:
	change_scene_to_file("res://scenes/battlefield.tscn")
	await frames(30)
	var level := current_scene
	level.start_match()
	for scout: Node in level.get_node("Enemies").get_children(): scout.ai_enabled=false
	var walker: CharacterBody3D = level.get_node("Walker")
	var combat: Node = walker.get_node("Combat")
	var anchor := walker.global_position+Vector3(0,0,18)
	var hit: Dictionary = combat.ray(anchor+Vector3.UP*15,anchor+Vector3.DOWN*15)
	anchor=hit.position
	var marker := Label3D.new()
	marker.text="ANCHOR"
	marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size=48
	marker.pixel_size=0.02
	level.add_child(marker)
	marker.global_position=anchor+Vector3.UP*0.7
	var view := Camera3D.new()
	level.add_child(view)
	view.current=true
	view.global_position=walker.global_position+Vector3(19,10,8)
	view.look_at(anchor+Vector3(0,0,-3))
	combat.grapple.launch_hooks(anchor)
	var coast_shot := false
	var brake_shot := false
	var out := Screenshot.out_dir()
	for i: int in 180:
		await process_frame
		if combat.grapple.state_name()=="coasting" and walker.global_position.z>anchor.z and not coast_shot:
			Screenshot.save(root,out,"past_anchor")
			coast_shot=true
		if combat.grapple.state_name()=="braking" and not brake_shot:
			Screenshot.save(root,out,"braking")
			brake_shot=true
	Screenshot.save(root,out,"stopped")
	marker.queue_free()
	# Close-range automatic swipe using the real actor and saved effect scene.
	walker.get_node("CameraRig/Pitch/Arm/Camera").current=true
	view.queue_free()
	var enemy: Node3D = level.get_node("Enemies/Scout0")
	enemy.global_position=walker.global_position+walker.global_basis.z*2.9
	enemy.health=enemy.max_health
	await frames(9)
	Screenshot.save(root,out,"auto_blades")
	await frames(6)
	Screenshot.save(root,out,"blade_hit")
	quit()
