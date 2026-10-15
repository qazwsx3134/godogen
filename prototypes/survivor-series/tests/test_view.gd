extends "res://addons/proto_kit/test_kit.gd"
## PokeSurvivor-style view and the mechanics borrowed with it (docs/pokesurvivor-reference.md):
## camera distance, depth sorting, projectile height, roadblock and breakable props, enemies moved ahead,
## surges, quieter spawning around elites, reroll, off-screen markers.
const META_PATH = "user://test_view_meta.json"
const DT := 1.0 / 60.0
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	await _frames(2)
	var street = game.street
	var map = street.map
	game.start_run()
	await _frames(1)
	street.spawn_left = 1000.0
	street.surge_left = 1000.0
	var hero = street.player

	# --- view ---
	_expect(street.camera.zoom.x <= 0.8, "the camera is pulled back so more of the street is visible")
	var world: Node2D = street.get_node("World")
	var props: Node2D = map.get_node("%Props")
	_expect(world.y_sort_enabled and props.y_sort_enabled and street.enemies.y_sort_enabled, "world, props and enemies depth-sort together")
	_expect(props.get_child_count() > 0 and props.get_child(0).y_sort_enabled, "map chunks depth-sort their props")
	_expect(hero.get_parent() == world and street.enemies.get_parent() == world and props.get_parent() == world and hero.z_index == 0 and street.enemies.z_index == 0 and props.z_index == 0, "hero, enemies and props share one layer so y decides who is in front")
	_expect(map.z_index + map.get_node("%Ground").z_index < 0 and street.pickups.z_index <= 0 and street.pickups.get_index() < world.get_index(), "ground and pickups stay under the walkers")

	# --- projectile height and orbit ---
	var wave: Node2D = (load("res://scenes/wave.tscn") as PackedScene).instantiate()
	street.projectiles.add_child(wave)
	var rest: Vector2 = wave.visual.position
	wave.velocity = Vector2.DOWN * 100.0
	wave.launch(hero.position)
	var lifted: Vector2 = wave.visual.global_position - wave.global_position - rest.rotated(wave.rotation)
	_expect(lifted.distance_to(Vector2(0.0, -wave.lift)) < 0.5 and wave.lift > 0.0, "a flying projectile is drawn above its ground point, straight up on screen, whatever its heading")
	wave.queue_free()
	var tofu: Node2D = (load("res://scenes/tofu.tscn") as PackedScene).instantiate()
	street.projectiles.add_child(tofu)
	tofu.launch(hero.position)
	_expect(tofu.lift == 0.0 and tofu.visual.position == tofu._rest, "ground zones lie on the ground")
	tofu.queue_free()
	var orb: Node2D = (load("res://scenes/incense.tscn") as PackedScene).instantiate()
	street.projectiles.add_child(orb)
	orb.mode = "orbit"
	orb.anchor = hero
	orb.orbit_radius = 80.0
	orb.orbit_speed = 0.0
	orb.orbit_angle = PI / 2.0
	orb.lifetime = 10.0
	orb.launch(hero.position)
	orb.step(0.0)
	_expect(absf((orb.position - hero.position).y - 80.0 * orb.ORBIT_SQUASH) < 0.5, "orbits are squashed into an ellipse on the ground")
	orb.queue_free()
	await _frames(1)

	# --- solid props ---
	var chunk: Node2D = map.get_node("%Props").get_child(0)
	var stall: Node2D = (load("res://scenes/props/stall_fruit.tscn") as PackedScene).instantiate()
	chunk.add_child(stall)
	stall.global_position = hero.position + Vector2(0.0, 90.0)
	_reindex(map)
	await _frames(2)
	var foot: Rect2 = _footprint(stall)
	for i: int in 60:
		street.step(DT, Vector2.DOWN, 1.0)
		await _frames(1)
	_expect(hero.position.y < foot.position.y, "the hero cannot walk through a stall")
	var pushed: Vector2 = map.push_out(foot.get_center(), 10.0)
	_expect(not foot.grow(9.9).has_point(pushed), "a walker inside a solid prop is pushed out")
	chunk.remove_child(stall)
	stall.free()
	_reindex(map)

	# --- breakable props ---
	street.clear()
	street.spawn_left = 1000.0
	street.surge_left = 1000.0
	var crate: Node2D = (load("res://scenes/props/fruit_crate.tscn") as PackedScene).instantiate()
	chunk.add_child(crate)
	crate.key = "test,crate"
	crate.global_position = hero.position + Vector2(140.0, 0.0)
	_reindex(map)
	var crate_foot: Rect2 = _footprint(crate)
	_expect(map.blocked(crate_foot.get_center()), "a standing crate is a roadblock")
	var drops_before: int = street.pickups.get_child_count()
	street.blast(crate.global_position, 30.0, 999.0, 1.0, &"gold")
	_expect(crate.is_queued_for_deletion() and street.props_broken == 1, "weapon damage breaks a crate")
	_expect(not map.blocked(crate_foot.get_center()), "a broken crate no longer blocks the street")
	_expect(street.pickups.get_child_count() >= drops_before + 1 + crate.coins, "a broken crate drops experience and coins")
	var cone: Node2D = (load("res://scenes/props/cone.tscn") as PackedScene).instantiate()
	chunk.add_child(cone)
	cone.key = "test,cone"
	cone.global_position = hero.position + Vector2(30.0, 0.0)
	_reindex(map)
	street.grid.rebuild([])
	_expect(street.arsenal._punch(street.build.weapon_stats(&"punch")) and cone.hp < 10.0, "with nobody in reach the fist smashes a nearby prop")
	await _frames(1)
	var real: Node2D = null
	for prop: Node2D in map._breakables:
		if not prop.key.begins_with("test"):
			real = prop
			break
	_expect(real != null, "generated chunks contain breakable props")
	if real != null:
		var key: String = real.key
		street.hit_props(real.global_position, 4.0, 999.0)
		await _frames(1)
		map.follow(hero.position + Vector2(6000.0, 6000.0))
		map.follow(hero.position)
		await _frames(1)
		var back: bool = false
		for each: Node2D in map.get_node("%Props").get_children():
			for prop: Node in each.find_children("*", "Node2D", true, false):
				if not prop.is_queued_for_deletion() and "key" in prop and prop.key == key:
					back = true
		_expect(not back, "a broken prop stays broken when its chunk is rebuilt")

	# --- enemies left behind move ahead ---
	street.clear()
	street.spawn_left = 1000.0
	street.surge_left = 1000.0
	var view: Rect2 = street.view_rect()
	var straggler: Node2D = street.spawn_enemy(2, hero.position + Vector2(0.0, view.size.y * 0.5 + 200.0))
	var elite: Node2D = street.spawn_enemy(2, hero.position + Vector2(60.0, view.size.y * 0.5 + 200.0), 1.0, true)
	for i: int in 200:
		street.step(DT, Vector2.UP, 2.0)
	_expect(street.relocations >= 1 and straggler.position.y < hero.position.y, "a regular enemy left behind off-screen reappears ahead of the walking hero")
	_expect(elite.position.y > hero.position.y, "elites are never moved ahead")

	# --- surge and elite pacing ---
	var phase: Resource = street.schedule.phases[street.schedule.index_at(120.0)]
	street.surge_left = 0.001
	street.spawn_left = 0.0001
	street.step(DT, Vector2.ZERO, 120.0)
	_expect(street.surges == 0, "no surge while an elite is alive")
	_expect(street.spawn_left > phase.interval * 1.5, "regular spawns slow down while an elite is alive")
	street.clear()
	street.spawn_left = 1000.0
	street.surge_left = 0.001
	street.step(DT, Vector2.ZERO, 120.0)
	_expect(street.surges == 1 and street.living_count() >= mini(street.surge_base, phase.max_alive), "a surge pours in a crowd at once")
	_expect(game.hud.get_node("%Banner").visible and game.hud.get_node("%Banner").text == street.surge_text, "the surge is announced on screen")
	var sides: Array = street.enemies.get_children().map(func(e: Node2D) -> float: return (e.position - hero.position).angle())
	var spread: float = 0.0
	for angle: float in sides:
		spread = maxf(spread, absf(angle_difference(sides[0], angle)))
	_expect(spread < 1.6, "a surge comes from one direction")
	_expect(street.enemies.get_children().all(func(e: Node2D) -> bool: return not street.view_rect().has_point(e.position)), "surge enemies arrive from outside the view")

	# --- off-screen markers ---
	street.clear()
	var far_chest: Node2D = street.drop("chest", hero.position + Vector2(0.0, 2000.0), 1.0)
	_expect(street.get_node("%Markers").targets().has(far_chest.position), "an off-screen chest gets an edge marker")

	# --- reroll ---
	street.build.pending_choices = 1
	street.build.picked_ids.append(&"x")
	game.state = game.State.RUNNING
	game.show_upgrades()
	var first: Array = game.current_offers.duplicate()
	_expect(street.build.rerolls == 1 and not game.upgrade_panel.reroll.disabled, "each run starts with one reroll")
	_expect(game.reroll_upgrades() and street.build.rerolls == 0 and game.upgrade_panel.reroll.disabled, "rerolling spends it and disables the button")
	_expect(not game.reroll_upgrades(), "no second reroll")
	_expect(game.choose_upgrade(game.current_offers[0].id), "a rerolled card can be chosen")
	_expect(first.size() == 3, "the panel offered three cards before the reroll")

	game.queue_free()
	await _frames(2)
	# The native audio thread needs wall time to release stopped playback resources.
	OS.delay_msec(150)
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	_finish("VIEW")

## Re-reads roadblocks and breakables after a test drops a prop straight into a chunk.
func _reindex(map: Node2D) -> void:
	for key: Vector2i in map._chunks:
		map._collect(key)
	map._rebuild_cells()

func _footprint(prop: Node2D) -> Rect2:
	var shape: CollisionShape2D = prop.get_node("Block/Footprint")
	var size: Vector2 = (shape.shape as RectangleShape2D).size * shape.global_scale.abs()
	return Rect2(shape.global_position - size * 0.5, size)
