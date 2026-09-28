@tool
extends Control
## Tsukkomi cut-in (scenes/ui/cutin.tscn): concentration lines and a tilted speech bubble with the
## big line. It never takes input, so the tap that follows it still reaches the story.

@export_enum("cinema", "ledger", "manga") var style_id: String = "manga":
	set(value):
		style_id = value
		queue_redraw()

@onready var bubble: Control = %Bubble
@onready var speaker: Label = %Speaker
@onready var text: Label = %Text


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	bubble.resized.connect(func() -> void: bubble.pivot_offset = bubble.size * 0.5)


## Pops in, holds, fades out, and frees itself.
func play(line: String, speaker_name: String) -> void:
	text.text = line
	speaker.text = speaker_name
	speaker.visible = not speaker_name.is_empty()
	modulate.a = 0.0
	bubble.scale = Vector2(0.6, 0.6)
	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.9)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var reach: float = size.length()
	var ink: Color = Color(1, 1, 1, 0.28) if style_id == "cinema" else Color(0.08, 0.08, 0.08, 0.3)
	for index: int in range(56):
		var angle: float = TAU * index / 56.0 + (0.02 if index % 2 == 0 else -0.015)
		var spread: float = 0.012 + 0.01 * float(index % 3)
		var near: float = minf(size.x, size.y) * (0.3 + 0.06 * float(index % 4))
		draw_colored_polygon(PackedVector2Array([
			center + Vector2.from_angle(angle) * near,
			center + Vector2.from_angle(angle - spread) * reach,
			center + Vector2.from_angle(angle + spread) * reach]), ink)
