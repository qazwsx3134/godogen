extends Control
## Fantasy UI Borders 示範：版面與樣式都在 scene／fantasy_theme.tres，這裡只接事件。

signal quest_accepted


func _ready() -> void:
	%Accept.pressed.connect(_on_accept)


func _on_accept() -> void:
	%Accept.text = "Quest accepted"
	%Accept.disabled = true
	%Title.text = "Quest — in progress"
	quest_accepted.emit()
