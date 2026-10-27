extends Control
## The home screen (scenes/home.tscn, the main scene; Taskbar Hero's layout at 941 x 1672): the header (the march
## leader, gold, 招募券, settings), seven pages over the nav bar, and the 行軍 strip (scenes/march_arena.tscn) playing
## on top of every page. Switching pages hides and shows them at once; the strip keeps fighting and its scenery
## binds to the shown page's landscape. Pages tell this screen what they changed (`changed`) and it saves, refreshes
## the header, the shown page and the nav dots, and restarts the march when its squad or stage changed (growth alone
## waits for the next 段). Opening the screen pays the time away (the offline report). The App hands over the tab to
## open ("tab") and takes the stage to push ("stage_n").

const Progression = preload("res://domain/progression.gd")
const Stages = preload("res://domain/stages.gd")
const Items = preload("res://domain/items.gd")
const Heroes = preload("res://domain/heroes.gd")
const Portraits = preload("res://scripts/portraits.gd")
const Names = preload("res://domain/push_report.gd")
const PixelUi = preload("res://scripts/pixel_ui.gd")
const PUSH := "res://scenes/main.tscn"
const SIZE := Vector2i(941, 1672)
const TABS := [&"overview", &"train", &"backpack", &"heroes", &"equipment", &"adventure", &"store"]
## The nav buttons' tabs, in navigation.tscn's order.
const NAV_TABS := [&"train", &"backpack", &"heroes", &"equipment", &"adventure", &"store"]
const SAVE_EVERY := 15.0
const LOG_SIZE := 60
const TOAST_TIME := 2.2
## Time away shorter than this (a push, a quick switch) is paid into the log; longer opens the 離線戰報.
const REPORT_AFTER := 600
## Where home.tscn puts the strip, the nav bar, the toast and the top of the pages' sky (_fit moves them down).
const ARENA_Y := 470.0
const NAV_Y := 1536.0
const TOAST_Y := 1440.0
const SKY_TOP := 110.0

var progress: RefCounted = null
## Where progress is saved ("" = the App's path, or the player's save).
var save_path: String = ""
## The clock (unix seconds); tests replace it.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
var tab: StringName = &"overview"
var log_lines := PackedStringArray()
var names := PackedStringArray()
var _save_in: float = SAVE_EVERY
var _tick_in: float = 1.0
var _toast_t: float = 0.0
var _squad_key: String = ""
var _offline: Dictionary = {}

@onready var _pages: Dictionary = {&"overview": %Overview, &"train": %Train, &"backpack": %Backpack, &"heroes": %Heroes,
	&"equipment": %Equipment, &"adventure": %Adventure, &"store": %Store}
@onready var _arena: Node2D = %MarchArena


func _enter_tree() -> void:
	get_tree().root.content_scale_size = SIZE
	add_to_group(PixelUi.PLAIN)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()
	var app: Node = get_node_or_null(^"/root/App")
	if progress == null:
		progress = app.progress() if app != null and save_path == "" else Progression.load_from(_path())
	names = Names.load_names()
	for key: StringName in _pages:
		var page: Control = _pages[key]
		page.progress = progress
		page.changed.connect(_on_changed)
		page.open_tab.connect(show_tab)
		page.message.connect(toast)
		if page.has_signal("dialog_requested"):
			page.dialog_requested.connect(dialog)
	%Adventure.push_requested.connect(push)
	var nav: Control = %Navigation
	for k: int in mini(nav.get_child_count(), NAV_TABS.size()):
		(nav.get_child(k) as Button).pressed.connect(show_tab.bind(NAV_TABS[k]))
	%Header.get_node("AvatarButton").pressed.connect(show_tab.bind(&"overview"))
	%Header.get_node("OverviewButton").pressed.connect(show_tab.bind(&"overview"))
	%Heroes.equip_requested.connect(func(i: int) -> void:
		%Equipment.show_hero(i)
		show_tab(&"equipment"))
	%Header.get_node("SettingsButton").pressed.connect(func() -> void: %SettingsOverlay.visible = true)
	%SettingsPanel.closed.connect(func() -> void: %SettingsOverlay.visible = false)
	%DialogOk.pressed.connect(func() -> void: %Dialog.visible = false)
	%DialogAlt.pressed.connect(_double_offline)
	_arena.killed.connect(_on_kill)
	_arena.logged.connect(add_log)
	_arena.start(progress)
	_squad_key = _key()
	add_log("小隊在 %s 出發。" % Stages.label(progress.march_stage))
	show_tab(app.take(&"tab", &"overview") if app != null else &"overview")
	_claim_offline()


