extends Node
## Fires every owned weapon on its own cooldown. Street resolves hits, blasts and feedback.
@export var flash_scene: PackedScene
@export var max_projectiles: int = 90
var street: Node2D
var cooldowns: Dictionary = {}
var punches: int = 0
var fired: Dictionary = {}
## Hits the umbrella can still absorb.
var shield: int = 0

func reset() -> void:
	cooldowns.clear()
	fired.clear()
	punches = 0
	shield = 0

func step(delta: float) -> void:
	for id: StringName in street.build.weapons:
		var left: float = float(cooldowns.get(id, 0.0)) - delta
		if left <= 0.0:
			var stats: Dictionary = street.build.weapon_stats(id)
			if fire(stats):
				left = stats.cooldown
				fired[id] = int(fired.get(id, 0)) + 1
			else:
				left = 0.0
		cooldowns[id] = left

func fire(s: Dictionary) -> bool:
	match s.kind:
		&"punch":
			return _punch(s)
		&"wave":
			return _wave(s)
		&"kick":
			return _kick(s)
		&"slipper":
			return _slipper(s)
		&"pearl":
			return _pearl(s)
		&"firecracker":
			return _firecracker(s)
		&"incense":
			return _incense(s)
		&"lantern":
			return _lantern(s)
		&"cane":
			return _cane(s)
		&"tofu":
			return _tofu(s)
		&"umbrella":
			return _umbrella(s)
		&"ring":
			return _ring(s)
		&"rider":
			return _rider(s)
	return false

func _hero() -> CharacterBody2D:
	return street.player

func _aim(reach: float) -> Vector2:
	var target: Node2D = street.grid.nearest(_hero().position, reach)
	if target == null:
		return _hero().facing
	var toward: Vector2 = (target.position - _hero().position).normalized()
	return toward if toward != Vector2.ZERO else Vector2.UP

## Up to `count` distinct nearby enemies, nearest first.
func _targets(reach: float, count: int) -> Array:
	var found: Array = street.grid.query(_hero().position, reach)
	var at: Vector2 = _hero().position
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_squared_to(at) < b.position.distance_squared_to(at))
	return found.slice(0, count)

func _room() -> bool:
	return street.projectiles.get_child_count() < max_projectiles

func _spawn(s: Dictionary) -> Node2D:
	var shot := (s.projectile as PackedScene).instantiate() as Node2D
	shot.damage = s.damage
	shot.force = s.knockback * street.build_force()
	shot.lifetime = s.duration
	shot.pierce = s.pierce
	shot.bounds = street.bounds
	shot.radius *= s.area
	shot.scale = Vector2.ONE * s.area
	street.projectiles.add_child(shot)
	return shot

func _flash(mode: String, radius: float, heading: Vector2, at: Vector2 = Vector2.INF) -> void:
	if flash_scene == null or street.effects.get_child_count() >= street.max_effects:
		return
	var effect := flash_scene.instantiate() as Node2D
	street.effects.add_child(effect)
	effect.position = (_hero().position - Vector2(0, 20)) if at == Vector2.INF else at
	effect.setup(mode, radius, heading)

func _punch(s: Dictionary) -> bool:
	var reach: float = _hero().attack_range * s.area
	var target: Node2D = street.grid.nearest(_hero().position, reach)
	if target == null:
		return false
	var toward: Vector2 = (target.position - _hero().position).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.UP
	punches += 1
	var heavy: bool = s.variant == &"palm" or (s.special and punches % 3 == 0)
	var cone: float = 0.2 if s.variant == &"palm" else 0.5
	_hero().punch(toward, s.cooldown, heavy)
	street.sfx.play(&"punch")
	if heavy:
		street.sfx.play(&"heavy", 0.12)
	var targets: Array = [target]
	for enemy: Node2D in street.grid.query(_hero().position, reach):
		if targets.size() >= s.amount:
			break
		if enemy != target and (enemy.position - _hero().position).normalized().dot(toward) >= cone:
			targets.append(enemy)
	_flash("heavy" if heavy or s.variant == &"palm" else "sweep", reach, toward)
	var damage: float = s.damage * (1.8 if heavy else 1.0)
	street.punching = true
	for enemy: Node2D in targets:
		enemy.hit(damage, toward, s.knockback * street.build_force() * (1.5 if heavy else 1.0))
	street.punching = false
	return true

