extends Node2D
## The ape-like boss. Origin = feet. Poses: 0 idle, 1 throw wind-up (boulder overhead), 2 defeated.
## The reaching arm is its own sprite on %ArmPivot (at the shoulder), pointing along the pivot's -x axis;
## `extension` 0..1 stretches it from the shoulder to the aimed point.

const POSE_IDLE := 0
const POSE_THROW := 1
const POSE_DOWN := 2

@onready var body: Sprite2D = %Body
@onready var arm_pivot: Node2D = %ArmPivot
@onready var arm: Sprite2D = %Arm
@onready var face: Marker2D = %Face
@onready var hand_rock: Marker2D = %HandRock

var extension := 0.0
var _reach_len := 400.0
var _t := 0.0


func _ready() -> void:
	set_extension(0.0)


func pose(index: int) -> void:
	body.frame = index


func aim(world_target: Vector2) -> void:
	var from := arm_pivot.global_position
	arm_pivot.rotation = (world_target - from).angle() - PI
	_reach_len = from.distance_to(world_target) + 12.0


func set_extension(value: float) -> void:
	extension = value
	arm.visible = value > 0.02
	arm.scale.x = maxf(0.01, value * _reach_len / arm.texture.get_width())


func hand_position() -> Vector2:
	return arm_pivot.to_global(Vector2(-arm.texture.get_width() * arm.scale.x + 26.0, 0.0))


func hand_rect() -> Rect2:
	return Rect2(hand_position() - Vector2(24.0, 24.0), Vector2(48.0, 48.0))


func flash(color: Color = Color(2.2, 2.2, 2.2)) -> void:
	body.modulate = color
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.18)


func _process(delta: float) -> void:
	_t += delta
	if body.frame != POSE_DOWN:
		body.scale = Vector2(1.0, 1.0 + sin(_t * 2.6) * 0.012)
