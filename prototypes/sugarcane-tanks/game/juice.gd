extends Node
## Game feel in one place. Each juicy event is one function here that layers its feedback: a sound
## event name (game.sfx), camera trauma, a hit stop, particles, a squash on a sprite, HUD pops. The
## actors only report that something happened (game.juice.enemy_hit(...)); how loud it is comes from
## the tier the event is filed under.
##
## Feedback never touches the simulation: the camera shake moves Camera2D.offset and rotation only,
## squashes move a %Sprite's scale only and always return to its resting scale, and the hit stop goes
## through TimeControl (the only thing that changes Engine.time_scale).

enum Tier { SMALL, MEDIUM, LARGE }

const Pickup = preload("res://pickups/pickup.gd")

@export_group("Small")
@export_range(0.0, 1.0, 0.01) var small_trauma: float = 0.25
@export_range(0.0, 0.5, 0.005) var small_hit_stop: float = 0.0
@export_range(0.0, 4.0, 0.1) var small_particles: float = 0.6
@export_group("Medium")
@export_range(0.0, 1.0, 0.01) var medium_trauma: float = 0.45
@export_range(0.0, 0.5, 0.005) var medium_hit_stop: float = 0.045
@export_range(0.0, 4.0, 0.1) var medium_particles: float = 1.0
@export_group("Large")
@export_range(0.0, 1.0, 0.01) var large_trauma: float = 0.85
@export_range(0.0, 0.5, 0.005) var large_hit_stop: float = 0.14
@export_range(0.0, 4.0, 0.1) var large_particles: float = 2.2

@export_group("Screen shake")
## Accessibility: scales how far the camera moves. 0 = the camera never shakes.
@export_range(0.0, 1.0, 0.05) var shake_scale: float = 1.0
## Trauma lost per second. The shake itself is trauma squared, so it dies away faster than trauma does.
@export var decay: float = 1.5
## Events of one tier pile up to this many times one event's trauma, at most. So a stream of crits, or
## four red circles going off in the same frame, rumbles gently instead of shaking like a big hit; a
## bigger event on top still adds its own.
@export_range(1.0, 3.0, 0.05) var stack_limit: float = 1.4
## Camera offset (px) at full trauma, and the roll (rad) the camera turns at most. Roll only shows
## with Camera2D.ignore_rotation off, which main.tscn sets.
@export var max_offset: Vector2 = Vector2(40.0, 30.0)
@export_range(0.0, 0.1, 0.002) var max_roll: float = 0.02
## How fast the shake wobbles (Hz). Much above 10 it turns into a buzz on a 30 or 60 fps screen.
@export var frequency: float = 8.0
## Accessibility: scales the red edge flash and the white flash over the screen. 0 = no flashing at all.
@export_range(0.0, 1.0, 0.05) var flash_scale: float = 1.0

@export_group("Boss death")
## The boss's hit stop is the large tier's, this many times longer.
@export var boss_hit_stop_factor: float = 1.6
## Extra shakes after the first one, each weaker, spread over about half a second.
@export var boss_aftershocks: int = 3

var game: Node
## 0..1, added to by every shake and drained by `decay`. The camera shakes by trauma squared.
var trauma: float = 0.0

var _clock: float = 0.0
var _palettes: Dictionary = {}   # texture -> Gradient of colours picked out of it

func _ready() -> void:
	game = get_parent()

# --- tiers and shake -----------------------------------------------------------

func trauma_of(tier: Tier) -> float:
	return [small_trauma, medium_trauma, large_trauma][tier]

func hit_stop_of(tier: Tier) -> float:
	return [small_hit_stop, medium_hit_stop, large_hit_stop][tier]

func particles_of(tier: Tier) -> float:
	return [small_particles, medium_particles, large_particles][tier]

## Shakes add up, but one never pushes the trauma past its own `ceiling` (and never lowers it).
## Does nothing while shake_scale is 0.
func add_trauma(amount: float, ceiling: float = 1.0) -> void:
	if shake_scale <= 0.0:
		return
	trauma = maxf(trauma, minf(trauma + amount, ceiling))

## A tier's trauma and hit stop; either can be left out for events that should not use it.
func impact(tier: Tier, shake: bool = true, stop: bool = true) -> void:
	if shake:
		add_trauma(trauma_of(tier), minf(trauma_of(tier) * stack_limit, 1.0))
	if stop and hit_stop_of(tier) > 0.0:
		game.time_control.hit_stop(hit_stop_of(tier))

## Just the tier's shake, for events that have nothing else to say (a summon, a ring of bullets).
func shake(tier: Tier) -> void:
	impact(tier, true, false)

func sound(event: StringName, min_gap: float = 0.035) -> void:
	game.sfx.play(event, min_gap)

