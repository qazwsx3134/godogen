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
## Bikes charge along an S: sideways swing in px and the length of one full wave.
var weave_amplitude: float = 45.0
var weave_length: float = 190.0
var weave_side: float = 1.0
var dash_travel: float = 0.0
var heading := Vector2.DOWN
var phase: String = "chase"
var phase_left: float = 0.0
var hazard_left: float = 1.5
var fly_left: float = 0.0
## Seconds spent off-screen while the hero walks away; Street moves the enemy ahead past a limit.
var lag: float = 0.0
var slow_left: float = 0.0
var slow_amount: float = 0.0
var rest_scale: Vector2
## Damage of the latest hit, for the floating number.
var last_damage: float = 0.0
## How a lethal hit plays out, from the damage left over past the remaining HP (see `hit`):
## "drop" falls over on the spot, "slide" is knocked back a little then falls, "launch" flies off spinning.
var death: String = "launch"
## Damage past zero HP, as a fraction of max HP, at which death becomes "slide" / "launch".
@export var slide_overkill: float = 0.25
@export var launch_overkill: float = 1.0
var _fall_side: float = 1.0
var _flash: Tween
@onready var visual: Node2D = %Visual
@onready var shadow: Sprite2D = %Shadow
@onready var warning: Node2D = %Warning
@onready var warning_lane: Line2D = %WarningLane
@onready var warning_line: Line2D = %WarningLine
## Grows along the warning lane as the countdown runs (bike only).
@onready var warning_fill: Line2D = get_node_or_null("%WarningFill")
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
		# Elites get a gold health bar, like PokéSurvivor's bosses.
		var gold := (hp_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
		gold.bg_color = Color("ffcb3d")
		hp_bar.add_theme_stylebox_override("fill", gold)
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
		fly_left -= delta
		match death:
			"launch":
				position += knockback * delta
				visual.rotation += delta * 12.0
				visual.scale += Vector2.ONE * delta * 0.24
			"slide":
				position += knockback * delta
				knockback = knockback.move_toward(Vector2.ZERO, delta * 1100.0)
				visual.rotation = move_toward(visual.rotation, _fall_side * 1.45, delta * 5.0)
				modulate.a = clampf(fly_left / 0.3, 0.0, 1.0)
			_:
				visual.rotation = move_toward(visual.rotation, _fall_side * 1.45, delta * 8.0)
				modulate.a = clampf(fly_left / 0.3, 0.0, 1.0)
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
			dash_travel = 0.0
			weave_side = -weave_side
			var lane := PackedVector2Array()
			for i: int in 34:
				lane.append(dash_offset(i * 20.0) / scale.x)
			warning_lane.points = lane
			warning_line.points = warning_lane.points
			warning.show()
			warning_started.emit()
		if phase == "warning":
			movement = Vector2.ZERO
			phase_left -= delta
			_fill_warning(1.0 - phase_left / definition.warning_time)
			if phase_left <= 0.0:
				phase = "dash"
				phase_left = definition.dash_time
				warning.hide()
		elif phase == "dash":
			var from: Vector2 = dash_offset(dash_travel)
			dash_travel += definition.dash_speed * delta
			movement = (dash_offset(dash_travel) - from) / delta if delta > 0.0 else Vector2.ZERO
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
	face(movement if phase == "dash" else dash_direction if phase == "warning" else toward)
	position += (movement + knockback) * delta
	knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
	if phase != "dash":
		position = position.clamp(bounds.position, bounds.end)
	elif not bounds.grow(100.0).has_point(position):
		queue_free()

## The countdown fills the lane from the bike outward; the last quarter blinks.
func _fill_warning(t: float) -> void:
	if warning_fill == null:
		return
	var lane: PackedVector2Array = warning_lane.points
	warning_fill.points = lane.slice(0, clampi(roundi(lane.size() * t), 2, lane.size()))
	warning.modulate.a = 0.35 if t > 0.75 and fmod(t * 12.0, 1.0) < 0.5 else 1.0

## Where the S-shaped charge is after `travel` px along the locked lane, relative to its start.
func dash_offset(travel: float) -> Vector2:
	return dash_direction * travel + dash_direction.orthogonal() * weave_side * weave_amplitude * sin(TAU * travel / weave_length)

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
	var overkill: float = (damage - hp) / max_hp
	last_damage = damage
	hp = maxf(0.0, hp - damage)
	hp_bar.value = hp
	if not elite and definition.max_hp >= 140.0 and hp < max_hp:
		hp_bar.show()
	dead = hp <= 0.0
	if dead:
		warning.hide()
		shadow.hide()
		hp_bar.hide()
		death = "launch" if overkill >= launch_overkill else ("slide" if overkill >= slide_overkill else "drop")
		_fall_side = 1.0 if direction.x >= 0.0 else -1.0
		match death:
			"launch":
				knockback = direction.normalized() * 1300.0
				fly_left = 1.0
			"slide":
				knockback = direction.normalized() * 520.0
				fly_left = 0.75
			_:
				knockback = Vector2.ZERO
				fly_left = 0.5
	else:
		knockback += direction.normalized() * (260.0 * force / definition.weight)
	if _flash != null and _flash.is_valid():
		_flash.kill()
	visual.modulate = Color(2.0, 2.0, 2.0)
	visual.scale = rest_scale * Vector2(1.18, 0.84)
	_flash = create_tween().set_parallel(true)
	_flash.tween_property(visual, "modulate", Color(1.15, 0.95, 0.75) if elite else Color.WHITE, 0.16)
	_flash.tween_property(visual, "scale", rest_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impacted.emit(self, dead, direction)
	return dead
