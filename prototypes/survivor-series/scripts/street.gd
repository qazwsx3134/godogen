extends Node2D
signal score_changed
signal player_hurt
signal chest_opened
## Big centre-screen notice, such as an incoming surge.
signal announced(text: String)
const Shake = preload("res://addons/proto_kit/camera_shake.gd")
const Grid = preload("res://scripts/grid.gd")
const Build = preload("res://scripts/run_build.gd")
## Smoker, bike, car, fatty: spawn weights in the schedule use this order.
@export var enemy_scenes: Array[PackedScene] = []
@export var smoke_scene: PackedScene
@export var pickup_scene: PackedScene
@export var number_scene: PackedScene
@export var progression: Resource
@export var schedule: Resource
## Playable heroes (HeroDef); `hero_id` picks one for the next run.
@export var heroes: Array[Resource] = []
## The play area travels with the hero (endless map): hero, enemies and drops stay inside it.
## Its size grows to the view plus a margin on wide screens; see `_recenter`.
@export var bounds := Rect2(48.0, 48.0, 1104.0, 1584.0)
@export var max_enemies: int = 140
@export var max_gems: int = 160
@export var max_hazards: int = 10
## Fire palettes use a brief radial explosion; fart/stink use gas, other palettes a quick flash.
@export var explosive_palettes: Array[StringName] = [&"blast", &"firecracker"]
## Floating damage numbers on screen at once; further hits show none until some fade.
@export var max_numbers: int = 40
@export var magnet_radius: float = 70.0
## Off-screen enemies left behind for this long while the hero walks away reappear ahead of the hero.
@export var relocate_after: float = 2.5
## While an elite is alive the regular spawn interval is divided by this (0.5 = half as many).
@export var elite_spawn_scale: float = 0.5
@export_group("Surge")
## Every `surge_interval` seconds (random in the range) a crowd pours in from one direction.
@export var surge_interval := Vector2(38.0, 56.0)
@export var surge_base: int = 10
@export var surge_per_minute: float = 3.0
@export var surge_text: String = "下班人潮來了！"
@export_group("Drops")
@export var coin_chance: float = 0.03
@export var food_chance: float = 0.006
@export var magnet_chance: float = 0.002
@onready var player: CharacterBody2D = %Player
@onready var enemies: Node2D = %Enemies
@onready var hazards: Node2D = %Hazards
@onready var effects: Node2D = %Effects
@onready var projectiles: Node2D = %Projectiles
@onready var pickups: Node2D = %Pickups
@onready var numbers: Node2D = %Numbers
@onready var camera: Camera2D = %Camera
@onready var arsenal: Node = %Arsenal
@onready var map: Node2D = %Map
@onready var fx: Node2D = %Fx
var time_control: Node
var sfx: Node
var shake = Shake.new()
var grid = Grid.new()
var build: RefCounted
var hero_id: StringName = &"man"
var meta_bonus: Dictionary = {}
var meta_unlocks: Array = []
## Fusion ids found in earlier runs; their cards show the real name.
var meta_fusions: Array = []
var rng := RandomNumberGenerator.new()
## Cosmetic randomness only, so effects never shift spawns or drops.
var _fx_rng := RandomNumberGenerator.new()
var kills: int = 0
var hits_taken: int = 0
var damage_taken: float = 0.0
## Damage taken per source kind this run, for tuning.
var damage_sources: Dictionary = {}
var warnings: int = 0
var smoke_spawns: int = 0
var bursts_fired: int = 0
var coins: int = 0
var chests: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_left: float = 0.0
var spawn_left: float = 0.0
var surge_left: float = 0.0
var surges: int = 0
var relocations: int = 0
var props_broken: int = 0
var _last_hero := Vector2.ZERO
var _hero_velocity := Vector2.ZERO
var phase_index: int = -1
var punching: bool = false
var big_gem: Node2D
var _bursts: Array = []
var _frame_kills: int = 0
var _frame_big: bool = false

func _ready() -> void:
	shake.camera = camera
	shake.max_offset = Vector2(12.0, 8.0)
	shake.max_roll = 0.01
	rng.randomize()
	arsenal.street = self

func clear() -> void:
	for holder: Node2D in [enemies, hazards, effects, projectiles, pickups, numbers]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_bursts.clear()
	fx.clear()
	big_gem = null
	shake.trauma = 0.0
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	if time_control != null:
		time_control.reset()

