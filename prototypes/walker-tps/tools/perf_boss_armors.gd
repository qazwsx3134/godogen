extends SceneTree
## Compare the same battlefield/camera using saved units, original vs reduced
## variants, and shadow on/off. Run with a renderer, e.g. xvfb-run on Linux.
## The software-renderer frame times do not represent a phone or GPU benchmark.

const MELEE_RAW := preload("res://assets/armor/melee_reference.glb")
const TANK_RAW := preload("res://assets/armor/tank_reference.glb")
const PHIDO_RAW := preload("res://assets/armor/phido.glb")


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _visible_and_processing(node: Node3D, enabled: bool) -> void:
	node.visible = enabled
	node.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED


func _set_shadow(group: Node, enabled: bool) -> void:
	for mesh: Node in group.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _measure(label: String) -> void:
	await _frames(20) # Let imports, pipeline creation and animation reach a steady state.
	var draws := 0.0
	var objects := 0.0
	var primitives := 0.0
	var process_ms := 0.0
	var physics_ms := 0.0
	for i: int in 30:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("BOSS_ARMOR_PERF %-25s draws=%.1f objects=%.1f primitives=%.0f process_ms=%.2f physics_ms=%.2f" % [
		label, draws / 30, objects / 30, primitives / 30, process_ms / 30, physics_ms / 30])


func _run() -> void:
	change_scene_to_file("res://scenes/boss_battlefield.tscn")
	await _frames(15)
	var scene: Node3D = current_scene
	var armor: Node3D = scene.get_node("Armor")
	var boss: Node3D = scene.get_node("Boss")
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 42, -86)
	camera.look_at(Vector3(0, 2, -43), Vector3.UP)
	camera.fov = 70
	camera.far = 400
	camera.current = true
	var reference := Node3D.new()
	reference.name = "ReferenceArmor"
	scene.add_child(reference)
	for unit: Node3D in armor.get_children():
		var resource: PackedScene = PHIDO_RAW if unit.name.begins_with("Phido") else \
			(MELEE_RAW if unit.name.begins_with("Melee") else TANK_RAW)
		var original := resource.instantiate() as Node3D
		reference.add_child(original)
		original.transform = unit.transform
		var player := original.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null and player.has_animation(&"idle"):
			player.play(&"idle")
			player.seek(float(unit.get("animation_phase")), true)
	_visible_and_processing(armor, false)
	_visible_and_processing(reference, false)
	_visible_and_processing(boss, false)
	await _measure("battlefield baseline")
	_visible_and_processing(boss, true)
	await _measure("boss only")
	_visible_and_processing(reference, true)
	await _measure("10 original armors")
	_visible_and_processing(reference, false)
	_visible_and_processing(armor, true)
	_set_shadow(armor, true)
	await _measure("10 optimized shadows on")
	_set_shadow(armor, false)
	await _measure("10 optimized shadows off")
	_set_shadow(armor, true)

	# Exercise the same runtime controls the user can operate in the scene.
	scene.set_armor_count(40)
	scene.set_armors_shadows(true)
	await _measure("40 optimized shadows on")
	scene.set_armors_shadows(false)
	await _measure("40 optimized shadows off")
	scene.set_armor_count(80)
	scene.set_armors_shadows(true)
	await _measure("80 optimized shadows on")
	scene.set_armors_shadows(false)
	await _measure("80 optimized shadows off")

	quit(0)
