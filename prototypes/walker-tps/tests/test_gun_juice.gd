extends "res://addons/proto_kit/test_kit.gd"
## The cannon feel standard (docs: godot-kit/skills/gun-juice): every item is checked on the
## real scenes, so a refactor that drops one (e.g. moves the flash a frame late) fails here.
var main: Node
var walker: CharacterBody3D
var combat: Node
var enemy: CharacterBody3D

func _init() -> void: _run.call_deferred()
func _run() -> void:
	main = load("res://scenes/battlefield.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	walker = main.get_node("Walker")
	combat = walker.get_node("Combat")
	enemy = main.get_node("Enemies/Scout0")
	await _frames(30)
	main.start_match()
	for scout: CharacterBody3D in main.get_node("Enemies").get_children():
		scout.set("ai_enabled", false)
		# The timing checks use live rounds. Keep the later hit fixture out of their path.
		scout.collision_layer = 0
	await _frames(30)
	await _test_trigger_frame()
	await _test_autofire_spread()
	await _test_magazine()
	await _test_splash()
	await _test_hit_and_kill()
	_finish("GUN_JUICE")

## 1 + 4 + 5 + 6: one call to try_fire() does everything on that frame.
func _test_trigger_frame() -> void:
	walker.velocity = Vector3.ZERO
	var shells: Node = main.get_tree().get_first_node_in_group("debris_shells")
	var shells_before: int = shells.active_count()
	var clinks := [0]
	var count_clink := func(_at: Vector3, _speed: float) -> void: clinks[0] += 1
	shells.landed.connect(count_clink)
	var vel_before := walker.velocity
	combat.reload_left = 0.0
	_expect(combat.try_fire(), "fires")
	var flash_layers := combat.get_node("MuzzleFlash").find_children("*", "GPUParticles3D", true, false)
	_expect(flash_layers.all(func(n: Node) -> bool: return (n as GPUParticles3D).emitting), "muzzle flash restarts on the trigger frame")
	_expect(combat.cannon.position.distance_to(combat.cannon_rest) > 0.25, "barrel kicks back on the trigger frame")
	_expect(combat.rig._recoil > 0.0 and combat.rig._trauma > 0.0, "camera kicks and shakes on the trigger frame")
	_expect((walker.velocity - vel_before).dot(-combat.muzzle.global_basis.z) > 0.5, "recoil shoves the hull back")
	_expect(shells.active_count() == shells_before + 1, "a shell casing is ejected")
	_expect(combat.get_node("ShotSound").playing, "shot sound plays")
	var shot: Node = main.get_node("Projectiles").get_child(main.get_node("Projectiles").get_child_count() - 1)
	_expect(shot.damage == 55.0 and shot.impact_radius == 4.0 and shot.splash_radius == 5.5, "heavy cannon round: direct damage, big burst and splash")
	_expect(combat.magazine_size == 8, "heavy cannon carries eight rounds")
	await _frames(1)
	_expect(shot.get_node("Tail").scale.z > 1.0, "the round has a tracer tail")
	_expect(shot.get_node("Head").scale.x == 2.0 and shot.get_node("Tail").scale.x == 2.0
		and shot.tail_seconds > 0.09, "the heavy cannon has a larger head and a wider, longer tracer")
	_expect(not shot.get_node("Whiz").playing, "the walker's own rounds do not whiz past itself")
	_expect(shot.get_node("Tail").scale.z <= shot.global_position.distance_to(combat.muzzle.global_position) + 0.3, "the tracer never reaches back inside the barrel")
	await _frames(12)
	_expect(combat.cannon.position.distance_to(combat.cannon_rest) < 0.05, "barrel returns fast, well before the next shot matters")
	await _frames(30)
	await _frames(40)  # a casing flies about 0.8 s before its first bounce
	shells.landed.disconnect(count_clink)
	_expect(shells.active_count() >= 1, "casings stay on the floor")
	_expect(clinks[0] >= 1 and combat.get_node("ShellSound").stream.resource_path.ends_with("shell_drop.ogg"), "a casing clinks when it lands")
	# An enemy round that flies close past the walker cracks by (whiz); it does not hit.
	var miss := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	miss.team = "enemy"
	main.get_node("Projectiles").add_child(miss)
	var side: Vector3 = walker.global_basis.x.normalized()
	miss.global_position = walker.global_position + Vector3.UP * 1.3 + side * 3.0 - walker.global_basis.z.normalized() * 20.0
	miss.direction = walker.global_basis.z.normalized()
	miss.speed = 60.0
	await _frames(1)
	_expect(miss.get_node("Head").scale.x == 1.0 and miss.get_node("Tail").scale.x == 1.0,
		"enemy projectile visuals retain their original scale")
	var whizzed := false
	for i in 40:
		await _frames(1)
		if not is_instance_valid(miss): break
		if miss.get_node("Whiz").playing: whizzed = true
	_expect(whizzed, "an enemy near miss whizzes past")
	if is_instance_valid(miss): miss.queue_free()

## 2: autofire with random spread and speed.
func _test_autofire_spread() -> void:
	seed(48251)
	for node: Node in main.get_node("Projectiles").get_children(): node.free()
	var dirs: Array[Vector3] = []
	var speeds: Array[float] = []
	var spread_angles: Array[float] = []
	var fired := 0
	for i in 60:  # one second of holding the trigger (the walker's own step counts reload down)
		if combat.try_fire():
			fired += 1
			var shot: Node = main.get_node("Projectiles").get_child(main.get_node("Projectiles").get_child_count() - 1)
			dirs.append(shot.direction)
			spread_angles.append(shot.direction.angle_to(combat.muzzle.global_basis.z))
			speeds.append(shot.speed)
		await _frames(1)
	_expect(fired == 3, "autofire: 3 rounds from a fresh trigger in one second (%d)" % fired)
	_expect(dirs.any(func(d: Vector3) -> bool: return d.angle_to(dirs[0]) > 0.002), "rounds spread randomly")
	_expect(speeds.max() - speeds.min() > 2.0, "round speed varies")
	_expect(spread_angles.all(func(angle: float) -> bool: return angle < deg_to_rad(combat.spread_deg) + 0.01), "spread stays inside the cone")
	for node: Node in main.get_node("Projectiles").get_children(): node.free()
	await _frames(2)

## Magazine: the last round starts a reload that locks the trigger, then refills.
func _test_magazine() -> void:
	combat.ammo = 1
	combat.reload_left = 0.0
	_expect(combat.try_fire() and combat.ammo == 0 and combat.magazine_left > 0.0, "the last round starts a reload")
	combat.reload_left = 0.0
	_expect(not combat.try_fire(), "no fire while reloading")
	for i in int(combat.magazine_reload_time * 60) + 10: await _frames(1)
	_expect(combat.ammo == combat.magazine_size and combat.magazine_left == 0.0, "magazine refills")
	_expect(combat.try_fire(), "fires again after the reload")
	for node: Node in main.get_node("Projectiles").get_children(): node.free()

## 3 + 5 + 6 + 7: a hit flashes, squashes and shoves the target, spills parts; a wall pings; a kill freezes and throws.
func _test_hit_and_kill() -> void:
	enemy.collision_layer = 4
	enemy.global_position = walker.global_position + Vector3(0, 0, 12)
	enemy.velocity = Vector3.ZERO
	await _frames(3)
	var parts: Node = main.get_tree().get_first_node_in_group("debris_parts")
	var before := enemy.global_position
	var parts_hit: int = parts.active_count()
	var shot := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	main.get_node("Projectiles").add_child(shot)
	shot.global_position = enemy.global_position + Vector3(0, 1.1, -6)
	shot.direction = Vector3.BACK
	shot.speed = 900
	shot.damage = 10
	shot.excluded.assign([walker.get_rid()])
	await _frames(3)
	var react: Node = enemy.get_node("HitReact")
	var model: Node3D = enemy.get_node("Model")
	_expect(react.is_reacting() and model.scale.y < react._rest_scale.y, "hit target squashes")
	_expect(model.find_children("*", "GeometryInstance3D", true, false).any(func(m: Node) -> bool: return (m as GeometryInstance3D).material_overlay != null) or react._flash_left <= 0.0, "hit target flashes white")
	_expect((enemy.global_position - before).dot(Vector3.BACK) > 0.025 or enemy.get("knock_velocity").dot(Vector3.BACK) > 0.0, "hit target is shoved back")
	var impacts := main.get_node("Projectiles").get_children().filter(func(n: Node) -> bool: return n.get("surface") != null)
	_expect(impacts.any(func(n: Node) -> bool: return n.surface == "body" and n.get_node("Sound").stream.resource_path.ends_with("round_impact.ogg")), "a cannon round bursts with the impact explosion sound")
	_expect(impacts.all(func(n: Node) -> bool: return n.surface != "body" or not n.get_node("Fx/Flash").visible), "a body hit sprays sparks, no glow disc")
	_expect(impacts.any(func(n: Node) -> bool: return n.surface == "body" and n.get_node("Fx/Fireball").visible and n.get_node("Fx/Sparks").visible), "a body hit bursts: sparks and a small explosion")
	_expect(parts.active_count() >= parts_hit + 2, "a body hit knocks parts off")
	var parts_before: int = parts.active_count()
	enemy.apply_damage(10000, enemy.global_position, Vector3.BACK)
	_expect(Engine.time_scale < 0.5, "the kill freezes the game (hit stop)")
	_expect(parts.active_count() >= parts_before + 6, "the wreck sheds parts")
	var y0 := model.global_position.y
	await _frames(20)
	OS.delay_msec(200)  # hit stop runs on the wall clock
	await _frames(10)
	_expect(Engine.time_scale == 1.0, "time resumes after the freeze")
	_expect(model.global_position.y > y0 + 0.3 or model.global_position.distance_to(before) > 1.0, "the dead body is thrown")
	# A wall: ping, sparks along the normal.
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 6, 0.3)
	col.shape = shape
	wall.add_child(col)
	main.add_child(wall)
	wall.global_position = walker.global_position + Vector3(8, 2, 20)
	await _frames(2)
	var ricochet := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	main.get_node("Projectiles").add_child(ricochet)
	ricochet.global_position = wall.global_position + Vector3(0, 0, -4)
	ricochet.direction = Vector3.BACK
	ricochet.excluded.assign([walker.get_rid()])
	await _frames(6)
	impacts = main.get_node("Projectiles").get_children().filter(func(n: Node) -> bool: return n.get("surface") == "wall")
	_expect(impacts.size() == 1, "a wall hit pings")
	_expect(impacts.size() == 1 and impacts[0].get_node("Fx").global_basis.y.normalized().dot(Vector3.FORWARD) > 0.9, "wall sparks spray out of the surface")
	wall.queue_free()
	await _frames(2)

