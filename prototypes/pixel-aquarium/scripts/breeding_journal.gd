extends PanelContainer

signal dismissed
signal locate_fish(id: int)

const State = preload("res://scripts/care_state.gd")
const FAMILY := 1

@onready var _tabs: TabContainer = %JournalTabs
@onready var _history: ItemList = %History
@onready var _tree: VBoxContainer = %Lineage
@onready var _locate: Button = %FindChild

var _state: State
var _child_id := 0


func _ready() -> void:
	%CloseJournal.pressed.connect(func() -> void: dismissed.emit())
	_history.item_selected.connect(_show_child)
	_locate.pressed.connect(func() -> void: locate_fish.emit(_child_id))


func present(state: State, now: int, child_id := 0) -> void:
	_state = state
	_child_id = child_id
	_tabs.current_tab = FAMILY if child_id != 0 else 0
	refresh(now)
	show()


func refresh(now: int) -> void:
	_render_catalog()
	_render_history()
	_render_breeding(now)


func tick(now: int) -> void:
	if _tabs.current_tab == 2:
		_render_breeding(now)


func _render_catalog() -> void:
	for traits in range(State.CARDINAL_EGG + 1):
		var row := %Phenotypes.get_child(traits)
		var date: int = _state.data.discovered.get(traits, -1)
		row.get_node("Date").text = _date(date) if date >= 0 else "尚未發現"
	var badges := PackedStringArray()
	for achievement in ["破殼", "養成一對", "第二代", "月影", "穩定月影家系"]:
		if _state.data.achievements.has(achievement):
			badges.append(achievement)
	%Achievements.text = "已達成　%s" % " · ".join(badges) if not badges.is_empty() else "第一顆卵孵化後就會記下第一個成就。"


func _render_history() -> void:
	var roster: Dictionary = _state.data.archive.merged(_state.data.fish)
	var descendants: Array[int] = []
	for id: int in roster:
		var entry: Dictionary = roster[id]
		if entry.stage != "egg" and entry.parents.size() == 2:
			descendants.append(id)
	descendants.sort_custom(func(a: int, b: int) -> bool:
		var born_a: int = roster[a].born_at
		var born_b: int = roster[b].born_at
		return a < b if born_a == born_b else born_a < born_b
	)
	var first_moon := 0
	for id in descendants:
		if roster[id].species == State.BETTA and roster[id].traits == 3:
			first_moon = id
			break
	_history.clear()
	if descendants.is_empty():
		%HistoryEmpty.show()
		_history.hide()
		_tree.hide()
		return
	%HistoryEmpty.hide()
	_history.show()
	_tree.show()
	var best_index := 0
	for index in range(descendants.size() - 1, -1, -1):
		var id := descendants[index]
		var marks := PackedStringArray()
		if index == 0:
			marks.append("首胎")
		if id == first_moon:
			marks.append("第一尾月影")
		var text := _state.title(roster[id])
		if not marks.is_empty():
			text += " · %s" % "・".join(marks)
		var row := _history.add_item(text)
		_history.set_item_metadata(row, {"id": id, "marks": marks})
		_history.set_item_tooltip(row, text)
		if id == _child_id:
			best_index = row
	_history.select(best_index)
	_history.ensure_current_is_visible()
	_show_child(best_index)


func _show_child(index: int) -> void:
	var item: Dictionary = _history.get_item_metadata(index)
	_child_id = item.id
	var child := _state.fish(_child_id)
	var first := _state.fish(child.parents[0])
	var second := _state.fish(child.parents[1])
	%FirstParent.text = _card_title(first)
	%SecondParent.text = _card_title(second)
	%ChildName.text = _card_title(child)
	var date := "第 %d 胎 · %s" % [child.clutch, _date(child.born_at)]
	%FamilyDate.text = date if item.marks.is_empty() else "%s · %s" % [date, " · ".join(item.marks)]
	var stable: bool = child.species == State.BETTA and child.traits == 3 and first.traits == 3 and second.traits == 3
	%FamilyBadge.visible = stable
	_locate.disabled = not _state.data.fish.has(_child_id) or child.stored
	if child.stored:
		_locate.text = "魚隻在收起清單"
	elif not _state.data.fish.has(_child_id):
		_locate.text = "已送養"
	else:
		_locate.text = "在缸中找到這尾魚"


func _card_title(fish: Dictionary) -> String:
	var phenotype := _state.phenotype(fish)
	return phenotype if fish.name.is_empty() else "%s\n%s" % [fish.name, phenotype]


func _render_breeding(now: int) -> void:
	var eggs := 0
	var hatch_at := 0
	for entry: Dictionary in _state.data.fish.values():
		if entry.stage == "egg" and not entry.stored:
			eggs += 1
			if hatch_at == 0 or entry.born_at < hatch_at:
				hatch_at = entry.born_at
	%HatchStatus.visible = eggs > 0
	%HatchStatus.text = "孵化中 ×%d · %s" % [eggs, _time_left(hatch_at - now)]
	var pair := _state.next_pair()
	if _state.data.fish.size() >= _state.data.capacity:
		%PairStatus.text = "缸位已滿"
	elif pair.is_empty():
		%PairStatus.text = "等待兩尾同種成魚"
	else:
		%PairStatus.text = "配對準備中 · %s" % _time_left(pair.at - now)


func _time_left(seconds: int) -> String:
	var left := maxi(0, seconds)
	return "%d:%02d" % [left / 60, left % 60]


func _date(unix: int) -> String:
	return Time.get_date_string_from_unix_time(unix)
