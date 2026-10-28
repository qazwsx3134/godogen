extends CanvasLayer
## Status frame (name, level, HP, XP, AP), the locked target's frame, the sweep and apple buttons, the bag
## (use / equip), the quest tracker, the NPC panel (quest + shop) and the message log. Town actions call the
## rules (Shop, player, quests) and hand the result to Main.town_action(), which saves and plays the sound.

@onready var name_label: Label = %NameLabel
@onready var level_label: Label = %LevelLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_text: Label = %HpText
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_text: Label = %XpText
@onready var target_panel: Control = %TargetPanel
@onready var target_name: Label = %TargetName
@onready var target_hp_bar: ProgressBar = %TargetHpBar
@onready var log_box: RichTextLabel = %Log
@onready var ap_bar: ProgressBar = %ApBar
@onready var ap_text: Label = %ApText
@onready var sweep_button: Button = %SweepButton
@onready var sweep_cooldown: Label = %SweepCooldown
@onready var bag_button: Button = %BagButton
@onready var bag_panel: Control = %BagPanel
@onready var bag_rows: VBoxContainer = %BagRows
@onready var bag_scroll: ScrollContainer = bag_rows.get_parent()
@onready var items_tab: Button = %ItemsTab
@onready var refine_tab: Button = %RefineTab
@onready var refine_scroll: ScrollContainer = %RefineScroll
@onready var gear_label: Label = %GearLabel
@onready var quest_tracker: Label = %QuestTracker
@onready var apple_button: Button = %AppleButton
@onready var npc_panel: Control = %NpcPanel
@onready var gold_label: Label = %GoldLabel
@onready var quest_title: Label = %QuestTitle
@onready var quest_text: Label = %QuestText
@onready var quest_button: Button = %QuestButton
@onready var shop_rows: VBoxContainer = %ShopRows
@onready var sell_button: Button = %SellButton
@onready var close_button: Button = %CloseButton
@onready var minimap: Control = %Minimap
@onready var map_button: Button = %MapButton
@onready var world_map: Control = %WorldMap
@onready var settings_button: Button = %SettingsButton
@onready var settings_window: Control = %SettingsWindow
@onready var collection_button: Button = %CollectionButton
@onready var collection_window: Control = %CollectionWindow
@onready var wardrobe_button: Button = %WardrobeButton
@onready var wardrobe_window: Control = %WardrobeWindow
@onready var fishing_window: Control = %FishingWindow
@onready var tutorial_panel: Control = %TutorialPanel
@onready var tutorial_text: Label = %TutorialText
@onready var tutorial_skip: Button = %TutorialSkip
@onready var fade_rect: ColorRect = %Fade
@onready var refine_rows: VBoxContainer = %RefineRows
@onready var pet_button: Button = %PetButton
@onready var pet_panel: Control = %PetPanel
@onready var pet_name: Label = %PetName
@onready var pet_info: Label = %PetInfo
@onready var feed_rows: VBoxContainer = %FeedRows
@onready var evolve_button: Button = %EvolveButton
@onready var pet_close: Button = %PetClose

const Items = preload("res://scripts/items.gd")
const Shop = preload("res://scripts/shop.gd")
const Refine = preload("res://scripts/refine.gd")
const PetRules = preload("res://scripts/pet_rules.gd")
const ItemRow = preload("res://ui/item_row.tscn")
const RefineRow = preload("res://ui/refine_row.tscn")
const SLOT_NAMES := {"weapon": "武器", "body": "衣服"}
const REASON_TEXT := {"gold": "金幣不夠。", "bag_full": "背包放不下。", "full_hp": "生命已滿。", "none": "沒有這個物品。",
	"not_done": "任務還沒完成。", "dead": "倒下時不能用。", "stone": "缺少精煉需要的寶石。", "max": "已經精煉到最高。",
	"not_ready": "寵物還不能進化（要 +9 且經驗滿）。", "materials": "進化材料不足。"}

