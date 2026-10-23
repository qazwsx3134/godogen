extends Control
## 養成 screen: what the player does between pushes, on domain/progression.gd (saved after every change).
##   roster     gold and 突破素材 with 一鍵養成; the 行軍小隊 (5 slots: tap one to open that hero; 派去行軍 on another
##              hero's page puts them in that slot); one tab per class with its 職業等級 and 升級; the class's heroes
##              as cards. It is the second page of scenes/home.tscn (the nav bar moves between pages)
##   hero page  the tapped hero (scenes/hero_page.tscn): 突破, 派去行軍 and 設為隊長; 英雄名冊 goes back to the roster.
##              It covers the roster (the home's nav bar stays under it)
## Layout lives in scenes/growth.tscn (tools/build_growth.gd); the cards are scenes/hero_card.tscn instances.

const PushSim = preload("res://domain/push_sim.gd")
const PushReport = preload("res://domain/push_report.gd")
const Progression = preload("res://domain/progression.gd")
const Portraits = preload("res://scripts/portraits.gd")
const HeroCard = preload("res://scenes/hero_card.tscn")

## Set before the screen enters the tree to use other progress (tests); otherwise loaded from save_path.
var progress: RefCounted = null
## "" = the App's progress_path (the player's save), or Progression.SAVE_PATH without the App.
var save_path: String = ""
var selected_class: int = 0
## The hero on the hero page (-1 = the roster is showing).
var selected_hero: int = -1
var selected_slot: int = 0

var _names: PackedStringArray = PushReport.load_names()
## Each hero's 招牌技 (PushSim.Sig), -1 for heroes without one.
var _sigs := PackedInt32Array()

@onready var _roster: Control = %Roster
@onready var _gold: Label = %Gold
@onready var _shards: Label = %Shards
@onready var _slots: HBoxContainer = %MarchSlots
@onready var _tabs: HBoxContainer = %ClassTabs
@onready var _class_icon: TextureRect = %ClassIcon
@onready var _class_title: Label = %ClassTitle
@onready var _class_level: Label = %ClassLevel
@onready var _class_mult: Label = %ClassMult
@onready var _class_up: Button = %ClassUp
@onready var _roster_title: Label = %RosterTitle
@onready var _cards: GridContainer = %Cards
@onready var _toast: Label = %Toast
@onready var _page: Control = %HeroPage


func _ready() -> void:
	if progress == null:
		var app: Node = get_node_or_null(^"/root/App")
		progress = app.progress() if app != null and save_path == "" else Progression.load_from(_save_path())
	var probe := PushSim.new()
	for i: int in Progression.HEROES:
		_sigs.append(probe.sig[i] if Progression.base_rarity(i) == PushSim.SSR else -1)
	for c: int in _tabs.get_child_count():
		(_tabs.get_child(c) as Button).pressed.connect(select_class.bind(c))
	for k: int in _slots.get_child_count():
		(_slots.get_child(k) as Button).pressed.connect(_slot_pressed.bind(k))
	_class_up.pressed.connect(func() -> void: _apply(progress.level_class(selected_class)))
	_page.back_pressed.connect(close_hero)
	_page.ascend_pressed.connect(func() -> void: _apply(progress.ascend(selected_hero)))
	_page.send_pressed.connect(_send_march)
	_page.captain_pressed.connect(func() -> void: _apply(progress.toggle_captain(selected_hero)))
	%AutoSpend.pressed.connect(func() -> void:
		progress.auto_spend()
		_toast.text = "一鍵養成：金幣、突破素材與強化石都用上了，也換上了更好的裝備"
		_apply(true))
	_toast.text = ""
	_page.visible = false
	select_class(0)


func select_class(c: int) -> void:
	selected_class = c
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
	_refresh()


## Opens hero i's page over the roster.
func select_hero(i: int) -> void:
	selected_hero = i
	_page.visible = true
	_roster.visible = false
	_refresh()


func close_hero() -> void:
	selected_hero = -1
	_page.visible = false
	_roster.visible = true
	_refresh()


func _slot_pressed(k: int) -> void:
	selected_slot = k
	select_hero(progress.march[k])


func _send_march() -> void:
	if selected_hero < 0 or progress.in_march(selected_hero):
		return
	progress.set_march(selected_slot, selected_hero)
	_toast.text = "%s 加入行軍小隊（第 %d 格）" % [PushReport.hero_name(_names, selected_hero), selected_slot + 1]
	_apply(true)


func _apply(changed: bool) -> void:
	if changed:
		progress.save(_save_path())
	_refresh()


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	_gold.text = "%d" % progress.gold
	_shards.text = "%d" % progress.shards
	var c: int = selected_class
	for k: int in _tabs.get_child_count():
		(_tabs.get_child(k) as Button).button_pressed = k == c
	_class_icon.texture = Portraits.class_icon(c)
	_class_title.text = "%s 職業等級" % PushSim.CLASS_NAMES[c]
	_class_level.text = "%d" % progress.class_level[c]
	_class_mult.text = "×%.2f" % pow(Progression.CLASS_STEP, progress.class_level[c] - 1)
	var cost: int = progress.class_cost(c)
	_class_up.text = "升級　%d 金" % cost
	_class_up.disabled = progress.gold < cost
	_roster_title.text = "%s職英雄　%d 人" % [PushSim.CLASS_NAMES[c], PushSim.ROSTER[c]]
	for k: int in _slots.get_child_count():
		var slot: Button = _slots.get_child(k)
		_show_card(slot, progress.march[k], false)
		slot.button_pressed = k == selected_slot
	for card: Node in _cards.get_children():
		if not card.is_queued_for_deletion():
			_show_card(card, card.hero)
			card.button_pressed = card.hero == selected_hero
	if selected_hero >= 0:
		_page.show_hero(progress, selected_hero, PushReport.hero_name(_names, selected_hero), _sigs[selected_hero],
			selected_slot)


## badge: show the 行軍 badge on a marching hero (not on the march slots themselves).
func _show_card(card: Node, i: int, badge: bool = true) -> void:
	var r: int = progress.rarity(i)
	card.show_hero(i, Progression.base_class(i), PushReport.hero_name(_names, i), r, PushSim.RARITY_NAMES[r],
		progress.hero_level[i], progress.ascension[i], badge and progress.in_march(i), progress.is_captain(i),
		progress.ascend_cost(i) > 0 and progress.shards >= progress.ascend_cost(i))


func _save_path() -> String:
	if save_path == "":
		var app: Node = get_node_or_null(^"/root/App")
		save_path = app.progress_path if app != null else Progression.SAVE_PATH
	return save_path
