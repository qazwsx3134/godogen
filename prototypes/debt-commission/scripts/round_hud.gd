extends MarginContainer
## The gameplay HUD (scenes/ui/round_hud.tscn) under the place name: the glasses (life) and the
## 吐槽之力 gauge, then the combo count and the tsukkomi countdown; below the panel, a column of the
## clues found so far on the right edge. One scene for every edition; set_style tints it.

const GLASSES_ICON: PackedScene = preload("res://scenes/ui/glasses_icon.tscn")
const CLUE_CHIP: PackedScene = preload("res://scenes/ui/clue_chip.tscn")

const TINTS: Dictionary = {
	"cinema": {"bg": Color(0.031, 0.063, 0.098, 0.82), "border": Color(0.65, 0.8, 0.81, 0.5), "width": 1,
		"text": Color("#e6e5dc"), "soft": Color("#bec9c9"), "gauge": Color("#a9d0cf"), "alert": Color("#ffb2a1")},
	"ledger": {"bg": Color(0.949, 0.91, 0.824, 0.95), "border": Color("#b9a681"), "width": 1,
		"text": Color("#382f28"), "soft": Color("#76634c"), "gauge": Color("#a94432"), "alert": Color("#8f2d22")},
	"manga": {"bg": Color("#f5f3e9"), "border": Color("#242522"), "width": 2,
		"text": Color("#242522"), "soft": Color("#5f605b"), "gauge": Color("#e4be32"), "alert": Color("#e74e36")},
}

@onready var panel: PanelContainer = %Panel
## One glasses_icon.tscn per pair; show_stats matches the story's max glasses.
@onready var glasses: HBoxContainer = %Glasses
@onready var power_bar: ProgressBar = %PowerBar
@onready var power_value: Label = %PowerValue
@onready var combo: Label = %Combo
@onready var timer: Label = %Timer
@onready var clues: Control = %Clues
@onready var clue_header: Label = %ClueHeader
## One clue_chip.tscn per clue, in the order they were found.
@onready var clue_list: VBoxContainer = %ClueList
var _tint: Dictionary = TINTS["cinema"]


func set_style(style_id: String) -> void:
	var tint: Dictionary = TINTS.get(style_id, TINTS["cinema"])
	_tint = tint
	var unit: float = 1080.0 / 390.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = tint["bg"]
	box.border_color = tint["border"]
	box.set_border_width_all(roundi(float(tint["width"]) * unit))
	box.set_corner_radius_all(roundi(2 * unit))
	panel.add_theme_stylebox_override("panel", box)
	for label: Label in [power_value, combo, find_child("PowerCaption") as Label]:
		label.add_theme_color_override("font_color", tint["text"])
	timer.add_theme_color_override("font_color", tint["alert"])
	clue_header.add_theme_color_override("font_color", Color.WHITE if style_id == "cinema" else tint["text"])
	for icon: Control in glasses.get_children():
		_paint_icon(icon)
	for chip: Control in clue_list.get_children():
		_paint_chip(chip)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.draw_center = false
	track.border_color = Color(tint["text"], 0.6)
	track.set_border_width_all(maxi(1, roundi(unit)))
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = tint["gauge"]
	power_bar.add_theme_stylebox_override("background", track)
	power_bar.add_theme_stylebox_override("fill", fill)


func show_stats(glasses_left: int, max_glasses: int, power: int, max_power: int, combo_count: int) -> void:
	while glasses.get_child_count() > max_glasses:
		glasses.get_child(-1).free()
	while glasses.get_child_count() < max_glasses:
		var icon: Control = GLASSES_ICON.instantiate() as Control
		glasses.add_child(icon)
		_paint_icon(icon)
	for index: int in range(max_glasses):
		glasses.get_child(index).set("broken", index >= glasses_left)
	power_bar.max_value = max_power
	power_bar.value = power
	power_value.text = "%d/%d" % [power, max_power]
	combo.text = "連擊 ×%d" % combo_count
	combo.visible = combo_count > 0


## Clues in the order they were found, each {name, picture} (picture null: the placeholder); the
## column hides while there are none.
func show_clues(entries: Array[Dictionary]) -> void:
	while clue_list.get_child_count() > entries.size():
		clue_list.get_child(-1).free()
	while clue_list.get_child_count() < entries.size():
		var chip: Control = CLUE_CHIP.instantiate() as Control
		clue_list.add_child(chip)
		_paint_chip(chip)
	for index: int in range(entries.size()):
		var chip: Control = clue_list.get_child(index) as Control
		(chip.get_node("Row/Name") as Label).text = str(entries[index]["name"])
		chip.get_node("Row/Picture").call("show_item", str(entries[index]["name"]), entries[index]["picture"])
	clues.visible = not entries.is_empty()


func _paint_icon(icon: Control) -> void:
	icon.set("color", _tint["text"])
	icon.set("crack_color", _tint["alert"])


func _paint_chip(chip: Control) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _tint["bg"]
	box.border_color = _tint["border"]
	box.set_border_width_all(roundi(float(_tint["width"]) * 1080.0 / 390.0))
	box.set_content_margin_all(roundf(6.0 * 1080.0 / 390.0))
	chip.add_theme_stylebox_override("panel", box)
	(chip.get_node("Row/Name") as Label).add_theme_color_override("font_color", _tint["text"])