func reset() -> void:
	clear()
	var hero: Resource = hero_def()
	build = Build.new(progression, meta_bonus, meta_unlocks, hero.start_weapon if hero != null else &"")
	for id: Variant in meta_fusions:
		build.discovered[StringName(id)] = true
	player.set_hero(hero)
	player.reset(player.max_hp * player.hero_hp * (1.0 + build.stat(&"max_hp")), build.stat(&"armor"), build.stat(&"speed"))
	arsenal.reset()
	kills = 0
	hits_taken = 0
	damage_taken = 0.0
	damage_sources.clear()
	warnings = 0
	smoke_spawns = 0
	bursts_fired = 0
	coins = 0
	chests = 0
	combo = 0
	best_combo = 0
	combo_left = 0.0
	spawn_left = 1.0
	surge_left = rng.randf_range(surge_interval.x, surge_interval.y)
	surges = 0
	relocations = 0
	props_broken = 0
	phase_index = -1
	camera.position = player.position
	_last_hero = player.position
	_hero_velocity = Vector2.ZERO
	_recenter()
	map.reset(player.position)
	# Three distinct editable scene instances introduce the run immediately.
	spawn_enemy(0, player.position + Vector2(0.0, -150.0))
	spawn_enemy(1, player.position + Vector2(-220.0, -260.0))
	spawn_enemy(2, player.position + Vector2(230.0, -220.0))
	score_changed.emit()

func hero_def() -> Resource:
	for entry: Resource in heroes:
		if entry.id == hero_id:
			return entry
	return heroes[0] if not heroes.is_empty() else null

func build_force() -> float:
	return 1.0

## Re-applies passive and shop stats to the hero after a pick; a higher HP cap heals the difference.
func refresh_player_stats() -> void:
	var limit: float = player.max_hp * player.hero_hp * (1.0 + build.stat(&"max_hp"))
	var gained: float = limit - player.hp_limit
	player.hp_limit = limit
	player.armor = build.stat(&"armor")
	player.speed_scale = player.hero_speed * (1.0 + build.stat(&"speed"))
	player.heal(maxf(0.0, gained))

func spawn_enemy(index: int, at: Vector2, hp_scale: float = 1.0, elite: bool = false) -> Node2D:
	var enemy := enemy_scenes[index].instantiate() as Node2D
	enemies.add_child(enemy)
	enemy.position = map.push_out(at.clamp(bounds.position, bounds.end), enemy.definition.radius * 0.6)
	enemy.setup(hp_scale, elite)
	enemy.smoke_requested.connect(_smoke)
	enemy.warning_started.connect(_warning)
	enemy.impacted.connect(_impact)
	return enemy

## ponytail: enemies left behind get dragged along the edge of the moving area instead of despawning; fine off-screen.
func _recenter() -> void:
	var size: Vector2 = bounds.size.max(get_viewport_rect().size / camera.zoom + Vector2(480.0, 480.0))
	bounds = Rect2(player.position - size * 0.5, size)

func view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / camera.zoom
	# The camera's own position, not get_screen_center_position(): that one lags a frame behind step().
	return Rect2(camera.position - size * 0.5, size)

## Where a ray from the hero along `direction` leaves the view grown by `margin`.
func edge_point(direction: Vector2, margin: float = 60.0) -> Vector2:
	var view: Rect2 = view_rect().grow(margin)
	var from: Vector2 = player.position
	var reach: float = INF
	if direction.x != 0.0:
		reach = minf(reach, ((view.end.x if direction.x > 0.0 else view.position.x) - from.x) / direction.x)
	if direction.y != 0.0:
		reach = minf(reach, ((view.end.y if direction.y > 0.0 else view.position.y) - from.y) / direction.y)
	return from + direction * maxf(0.0, reach)

func elite_alive() -> bool:
	return elite_enemy() != null

## The first living elite, or null.
func elite_enemy() -> Node2D:
	for enemy: Node2D in enemies.get_children():
		if enemy.elite and not enemy.dead and not enemy.is_queued_for_deletion():
			return enemy
	return null

