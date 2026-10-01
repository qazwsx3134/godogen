extends Node2D
## Runs one chapter: loads rooms in order, spawns projectiles and drops, and handles
## room clear → collect → level-up picks → (angel after a boss) → door → next room.
##
## Command-line (after `--`): --autoplay (bot plays and picks cards), --room=N, --seed=N,
## --give=front,multishot,... (start with these abilities, to try a build or record a later room).

const HeroStats = preload("res://domain/hero_stats.gd")
const Pickup = preload("res://pickups/pickup.gd")

enum State { FIGHT, REWARD, DOOR, TRANSITION, DEAD, WON }

@export var rooms: Array[PackedScene] = []
@export var abilities: Array[Resource] = []
@export var sugarcane_scene: PackedScene
@export var exp_gem_scene: PackedScene
@export var heart_scene: PackedScene
@export var coin_scene: PackedScene
@export var damage_number_scene: PackedScene
@export var explosion_scene: PackedScene
@export var spark_scene: PackedScene
@export var dust_scene: PackedScene
@export var debris_scene: PackedScene
@export var gold_burst_scene: PackedScene
@export var ring_scene: PackedScene
@export_range(0.0, 1.0, 0.05) var angel_heal_ratio: float = 0.4
@export_range(0.0, 1.0, 0.05) var heart_heal_ratio: float = 0.1
@export var sugarcane_speed: float = 1500.0

@onready var room_holder: Node2D = %RoomHolder
@onready var hero: CharacterBody2D = %Hero
@onready var shots: Node2D = %Shots
@onready var enemy_shots: Node2D = %EnemyShots
@onready var pickups: Node2D = %Pickups
@onready var effects: Node2D = %Effects
@onready var camera: Camera2D = %Camera
@onready var hud: Control = %Hud
@onready var choice_panel: Control = %ChoicePanel
@onready var result_panel: Control = %ResultPanel
@onready var time_control: Node = %TimeControl
@onready var sfx: Node = %Sfx
@onready var juice: Node = %Juice
@onready var music: Node = %Music

var stats: RefCounted
var room: Node2D
var room_index: int = 0
var state: State = State.FIGHT
var kills: int = 0
var coins: int = 0   # gold picked up this run only; a restart reloads the scene and starts over
var volleys_thrown: int = 0
var rng := RandomNumberGenerator.new()
var autoplay: bool = false
var auto_pick: bool = false
var _given: PackedStringArray = []

var _pending_levels: int = 0
var _boss: Node2D
var _area_name: String = ""
var _bot_move: Vector2 = Vector2.ZERO
var _bot_move_time: float = 0.0
var _bot_grid: AStarGrid2D
var _bot_grid_room: Node
var _bot_calm: float = 0.0   # after backing off from enemies it stands and throws for a while (cornered, it would only run)
var _bot_hidden: float = 0.0   # how long the nearest enemy has been out of sight

func _ready() -> void:
	rng.randomize()
	_parse_args()
	_ensure_input_actions()
	hero.died.connect(_on_hero_died)
	hud.pause_toggled.connect(func(paused: bool) -> void: get_tree().paused = paused)
	result_panel.restart_requested.connect(restart)
	stats = HeroStats.new()
	hero.setup(self, stats)
	for id: String in _given:
		for def: Resource in abilities:
			if def.id == StringName(id):
				_take_ability(def)
	_refresh_level()
	_refresh_hp()
	hud.set_coins(coins)
	_load_room(room_index)

func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			autoplay = true
			auto_pick = true
		elif arg.begins_with("--room="):
			room_index = clampi(int(arg.get_slice("=", 1)) - 1, 0, rooms.size() - 1)
		elif arg.begins_with("--give="):
			_given = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--seed="):
			rng.seed = int(arg.get_slice("=", 1))
			seed(rng.seed)

func _ensure_input_actions() -> void:
	var keys: Dictionary = {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)

# --- rooms -------------------------------------------------------------------

