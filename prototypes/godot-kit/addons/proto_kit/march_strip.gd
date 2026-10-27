extends Control
## An idle side-scroller strip (Taskbar Hero style, the 行軍 view of an idle RPG): the party walks right through the
## region (the far picture, the props and the ground scroll at their own rates), meets a monster, stops and fights it
## on its own (damage numbers, the monster's HP bar), the monster falls and they walk on. It only shows the idle
## loop: what the march pays is the game's business (fell() is where it says so). Its own random numbers
## (rng_seed), so the game's randf() is never touched; it runs only while visible, and step(dt) drives it in tests.
##   extends "res://addons/proto_kit/march_strip.gd"     # the game's view: looks, damage, texts
##
## Scene (unique names; march_view.tscn in hero-horde-idle is a full example):
##   %Far     TextureRect, parallax_layer.gdshader material (tex = the far picture, mirror on), full rect
##   %Props   Control of TextureRects (trees, rocks) that drift left at prop_rate and wrap around
##   %Ground  TextureRect, parallax_layer.gdshader material (tex = the ground strip)
##   %Heroes  Control of the party's TextureRects, front one rightmost; hidden ones do not count
##   %Enemy   TextureRect of the monster, positioned in the same band as the heroes
##   %EnemyHp ProgressBar over the monster
##   %Popups  Control holding a few Labels reused for damage and reward numbers
## Hooks for the subclass (all optional): _damage_base() (the hit size; a kill takes hits_to_kill of them),
## _show_frames() (animate the party: `walking`, `_t`), fell() (a monster fell: count it, pop the reward).

signal enemy_spawned
signal hit(damage: float, crit: bool)
signal enemy_fell

## Pixels per second the world moves while the party walks; the far picture and the props move slower.
@export var walk_speed: float = 70.0
@export var far_rate: float = 0.15
@export var prop_rate: float = 0.55
## The ground layer's texture width in px and its on-screen scale: its offset advances one tile per that many px.
@export var ground_px: float = 96.0
@export var ground_scale: float = 2.0
@export var hits_to_kill: float = 9.0
@export var hit_every: float = 0.32
@export var death_time: float = 0.45
## Seconds of walking between a monster falling and the next appearing (random in the range).
@export var spawn_gap := Vector2(1.2, 2.4)
@export var crit_chance: float = 0.15
@export var crit_mult: float = 2.0
## How close (px) the monster comes to the front hero before the fight starts.
@export var contact_px: float = 24.0
@export var damage_color := Color.WHITE
@export var crit_color := Color("ffe9a8")
@export var rng_seed: int = 11

var kills: int = 0
var walking: bool = true

var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _scroll: float = 0.0
var _enemy_hp: float = 0.0
var _enemy_max: float = 1.0
var _enemy_dying: float = -1.0
var _spawn_in: float = 1.0
var _hit_in: float = 0.0
var _pop: int = 0

@onready var _far: TextureRect = %Far
@onready var _ground: TextureRect = %Ground
@onready var _props: Control = %Props
@onready var _hero_nodes: Control = %Heroes
@onready var _enemy: TextureRect = %Enemy
@onready var _enemy_bar: ProgressBar = %EnemyHp
@onready var _popups: Control = %Popups


func _ready() -> void:
	_rng.seed = rng_seed
	_far.material = _far.material.duplicate()
	_ground.material = _ground.material.duplicate()
	_enemy.visible = false
	_enemy_bar.visible = false
	resized.connect(_fit_far)
	_fit_far()
	for popup: Node in _popups.get_children():
		(popup as Control).visible = false


func _process(delta: float) -> void:
	if is_visible_in_tree():
		step(delta)


## Advances the strip by dt seconds.
func step(dt: float) -> void:
	_t += dt
	if walking:
		_scroll += walk_speed * dt
		_spawn_in -= dt
		if _spawn_in <= 0.0 and not _enemy.visible:
			_spawn()
	_move_world(dt)
	if _enemy.visible:
		if _enemy_dying >= 0.0:
			_enemy_dying += dt
			_enemy.modulate.a = 1.0 - _enemy_dying / death_time
			if _enemy_dying >= death_time:
				_enemy.visible = false
				_enemy_bar.visible = false
				walking = true
				_spawn_in = _rng.randf_range(spawn_gap.x, spawn_gap.y)
		elif walking:
			_enemy.position.x -= walk_speed * dt
			if _enemy.position.x <= _front_x() + contact_px:
				walking = false
				_hit_in = 0.1
		else:
			_hit_in -= dt
			if _hit_in <= 0.0:
				_hit_in = hit_every
				_hit()
	_enemy_bar.position = _enemy.position + Vector2(_enemy.size.x * 0.2, -14.0)
	_enemy_bar.value = 100.0 * _enemy_hp / _enemy_max
	_step_popups(dt)
	_show_frames()


