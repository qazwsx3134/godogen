extends Control
## Presentation controller for the authored page scenes. It reads Game state and dispatches
## each scene button's `action` metadata; it never rebuilds a screen tree or owns combat units.
##
## UI action metadata:
##   page:<overview|train|backpack|monster|equipment|adventure|store>
##   settings | pause | save | filter:<kind> | backpack_item:<item_id>
##   train:<0..3> | monster:<0..3> | deploy:<monster_id>
##   equipment_tab:<manage|upgrade> | equipment_owner:<hero|selected_monster>
##   equipment_monster:<0..3> | equipment_filter:<kind>
##   equipment_slot:<owner|selected_monster>:<slot> | equipment_item:<item_id>
##   unequip | upgrade | stage:<0..3> | depart | chapter | buy:<0..3> | gift

@export var reference_preview: bool = false

const MONSTER_FALLBACK_IDS: Array[String] = ["sprout", "fox", "aqua", "mushroom"]
const STAT_KEYS: Array[String] = ["attack", "defense", "health", "speed", "crit", "regen"]
const STAT_LABELS: Array[String] = ["攻擊", "防禦", "生命", "速度", "暴擊", "回復"]
const TRAINING_STAT_KEYS: Array[String] = ["attack", "health", "speed", "regen"]
const HERO_SLOT_KEYS: Array[String] = ["weapon", "shield", "armor", "helmet", "boots", "accessory"]
const HERO_SLOT_LABELS: Array[String] = ["武器", "盾牌", "盔甲", "頭盔", "靴子", "飾品"]
const HERO_SLOT_ICON_INDEX: Array[int] = [0, 3, 4, 5, 6, 7]
const MONSTER_SLOT_KEYS: Array[String] = ["necklace", "badge", "armor", "claws", "cape", "accessory"]
const MONSTER_SLOT_LABELS: Array[String] = ["項圈", "徽章", "護甲", "利爪", "披風", "飾品"]
const MONSTER_SLOT_ICON_INDEX: Array[int] = [8, 9, 10, 11, 12, 14]
const FILTER_KEYS: Array[String] = ["all", "weapon", "armor", "accessory", "other"]

var current_page: String = "overview"
var selected_monster: int = 0
var backpack_filter: String = "all"
var equipment_filter: String = "all"
var equipment_tab: String = "manage"
var equipment_owner: String = "hero"
var selected_equipment_slot: String = ""
var selected_item_id: String = ""
var selected_item_data: Dictionary = {}
var message_remaining: float = 0.0
var feedback_remaining: float = 0.0
var _connected_buttons: Array[Button] = []
var _backpack_items: Array[Dictionary] = []
var _damage_log: Array[String] = []

@onready var game_state: Node = get_node_or_null("/root/Game")
@onready var save_manager: Node = get_node_or_null("/root/SaveManager")
@onready var event_bus: Node = get_node_or_null("/root/EventBus")
@onready var combat_arena: Node2D = %CombatArena
@onready var pages: Control = $Pages
@onready var gold_badge: Label = $Header/GoldBadge
@onready var pause_button: Button = $SettingsPanel/PauseButton

func _ready() -> void:
	_wire_actions(self)
	if game_state != null:
		_connect_if_present(game_state, "gold_changed", _on_gold_changed)
		_connect_if_present(game_state, "combat_pause_changed", _on_combat_pause_changed)
		_connect_if_present(game_state, "changed", _on_game_changed)
	if event_bus != null:
		_connect_if_present(event_bus, "damage_dealt", _on_damage_dealt)
	if save_manager != null:
		_connect_if_present(save_manager, "save_completed", _on_save_completed)
	_on_gold_changed(int(_game_value("gold", 0)))
	_on_combat_pause_changed(bool(_game_value("combat_paused", false)))
	show_page("overview")
	_refresh_all()
	_update_save_notice()
	var load_message := _save_warning_message()
	if not load_message.is_empty():
		show_message(load_message, 7.0)

func _save_warning_message() -> String:
	if save_manager != null:
		var manager_message := str(save_manager.get("last_load_message"))
		if not manager_message.is_empty():
			return manager_message
	return str(_game_value("last_load_message", ""))

func _connect_if_present(target: Node, signal_name: String, callback: Callable) -> void:
	if target.has_signal(signal_name) and not target.is_connected(signal_name, callback):
		target.connect(signal_name, callback)

func _wire_actions(node: Node) -> void:
	if node is Button and node.has_meta("action"):
		var button_node := node as Button
		if not button_node.has_meta("ui_action_wired"):
			button_node.set_meta("ui_action_wired", true)
			button_node.pressed.connect(_dispatch_button.bind(button_node))
	for child in node.get_children():
		_wire_actions(child)

func _dispatch_button(button_node: Button) -> void:
	if is_instance_valid(button_node):
		_action(str(button_node.get_meta("action", "")))