func _load_room(index: int) -> void:
	room_index = index
	for container: Node in [shots, enemy_shots, pickups, effects]:
		for child: Node in container.get_children():
			child.queue_free()
	for old: Node in room_holder.get_children():
		room_holder.remove_child(old)
		old.queue_free()
	room = rooms[index].instantiate() as Node2D
	room_holder.add_child(room)
	hero.global_position = room.player_start.global_position
	hero.velocity = Vector2.ZERO
	hero.active = true
	hud.set_room(index + 1, rooms.size())
	hud.hide_boss()
	_boss = null
	room.door().entered.connect(_on_door_entered)
	state = State.FIGHT
	room.activate(self, hero)
	music.play(music.boss_track if room.boss_room else music.room_track)
	if room.boss_room:
		hud.banner("BOSS 來了！")
	elif room.area_name != _area_name:
		hud.banner(room.area_name)
	_area_name = room.area_name
	if room.living_enemies().is_empty():
		_room_cleared()

func nearest_enemy(from: Vector2, exclude: Dictionary = {}, max_distance: float = INF) -> Node2D:
	if room == null:
		return null
	var best: Node2D = null
	var best_score: float = INF
	for enemy: Node2D in room.living_enemies():
		if exclude.has(enemy) or not enemy.targetable():
			continue
		var distance: float = from.distance_to(enemy.global_position)
		if distance > max_distance:
			continue
		# Archero prefers an enemy it can actually hit over a closer one behind a crate.
		var score: float = distance if _in_sight(from, enemy.global_position) else distance + 5000.0
		if score < best_score:
			best_score = score
			best = enemy
	return best

func _in_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _room_cleared() -> void:
	state = State.REWARD
	for bean: Node in enemy_shots.get_children():
		bean.queue_free()
	await get_tree().create_timer(0.45, false).timeout
	for pickup: Node in pickups.get_children():
		pickup.magnet(hero)
	var waited: float = 0.0
	while _live_children(pickups) > 0 and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _resolve_level_ups()
	if state != State.REWARD:
		return
	var last: bool = room_index >= rooms.size() - 1
	if room.boss_room and not last:
		await _angel()
	if last:
		_win()
		return
	room.door().open()
	sfx.play(&"door")
	juice.door_opened(room.door().global_position)
	hud.banner("門開了！往上走")
	state = State.DOOR

func _live_children(container: Node) -> int:
	var count: int = 0
	for child: Node in container.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count

func _on_door_entered() -> void:
	if state != State.DOOR:
		return
	state = State.TRANSITION
	hero.active = false
	sfx.play(&"door")
	await hud.fade_out()
	_load_room(room_index + 1)
	await hud.fade_in()

# --- rewards -----------------------------------------------------------------

func collect_pickup(pickup: Node) -> void:
	match pickup.kind:
		Pickup.Kind.EXP:
			var gained: int = stats.gain_exp(pickup.value)
			_pending_levels += gained
			_refresh_level()
			if gained > 0:
				juice.level_gained(hero)
		Pickup.Kind.HEART:
			stats.heal(int(round(stats.max_hp * heart_heal_ratio)))
			_refresh_hp()
		Pickup.Kind.COIN:
			coins += pickup.value
			hud.set_coins(coins)
	juice.pickup_collected(pickup.kind, pickup.global_position)

func _refresh_level() -> void:
	hud.set_level(stats.level, stats.experience, HeroStats.exp_to_next(stats.level))

## The hero's head bar and the HUD's HP bar both follow stats; call after any HP or max HP change.
func _refresh_hp() -> void:
	hero.refresh_hp()
	hud.set_hp(stats.hp, stats.max_hp)

func _resolve_level_ups() -> void:
	while _pending_levels > 0:
		_pending_levels -= 1
		var defs: Array = stats.draw_choices(abilities, rng)
		if defs.is_empty():
			continue
		sfx.play(&"level")
		var options: Array = []
		for def: Resource in defs:
			options.append(_ability_option(def))
		var index: int = await _choose("升級！", "選擇一項能力", options)
		_take_ability(defs[index])

