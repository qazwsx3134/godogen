extends Control
## 總覽 (scenes/pages/overview.tscn, Taskbar Hero's idel.png page): where the march is, the squad's leader, the five
## march slots, the bonds, what can be done now (progression.gd todo(); a row opens its page) and the march log the
## home screen keeps.

signal changed
signal open_tab(tab: StringName)
signal message(text: String)

const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const Heroes = preload("res://domain/heroes.gd")
const PushSim = preload("res://domain/push_sim.gd")
const Portraits = preload("res://scripts/portraits.gd")
const Army = preload("res://scripts/army.gd")
const Names = preload("res://domain/push_report.gd")

var progress: RefCounted = null
var names := PackedStringArray()
## The march log's lines, newest last (the home screen fills it).
var log_lines: PackedStringArray = []
var _todo: Array = []
## Rows of 可以做的事 that fit above the log (the rest wait their turn).
const TODO_ROWS := 3


func _ready() -> void:
	for k: int in %TodoList.get_child_count():
		(%TodoList.get_child(k) as Button).pressed.connect(func() -> void:
			if k < _todo.size():
				open_tab.emit(_todo[k].tab))


func refresh() -> void:
	if progress == null:
		return
	if names.is_empty():
		names = Names.load_names()
	var stage: int = progress.march_stage
	%MarchStatus.text = "行軍中：%s %s　·　下一個關卡王 %s %s" % [Stages.label(stage), Stages.REGIONS[Stages.region(stage)].name,
		Stages.label(progress.next_stage()), Stages.boss_name(progress.next_stage())]
	var leader: int = progress.march[0]
	var c: int = Progression.base_class(leader)
	var f: int = Heroes.form(leader)
	%LeaderPortrait.texture = Portraits.hero_full(f, c)
	%LeaderName.text = "%s　%s%s　Lv.%d" % [Names.hero_name(names, leader), Heroes.FORM_NAMES[f], PushSim.CLASS_NAMES[c],
		progress.hero_level[leader]]
	%SquadLine.text = "行軍小隊 %d／%d　·　擊倒 %d　·　每次擊倒 %d 金幣" % [progress.march.size(), progress.slots(),
		progress.march_kills, progress.kill_gold(stage)]
	for k: int in %SquadRow.get_child_count():
		var card: Control = %SquadRow.get_child(k)
		card.visible = k < progress.slots()
		if not card.visible:
			continue
		var icon: TextureRect = card.get_node("Icon")
		if k < progress.march.size():
			var i: int = progress.march[k]
			icon.texture = Portraits.hero_sprite(Heroes.form(i), Progression.base_class(i))
			icon.self_modulate = Portraits.tint(i, Progression.base_class(i))
			(card.get_node("Title") as Label).text = Names.hero_name(names, i)
			(card.get_node("Level") as Label).text = "Lv.%d" % progress.hero_level[i]
			(card.get_node("EquippedBy") as Label).text = Heroes.FORM_NAMES[Heroes.form(i)]
		else:
			icon.texture = null
			(card.get_node("Title") as Label).text = "空位"
			(card.get_node("Level") as Label).text = ""
			(card.get_node("EquippedBy") as Label).text = "去英雄頁上陣"
	var bonds: Dictionary = progress.bonds()
	%BondLabel.text = "羈絆：" + ("、".join(bonds.lines) if not bonds.lines.is_empty() else "同形態 2 人以上就有羈絆")
	_todo = progress.todo().slice(0, TODO_ROWS)
	for k: int in %TodoList.get_child_count():
		var b: Button = %TodoList.get_child(k)
		b.visible = k < _todo.size()
		if b.visible:
			b.text = "　▶ " + _todo[k].text
	if _todo.is_empty():
		%TodoList.get_child(0).visible = true
		(%TodoList.get_child(0) as Button).text = "　小隊正在行軍，回來時會有收穫"
	show_log()


func show_log() -> void:
	%CombatLog.text = "\n".join(log_lines.slice(maxi(0, log_lines.size() - 40)))
	await get_tree().process_frame
	if is_inside_tree():
		%CombatLogScroll.scroll_vertical = int(%CombatLogScroll.get_v_scroll_bar().max_value)
