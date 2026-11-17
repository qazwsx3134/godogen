extends SceneTree
## Visual check of the playable Boss, attack effects and speed blur.
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")

func _initialize() -> void: _run.call_deferred()

func _frames(count: int) -> void:
	for i in count: await process_frame

func _run() -> void:
	change_scene_to_file("res://scenes/boss_battlefield.tscn")
	await _frames(40)
	var scene := current_scene
	var session: Node = scene.get_node("Battlefield")
	var boss: CharacterBody3D = scene.get_node("Boss")
	session.start_match()
	for enemy: Node in session.get_node("Enemies").get_children(): enemy.ai_enabled = false
	boss._attack_timer = 1000.0
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = boss.global_position + Vector3(30, 15, -25)
	camera.look_at(boss.global_position + Vector3.UP * 4.0, Vector3.UP)
	camera.current = true
	await _frames(40)
	var out := Screenshot.out_dir()
	Screenshot.save(root, out, "boss_ground")
	boss.try_attack("beam")
	await _frames(80)
	Screenshot.save(root, out, "boss_beam")
	var impact := (load("res://scenes/combat_impact.tscn") as PackedScene).instantiate() as Node3D
	impact.radius = 3.0
	session.get_node("Projectiles").add_child(impact)
	impact.global_position = boss.global_position + Vector3(8, 2, -8)
	await _frames(7)
	Screenshot.save(root, out, "explosion")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(110)
	Screenshot.save(root, out, "speed_blur")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	quit(0)
