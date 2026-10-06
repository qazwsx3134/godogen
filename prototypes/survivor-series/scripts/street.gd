extends Node2D
signal score_changed
signal player_hurt
signal experience_gained(amount: int)
const Shake = preload("res://addons/proto_kit/camera_shake.gd")
@export var enemy_scenes: Array[PackedScene] = []
@export var smoke_scene: PackedScene
@export var impact_scene: PackedScene
@export var wave_scene: PackedScene
@export var attack_flash_scene: PackedScene
@export var progression: Resource
@export var bounds := Rect2(45.0, 175.0, 450.0, 640.0)
@export var max_enemies: int = 22
@export var max_effects: int = 24
@export var max_waves: int = 12
@onready var player: CharacterBody2D = %Player
@onready var enemies: Node2D = %Enemies
@onready var hazards: Node2D = %Hazards
@onready var effects: Node2D = %Effects
@onready var projectiles: Node2D = %Projectiles
@onready var camera: Camera2D = %Camera
var time_control: Node
var sfx: Node
var shake = Shake.new()
var kills: int = 0
var hits_taken: int = 0
var punches: int = 0
var warnings: int = 0
var smoke_spawns: int = 0
var waves_fired: int = 0
var kicks: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_left: float = 0.0
var build: RefCounted
var spawn_left: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	shake.camera = camera
	shake.max_offset = Vector2(12.0, 8.0)
	shake.max_roll = 0.01
	rng.randomize()

func clear() -> void:
	for holder: Node2D in [enemies, hazards, effects, projectiles]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	shake.trauma = 0.0
	camera.offset = Vector2.ZERO
	camera.rotation = 0.0
	if time_control != null:
		time_control.reset()

func reset() -> void:
	clear()
	build = preload("res://scripts/run_build.gd").new(progression)
	player.reset()
	kills = 0
	hits_taken = 0
	punches = 0
	warnings = 0
	smoke_spawns = 0
	waves_fired = 0
	kicks = 0
	combo = 0
	best_combo = 0
	combo_left = 0.0
	spawn_left = 1.5
	# Three distinct editable scene instances introduce the test immediately.
	spawn_enemy(0, player.position + Vector2(0.0, -72.0))
	spawn_enemy(1, Vector2(80.0, 250.0))
	spawn_enemy(2, Vector2(430.0, 330.0))
	score_changed.emit()

func spawn_enemy(index: int, at: Vector2) -> Node2D:
	var enemy := enemy_scenes[index].instantiate() as Node2D
	enemies.add_child(enemy)
	enemy.position = at
	enemy.smoke_requested.connect(_smoke)
	enemy.warning_started.connect(_warning)
	enemy.impacted.connect(_impact)
	return enemy

func step(delta: float, direction: Vector2, elapsed: float) -> void:
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left <= 0.0:
		combo = 0
	player.step(delta, direction, bounds.grow(-18.0))
	shake.step(delta)
	spawn_left -= delta
	if spawn_left <= 0.0:
		spawn_left = maxf(0.7, 2.0 - elapsed * 0.012)
		if living_count() < max_enemies and enemies.get_child_count() < max_enemies + 12:
			var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), bounds.position.y)
			if rng.randf() > 0.5:
				at = Vector2(bounds.position.x if rng.randf() < 0.5 else bounds.end.x, rng.randf_range(bounds.position.y, bounds.end.y))
			spawn_enemy(rng.randi_range(0, 2), at)
	for enemy: Node2D in enemies.get_children():
		if enemy.is_queued_for_deletion():
			continue
		enemy.step(delta, player.position, bounds)
		if not enemy.dead and enemy.position.distance_to(player.position) < enemy.definition.radius + 15.0:
			_hurt()
	_separate_enemies(delta)
	for cloud: Node2D in hazards.get_children():
		cloud.step(delta)
		if not cloud.is_queued_for_deletion() and cloud.position.distance_to(player.position) < cloud.radius + 12.0:
			_hurt()
	for wave: Node2D in projectiles.get_children():
		if wave.is_queued_for_deletion():
			continue
		var before: Vector2 = wave.step(delta)
		for enemy: Node2D in enemies.get_children():
			if not enemy.is_queued_for_deletion() and wave.can_hit(enemy, before):
				wave.remember(enemy)
				enemy.hit(wave.damage, wave.direction, wave.force)
	if player.attack_cooldown <= 0.0:
		var target: Node2D = nearest_enemy()
		if target != null:
			var toward: Vector2 = (target.position - player.position).normalized()
			if toward == Vector2.ZERO:
				toward = Vector2.UP
			punches += 1
			var heavy: bool = build.count(&"heavy") > 0 and punches % 3 == 0
			player.punch(toward, build.interval(player.attack_interval), heavy)
			sfx.play(&"punch")
			if heavy:
				sfx.play(&"heavy", 0.12)
			var damage: float = build.damage(player.attack_damage) * (build.value(&"heavy") if heavy else 1.0)
			var targets: Array[Node2D] = [target]
			if build.count(&"sweep") > 0:
				for enemy: Node2D in enemies.get_children():
					if targets.size() >= 1 + build.count(&"sweep"):
						break
					var offset: Vector2 = enemy.position - player.position
					if not enemy.dead and not enemy.is_queued_for_deletion() and enemy != target and offset.length() <= build.reach(player.attack_range) + enemy.definition.radius and offset.normalized().dot(toward) >= 0.5:
						targets.append(enemy)
			_flash("heavy" if heavy else "sweep", build.reach(player.attack_range), toward)
			for enemy: Node2D in targets:
				enemy.hit(damage, toward, build.force() * (1.5 if heavy else 1.0))
			if build.count(&"wave") > 0 and punches % 2 == 0:
				_fire_wave(toward)
			if build.count(&"kick") > 0 and punches % 4 == 0:
				_roundhouse()

