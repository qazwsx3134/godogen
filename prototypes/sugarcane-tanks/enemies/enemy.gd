extends CharacterBody2D
## Shared enemy body: HP, contact damage, burn and freeze, spawn-in fade, knockback.
## Enemies sit in the room scene dormant; the room calls activate() when the fight starts.
## Optional nodes: %Body holds the sprite (art faces right) and is flipped to face left or right,
## %Muzzle is where it throws from.

## The sprite flips only when the move is at least this sideways (share of the direction's length),
## so near-vertical movement keeps the current side instead of flickering.
const FACE_SIDE_RATIO: float = 0.4

@export var display_name: String = "敵人"
@export var max_hp: int = 100
@export var move_speed: float = 120.0
@export var contact_damage: int = 40
@export var exp_value: int = 2
@export var body_faces_motion: bool = true
@export var knockback: float = 60.0
@export var heart_drop_chance: float = 0.06
@export var is_boss: bool = false
@export var spawn_delay: float = 0.6
## Picture the HUD's boss bar shows (bosses only).
@export var portrait: Texture2D
## After dying the body lies flattened for a moment, then shrinks away and is freed. Bosses take twice as long.
@export var corpse_time: float = 0.45

var game: Node
var target: Node2D
var hp: int = 0
var active: bool = false
var dead: bool = false

var _rage_announced: bool = false
var _burn_time: float = 0.0
var _burn_tick: float = 0.0
var _burn_damage: int = 0
var _slow_time: float = 0.0
var _contact_cooldown: float = 0.0
var _flash_tween: Tween
var _detour_time: float = 0.0
var _detour_direction: Vector2 = Vector2.ZERO

@onready var body_pivot: Node2D = get_node_or_null("%Body")
@onready var muzzle: Marker2D = get_node_or_null("%Muzzle")
@onready var sprite: Sprite2D = get_node_or_null("%Sprite") as Sprite2D
@onready var hp_bar: ProgressBar = %HpBar
@onready var contact_area: Area2D = %ContactArea

func _ready() -> void:
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if sprite != null:
		sprite.set_meta(&"rest_scale", sprite.scale)   # squashes (game/juice.gd) always return to this

## Where the soles are on the floor (the picture stands on its feet, so that is %Sprite's position).
func feet() -> Vector2:
	return global_position + Vector2(0.0, sprite.position.y if sprite != null else 0.0)

