extends Node2D
signal smoke_requested(at: Vector2)
signal warning_started
signal impacted(enemy: Node2D, lethal: bool, direction: Vector2)
@export var definition: Resource
## Optional art per heading for vehicles, in order S, SE, E, NE, N. West headings mirror SE/E/NE.
@export var direction_textures: Array[Texture2D] = []
var hp: float
var max_hp: float
var elite: bool = false
var dead: bool = false
var knockback := Vector2.ZERO
var dash_direction := Vector2.RIGHT
var heading := Vector2.DOWN
var phase: String = "chase"
var phase_left: float = 0.0
var hazard_left: float = 1.5
var fly_left: float = 0.0
var slow_left: float = 0.0
var slow_amount: float = 0.0
var rest_scale: Vector2
var _flash: Tween
@onready var visual: Node2D = %Visual
@onready var shadow: Polygon2D = %Shadow
@onready var warning: Node2D = %Warning
@onready var warning_lane: Line2D = %WarningLane
@onready var warning_line: Line2D = %WarningLine
@onready var hp_bar: ProgressBar = %HpBar
@onready var art: Sprite2D = visual.get_node("Art")
@onready var placeholder: Node2D = visual.get_node("Placeholder")

func _ready() -> void:
	rest_scale = visual.scale
	warning.hide()
	setup(1.0, false)

func setup(hp_scale: float, is_elite: bool) -> void:
	elite = is_elite
	max_hp = definition.max_hp * hp_scale * (12.0 if elite else 1.0)
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.visible = elite
	if elite:
		scale = Vector2.ONE * 1.5
		visual.modulate = Color(1.15, 0.95, 0.75)

## Slows chasing for `duration` seconds; the strongest slow wins.
func slow(amount: float, duration: float) -> void:
	slow_amount = maxf(amount, slow_amount if slow_left > 0.0 else 0.0)
	slow_left = maxf(slow_left, duration)

func contact_damage() -> float:
	return definition.contact_damage * (2.5 if phase == "dash" else 1.0) * (1.5 if elite else 1.0)

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
	if slow_left > 0.0:
		slow_left -= delta
		movement *= 1.0 - slow_amount
	if definition.kind == "smoker" and hazard_left <= 0.0:
		hazard_left = definition.hazard_interval
		smoke_requested.emit(position)
	if definition.kind == "bike":
		if phase == "chase" and hazard_left <= 0.0:
			phase = "warning"
			phase_left = definition.warning_time
			dash_direction = toward
			warning_lane.points = PackedVector2Array([Vector2.ZERO, dash_direction * 650.0 / scale.x])
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
	face(dash_direction if phase in ["warning", "dash"] else toward)
	position += (movement + knockback) * delta
	knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
	if phase != "dash":
		position = position.clamp(bounds.position, bounds.end)
	elif not bounds.grow(100.0).has_point(position):
		queue_free()

## Vehicles pick one of eight headings (five drawings, mirrored for the west side); people only flip.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	heading = direction
	if not definition.turns:
		if absf(direction.x) > 0.05:
			placeholder.scale.x = absf(placeholder.scale.x) * signf(direction.x)
			art.flip_h = direction.x < 0.0
		return
	var octant: int = wrapi(roundi(direction.angle() / (PI / 4.0)), 0, 8)
	# Godot angles: 0 = E, 2 = S, 4 = W, 6 = N.
	var frame: int = [2, 1, 0, 1, 2, 3, 4, 3][octant]
	var mirrored: bool = octant in [3, 4, 5]
	if direction_textures.size() >= 5 and art.visible:
		art.texture = direction_textures[frame]
		art.flip_h = mirrored
	# Geometric placeholder has one drawing: mirror it and tilt toward the heading.
	var side: float = -1.0 if mirrored else 1.0
	placeholder.scale.x = absf(placeholder.scale.x) * side
	placeholder.rotation = clampf(direction.y, -1.0, 1.0) * 0.35 * side

func hit(damage: float, direction: Vector2, force: float = 1.0) -> bool:
	if dead:
		return false
	hp = maxf(0.0, hp - damage)
	hp_bar.value = hp
	if not elite and definition.max_hp >= 140.0 and hp < max_hp:
		hp_bar.show()
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
	_flash.tween_property(visual, "modulate", Color(1.15, 0.95, 0.75) if elite else Color.WHITE, 0.16)
	_flash.tween_property(visual, "scale", rest_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impacted.emit(self, dead, direction)
	return dead