## A point just outside the visible rect, inside the block; falls back to the far edge of the block.
func spawn_point() -> Vector2:
	var view: Rect2 = view_rect().grow(60.0)
	for attempt: int in 8:
		var side: int = rng.randi_range(0, 3)
		var at: Vector2
		match side:
			0:
				at = Vector2(rng.randf_range(view.position.x, view.end.x), view.position.y)
			1:
				at = Vector2(rng.randf_range(view.position.x, view.end.x), view.end.y)
			2:
				at = Vector2(view.position.x, rng.randf_range(view.position.y, view.end.y))
			_:
				at = Vector2(view.end.x, rng.randf_range(view.position.y, view.end.y))
		if bounds.has_point(at):
			return at
	var far := Vector2(bounds.position.x if player.position.x > bounds.get_center().x else bounds.end.x, rng.randf_range(bounds.position.y, bounds.end.y))
	return far

func living_count() -> int:
	var total: int = 0
	for enemy: Node2D in enemies.get_children():
		if not enemy.dead and not enemy.is_queued_for_deletion():
			total += 1
	return total

func nearest_enemy() -> Node2D:
	return grid.nearest(player.position, player.attack_range * (build.weapon_stats(&"punch").area if build != null and build.count(&"punch") > 0 else 1.0))

func step(delta: float, direction: Vector2, elapsed: float) -> void:
	_frame_kills = 0
	_frame_big = false
	_resolve_bursts()
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left <= 0.0:
		combo = 0
	var living: Array = enemies.get_children().filter(func(e: Node2D) -> bool: return not e.dead and not e.is_queued_for_deletion())
	grid.rebuild(living)
	var slow: float = 0.0
	for enemy: Node2D in grid.query(player.position, 120.0):
		if enemy.definition.aura_radius > 0.0 and enemy.position.distance_to(player.position) <= enemy.definition.aura_radius:
			slow = maxf(slow, enemy.definition.aura_slow)
	_recenter()
	player.step(delta, direction, bounds.grow(-18.0), slow)
	_hero_velocity = (player.position - _last_hero) / delta if delta > 0.0 else Vector2.ZERO
	_last_hero = player.position
	camera.position = player.position
	map.follow(camera.position)
	map.tick(delta)
	shake.step(delta)
	_spawn(delta, elapsed, living.size())
	for enemy: Node2D in enemies.get_children():
		if enemy.is_queued_for_deletion():
			continue
		enemy.step(delta, player.position, bounds)
		if not enemy.dead and not enemy.is_queued_for_deletion():
			_relocate_if_left_behind(enemy, delta)
	grid.rebuild(enemies.get_children().filter(func(e: Node2D) -> bool: return not e.dead and not e.is_queued_for_deletion()))
	for enemy: Node2D in grid.query(player.position, 15.0):
		_hurt(enemy.contact_damage(), enemy.definition.kind + ("_dash" if enemy.phase == "dash" else ""))
		break
	_separate_enemies(delta)
	_block_enemies(delta)
	for cloud: Node2D in hazards.get_children():
		cloud.step(delta)
		if not cloud.is_queued_for_deletion() and cloud.position.distance_to(player.position) < cloud.radius + 12.0:
			_hurt(cloud.damage, "smoke")
	arsenal.step(delta)
	_step_projectiles(delta)
	_step_pickups(delta)
	var recovery: float = build.stat(&"recovery")
	if recovery > 0.0:
		player.heal(recovery * delta)
	_flush_feedback()

func _spawn(delta: float, elapsed: float, living: int) -> void:
	if schedule == null or schedule.phases.is_empty():
		return
	var index: int = schedule.index_at(elapsed)
	var phase: Resource = schedule.phases[index]
	if index != phase_index:
		phase_index = index
		_begin_phase(phase)
	var elite_here: bool = elite_alive()
	if not elite_here:
		surge_left -= delta
		if surge_left <= 0.0:
			surge_left = rng.randf_range(surge_interval.x, surge_interval.y)
			_surge(phase, elapsed, living)
	spawn_left -= delta
	if spawn_left > 0.0:
		return
	spawn_left = phase.interval / (elite_spawn_scale if elite_here else 1.0)
	var cap: int = mini(max_enemies, phase.max_alive)
	for i: int in phase.batch:
		if living + i >= cap or enemies.get_child_count() >= max_enemies + 30:
			break
		spawn_enemy(_pick_kind(phase.weights), spawn_point(), phase.hp_scale)

