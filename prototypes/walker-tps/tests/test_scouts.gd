extends "res://addons/proto_kit/test_kit.gd"
## godot --headless --fixed-fps 60 --path . --script res://tests/test_scouts.gd

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var scouts: Array[Node] = main.get_node("Enemies").get_children()
	_expect(scouts.size() == 12, "12 scouts in main.tscn (%d)" % scouts.size())
	var start := {}
	for s: Node3D in scouts:
		start[s] = s.global_position
	var walked_with_matching_speed := 0
	for f: int in 600:  # 10 s
		await _frames(1)
		if f % 30 == 0:
			for s in scouts:
				var anim: AnimationPlayer = s._anim
				var v := Vector2(s.velocity.x, s.velocity.z).length()
				if anim.current_animation == "walk" and v > 1.0 \
						and absf(anim.speed_scale - v / s.WALK_ANIM_SPEED) < 0.05:
					walked_with_matching_speed += 1
	var moved := 0
	for s: CharacterBody3D in scouts:
		var p := s.global_position
		if Vector2(p.x - start[s].x, p.z - start[s].z).length() > 1.0:
			moved += 1
		_expect(p.y > -0.5 and p.y < 4.0, "%s stays on the ground (y=%.2f)" % [s.name, p.y])
		_expect(Vector2(p.x - s._home.x, p.z - s._home.z).length() < s.wander_radius + 2.5,
				"%s stays near home" % s.name)
		_expect((s.find_child("Scout") as MeshInstance3D).mesh.get_surface_count() == 1, "one surface = one draw call")
	_expect(moved >= 8, "most scouts wander off their spawn point (%d / 12)" % moved)
	_expect(walked_with_matching_speed > 20, "walk cycle plays at speed / %.1f (%d samples)" % [1.6, walked_with_matching_speed])
	_finish("SCOUTS")
