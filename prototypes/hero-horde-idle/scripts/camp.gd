extends Control
## 營地 (the first page of scenes/home.tscn): gold and shards; the 行軍小隊 marching in real time, as an idle
## side-scroller (scenes/march_view.tscn) over its hours banked, the next one's countdown and 領取; the next 關卡
## (region, stage, boss, our 戰力 against its 推薦: green when enough, gold when close, red when far) with 推王; the
## 待辦 (progression.gd todo(): what can be done now; a tap claims the march or opens that page); 設定. Coming back with march hours banked
## opens the 離線戰報 first. Every 領取 (the 離線戰報's, the march panel's, the 待辦's) shows what came back in that
## dialog, listed by section (資源, 裝備, 英雄升級: scenes/reward_row.tscn lines); then 看廣告 (the Store autoload)
## pays the claim's gold once more. Layout lives in scenes/camp.tscn (tools/build_shell.gd).

const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const PushReport = preload("res://domain/push_report.gd")
const Portraits = preload("res://scripts/portraits.gd")
const Items = preload("res://domain/items.gd")
const RewardRow = preload("res://scenes/reward_row.tscn")

## Set before the screen enters the tree to use other progress (tests); otherwise loaded from save_path.
var progress: RefCounted = null
## "" = the App's progress_path (the player's save), or Progression.SAVE_PATH without the App.
var save_path: String = ""
## Where the last button sent the player (tests read it when there is no App to change scenes).
var went: Dictionary = {}

## A 待辦 row asks the home to show another page (and, for 養成, a class tab).
signal tab_requested(tab: StringName, cls: int)
## Unix seconds now (tests replace it).
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())

var _names: PackedStringArray = PushReport.load_names()
var _tick: float = 0.0

@onready var _gold: Label = %Gold
@onready var _shards: Label = %Shards
@onready var _region: Label = %RegionName
@onready var _stage: Label = %StageLabel
@onready var _boss: Label = %BossName
@onready var _settings: Control = %SettingsOverlay
@onready var _view: Control = %MarchView
@onready var _power: Label = %PowerLine
@onready var _thumb: TextureRect = %BossThumb
@onready var _todo: VBoxContainer = %TodoList
@onready var _todo_panel: Control = %TodoPanel
@onready var _march_line: Label = %MarchLine
@onready var _march_bar: ProgressBar = %MarchBar
@onready var _march_next: Label = %MarchNext
@onready var _claim: Button = %Claim
@onready var _offline: Control = %OfflineReport
@onready var _offline_text: Label = %OfflineText
@onready var _offline_button: Button = %OfflineClaim
@onready var _offline_ad: Button = %OfflineAd
@onready var _offline_title: Label = %OfflineTitle
@onready var _offline_scroll: Control = %OfflineScroll
## The claim the 離線戰報 just paid ({} once its 看廣告 was used).
var _offline_got: Dictionary = {}


func _ready() -> void:
	if progress == null:
		var app: Node = get_node_or_null(^"/root/App")
		progress = app.progress() if app != null and save_path == "" else Progression.load_from(_save_path())
	if progress.march_since <= 0:
		progress.march_hours(clock.call())
		progress.save(_save_path())  # the march's clock starts now, also if the player leaves straight away
	%Push.pressed.connect(func() -> void: push(progress.next_stage()))
	%SettingsButton.pressed.connect(func() -> void: _settings.visible = true)
	%SettingsPanel.closed.connect(func() -> void: _settings.visible = false)
	_claim.pressed.connect(func() -> void: show_claim(claim()))
	_offline_button.pressed.connect(_offline_pressed)
	_offline_ad.pressed.connect(offline_ad)
	for row: Node in _todo.get_children():
		(row as Button).pressed.connect(_todo_pressed.bind(row))
	_settings.visible = false
	for grid: Node in [%ResourcesGrid, %GearGrid, %HeroesGrid]:
		for child: Node in grid.get_children():
			child.free()  # the editor preview lines
	refresh()
	var hours: int = progress.march_hours(clock.call())
	_offline.visible = hours > 0
	if hours > 0:
		_offline_title.text = "離線戰報"
		_offline_scroll.visible = false
		_offline_ad.visible = false
		_offline_text.text = "你不在的時候，行軍小隊走了 %d 小時%s。" % [hours,
			"（已達上限 %d 小時）" % Progression.MARCH_CAP_HOURS if hours >= Progression.MARCH_CAP_HOURS else ""]
		_offline_button.text = "領取"


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_show_march()


## 領取: every banked march hour, saved. Returns what it paid (claim_march()).
func claim() -> Dictionary:
	var got: Dictionary = progress.claim_march(clock.call())
	if got.hours > 0:
		progress.save(_save_path())
	refresh()
	return got


func _show_todo() -> void:
	var items: Array = progress.todo(clock.call())
	_todo_panel.visible = not items.is_empty()
	for k: int in _todo.get_child_count():
		var row: Button = _todo.get_child(k)
		row.visible = k < items.size()
		if k < items.size():
			row.text = "•  %s" % items[k].text
			row.set_meta(&"item", items[k])


func _todo_pressed(row: Button) -> void:
	var item: Dictionary = row.get_meta(&"item", {})
	if item.get("kind", "") == "march":
		show_claim(claim())
	elif not item.is_empty():
		tab_requested.emit(item.tab, item.cls)


## 離線戰報: the first press claims and shows what came back, the second closes it.
func _offline_pressed() -> void:
	if _offline_button.text == "領取":
		show_claim(claim(), "離線戰報")
	else:
		_offline.visible = false


