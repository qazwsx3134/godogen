@tool
extends "res://game/actor_view.gd"
## One approved illustration, with telegraph/impact presentation driven by battle events.
## This is a single-frame boss: pose animation can be added to the sheet later.
var _preparing: bool = false
var _prepare_time: float = 0.0
var _impact_left: float = 0.0


func bind(unit: RefCounted) -> void:
	super.bind(unit)
	_preparing = false
	_prepare_time = 0.0
	_impact_left = 0.0


func begin_telegraph(_seconds: float) -> void:
	_preparing = true
	_prepare_time = 0.0


func show_impact() -> void:
	_preparing = false
	_impact_left = 0.24


func _animate_body(unit: RefCounted, delta: float) -> void:
	if _sprite_base == Vector3.ZERO:
		_sprite_base = _sprite.scale
	if not unit.alive:
		_preparing = false
		_impact_left = 0.0
		_sprite.position = Vector3.ZERO
		_sprite.scale = _sprite_base
		return
	_prepare_time += delta
	_impact_left = maxf(0.0, _impact_left - delta)
	var charge := minf(_prepare_time / 0.25, 1.0) if _preparing else 0.0
	var impact := sin((_impact_left / 0.24) * PI) if _impact_left > 0.0 else 0.0
	_sprite.scale = _sprite_base * Vector3(1.0 + charge * 0.03 + impact * 0.08, 1.0 - charge * 0.025 - impact * 0.07, 1.0)
	_sprite.position = Vector3(0.0, charge * 0.06, 0.0)