func _angel() -> void:
	var defs: Array = stats.draw_choices(abilities, rng, 1)
	var options: Array = [{
		"title": "天使的祝福", "description": "回復 %d%% 生命" % int(angel_heal_ratio * 100.0),
		"color": Color(1.0, 0.92, 0.55),
	}]
	if not defs.is_empty():
		var gift: Dictionary = _ability_option(defs[0])
		gift["title"] = "天使的禮物：" + gift["title"]
		options.append(gift)
	var index: int = await _choose("天使降臨", "打倒 BOSS 的獎勵，選一個", options)
	if index == 0:
		stats.heal(int(round(stats.max_hp * angel_heal_ratio)))
		_refresh_hp()
	else:
		_take_ability(defs[0])

func _choose(title: String, subtitle: String, options: Array) -> int:
	get_tree().paused = true
	choice_panel.open(title, subtitle, options)
	if auto_pick:
		_auto_pick()
	var index: int = await choice_panel.chosen
	get_tree().paused = false
	return index

func _auto_pick() -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	var cards: Array[Node] = choice_panel.cards()
	if choice_panel.visible and not cards.is_empty():
		(cards[rng.randi_range(0, cards.size() - 1)] as Button).pressed.emit()

func _ability_option(def: Resource) -> Dictionary:
	var owned: int = stats.count(def.id)
	var stack: String = ""
	if def.max_stacks > 1 and def.max_stacks < 99:
		stack = "%d / %d" % [owned, def.max_stacks]
	return {"title": def.title, "description": def.description, "color": def.color, "icon": def.icon, "stack": stack}

func _take_ability(def: Resource) -> void:
	stats.add_ability(def.id)
	_refresh_hp()
	hud.set_ability(def, stats.count(def.id))

# --- end of run --------------------------------------------------------------

func _on_hero_died() -> void:
	state = State.DEAD
	music.stop()
	hero.active = false
	juice.hero_died(hero.global_position)
	# Deferred: the hero's last hit usually arrives inside a physics callback, where disabling bodies is not allowed.
	room.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	enemy_shots.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	await get_tree().create_timer(0.8).timeout
	result_panel.open("你倒下了", "抵達第 %d 間｜Lv %d｜擊倒 %d 隻敵人" % [room_index + 1, stats.level, kills], coins)

func _win() -> void:
	state = State.WON
	music.stop()
	hero.active = false
	var picked: int = 0
	for id: StringName in stats.stacks:
		picked += stats.count(id)
	result_panel.open("第一章 完成！", "Lv %d｜擊倒 %d 隻敵人｜拿到 %d 個能力" % [stats.level, kills, picked], coins)

func restart() -> void:
	get_tree().paused = false
	time_control.reset()
	get_tree().reload_current_scene()

# --- spawning, called by hero / enemies / projectiles -------------------------

func throw_volley(_thrower: Node2D, direction: Vector2) -> void:
	volleys_thrown += 1
	var origin: Vector2 = hero.throw_origin()
	# A hand that reaches past a fence or stair rail would start the cane on the other side of it (or inside it).
	if not get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(hero.global_position, origin, 1)).is_empty():
		origin = hero.global_position
	for shot: Dictionary in stats.volley_pattern():
		var shot_direction: Vector2 = direction.rotated(shot["angle"])
		var cane: Area2D = sugarcane_scene.instantiate() as Area2D
		cane.game = self
		cane.direction = shot_direction
		cane.speed = sugarcane_speed
		cane.damage = stats.projectile_damage()
		cane.crit_chance = stats.crit_chance()
		cane.pierce = stats.pierces()
		cane.ricochets = stats.ricochets()
		cane.bounces = stats.wall_bounces()
		cane.burn = stats.burns()
		cane.freeze = stats.freezes()
		cane.position = origin + shot_direction.orthogonal() * float(shot["offset"])
		shots.add_child(cane)
	sfx.play(&"throw")

func spawn_projectile(scene: PackedScene, at: Vector2, direction: Vector2, speed: float, damage: int) -> Area2D:
	var projectile: Area2D = scene.instantiate() as Area2D
	projectile.game = self
	projectile.direction = direction
	projectile.speed = speed
	projectile.damage = damage
	projectile.position = at
	enemy_shots.add_child(projectile)
	return projectile

