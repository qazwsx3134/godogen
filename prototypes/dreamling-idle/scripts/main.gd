extends Control
const GameModel = preload("res://domain/game_model.gd")
const SaveRepository = preload("res://domain/save_repository.gd")
const ITEM_SCENE = preload("res://scenes/items/equipment_card.tscn")
var model: RefCounted
var repository: RefCounted
var selected_unit: String = "moss"
var _ui_elapsed: float = 0.0
var _save_elapsed: float = 0.0
var _toast_left: float = 0.0
var _inventory_signature: String = ""
var _last_revision: int = -1
var _qa: bool = false
@onready var driver: Node = %SimulationDriver
@onready var lane: Control = %BattleLane
@onready var roster_panel: Control = %RosterPanel
@onready var equipment_panel: Control = %EquipmentPanel
@onready var map_panel: Control = %MapPanel
@onready var talent_panel: Control = %TalentPanel
@onready var codex_panel: Control = %CodexPanel
@onready var report_panel: Control = %ReportPanel
@onready var sfx: Node = %Sfx


func _ready() -> void:
	_qa = "--qa" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		_qa = _qa or bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('qa') === '1'"))
	repository = SaveRepository.new("user://qa_profile.json" if _qa else "user://profile.json")
	var resume_qa: bool = _qa and OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('resume') === '1'"))
	var loaded: Dictionary = repository.restore() if not _qa or resume_qa else {"state": {}, "source": "qa", "message": "試玩測試存檔獨立。"}
	model = GameModel.new(2026, loaded.state)
	driver.model = model
	driver.advanced.connect(_on_advanced)
	lane.bind(model)
	for card: Node in roster_panel.get_node("%UnitCards").get_children():
		card.inspected.connect(select_unit)
		card.deployment_requested.connect(func(id: String) -> void: _command(model.deploy(id)))
	for card: Node in map_panel.get_node("%StageCards").get_children():
		card.travel_requested.connect(func(index: int) -> void: _command(model.select_stage(index)))
	for card: Node in talent_panel.get_node("%TalentCards").get_children():
		card.purchase_requested.connect(func(id: String) -> void: _command(model.buy_talent(id)))
	roster_panel.get_node("%Train").pressed.connect(func() -> void: _command(model.train(selected_unit)))
	roster_panel.get_node("%Recruit").pressed.connect(func() -> void: _command(model.recruit(selected_unit)))
	equipment_panel.get_node("%RemoveWeapon").pressed.connect(func() -> void: _command(model.unequip(_equipment_unit(), "weapon")))
	equipment_panel.get_node("%RemoveArmor").pressed.connect(func() -> void: _command(model.unequip(_equipment_unit(), "armor")))
	equipment_panel.get_node("%ClaimPending").pressed.connect(func() -> void: _command(model.claim_pending()))
	equipment_panel.get_node("%EquipUnit").item_selected.connect(_on_equipment_unit)
	%Pause.pressed.connect(_toggle_pause)
	%Save.pressed.connect(_save)
	%Sound.pressed.connect(_toggle_sound)
	%AutoAdvance.toggled.connect(func(value: bool) -> void: model.set_auto(value); _save())
	%DismissHelp.pressed.connect(func() -> void: model.state.tutorial_seen = true; %HelpBar.hide(); _save())
	%Pages.tab_changed.connect(func(_index: int) -> void: refresh())
	%HelpBar.visible = not model.state.tutorial_seen
	%Save.disabled = repository.read_only
	%SaveStatus.text = loaded.message
	if repository.read_only:
		%RecoveryNotice.text = loaded.message
		%RecoveryNotice.show()
	refresh()
	_notify("先看隊伍自動作戰；覺得吃力時，試試讓露露上陣。")
	_on_advanced()


func _process(delta: float) -> void:
	if model == null: return
	_ui_elapsed += delta
	_save_elapsed += delta
	_toast_left = maxf(0.0, _toast_left - delta)
	%Toast.modulate.a = clampf(_toast_left * 2.0, 0.0, 1.0)
	if _ui_elapsed >= 0.2:
		_ui_elapsed = 0.0
		refresh()
	if _save_elapsed >= 20.0:
		_save_elapsed = 0.0
		if model.dirty and not repository.read_only: _save(false)