func show_page(id: String) -> void:
	if id not in ["overview", "train", "backpack", "monster", "equipment", "adventure", "store"]:
		return
	current_page = id
	for page in pages.get_children():
		page.visible = str(page.get_meta("page_id", "")) == id
	var socket := pages.get_node_or_null(id.capitalize() + "/BattleSocket") as Node2D
	if socket != null and combat_arena.get_parent() != socket:
		# Arena position.x is its world travel offset. Keeping local transform preserves its march.
		combat_arena.reparent(socket, false)
		if combat_arena.has_method("refresh_spawns"):
			combat_arena.call("refresh_spawns")
	if combat_arena.has_method("set_training_mode"):
		combat_arena.call("set_training_mode", id == "train")
	_set_game_value("current_view", "adventure" if id == "overview" else id)
	_set_nav_selection(id)
	_set_settings_visible(false)
	if feedback_remaining > 0.0:
		_hide_all_damage_feedback()

func _set_nav_selection(page_id: String) -> void:
	var nav := pages.get_node_or_null(page_id.capitalize() + "/Navigation")
	if nav == null:
		return
	for child in nav.get_children():
		if child is Button and str(child.get_meta("action", "")).begins_with("page:"):
			(child as Button).button_pressed = str(child.get_meta("action")).trim_prefix("page:") == page_id

func _action(action: String) -> void:
	if action.is_empty():
		return
	var parts := action.split(":", false)
	var verb := parts[0]
	var value := parts[1] if parts.size() > 1 else ""
	match verb:
		"page": show_page(value)
		"settings": _set_settings_visible(not $SettingsPanel.visible)
		"pause": _toggle_pause()
		"save": _save_now()
		"filter": _set_backpack_filter(value)
		"backpack_item": _inspect_backpack_item(value)
		"train": _train(int(value))
		"monster": _select_monster(int(value))
		"deploy": _toggle_deployment(_monster_id_from_action(value))
		"equipment_tab": _set_equipment_tab(value)
		"equipment_owner": _set_equipment_owner(value)
		"equipment_monster": _select_equipment_monster(int(value))
		"equipment_filter": _set_equipment_filter(value)
		"equipment_slot": _select_equipment_slot(parts)
		"equipment_item": _select_or_equip_item(value)
		"unequip": _unequip_selected_slot()
		"upgrade": _upgrade_selected_item()
		"stage": _select_stage(int(value))
		"depart": _depart()
		"chapter": show_message("目前進度：第 %s 章遠征；路線會持續向前推進。" % _current_chapter())
		"buy": _show_store_demo(int(value))
		"gift": show_message("本機商店示範：沒有播放廣告、發放獎勵或記錄領取狀態。", 6.0)

func _process(delta: float) -> void:
	if message_remaining > 0.0:
		message_remaining = maxf(message_remaining - delta, 0.0)
		$MessagePanel.visible = message_remaining > 0.0
	if feedback_remaining > 0.0:
		feedback_remaining = maxf(feedback_remaining - delta, 0.0)
		if feedback_remaining <= 0.0:
			_hide_all_damage_feedback()

func _game_value(property_name: String, fallback: Variant = null) -> Variant:
	if game_state == null:
		return fallback
	for property in game_state.get_property_list():
		if str(property.get("name", "")) == property_name:
			return game_state.get(property_name)
	return fallback

func _set_game_value(property_name: String, value: Variant) -> void:
	if game_state == null:
		return
	for property in game_state.get_property_list():
		if str(property.get("name", "")) == property_name:
			game_state.set(property_name, value)
			return

func _call_dict(method_name: String, arguments: Array = []) -> Dictionary:
	if game_state == null or not game_state.has_method(method_name):
		return {}
	var result: Variant = game_state.callv(method_name, arguments)
	return result if result is Dictionary else {}

func _call_array(method_name: String, arguments: Array = []) -> Array:
	if game_state == null or not game_state.has_method(method_name):
		return []
	var result: Variant = game_state.callv(method_name, arguments)
	return result if result is Array else []

func _monster_ids() -> Array[String]:
	var result: Array[String] = []
	for value in _call_array("monster_ids"):
		result.append(str(value))
	return result if not result.is_empty() else MONSTER_FALLBACK_IDS.duplicate()

func _monster_id_from_action(value: String) -> String:
	if value.is_valid_int():
		return _monster_id(int(value))
	return value

func _monster_id(index: int) -> String:
	var ids := _monster_ids()
	return ids[clampi(index, 0, ids.size() - 1)] if not ids.is_empty() else ""

func _monster_index(id: String) -> int:
	return maxi(_monster_ids().find(id), 0)

func _hero_info() -> Dictionary:
	return _call_dict("hero_info")

func _monster_info(id: String) -> Dictionary:
	return _call_dict("monster_info", [id])

func _gold() -> int:
	return int(_game_value("gold", 0))

