extends Control
## First-time guide (scenes/ui/tutorial_overlay.tscn, docs/PLAN-LOG-AVATAR-TUTORIAL.md B): dims the screen around one
## control, frames it, and explains it on a washi card, one step at a time; 下一步 / 略過. Steps come from
## data/tutorials.json; main.gd resolves each step's `target` to a Control. Only the frame, the four shades, the arrow
## and the card's vertical place follow the target at run time; sizes, colours and text styles live in the scene.

signal finished(id: String, skipped: bool)

## Gap between the target and its frame, and between the frame and the card.
@export var frame_margin: float = 14.0
@export var card_gap: float = 36.0

var tutorial_id: String = ""
var _steps: Array = []
var _index: int = 0
var _resolve: Callable

@onready var _shades: Array[ColorRect] = [%ShadeTop, %ShadeBottom, %ShadeLeft, %ShadeRight]
@onready var _focus: Control = %Focus
@onready var _arrow: Label = %Arrow
@onready var _card: Control = %Card
@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _step: Label = %Step
@onready var _next: Button = %Next
@onready var _skip: Button = %Skip


func _ready() -> void:
	visible = false
	_next.pressed.connect(next)
	_skip.pressed.connect(func() -> void: _end(true))
	resized.connect(_place)


## steps: [{target, title, text, arrow}]; resolve(target name) -> Control or null (then the card shows alone).
func start(id: String, steps: Array, resolve: Callable) -> void:
	tutorial_id = id
	_steps = steps
	_resolve = resolve
	_index = 0
	visible = true
	_show_step()


func active() -> bool:
	return visible


func next() -> void:
	if _index + 1 >= _steps.size():
		_end(false)
		return
	_index += 1
	_show_step()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		next()
	elif event.is_action_pressed("ui_cancel"):
		_end(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _show_step() -> void:
	var step: Dictionary = _steps[_index]
	_title.text = str(step.get("title", ""))
	_body.text = str(step.get("text", ""))
	_step.text = "%d／%d" % [_index + 1, _steps.size()]
	_next.text = "知道了" if _index + 1 >= _steps.size() else "下一步 ›"
	_place.call_deferred()
	# Wrapped text settles its height one frame after its width; place again then.
	get_tree().process_frame.connect(_place, CONNECT_ONE_SHOT | CONNECT_DEFERRED)


## Re-places the frame around the current target; main.gd also calls this after its own layout changes.
func _place() -> void:
	if not visible or _steps.is_empty():
		return
	var target: Control = _resolve.call(str(_steps[_index].get("target", ""))) as Control if _resolve.is_valid() else null
	var hole := Rect2(size * 0.5, Vector2.ZERO)
	if target != null and target.is_visible_in_tree():
		var screen: Rect2 = target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size)
		hole = (get_global_transform_with_canvas().affine_inverse() * screen).grow(frame_margin)
		hole = hole.intersection(Rect2(Vector2.ZERO, size))
	_focus.visible = hole.size != Vector2.ZERO
	_focus.position = hole.position
	_focus.size = hole.size
	_shades[0].position = Vector2.ZERO
	_shades[0].size = Vector2(size.x, hole.position.y)
	_shades[1].position = Vector2(0.0, hole.end.y)
	_shades[1].size = Vector2(size.x, size.y - hole.end.y)
	_shades[2].position = Vector2(0.0, hole.position.y)
	_shades[2].size = Vector2(hole.position.x, hole.size.y)
	_shades[3].position = Vector2(hole.end.x, hole.position.y)
	_shades[3].size = Vector2(size.x - hole.end.x, hole.size.y)
	# The card goes on whichever side of the target has more room, clamped to the screen.
	_card.size.y = 0.0  # shrink to its content at the current width (the body text wraps)
	var card_h: float = _card.size.y
	var above: bool = hole.get_center().y > size.y * 0.5
	var y: float = hole.position.y - card_gap - card_h if above else hole.end.y + card_gap
	if hole.size.y > size.y * 0.5:  # a big area (the scene to search): the card sits inside it, at its foot
		above = false
		y = hole.end.y - card_gap - card_h
	_card.position.y = clampf(y, 0.0, maxf(0.0, size.y - card_h))
	_arrow.visible = _focus.visible and hole.size.y <= size.y * 0.5
	_arrow.text = "▼" if above else "▲"
	var arrow_size: Vector2 = _arrow.get_combined_minimum_size()
	_arrow.position = Vector2(hole.get_center().x - arrow_size.x * 0.5,
		hole.position.y - arrow_size.y if above else hole.end.y)


func _end(skipped: bool) -> void:
	visible = false
	finished.emit(tutorial_id, skipped)
