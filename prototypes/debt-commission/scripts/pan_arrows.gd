extends Control
## Arrows on the edges of a search (scenes/ui/pan_arrows.tscn): each shows only while the picture can still
## be dragged that way, and a tap glides the view one step. The root never takes taps; only the arrows do,
## so a tap elsewhere still searches the picture.

## A view direction: Vector2.LEFT looks further left (the picture moves right).
signal pan_requested(direction: Vector2)

@onready var _arrows: Dictionary = {Vector2.LEFT: %Left, Vector2.RIGHT: %Right, Vector2.UP: %Up, Vector2.DOWN: %Down}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for direction: Vector2 in _arrows:
		var arrow: Button = _arrows[direction]
		arrow.pressed.connect(func() -> void: pan_requested.emit(direction))
	visible = false


## pan / pan_y: the current offsets; ranges: Vector2(min, max). A larger pan shows more of the left
## (and a larger pan_y more of the top), as in main_investigation.set_pan.
func refresh(pan: float, pan_range: Vector2, pan_y: float, pan_y_range: Vector2) -> void:
	(_arrows[Vector2.LEFT] as Control).visible = pan < pan_range.y - 1.0
	(_arrows[Vector2.RIGHT] as Control).visible = pan > pan_range.x + 1.0
	(_arrows[Vector2.UP] as Control).visible = pan_y < pan_y_range.y - 1.0
	(_arrows[Vector2.DOWN] as Control).visible = pan_y > pan_y_range.x + 1.0


func arrow(direction: Vector2) -> Button:
	return _arrows[direction]
