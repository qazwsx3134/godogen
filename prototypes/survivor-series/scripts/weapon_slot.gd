extends Panel
## One HUD slot: the item's pixel icon (or its first characters when it has none) and one pip per level.
@export var pip_on := Color("ffd36b")
@export var pip_off := Color(1, 1, 1, 0.18)
@onready var icon: TextureRect = %Icon
@onready var short: Label = %Short
@onready var pips: HBoxContainer = %Pips
var id: StringName

func setup(item: Resource, level: int) -> void:
	id = item.id
	icon.texture = item.icon
	icon.visible = item.icon != null
	short.text = item.title.left(2 if custom_minimum_size.x >= 40.0 else 1)
	short.visible = item.icon == null
	var top: int = maxi(1, item.max_level)
	for child: Node in pips.get_children():
		child.queue_free()
	# ponytail: pips are built per setup; the slot is rebuilt only when the build changes.
	for i: int in top:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(4, 4)
		pip.color = pip_on if i < level else pip_off
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)

## A short pop when the slot is new or levelled up.
func flash() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.25, 1.25)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
