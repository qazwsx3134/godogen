@tool
extends Control
## Editor-only preview: the character instance follows this slot's editable frame in the same way
## that the game places a character. main.gd removes Preview before presenting the stage.

const REFERENCE_SIZE: Vector2 = Vector2(480.0, 1560.0)


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	resized.connect(_place_preview)
	_place_preview.call_deferred()


func _place_preview() -> void:
	if not Engine.is_editor_hint() or get_child_count() == 0:
		return
	var character: Control = get_child(0) as Control
	if character == null:
		return
	var frame: CanvasItem = character.get_node_or_null("Box") as CanvasItem
	if frame != null:
		frame.visible = false
	character.size = REFERENCE_SIZE
	character.pivot_offset = Vector2(REFERENCE_SIZE.x * 0.5, REFERENCE_SIZE.y)
	character.scale = Vector2.ONE * (size.y / REFERENCE_SIZE.y)
	character.position = Vector2(size.x * 0.5, size.y) - character.pivot_offset