func activate(game_ref: Node, hero: Node2D, hp_scale: float = 1.0) -> void:
	game = game_ref
	target = hero
	max_hp = int(round(max_hp * hp_scale))
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.visible = not is_boss
	modulate.a = 0.0
	var base_scale: Vector2 = scale
	scale = base_scale * 0.6
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, spawn_delay * 0.7)
	tween.tween_property(self, "scale", base_scale, spawn_delay * 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_interval(spawn_delay * 0.3)
	tween.chain().tween_callback(func() -> void: active = true)
	if is_boss:
		game.register_boss(self)

## Can be aimed at as soon as it has faded in a little.
func targetable() -> bool:
	return not dead and modulate.a > 0.3

func slow_factor() -> float:
	return 0.45 if _slow_time > 0.0 else 1.0

func _physics_process(delta: float) -> void:
	if not active or dead:
		return
	_contact_cooldown -= delta
	_slow_time = maxf(0.0, _slow_time - delta)
	_tick_burn(delta)
	if dead:
		return
	think(delta)
	for body: Node2D in contact_area.get_overlapping_bodies():
		if body == target and _contact_cooldown <= 0.0:
			target.take_hit(current_contact_damage(), is_crushing())
			_contact_cooldown = 0.8

## Per-type behaviour. Subclasses override.
func think(_delta: float) -> void:
	pass

func current_contact_damage() -> int:
	return contact_damage

## True while a hit from this enemy should flatten the hero (a dashing tank).
func is_crushing() -> bool:
	return false

func to_target() -> Vector2:
	return target.global_position - global_position

## Moves toward `direction`. When blocked head-on by a crate or wall it detours sideways for a moment.
func drive(direction: Vector2, delta: float, speed_scale: float = 1.0) -> void:
	if _detour_time > 0.0:
		_detour_time -= delta
		direction = (_detour_direction + direction * 0.3).normalized()
	var wanted: Vector2 = direction * move_speed * speed_scale * slow_factor()
	velocity = wanted
	move_and_slide()
	if _detour_time <= 0.0 and wanted.length() > 1.0 and get_real_velocity().length() < wanted.length() * 0.3:
		_detour_time = 0.7
		_detour_direction = direction.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
	if body_faces_motion and velocity.length() > 5.0:
		face_toward(velocity)

## Flips %Body to the side `direction` points to. Too vertical a direction changes nothing.
func face_toward(direction: Vector2) -> void:
	if body_pivot != null and absf(direction.x) > FACE_SIDE_RATIO * direction.length():
		body_pivot.scale.x = signf(direction.x) * absf(body_pivot.scale.x)

func throw_projectile(scene: PackedScene, angle_offset: float, speed: float, damage: int) -> void:
	var from: Vector2 = muzzle.global_position if muzzle != null else global_position
	var direction: Vector2 = (target.global_position - from).normalized().rotated(angle_offset)
	game.spawn_projectile(scene, from, direction, speed, damage)

## `push` is the way the hit was flying; `hit_at` is where it struck (the body's middle if not given).
func take_hit(amount: float, crit: bool = false, burn: bool = false, freeze: bool = false, push: Vector2 = Vector2.ZERO, hit_at: Vector2 = Vector2.INF) -> void:
	if dead:
		return
	var damage: int = maxi(1, int(round(amount)))
	hp -= damage
	game.show_damage(global_position + Vector2(0, -40), damage, crit)
	game.on_enemy_hit(self, crit, hit_at if hit_at != Vector2.INF else global_position, push)
	_flash()
	if burn:
		_burn_time = 2.0
		_burn_damage = maxi(1, int(round(amount * 0.12)))
	if freeze:
		_slow_time = 1.5
	if knockback > 0.0 and push != Vector2.ZERO:
		velocity = push * knockback
		move_and_slide()
	_refresh_bar()
	if hp <= 0:
		die()

func _tick_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		hp -= _burn_damage
		game.show_damage(global_position + Vector2(0, -40), _burn_damage, false)
		_refresh_bar()
		if hp <= 0:
			die()

## Bosses with a second phase say so here (below half HP). The first hit that makes this true plays `rage`.
func enraged() -> bool:
	return false

func _refresh_bar() -> void:
	hp_bar.value = maxi(hp, 0)
	if is_boss:
		game.update_boss(self)
		if hp > 0 and not _rage_announced and enraged():
			_rage_announced = true
			game.juice.boss_enraged()

func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	var frozen: bool = _slow_time > 0.0
	modulate = Color(0.6, 0.85, 1.6) if frozen else Color(2.2, 2.2, 2.2)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color(0.75, 0.9, 1.3) if frozen else Color.WHITE, 0.12)

func die() -> void:
	if dead:
		return
	dead = true
	active = false
	# The body is out of the fight at once: nothing can hit it, it blocks nobody, it hurts nobody
	# (deferred: this can run inside a physics callback).
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	contact_area.set_deferred("monitoring", false)
	hp_bar.visible = false
	game.on_enemy_killed(self)
	_lie_down_and_vanish()

## Flashes white, flattens, then shrinks and fades away before it is freed, instead of popping out of
## existence. Only the picture and the fade change; the simulation is already done with this enemy.
func _lie_down_and_vanish() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	var time: float = corpse_time * (2.0 if is_boss else 1.0)
	modulate = Color(2.0, 2.0, 2.0, 1.0)
	var fade: Tween = create_tween().set_parallel()
	fade.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), time * 0.8).set_delay(time * 0.2).set_ease(Tween.EASE_IN)
	if sprite == null:
		fade.chain().tween_callback(queue_free)
		return
	if sprite.has_meta(&"squash_tween"):
		var old: Tween = sprite.get_meta(&"squash_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	var rest: Vector2 = sprite.get_meta(&"rest_scale", sprite.scale)
	var shrink: Tween = sprite.create_tween()
	shrink.tween_property(sprite, "scale", rest * Vector2(1.4, 0.2), time * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	shrink.tween_property(sprite, "scale", rest * Vector2(0.15, 0.03), time * 0.7).set_ease(Tween.EASE_IN)
	shrink.tween_callback(queue_free)