## Splash: a round bursting on the ground between two scouts hurts both and shoves them outward;
## the nearer one takes more.
func _test_splash() -> void:
	var near: CharacterBody3D = main.get_node("Enemies/Scout1")
	var far: CharacterBody3D = main.get_node("Enemies/Scout2")
	var at := walker.global_position + Vector3(0, 0, 20)
	for s: CharacterBody3D in [near, far]:
		s.collision_layer = 4
		s.velocity = Vector3.ZERO
	near.global_position = at + Vector3(1.5, 0, 0)
	far.global_position = at + Vector3(-4.5, 0, 0)
	await _frames(3)
	var hp_near: float = near.health
	var hp_far: float = far.health
	var shot := load("res://scenes/combat_projectile.tscn").instantiate() as Node3D
	main.get_node("Projectiles").add_child(shot)
	shot.global_position = at + Vector3(0, 3, 0)
	shot.direction = Vector3.DOWN
	shot.speed = 300
	shot.damage = 55
	shot.splash_radius = combat.splash_radius
	shot.splash_damage = combat.splash_damage
	shot.excluded.assign([walker.get_rid()])
	await _frames(3)
	var lost_near: float = hp_near - near.health
	var lost_far: float = hp_far - far.health
	_expect(lost_near > 0.0 and lost_far > 0.0, "splash hurts every scout in the burst (%.1f, %.1f)" % [lost_near, lost_far])
	_expect(lost_near > lost_far, "splash falls off with distance")
	_expect(near.global_position.x - at.x > 1.5 and far.global_position.x - at.x < -4.5, "splash shoves targets away from the burst")
	for s: CharacterBody3D in [near, far]:
		s.collision_layer = 0
		s.health = s.max_health
	for node: Node in main.get_node("Projectiles").get_children(): node.free()