func _commas(value: int) -> String:
	var raw := str(value)
	var result := ""
	for i in raw.length():
		if i > 0 and (raw.length() - i) % 3 == 0:
			result += ","
		result += raw[i]
	return result

func _number(value: Variant) -> String:
	var numeric := float(value)
	if is_equal_approx(numeric, roundf(numeric)):
		return str(int(roundf(numeric)))
	return String.num(numeric, 1)

func _refresh_all() -> void:
	_refresh_header()
	_refresh_training()
	_refresh_backpack()
	_refresh_monsters()
	_refresh_equipment()
	_refresh_adventure()
	_refresh_overview()

func _refresh_header() -> void:
	if not is_node_ready():
		return
	var info := _hero_info()
	var level := int(info.get("level", 1))
	$Header/LevelLabel.text = "Lv. %d" % level
	var xp_next := int(info.get("xp_next", 0))
	var xp := int(info.get("xp", 0))
	$Header/ExperienceBar.value = 100.0 if xp_next <= 0 else clampf(float(xp) / float(xp_next) * 100.0, 0.0, 100.0)
	gold_badge.text = "12,480" if reference_preview else _commas(_gold())

func _on_gold_changed(_value: int) -> void:
	_refresh_header()
	_refresh_training()
	_refresh_equipment()

func _on_game_changed() -> void:
	call_deferred("_refresh_all")

func _refresh_training() -> void:
	if not is_node_ready():
		return
	var levels: Array = _game_value("training", [])
	var hero := _hero_info()
	var stats: Dictionary = hero.get("stats", {})
	for i in 4:
		var row := pages.get_node_or_null("Train/TrainingList/TrainingRow%d" % i)
		if row == null:
			continue
		var level := int(levels[i]) if i < levels.size() else 0
		var cost := int(game_state.call("training_cost", i)) if game_state != null and game_state.has_method("training_cost") else 0
		var current: Variant = stats.get(TRAINING_STAT_KEYS[i], 0)
		row.get_node("TrainingLevel").text = "目前等級 Lv.%d" % level
		row.get_node("CurrentValue").text = "目前數值：%s" % _number(current)
		row.get_node("NextCost").text = "下一級費用：%s 金" % _commas(cost) if cost > 0 else "下一級費用：已達上限"
		var train_button := row.get_node("TrainButton") as Button
		train_button.text = "立即提升" if cost > 0 and _gold() >= cost else ("金幣不足" if cost > _gold() else "已達上限")
		train_button.disabled = cost <= 0 or _gold() < cost

func _train(index: int) -> void:
	if index < 0 or index >= 4 or game_state == null or not game_state.has_method("train"):
		show_message("訓練資料目前無法載入。")
		return
	var result: Variant = game_state.call("train", index)
	if not result is Dictionary:
		show_message("訓練沒有完成。")
		return
	if bool(result.get("ok", false)):
		_save_progress()
		show_message(str(result.get("message", "訓練完成，主角提升一級。")))
	else:
		show_message(str(result.get("message", "目前無法訓練。")))
	_refresh_all()

func _all_compatible_items() -> Array[Dictionary]:
	var unique: Dictionary = {}
	var owners: Array[String] = ["hero"]
	owners.append_array(_monster_ids())
	for owner in owners:
		for item in _call_array("items_for", [owner, "all"]):
			if item is Dictionary:
				var item_id := str(item.get("id", ""))
				if not item_id.is_empty():
					unique[item_id] = item
	var ids: Array = unique.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for item_id in ids:
		result.append(unique[item_id])
	return result

func _make_item_card(grid: GridContainer, item: Dictionary, action: String) -> Control:
	var item_id := str(item.get("id", ""))
	var card_scene_path := "res://scenes/components/equipment_bag_card.tscn" if action.begins_with("equipment_item:") else "res://scenes/components/equipment_item_card.tscn"
	var scene := load(card_scene_path) as PackedScene
	var card := scene.instantiate() as Control
	card.name = "Item_" + item_id.replace("-", "_")
	card.set_meta("item_id", item_id)
	card.set_meta("kind", str(item.get("kind", "other")))
	card.set_meta("slot", str(item.get("slot", "")))
	card.set_meta("equipped_by", str(item.get("equipped_by", "")))
	card.tooltip_text = str(item.get("name", item_id))
	grid.add_child(card)
	card.get_node("Title").text = str(item.get("name", item_id))
	card.get_node("Level").text = "Lv.%d" % int(item.get("level", 1))
	card.get_node("EquippedBy").text = "已裝備" if not str(item.get("equipped_by", "")).is_empty() else str(item.get("kind", ""))
	card.get_node("Icon").texture = _item_icon(int(item.get("icon_index", 0)))
	var select := card.get_node("SelectButton") as Button
	select.set_meta("action", action + item_id)
	select.tooltip_text = str(item.get("name", item_id))
	_wire_actions(card)
	return card

