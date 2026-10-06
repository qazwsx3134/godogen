extends Node2D
signal smoke_requested(at: Vector2)
signal warning_started
signal impacted(enemy: Node2D, lethal: bool, direction: Vector2)
@export var definition: Resource
var hp: float
var dead: bool = false
var knockback := Vector2.ZERO
var dash_direction := Vector2.RIGHT
var phase: String = "chase"
var phase_left: float = 0.0
var hazard_left: float = 1.5
var fly_left: float = 0.0
var rest_scale: Vector2
var _flash: Tween
@onready var visual: Node2D = %Visual
@onready var shadow: Polygon2D = %Shadow
@onready var warning: Node2D = %Warning
@onready var warning_lane: Line2D = %WarningLane
@onready var warning_line: Line2D = %WarningLine
@onready var hp_bar: ProgressBar = %HpBar

func _ready() -> void:
	hp = definition.max_hp
	rest_scale = visual.scale
	warning.hide()
	hp_bar.max_value = hp
	hp_bar.value = hp

func step(delta: float, target: Vector2, bounds: Rect2) -> void:
	if dead:
		position += knockback * delta
		visual.rotation += delta * 12.0
		visual.scale += Vector2.ONE * delta * 0.24
		fly_left -= delta
		if fly_left <= 0.0:
			queue_free()
		return
	var toward: Vector2 = (target - position).normalized()
	hazard_left -= delta
	var movement: Vector2 = toward * definition.speed
	if definition.kind == "smoker" and hazard_left <= 0.0:
		hazard_left = definition.hazard_interval
		smoke_requested.emit(position)
	if definition.kind == "bike":
		if phase == "chase" and hazard_left <= 0.0:
			phase = "warning"
			phase_left = definition.warning_time
			dash_direction = toward
			warning_lane.points = PackedVector2Array([Vector2.ZERO, dash_direction * 650.0])
			warning_line.points = warning_lane.points
			warning.show()
			warning_started.emit()
		if phase == "warning":
			movement = Vector2.ZERO
			phase_left -= delta
			if phase_left <= 0.0:
				phase = "dash"
				phase_left = definition.dash_time
				warning.hide()
		elif phase == "dash":
			movement = dash_direction * definition.dash_speed
			phase_left -= delta
			if phase_left <= 0.0:
				phase = "recover"
				phase_left = 0.7
		elif phase == "recover":
			movement = Vector2.ZERO
			phase_left -= delta
			if phase_left <= 0.0:
				phase = "chase"
				hazard_left = definition.hazard_interval
	position += (movement + knockback) * delta
	knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
	if phase != "dash":
		position = position.clamp(bounds.position, bounds.end)
	elif not bounds.grow(100.0).has_point(position):
		queue_free()

func hit(damage: float, direction: Vector2, force: float = 1.0) -> bool:
	if dead:
		return false
	hp = maxf(0.0, hp - damage)
	hp_bar.value = hp
	dead = hp <= 0.0
	if dead:
		warning.hide()
		shadow.hide()
		hp_bar.hide()
		knockback = direction.normalized() * 1300.0
		fly_left = 1.0
	else:
		knockback += direction.normalized() * (260.0 * force / definition.weight)
	if _flash != null and _flash.is_valid():
		_flash.kill()
	visual.modulate = Color(2.0, 1.8, 1.2)
	visual.scale = rest_scale * Vector2(1.18, 0.84)
	_flash = create_tween().set_parallel(true)
	_flash.tween_property(visual, "modulate", Color.WHITE, 0.16)
	_flash.tween_property(visual, "scale", rest_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impacted.emit(self, dead, direction)
	return dead
