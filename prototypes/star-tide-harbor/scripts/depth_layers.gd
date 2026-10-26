extends CanvasLayer
## Authored origins remain editable; only the camera-relative offset is animated.
@export var mid_speed: float = .46
@export var foreground_speed: float = 1.30
var mid_origin := Vector2.ZERO
var foreground_origin := Vector2.ZERO
func _ready() -> void:
	mid_origin=%MidShore.position
	foreground_origin=%NearPlants.position
func follow(camera_x: float) -> void:
	var travel:=camera_x-640.0
	%MidShore.position=mid_origin-Vector2(roundf(travel*mid_speed),0)
	%NearPlants.position=foreground_origin-Vector2(roundf(travel*foreground_speed),0)