## A summoned enemy appears on the floor: inside the arena's walk area, and walked toward the hero
## until it stands clear of walls and crates (the painted gardens and fences are not rectangles).
func spawn_enemy(scene: PackedScene, at: Vector2) -> void:
	var box: Rect2 = room.arena.walk_area.grow(-50.0)
	var spot: Vector2 = Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.y, box.position.y, box.end.y))
	for step: int in 12:
		if floor_free(spot, 34.0):
			break
		spot = spot.move_toward(hero.global_position, 40.0)
	room.add_enemy(scene.instantiate() as Node2D, spot, self, hero)

## True if a circle of `radius` at `p` fits on the floor: inside the walk area, clear of walls and crates.
func floor_free(p: Vector2, radius: float = 30.0) -> bool:
	if not room.arena.walk_area.grow(-radius).has_point(p):
		return false
	var probe := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	probe.shape = circle
	probe.transform = Transform2D(0.0, p)
	probe.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_shape(probe, 1).is_empty()

func spawn_explosion(at: Vector2, size: float = 1.0, tint: Color = Color.WHITE) -> void:
	var blast: Node2D = explosion_scene.instantiate() as Node2D
	blast.position = at
	blast.scale = Vector2.ONE * size
	blast.modulate = tint
	effects.add_child(blast)

func spawn_puff(at: Vector2, tint: Color) -> void:
	spawn_explosion(at, 0.3, tint)

## The one-shot pixel bursts (effects/burst.gd): the scene decides the look, these say where, how many
## (`count_scale` times the scene's amount), which way and in what colour.
func _burst(scene: PackedScene, at: Vector2, count_scale: float, tint: Color, direction: Vector2 = Vector2.ZERO, palette: Gradient = null) -> void:
	var burst: CPUParticles2D = scene.instantiate() as CPUParticles2D
	burst.position = at
	effects.add_child(burst)
	burst.fire(count_scale, tint, direction, palette)

func spawn_spark(at: Vector2, direction: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, count_scale: float = 1.0) -> void:
	_burst(spark_scene, at, count_scale, tint, direction)

func spawn_dust(at: Vector2, count_scale: float = 1.0) -> void:
	_burst(dust_scene, at, count_scale, Color.WHITE)

## Pieces in colours picked out of the picture that broke (see juice.palette_of).
func spawn_debris(at: Vector2, palette: Gradient, count_scale: float = 1.0) -> void:
	_burst(debris_scene, at, count_scale, Color.WHITE, Vector2.ZERO, palette)

func spawn_gold_burst(at: Vector2) -> void:
	_burst(gold_burst_scene, at, 1.0, Color.WHITE)

## The ring of light that goes out from the hero when a level is gained.
func spawn_ring(at: Vector2) -> void:
	var ring: Node2D = ring_scene.instantiate() as Node2D
	ring.position = at
	effects.add_child(ring)

func show_damage(at: Vector2, amount: int, crit: bool) -> void:
	var number: Node2D = damage_number_scene.instantiate() as Node2D
	number.position = at
	effects.add_child(number)
	number.setup(amount, crit)

## `at` is where the cane struck, `direction` the way it was flying.
func on_enemy_hit(enemy: Node2D, crit: bool, at: Vector2, direction: Vector2) -> void:
	juice.enemy_hit(enemy, crit, at, direction)

func on_hero_hurt(_amount: int, crushed: bool = false) -> void:
	hud.set_hp(stats.hp, stats.max_hp)   # hero.take_hit has already taken the damage
	juice.hero_hurt(crushed)

func on_enemy_killed(enemy: Node2D) -> void:
	kills += 1
	var boss: bool = enemy.is_boss
	juice.enemy_died(enemy)
	var remaining: int = enemy.exp_value
	while remaining > 0:
		var value: int = 5 if remaining >= 5 else 1
		remaining -= value
		var gem: Node2D = exp_gem_scene.instantiate() as Node2D
		gem.game = self
		gem.value = value
		if value > 1:
			gem.scale = Vector2(1.5, 1.5)
		pickups.add_child(gem)
		gem.drop(enemy.global_position)
	# Coins: 1 gold per EXP point (a boss drops double), as 5-gold coins plus singles like the gems.
	var gold: int = enemy.exp_value * (2 if boss else 1)
	while gold > 0:
		var worth: int = 5 if gold >= 5 else 1
		gold -= worth
		var coin: Node2D = coin_scene.instantiate() as Node2D
		coin.game = self
		coin.value = worth
		if worth > 1:
			coin.scale = Vector2(1.3, 1.3)
		pickups.add_child(coin)
		coin.drop(enemy.global_position)
	if rng.randf() < enemy.heart_drop_chance:
		var heart: Node2D = heart_scene.instantiate() as Node2D
		heart.game = self
		pickups.add_child(heart)
		heart.drop(enemy.global_position)
	if enemy == _boss:
		hud.hide_boss()
		_boss = null
	_check_clear.call_deferred()