func _item_icon(index: int) -> Texture2D:
	var path := "res://assets/atlas/equipment_item_%d.tres" % index
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	path = "res://assets/atlas/item_%d.tres" % posmod(index, 10)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _clear_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func _refresh_backpack() -> void:
	if not is_node_ready():
		return
	var grid := pages.get_node("Backpack/ItemsGridScroll/ItemsGrid") as GridContainer
	_clear_grid(grid)
	_backpack_items = _all_compatible_items()
	for item in _backpack_items:
		_make_item_card(grid, item, "backpack_item:")
	_apply_backpack_filter()

func _apply_backpack_filter() -> void:
	var page := pages.get_node_or_null("Backpack")
	if page == null:
		return
	var grid := page.get_node("ItemsGridScroll/ItemsGrid") as GridContainer
	var visible_count := 0
	for card in grid.get_children():
		var matches := backpack_filter == "all" or str(card.get_meta("kind", "other")) == backpack_filter
		card.visible = matches
		if matches:
			visible_count += 1
	page.get_node("EmptyState").visible = visible_count == 0
	var tabs := page.get_node("FilterRow")
	for child in tabs.get_children():
		if child is Button:
			var pressed := str(child.get_meta("action", "")) == "filter:" + backpack_filter
			(child as Button).button_pressed = pressed

func _set_backpack_filter(filter: String) -> void:
	backpack_filter = filter if FILTER_KEYS.has(filter) else "all"
	_apply_backpack_filter()

func _inspect_backpack_item(item_id: String) -> void:
	for item in _backpack_items:
		if str(item.get("id", "")) == item_id:
			var equip_text := "目前由 %s 裝備。" % str(item.get("equipped_by", "")) if not str(item.get("equipped_by", "")).is_empty() else "尚未裝備。"
			show_message("%s · %s · Lv.%d\n%s" % [str(item.get("name", item_id)), str(item.get("slot", "")), int(item.get("level", 1)), equip_text], 5.0)
			return
	show_message("找不到這件裝備。")

func _deployed_ids() -> Array[String]:
	var result: Array[String] = []
	var raw: Array = _game_value("deployed", [])
	for value in raw:
		result.append(str(value))
	return result

func _refresh_monsters() -> void:
	if not is_node_ready():
		return
	var ids := _monster_ids()
	if ids.is_empty():
		return
	selected_monster = clampi(selected_monster, 0, ids.size() - 1)
	var selected_id := _monster_id(selected_monster)
	var info := _monster_info(selected_id)
	var grid := pages.get_node("Monster/MonsterGrid") as GridContainer
	var deployed := _deployed_ids()
	pages.get_node("Monster/PetName").text = str(info.get("name", selected_id))
	pages.get_node("Monster/PetLevel").text = "Lv.%d" % int(info.get("level", 1))
	var xp_next := int(info.get("xp_next", 0))
	var xp := int(info.get("xp", 0))
	pages.get_node("Monster/PetExperience").value = 100.0 if xp_next <= 0 else clampf(float(xp) / float(xp_next) * 100.0, 0.0, 100.0)
	pages.get_node("Monster/PetExperienceText").text = "%s / %s XP" % [_commas(xp), _commas(xp_next)]
	pages.get_node("Monster/PetDeploymentStatus").text = "已部署同行" if deployed.has(selected_id) else "未部署同行"
	pages.get_node("Monster/DetailPortrait").texture = _monster_icon(selected_monster)
	_set_stat_summary("Monster/PetStat", "Monster/PetBonus", info)
	for i in ids.size():
		var card := grid.get_node_or_null("MonsterCard%d" % i)
		if card == null:
			continue
		var id := ids[i]
		var monster_info := _monster_info(id)
		var is_deployed := deployed.has(id)
		card.get_node("Title").text = str(monster_info.get("name", id))
		card.get_node("Level").text = "Lv.%d　·　%s XP" % [int(monster_info.get("level", 1)), _commas(int(monster_info.get("xp", 0)))]
		card.get_node("Status").text = "正在同行" if is_deployed else "待命中"
		card.get_node("Icon").texture = _monster_icon(i)
		var inspect := card.get_node("InspectButton") as Button
		inspect.set_meta("action", "monster:%d" % i)
		var deploy := card.get_node("DeploymentButton") as Button
		deploy.text = "撤下" if is_deployed else "部署"
		deploy.set_meta("action", "deploy:" + id)
		deploy.add_theme_stylebox_override("normal", load("res://ui/card_normal.tres") if is_deployed else load("res://ui/green.tres"))
	pages.get_node("Monster/CollectionCount").text = "已部署 %d / %d 隻" % [deployed.size(), ids.size()]

func _monster_icon(index: int) -> Texture2D:
	var path := "res://assets/atlas/monster_%d.tres" % clampi(index, 0, 3)
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _select_monster(index: int) -> void:
	var ids := _monster_ids()
	if index < 0 or index >= ids.size():
		return
	selected_monster = index
	_refresh_monsters()
	_refresh_equipment()

