extends CanvasLayer
## FPS and draw calls in a corner: the cheapest way to see how the walker runs on a phone.

@onready var _stats: Label = %Stats
var _t := 0.0

func _ready() -> void:
	# TouchScreenButton hides only its own texture without a touchscreen; hide the labels with it.
	%Buttons.visible = DisplayServer.is_touchscreen_available()

func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	_stats.text = "FPS %d · draw calls %d" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