## The size of one hit before the random spread (0.8-1.3) and crits. Override with the party's strength.
func _damage_base() -> float:
	return 100.0


## Animate the party here (run frames while `walking`, attack frames otherwise; `_t` is the strip's clock).
func _show_frames() -> void:
	pass


## A monster fell: count it, show what it paid (popup()). Called after the killing hit's number popped.
func fell() -> void:
	pass


## Shows `text` in `color` rising from `at` (strip coordinates), reusing the oldest popup label.
func popup(text: String, color: Color, at: Vector2) -> void:
	var label: Label = _popups.get_child(_pop % _popups.get_child_count())
	_pop += 1
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.position = at + Vector2(_rng.randf_range(-16.0, 16.0), 0.0)
	label.modulate.a = 1.0
	label.visible = true
	label.set_meta(&"age", 0.0)


## Where the monster's body is, for popups over it.
func enemy_rect() -> Rect2:
	return Rect2(_enemy.position, _enemy.size)


func _spawn() -> void:
	_enemy_max = hits_to_kill * _damage_base()
	_enemy_hp = _enemy_max
	_enemy_dying = -1.0
	_enemy.position.x = size.x + 10.0  # the band spans the view, so its x is the view's
	_enemy.modulate.a = 1.0
	_enemy.visible = true
	_enemy_bar.visible = true
	enemy_spawned.emit()


func _hit() -> void:
	var dmg: float = _damage_base() * _rng.randf_range(0.8, 1.3)
	var crit: bool = _rng.randf() < crit_chance
	if crit:
		dmg *= crit_mult
	_enemy_hp = maxf(_enemy_hp - dmg, 0.0)
	popup("%d" % roundi(dmg), crit_color if crit else damage_color, _enemy.position + Vector2(_enemy.size.x * 0.4, 10.0))
	_enemy.position.x += 4.0
	hit.emit(dmg, crit)
	if _enemy_hp <= 0.0:
		_enemy_dying = 0.0
		kills += 1
		fell()
		enemy_fell.emit()


## The far picture keeps its own proportions at the strip's height and repeats (mirrored) across its width.
func _fit_far() -> void:
	var tex: Texture2D = _far.texture
	if tex == null or _far.size.y <= 0.0:
		return
	var tile_w: float = tex.get_width() * _far.size.y / tex.get_height()
	(_far.material as ShaderMaterial).set_shader_parameter(&"tiles", Vector2(_far.size.x / tile_w, 1.0))


func _front_x() -> float:
	var front: float = 0.0
	for node: Node in _hero_nodes.get_children():
		if (node as Control).visible:
			front = maxf(front, (node as Control).position.x + (node as Control).size.x)
	return front


func _move_world(dt: float) -> void:
	if _far.texture != null:
		var tile_w: float = _far.size.y * _far.texture.get_width() / maxf(_far.texture.get_height(), 1.0)
		(_far.material as ShaderMaterial).set_shader_parameter(&"offset", _scroll * far_rate / maxf(tile_w, 1.0))
	(_ground.material as ShaderMaterial).set_shader_parameter(&"offset", _scroll / ground_px / ground_scale)
	if not walking:
		return
	for prop: Node in _props.get_children():
		var c := prop as Control
		c.position.x -= walk_speed * prop_rate * dt
		if c.position.x + c.size.x < 0.0:
			c.position.x = size.x + _rng.randf_range(20.0, 260.0)


func _step_popups(dt: float) -> void:
	for label: Node in _popups.get_children():
		var c := label as Control
		if not c.visible:
			continue
		var age: float = float(c.get_meta(&"age", 0.0)) + dt
		c.set_meta(&"age", age)
		c.position.y -= 40.0 * dt
		c.modulate.a = clampf(1.6 - age * 1.6, 0.0, 1.0)
		if age >= 1.0:
			c.visible = false