func _on_advanced() -> void:
	for event: Dictionary in model.drain_events():
		if event.kind == "encounter": lane.bind(model)
		lane.display(event)
		if event.kind == "notice":
			var category: String = str(event.get("category", ""))
			if category in ["clear", "level", "defeat", "capacity"]: _notify(event.message)
			if not model.state.muted and category in ["loot", "level", "clear"]:
				sfx.play(&"loot" if category == "loot" else &"upgrade", 0.2)


func select_unit(id: String) -> void:
	selected_unit = id
	refresh()


func refresh() -> void:
	if model == null: return
	%Gold.text = "%s 金" % _format_number(int(model.state.gold))
	%Collection.text = "同行 %d／6  ·  擊倒 %d" % [model.state.roster.size(), int(model.state.kills)]
	var stage: Dictionary = model.catalog.stages[int(model.state.stage)]
	%CurrentStage.text = "01-%02d  %s" % [int(model.state.stage) + 1, stage.name]
	%BattleState.text = "休整中 · 即將返回獵場" if model.phase == "recover" else ("小隊正在前進…" if model.phase == "advance" else "第 %d／3 波 · 敵人 %d" % [model.wave + 1, model.actors.filter(func(a: Dictionary) -> bool: return not a.friendly and float(a.hp) > 0).size()])
	%StageProgress.value = float(model.wave) * 33.333
	%PartyStatus.text = "上陣 %d／%d  ·  %s" % [model.state.deployed.size(), model.slots(), "配置已排隊，下波生效" if model.build_pending else "配置已生效"]
	%BondSummary.text = model.bond_text()
	%Pause.text = "繼續" if model.paused else "暫停"
	%Sound.text = "聲音：關" if model.state.muted else "聲音：開"
	%AutoAdvance.set_pressed_no_signal(model.state.auto_advance)
	for card: Node in roster_panel.get_node("%UnitCards").get_children(): card.refresh(model, selected_unit)
	_refresh_detail()
	_refresh_equipment()
	for card: Node in map_panel.get_node("%StageCards").get_children(): card.refresh(model)
	for card: Node in talent_panel.get_node("%TalentCards").get_children(): card.refresh(model)
	_refresh_codex()
	_refresh_report()
	_last_revision = model.revision
	_publish_qa()


func _refresh_detail() -> void:
	var definition: Dictionary = model.catalog.units[selected_unit]
	var owned: bool = model.state.roster.has(selected_unit)
	roster_panel.get_node("%DetailName").text = "%s · %s" % [definition.name, definition.job_name]
	roster_panel.get_node("%DetailTags").text = "%s ／ %s" % [definition.race_name, definition.element_name]
	roster_panel.get_node("%DetailDescription").text = definition.description
	var values: Dictionary = model.stats(selected_unit)
	roster_panel.get_node("%DetailStats").text = "生命  %d\n攻擊  %d\n護甲  %d\n攻擊間隔  %.2f 秒\n治療係數  %.1f × 攻擊" % [roundi(values.hp), roundi(values.attack), roundi(values.defense), values.interval, values.heal]
	var train: Button = roster_panel.get_node("%Train")
	train.visible = owned
	train.disabled = owned and int(model.state.roster[selected_unit].level) >= model.catalog.level_cap
	train.text = "訓練升級 · %d 金" % model.train_cost(selected_unit) if owned else "訓練"
	var recruit: Button = roster_panel.get_node("%Recruit")
	recruit.visible = not owned
	recruit.text = "邀請同行 · %d 金" % int(definition.cost)
	recruit.disabled = int(model.state.best_stage) + 1 < int(definition.unlock)
	if owned:
		var progress: Dictionary = model.state.roster[selected_unit]
		roster_panel.get_node("%DetailXP").text = "Lv.%d  ·  EXP %d／%d\n經驗由上陣戰鬥取得；訓練可直接補滿本級。" % [progress.level, progress.xp, model.xp_needed(int(progress.level))]
	else:
		roster_panel.get_node("%DetailXP").text = "完成 %d 個關卡後，可邀請這位新夥伴。" % int(definition.unlock)