## A crowd from one direction, announced on screen. Counts toward the phase cap like normal spawns.
func _surge(phase: Resource, elapsed: float, living: int) -> void:
	var room: int = mini(max_enemies, phase.max_alive) - living
	var count: int = mini(room, surge_base + roundi(elapsed / 60.0 * surge_per_minute))
	if count <= 0:
		return
	surges += 1
	var heading: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU)
	for i: int in count:
		spawn_enemy(_pick_kind(phase.weights), edge_point(heading.rotated(rng.randf_range(-0.55, 0.55)), rng.randf_range(40.0, 140.0)), phase.hp_scale)
	sfx.play(&"warning", 0.1)
	announced.emit(surge_text)

## Like PokeSurvivor: a regular enemy stuck off-screen while the hero walks away is moved ahead of the hero,
## so on an endless map the crowd stays in front instead of trailing behind.
func _relocate_if_left_behind(enemy: Node2D, delta: float) -> void:
	if enemy.elite or enemy.phase in ["warning", "dash"]:
		enemy.lag = 0.0
		return
	var speed: float = _hero_velocity.length()
	var offset: Vector2 = enemy.position - player.position
	if view_rect().grow(60.0).has_point(enemy.position):
		enemy.lag = 0.0
		return
	if speed > 40.0 and offset.dot(_hero_velocity) < -0.2 * offset.length() * speed:
		enemy.lag += delta
	if enemy.lag < relocate_after:
		return
	enemy.lag = 0.0
	relocations += 1
	enemy.knockback = Vector2.ZERO
	enemy.position = map.push_out(edge_point(_hero_velocity.normalized().rotated(rng.randf_range(-0.9, 0.9)), rng.randf_range(40.0, 110.0)), enemy.definition.radius * 0.6)

func _begin_phase(phase: Resource) -> void:
	for i: int in phase.ring:
		if enemies.get_child_count() >= max_enemies + 30:
			break
		spawn_enemy(0, player.position + Vector2.RIGHT.rotated(TAU * i / phase.ring) * 340.0, phase.hp_scale)
	if phase.elite >= 0:
		spawn_enemy(phase.elite, spawn_point(), phase.hp_scale, true)
		sfx.play(&"warning", 0.1)

