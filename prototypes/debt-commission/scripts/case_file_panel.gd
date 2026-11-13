extends Panel
## 吐槽素材／人物檔案 (scenes/ui/case_file_panel.tscn): tabs, a row of tall cards (CardStrip, scrolls
## sideways) — what the player has, then a dark blank with a Roman numeral for each one the story still
## holds — and below it the selected entry's status card — a ◆ ribbon, the name on a plaque,
## its place in the list and whether it can be used now beside the picture in a ring, then ◆ 說明
## and, while it can answer the timed choice, ◆ 拿來吐槽. Layout lives in the scene; this
## script fills it. During the timed tsukkomi choice, a material that backs one of the visible
## options offers 「拿來吐槽」, which answers with that option.
## Colors come from ui_styles.gd through each node's `ui_style_role` metadata.

signal closed
signal material_used(option_id: String)

const UI_STYLES: Script = preload("res://scripts/ui_styles.gd")
const CARD_SCENE: PackedScene = preload("res://scenes/ui/case_file_card.tscn")

var _style_id: String = "gintama"
## The skin's words (skin.gd terms): rebut, materials, …
var terms: Dictionary = {"rebut": "吐槽", "materials": "吐槽素材"}
var _entries: Dictionary = {"materials": [], "profiles": []}
## How many each tab can hold in this story (StoryRunner.case_file() material_total / profile_total).
var _totals: Dictionary = {"materials": 0, "profiles": 0}
const NUMERALS: Array[String] = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ"]
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
@onready var _kind: Label = %CaseFileKind
@onready var _order: Label = %CaseFileOrder
@onready var _status: Label = %CaseFileStatus
@onready var _use_head: Label = %CaseFileUseHead
@onready var _plaque: PanelContainer = %CaseFileNamePlaque
@onready var _ring: PanelContainer = %CaseFileRing
@onready var _detail: Control = %CaseFileDetail


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
	_totals = {"materials": int(case_file.get("material_total", 0)), "profiles": int(case_file.get("profile_total", 0))}
	_pictures = pictures
	_usable = usable
	visible = true
	_show_tab(tab)


func current_tab() -> String:
	return _tab


func _show_tab(tab: String) -> void:
	_tab = tab if tab in ["materials", "profiles"] else "materials"
	for tab_id: String in _tabs.keys():
		UI_STYLES.apply_button(_tabs[tab_id], _style_id, "tab", tab_id == _tab)  # selected and not look different
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
	for blank: int in range(entries.size(), maxi(int(_totals[_tab]), entries.size())):
		_grid.add_child(_blank_card(blank))
	_empty.text = "還沒有取得%s。" % terms["materials"] if _tab == "materials" else "還沒有解鎖人物檔案。"
	_empty.visible = entries.is_empty()
	_select(0)


func _select(index: int) -> void:
	var entries: Array = _entries[_tab]
	_selected = clampi(index, 0, maxi(entries.size() - 1, 0))
	for card_index: int in range(entries.size()):
		var card: Button = _grid.get_child(card_index) as Button
		UI_STYLES.apply_button(card, _style_id, "selector" if card_index == _selected else "standard", card_index == _selected)
		(card.get_node("Content/Name") as Label).add_theme_color_override("font_color", card.get_theme_color("font_color"))
	var entry: Dictionary = entries[_selected] if not entries.is_empty() else {}
	var entry_id: String = str(entry.get("id", ""))
	_detail_name.text = str(entry.get("name", ""))
	_detail_text.text = str(entry.get("description", entry.get("profile", "")))
	_picture.call("show_item", _detail_name.text, _picture_of(entry_id))
	_detail.visible = not entries.is_empty()
	var usable: bool = _tab == "materials" and _usable.has(entry_id)
	_use_button.visible = usable
	_use_head.visible = usable
	_kind.text = "◆ %s情報" % terms["materials"] if _tab == "materials" else "◆ 人物檔案"
	var total: int = maxi(int(_totals[_tab]), entries.size())  # found and still hidden
	_order.text = "第 %d 件／共 %d 件" % [_selected + 1, total] if _tab == "materials" \
		else "第 %d 人／共 %d 人" % [_selected + 1, total]
	_status.text = ("現在可以拿來%s！" % terms["rebut"] if usable else "收在案件檔裡，%s時可以拿出來" % terms["rebut"]) if _tab == "materials" \
		else "已解鎖的人物檔案"
	_paint_card()


## A card the player has not found yet: dark, inert, numbered in the order it would come.
func _blank_card(index: int) -> Button:
	var card: Button = CARD_SCENE.instantiate() as Button
	card.name = "CaseFileBlank_%d" % (index + 1)
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.get_node("Content").visible = false
	var numeral: Label = card.get_node("Numeral")
	numeral.text = NUMERALS[index] if index < NUMERALS.size() else str(index + 1)
	numeral.visible = true
	var dark: StyleBoxFlat = StyleBoxFlat.new()
	dark.bg_color = Color(0.07, 0.08, 0.11, 0.92)
	dark.border_color = Color(0.55, 0.58, 0.64, 0.6)
	dark.set_border_width_all(3)
	dark.set_corner_radius_all(14)
	for state: String in ["normal", "disabled", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, dark)
	return card


## The plaque, the picture ring and the plaque's ink in the current edition.
func _paint_card() -> void:
	var p: Dictionary = UI_STYLES.palette(_style_id)
	_plaque.add_theme_stylebox_override("panel", UI_STYLES.name_plaque(_style_id))
	_detail_name.add_theme_color_override("font_color", p["name_ink"] as Color)
	UI_STYLES.set_hud_font(_detail_name, _style_id)
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.bg_color = p["panel_soft"] as Color
	ring.border_color = p["rule"] as Color
	ring.set_border_width_all(6)
	ring.set_corner_radius_all(150)
	ring.set_content_margin_all(28.0)
	ring.shadow_color = Color(0.06, 0.1, 0.18, 0.25)
	ring.shadow_size = 6
	_ring.add_theme_stylebox_override("panel", ring)


func _picture_of(entry_id: String) -> Texture2D:
	var path: String = str(_pictures.get(entry_id, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _on_use_pressed() -> void:
	var entries: Array = _entries["materials"]
	if _selected < entries.size():
		var material_id: String = str((entries[_selected] as Dictionary).get("id", ""))
		if _usable.has(material_id):
			material_used.emit(_usable[material_id])