func _refresh_equipment() -> void:
	var picker: OptionButton = equipment_panel.get_node("%EquipUnit")
	var owned: Array = model.state.roster.keys()
	if picker.item_count != owned.size():
		picker.clear()
		for id: String in owned:
			picker.add_item(model.catalog.units[id].name)
			picker.set_item_metadata(picker.item_count - 1, id)
	if not model.state.roster.has(selected_unit):
		picker.select(0)
	var equip_id: String = selected_unit if model.state.roster.has(selected_unit) else str(owned[0])
	for i: int in picker.item_count:
		if picker.get_item_metadata(i) == equip_id: picker.select(i)
	for slot: String in ["weapon", "armor"]:
		var entry: Dictionary = model.item(str(model.state.equipped[equip_id][slot]))
		var name: String = "Weapon" if slot == "weapon" else "Armor"
		equipment_panel.get_node("%" + name + "Name").text = entry.get("name", "未穿戴")
		equipment_panel.get_node("%Remove" + name).disabled = entry.is_empty()
	%BagSummary.text = "背包 %d／%d · 待領 %d／%d" % [model.bag_count(), model.catalog.bag_capacity, model.state.pending.size(), model.catalog.pending_capacity]
	equipment_panel.get_node("%ClaimPending").text = "領取待領裝備（%d）" % model.state.pending.size()
	var signature: String = ",".join(model.state.items.map(func(entry: Dictionary) -> String: return entry.uid))
	var cards: Node = equipment_panel.get_node("%GearCards")
	if signature != _inventory_signature:
		for child: Node in cards.get_children():
			cards.remove_child(child)
			child.queue_free()
		for entry: Dictionary in model.state.items:
			var card: Control = ITEM_SCENE.instantiate()
			cards.add_child(card)
			card.action_requested.connect(_equipment_action)
		_inventory_signature = signature
	for i: int in model.state.items.size(): cards.get_child(i).refresh(model.state.items[i], model, equip_id)


func _refresh_codex() -> void:
	var text: String = "[font_size=24]旅途中的六位夢靈[/font_size]\n[color=#aab1c5]曾經加入的夥伴都記錄在這裡；本版不包含閃光與進化。[/color]\n\n"
	for id: String in model.catalog.units:
		var definition: Dictionary = model.catalog.units[id]
		text += "[color=#d8c59f]%s  %s[/color]  ·  %s／%s\n%s\n\n" % ["●" if model.state.roster.has(id) else "○", definition.name, definition.race_name, definition.job_name, definition.description]
	codex_panel.get_node("%CodexText").text = text


func _refresh_report() -> void:
	var seconds: float = maxf(model.elapsed, 1.0)
	var text: String = "[color=#d8c59f]這趟旅程[/color]\n擊倒 %d  ·  首通 %d／6  ·  休整 %d\n累計獲得 %d 金\n\n[color=#d8c59f]本次開啟的戰鬥貢獻[/color]\n" % [model.state.kills, model.state.cleared.size(), model.state.defeats, model.state.earned]
	for id: String in model.state.roster:
		text += "%s：傷害 %d（%.1f／秒）· 有效治療 %d\n" % [model.catalog.units[id].name, int(model.session_damage.get(id, 0)), float(model.session_damage.get(id, 0)) / seconds, roundi(float(model.session_heal.get(id, 0)))]
	text += "\n[color=#aab1c5]戰鬥依固定時間推進；關閉遊戲後暫停收益。\n卡關時可回刷、訓練，或用療癒者與羈絆調整隊伍。[/color]"
	report_panel.get_node("%StatsText").text = text
	var lines: Array[String] = []
	var journal: Array = model.state.journal
	for i: int in range(journal.size() - 1, maxi(-1, journal.size() - 41), -1):
		var entry: Dictionary = journal[i]
		var tint: String = "d8c59f" if entry.kind in ["clear", "loot", "level"] else "b5bed0"
		lines.append("[color=#%s]%02d:%02d  %s[/color]" % [tint, int(entry.seconds) / 60, int(entry.seconds) % 60, entry.message])
	report_panel.get_node("%Journal").text = "\n".join(lines)


