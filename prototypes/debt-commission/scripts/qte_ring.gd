extends Control
## The QTE (scenes/ui/qte_ring.tscn): a ring shrinks onto the target ring over `duration`; one tap
## anywhere answers it. Emits the tap's offset from the moment the rings meet (negative = early),
## or tapped=false once `late_after` passes without a tap. StoryRunner judges the offset.
## Timing uses the clock (Time.get_ticks_usec), not frame deltas.

signal resolved(tapped: bool, offset: float)

## Target ring radius in local px.
@export var target_radius: float = 190.0
@export var ring_color: Color = Color("#fffdf5")
@export var target_color: Color = Color("#ffdc41")

var duration: float = 1.6
var late_after: float = 2.0
var _start_usec: int = 0
var _done: bool = true

@onready var prompt: Label = %Prompt


func _ready() -> void:
	set_process(false)


## qte: the slot's {duration, window, late_after, ...}.
func start(qte: Dictionary) -> void:
	duration = float(qte.get("duration", 1.6))
	late_after = float(qte.get("late_after", 2.0))
	_start_usec = Time.get_ticks_usec()
	_done = false
	set_process(true)
	queue_redraw()


func elapsed() -> float:
	return float(Time.get_ticks_usec() - _start_usec) / 1000000.0


## Seconds from the moment the rings meet.
static func offset_at(seconds: float, ring_duration: float) -> float:
	return seconds - ring_duration


func _process(_delta: float) -> void:
	queue_redraw()
	if elapsed() > late_after:
		_finish(false, offset_at(elapsed(), duration))


func _gui_input(event: InputEvent) -> void:
	if _done or not (event is InputEventMouseButton and event.is_pressed()):
		return
	accept_event()  # the tap answers the QTE and nothing underneath
	_finish(true, offset_at(elapsed(), duration))


func _finish(tapped: bool, offset: float) -> void:
	if _done:
		return
	_done = true
	set_process(false)
	resolved.emit(tapped, offset)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_arc(center, target_radius, 0.0, TAU, 96, target_color, 14.0, true)
	var progress: float = elapsed() / maxf(duration, 0.01) if not _done else 1.0
	var radius: float = maxf(8.0, target_radius * (1.0 + 2.0 * (1.0 - progress)))
	draw_arc(center, radius, 0.0, TAU, 96, Color(0, 0, 0, 0.6), 16.0, true)
	draw_arc(center, radius, 0.0, TAU, 96, ring_color, 8.0, true)