func _toggle_deployment(monster_id: String) -> void:
	if game_state == null or not game_state.has_method("toggle_deployment"):
		show_message("隊伍資料目前無法載入。")
		return
	var result: Variant = game_state.call("toggle_deployment", monster_id)
	if result is Dictionary and bool(result.get("ok", false)):
		_save_progress()
		show_message(str(result.get("message", "同行名單已更新。")))
	else:
		show_message(str(result.get("message", "同行名單無法更新。")) if result is Dictionary else "同行名單無法更新。")
	_refresh_monsters()

func _set_stat_summary(stats_prefix: String, bonus_prefix: String, info: Dictionary) -> void:
	var stats: Dictionary = info.get("stats", {})
	var base: Dictionary = info.get("base", {})
	var bonus: Dictionary = info.get("bonus", {})
	for i in STAT_KEYS.size():
		var stat_key := STAT_KEYS[i]
		var stat_label := pages.get_node_or_null("Monster/%s%s" % [stats_prefix.get_slice("/", 1), stat_key.capitalize()])
		var bonus_label := pages.get_node_or_null("Monster/%s%s" % [bonus_prefix.get_slice("/", 1), stat_key.capitalize()])
		if stat_label is Label:
			(stat_label as Label).text = "%s　%s" % [STAT_LABELS[i], _number(stats.get(stat_key, 0))]
		if bonus_label is Label:
			(bonus_label as Label).text = "基礎 %s　+%s" % [_number(base.get(stat_key, 0)), _number(bonus.get(stat_key, 0))]

func _set_equipment_tab(tab_id: String) -> void:
	equipment_tab = "upgrade" if tab_id == "upgrade" else "manage"
	_refresh_equipment()

func _set_equipment_owner(owner_id: String) -> void:
	equipment_owner = _monster_id(selected_monster) if owner_id == "selected_monster" else "hero"
	selected_equipment_slot = ""
	selected_item_id = ""
	selected_item_data.clear()
	_refresh_equipment()

func _select_equipment_monster(index: int) -> void:
	var ids := _monster_ids()
	if index < 0 or index >= ids.size():
		return
	selected_monster = index
	if equipment_owner != "hero":
		equipment_owner = ids[index]
	selected_equipment_slot = ""
	selected_item_id = ""
	selected_item_data.clear()
	_refresh_monsters()
	_refresh_equipment()

func _set_equipment_filter(filter: String) -> void:
	equipment_filter = filter if FILTER_KEYS.has(filter) else "all"
	_refresh_equipment_grid()
	var row := pages.get_node("Equipment/EquipmentFilterRow")
	for child in row.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("action", "")) == "equipment_filter:" + equipment_filter

func _owner_slot_keys(owner_id: String) -> Array[String]:
	return MONSTER_SLOT_KEYS.duplicate() if owner_id != "hero" else HERO_SLOT_KEYS.duplicate()

func _owner_slot_labels(owner_id: String) -> Array[String]:
	return MONSTER_SLOT_LABELS.duplicate() if owner_id != "hero" else HERO_SLOT_LABELS.duplicate()

func _equipment_for(owner_id: String) -> Dictionary:
	return _call_dict("equipment_for", [owner_id])

func _item_record(item_id: String, owner_hint: String = "") -> Dictionary:
	if item_id.is_empty():
		return {}
	var owners: Array[String] = []
	if not owner_hint.is_empty():
		owners.append(owner_hint)
	if not owners.has("hero"):
		owners.append("hero")
	for id in _monster_ids():
		if not owners.has(id):
			owners.append(id)
	for owner in owners:
		for item in _call_array("items_for", [owner, "all"]):
			if item is Dictionary and str(item.get("id", "")) == item_id:
				return item
	return {}