## Refine button waiting for its second press (slot), so one stray tap never spends a stone.
var _refine_armed: String = ""
var _evolve_armed: bool = false
var _large_text: bool = false
## What each list was last built from. HP regen emits stats_changed every frame; lists are rebuilt only when their
## content changes, so a button is never freed under the player's finger.
var _built := {}

const REJECT_TEXT := {"cooldown": "範圍揮砍還在冷卻。", "ap": "AP 不足。", "dead": "倒下時不能使用技能。", "casting": ""}

signal sweep_denied

var player: Node3D
## Main, for town_action(result).
var main: Node


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


## Keeps the HUD inside the screen's safe area (notch / rounded corners on phones): the Root control is inset by
## how far the safe area cuts into the window, converted to viewport units.
func _apply_safe_area() -> void:
	var root: Control = $Root
	var window := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window.size.x <= 0 or safe.size.x <= 0:
		return
	var to_view: Vector2 = get_viewport().get_visible_rect().size / window.size
	root.offset_left = maxf(0.0, safe.position.x - window.position.x) * to_view.x
	root.offset_top = maxf(0.0, safe.position.y - window.position.y) * to_view.y
	root.offset_right = -maxf(0.0, window.end.x - safe.end.x) * to_view.x
	root.offset_bottom = -maxf(0.0, window.end.y - safe.end.y) * to_view.y


func bind(p: Node3D) -> void:
	player = p
	player.stats_changed.connect(refresh)
	player.message.connect(log_line)
	name_label.text = player.player_name
	sweep_button.pressed.connect(try_sweep)
	minimap.player = player
	minimap.gui_input.connect(_on_minimap_input)
	map_button.pressed.connect(open_world_map)
	settings_button.pressed.connect(open_settings)
	settings_window.changed.connect(func(key: String, value: bool) -> void: main.update_setting(key, value))
	collection_button.pressed.connect(open_collection)
	collection_window.bind(player, main)
	wardrobe_button.pressed.connect(open_wardrobe)
	wardrobe_window.bind(player, main)
	collection_window.rows_updated.connect(func() -> void: _apply_text_size(collection_window))
	fishing_window.start_requested.connect(main.start_fishing)
	fishing_window.stop_requested.connect(main.cancel_fishing)
	pet_button.pressed.connect(func() -> void:
		var show := not pet_panel.visible
		_close_panels()
		pet_panel.visible = show
		refresh())
	pet_close.pressed.connect(func() -> void:
		pet_panel.visible = false
		_evolve_armed = false)
	evolve_button.pressed.connect(func() -> void:
		if not _evolve_armed:
			_evolve_armed = true
			_refresh_pet()
			return
		_evolve_armed = false
		var r := {}
		var reason: String = player.evolve_pet(r)
		if reason == "":
			if r.ok:
				log_line("寵物進化成%s%s！" % [PetRules.TYPE_NAMES.get(r.type, r.type), "（稀有）" if r.rare else ""], Color("ffd75e"))
			else:
				log_line("進化失敗，材料用掉了，經驗要重新累積。", Color("ff9d8a"))
		_act(reason))
	tutorial_skip.pressed.connect(func() -> void:
		player.tutorial.skip()
		_act(""))
	items_tab.pressed.connect(func() -> void: _select_bag_tab(false))
	refine_tab.pressed.connect(func() -> void: _select_bag_tab(true))
	bag_button.pressed.connect(func() -> void:
		var show := not bag_panel.visible
		_close_panels()
		bag_panel.visible = show
		if show:
			_select_bag_tab(false)
			refresh())
	apple_button.pressed.connect(func() -> void: _act(player.use_item("apple")))
	close_button.pressed.connect(func() -> void: npc_panel.visible = false)
	quest_button.pressed.connect(_on_quest_button)
	sell_button.pressed.connect(func() -> void:
		var earned := Shop.sell_materials(player)
		if earned > 0:
			log_line("賣掉材料，得到 %d 金幣。" % earned, Color("ffd75e"))
		_act("" if earned > 0 else "none"))
	refresh()
	log_line("歡迎來到蓬蓬草原！點地面移動，點怪物攻擊。", Color("ffd75e"))


func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		open_world_map()