func _wave(s: Dictionary) -> bool:
	var heading: Vector2 = _aim(420.0)
	for i: int in s.amount:
		if not _room():
			break
		var shot := _spawn(s)
		var turn: float = TAU * i / s.amount if s.variant == &"duo" else (i - (s.amount - 1) * 0.5) * 0.22
		shot.velocity = heading.rotated(turn) * s.speed
		shot.launch(_hero().position)
	street.sfx.play(&"wave", 0.1)
	return true

func _kick(s: Dictionary) -> bool:
	var radius: float = 112.0 * s.area
	_flash("kick", radius, Vector2.RIGHT)
	street.sfx.play(&"kick", 0.12)
	for enemy: Node2D in street.grid.query(_hero().position, radius):
		var heading: Vector2 = (enemy.position - _hero().position).normalized()
		enemy.hit(s.damage, heading if heading != Vector2.ZERO else Vector2.UP, s.knockback * street.build_force() * 1.6)
	return true

func _slipper(s: Dictionary) -> bool:
	var targets: Array = _targets(380.0, s.amount)
	for i: int in s.amount:
		if not _room():
			break
		var heading: Vector2 = _hero().facing.rotated(TAU * i / s.amount)
		if i < targets.size():
			heading = (targets[i].position - _hero().position).normalized()
		var shot := _spawn(s)
		if s.variant == &"homing":
			shot.mode = "straight"
			shot.homing = true
			shot.rehit = 0.5
		else:
			shot.mode = "boomerang"
			shot.rehit = s.duration * 0.5
		shot.velocity = heading * s.speed
		shot.launch(_hero().position)
	street.sfx.play(&"throw", 0.08)
	return true

func _pearl(s: Dictionary) -> bool:
	var targets: Array = _targets(460.0, s.amount)
	if targets.is_empty():
		return false
	for i: int in s.amount:
		if not _room():
			break
		var target: Node2D = targets[i % targets.size()]
		var shot := _spawn(s)
		shot.bounce = true
		shot.velocity = (target.position - _hero().position).normalized().rotated((i / targets.size()) * 0.3) * s.speed
		shot.launch(_hero().position)
	street.sfx.play(&"pearl", 0.06)
	return true

func _firecracker(s: Dictionary) -> bool:
	if s.variant == &"rocket":
		for i: int in s.amount:
			if not _room():
				break
			var shot := _spawn(s)
			shot.blast_radius = 70.0 * s.area
			shot.velocity = Vector2.RIGHT.rotated(TAU * i / s.amount + street.rng.randf() * 0.3) * s.speed
			shot.launch(_hero().position)
		street.sfx.play(&"throw", 0.08)
		return true
	var targets: Array = _targets(340.0, s.amount)
	for i: int in s.amount:
		if not _room():
			break
		var shot := _spawn(s)
		shot.mode = "lob"
		shot.blast_radius = 58.0 * s.area
		shot.target_point = targets[i].position if i < targets.size() else _hero().position + Vector2.RIGHT.rotated(street.rng.randf() * TAU) * 160.0
		shot.launch(_hero().position)
	street.sfx.play(&"throw", 0.08)
	return true

func _incense(s: Dictionary) -> bool:
	var permanent: bool = s.variant == &"permanent"
	var existing: int = 0
	for shot: Node2D in street.projectiles.get_children():
		if shot.mode == "orbit" and not shot.is_queued_for_deletion():
			existing += 1
	if permanent and existing >= s.amount:
		return true
	if not permanent and existing > 0:
		return false
	if permanent:
		for shot: Node2D in street.projectiles.get_children():
			if shot.mode == "orbit":
				shot.queue_free()
	for i: int in s.amount:
		var shot := _spawn(s)
		shot.mode = "orbit"
		shot.face_travel = false
		shot.anchor = _hero()
		shot.rehit = 0.45
		shot.lifetime = INF if permanent else s.duration
		shot.orbit_radius = 82.0 * s.area
		shot.orbit_speed = s.speed / 100.0
		shot.scale = Vector2.ONE
		shot.orbit_angle = TAU * i / s.amount
		shot.launch(_hero().position)
		shot.step(0.0)
	street.sfx.play(&"incense", 0.2)
	return true

func _lantern(s: Dictionary) -> bool:
	var view: Rect2 = street.view_rect()
	var pool: Array = street.grid.query(view.get_center(), view.size.length() * 0.5).filter(func(e: Node2D) -> bool: return view.has_point(e.position))
	if pool.is_empty():
		return false
	for i: int in s.amount:
		if not _room():
			break
		var shot := _spawn(s)
		shot.mode = "fall"
		shot.blast_radius = 52.0 * s.area
		shot.target_point = pool[street.rng.randi_range(0, pool.size() - 1)].position
		shot.launch(shot.target_point)
		shot.step(0.0)
	street.sfx.play(&"lantern", 0.15)
	return true

