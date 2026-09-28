extends MarginContainer
## The folded reading box while searching (scenes/ui/investigate_bar.tscn): how many clues are
## found, and 展開 to bring the box back. One scene for every edition; set_style tints it.

signal expand_pressed

const HUD: Script = preload("res://scripts/round_hud.gd")
const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")

@onready var panel: PanelContainer = %Panel
@onready var progress: Label = %Progress
@onready var expand_button: Button = %Expand


func _ready() -> void:
	expand_button.pressed.connect(func() -> void: expand_pressed.emit())
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))


func set_style(style_id: String) -> void:
	var tint: Dictionary = HUD.TINTS.get(style_id, HUD.TINTS["cinema"])
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = tint["bg"]
	box.border_color = tint["border"]
	box.set_border_width_all(roundi(float(tint["width"]) * 1080.0 / 390.0))
	panel.add_theme_stylebox_override("panel", box)
	progress.add_theme_color_override("font_color", tint["text"])
	UI_STYLES.apply_button(expand_button, style_id, "quickbar")


func set_progress(found: int, total: int) -> void:
	progress.text = "線索 %d/%d・左右拖曳背景，點畫面上的東西調查" % [found, total]
