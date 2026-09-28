extends Panel
## 設定 (scenes/ui/settings_panel.tscn): text speed, auto-play speed, and music and sound volume,
## each a row of choices in the scene (the button's position in its row is the value). main.gd
## keeps the values (settings.gd) and applies them; colours come from ui_styles.gd.

signal changed(key: String, value: int)
signal closed

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")

var _style_id: String = "cinema"
var _values: Dictionary = {}

@onready var close_button: Button = %Close
@onready var _rows: Dictionary = {
	"text_speed": %TextSpeed, "auto_speed": %AutoSpeed, "bgm_volume": %BgmVolume, "se_volume": %SeVolume,
}


func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			(row.get_child(index) as Button).pressed.connect(_pick.bind(key, index))


func set_style(style_id: String) -> void:
	_style_id = style_id


func open(values: Dictionary) -> void:
	_values = values.duplicate()
	_paint()
	visible = true


## Choice buttons by "<key>_<index>", for QA.
func buttons() -> Dictionary:
	var found: Dictionary = {}
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			found["%s_%d" % [key, index]] = row.get_child(index)
	return found


func _pick(key: String, index: int) -> void:
	_values[key] = index
	_paint()
	changed.emit(key, index)


func _paint() -> void:
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			UI_STYLES.apply_button(row.get_child(index) as Button, _style_id, "selector", int(_values.get(key, -1)) == index)
