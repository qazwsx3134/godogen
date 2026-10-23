extends Panel
## 設定 (scenes/ui/settings_panel.tscn): text speed, auto-play speed, music and sound volume, reading
## size and paper, 畫面效果 and 吐槽輔助, each a row of choices in the scene (the button's position in
## its row is the value), and 介面風格, whose buttons pick the UI edition (style_picked). main.gd
## keeps the values (settings.gd) and applies them. Colours come from ui_styles.gd, except in an
## edition scene with `paint_from_style` off (settings_panel_gintama.tscn): its buttons are toggles
## styled in the scene, and the chosen one is shown pressed. 存檔備份 asks main.gd to export or import
## every save (save_transfer.gd); importing is only offered from the title.

signal changed(key: String, value: int)
signal style_picked(style_id: String)
signal closed
signal export_saves
signal import_saves

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
## The 介面風格 row's buttons, in order.
const STYLE_IDS: Array[String] = ["cinema", "ledger", "manga", "gintama"]

## Off: the scene's own StyleBoxes are kept and the chosen choice is the pressed toggle.
@export var paint_from_style: bool = true

var _style_id: String = "cinema"
var _values: Dictionary = {}

@onready var close_button: Button = %Close
@onready var _rows: Dictionary = {
	"text_speed": %TextSpeed, "auto_speed": %AutoSpeed, "bgm_volume": %BgmVolume, "se_volume": %SeVolume,
	"font_size": %FontSize, "paper_opacity": %PaperOpacity, "motion": %Motion, "assist": %Assist,
}
@onready var _style_row: Container = %UiStyle
@onready var export_button: Button = %SavesExport
@onready var import_button: Button = %SavesImport


func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	export_button.pressed.connect(func() -> void: export_saves.emit())
	import_button.pressed.connect(func() -> void: import_saves.emit())
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			(row.get_child(index) as Button).pressed.connect(_pick.bind(key, index))
	for index: int in range(STYLE_IDS.size()):
		(_style_row.get_child(index) as Button).pressed.connect(func() -> void:
			_paint()  # a toggle pressed again stays shown as the current edition
			style_picked.emit(STYLE_IDS[index]))


func set_style(style_id: String) -> void:
	_style_id = style_id


## import_allowed: false while a story is open (目錄), where an import would pull saves from under it.
func open(values: Dictionary, import_allowed: bool = true) -> void:
	_values = values.duplicate()
	import_button.disabled = not import_allowed
	import_button.text = "匯入存檔" if import_allowed else "匯入存檔（回標題）"
	_paint()
	visible = true


## Choice buttons by "<key>_<index>", for QA.
func buttons() -> Dictionary:
	var found: Dictionary = {}
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			found["%s_%d" % [key, index]] = row.get_child(index)
	for index: int in range(STYLE_IDS.size()):
		found["ui_style_" + STYLE_IDS[index]] = _style_row.get_child(index)
	found["saves_export"] = export_button
	found["saves_import"] = import_button
	return found


func _pick(key: String, index: int) -> void:
	_values[key] = index
	_paint()
	changed.emit(key, index)


func _paint() -> void:
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			var chosen: bool = int(_values.get(key, -1)) == index
			if paint_from_style:
				UI_STYLES.apply_button(row.get_child(index) as Button, _style_id, "selector", chosen)
			else:
				(row.get_child(index) as Button).set_pressed_no_signal(chosen)
	if paint_from_style:
		for button: Button in [export_button, import_button]:
			UI_STYLES.apply_button(button, _style_id, "standard")
	for index: int in range(STYLE_IDS.size()):
		var current: bool = STYLE_IDS[index] == _style_id
		if paint_from_style:
			UI_STYLES.apply_button(_style_row.get_child(index) as Button, _style_id, "selector", current)
		else:
			(_style_row.get_child(index) as Button).set_pressed_no_signal(current)
