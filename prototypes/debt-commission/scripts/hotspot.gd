extends Control
## One spot to search on the background (scenes/ui/hotspot.tscn), laid over its object in the
## picture by main.gd from the story's `pos`/`size` (fractions of the picture). It shows nothing
## until found; then a faint outline and a check stay on it.

@onready var outline: ReferenceRect = %Outline
@onready var mark: Label = %Mark
var found: bool = false


func set_found(value: bool, animate: bool) -> void:
	found = value
	outline.visible = value
	mark.visible = value
	outline.modulate.a = 1.0 if animate else 0.5
	if value and animate:
		create_tween().tween_property(outline, "modulate:a", 0.5, 0.8)
