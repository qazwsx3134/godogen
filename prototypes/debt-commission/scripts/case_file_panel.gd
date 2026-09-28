extends Panel
## 吐槽素材／人物檔案 (scenes/ui/case_file_panel.tscn): tabs, a four-column grid of what the
## player has, and the selected entry's picture and text below. Layout lives in the scene; this
## script fills it. During the timed tsukkomi choice, a material that backs one of the visible
## options offers 「拿來吐槽」, which answers with that option.
## Colors come from ui_styles.gd through each node's `ui_style_role` metadata.

signal closed
signal material_used(option_id: String)

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/case_file_card.tscn")

var _style_id: String = "cinema"
var _entries: Dictionary = {"materials": [], "profiles": []}
var _pictures: Dictionary = {}
var _usable: Dictionary = {}
var _tab: String = "materials"
var _selected: int = 0

@onready var _tabs: Dictionary = {"materials": %CaseFileTab_materials, "profiles": %CaseFileTab_profiles}
@onready var _grid: GridContainer = %CaseFileGrid
@onready var _empty: Label = %CaseFileEmpty
@onready var _picture: TextureRect = %CaseFilePicture
@onready var _detail_name: Label = %CaseFileName
@onready var _detail_text: Label = %CaseFileText
@onready var _use_button: Button = %CaseFileUse


func _ready() -> void:
	visible = false
	for tab_id: String in _tabs.keys():
		(_tabs[tab_id] as Button).pressed.connect(_show_tab.bind(tab_id))
	%CaseFileClose.pressed.connect(func() -> void: closed.emit())
	_use_button.pressed.connect(_on_use_pressed)


func set_style(style_id: String) -> void:
	_style_id = style_id


## The only placement done in code: keep the full-rect panel between the safe-area edges.
func layout(area: Rect2) -> void:
	offset_top = area.position.y
	offset_bottom = area.end.y - get_parent_area_size().y


## case_file: StoryRunner.case_file(). pictures: {id: "res://..."} from the asset catalog.
## usable: {material_id: option_id} for materials that back a visible tsukkomi option now.
func open(case_file: Dictionary, tab: String, pictures: Dictionary, usable: Dictionary = {}) -> void:
	_entries = {"materials": case_file.get("materials", []), "profiles": case_file.get("profiles", [])}
	_pictures = pictures
	_usable = usable
	visible = true
	_show_tab(tab)


func current_tab() -> String:
	return _tab


func _show_tab(tab: String) -> void:
	_tab = tab if tab in ["materials", "profiles"] else "materials"
	for tab_id: String in _tabs.keys():
		UI_STYLES.apply_button(_tabs[tab_id], _style_id, "selector", tab_id == _tab)
	for card: Node in _grid.get_children():
		_grid.remove_child(card)
		card.queue_free()
	var entries: Array = _entries[_tab]
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var card: Button = CARD_SCENE.instantiate() as Button
		card.name = "CaseFileCard_%s" % entry.get("id", index)
		var entry_name: String = str(entry.get("name", entry.get("id", "")))
		(card.get_node("Content/Name") as Label).text = entry_name
		card.get_node("Content/Picture").call("show_item", entry_name, _picture_of(str(entry.get("id", ""))))
		_grid.add_child(card)
		card.pressed.connect(_select.bind(index))
	_empty.text = "還沒有取得吐槽素材。" if _tab == "materials" else "還沒有解鎖人物檔案。"
	_empty.visible = entries.is_empty()
	_select(0)


func _select(index: int) -> void:
	var entries: Array = _entries[_tab]
	_selected = clampi(index, 0, maxi(entries.size() - 1, 0))
	for card_index: int in range(_grid.get_child_count()):
		var card: Button = _grid.get_child(card_index) as Button
		UI_STYLES.apply_button(card, _style_id, "selector", card_index == _selected)
		(card.get_node("Content/Name") as Label).add_theme_color_override("font_color", card.get_theme_color("font_color"))
	var entry: Dictionary = entries[_selected] if not entries.is_empty() else {}
	var entry_id: String = str(entry.get("id", ""))
	_detail_name.text = str(entry.get("name", ""))
	_detail_text.text = str(entry.get("description", entry.get("profile", "")))
	_picture.call("show_item", _detail_name.text, _picture_of(entry_id))
	_picture.visible = not entries.is_empty()  # a placeholder until the entry has art
	_use_button.visible = _tab == "materials" and _usable.has(entry_id)


func _picture_of(entry_id: String) -> Texture2D:
	var path: String = str(_pictures.get(entry_id, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _on_use_pressed() -> void:
	var entries: Array = _entries["materials"]
	if _selected < entries.size():
		var material_id: String = str((entries[_selected] as Dictionary).get("id", ""))
		if _usable.has(material_id):
			material_used.emit(_usable[material_id])
