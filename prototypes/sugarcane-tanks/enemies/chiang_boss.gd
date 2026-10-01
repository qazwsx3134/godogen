extends "res://enemies/enemy.gd"
## Final boss: moves around the upper half of the room and fires bullet patterns to dodge.
## Each pattern is announced by a short flash. Below half HP he is angry (see _enter_rage): bullets get
## faster and bounce off walls and crates, rests shorter, and the red circles come in greater number and
## fill faster. The circles are the first pattern.
##   aoe    — red circles on the floor, one under the hero, that blow up after a moment
##   aimed  — three 3-way bursts at the hero
##   fan    — two wide fans, the second offset so there are gaps to slip through
##   spiral — two arms rotating for a few seconds
##   ring   — a full circle

enum Pattern { AOE, AIMED, FAN, SPIRAL, RING }

@export var bullet_scene: PackedScene
@export var bullet_speed: float = 420.0
@export var bullet_damage: int = 70
@export var rest_time: float = 1.1
@export var telegraph_time: float = 0.45
@export var roam_area: Rect2 = Rect2(200, 380, 680, 280)
@export_group("Red circles")
@export var aoe_scene: PackedScene
@export var aoe_count: int = 4
@export var aoe_count_enraged: int = 6
## How long a circle takes to fill before it blows up. Shorter below half HP.
@export var aoe_telegraph_time: float = 1.5
@export var aoe_telegraph_time_enraged: float = 1.0
## Where the random circles may be centred: the floor (x 60–1020, y 260–1760) inset by one radius, so they stay on it.
@export var aoe_area: Rect2 = Rect2(190, 390, 700, 1240)
## Centre-to-centre distance between circles, in circle radii, so they do not pile up.
@export var aoe_spacing: float = 1.5
@export_group("Rage (below half HP)")
## A bullet fired in rage bounces off a wall or crate this many times before it dies. 0 = no bounce.
@export var rage_bounces: int = 2
## A bullet that has bounced fades out this many seconds after its first bounce (0 = it flies on until it hits something).
@export var rage_bounce_life: float = 1.5
## Rests run this many times faster in rage (1 = as before the rage).
@export var rage_rest_speed: float = 1.6
## Tint of the bullets that bounce, so they can be told from the plain ones.
@export var rage_bullet_tint: Color = Color(1.0, 0.5, 0.4)
## The body pulses between these two tints while he is angry.
@export var rage_tint_high: Color = Color(1.0, 0.45, 0.4)
@export var rage_tint_low: Color = Color(1.0, 0.72, 0.66)

## True from the moment his HP first drops below half.
var raging: bool = false

var _pattern_index: int = 0
var _busy: bool = false
var _rest: float = 1.2
var _roam_target: Vector2 = Vector2.ZERO

@onready var _gun_arm: Node2D = %GunArm
@onready var _steam: CPUParticles2D = %RageSteam
@onready var _mark: Node2D = %RageMark

func enraged() -> bool:
	return hp * 2 < max_hp

## The moment he gets angry: a flash and a shake, a banner, the anger mark pops up over his head and steam
## starts to rise; the body then settles into a slow red pulse for the rest of the fight. (The sound is the
## `rage` event enemy.gd plays on the hit that takes him below half HP.)
func _enter_rage() -> void:
	raging = true
	game.hud.banner("%s 生氣了！" % display_name)
	game.juice.shake(game.juice.Tier.MEDIUM)
	_steam.emitting = true
	_mark.visible = true
	_mark.scale = Vector2.ZERO
	create_tween().tween_property(_mark, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sprite.modulate = Color(3.0, 0.7, 0.55)
	var flash: Tween = create_tween()
	flash.tween_property(sprite, "modulate", rage_tint_high, 0.4)
	flash.tween_callback(_pulse)

func _pulse() -> void:
	var body: Tween = create_tween().set_loops()
	body.tween_property(sprite, "modulate", rage_tint_low, 0.5).set_trans(Tween.TRANS_SINE)
	body.tween_property(sprite, "modulate", rage_tint_high, 0.5).set_trans(Tween.TRANS_SINE)
	var mark: Tween = create_tween().set_loops()
	mark.tween_property(_mark, "scale", Vector2(1.2, 1.2), 0.5).set_trans(Tween.TRANS_SINE)
	mark.tween_property(_mark, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)

## The body (art faces right) turns to the hero's side and the pistol follows the hero. Aimed left the
## pistol would hang upside down, so it is mirrored (scale.y = -1); it also changes sides with the body.
func _aim_gun(delta: float) -> void:
	_gun_arm.position.x = absf(_gun_arm.position.x) * signf(body_pivot.scale.x)
	var aim: float = (target.global_position - _gun_arm.global_position).angle()
	_gun_arm.rotation = lerp_angle(_gun_arm.rotation, aim, clampf(10.0 * delta, 0.0, 1.0))
	_gun_arm.scale.y = -1.0 if cos(_gun_arm.rotation) < 0.0 else 1.0

func think(delta: float) -> void:
	if not raging and enraged():
		_enter_rage()
	face_toward(to_target())
	_aim_gun(delta)
	if _busy:
		drive(Vector2.ZERO, delta)
		return
	if _roam_target == Vector2.ZERO or global_position.distance_to(_roam_target) < 20.0:
		_roam_target = roam_area.position + Vector2(randf() * roam_area.size.x, randf() * roam_area.size.y)
	drive((_roam_target - global_position).normalized(), delta)
	_rest -= delta * (rage_rest_speed if enraged() else 1.0) * slow_factor()
	if _rest <= 0.0:
		_run_pattern(_pattern_index % Pattern.size())
		_pattern_index += 1

func _speed() -> float:
	return bullet_speed * (1.2 if enraged() else 1.0)

func _fire(angle: float) -> void:
	var bullet: Area2D = game.spawn_projectile(bullet_scene, muzzle.global_position, Vector2.from_angle(angle), _speed(), bullet_damage)
	if enraged():
		bullet.bounces = rage_bounces
		bullet.bounce_life = rage_bounce_life
		bullet.modulate = rage_bullet_tint

func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds, false).timeout
	return not dead and active