func _refresh_equipment() -> void:
	if not is_node_ready():
		return
	var page := pages.get_node("Equipment")
	var monster_id := _monster_id(selected_monster)
	var ids := _monster_ids()
	page.get_node("EquipmentMonsterPortrait").texture = _monster_icon(selected_monster)
	var monster_info := _monster_info(monster_id)
	page.get_node("EquipmentMonsterLevel").text = "Lv.%d" % int(monster_info.get("level", 1))
	var hero_info := _hero_info()
	page.get_node("HeroLevel").text = "Lv.%d" % int(hero_info.get("level", 1))
	_set_equipment_slots("HeroSlot", "hero", HERO_SLOT_KEYS, HERO_SLOT_LABELS)
	_set_equipment_slots("MonsterSlot", monster_id, MONSTER_SLOT_KEYS, MONSTER_SLOT_LABELS)
	_set_equipment_stats("HeroStat", hero_info)
	_set_equipment_stats("EquipmentMonsterStat", monster_info)
	for i in 4:
		var select := page.get_node("EquipmentMonster%d" % i) as Button
		if i < ids.size():
			select.text = str(_monster_info(ids[i]).get("name", ids[i]))
			select.set_meta("action", "equipment_monster:%d" % i)
			select.visible = true
			select.button_pressed = i == selected_monster
		else:
			select.visible = false
	var hero_target := page.get_node("UseHeroButton") as Button
	hero_target.button_pressed = equipment_owner == "hero"
	var monster_target := page.get_node("UseMonsterButton") as Button
	monster_target.button_pressed = equipment_owner == monster_id
	page.get_node("ManagementTab").button_pressed = equipment_tab == "manage"
	page.get_node("UpgradeTab").button_pressed = equipment_tab == "upgrade"
	_refresh_equipment_grid()
	var has_selected_slot := not selected_equipment_slot.is_empty()
	var selected_loadout := _equipment_for(equipment_owner)
	var selected_slot_item := str(selected_loadout.get(selected_equipment_slot, "")) if has_selected_slot else ""
	var is_upgrade := equipment_tab == "upgrade"
	page.get_node("ManagementHint").visible = not is_upgrade and selected_item_id.is_empty()
	page.get_node("SelectedItemInfo").visible = not selected_item_id.is_empty()
	page.get_node("SelectedItemCost").visible = is_upgrade
	page.get_node("UnequipButton").visible = not is_upgrade and not selected_slot_item.is_empty()
	page.get_node("UpgradeButton").visible = is_upgrade
	if not selected_item_id.is_empty():
		selected_item_data = _item_record(selected_item_id, equipment_owner)
		page.get_node("SelectedItemInfo").text = "%s　Lv.%d" % [str(selected_item_data.get("name", selected_item_id)), int(selected_item_data.get("level", 1))]
		var cost := int(game_state.call("upgrade_cost", selected_item_id)) if game_state != null and game_state.has_method("upgrade_cost") else 0
		page.get_node("SelectedItemCost").text = "強化費用：%s 金" % _commas(cost) if cost > 0 else "已達最高等級"
		var upgrade_button := page.get_node("UpgradeButton") as Button
		upgrade_button.disabled = is_upgrade and (cost <= 0 or cost > _gold())
	else:
		page.get_node("SelectedItemInfo").text = "尚未選取裝備"
		page.get_node("SelectedItemCost").text = "強化費用：—"
		(page.get_node("UpgradeButton") as Button).disabled = true
	(page.get_node("UnequipButton") as Button).disabled = selected_slot_item.is_empty()

func _set_equipment_slots(prefix: String, owner_id: String, slots: Array[String], labels: Array[String]) -> void:
	var loadout := _equipment_for(owner_id)
	var icon_indexes: Array[int] = HERO_SLOT_ICON_INDEX if prefix == "HeroSlot" else MONSTER_SLOT_ICON_INDEX
	for i in slots.size():
		var slot_name := slots[i]
		var grid_name := "HeroSlotGrid" if prefix == "HeroSlot" else "MonsterSlotGrid"
		var control := pages.get_node_or_null("Equipment/%s/%s%d" % [grid_name, prefix, i]) as Button
		if control == null:
			continue
		var item_id := str(loadout.get(slot_name, ""))
		var item := _item_record(item_id, owner_id)
		control.text = ""
		control.tooltip_text = labels[i] if item_id.is_empty() else "%s · Lv.%d" % [str(item.get("name", item_id)), int(item.get("level", 1))]
		var icon := control.get_node("Icon") as TextureRect
		icon.texture = _item_icon(int(item.get("icon_index", icon_indexes[i])))
		(control.get_node("SlotLabel") as Label).text = labels[i]
		(control.get_node("LevelLabel") as Label).text = "未裝備" if item_id.is_empty() else "Lv.%d" % int(item.get("level", 1))
		control.set_meta("action", "equipment_slot:%s:%s" % [owner_id, slot_name])
		var selected := equipment_owner == owner_id and selected_equipment_slot == slot_name
		control.add_theme_stylebox_override("normal", load("res://ui/slot_selected.tres") if selected else load("res://ui/slot.tres"))

func _set_equipment_stats(prefix: String, info: Dictionary) -> void:
	var stats: Dictionary = info.get("stats", {})
	var base: Dictionary = info.get("base", {})
	var bonus: Dictionary = info.get("bonus", {})
	for i in STAT_KEYS.size():
		var key := STAT_KEYS[i]
		var label_node := pages.get_node_or_null("Equipment/%s%s" % [prefix, key.capitalize()]) as Label
		if label_node != null:
			label_node.text = "%s %s　·　%s +%s" % [STAT_LABELS[i], _number(stats.get(key, 0)), _number(base.get(key, 0)), _number(bonus.get(key, 0))]

