extends "res://addons/proto_kit/test_kit.gd"
## Collision order, rounded roadblock corners, critical smoke, pause and scene cleanup.
const VFX = preload("res://addons/proto_kit/pixel_vfx.gd")
const GAME = preload("res://scenes/game.tscn")
const SHOT = preload("res://scenes/wave.tscn")
const META_PATH := "user://test_combat_regressions_meta.json"
var game: Node
var street: Node2D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	game = GAME.instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)
	game.set_physics_process(false)
	game.start_run()
	street = game.street
	await _reset()
	_test_roadblocks()
	await _test_hit_order()
	await _test_smoke()
	await _test_readability()
	await _test_density()
	await _test_clear()
	game.queue_free()
	await _frames(2)
	OS.delay_msec(150)
	await _frames(2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	print("checks: ", checks)
	_finish("COMBAT REGRESSIONS")

func _reset() -> void:
	street.clear()
	street.grid.rebuild([])
	street.map._blocks.clear()
	street.map._rebuild_cells()
	street.player.reset()
	street.spawn_left = 10000.0
	street.surge_left = 10000.0
	street.build.weapons.clear()
	street.build.levels.clear()
	await _frames(1)

func _walls(rects: Array) -> void:
	street.map._blocks.clear()
	street.map._blocks[Vector2i(99999, 99999)] = rects
	street.map._rebuild_cells()

func _test_roadblocks() -> void:
	var map: Node2D = street.map
	_walls([Rect2(70, -60, 10, 120), Rect2(30, -60, 10, 120)])
	_expect(is_equal_approx(map.sweep_block(Vector2.ZERO, Vector2(100, 0), 5), 0.25), "sweep chooses the nearest thin wall, including projectile radius")
	_walls([Rect2(-60, 30, 120, 10)])
	_expect(is_equal_approx(map.sweep_block(Vector2.ZERO, Vector2(0, 100), 5), 0.25), "vertical movement handles a zero x component")
	_expect(is_inf(map.sweep_block(Vector2(200, 0), Vector2(200, 100), 5)), "parallel movement outside the wall does not collide")
	_walls([Rect2(-330, -360, 10, 120)])
	_expect(is_equal_approx(map.sweep_block(Vector2(-400, -300), Vector2(-200, -300), 5), 0.325), "negative coordinates and multiple grid cells are swept")
	_walls([Rect2(0, 0, 10, 10)])
	_expect(is_inf(map.sweep_block(Vector2(-6, -4), Vector2(-4, -4), 5)), "a circle can pass the empty square outside a rounded corner")
	var corner_t: float = map.sweep_block(Vector2(-10, -3), Vector2(10, -3), 5)
	_expect(is_equal_approx(corner_t, 0.3), "rounded corner contact uses the circle, not an expanded box")
	_expect(is_equal_approx(map.sweep_block(Vector2(-10, -5), Vector2(10, -5), 5), 0.5), "an exact corner tangent is detected")
	_expect(map.sweep_block(Vector2(5, 5), Vector2(5, 5), 5) == 0.0, "stationary overlap returns contact at the start")
	_expect(is_inf(map.sweep_block(Vector2(-4, -4), Vector2(-4, -4), 5)), "stationary point outside a rounded corner stays clear")
	_expect(is_equal_approx(map.sweep_block(Vector2(-10, 5), Vector2(10, 5), 0), 0.5), "zero radius reduces to segment versus rectangle")

func _shot(at: Vector2, mode: String = "straight") -> Node2D:
	var shot := SHOT.instantiate() as Node2D
	street.projectiles.add_child(shot)
	shot.mode = mode
	shot.velocity = Vector2(1000, 0)
	shot.radius = 5.0
	shot.damage = 1.0
	shot.force = 0.0
	shot.lifetime = 10.0
	shot.pierce = -1
	shot.launch(at)
	return shot

func _test_hit_order() -> void:
	var at: Vector2 = street.player.position
	_walls([Rect2(at + Vector2(30, -60), Vector2(10, 120))])
	var behind = street.spawn_enemy(0, at + Vector2(90, 0))
	street.grid.rebuild([behind])
	var hp: float = behind.hp
	var shot := _shot(at)
	street._step_projectiles(0.1)
	_expect(behind.hp == hp and shot.is_queued_for_deletion() and shot.position.distance_to(at + Vector2(25, 0)) < 0.01, "fast shot stops at the wall without damaging the enemy behind")
	await _reset()
	var far = street.spawn_enemy(0, at + Vector2(75, 0))
	var near = street.spawn_enemy(0, at + Vector2(35, 0))
	street.grid.rebuild([far, near])
	hp = near.hp
	shot = _shot(at)
	shot.pierce = 1
	street._step_projectiles(0.1)
	_expect(near.hp == hp - 1.0 and far.hp == hp, "one-hit shot damages the nearest enemy even if the grid returns the far enemy first")
	await _reset()
	_walls([Rect2(at + Vector2(30, -60), Vector2(10, 120))])
	shot = _shot(at)
	shot.lifetime = 0.05
	shot.blast_radius = 10.0
	street._step_projectiles(0.1)
	_expect(shot.detonate and shot.position.distance_to(at + Vector2(25, 0)) < 0.01, "expiry in the crossing frame still detonates at the wall")
	await _reset()
	_walls([Rect2(at + Vector2(30, -60), Vector2(10, 120))])
	shot = _shot(at, "boomerang")
	street._step_projectiles(0.1)
	_expect(shot.is_queued_for_deletion(), "boomerangs also sweep roadblocks")
	await _reset()
	_walls([Rect2(at + Vector2(30, -60), Vector2(10, 120))])
	shot = _shot(at, "lob")
	shot.target_point = at + Vector2(100, 0)
	shot.lifetime = 1.0
	street._step_projectiles(0.5)
	_expect(not shot.is_queued_for_deletion() and shot.position.x > at.x + 40, "lobbed projectiles keep flying over roadblocks")
	await _reset()

func _test_smoke() -> void:
	var fx: Node2D = street.fx
	for i: int in fx.max_shader_effects:
		fx.effect(&"explosion", Vector2.ZERO, Vector2(40, 40), 20.0, &"blast")
	_expect(fx.effect(&"gas", Vector2.ZERO, Vector2(40, 40), 1.0, &"fart") == null, "cosmetic shader cap is genuinely full")
	street._smoke(street.player.position)
	street._smoke(street.player.position + Vector2(120, 0))
	var cloud = street.hazards.get_child(0)
	var other = street.hazards.get_child(1)
	_expect(cloud.cloud.is_visible_in_tree() and cloud.footprint.is_visible_in_tree(), "critical smoke and footprint remain visible at the cosmetic cap")
	_expect(cloud.cloud.material != other.cloud.material, "overlapping smoke hazards have independent materials")
	cloud.step(1.0)
	other.step(2.0)
	_expect(is_equal_approx(cloud.cloud.material.get_shader_parameter("progress"), 1.0 / cloud.lifetime) and is_equal_approx(other.cloud.material.get_shader_parameter("progress"), 2.0 / other.lifetime), "smoke visuals follow each hazard simulation clock")
	var saved_age: float = cloud.age
	var saved_fx_age: float = fx.get_children().filter(func(n: Node) -> bool: return n is VFX.ShaderEffect)[0].age
	game.pause_run()
	await _frames(4)
	_expect(cloud.age == saved_age, "pause freezes the critical smoke clock")
	var live_effect = fx.get_children().filter(func(n: Node) -> bool: return n is VFX.ShaderEffect)[0]
	_expect(live_effect.age == saved_fx_age, "pause freezes cosmetic shader clocks too")
	game.resume_run()
	# Damage must stop in the same simulation step the final visible boundary expires.
	for hazard: Node in street.hazards.get_children():
		hazard.age = hazard.lifetime - 0.01
	street.player.hurt_cooldown = 0.0
	var hp: float = street.player.hp
	street.step(0.02, Vector2.ZERO, 0.02)
	_expect(street.player.hp == hp, "expired smoke does not deal one last invisible hit")
	await _frames(1)
	_expect(street.hazards.get_child_count() == 0, "expired smoke scenes are reclaimed")
	var stats: Dictionary = game.snapshot()
	_expect(stats.effects == fx.count() and stats.vfx.shaders == fx.count_effects(), "telemetry reads the actual renderer")
	await _reset()

func _test_readability() -> void:
	await _reset()
	var player: Node2D = street.player
	var man: CanvasItem = player.body_man.get_node("Readability")
	var woman: CanvasItem = player.body_woman.get_node("Readability")
	street._refresh_player_readability()
	_expect(not man.visible and not woman.visible, "quiet combat leaves the hero's authored appearance unchanged")
	for i: int in street.readability_projectiles:
		_shot(player.position)
	street._refresh_player_readability()
	_expect(man.is_visible_in_tree() and not woman.is_visible_in_tree(), "crowded projectiles reveal only the selected hero silhouette")
	_expect(man.z_index > street.projectiles.z_index and not man.z_as_relative, "the silhouette stays above projectiles without changing actor depth sorting")
	_expect(player.hp_bar.z_index > street.fx.z_index and not player.hp_bar.z_as_relative, "the player's health remains readable above VFX")
	player.set_hero(street.heroes[1])
	_expect(woman.is_visible_in_tree() and not man.is_visible_in_tree(), "readability follows the woman hero and inherited facing/animation")
	_expect(man.transform == player.body_man.get_node("Art").transform and woman.transform == player.body_woman.get_node("Art").transform, "readability sprites preserve the authored art transforms")
	player.set_hero(street.heroes[0])
	street.clear()
	_expect(not man.visible and not woman.visible, "clear resets the crowd-only silhouette")
	await _frames(1)

## Exercise real actors/projectiles plus both VFX renderers at capacity for five simulation seconds.
func _test_density() -> void:
	await _reset()
	var at: Vector2 = street.player.position
	for i: int in street.max_enemies:
		var enemy = street.spawn_enemy(i % 4, at + Vector2.RIGHT.rotated(i * 2.399) * (100.0 + i % 5 * 45.0))
		enemy.hp = 100000.0
	var budgets_hold: bool = true
	var smoke_readable: bool = true
	var peak := {"actors": 0, "projectiles": 0, "particles": 0, "shapes": 0, "shaders": 0, "hazards": 0}
	for tick: int in 300:
		if tick % 30 == 0:
			for i: int in 40:
				var shot := _shot(at)
				shot.velocity = Vector2.RIGHT.rotated(i * TAU / 40.0) * 160.0
				shot.lifetime = 2.0
		if tick % 4 == 0:
			for i: int in 16:
				street.fx.effect(&"explosion" if i % 2 == 0 else &"gas", at, Vector2(100, 100), 0.5, &"firecracker" if i % 2 == 0 else &"fart")
		for i: int in 20:
			street.fx.burst(at, &"hit", 5)
			street.fx.ring(at, 10, 60, &"hit")
			street.fx.star(at, &"hit")
		street._smoke(at + Vector2(120, 0))
		street.step(1.0 / 60.0, Vector2.ZERO, tick / 60.0)
		var stats: Dictionary = game.snapshot()
		var fx: Dictionary = stats.vfx
		budgets_hold = budgets_hold and fx.particles <= fx.limits.particles and fx.shapes <= fx.limits.shapes and fx.shaders <= fx.limits.shaders and stats.hazards <= street.max_hazards and stats.living <= street.max_enemies
		for key: String in ["actors", "projectiles", "hazards"]:
			peak[key] = maxi(peak[key], stats[key])
		for key: String in ["particles", "shapes", "shaders"]:
			peak[key] = maxi(peak[key], fx[key])
		for cloud: Node in street.hazards.get_children():
			if not cloud.is_queued_for_deletion():
				smoke_readable = smoke_readable and cloud.cloud.is_visible_in_tree() and cloud.footprint.is_visible_in_tree()
		await _frames(1)
	var dropped: Dictionary = street.fx.stats().dropped
	_expect(budgets_hold, "all renderer and hazard budgets hold throughout dense combat")
	_expect(smoke_readable and peak.hazards == street.max_hazards, "critical smoke stays visible while cosmetic requests are dropped")
	_expect(peak.actors == 140 and peak.projectiles >= 40 and peak.shaders == 12 and peak.particles == 500 and peak.shapes == 80, "density run genuinely reaches the intended actor and renderer limits")
	_expect(dropped.particles > 0 and dropped.shapes > 0 and dropped.shaders > 0, "density run exercises every rejection counter")
	print("DENSITY ", JSON.stringify({"seconds": 5, "peak": peak, "dropped": dropped}))
	await _reset()

func _test_clear() -> void:
	var enemy = street.spawn_enemy(0, street.player.position + Vector2(60, 0))
	street.grid.rebuild([enemy])
	street.fx.slash(street.player.position, 0.0, 80.0, 1.7, &"hit")
	street._smoke(street.player.position)
	street.clear()
	_expect(street.fx.count() == 0 and street.hazards.get_child_count() == 0, "clear removes all critical and cosmetic visuals immediately")
	_expect(street.grid.cells.is_empty(), "clear also clears enemy references in the spatial index")
	# Keep subsequent diagnostics safe if this assertion fails on a regression.
	if not street.grid.cells.is_empty():
		street.grid.rebuild([])
	await _frames(2)
	_expect(street.grid.query(street.player.position, 1000).is_empty(), "queries after clear cannot reach freed enemies")
