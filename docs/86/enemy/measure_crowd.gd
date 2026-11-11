extends SceneTree
## Run through validate_models.py --crowd in a renderer, not --headless.
## Uses equal numbers of melee/tank, walking, with shadows disabled.

var models: Node3D
var packed: Array[PackedScene] = []

func _initialize() -> void:
	_run.call_deferred()

func _measure(label: String) -> void:
	for i in 15:
		await process_frame
	var calls := 0.0
	var objects := 0.0
	var primitives := 0.0
	for i in 15:
		await process_frame
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("CROWD %s draw_calls=%.0f objects=%.0f primitives=%.0f" % [label, calls/15, objects/15, primitives/15])

func _run() -> void:
	packed = [load("res://melee.glb"), load("res://tank.glb")]
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.23, 0.24, 0.27)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 1)
	env.ambient_light_energy = 0.9
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	light.shadow_enabled = false
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50.0
	camera.position = Vector3(0, 45, -48)
	camera.look_at(Vector3(0, 0, 0))
	camera.current = true
	models = Node3D.new()
	world.add_child(models)
	await _measure("empty")
	for i in 48:
		var enemy := packed[i % 2].instantiate() as Node3D
		enemy.position = Vector3((i % 8 - 3.5) * 6.6, 0, (i / 8 - 2.5) * 6.7)
		models.add_child(enemy)
		for mesh: MeshInstance3D in enemy.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var player := enemy.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		player.play("walk")
		player.seek(float(i % 8) / 10.0)
		if i == 23:
			await _measure("24 animated")
	await _measure("48 animated")
	world.queue_free()
	await process_frame
	quit()