## Phones are taller than the 941 x 1672 layout: the screen keeps its width and the extra height goes above the
## pages, as more sky over the 行軍 strip; the header stays on top, the pages and the nav bar sit on the bottom.
func _fit() -> void:
	var extra: float = maxf(get_viewport_rect().size.y - SIZE.y, 0.0)
	%Pages.position.y = extra
	_arena.position.y = ARENA_Y + extra
	%Navigation.position.y = NAV_Y + extra
	%NavDots.position.y = extra
	%Toast.position.y = TOAST_Y + extra
	%SkyFill.size = Vector2(SIZE.x, SKY_TOP + extra)


func _path() -> String:
	if save_path != "":
		return save_path
	var app: Node = get_node_or_null(^"/root/App")
	return app.progress_path if app != null else Progression.SAVE_PATH


func save() -> void:
	progress.save(_path())
	_save_in = SAVE_EVERY


func _process(delta: float) -> void:
	_save_in -= delta
	if _save_in <= 0.0:
		save()
	_tick_in -= delta
	if _tick_in <= 0.0:
		_tick_in = 1.0
		# Back from the background (or a push): pay the time away first, then keep counting.
		if clock.call() - progress.march_since >= Progression.OFFLINE_MIN:
			_claim_offline()
		progress.keep_marching(clock.call())
		_refresh_header()
		_update_dots()
	if _toast_t > 0.0:
		_toast_t -= delta
		%Toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
		if _toast_t <= 0.0:
			%Toast.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if progress != null:
			progress.keep_marching(clock.call())
			save()


func show_tab(which: StringName) -> void:
	var before: Control = _pages.get(tab)
	if before != null and which != tab and before.has_method("leave"):
		before.leave()
	tab = which
	for key: StringName in _pages:
		_pages[key].visible = key == which
	var page: Control = _pages[which]
	_arena.bind_scenery(page)
	if which == &"overview":
		%Overview.log_lines = log_lines
	page.refresh()
	var nav: Control = %Navigation
	for k: int in mini(nav.get_child_count(), NAV_TABS.size()):
		(nav.get_child(k) as Button).modulate = Color("fff1b8") if NAV_TABS[k] == which else Color.WHITE
	_refresh_header()
	_update_dots()


func _on_changed() -> void:
	save()
	var key: String = _key()
	if key != _squad_key:
		_squad_key = key
		_arena.restart()
	else:
		_arena.pending = true
	_pages[tab].refresh()
	_refresh_header()
	_update_dots()


## What the strip must restart for: the squad and the stage it marches at.
func _key() -> String:
	return "%s@%d" % [str(progress.march), progress.march_stage]


func _on_kill(got: Dictionary) -> void:
	for i: int in got.levels:
		add_log("%s 升到 Lv.%d" % [Names.hero_name(names, i), progress.hero_level[i]])
		_arena.pending = true
	if got.shards > 0:
		add_log("撿到突破素材 ×%d" % got.shards)
	for item: Dictionary in got.items:
		add_log("撿到 %s（%s）" % [Items.item_name(item.id), Items.RARITY_NAMES[Items.rarity(item.id)]])
	if got.salvaged > 0:
		add_log("自動分解了 %d 件裝備" % got.salvaged)
	if not got.items.is_empty() or got.shards > 0:
		_pages[tab].refresh()


func add_log(text: String) -> void:
	var t: Dictionary = Time.get_time_dict_from_system()
	log_lines.append("[%02d:%02d] %s" % [t.hour, t.minute, text])
	if log_lines.size() > LOG_SIZE:
		log_lines = log_lines.slice(log_lines.size() - LOG_SIZE)
	if tab == &"overview" and is_node_ready():
		%Overview.log_lines = log_lines
		%Overview.show_log()


