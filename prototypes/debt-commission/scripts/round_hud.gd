extends MarginContainer
## The gameplay HUD (scenes/ui/round_hud.tscn) under the place name: the glasses (life) and the
## 吐槽之力 gauge, then the combo count and the tsukkomi countdown; below the panel on the right edge,
## a small 「線索 ×N」 tag (the clues themselves are in 案件檔, so they never cover the stage).
## One scene for every edition; set_style tints it.

const GLASSES_ICON: PackedScene = preload("res://scenes/ui/glasses_icon.tscn")
const CLUE_CHIP: PackedScene = preload("res://scenes/ui/clue_chip.tscn")
const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")

## The HUD's colours from the skin's palette (ui_styles.gd).
static func tint_of(style_id: String) -> Dictionary:
	var p: Dictionary = UI_STYLES.palette(style_id)
	return {"bg": Color(p["panel_soft"] as Color, 0.94), "border": p["rule"], "width": 1, "text": p["text"],
		"soft": p["muted"], "gauge": p["accent"], "alert": p["danger"]}

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
var _tint: Dictionary = {}
## The life icon scene (the skin's `life_icon`): broken, charged, color and crack_color properties.
var life_icon: PackedScene = GLASSES_ICON
var _style_id: String = "cinema"
## 畫面效果 減少: the numbers still change, without the pops.
var reduce_motion: bool = false
## What the last show_stats showed, so only a change pops: [glasses left, power, combo]; -1 = nothing yet.
var _shown: Array[int] = [-1, -1, -1]


func set_style(style_id: String) -> void:
	var tint: Dictionary = tint_of(style_id)
	_tint = tint
	_style_id = style_id
	var unit: float = 1080.0 / 390.0
	panel.add_theme_stylebox_override("panel", _panel_box(tint["width"]))
	for label: Label in [power_value, combo, timer, clue_header, find_child("PowerCaption") as Label]:
		UI_STYLES.set_hud_font(label, style_id)
	for label: Label in [power_value, combo, find_child("PowerCaption") as Label]:
		label.add_theme_color_override("font_color", tint["text"])
	timer.add_theme_color_override("font_color", tint["alert"])
	clue_header.add_theme_color_override("font_color", tint["text"])
	UI_STYLES.set_hud_font(clue_header, style_id)
	var chip_box: StyleBox = UI_STYLES.hud_resource(style_id, "clue_chip") as StyleBox
	if chip_box != null:
		clue_header.add_theme_stylebox_override("normal", chip_box)
	else:
		clue_header.remove_theme_stylebox_override("normal")
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


## Uses another life icon scene; the row is rebuilt on the next show_stats.
func set_life_icon(scene: PackedScene) -> void:
	if scene == null or scene == life_icon:
		return
	life_icon = scene
	for icon: Node in glasses.get_children():
		glasses.remove_child(icon)
		icon.queue_free()


func show_stats(glasses_left: int, max_glasses: int, power: int, max_power: int, combo_count: int) -> void:
	while glasses.get_child_count() > max_glasses:
		glasses.get_child(-1).free()
	while glasses.get_child_count() < max_glasses:
		var icon: Control = life_icon.instantiate() as Control
		glasses.add_child(icon)
		_paint_icon(icon)
	for index: int in range(max_glasses):
		glasses.get_child(index).set("broken", index >= glasses_left)
		glasses.get_child(index).set("charged", power >= max_power and max_power > 0)
	power_bar.max_value = max_power
	power_bar.value = power
	power_value.text = "%d/%d" % [power, max_power]
	combo.text = "連擊 ×%d" % combo_count
	combo.visible = combo_count > 0
	if _shown[0] >= 0:
		for index: int in range(glasses_left, mini(_shown[0], max_glasses)):
			_pop(glasses.get_child(index) as Control, 1.45, Color(1.0, 0.45, 0.4))  # this pair just broke
		if power > _shown[1]:
			_pop(power_value, 1.3, Color(1.0, 0.92, 0.55))
		if combo_count > _shown[2] and combo_count > 0:
			_pop(combo, 1.35, Color.WHITE)
	_shown = [glasses_left, power, combo_count]


## Forget what was shown, so the next show_stats pops nothing: a save loaded or a story started
## shows its own count, not a change.
func reset_pops() -> void:
	_shown = [-1, -1, -1]


## A quick punch: grows to `peak` tinted `flash`, then springs back. Scale and tint only, so the
## containers keep their layout. The tween starts `from` the peak on purpose: a container re-sorting
## (the label's text just changed) resets its children's scale at the end of this frame, and a tween
## that read its start value then would run from 1 to 1.
func _pop(item: Control, peak: float, flash: Color) -> void:
	if reduce_motion or item == null or not item.is_inside_tree():
		return
	if item.has_meta("pop_tween"):
		(item.get_meta("pop_tween") as Tween).kill()
	item.pivot_offset = item.size * 0.5
	item.scale = Vector2.ONE * peak
	item.modulate = flash
	var tween: Tween = item.create_tween().set_parallel()
	tween.tween_property(item, "scale", Vector2.ONE, 0.28).from(Vector2.ONE * peak) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate", Color.WHITE, 0.3).from(flash)
	item.set_meta("pop_tween", tween)


## Clues in the order they were found, each {name, picture} (picture null: the placeholder). The tag
## shows their count; it hides while there are none or when `shown` is false (while searching, the
## folded search bar already counts them).
func show_clues(entries: Array[Dictionary], shown: bool = true) -> void:
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
	clue_list.visible = false
	clue_header.text = "線索 ×%d" % entries.size()
	clues.visible = shown and not entries.is_empty()


func _paint_icon(icon: Control) -> void:
	icon.set("color", _tint["text"])
	icon.set("crack_color", _tint["alert"])


func _paint_chip(chip: Control) -> void:
	var chip_box: StyleBox = UI_STYLES.hud_resource(_style_id, "clue_chip") as StyleBox
	if chip_box != null:
		chip.add_theme_stylebox_override("panel", chip_box)
	else:
		var box: StyleBoxFlat = _panel_box(_tint["width"])
		box.set_corner_radius_all(0)
		box.set_content_margin_all(roundf(6.0 * 1080.0 / 390.0))
		chip.add_theme_stylebox_override("panel", box)
	var chip_name: Label = chip.get_node("Row/Name") as Label
	chip_name.add_theme_color_override("font_color", _tint["text"])
	UI_STYLES.set_hud_font(chip_name, _style_id)


## The panel behind the stats (and, square, the clue chips) in this edition; the gintama
## skin's `hud.panel` when it has one (the base skin's is assets/ui/gintama_hud/hud_panel.tres).
func _panel_box(width: float) -> StyleBoxFlat:
	var own: StyleBox = UI_STYLES.hud_resource(_style_id, "panel") as StyleBox
	if own is StyleBoxFlat:
		return own as StyleBoxFlat
	var unit: float = 1080.0 / 390.0
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _tint["bg"]
	box.border_color = _tint["border"]
	box.set_border_width_all(roundi(width * unit))
	box.set_corner_radius_all(roundi(2 * unit))
	return box