func _check_clear() -> void:
	if state == State.FIGHT and room.living_enemies().is_empty():
		_room_cleared()

func register_boss(enemy: Node2D) -> void:
	_boss = enemy
	update_boss(enemy)
	juice.boss_appeared()

func update_boss(enemy: Node2D) -> void:
	hud.show_boss(enemy.display_name, maxi(enemy.hp, 0), enemy.max_hp, enemy.portrait)

# --- per frame ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if hero.dead or state == State.TRANSITION or state == State.WON:
		hero.move_input = Vector2.ZERO
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if hud.joystick.vector != Vector2.ZERO:
		input = hud.joystick.vector
	if autoplay:
		input = _bot_input(delta)
	hero.move_input = input

## Demo/test bot: stands still to throw, sidesteps beans and tank dash lines, walks out of
## red circles, backs off from rats and tanks that get close, walks to the door when it opens.
func _bot_input(delta: float) -> Vector2:
	var at: Vector2 = hero.global_position
	if state == State.DOOR:
		return _bot_door_step(at)
	if state != State.FIGHT:
		return Vector2.ZERO
	_bot_calm -= delta
	if _bot_move_time > 0.0:
		_bot_move_time -= delta
		return _bot_move
	for enemy: Node2D in room.living_enemies():
		if not enemy.has_method("dash_warning"):
			continue
		var warning: Array = enemy.dash_warning()
		if warning.is_empty():
			continue
		var origin: Vector2 = warning[0]
		var line: Vector2 = warning[1]
		var along: float = (at - origin).dot(line)
		var off_line: Vector2 = (at - origin) - line * along
		if along > -60.0 and along < float(warning[2]) + 60.0 and off_line.length() < 130.0:
			_bot_step(off_line if off_line.length() > 1.0 else line.orthogonal(), 0.4)
			return _bot_move
	if _bot_leave_circle():
		return _bot_move
	if _bot_dodge_bullets():
		return _bot_move
	for enemy: Node2D in room.living_enemies():
		if enemy.active and _bot_calm <= 0.0 and at.distance_to(enemy.global_position) < 170.0:
			_bot_step(at - enemy.global_position, 0.25)
			_bot_calm = 0.9
			return _bot_move
	# Nothing to dodge. A target hidden behind a garden, fence or crate (a chef keeps its distance) would never
	# come out, so after a moment the bot walks toward it until a throw can land.
	var target: Node2D = nearest_enemy(at)
	if target != null and not _in_sight(at, target.global_position):
		_bot_hidden += delta
		if _bot_hidden > 0.8:
			_bot_step(target.global_position - at, 0.3, 0.0)
			return _bot_move
	else:
		_bot_hidden = 0.0
	return Vector2.ZERO

## A step away from `direction`'s danger, pulled a little toward the middle of the room (`pull`), and turned
## aside if it would run into a wall or crate right away (the painted fences and gardens are not rectangles).
func _bot_step(direction: Vector2, duration: float, pull: float = 0.5) -> void:
	var toward_center: Vector2 = (Vector2(540, 1100) - hero.global_position).normalized()
	var wanted: Vector2 = (direction.normalized() + toward_center * pull).normalized()
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		if floor_free(hero.global_position + wanted.rotated(turn) * 110.0):
			wanted = wanted.rotated(turn)
			break
	_bot_move = wanted
	_bot_move_time = duration

