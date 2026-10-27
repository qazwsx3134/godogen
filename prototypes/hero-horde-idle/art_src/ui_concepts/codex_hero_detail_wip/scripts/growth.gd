extends Control
## 養成 screen: what the player does between pushes, on domain/progression.gd (saved after every change).
##   top      gold and 突破素材; the 行軍小隊 (5 slots: tap one, then 派去行軍 on a hero puts them there)
##   middle   one tab per class: its 職業等級 and level-up button, and its heroes as cards (rarity, level, ★)
##   detail   full-page scenes/hero_detail.tscn: level / cap, EXP, signature, class bonus, 突破 and march target
##   bottom   行軍 1 小時, 一鍵養成, 開始推王 (back to scenes/main.tscn)
## Layout lives in scenes/growth.tscn (tools/build_growth.gd); the cards are scenes/hero_card.tscn instances.

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const Progression = preload("res://domain/progression.gd")
const HeroCard = preload("res://scenes/hero_card.tscn")
const CELL := 48
const PUSH_SCENE := "res://scenes/main.tscn"

## Set before the screen enters the tree to use other progress (tests); otherwise loaded from save_path.
var progress: RefCounted = null
var save_path: String = Progression.SAVE_PATH
var selected_class: int = 0
var selected_hero: int = -1
var selected_slot: int = 0

var _names: PackedStringArray = PushReport.load_names()

@onready var _gold: Label = %Gold
@onready var _shards: Label = %Shards
@onready var _slots: HBoxContainer = %MarchSlots
@onready var _tabs: HBoxContainer = %ClassTabs
@onready var _class_line: Label = %ClassLine
@onready var _class_up: Button = %ClassUp
@onready var _cards: GridContainer = %Cards
@onready var _detail: Control = %Detail
@onready var _toast: Label = %Toast


func _ready() -> void:
	if progress == null:
		progress = Progression.load_from(save_path)
	for c: int in _tabs.get_child_count():
		(_tabs.get_child(c) as Button).pressed.connect(select_class.bind(c))
	for k: int in _slots.get_child_count():
		(_slots.get_child(k) as Button).pressed.connect(_slot_pressed.bind(k))
	_class_up.pressed.connect(func() -> void: _apply(progress.level_class(selected_class)))
	_detail.ascend_requested.connect(func() -> void:
		var changed: bool = progress.ascend(selected_hero)
		_apply(changed)
		if changed:
			_detail.show_feedback("突破成功，等級上限提升至 %d。" % progress.hero_cap(selected_hero)))
	_detail.march_requested.connect(_send_march)
	_detail.back_requested.connect(_close_detail)
	_detail.march_slot_selected.connect(func(slot: int) -> void: selected_slot = slot)
	%MarchHour.pressed.connect(march_hour)
	%AutoSpend.pressed.connect(func() -> void:
		progress.auto_spend()
		_apply(true))
	%StartPush.pressed.connect(start_push)
	_toast.text = ""
	select_class(0)


func select_class(c: int) -> void:
	_close_detail()
	selected_class = c
	selected_hero = -1
	for child: Node in _cards.get_children():
		child.queue_free()
	var heroes: Array[int] = []
	for i: int in Progression.HEROES:
		if Progression.base_class(i) == c:
			heroes.append(i)
	heroes.sort_custom(func(a: int, b: int) -> bool:
		if progress.rarity(a) != progress.rarity(b):
			return progress.rarity(a) > progress.rarity(b)
		return a < b)
	for i: int in heroes:
		var card: Button = HeroCard.instantiate()
		card.hero = i
		_cards.add_child(card)
		card.pressed.connect(select_hero.bind(i))
	if not heroes.is_empty():
		selected_hero = heroes[0]
	_refresh()


func select_hero(i: int) -> void:
	selected_hero = i
	_detail.show_feedback("")
	_refresh()
	$Margins.hide()
	_detail.open()


## 行軍 1 小時: rewards in the toast, then save.
func march_hour() -> void:
	var got: Dictionary = progress.march_hour()
	var parts := PackedStringArray(["金幣 +%d" % got.gold])
	if got.shards > 0:
		parts.append("突破素材 +%d" % got.shards)
	for i: int in got.levels:
		parts.append("%s 升到 Lv%d" % [PushReport.hero_name(_names, i), progress.hero_level[i]])
	_toast.text = "行軍回來了：" + "、".join(parts)
	_apply(true)


func start_push() -> void:
	progress.save(save_path)
	get_tree().change_scene_to_file(PUSH_SCENE)


func _slot_pressed(k: int) -> void:
	selected_slot = k
	select_hero(progress.march[k])


func _send_march() -> void:
	if selected_hero < 0 or progress.in_march(selected_hero):
		return
	progress.set_march(selected_slot, selected_hero)
	_toast.text = "%s 加入行軍小隊" % PushReport.hero_name(_names, selected_hero)
	_apply(true)
	_detail.show_feedback("已加入行軍第 %d 格。" % (selected_slot + 1))


func _apply(changed: bool) -> void:
	if changed:
		progress.save(save_path)
	_refresh()


func _refresh() -> void:
	_gold.text = "金幣 %d" % progress.gold
	_shards.text = "突破素材 %d" % progress.shards
	for c: int in _tabs.get_child_count():
		(_tabs.get_child(c) as Button).button_pressed = c == selected_class
	var cost: int = progress.class_cost(selected_class)
	_class_line.text = "%s 職業等級 %d　全職業英雄 ×%.2f" % [PushSim.CLASS_NAMES[selected_class],
		progress.class_level[selected_class], pow(Progression.CLASS_STEP, progress.class_level[selected_class] - 1)]
	_class_up.text = "升級（%d 金）" % cost
	_class_up.disabled = progress.gold < cost
	for k: int in _slots.get_child_count():
		var slot: Button = _slots.get_child(k)
		_show_card(slot, progress.march[k])
		slot.button_pressed = k == selected_slot
	for card: Node in _cards.get_children():
		if card.is_queued_for_deletion():
			continue
		_show_card(card, card.hero)
		card.button_pressed = card.hero == selected_hero
	_show_detail()


func _show_card(card: Node, i: int) -> void:
	var r: int = progress.rarity(i)
	var line: String = "%s Lv%d%s" % [PushSim.RARITY_NAMES[r], progress.hero_level[i], " ★%d" % progress.ascension[i] if progress.ascension[i] > 0 else ""]
	card.show_hero(i, _region(i), PushReport.hero_name(_names, i), r, line, progress.in_march(i))


func _close_detail() -> void:
	_detail.hide()
	$Margins.show()
	if selected_hero >= 0:
		for card: Node in _cards.get_children():
			if not card.is_queued_for_deletion() and card.hero == selected_hero:
				card.grab_focus()
				break


func _show_detail() -> void:
	if selected_hero >= 0:
		_detail.show_hero(progress, selected_hero, PushReport.hero_name(_names, selected_hero), selected_slot)


func _region(i: int) -> Rect2:
	return Rect2(4 * CELL, Progression.base_class(i) * CELL, CELL, CELL)
