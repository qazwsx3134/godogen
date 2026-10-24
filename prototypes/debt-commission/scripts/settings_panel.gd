extends Panel
## 設定 (scenes/ui/settings_panel_gintama.tscn): text speed, auto-play speed, music and sound volume,
## reading size and paper, 畫面效果, 吐槽輔助 and 教學提示 (with 重看教學), each a row of toggles styled in the scene (the
## button's position in its row is the value; the chosen one shows pressed). main.gd keeps the
## values (settings.gd) and applies them. 存檔備份 asks main.gd to export or import every save
## (save_transfer.gd); importing is only offered from the title.

signal changed(key: String, value: int)
signal closed
signal export_saves
signal import_saves
signal replay_tutorials

var _values: Dictionary = {}

@onready var close_button: Button = %Close
@onready var _rows: Dictionary = {
	"text_speed": %TextSpeed, "auto_speed": %AutoSpeed, "bgm_volume": %BgmVolume, "se_volume": %SeVolume,
	"font_size": %FontSize, "paper_opacity": %PaperOpacity, "motion": %Motion, "assist": %Assist,
	"tutorial": %Tutorial,
}
@onready var export_button: Button = %SavesExport
@onready var import_button: Button = %SavesImport


func _ready() -> void:
	visible = false
	close_button.pressed.connect(func() -> void: closed.emit())
	export_button.pressed.connect(func() -> void: export_saves.emit())
	import_button.pressed.connect(func() -> void: import_saves.emit())
	%TutorialReplay.pressed.connect(func() -> void:
		%TutorialReplay.disabled = true  # once per opening; it only clears the "seen" list
		replay_tutorials.emit())
	for key: String in _rows.keys():
		var row: Container = _rows[key]
		for index: int in range(row.get_child_count()):
			(row.get_child(index) as Button).pressed.connect(_pick.bind(key, index))


## import_allowed: false while a story is open (目錄), where an import would pull saves from under it.
## gameplay: false for a story without rounds or searches, which hides the 輔助 row.
func open(values: Dictionary, import_allowed: bool = true, gameplay: bool = true) -> void:
	_values = values.duplicate()
	for node_name: String in ["AssistRule", "AssistLabel", "Assist"]:
		var node: Control = find_child(node_name, true, false) as Control
		if node != null:
			node.visible = gameplay
	import_button.disabled = not import_allowed
	%TutorialReplay.disabled = false
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
			(row.get_child(index) as Button).set_pressed_no_signal(int(_values.get(key, -1)) == index)
