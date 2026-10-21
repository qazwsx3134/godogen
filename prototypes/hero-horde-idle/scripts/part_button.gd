extends Button
## A boss part (腿, 持棍手臂, 角) on screen: tap to aim the ranged squad at it. The bar is the part's HP; a broken part
## stays on screen, greyed out. hud.gd places it over the part's anchor on the boss each frame.

@export var part_index: int = 0

@onready var _bar: ProgressBar = %Bar


func show_part(title: String, hp_ratio: float, aimed: bool) -> void:
	text = ("◎" + title) if aimed else title
	_bar.value = hp_ratio * 100.0
	disabled = hp_ratio <= 0.0
	modulate = Color(1.0, 0.9, 0.5) if aimed else (Color(0.6, 0.6, 0.65) if disabled else Color.WHITE)