func _process(delta: float) -> void:
	if shake_scale <= 0.0:
		trauma = 0.0
	if trauma <= 0.0:
		return
	trauma = maxf(trauma - decay * delta, 0.0)
	_clock += delta
	var amount: float = trauma * trauma * shake_scale   # small hits barely move, big ones punch
	var camera: Camera2D = game.camera
	camera.offset = Vector2(max_offset.x * amount * _wave(0.0), max_offset.y * amount * _wave(11.0))
	camera.rotation = max_roll * amount * _wave(23.0)   # the last frame (trauma 0) puts both back to zero

## Smooth, not random: two sines at unrelated rates. A fresh randf() every frame would buzz.
func _wave(phase: float) -> float:
	var t: float = TAU * frequency * _clock
	return 0.62 * sin(t + phase) + 0.38 * sin(t * 1.55 + phase * 2.0)

# --- sprite helpers ------------------------------------------------------------

func _sprite_of(actor: Node) -> Node2D:
	return actor.get_node_or_null("%Sprite") as Node2D if actor != null else null

## Where the middle of the picture is (the sprite stands on its feet).
func _center_of(sprite: Sprite2D) -> Vector2:
	return sprite.global_position + Vector2(0.0, -sprite.texture.get_height() * 0.5 * absf(sprite.global_scale.y))

func _rest_scale(node: Node2D) -> Vector2:
	if not node.has_meta(&"rest_scale"):
		node.set_meta(&"rest_scale", node.scale)   # actors record it in _ready; this is the fallback
	return node.get_meta(&"rest_scale")

func _stop_tween(node: Node, key: StringName) -> void:
	if node.has_meta(key):
		var old: Tween = node.get_meta(key) as Tween
		if old != null and old.is_valid():
			old.kill()

## Squash/stretch: scale jumps to `factor` times the resting scale, then eases back past it and
## settles (TRANS_BACK by default). Another squash on the same node cancels the running one and starts
## from the resting scale again, so hits in a row never pile up.
func squash(node: Node2D, factor: Vector2, time: float = 0.2, trans: Tween.TransitionType = Tween.TRANS_BACK) -> void:
	if node == null or not is_instance_valid(node):
		return
	var rest: Vector2 = _rest_scale(node)
	_stop_tween(node, &"squash_tween")
	node.scale = rest * factor
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", rest, time).set_trans(trans).set_ease(Tween.EASE_OUT)
	node.set_meta(&"squash_tween", tween)

## Pops in from nothing with an overshoot.
func pop_in(node: Node2D, time: float = 0.32) -> void:
	var rest: Vector2 = _rest_scale(node)
	_stop_tween(node, &"squash_tween")
	node.scale = Vector2.ZERO
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", rest, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.set_meta(&"squash_tween", tween)

## A handful of colours picked out of a picture, for debris that looks like what broke. Cached.
func palette_of(texture: Texture2D) -> Gradient:
	if _palettes.has(texture):
		return _palettes[texture]
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT   # one flat colour per particle
	var image: Image = texture.get_image()
	var picker := RandomNumberGenerator.new()
	picker.seed = texture.get_width() * 7919 + texture.get_height()
	var colors := PackedColorArray()
	for attempt: int in 300:
		if colors.size() >= 8:
			break
		var pixel: Color = image.get_pixel(picker.randi_range(0, image.get_width() - 1), picker.randi_range(0, image.get_height() - 1))
		if pixel.a > 0.9 and pixel.get_luminance() > 0.12:   # not a hole, not the black outline
			colors.append(pixel)
	if colors.is_empty():
		colors.append(Color.WHITE)
	gradient.colors = colors
	var offsets := PackedFloat32Array()
	for i: int in colors.size():
		offsets.append(float(i) / float(colors.size()))
	gradient.offsets = offsets
	_palettes[texture] = gradient
	return gradient

# --- events: the hero ----------------------------------------------------------
# (the throw's own sound, `throw`, is played where the cane is created: main.throw_volley)

## The cane leaves the hand: a small stretch, no shake, a few sparks at the hand.
func hero_threw(hero: Node2D, hand: Vector2, direction: Vector2) -> void:
	squash(_sprite_of(hero), Vector2(0.93, 1.09), 0.16)
	game.spawn_spark(hand, direction, Color(1.0, 0.86, 0.5), particles_of(Tier.SMALL))

## Event `step`: a puff of dust at the feet, every so often while walking.
func hero_stepped(feet: Vector2) -> void:
	game.spawn_dust(feet, 1.0)
	sound(&"step", 0.12)

func hero_stopped(hero: Node2D) -> void:
	squash(_sprite_of(hero), Vector2(1.07, 0.93), 0.18)

## Event `hurt` (medium), or `crush` (large) when a tank ran the hero over.
func hero_hurt(crushed: bool) -> void:
	sound(&"crush" if crushed else &"hurt")
	impact(Tier.LARGE if crushed else Tier.MEDIUM)
	game.hud.hurt_flash((0.8 if crushed else 0.45) * flash_scale)

## Event `hero_die` (large).
func hero_died(at: Vector2) -> void:
	game.spawn_explosion(at, 1.2)
	sound(&"hero_die")
	impact(Tier.LARGE)