func _pick_kind(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for i: int in mini(weights.size(), enemy_scenes.size()):
		total += weights[i]
	var roll: float = rng.randf() * total
	for i: int in mini(weights.size(), enemy_scenes.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0

func _step_projectiles(delta: float) -> void:
	for shot: Node2D in projectiles.get_children():
		if shot.is_queued_for_deletion():
			continue
		if shot.homing:
			var target: Node2D = grid.nearest(shot.position, 260.0)
			if target != null:
				var want: Vector2 = (target.position - shot.position).normalized() * shot.velocity.length()
				shot.velocity = shot.velocity.lerp(want, minf(1.0, delta * 6.0))
		var airborne: bool = shot.flight_left > 0.0
		var before: Vector2 = shot.step(delta)
		var destination: Vector2 = shot.position
		var wall_t: float = INF
		if not airborne and shot.mode in ["straight", "boomerang"] and shot.velocity != Vector2.ZERO and not shot.is_queued_for_deletion():
			wall_t = map.sweep_block(before, destination, shot.radius)
		var hits: Array = []
		var stopped_on_enemy: bool = false
		if not shot.detonate and not shot.is_queued_for_deletion():
			for enemy: Node2D in grid.query((before + destination) * 0.5, before.distance_to(destination) * 0.5 + shot.radius):
				var contact: float = shot.hit_fraction(enemy, before)
				if is_finite(contact) and contact < wall_t:
					hits.append({"enemy": enemy, "t": contact})
			hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
			for hit: Dictionary in hits:
				var enemy: Node2D = hit.enemy
				var at: Vector2 = before.lerp(destination, hit.t)
				shot.remember(enemy)
				fx.burst(at - Vector2(0.0, shot.lift), shot.palette, 5 if shot.is_queued_for_deletion() else 3, 45.0)
				enemy.hit(shot.damage, shot.velocity.normalized() if shot.velocity != Vector2.ZERO else (enemy.position - player.position).normalized(), shot.force)
				if shot.detonate or shot.is_queued_for_deletion():
					shot.position = at
					stopped_on_enemy = true
					break
		if is_finite(wall_t) and not stopped_on_enemy and not shot.is_queued_for_deletion():
			shot.position = before.lerp(destination, wall_t)
			fx.spark(shot.position - Vector2(0.0, shot.lift), -shot.velocity.normalized(), shot.palette, 3)
			# Include the contacted prop even when its boundary is exactly one radius away.
			hit_props(shot.position, shot.radius + 0.1, shot.damage)
			if shot.blast_radius > 0.0:
				shot.detonate = true
			else:
				shot.queue_free()
				continue
		elif shot.mode not in ["lob", "fall"] and shot.flight_left <= 0.0 and not shot.is_queued_for_deletion():
			hit_props(shot.position, shot.radius, shot.damage)
		if shot.trail != &"" and shot.flight_left <= 0.0 and not shot.is_queued_for_deletion():
			fx.trail(shot.position - Vector2(0.0, shot.lift), shot.palette, shot.trail)
		if (shot.slow > 0.0 or shot.pull > 0.0) and shot.flight_left <= 0.0 and not shot.detonate and not shot.is_queued_for_deletion():
			for enemy: Node2D in grid.query(shot.position, shot.radius):
				if shot.slow > 0.0:
					enemy.slow(shot.slow, 0.3)
				if shot.pull > 0.0 and enemy.position.distance_to(shot.position) > 12.0:
					enemy.position = enemy.position.move_toward(shot.position, shot.pull * delta)
		if shot.detonate and not shot.is_queued_for_deletion():
			blast(shot.position, shot.blast_radius, shot.damage, shot.force, shot.palette)
			sfx.play(&"pop", 0.05)
			shot.queue_free()

## Instant area damage with ground ring and material-specific feedback. Lethal hits inside
## queue their own consequences.
func blast(at: Vector2, radius: float, damage: float, force: float, palette: StringName = &"blast", caption: String = "") -> void:
	var gas: bool = palette in [&"fart", &"stink"]
	if gas:
		fx.effect(&"gas", at - Vector2(0.0, 8.0), Vector2.ONE * radius * 2.6, 0.55, palette)
	elif palette in explosive_palettes:
		fx.effect(&"explosion", at - Vector2(0.0, 14.0), Vector2.ONE * radius * 2.6, 0.3, palette)
		fx.pop(at - Vector2(0.0, 14.0), palette, minf(radius * 0.2, 18.0), 0.055)
	else:
		fx.pop(at - Vector2(0.0, 10.0), palette, minf(radius * 0.25, 24.0), 0.09)
	fx.ring(at, radius * 0.45, radius, palette, 0.24, 1)
	fx.burst(at - Vector2(0.0, 10.0), palette, 6 if gas else 12, 35.0 if gas else 85.0)
	if caption != "":
		fx.caption(at - Vector2(0.0, 40.0), caption, palette)
	for enemy: Node2D in grid.query(at, radius):
		var heading: Vector2 = (enemy.position - at).normalized()
		enemy.hit(damage, heading if heading != Vector2.ZERO else Vector2.UP, force * 1.4)
	hit_props(at, radius, damage)

## Weapon damage to breakable street props; a broken prop scatters its loot.
func hit_props(at: Vector2, radius: float, damage: float) -> void:
	for prop: Node2D in map.breakables_in(at, radius):
		if prop.damage(damage):
			_break_prop(prop)

func _break_prop(prop: Node2D) -> void:
	var at: Vector2 = prop.global_position
	props_broken += 1
	sfx.play(&"chest" if prop.coins >= 3 else &"pop", 0.05)
	shake.add_trauma(0.12, 0.3)
	fx.ring(at - Vector2(0.0, 6.0), 6.0, prop.hit_radius + 18.0, &"gold", 0.3)
	fx.burst(at - Vector2(0.0, 12.0), &"gold", 10, 65.0)
	if prop.xp > 0.0:
		drop("xp", at, prop.xp)
	for i: int in prop.coins:
		drop("coin", at + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-10.0, 10.0)), 1.0)
	var roll: float = rng.randf()
	if roll < prop.food_chance:
		drop("food", at + Vector2(10, 6), 30.0)
	elif roll < prop.food_chance + prop.magnet_chance:
		drop("magnet", at + Vector2(10, 6), 1.0)
	map.remove_prop(prop)
	score_changed.emit()