## Walks to the door along an A* path over a 40 px grid of the floor (cells a hero fits in), built the first
## time it is needed in a room: the straight line to the door runs into crates, sandbags and the painted fences.
func _bot_door_step(at: Vector2) -> Vector2:
	var door_at: Vector2 = room.door().global_position
	if _bot_grid_room != room:
		_bot_grid_room = room
		_bot_grid = AStarGrid2D.new()
		_bot_grid.region = Rect2i(0, 0, 27, 48)
		_bot_grid.cell_size = Vector2(40, 40)
		_bot_grid.offset = Vector2(20, 20)
		_bot_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_bot_grid.update()
		for x: int in 27:
			for y: int in 48:
				_bot_grid.set_point_solid(Vector2i(x, y), not floor_free(Vector2(x * 40 + 20, y * 40 + 20)))
	var path: PackedVector2Array = _bot_grid.get_point_path(_bot_free_cell(at), _bot_free_cell(door_at))
	var target: Vector2 = path[1] if path.size() > 2 else door_at
	var to_target: Vector2 = target - at
	return to_target.normalized() if to_target.length() > 8.0 else Vector2.ZERO

## The grid cell nearest to `p` that a hero fits in.
func _bot_free_cell(p: Vector2) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var best_distance: float = INF
	for x: int in 27:
		for y: int in 48:
			var cell := Vector2i(x, y)
			var distance: float = Vector2(x * 40 + 20, y * 40 + 20).distance_squared_to(p)
			if distance < best_distance and not _bot_grid.is_point_solid(cell):
				best = cell
				best_distance = distance
	return best

## Weighs standing still and eight steps by where the bullets near the hero will be over the next half second
## (each flies straight on at its speed) and takes the least dangerous. False when standing still is safe.
func _bot_dodge_bullets() -> bool:
	var at: Vector2 = hero.global_position
	var bullets: Array[Node2D] = []
	for threat: Node in enemy_shots.get_children():
		if not threat.has_method(&"is_aoe") and (threat as Node2D).global_position.distance_to(at) < 450.0:
			bullets.append(threat as Node2D)
	if bullets.is_empty():
		return false
	var best: Vector2 = Vector2.ZERO
	var best_cost: float = INF
	var stay_cost: float = 0.0
	for i: int in 9:
		var dir: Vector2 = Vector2.ZERO if i == 0 else Vector2.from_angle(TAU * (i - 1) / 8.0)
		var cost: float = 0.0
		for step: int in range(1, 7):
			var t: float = step * 0.08
			var me: Vector2 = at + dir * hero.move_speed * t
			for bullet: Node2D in bullets:
				var gap: float = (bullet.global_position + (bullet.direction as Vector2) * float(bullet.speed) * t).distance_to(me)
				cost += maxf(0.0, 75.0 - gap)
		if i == 0:
			stay_cost = cost
		else:
			cost += 10.0 + (0.0 if floor_free(at + dir * 120.0) else 5000.0)
		if cost < best_cost:
			best_cost = cost
			best = dir
	if stay_cost < 1.0 or best == Vector2.ZERO:
		return false
	_bot_move = best
	_bot_move_time = 0.2
	return true

## Stepping out of a red circle it stands in: of 16 directions, the one that leaves the circle
## soonest and still ends on the floor. Ties (a circle centred on the bot) go toward the room centre.
## Short steps, so it looks again every 0.15 s.
func _bot_leave_circle() -> bool:
	var at: Vector2 = hero.global_position
	for circle: Node in enemy_shots.get_children():
		if not circle.has_method(&"is_aoe") or not circle.is_aoe():
			continue
		var rel: Vector2 = at - (circle as Node2D).global_position
		var reach: float = circle.radius + 50.0
		if rel.length() >= reach:
			continue
		var to_center: Vector2 = (Vector2(540, 1100) - at).normalized()
		var best_score: float = INF
		_bot_move = to_center
		for i: int in 16:
			var dir: Vector2 = Vector2.from_angle(TAU * i / 16.0)
			var b: float = rel.dot(dir)
			var travel: float = -b + sqrt(b * b - rel.length_squared() + reach * reach)
			var score: float = travel - 40.0 * dir.dot(to_center)
			if score < best_score and floor_free(at + dir * travel):
				best_score = score
				_bot_move = dir
		_bot_move_time = 0.15
		return true
	return false