func _refresh_equipment_grid() -> void:
	if not is_node_ready():
		return
	var grid := pages.get_node("Equipment/EquipmentItemsGridScroll/EquipmentItemsGrid") as GridContainer
	_clear_grid(grid)
	var items: Array[Dictionary] = []
	for item in _call_array("items_for", [equipment_owner, equipment_filter]):
		if item is Dictionary:
			items.append(item)
	for item in items:
		_make_item_card(grid, item, "equipment_item:")
	pages.get_node("Equipment/EquipmentEmptyState").visible = items.is_empty()
	var filter_row := pages.get_node("Equipment/EquipmentFilterRow")
	for child in filter_row.get_children():
		if child is Button:
			(child as Button).button_pressed = str(child.get_meta("action", "")) == "equipment_filter:" + equipment_filter

func _select_equipment_slot(parts: PackedStringArray) -> void:
	if parts.size() < 3:
		return
	var requested_owner := parts[1]
	if requested_owner == "selected_monster":
		requested_owner = _monster_id(selected_monster)
	if requested_owner != "hero" and not _monster_ids().has(requested_owner):
		return
	equipment_owner = requested_owner
	selected_equipment_slot = parts[2]
	var loadout := _equipment_for(equipment_owner)
	selected_item_id = str(loadout.get(selected_equipment_slot, ""))
	selected_item_data = _item_record(selected_item_id, equipment_owner)
	_refresh_equipment()

func _select_or_equip_item(item_id: String) -> void:
	var item := _item_record(item_id, equipment_owner)
	if item.is_empty():
		show_message("這件裝備目前不適用於此目標。")
		return
	selected_item_id = item_id
	selected_item_data = item
	if equipment_tab == "upgrade":
		_refresh_equipment()
		return
	if game_state == null or not game_state.has_method("equip"):
		show_message("裝備資料目前無法載入。")
		return
	var result: Variant = game_state.call("equip", equipment_owner, item_id)
	if result is Dictionary and bool(result.get("ok", false)):
		selected_equipment_slot = str(item.get("slot", ""))
		_save_progress()
		show_message(str(result.get("message", "裝備已更新。")))
	else:
		show_message(str(result.get("message", "此裝備與目標欄位不相容。")) if result is Dictionary else "此裝備與目標欄位不相容。")
	_refresh_equipment()

func _unequip_selected_slot() -> void:
	if selected_equipment_slot.is_empty() or game_state == null or not game_state.has_method("unequip"):
		show_message("請先選取已裝備的欄位。")
		return
	var result: Variant = game_state.call("unequip", equipment_owner, selected_equipment_slot)
	if result is Dictionary and bool(result.get("ok", false)):
		selected_item_id = ""
		selected_item_data.clear()
		_save_progress()
		show_message(str(result.get("message", "已卸下裝備。")))
	else:
		show_message(str(result.get("message", "無法卸下這個欄位。")) if result is Dictionary else "無法卸下這個欄位。")
	_refresh_equipment()

func _upgrade_selected_item() -> void:
	if selected_item_id.is_empty() or game_state == null or not game_state.has_method("upgrade_equipment"):
		show_message("請先選取要強化的裝備。")
		return
	var cost := int(game_state.call("upgrade_cost", selected_item_id)) if game_state.has_method("upgrade_cost") else 0
	if cost <= 0 or cost > _gold():
		show_message("金幣不足或裝備已達最高等級。")
		return
	var result: Variant = game_state.call("upgrade_equipment", selected_item_id)
	if result is Dictionary and bool(result.get("ok", false)):
		_save_progress()
		show_message(str(result.get("message", "裝備強化完成。")))
	else:
		show_message(str(result.get("message", "裝備強化失敗。")) if result is Dictionary else "裝備強化失敗。")
	_refresh_equipment()

func _refresh_adventure() -> void:
	if not is_node_ready():
		return
	var page := pages.get_node("Adventure")
	var current_stage := _current_stage()
	page.get_node("ChapterButton").text = "第 %s 章遠征　⌄" % _current_chapter()
	page.get_node("LaunchNote").text = "戰鬥會從目前關卡（%s）繼續，不會重設進度。" % current_stage
	for i in 4:
		var card := page.get_node("StageGrid/StageCard%d" % i)
		card.get_node("Title").text = _stage_after(current_stage, i)
		card.get_node("Status").text = "目前進度" if i == 0 else "接續路線"
		card.get_node("SelectButton").disabled = i > 0
	page.get_node("DepartButton").text = "繼續遠征 · %s" % current_stage

func _current_stage() -> String:
	return str(_game_value("current_stage", "1-1"))

func _current_chapter() -> String:
	var parts := _current_stage().split("-")
	return parts[0] if parts.size() == 2 and parts[0].is_valid_int() else "1"

func _stage_after(stage_id: String, offset: int) -> String:
	var parts := stage_id.split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return stage_id if offset == 0 else "持續遠征"
	var chapter := int(parts[0])
	var stage := int(parts[1]) + offset
	while stage > 99 and chapter < 99:
		stage -= 99
		chapter += 1
	stage = mini(stage, 99)
	return "%d-%d" % [chapter, stage]

