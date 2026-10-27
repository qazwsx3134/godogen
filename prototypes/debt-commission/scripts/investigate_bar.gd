extends MarginContainer
## The folded reading box while searching: a translucent bottom strip and compact controls.

signal expand_pressed
signal continue_pressed

const HUD: Script = preload("res://scripts/round_hud.gd")
const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")

@onready var panel: PanelContainer = %Panel
@onready var progress: Label = %Progress
@onready var expand_button: Button = %Expand
@onready var continue_button: Button = %Continue


func _ready() -> void:
	expand_button.pressed.connect(func() -> void: expand_pressed.emit())
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	resized.connect(func() -> void: pivot_offset = Vector2(0.0, size.y))


func set_style(style_id: String) -> void:
	var tint: Dictionary = HUD.tint_of(style_id)
	var own: StyleBox = UI_STYLES.hud_resource(style_id, "panel") as StyleBox
	if own != null:
		panel.add_theme_stylebox_override("panel", own)
	else:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = tint["bg"]
		box.border_color = tint["border"]
		box.set_border_width_all(roundi(float(tint["width"]) * 1080.0 / 390.0))
		panel.add_theme_stylebox_override("panel", box)
	progress.add_theme_color_override("font_color", tint["text"])
	UI_STYLES.set_hud_font(progress, style_id)


func set_progress(found: int, total: int, complete: bool) -> void:
	progress.text = "線索 %d/%d · 拖曳背景調查" % [found, total]
	continue_button.visible = complete


func set_reduce_motion(reduced: bool) -> void:
	for button: Button in [expand_button, continue_button]:
		if button.has_method("set_reduce_motion"):
			button.call("set_reduce_motion", reduced)