func open_world_map() -> void:
	_close_panels()
	world_map.show_zone(main.zone)


func open_settings() -> void:
	_close_panels()
	settings_window.show_settings(main.settings)


func open_collection() -> void:
	_close_panels()
	collection_window.show_book()


func open_wardrobe() -> void:
	_close_panels()
	wardrobe_window.show_wardrobe()


func open_fishing() -> void:
	_close_panels()
	fishing_window.show_spot(player.bag.count("fishing_bait"))


func _select_bag_tab(refining: bool) -> void:
	_refine_armed = ""
	_built.erase("refine")
	items_tab.set_pressed_no_signal(not refining)
	refine_tab.set_pressed_no_signal(refining)
	bag_scroll.visible = not refining
	refine_scroll.visible = refining
	if refining:
		_fill_refine_rows()


func _close_panels() -> void:
	bag_panel.visible = false
	npc_panel.visible = false
	pet_panel.visible = false
	world_map.visible = false
	settings_window.visible = false
	collection_window.visible = false
	if wardrobe_window.visible:
		wardrobe_window.dismiss()
	if fishing_window.visible:
		main.cancel_fishing()
		fishing_window.visible = false
	_refine_armed = ""
	_built.erase("refine")
	_evolve_armed = false


func close_top_window() -> void:
	_close_panels()


func set_large_text(enabled: bool) -> void:
	_large_text = enabled
	_apply_text_size($Root)


func _apply_text_size(node: Node) -> void:
	var key := ""
	if node is Label or node is BaseButton:
		key = "font_size"
	elif node is RichTextLabel:
		key = "normal_font_size"
	if not key.is_empty():
		var control := node as Control
		if not control.has_meta("base_font_size"):
			control.set_meta("base_font_size", control.get_theme_font_size(key))
		var base: int = int(control.get_meta("base_font_size"))
		if base > 0:
			control.add_theme_font_size_override(key, roundi(base * (1.25 if _large_text else 1.0)))
	for child: Node in node.get_children():
		_apply_text_size(child)


func refresh() -> void:
	level_label.text = "Lv %d" % player.level
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	hp_text.text = "%d / %d" % [ceili(player.hp), player.max_hp]
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp
	xp_text.text = "EXP %.1f%%" % (100.0 * player.xp / player.xp_to_next())
	var bag = player.bag
	bag_button.text = "背包 %d/%d　金 %d" % [bag.slots.size(), bag.capacity, player.gold]
	apple_button.text = "蘋果\n×%d" % bag.count("apple")
	var worn: PackedStringArray = []
	for slot: String in player.equipped:
		var id: String = player.equipped[slot]
		worn.append("%s：%s" % [SLOT_NAMES[slot], "%s +%d" % [Items.ALL[id].name, player.refine_level(slot)] if id != "" else "無"])
	gear_label.text = "　".join(worn)
	_fill_bag_rows()
	if bag_panel.visible and refine_scroll.visible:
		_fill_refine_rows()
	_refresh_quest()
	tutorial_panel.visible = not player.tutorial.finished()
	tutorial_text.text = player.tutorial.text()
	if npc_panel.visible:
		_refresh_npc()
	if pet_panel.visible:
		_refresh_pet()