func toast(text: String) -> void:
	%Toast.text = text
	%Toast.visible = true
	%Toast.modulate.a = 1.0
	_toast_t = TOAST_TIME


## The home screen's dialog. `alt` is the second button's text ("" hides it).
func dialog(title: String, body: String, alt: String = "") -> void:
	%DialogTitle.text = title
	%DialogBody.text = body
	%DialogAlt.visible = alt != ""
	%DialogAlt.text = alt
	%Dialog.visible = true


func _refresh_header() -> void:
	var header: Control = %Header
	var leader: int = progress.march[0]
	var c: int = Progression.base_class(leader)
	var portrait: TextureRect = header.get_node("AvatarButton/Portrait")
	portrait.texture = Portraits.hero_sprite(Heroes.form(leader), c)
	portrait.self_modulate = Portraits.tint(leader, c)
	(header.get_node("LevelLabel") as Label).text = "Lv. %d　%s" % [progress.hero_level[leader], Names.hero_name(names, leader)]
	var bar: ProgressBar = header.get_node("ExperienceBar")
	bar.max_value = Progression.EXP_PER_LEVEL * progress.hero_level[leader]
	bar.value = progress.hero_exp[leader]
	(header.get_node("GoldBadge") as Label).text = _short(progress.gold)
	(header.get_node("GemBadge") as Label).text = str(progress.tickets)


func _update_dots() -> void:
	var kinds: Array = progress.todo().map(func(item: Dictionary) -> String: return item.kind)
	var on: Array = [kinds.has("talent"), progress.fresh.size() > 0, kinds.has("ascend") or kinds.has("slot"),
		kinds.has("equip") or kinds.has("armory"), false, kinds.has("recruit") or progress.ad_pull_ready(clock.call())]
	var dots: Control = %NavDots
	for k: int in mini(dots.get_child_count(), on.size()):
		(dots.get_child(k) as Control).visible = on[k]


## The time away, paid at the march's measured pace, shown as the 離線戰報.
func _claim_offline() -> void:
	_offline = progress.claim_offline(clock.call())
	if _offline.seconds <= 0:
		return
	save()
	var lines := PackedStringArray()
	lines.append("離開 %d 小時 %d 分，小隊在 %s 行軍：" % [_offline.seconds / 3600, _offline.seconds / 60 % 60,
		Stages.label(_offline.stage)])
	lines.append("擊倒 %d 隻怪物" % _offline.kills)
	lines.append("金幣 +%s" % _short(_offline.gold))
	if _offline.shards > 0:
		lines.append("突破素材 +%d" % _offline.shards)
	lines.append_array(Items.drops_text(_offline))
	for i: int in _offline.levels:
		lines.append("%s 升了 %d 級" % [Names.hero_name(names, i), _offline.levels[i]])
	if _offline.seconds >= progress.offline_cap_hours() * 3600:
		lines.append("\n（已達離線上限 %d 小時；點亮天賦「休息」可以延長）" % progress.offline_cap_hours())
	add_log("離開 %d 分鐘：擊倒 %d，金幣 +%s" % [_offline.seconds / 60, _offline.kills, _short(_offline.gold)])
	if _offline.seconds >= REPORT_AFTER:
		dialog("離線戰報", "\n".join(lines), "看廣告 金幣 ×2" if _offline.gold > 0 else "")
	_refresh_header()


func _double_offline() -> void:
	var store: Node = get_node_or_null(^"/root/Store")
	if store != null and not await store.show_ad("march_double", progress.owns("no_ads")):
		return
	var extra: int = progress.double_offline(_offline)
	_offline = {}
	%DialogAlt.visible = false
	toast("金幣再 +%s" % _short(extra))
	_on_changed()


func push(stage_n: int) -> void:
	save()
	var app: Node = get_node_or_null(^"/root/App")
	if app != null:
		app.go(PUSH, {"stage_n": stage_n})
	else:
		get_tree().change_scene_to_file(PUSH)


static func _short(v: int) -> String:
	if v >= 100_000_000:
		return "%.2f億" % (v / 100_000_000.0)
	if v >= 100_000:
		return "%.1f萬" % (v / 10_000.0)
	return str(v)
