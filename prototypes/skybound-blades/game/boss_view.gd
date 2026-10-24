extends "res://game/actor_view.gd"
## A floor guardian built from low-poly stone (scenes/actors/gatekeeper.tscn). Same contract as
## the sprite actor (bind/remember/capture/sync/hurt), different body: arms rise during a
## telegraph and slam on impact, the eyes flare when hurt, the whole golem sinks when it falls.

@onready var _body: Node3D = $Visual/Body
@onready var _arm_l: Node3D = $Visual/Body/ArmL
@onready var _arm_r: Node3D = $Visual/Body/ArmR
@onready var _eyes: MeshInstance3D = $Visual/Body/Head/Eyes

var _flare: float = 0.0
var _windup: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	nameplate.position.y = head_height + 0.32
	hp_bar.position.y = head_height + 0.08
	hp_bar.material_override = hp_bar.material_override.duplicate()
	_eyes.material_override = _eyes.material_override.duplicate()
	nameplate.modulate = nameplate_color
	hp_bar.visible = false
	select_ring.visible = false


func bind(unit: RefCounted) -> void:
	unit_id = unit.id
	nameplate.text = unit.display_name
	nameplate.visible = true
	_curr = Vector3(unit.pos.x, 0.0, unit.pos.y)
	_prev = _curr
	global_position = _curr
	_was_alive = unit.alive
	_shown_action_ms = unit.action_ms
	_body.position.y = 0.0
	_trail = 1.0


func sync(unit: RefCounted, alpha: float, delta: float, targeted: bool) -> void:
	global_position = _prev.lerp(_curr, alpha)
	if unit.alive and not _was_alive:
		_prev = _curr
		global_position = _curr
		_body.position.y = 0.0
		nameplate.visible = true
	_was_alive = unit.alive
	_clock += delta
	if unit.facing.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(unit.facing.x, unit.facing.y), 1.0 - exp(-delta * 6.0))
	if unit.action_ms != _shown_action_ms:
		_shown_action_ms = unit.action_ms
		_windup = 1.6 if unit.action == &"skill" else 0.35
	_windup = maxf(0.0, _windup - delta)
	var raise := clampf(_windup / 0.6, 0.0, 1.0) if _windup > 0.25 else _windup * 4.0
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.4 * raise, 1.0 - exp(-delta * 10.0))
	_arm_r.rotation.x = _arm_l.rotation.x
	_flare = move_toward(_flare, 0.0, delta * 3.0)
	(_eyes.material_override as StandardMaterial3D).emission_energy_multiplier = 2.0 + _flare * 6.0
	if not unit.alive:
		_body.position.y = move_toward(_body.position.y, -2.6, delta * 1.5)
		nameplate.visible = false
	else:
		_body.position.y = sin(_clock * 1.8) * 0.04 + (absf(sin(_clock * 6.0)) * 0.08 if unit.moving else 0.0)
	var ratio: float = unit.hp / unit.max_hp
	hp_bar.visible = unit.alive
	_trail = ratio if ratio > _trail else move_toward(_trail, ratio, delta * 0.6)
	var bar := hp_bar.material_override as ShaderMaterial
	bar.set_shader_parameter(&"ratio", ratio)
	bar.set_shader_parameter(&"trail", _trail)
	select_ring.visible = targeted and unit.alive


func hurt(amount: int) -> void:
	_flare = 1.0