func living_count() -> int:
	var total: int = 0
	for enemy: Node2D in enemies.get_children():
		if not enemy.dead and not enemy.is_queued_for_deletion():
			total += 1
	return total

func nearest_enemy() -> Node2D:
	var nearest: Node2D
	var distance: float = INF
	for enemy: Node2D in enemies.get_children():
		if enemy.dead or enemy.is_queued_for_deletion():
			continue
		var gap: float = enemy.position.distance_to(player.position)
		var reach: float = build.reach(player.attack_range) if build != null else player.attack_range
		if gap <= reach + enemy.definition.radius and gap < distance:
			nearest = enemy
			distance = gap
	return nearest

func _flash(mode: String, radius: float, heading: Vector2) -> void:
	if attack_flash_scene == null or effects.get_child_count() >= max_effects:
		return
	var effect := attack_flash_scene.instantiate() as Node2D
	effects.add_child(effect)
	effect.position = player.position - Vector2(0, 20)
	effect.setup(mode, radius, heading)

func _fire_wave(heading: Vector2) -> void:
	if projectiles.get_child_count() >= max_waves:
		return
	var wave := wave_scene.instantiate() as Node2D
	projectiles.add_child(wave)
	wave.position = player.position
	wave.setup(heading, build.damage(player.attack_damage) * (build.value(&"wave") + build.value(&"wave_power")), build.force(), build.count(&"wave_power"))
	waves_fired += 1
	sfx.play(&"wave", 0.1)

func _roundhouse() -> void:
	var radius: float = 112.0 + build.value(&"kick_power")
	var damage: float = build.damage(player.attack_damage) * (build.value(&"kick") + 0.2 * build.count(&"kick_power"))
	kicks += 1
	_flash("kick", radius, Vector2.RIGHT)
	sfx.play(&"kick", 0.12)
	for enemy: Node2D in enemies.get_children():
		if not enemy.dead and not enemy.is_queued_for_deletion() and enemy.position.distance_to(player.position) <= radius + enemy.definition.radius:
			var heading: Vector2 = (enemy.position - player.position).normalized()
			enemy.hit(damage, heading if heading != Vector2.ZERO else Vector2.UP, build.force() * 1.6)

func _separate_enemies(delta: float) -> void:
	var crowd: Array[Node] = enemies.get_children()
	for i: int in crowd.size():
		var a = crowd[i]
		if a.dead or a.is_queued_for_deletion() or a.phase in ["warning", "dash"]:
			continue
		for j: int in range(i + 1, crowd.size()):
			var b = crowd[j]
			if b.dead or b.is_queued_for_deletion() or b.phase in ["warning", "dash"]:
				continue
			var offset: Vector2 = a.position - b.position
			var space: float = (a.definition.radius + b.definition.radius) * 0.65
			if offset.length() < space:
				var heading: Vector2 = offset.normalized() if offset != Vector2.ZERO else Vector2.RIGHT
				var push: Vector2 = heading * (space - offset.length()) * minf(1.0, delta * 5.0)
				var weight: float = a.definition.weight + b.definition.weight
				a.position = (a.position + push * b.definition.weight / weight).clamp(bounds.position, bounds.end)
				b.position = (b.position - push * a.definition.weight / weight).clamp(bounds.position, bounds.end)

func _smoke(at: Vector2) -> void:
	if hazards.get_child_count() >= 18:
		return
	var cloud := smoke_scene.instantiate() as Node2D
	hazards.add_child(cloud)
	cloud.position = at
	smoke_spawns += 1

func _warning() -> void:
	warnings += 1
	sfx.play(&"warning", 0.25)

func _hurt() -> void:
	if player.hurt():
		hits_taken += 1
		sfx.play(&"hurt", 0.15)
		player_hurt.emit()
		score_changed.emit()

func _impact(enemy: Node2D, lethal: bool, direction: Vector2) -> void:
	if effects.get_child_count() < max_effects:
		var effect := impact_scene.instantiate() as Node2D
		effects.add_child(effect)
		effect.position = enemy.position - Vector2(0.0, 20.0)
		effect.setup(lethal, direction)
	if lethal:
		kills += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		combo_left = 1.8
		if combo % 5 == 0:
			sfx.play(&"combo", 0.15)
		sfx.play(&"launch", 0.08)
		shake.add_trauma(0.65, 0.7)
		time_control.hit_stop(0.065)
		score_changed.emit()
		experience_gained.emit(enemy.definition.experience)
	else:
		sfx.play(&"metal" if enemy.definition.kind != "smoker" else &"hit")
		shake.add_trauma(0.16, 0.3)
		time_control.hit_stop(0.022)