func _resolve_bursts() -> void:
	var queued: Array = _bursts
	_bursts = []
	if queued.is_empty():
		return
	grid.rebuild(enemies.get_children().filter(func(e: Node2D) -> bool: return not e.dead and not e.is_queued_for_deletion()))
	for burst: Dictionary in queued:
		bursts_fired += 1
		sfx.play(&"fart", 0.05)
		shake.add_trauma(0.25, 0.5)
		blast(burst.at, burst.radius, burst.damage, 1.6, &"fart", "噗～")

func _step_pickups(delta: float) -> void:
	var radius: float = magnet_radius * (1.0 + build.stat(&"magnet"))
	for drop: Node2D in pickups.get_children():
		if drop.is_queued_for_deletion():
			continue
		var gap: float = drop.position.distance_to(player.position)
		if not drop.attracted and gap <= radius:
			drop.attracted = true
		if drop.attracted:
			drop.pull = minf(drop.pull + delta * 1600.0, 900.0)
			drop.position = drop.position.move_toward(player.position, drop.pull * delta)
			gap = drop.position.distance_to(player.position)
		if gap <= 18.0:
			_collect(drop)

func _collect(drop: Node2D) -> void:
	match drop.kind:
		"xp":
			build.award(drop.value)
			sfx.play(&"gem", 0.04)
			if drop == big_gem:
				big_gem = null
		"coin":
			coins += int(drop.value)
			sfx.play(&"coin", 0.05)
		"food":
			player.heal(drop.value)
			sfx.play(&"heal", 0.1)
		"magnet":
			for other: Node2D in pickups.get_children():
				if other.kind == "xp":
					other.attracted = true
			sfx.play(&"heal", 0.1)
		"chest":
			chests += 1
			# Like VS: one, three or five picks at 2/6, 3/6, 1/6; offers() lists ready evolutions first.
			var roll: float = rng.randf()
			build.pending_choices += 1 if roll < 2.0 / 6.0 else (3 if roll < 5.0 / 6.0 else 5)
			sfx.play(&"chest", 0.1)
			chest_opened.emit()
	drop.queue_free()
	score_changed.emit()

func drop(kind: String, at: Vector2, value: float) -> Node2D:
	if kind == "xp":
		var gems: int = 0
		for item: Node2D in pickups.get_children():
			if item.kind == "xp" and not item.is_queued_for_deletion():
				gems += 1
		if gems >= max_gems:
			if big_gem == null or big_gem.is_queued_for_deletion():
				big_gem = _make_drop("xp", at, value)
			else:
				big_gem.add_value(value)
			return big_gem
	return _make_drop(kind, at, value)

func _make_drop(kind: String, at: Vector2, value: float) -> Node2D:
	var item := pickup_scene.instantiate() as Node2D
	pickups.add_child(item)
	item.position = at.clamp(bounds.position, bounds.end)
	item.setup(kind, value)
	return item

func _separate_enemies(delta: float) -> void:
	for a: Node2D in enemies.get_children():
		if a.dead or a.is_queued_for_deletion() or a.phase in ["warning", "dash"]:
			continue
		for b: Node2D in grid.query(a.position, a.definition.radius * 1.3):
			if b == a or b.get_instance_id() < a.get_instance_id() or b.phase in ["warning", "dash"]:
				continue
			var offset: Vector2 = a.position - b.position
			var space: float = (a.definition.radius + b.definition.radius) * 0.65
			if offset.length() < space:
				var heading: Vector2 = offset.normalized() if offset != Vector2.ZERO else Vector2.RIGHT
				var push: Vector2 = heading * (space - offset.length()) * minf(1.0, delta * 5.0)
				var weight: float = a.definition.weight + b.definition.weight
				a.position = (a.position + push * b.definition.weight / weight).clamp(bounds.position, bounds.end)
				b.position = (b.position - push * a.definition.weight / weight).clamp(bounds.position, bounds.end)

## Roadblocks hold enemies back; they slide along the face toward the shorter way round the hero.
func _block_enemies(delta: float) -> void:
	for enemy: Node2D in enemies.get_children():
		if enemy.dead or enemy.is_queued_for_deletion():
			continue
		enemy.position = map.push_out(enemy.position, enemy.definition.radius * 0.6, player.position, enemy.definition.speed * delta * 0.8)