func _refresh_pet() -> void:
	var p = player.pet
	pet_name.text = "%s +%d（第 %d 階）" % [PetRules.TYPE_NAMES.get(p.type, p.type), p.level, p.stage]
	var bonus: PackedStringArray = []
	for stat: String in p.stats():
		bonus.append("%s +%d" % ["攻擊" if stat == "atk" else "生命", int(p.stats()[stat])])
	pet_info.text = "經驗 %d/%d　飽足 %d%%　加成 %s%s\n進化成功率 90%%；失敗消耗材料並清空本級經驗。" % [p.xp, p.xp_to_next(), int(p.hunger * 100.0), "、".join(bonus),
		"\n想吃：%s" % Items.ALL[p.wants].name if p.wants != "" else ""]
	evolve_button.text = "確認進化？" if _evolve_armed else "進化（四葉草＋野豬長牙）"
	if not _changed("feed", [player.bag.slots, p.wants]):
		evolve_button.disabled = not p.can_evolve()
		return
	for c in feed_rows.get_children():
		c.queue_free()
	for id: String in PetRules.OPTIONS.foods:
		var row: Node = ItemRow.instantiate()
		feed_rows.add_child(row)
		var have: int = player.bag.count(id)
		row.setup("%s（有 %d）" % [Items.ALL[id].name, have], "想吃！" if p.wants == id else "", "餵", have > 0)
		_apply_text_size(row)
		row.action_pressed.connect(func() -> void:
			_evolve_armed = false
			var r := {}
			var reason: String = player.feed_pet(id, r)
			if reason == "":
				log_line("寵物吃了%s，經驗 +%d%s。" % [Items.ALL[id].name, r.xp, "（最愛）" if r.wanted else ""], Color("b8f28a"))
			_act(reason))
	evolve_button.visible = p.stage < PetRules.OPTIONS.max_stage
	evolve_button.disabled = not p.can_evolve()


## True when `list`'s content key changed since it was last built (and remembers the new key).
func _changed(list: String, key: Variant) -> bool:
	var s := var_to_str(key)
	if _built.get(list, "") == s:
		return false
	_built[list] = s
	return true


func _fill_bag_rows() -> void:
	if not _changed("bag", [player.bag.slots, player.equipped]):
		return
	for c in bag_rows.get_children():
		c.queue_free()
	for s: Dictionary in player.bag.slots:
		var def: Dictionary = Items.ALL[s.id]
		var row: Node = ItemRow.instantiate()
		bag_rows.add_child(row)
		var action := "裝備" if def.has("slot") else ("使用" if def.has("heal") else "")
		var info := "攻擊 +%d" % def.atk if def.has("atk") else ("生命 +%d" % def.hp if def.has("hp") else "")
		var item_name: String = "%s +%d" % [def.name, int(s.get("refine", 0))] if def.has("slot") else "%s ×%d" % [def.name, s.count]
		row.setup(item_name, info, action)
		_apply_text_size(row)
		var id: String = s.id
		var uid: String = s.get("uid", "")
		row.action_pressed.connect(func() -> void:
			_act(player.equip(id, uid) if def.has("slot") else player.use_item(id)))


## Opens the NPC panel (Main calls this when the player reaches the NPC).
func open_npc() -> void:
	_close_panels()
	npc_panel.visible = true
	_refresh_npc()


func _refresh_npc() -> void:
	gold_label.text = "金幣 %d" % player.gold
	var q: Dictionary = player.quests.current()
	if q.is_empty():
		quest_title.text = "任務：全部完成"
		quest_text.text = "謝謝你，草原安靜多了。"
		quest_button.visible = false
	else:
		quest_title.text = "任務：" + q.title
		quest_text.text = q.text
		quest_button.visible = true
		if not player.quests.accepted:
			quest_button.text = "接受任務"
			quest_button.disabled = false
		else:
			var ready: bool = player.quests.done(player)
			quest_button.text = "提交任務" if ready else "進行中 %d/%d" % [player.quests.count(player), q.goal.n]
			quest_button.disabled = not ready
	if not _changed("shop", player.gold):
		return
	for c in shop_rows.get_children():
		c.queue_free()
	for id: String in Items.SHOP:
		var def: Dictionary = Items.ALL[id]
		var row: Node = ItemRow.instantiate()
		shop_rows.add_child(row)
		row.setup(def.name, "%d 金" % def.buy, "買", player.gold >= def.buy)
		_apply_text_size(row)
		row.action_pressed.connect(func() -> void:
			var r := Shop.buy(player, id)
			if r == "":
				log_line("買了 %s。" % def.name, Color("b8f28a"))
			_act(r))


