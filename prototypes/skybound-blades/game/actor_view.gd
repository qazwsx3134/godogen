@tool
extends Node3D
## How one battle unit looks. Placed in field.tscn (party and monsters), bound to a unit at
## run time, then synced every frame. It never changes the battle; the field feeds it.
##
## Animation is decided once per frame from the unit's state (down > action > walk > idle), so
## a walk never restarts itself and an attack plays out before idle returns.

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")

## tuning id: leader, guardian, support, or a monster id (meadow_slime, ...).
@export var kind_id: String = "meadow_slime"
@export var sheet: Resource:
	set(value):
		sheet = value
		if is_node_ready() and visual != null:
			if Engine.is_editor_hint():
				_preview_in_editor()
			else:
				visual.sheet = value
## Party members lie down when they fall; monsters dissolve away.
@export var dissolve_on_down: bool = true
@export var nameplate_color: Color = Color("f4ead2")
## Companions are named in the HUD; their world nameplate stays off.
@export var show_nameplate: bool = true
## Top of the sprite (m): the nameplate and HP bar sit above it.
@export var head_height: float = 2.0

@onready var visual: Node3D = $Visual
@onready var nameplate: Label3D = $Nameplate
@onready var hp_bar: MeshInstance3D = $HpBar
@onready var select_ring: MeshInstance3D = $SelectRing

var unit_id: int = -1
var _prev: Vector3
var _curr: Vector3
var _shown_action_ms: float = -1.0e9
var _action_left: float = 0.0
var _hp_show_left: float = 0.0
var _was_alive: bool = true
var _trail: float = 1.0
# Procedural body motion on the Sprite node (the shadow stays on the ground).
var _sprite: Node3D
var _sprite_base: Vector3
var _clock: float = 0.0
var _phase: float = 0.0
var _squash: float = 0.0
var _action_total: float = 0.3


func _ready() -> void:
	if Engine.is_editor_hint():
		_preview_in_editor()
	elif sheet != null:
		visual.sheet = sheet
	nameplate.position.y = head_height + 0.32
	hp_bar.position.y = head_height + 0.08
	if Engine.is_editor_hint():
		return
	visual.auto_advance = false
	hp_bar.material_override = hp_bar.material_override.duplicate()
	_sprite = visual.get_node(^"Sprite")
	_phase = float(get_instance_id() % 997) * 0.37
	nameplate.modulate = nameplate_color
	nameplate.visible = show_nameplate
	hp_bar.visible = false
	select_ring.visible = false


## Called by the field once the battle exists.
func bind(unit: RefCounted) -> void:
	unit_id = unit.id
	nameplate.text = unit.display_name
	_curr = Vector3(unit.pos.x, 0.0, unit.pos.y)
	_prev = _curr
	global_position = _curr
	_was_alive = unit.alive
	_shown_action_ms = unit.action_ms
	_action_left = 0.0
	_hp_show_left = 0.0
	visual.dissolve = 0.0
	visual.flash = 0.0
	visual.play(&"idle", true)
	nameplate.visible = show_nameplate
	hp_bar.visible = false
	select_ring.visible = false
	_trail = 1.0


## Before each simulation step: remember where the unit was, for interpolation.
func remember(unit: RefCounted) -> void:
	_prev = Vector3(unit.pos.x, 0.0, unit.pos.y)


## After the steps of a frame.
func capture(unit: RefCounted) -> void:
	_curr = Vector3(unit.pos.x, 0.0, unit.pos.y)


