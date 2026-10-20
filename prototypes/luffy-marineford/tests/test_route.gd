extends "res://addons/proto_kit/test_kit.gd"
## The C6 route and the fixed chase camera on the real main scene: the corridor holds the player and the crowd,
## the bridge mouth is solid beside the bridge, enemies come from ahead, every high camera preset keeps the
## player low on screen with the execution platform at the top edge, and Luffy shows all 8 directions.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.default_act = 0  # the free-run sandbox: no story holds the clock
	root.add_child(main)
	# Start-of-run warm-up: the game does not advance, the pooled samples are drawn, then they go.
	await _frames(2)
	_expect(main._warm_frames > 0 and is_zero_approx(main.elapsed), "the warm-up holds the game clock")
	_expect(main.glow.multimesh.visible_instance_count > 0, "the warm-up's pooled effects are committed while the screen is dark")
	await _until(func() -> bool: return main._warm_shown.is_empty(), "warm-up ends")
	_expect(main.fx.live() == 0, "the warm-up's samples are gone when the game starts")
	await _frames(2)
	_expect(main.elapsed > 0.0, "the game runs after the warm-up")
	var route: Route = main.route

	_expect(is_equal_approx(route.clamp_point(Vector2(40.0, -50.0), 0.4).x, route.plaza_half - 0.4), "plaza edge holds the player")
	_expect(is_equal_approx(route.clamp_point(Vector2(3.0, -190.0), 0.4).x, 3.0), "walking on the bridge is free")
	_expect(is_equal_approx(route.clamp_point(Vector2(9.0, -190.0), 0.4).x, route.bridge_half - 0.4), "the bridge's sides hold")
	var r: float = 0.55
	var stop: Vector2 = route.clamp_move(Vector2(12.0, route.bridge_from + 1.0), Vector2(12.0, route.bridge_from - 1.1), r)
	_expect(is_equal_approx(stop.y, route.bridge_from + r) and is_equal_approx(stop.x, 12.0), "walking into the crack beside the bridge stops a radius short, no sideways hop (%s)" % stop)
	var dash: Vector2 = route.clamp_move(Vector2(12.0, route.bridge_from + 0.5), Vector2(11.0, route.bridge_from - 2.6), r)
	_expect(is_equal_approx(dash.y, route.bridge_from + r), "a 3 m dash step cannot jump the crack's edge onto the bridge (%s)" % dash)
	var back: Vector2 = route.clamp_move(Vector2(-12.0, route.bridge_to - 1.0), Vector2(-12.0, route.bridge_to + 1.1), r)
	_expect(is_equal_approx(back.y, route.bridge_to - r), "the far mouth holds the same way (%s)" % back)
	var side: Vector2 = route.clamp_move(Vector2(0.0, -190.0), Vector2(6.0, -190.0), r)
	_expect(is_equal_approx(side.x, route.bridge_half - r) and is_equal_approx(side.y, -190.0), "on the bridge its sides hold")
	var enter: Vector2 = route.clamp_move(Vector2(1.0, route.bridge_from + 0.2), Vector2(1.0, route.bridge_from - 0.8), r)
	_expect(is_equal_approx(enter.y, route.bridge_from - 0.8), "lined up with the bridge you walk onto it")
	for radius: float in [0.4, 0.55, 0.65, 0.7, 0.95]:
		var front: Vector2 = route.clamp_move(Vector2(12.0, -149.0), Vector2(12.0, -152.0), radius)
		var rear: Vector2 = route.clamp_move(Vector2(12.0, -231.0), Vector2(12.0, -228.0), radius)
		_expect(is_equal_approx(front.x, 12.0) and is_equal_approx(rear.x, 12.0), "radius %.2f: both mouths stop the step without a sideways jump (%s, %s)" % [radius, front, rear])
		var again: Vector2 = route.clamp_move(front, front + Vector2(0.0, -0.5), radius)
		_expect(is_equal_approx(again.x, 12.0), "radius %.2f: pushing on from the stop point still holds (%s)" % [radius, again])
	var corner: Vector2 = route.clamp_move(Vector2(5.0, -149.4), Vector2(3.5, -151.0), r)
	_expect(is_equal_approx(corner.y, route.bridge_from + r), "a diagonal step cannot cut the mouth's corner (%s)" % corner)
	var corner_far: Vector2 = route.clamp_move(Vector2(-5.0, -230.6), Vector2(-3.5, -229.0), r)
	_expect(is_equal_approx(corner_far.y, route.bridge_to - r), "nor at the far mouth (%s)" % corner_far)
	var placed: Vector2 = route.clamp_point(Vector2(12.0, route.bridge_from - 0.3), r)
	_expect(is_equal_approx(placed.y, route.bridge_from + r) and is_equal_approx(placed.x, 12.0), "a spawn beside the bridge goes to the crack's edge")
	_expect(route.clamp_point(Vector2(0.0, -400.0), 0.4).y > route.end_z, "the platform base ends the route")
	_expect(route.height(0.0, -50.0) == 0.0 and route.height(30.0, -50.0) > 4.0 and route.height(0.0, -190.0) < -4.0, "floor, terrace and trench heights")

	main.player.position = Vector3(60.0, 0.0, -20.0)
	await _frames(2)
	_expect(absf(main.player.position.x) <= route.plaza_half, "a frame of movement puts a player outside the corridor back inside")
	main.player.position = Vector3.ZERO

	var ahead: int = 0
	var spawned: int = 40
	for i: int in spawned:
		main._spawn_one(0, main.spawn_radius)
	for i: int in main.horde.count:
		if main.horde._pos[i].y < -20.0:
			ahead += 1
	_expect(ahead >= spawned, "new enemies appear ahead (got %d of %d)" % [ahead, spawned])

	var horde: Horde = main.horde
	var far := horde.spawn(0, Vector2(0.0, -190.0))
	horde.step(0.016, Vector2.ZERO, 0.55)
	_expect(route.walkable(horde._pos[far], 0.0), "an enemy far ahead stays on the route (no radial recycle behind the player) %s" % horde._pos[far])
	var straggler := horde.spawn(0, Vector2(0.0, 40.0 - 60.0))
	horde.step(0.016, Vector2(0.0, -60.0), 0.55)
	_expect(horde._pos[straggler].y < -100.0, "a straggler 40 m behind is moved ahead of the player")
	main.player.position = Vector3(0.0, 0.0, route.end_z + 4.0)
	_expect(not main._spawn_one(0, main.spawn_radius), "no spawn past the route's end (it would pop up in view)")
	var short := horde.spawn(0, Vector2(0.0, -180.0))
	horde.step(0.016, Vector2(0.0, -210.0), 0.55)
	_expect(horde._pos[short].y > -200.0, "with less than the full distance ahead (Z -210) a straggler is not recycled into view (%s)" % horde._pos[short])
	var late := horde.spawn(0, Vector2(0.0, route.end_z + 50.0))
	horde.step(0.016, Vector2(0.0, route.end_z + 4.0), 0.55)
	_expect(horde._pos[late].y > route.end_z + 30.0, "near the end a straggler is not recycled onto the player")
	main.player.position = Vector3.ZERO
	var elite_kind: int = -1
	for k: int in horde.defs.size():
		if horde.defs[k].elite:
			elite_kind = k
	var outline: Variant = (main.player.get_node(^"%Body") as MeshInstance3D).material_override.get_shader_parameter(&"outline")
	_expect(outline is Color and (outline as Color).a > 0.9, "the player has its white identity outline (%s)" % [outline])
	_expect(elite_kind >= 0 and is_equal_approx(horde._k_role[elite_kind], 0.75) and is_equal_approx(horde._k_role[0], 1.0), "elites carry the gold outline role, the crowd none")
	_expect(is_equal_approx(float((route.get_node(^"Terrain") as MeshInstance3D).material_override.get_shader_parameter(&"px_per_m")), 1.0 / main.player.sheet.meters_per_px), "the ground uses the characters' pixel density")

	var cam: Camera3D = main.rig.camera
	var size: Vector2 = main.get_viewport().get_visible_rect().size
	var deck: Node3D = route.get_node(^"Landmarks/PlatformDeck")
	for preset: String in ["high", "higher"]:
		main.rig.use_preset(preset)
		main.rig.global_position = Vector3.ZERO
		await _frames(1)
		var feet: float = cam.unproject_position(Vector3.ZERO).y / size.y
		var deck_base: float = cam.unproject_position(deck.global_position - Vector3(0.0, 0.7, 0.0)).y / size.y
		_expect(feet > 0.62 and feet < 0.82, "%s: the player stands in the lower third (%.2f)" % [preset, feet])
		_expect(deck_base > 0.0 and deck_base < 0.2, "%s: the platform deck is at the top edge (%.2f)" % [preset, deck_base])
		_expect(main.rig.center_pitch() < main.rig.fov * 0.5, "%s: the horizon is in view" % preset)
	main.rig.use_preset("high")
	var seen := {}
	for step: int in 8:
		var a: float = TAU * step / 8.0
		main.player.face(Vector2(sin(a), cos(a)))
		var drawn: Vector2i = main.player._drawn()
		seen[drawn] = true
	_expect(seen.size() == 8, "Luffy turning a full circle under the fixed camera shows 8 distinct rows (5 drawn + 3 mirrored), got %d" % seen.size())
	main.player.pose(&"punch")
	var punch_cells := {}
	for i: int in 30:
		punch_cells[main.player._drawn().x] = true
		main.player.move(0.2 / 30.0, Vector2.ZERO, 1.0)
	_expect(punch_cells.size() == 3, "a punch plays all three frames within its hold (%d)" % punch_cells.size())
	var fist: FistStreak = main.fist
	fist.play(main.player.global_position, Vector2(0.0, -1.0), 4.0)
	var arm := fist.get_child((fist._next + fist.get_child_count() - 1) % fist.get_child_count()) as MeshInstance3D
	_expect(arm.visible and is_equal_approx(arm.global_basis.x.length(), 4.0), "a punch throws a 4 m arm afterimage")
	for i: int in 20:
		fist.step(0.02)
	_expect(not arm.visible, "the arm afterimage is gone after its life")
	main.dominance = 100.0
	main._fire_ultimate()
	await _frames(12)
	_expect(main.hud.ult_banner.visible, "firing the ultimate shows the Haki banner")
	main.rig.zoom_to(1.4)
	var aim_before: Vector2 = cam.unproject_position(main.rig.to_global(main.rig.aim_point()))
	for i: int in 60:
		main.rig.step(0.0, 0.05)
	var aim_after: Vector2 = cam.unproject_position(main.rig.to_global(main.rig.aim_point()))
	_expect(main.rig.zoom > 1.3 and aim_before.distance_to(aim_after) < 2.0, "a pull-back keeps the aim point where it was on screen")
	_finish("ROUTE")