## Shows a claim (claim_march()) in the dialog, listed by section, with 好 and 看廣告.
func show_claim(got: Dictionary, title: String = "行軍收穫") -> void:
	if got.hours <= 0:
		return
	_offline_got = got
	_offline.visible = true
	_offline_title.text = title
	_offline_text.text = "行軍 %d 小時帶回來：" % got.hours
	_offline_button.text = "好"
	_offline_ad.visible = got.gold > 0
	_offline_ad.disabled = false
	_offline_ad.text = "免廣告　金幣再領一次" if progress.owns("no_ads") else "看廣告　金幣再領一次"
	_fill_rewards(got)
	%MarchToast.text = "已領取行軍 %d 小時的收穫" % got.hours


## The claim's lines: 資源 (gold, shards, 強化石), 裝備 (each item once, with its count), 英雄升級 (Lv before -> after).
func _fill_rewards(got: Dictionary, extra_gold: int = 0) -> void:
	_offline_scroll.visible = true
	var resources: Array = [[Items.material_icon("gold"), "金幣", "+%d" % got.gold]]
	if extra_gold > 0:
		resources.append([Items.material_icon("gold"), "看廣告加碼", "+%d" % extra_gold])
	if got.shards > 0:
		resources.append([Items.material_icon("shards"), "突破素材", "+%d" % got.shards])
	if got.stones > 0:
		resources.append([Items.material_icon("stones"), "強化石", "+%d" % got.stones])
	var grid: Node = %ResourcesGrid
	_clear(grid)
	for line: Array in resources:
		_line(grid).show_row(line[0], -1, line[1], line[2])
	var counts: Dictionary = {}
	for id: String in got.items:
		counts[id] = counts.get(id, 0) + 1
	grid = %GearGrid
	_clear(grid)
	for id: String in counts:
		_line(grid).show_row(Items.icon(id), Items.rarity(id), Items.item_name(id), "×%d" % counts[id] if counts[id] > 1 else "")
	%GearSection.visible = not counts.is_empty()
	grid = %HeroesGrid
	_clear(grid)
	for i: int in got.levels:
		var c: int = Progression.base_class(i)
		var now: int = progress.hero_level[i]
		_line(grid).show_row(Portraits.card(c), progress.rarity(i), PushReport.hero_name(_names, i),
			"Lv%d→%d" % [now - got.levels[i], now], Portraits.tint(i, c), Portraits.material(progress.rarity(i)))
	%HeroesSection.visible = not got.levels.is_empty()


func _clear(grid: Node) -> void:
	for child: Node in grid.get_children():
		child.queue_free()
		grid.remove_child(child)


func _line(grid: Node) -> Node:
	var row: Node = RewardRow.instantiate()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(row)
	return row


## 看廣告 after the 離線戰報's claim: its gold once more (once).
func offline_ad() -> void:
	if _offline_got.is_empty():
		return
	var got: Dictionary = _offline_got
	_offline_got = {}
	_offline_ad.disabled = true
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.show_ad("march_double", progress.owns("no_ads")):
		_offline_ad.disabled = false
		_offline_got = got
		return
	var gold: int = progress.double_march(got)
	progress.save(_save_path())
	_offline_ad.visible = false
	_fill_rewards(got, gold)
	refresh()


func _show_march() -> void:
	var now: int = clock.call()
	var hours: int = progress.march_hours(now)
	var next: int = progress.march_next_in(now)
	_march_line.text = "已累積 %d 小時（上限 %d）" % [hours, Progression.MARCH_CAP_HOURS]
	_march_bar.value = 100.0 if next == 0 else 100.0 * (1.0 - float(next) / Progression.MARCH_SECONDS)
	_march_next.text = "已滿，快領取" if next == 0 else "下一小時 %02d:%02d" % [next / 60, next % 60]
	_claim.disabled = hours == 0
	_claim.text = "領取 %d 小時" % hours if hours > 0 else "領取"


## Goes to the push of stage n (when it is open).
func push(n: int) -> void:
	if progress.unlocked(n):
		_go(&"push", {"stage_n": n})


func _go(where: StringName, hand: Dictionary) -> void:
	went = {"where": where, "hand": hand}
	var app: Node = get_node_or_null(^"/root/App")
	if app != null:
		app.go(app.PUSH, hand)


func refresh() -> void:
	_gold.text = "%d" % progress.gold
	_shards.text = "%d" % progress.shards
	var n: int = progress.next_stage()
	_region.text = Stages.REGIONS[Stages.region(n)].name
	_stage.text = Stages.label(n)
	_boss.text = Stages.boss_name(n)
	var region: Dictionary = Stages.REGIONS[Stages.region(n)]
	_thumb.self_modulate = region.boss_tint
	var ours: int = roundi(progress.team_power() * 1000.0)
	var asks: int = roundi(Stages.recommended(n) * 1000.0)
	_power.text = "我方戰力 %d ／ 推薦 %d" % [ours, asks]
	_power.add_theme_color_override(&"font_color", Color("9fd08f") if ours >= asks else (Color("d9b26e") if ours * 5 >= asks * 4
		else Color("d9735a")))
	var squad: Array = []
	for i: int in progress.march:
		var c: int = Progression.base_class(i)
		squad.append({"cls": c, "rarity": progress.rarity(i), "tint": Portraits.tint(i, c)})
	_show_todo()
	_view.setup(squad, region.name, region.boss_tint, progress.march_strength() * Progression.START_POWER * 10.0,
		roundi(Progression.MARCH_GOLD * progress.march_strength()))
	_show_march()


func _save_path() -> String:
	if save_path == "":
		var app: Node = get_node_or_null(^"/root/App")
		save_path = app.progress_path if app != null else Progression.SAVE_PATH
	return save_path