func _on_equipment_unit(index: int) -> void:
	selected_unit = str(equipment_panel.get_node("%EquipUnit").get_item_metadata(index))
	refresh()


func _equipment_unit() -> String:
	return selected_unit if model.state.roster.has(selected_unit) else str(model.state.roster.keys()[0])


func _equipment_action(action: String, uid: String) -> void:
	var equip_id: String = selected_unit if model.state.roster.has(selected_unit) else str(model.state.roster.keys()[0])
	match action:
		"equip": _command(model.equip(equip_id, uid))
		"sell": _command(model.sell(uid))
		"lock": _command(model.lock_item(uid))


func _command(result: Dictionary) -> void:
	_notify(result.message, not result.ok)
	if result.ok:
		if not model.state.muted: sfx.play(&"upgrade", 0.1)
		_save(false)
	refresh()


func _toggle_pause() -> void:
	model.paused = not model.paused
	_notify("戰鬥已暫停，可安心整理隊伍。" if model.paused else "繼續旅程。")
	refresh()


func _toggle_sound() -> void:
	model.state.muted = not model.state.muted
	if not model.state.muted: sfx.play(&"click")
	_save(false)
	refresh()


func _save(show_message: bool = true) -> void:
	if model == null or repository == null: return
	var error: Error = repository.save(model.snapshot())
	if error == OK:
		model.dirty = false
		%SaveStatus.text = "已儲存 · 關閉後暫停收益"
		if show_message: _notify("旅程已儲存。")
	elif not repository.read_only:
		%SaveStatus.text = "儲存失敗：" + error_string(error)
		_notify(%SaveStatus.text, true)
	elif show_message:
		_notify("目前是唯讀試玩，不會覆寫原存檔。", true)


func _notify(message: String, warning: bool = false) -> void:
	%Toast.text = message
	%Toast.add_theme_color_override("font_color", Color("f1b6aa") if warning else Color("d8dccb"))
	_toast_left = 5.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save(false)


func _exit_tree() -> void:
	if model != null and repository != null and not repository.read_only:
		repository.save(model.snapshot())


static func _format_number(value: int) -> String:
	return "%.1fk" % (float(value) / 1000.0) if value >= 10000 else str(value)


func _publish_qa() -> void:
	if not _qa or not OS.has_feature("web"): return
	var controls: Array = []
	for node: Node in find_children("*", "BaseButton", true, false):
		if not node.is_visible_in_tree(): continue
		var rectangle: Rect2 = node.get_global_rect()
		if not rectangle.intersects(get_global_rect()): continue
		var visible_rectangle: Rect2 = rectangle.intersection(get_global_rect())
		var ancestor: Node = node.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				visible_rectangle = visible_rectangle.intersection(ancestor.get_global_rect())
			ancestor = ancestor.get_parent()
		if visible_rectangle.size.y < rectangle.size.y - 1.0 or visible_rectangle.size.x < rectangle.size.x - 1.0: continue
		controls.append({"key": str(get_path_to(node)), "caption": node.text,
			"disabled": node.disabled, "x": rectangle.position.x, "y": rectangle.position.y,
			"w": rectangle.size.x, "h": rectangle.size.y})
	var tabs: Array = []
	var bar: TabBar = %Pages.get_tab_bar()
	for i: int in bar.tab_count:
		var rectangle: Rect2 = bar.get_tab_rect(i)
		rectangle.position += bar.global_position
		tabs.append({"index": i, "x": rectangle.position.x, "y": rectangle.position.y, "w": rectangle.size.x, "h": rectangle.size.y})
	var info: Dictionary = {"ready": true, "gold": int(model.state.gold), "roster": model.state.roster,
		"deployed": model.state.deployed, "stage": int(model.state.stage), "slots": model.slots(),
		"paused": model.paused, "selected": selected_unit, "tab": %Pages.current_tab,
		"save_status": %SaveStatus.text, "logical_size": {"w": size.x, "h": size.y}, "controls": controls, "tabs": tabs}
	JavaScriptBridge.eval("window.__dreamlingQA = " + JSON.stringify(info), true)