## Every rendered frame, also while paused or after the run ended (delta 0 freezes time only).
func sync(unit: RefCounted, alpha: float, delta: float, targeted: bool) -> void:
	global_position = _prev.lerp(_curr, alpha)
	if unit.alive and not _was_alive:  # respawned: snap, no slide from the death spot
		_prev = _curr
		global_position = _curr
		visual.dissolve = 0.0
		nameplate.visible = show_nameplate
		visual.play(&"idle", true)
	_was_alive = unit.alive
	visual.facing = Vector3(unit.facing.x, 0.0, unit.facing.y)
	visual.flash = move_toward(visual.flash, 0.0, delta * 6.0)
	_hp_show_left = maxf(0.0, _hp_show_left - delta)
	if unit.action_ms != _shown_action_ms:
		_shown_action_ms = unit.action_ms
		var a: Dictionary = sheet.resolve(unit.action) if sheet != null else {}
		_action_left = maxf(0.3, Sheet.length_ticks(a) / 60.0)
		_action_total = _action_left
		visual.play(unit.action, true)
	_action_left = maxf(0.0, _action_left - delta)
	if not unit.alive:
		visual.play(&"down")
		if dissolve_on_down:
			visual.dissolve = minf(1.0, visual.dissolve + delta * 1.6)
		nameplate.visible = false
	elif _action_left > 0.0:
		pass
	elif unit.moving:
		visual.play(&"walk")
	else:
		visual.play(&"idle")
	visual.step(delta)
	_animate_body(unit, delta)
	var ratio: float = unit.hp / unit.max_hp if unit.max_hp > 0.0 else 0.0
	hp_bar.visible = unit.alive and (targeted or ratio < 0.999 or _hp_show_left > 0.0)
	_trail = ratio if ratio > _trail else move_toward(_trail, ratio, delta * 0.6)
	var bar := hp_bar.material_override as ShaderMaterial
	bar.set_shader_parameter(&"ratio", ratio)
	bar.set_shader_parameter(&"trail", _trail)
	select_ring.visible = targeted and unit.alive


func hurt(amount: int) -> void:
	visual.flash = 1.0
	_hp_show_left = 3.0
	_squash = 1.0


## Breathing at rest, a bounce while walking, a lunge on attack, a hop on skills, a squash when hit.
## Offsets are in world axes; the camera never yaws, so +x is screen-right and the lunge
## follows the side the sprite faces.
func _animate_body(unit: RefCounted, delta: float) -> void:
	if _sprite_base == Vector3.ZERO:
		_sprite_base = _sprite.scale
	_clock += delta
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	var offset := Vector3.ZERO
	var stretch := 0.0
	if not unit.alive:
		pass
	elif _action_left > 0.0:
		var t := 1.0 - _action_left / maxf(_action_total, 0.01)  # 0 → 1 over the action
		var swing := sin(clampf(t * 1.6, 0.0, 1.0) * PI)
		if unit.action == &"skill":
			offset.y = swing * 0.28
			stretch = swing * 0.05
		else:
			var side := 1.0 if visual.drawn.y >= 0 else -1.0
			offset.x = swing * 0.32 * side
			stretch = -swing * 0.03
	elif unit.moving:
		offset.y = absf(sin(_clock * 9.5 + _phase)) * 0.07
		stretch = sin(_clock * 19.0 + _phase) * 0.025
	else:
		stretch = sin(_clock * 2.3 + _phase) * 0.018
	stretch -= _squash * 0.12
	_sprite.position = offset
	_sprite.scale = Vector3(_sprite_base.x * (1.0 - stretch * 0.6), _sprite_base.y * (1.0 + stretch), _sprite_base.z)


## Editor preview: the sheet script is not a tool script, so read its exported values and show
## the idle cell on this instance's own material (nothing is written back to actor.tscn).
func _preview_in_editor() -> void:
	nameplate.position.y = head_height + 0.32
	hp_bar.position.y = head_height + 0.08
	var sprite := visual.get_node_or_null(^"Sprite") as MeshInstance3D
	if sheet == null or sprite == null or not sprite.material_override is ShaderMaterial:
		return
	var material := (sprite.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	material.set_shader_parameter(&"atlas", sheet.get("atlas"))
	material.set_shader_parameter(&"frames", Vector2(sheet.get("columns"), sheet.get("rows")))
	material.set_shader_parameter(&"foot_gutter", float(sheet.get("foot_px")) / float(sheet.get("cell_px")))
	material.set_shader_parameter(&"frame", 0.0)
	sprite.material_override = material
	var size: float = float(sheet.get("cell_px")) * float(sheet.get("meters_per_px"))
	sprite.scale = Vector3.ONE * size
	var shadow := visual.get_node_or_null(^"Shadow") as Node3D
	if shadow != null:
		shadow.scale = Vector3.ONE * size