func _fill_refine_rows() -> void:
	if not _changed("refine", [player.gear, player.bag.slots]):
		return
	for c in refine_rows.get_children():
		c.queue_free()
	for slot: String in player.equipped:
		var id: String = player.equipped[slot]
		if id == "":
			continue
		var level: int = player.refine_level(slot)
		var uid: String = player.gear[slot].uid
		var row: Node = RefineRow.instantiate()
		refine_rows.add_child(row)
		if level >= Refine.max_level():
			row.setup("%s +%d" % [Items.ALL[id].name, level], "已達上限", "")
			_apply_text_size(row)
			continue
		var step: Dictionary = Refine.STEPS[level]
		var info := "%s×1　成功率 %d%%" % [Items.ALL[step.stone].name, int(step.chance * 100.0)]
		var armed := _refine_armed == uid
		row.setup("%s +%d → +%d" % [Items.ALL[id].name, level, level + 1], info, "確定？" if armed else "精煉",
			player.bag.count(step.stone) > 0)
		_apply_text_size(row)
		row.action_pressed.connect(func() -> void:
			if player.gear[slot].get("uid", "") != uid:
				_refine_armed = ""
				refresh()
				return
			if _refine_armed != uid:
				_refine_armed = uid
				_built.erase("refine")
				_fill_refine_rows()
				return
			_refine_armed = ""
			var r := {}
			var reason := Refine.attempt(player, slot, main.combat.rng if main else RandomNumberGenerator.new(), r)
			if reason == "":
				if r.ok:
					log_line("精煉成功！%s +%d" % [Items.ALL[id].name, r.level], Color("ffd75e"))
				else:
					log_line("精煉失敗，%s碎掉了（裝備不受影響）。" % Items.ALL[r.stone].name, Color("ff9d8a"))
			_act(reason))


func _refresh_quest() -> void:
	var q: Dictionary = player.quests.current()
	if q.is_empty() or not player.quests.accepted:
		quest_tracker.text = "" if q.is_empty() else "！村長有事找你"
	else:
		var n: int = player.quests.count(player)
		quest_tracker.text = "%s　%d/%d%s" % [q.title, n, q.goal.n, "　→ 回村長那裡" if n >= q.goal.n else ""]


## Fades the screen to black (true) or back (false); input is blocked while black.
func fade(to_black: bool) -> void:
	fade_rect.visible = true
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0 if to_black else 0.0, 0.25)
	await tween.finished
	fade_rect.visible = to_black


func _on_quest_button() -> void:
	var q: Dictionary = player.quests.current()
	if not player.quests.accepted:
		player.quests.accept()
		log_line("接受任務「%s」。" % q.title, Color("ffd75e"))
		_act("")
		return
	var r: String = player.quests.turn_in(player)
	if r == "":
		log_line("完成任務「%s」！" % q.title, Color("ffd75e"))
	_act(r)


func _act(result: String) -> void:
	if result != "" and REASON_TEXT.has(result):
		log_line(REASON_TEXT[result], Color("ff9d8a"))
	if main:
		main.town_action(result)
	refresh()


func try_sweep() -> void:
	var reason: String = player.use_sweep()
	if REJECT_TEXT.get(reason, "") != "":
		sweep_denied.emit()
		log_line(REJECT_TEXT[reason], Color("ff9d8a"))


func log_line(text: String, color: Color = Color.WHITE) -> void:
	log_box.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])
	while log_box.get_paragraph_count() > 60:  # unbounded, the log was the memory leak in long sessions
		log_box.remove_paragraph(0)


func _process(_delta: float) -> void:
	if player == null:
		return
	if player.tutorial.update(player):
		refresh()
		if main:
			main.save_game()
	ap_bar.max_value = player.max_ap
	ap_bar.value = player.ap
	ap_text.text = "AP %d / %d" % [int(player.ap), player.max_ap]
	sweep_cooldown.text = "%.0f" % ceilf(player.sweep_left) if player.sweep_left > 0.0 else ""
	sweep_button.modulate.a = 1.0 if player.sweep_left <= 0.0 and player.ap >= player.sweep_cost else 0.55
	var t: Node3D = player.target
	target_panel.visible = t != null and is_instance_valid(t) and t.is_alive()
	if target_panel.visible:
		target_name.text = t.actor.display_name
		target_hp_bar.max_value = t.max_hp
		target_hp_bar.value = t.hp
