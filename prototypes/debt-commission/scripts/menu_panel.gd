extends Control
## 目錄 (scenes/ui/menu_panel_gintama.tscn; washi rows from menu_row_washi.tscn, the navy quick rows from menu_row_gintama.tscn): a dimmed
## screen with a centred panel, heading and ×, then the rows (回到故事 first). On a short screen the
## rows scroll (fit).
## main.gd decides what each row does and which rows show.

signal closed
signal row_pressed(row_id: String)

@export var style_id: String = "gintama"

## Full-screen margin around the panel; main.gd scales it up on narrow phones.
@onready var area: Control = %Area
@onready var panel: Control = %Panel
@onready var close_button: Button = %Close
@onready var rows_scroll: ScrollContainer = %RowsScroll
@onready var row_list: Container = %Rows
@onready var rows: Dictionary = {
	"resume": %Resume, "save": %Save, "load": %Load, "material": %Material, "profile": %Profile,
	"log": %Log, "skip": %Skip, "mute": %Mute, "settings": %Settings, "title": %Title,
	"rollback": %Rollback, "quick_save": %QuickSave, "quick_load": %QuickLoad,
}


func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())
	%Dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	for row_id: String in rows.keys():
		(rows[row_id] as Button).pressed.connect(func() -> void: row_pressed.emit(row_id))
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)


func set_row_hint(row_id: String, hint: String) -> void:
	((rows[row_id] as Button).get_node("%Hint") as Label).text = hint




## Height the panel may take, in this scene's own pixels: the rows scroll past it.
func fit(max_height: float) -> void:
	rows_scroll.custom_minimum_size.y = 0.0
	var fixed: float = panel.get_combined_minimum_size().y
	rows_scroll.custom_minimum_size.y = clampf(max_height - fixed, 0.0, row_list.get_combined_minimum_size().y)


## The panel pops in from 70 %.
func pop_in() -> Tween:
	panel.scale = Vector2(0.7, 0.7)
	panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.1)
	return tween
