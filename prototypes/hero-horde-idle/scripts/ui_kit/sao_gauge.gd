extends ProgressBar
## The slanted gauge every SAO-kit bar is made of (docs/SAO_UI_SPEC.md). With `by_health` the fill goes green, yellow
## under half, red under a fifth; otherwise it keeps the fill saved in the scene (cyan timer, red boss).

const GREEN := preload("res://ui/sao_gauge_green.tres")
const YELLOW := preload("res://ui/sao_gauge_yellow.tres")
const RED := preload("res://ui/sao_gauge_red.tres")

@export var by_health: bool = true


## r in 0..1.
func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	max_value = 1.0
	value = r
	if by_health:
		add_theme_stylebox_override(&"fill", GREEN if r > 0.5 else (YELLOW if r > 0.2 else RED))