func _smoke(at: Vector2) -> void:
	if hazards.get_child_count() >= max_hazards:
		return
	var cloud := smoke_scene.instantiate() as Node2D
	cloud.position = at
	hazards.add_child(cloud)
	# The hazard owns its cloud and footprint, independently of cosmetic VFX budgets.
	smoke_spawns += 1

func _warning() -> void:
	warnings += 1
	sfx.play(&"warning", 0.25)

func _hurt(amount: float, source: String) -> void:
	if player.hurt_cooldown <= 0.0 and player.hp > 0.0 and arsenal.absorb():
		score_changed.emit()
		return
	var before: float = player.hp
	if player.hurt(amount):
		hits_taken += 1
		damage_taken += before - player.hp
		damage_sources[source] = float(damage_sources.get(source, 0.0)) + before - player.hp
		_number_at(player.position + Vector2(_fx_rng.randf_range(-8.0, 8.0), -110.0), before - player.hp, false, true)
		sfx.play(&"hurt", 0.15)
		player_hurt.emit()
		score_changed.emit()

func _impact(enemy: Node2D, lethal: bool, direction: Vector2) -> void:
	_show_number(enemy, lethal)
	var chest: Vector2 = enemy.position - Vector2(0.0, 20.0)
	if not lethal:
		fx.spark(chest, direction, &"hit")
		if punching:
			fx.star(chest, &"hit")
		sfx.play(&"metal" if enemy.definition.kind in ["bike", "car"] else &"hit", 0.05)
		shake.add_trauma(0.08, 0.3)
		return
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_left = 1.8
	_frame_kills += 1
	var milestone: bool = combo % 25 == 0
	if enemy.elite:
		_frame_big = true
	fx.pop(chest, &"heavy" if enemy.elite else &"hit", 22.0 if enemy.elite else 9.0, 0.1)
	fx.burst(chest, &"heavy" if enemy.elite else &"hit", 12 if enemy.elite else 5, 70.0)
	if enemy.elite or milestone or punching:
		fx.star(chest, &"heavy", true)
	if enemy.elite or milestone:
		fx.caption(chest - Vector2(0.0, 36.0), "飛出去！", &"heavy")
	if milestone:
		sfx.play(&"combo", 0.15)
	drop("xp", enemy.position, enemy.definition.experience * (10.0 if enemy.elite else 1.0))
	if enemy.elite:
		drop("chest", enemy.position + Vector2(0, 18), 1.0)
	else:
		var roll: float = rng.randf()
		if roll < magnet_chance:
			drop("magnet", enemy.position + Vector2(10, 8), 1.0)
		elif roll < magnet_chance + food_chance:
			drop("food", enemy.position + Vector2(10, 8), 30.0)
		elif roll < magnet_chance + food_chance + coin_chance:
			drop("coin", enemy.position + Vector2(10, 8), 1.0)
	if enemy.definition.burst_radius > 0.0:
		# Resolved at the start of the next step so a chain of farts never recurses inside hit().
		_bursts.append({"at": enemy.position, "radius": enemy.definition.burst_radius * (1.6 if enemy.elite else 1.0), "damage": enemy.definition.burst_damage})
	score_changed.emit()

func _show_number(enemy: Node2D, lethal: bool) -> void:
	_number_at(enemy.position + Vector2(_fx_rng.randf_range(-10.0, 10.0), -enemy.definition.radius - 46.0), enemy.last_damage, lethal)

func _number_at(at: Vector2, amount: float, lethal: bool, hurt: bool = false) -> void:
	if number_scene == null or numbers.get_child_count() >= max_numbers:
		return
	var label := number_scene.instantiate() as Node2D
	numbers.add_child(label)
	label.position = at
	label.setup(amount, lethal, hurt)

## One sound, one shake and at most one hit stop per frame, however many enemies flew.
## Hit stop is kept for elites and huge multi-kills; late-game swarms would otherwise freeze the screen.
@export var big_kill_count: int = 12

func _flush_feedback() -> void:
	if _frame_kills <= 0 and not _frame_big:
		return
	if _frame_kills > 0:
		sfx.play(&"launch", 0.06)
		shake.add_trauma(minf(0.15 + 0.03 * _frame_kills, 0.45), 0.5)
	if _frame_big or _frame_kills >= big_kill_count:
		shake.add_trauma(0.6, 0.8)
		time_control.hit_stop(0.06)
