extends Control
## 關卡 (the third page of scenes/home.tscn): every stage under its region's heading, with its first-clear reward
## (cleared ones replayable), the next one marked, locked ones greyed; tapping an open one starts its push. Layout lives in scenes/stages.tscn
## (tools/build_shell.gd); the rows are scenes/stage_row.tscn instances.

const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const StageRow = preload("res://scenes/stage_row.tscn")

## Set before the page enters the tree to use other progress (tests); otherwise the App's.
var progress: RefCounted = null
## Where the last row sent the player (tests read it when there is no App).
var went: Dictionary = {}

@onready var _list: VBoxContainer = %StageList


func _ready() -> void:
	if progress == null:
		var app: Node = get_node_or_null(^"/root/App")
		progress = app.progress() if app != null else Progression.load_from(Progression.SAVE_PATH)
	for child: Node in _list.get_children():
		child.queue_free()
	for r: int in Stages.REGIONS.size():
		var header := Label.new()
		header.theme_type_variation = &"Dim"
		header.add_theme_font_size_override(&"font_size", 24)
		header.text = Stages.REGIONS[r].name
		_list.add_child(header)
		var last: int = Stages.REGIONS[r + 1].first - 1 if r + 1 < Stages.REGIONS.size() else Stages.COUNT
		for n: int in range(Stages.REGIONS[r].first, last + 1):
			var row: Button = StageRow.instantiate()
			_list.add_child(row)
			row.stage = n
			row.pressed.connect(push.bind(n))
	refresh()


func refresh() -> void:
	for row: Node in _list.get_children():
		if row.is_queued_for_deletion() or not row is Button:
			continue
		var n: int = row.stage
		var state: int = 2 if n <= progress.cleared else (1 if progress.unlocked(n) else 0)
		var note: String = "可重打" if n <= progress.cleared else "首通獎勵　金幣 +%d　突破素材 +%d" % [
			roundi(Stages.FIRST_GOLD * Stages.stage(n).reward), Stages.FIRST_SHARDS]
		row.show_stage(n, Stages.label(n), Stages.boss_name(n), note, state)


## Goes to the push of stage n (when it is open).
func push(n: int) -> void:
	if not progress.unlocked(n):
		return
	went = {"where": &"push", "hand": {"stage_n": n}}
	var app: Node = get_node_or_null(^"/root/App")
	if app != null:
		app.go(app.PUSH, {"stage_n": n})