## A level gained (the upgrade panel and its `level` sound come at the end of the room): a ring of
## light around the hero. The HUD's LV and EXP bar pop by themselves (hud.set_level). Event `level_up`.
func level_gained(hero: Node2D) -> void:
	game.spawn_ring(hero.global_position + Vector2(0.0, -40.0))
	sound(&"level_up")

# --- events: enemies -----------------------------------------------------------

## Events `hit` and `crit`. The enemy squashes and springs back, pixel sparks fly from where the cane
## hit; a crit also gets a small shake (the damage number pops by itself).
func enemy_hit(enemy: Node2D, crit: bool, at: Vector2, direction: Vector2) -> void:
	sound(&"crit" if crit else &"hit")
	var weight: float = 0.5 if enemy.is_boss else 1.0
	squash(_sprite_of(enemy), Vector2(1.0 + (0.26 if crit else 0.16) * weight, 1.0 - (0.22 if crit else 0.13) * weight), 0.22)
	game.spawn_spark(at, direction, Color(1.0, 0.8, 0.3) if crit else Color(1.0, 0.95, 0.7), particles_of(Tier.SMALL) * (2.0 if crit else 1.0))
	if crit:
		impact(Tier.SMALL, true, false)

## Event `enemy_die` (medium: hit stop, debris in the picture's colours), or `boss_die` (large: a
## longer hit stop, a white flash over the screen, lots of debris, aftershocks).
func enemy_died(enemy: Node2D) -> void:
	var boss: bool = enemy.is_boss
	var sprite: Sprite2D = _sprite_of(enemy) as Sprite2D
	var center: Vector2 = _center_of(sprite) if sprite != null else enemy.global_position
	game.spawn_explosion(center, 1.8 if boss else 0.6)
	if sprite != null and sprite.texture != null:
		game.spawn_debris(center, palette_of(sprite.texture), particles_of(Tier.LARGE if boss else Tier.MEDIUM) * (2.0 if boss else 1.0))
	if boss:
		sound(&"boss_die")
		impact(Tier.LARGE, true, false)
		game.time_control.hit_stop(hit_stop_of(Tier.LARGE) * boss_hit_stop_factor, true)
		game.hud.white_flash(0.7 * flash_scale, 0.5)
		var aftershocks: Tween = create_tween().set_ignore_time_scale(true)
		for i: int in boss_aftershocks:
			aftershocks.tween_interval(0.16)
			aftershocks.tween_callback(add_trauma.bind(trauma_of(Tier.LARGE) * 0.5 / float(i + 1)))
	else:
		sound(&"enemy_die")
		impact(Tier.MEDIUM)

## Event `boss_intro` (medium): the boss bar fills from empty by itself (hud.show_boss).
func boss_appeared() -> void:
	sound(&"boss_intro")
	impact(Tier.MEDIUM, true, false)

## Event `rage`: a boss has just dropped below half HP and turns angrier. Sound only.
func boss_enraged() -> void:
	sound(&"rage")

## Dust behind a dashing tank.
func dash_dust(at: Vector2) -> void:
	game.spawn_dust(at, 0.8)

## Event `bump` (small): the dash ended against a wall.
func tank_bumped(at: Vector2) -> void:
	sound(&"bump")
	impact(Tier.SMALL, true, false)
	game.spawn_dust(at, 2.0)

## Event `aoe_blast`. Small if it missed the hero. If it hurt the hero, the hero's own hurt feedback
## (medium) is the shake, so the blast adds none.
func aoe_blasted(hero_was_hurt: bool) -> void:
	sound(&"aoe_blast")
	if not hero_was_hurt:
		impact(Tier.SMALL, true, false)

# --- events: pickups and doors ---------------------------------------------------

## Event `drop`: the pickup pops out with an overshoot (visual is its %Visual).
func pickup_dropped(visual: Node2D) -> void:
	pop_in(visual)
	sound(&"drop", 0.06)

## Events `pickup` (EXP gem), `coin`, `heal` (heart): a little flash where it was picked up (the HUD
## numbers pop by themselves when they go up).
func pickup_collected(kind: int, at: Vector2) -> void:
	match kind:
		Pickup.Kind.EXP:
			sound(&"pickup", 0.02)
			game.spawn_spark(at, Vector2.UP, Color(0.6, 0.9, 1.0), 0.6)
		Pickup.Kind.COIN:
			sound(&"coin", 0.02)
			game.spawn_spark(at, Vector2.UP, Color(1.0, 0.85, 0.3), 0.6)
		Pickup.Kind.HEART:
			sound(&"heal")
			game.spawn_spark(at, Vector2.UP, Color(1.0, 0.45, 0.5), 0.9)

## Small: a burst of gold at the doorway (the door's own sound, `door`, is played where it opens).
func door_opened(at: Vector2) -> void:
	game.spawn_gold_burst(at)
	impact(Tier.SMALL, true, false)