func _cane(s: Dictionary) -> bool:
	var side: float = signf(_hero().facing.x) if absf(_hero().facing.x) > 0.05 else 1.0
	var width: float = 150.0 * s.area
	var height: float = 56.0 * s.area
	for i: int in s.amount:
		var direction: float = side if i % 2 == 0 else -side
		var center: Vector2 = _hero().position + Vector2(direction * (width * 0.5 + 10.0), -12.0)
		var zone := Rect2(center - Vector2(width, height) * 0.5, Vector2(width, height))
		_flash("cane", width, Vector2(direction, 0.0), center)
		for enemy: Node2D in street.grid.query(center, width * 0.5 + 10.0):
			if zone.grow(enemy.definition.radius).has_point(enemy.position):
				enemy.hit(s.damage, Vector2(direction, -0.2).normalized(), s.knockback * street.build_force())
	street.sfx.play(&"swish", 0.08)
	return true

## The densest of a few nearby enemies, so zones land where they catch the most.
func _crowd_center(reach: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_count: int = -1
	for enemy: Node2D in _targets(reach, 8):
		var crowd: int = street.grid.query(enemy.position, 70.0).size()
		if crowd > best_count:
			best_count = crowd
			best = enemy.position
	return best

func _zone(s: Dictionary, at: Vector2) -> Node2D:
	var zone := _spawn(s)
	zone.mode = "straight"
	zone.face_travel = false
	zone.velocity = Vector2.ZERO
	zone.rehit = 0.5
	zone.slow = s.slow
	zone.pull = s.pull
	if s.blast_on_end:
		zone.blast_radius = 80.0 * s.area
		zone.blast_on_end = true
	zone.launch(at)
	return zone

func _tofu(s: Dictionary) -> bool:
	for i: int in s.amount:
		if not _room():
			break
		var at: Vector2 = _crowd_center(320.0)
		if at == Vector2.INF:
			at = _hero().position + Vector2.RIGHT.rotated(street.rng.randf() * TAU) * 120.0
		_zone(s, at + Vector2.RIGHT.rotated(TAU * i / s.amount) * 30.0 * minf(i, 1.0))
	street.sfx.play(&"incense", 0.2)
	return true

func _ring(s: Dictionary) -> bool:
	var at: Vector2 = _crowd_center(380.0)
	if at == Vector2.INF:
		return false
	for i: int in s.amount:
		if not _room():
			break
		_zone(s, at + Vector2.RIGHT.rotated(TAU * i / s.amount) * 40.0 * minf(i, 1.0))
	street.sfx.play(&"throw", 0.08)
	return true

func _rider(s: Dictionary) -> bool:
	var heading: Vector2 = _aim(520.0)
	var side: Vector2 = heading.orthogonal()
	for i: int in s.amount:
		if not _room():
			break
		var shot := _spawn(s)
		shot.velocity = heading * s.speed
		if s.blast_on_end:
			shot.blast_radius = 60.0 * s.area
			shot.blast_on_end = true
		shot.launch(_hero().position - heading * 70.0 + side * (i - (s.amount - 1) * 0.5) * 70.0)
	street.sfx.play(&"heavy", 0.1)
	return true

## The umbrella recharges one absorbed hit per cooldown, up to `amount`.
## Full charges still spend the cooldown, so a hit taken while full waits a whole cooldown to come back.
func _umbrella(s: Dictionary) -> bool:
	if shield >= s.amount:
		return true
	shield += 1
	_hero().set_shield(shield)
	street.sfx.play(&"upgrade", 0.2)
	return true

## Called before the hero takes damage. A charged umbrella eats the hit and shoves everything nearby away.
func absorb() -> bool:
	if shield <= 0:
		return false
	var stats: Dictionary = {}
	for id: StringName in street.build.weapons:
		var candidate: Dictionary = street.build.weapon_stats(id)
		if candidate.kind == &"umbrella":
			stats = candidate
	if stats.is_empty():
		return false
	shield -= 1
	_hero().set_shield(shield)
	_hero().hurt_cooldown = _hero().hurt_interval
	street.blast(_hero().position, 110.0 * stats.area, stats.damage, stats.knockback, Color("9fd8ff"), "彈！")
	street.sfx.play(&"metal", 0.1)
	if stats.variant == &"counter":
		_hero().heal(6.0)
	return true