## Drops the circles all at once and does not wait for them: the first sits on the hero, the rest
## at random spots on the floor that keep `aoe_spacing` radii from the ones already placed.
func _drop_circles() -> void:
	var fast: bool = enraged()
	var taken: Array[Vector2] = []
	for i: int in (aoe_count_enraged if fast else aoe_count):
		var circle: Node2D = aoe_scene.instantiate() as Node2D
		var spot: Vector2 = target.global_position if i == 0 else _random_spot(taken, circle.radius * aoe_spacing)
		taken.append(spot)
		circle.game = game
		circle.telegraph_time = aoe_telegraph_time_enraged if fast else aoe_telegraph_time
		circle.position = spot
		game.enemy_shots.add_child(circle)

func _random_spot(taken: Array[Vector2], gap: float) -> Vector2:
	var spot := Vector2.ZERO
	for attempt: int in 30:
		spot = aoe_area.position + Vector2(randf(), randf()) * aoe_area.size
		if taken.all(func(other: Vector2) -> bool: return spot.distance_to(other) >= gap):
			break
	return spot   # ponytail: 30 misses in a cramped area keep the last try (some overlap) instead of looping

func _run_pattern(pattern: int) -> void:
	_busy = true
	var flash: Tween = create_tween()
	flash.tween_property(body_pivot, "modulate", Color(1.8, 1.5, 1.0), telegraph_time * 0.5)
	flash.tween_property(body_pivot, "modulate", Color.WHITE, telegraph_time * 0.5)
	var gun_flash: Tween = create_tween()   # the gun arm is not under %Body, so it needs its own
	gun_flash.tween_property(_gun_arm, "modulate", Color(1.8, 1.5, 1.0), telegraph_time * 0.5)
	gun_flash.tween_property(_gun_arm, "modulate", Color.WHITE, telegraph_time * 0.5)
	if not await _wait(telegraph_time):
		return
	match pattern:
		Pattern.AOE:
			_drop_circles()
			game.sfx.play(&"toss")
		Pattern.AIMED:
			for burst: int in 3:
				var aim: float = (target.global_position - muzzle.global_position).angle()
				for offset: float in [-0.17, 0.0, 0.17]:
					_fire(aim + offset)
				game.sfx.play(&"gun")
				if not await _wait(0.28):
					return
		Pattern.FAN:
			var count: int = 13
			for wave: int in 2:
				var aim: float = (target.global_position - muzzle.global_position).angle()
				var half_step: float = deg_to_rad(140.0) / (count - 1) * 0.5 * wave
				for i: int in count:
					_fire(aim - deg_to_rad(70.0) + deg_to_rad(140.0) * i / (count - 1) + half_step)
				game.sfx.play(&"gun")
				if not await _wait(0.5):
					return
		Pattern.SPIRAL:
			var angle: float = randf() * TAU
			for step: int in 28:
				_fire(angle)
				_fire(angle + PI)
				angle += deg_to_rad(17.0)
				if step % 4 == 0:
					game.sfx.play(&"gun")
				if not await _wait(0.085):
					return
		Pattern.RING:
			var count: int = 24 + (8 if enraged() else 0)
			var start: float = randf() * TAU
			for i: int in count:
				_fire(start + TAU * i / count)
			game.sfx.play(&"gun")
			game.juice.shake(game.juice.Tier.SMALL)
	_rest = rest_time
	_busy = false
