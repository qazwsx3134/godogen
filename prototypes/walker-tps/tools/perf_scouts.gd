extends SceneTree
## Render cost of the scout crowd from the start camera (all 12 in view). Needs a renderer:
##   xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/perf_scouts.gd
## Draw calls / objects / primitives are exact; FPS under xvfb is software rendering and means nothing for phones.

const SCOUT := preload("res://scenes/scout.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _measure(label: String) -> void:
	for _i: int in 20:
		await process_frame
	var dc := 0.0
	var obj := 0.0
	var prim := 0.0
	for _i: int in 30:
		await process_frame
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		obj += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prim += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("PERF %-28s draw calls %5.0f  objects %4.0f  primitives %7.0f  (xvfb fps %d)" % [
		label, dc / 30, obj / 30, prim / 30, Engine.get_frames_per_second()])

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for _i: int in 40:
		await process_frame
	var enemies: Node3D = current_scene.get_node("Enemies")
	enemies.visible = false
	await _measure("no scouts")
	enemies.visible = true
	await _measure("12 scouts")
	for i: int in 36:  # 48 in total, packed in the same field of view
		var s := SCOUT.instantiate() as Node3D
		s.name = "Extra%02d" % i
		s.position = Vector3(-20.0 + (i % 9) * 3.5, 0.05, 44.0 + (i / 9) * 4.0)
		enemies.add_child(s)
	await _measure("48 scouts")
	for m: MeshInstance3D in enemies.find_children("*", "MeshInstance3D", true, false):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _measure("48 scouts, no shadows")
	quit()
