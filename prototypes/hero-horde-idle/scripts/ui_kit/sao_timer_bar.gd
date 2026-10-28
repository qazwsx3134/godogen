extends Control
## The countdown as a long thin bar: cyan, red in the last fifth. No number.

const CYAN := preload("res://ui/sao_gauge_cyan.tres")
const RED := preload("res://ui/sao_gauge_red.tres")


func set_time(left: float, total: float) -> void:
	var r: float = clampf(left / maxf(total, 0.001), 0.0, 1.0)
	var bar: ProgressBar = %Gauge
	bar.max_value = 1.0
	bar.value = r
	bar.add_theme_stylebox_override(&"fill", CYAN if r > 0.2 else RED)