func _select_stage(index: int) -> void:
	if index != 0:
		show_message("遠征會自動沿目前路線推進。")
		return
	_refresh_adventure()
	show_message("目前遠征關卡：%s；返回戰場後會從這裡繼續。" % _current_stage())

func _depart() -> void:
	var stage := _current_stage()
	if game_state != null and game_state.has_method("set_combat_paused"):
		game_state.call("set_combat_paused", false)
	show_page("overview")
	show_message("繼續遠征！第 %s 關自動戰鬥進行中。" % stage)

func _refresh_overview() -> void:
	if not is_node_ready():
		return
	var hero := _hero_info()
	$Pages/Overview/HeroSummaryName.text = "主角 Lv.%d　·　遠征隊伍" % int(hero.get("level", 1))
	$Pages/Overview/SessionTotals.text = "擊倒 %s 隻　·　金幣 %s　·　第 %s" % [
		_commas(int(_game_value("kills", 0))), _commas(_gold()), str(_game_value("current_stage", "1-1"))
	]
	if not _damage_log.is_empty():
		var combat_log := $Pages/Overview/CombatLogScroll/CombatLog as Label
		combat_log.text = "\n".join(_damage_log)
		combat_log.custom_minimum_size.y = maxf(150.0, _damage_log.size() * 38.0)

func _on_damage_dealt(source: String, target: String, amount: int, remaining: int, maximum: int) -> void:
	var line := "%s 命中 %s，造成 %d 傷害（生命 %d / %d）。" % [
		_unit_name(source), _unit_name(target), amount, remaining, maximum
	]
	_damage_log.append(line)
	while _damage_log.size() > 12:
		_damage_log.pop_front()
	_refresh_overview()
	if combat_arena.has_method("find_unit"):
		var target_unit: Variant = combat_arena.call("find_unit", target)
		if target_unit is Node:
			var feedback: Node = target_unit.get_node_or_null("DamageFeedback")
			if feedback is Label:
				(feedback as Label).text = "-%d" % amount
				(feedback as Label).visible = true
				feedback_remaining = 0.55

func _unit_name(unit_id: String) -> String:
	match unit_id:
		"knight": return "主角"
		"enemy_0", "enemy_1", "enemy_2": return "敵人"
		_: 
			var index := _monster_ids().find(unit_id)
			if index >= 0:
				return str(_monster_info(unit_id).get("name", unit_id))
	return unit_id

func _hide_all_damage_feedback() -> void:
	if combat_arena == null or not combat_arena.has_method("live_units"):
		return
	for unit in combat_arena.call("live_units"):
		if unit is Node:
			var feedback: Node = unit.get_node_or_null("DamageFeedback")
			if feedback is Control:
				(feedback as Control).visible = false

func _toggle_pause() -> void:
	if game_state != null and game_state.has_method("set_combat_paused"):
		game_state.call("set_combat_paused", not bool(_game_value("combat_paused", false)))

func _on_combat_pause_changed(paused: bool) -> void:
	if is_instance_valid(pause_button):
		pause_button.text = "繼續戰鬥" if paused else "暫停戰鬥"

func _set_settings_visible(value: bool) -> void:
	if not is_node_ready():
		return
	$SettingsPanel.visible = value
	$SettingsDimmer.visible = value

func _save_now() -> void:
	if save_manager != null and save_manager.has_method("save_game"):
		save_manager.call("save_game")
	else:
		show_message("本機存檔目前無法使用。")

func _save_progress() -> void:
	if save_manager != null and save_manager.has_method("save_game"):
		save_manager.call("save_game")

func _on_save_completed(_success: bool, message: String) -> void:
	_update_save_notice()
	var load_message := _save_warning_message()
	show_message(load_message if not load_message.is_empty() else message, 6.0)

func _update_save_notice() -> void:
	if not is_node_ready() or save_manager == null:
		return
	$SettingsPanel/SaveNotice.text = str(save_manager.get("last_load_message"))
	$SettingsPanel/SaveButton.text = "存檔受保護" if bool(save_manager.get("writes_blocked")) else "儲存進度"

func _show_store_demo(product_index: int) -> void:
	var products: Array[String] = ["金幣袋", "寶石", "怪獸糧食", "回復藥水"]
	var name := products[clampi(product_index, 0, products.size() - 1)]
	show_message("%s：本機商店示範，沒有扣款、扣寶石或發放商品。" % name, 6.0)

func show_message(value: String, seconds: float = 4.0) -> void:
	$MessagePanel/MessageText.text = value
	message_remaining = seconds
	$MessagePanel.visible = seconds > 0.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if $SettingsPanel.visible:
		_set_settings_visible(false)
	elif message_remaining > 0.0:
		message_remaining = 0.0
		$MessagePanel.visible = false
	else:
		show_page("overview")
	get_viewport().set_input_as_handled()
