extends "res://scripts/aquarium.gd"

const State = preload("res://scripts/care_state.gd")
const Betta = preload("res://scripts/betta.gd")
const EGG_ICONS := {1: "long_egg", 2: "silver_egg", State.CARDINAL_EGG: "cardinal_egg"}
const Food = preload("res://scripts/food.gd")
const Journal = preload("res://scripts/breeding_journal.gd")
const FLOOR_HEIGHT := -2.28
const ROTATION_STEP := PI / 6.0
const USE_ITEM := 1
const SELL_ITEM := 2
const STORE_DECOR := 0

const HOMES := [
	Vector3(-1.32, 0.37, 1.2), Vector3(1.23, 0.48, 0.62),
	Vector3(-2.79, 0.92, -0.8), Vector3(2.82, -0.33, 1.25),
	Vector3(-3.7, -0.5, 1.48), Vector3(3.55, 0.84, -0.75),
	Vector3(-0.48, 1.4, -2.1), Vector3(1.18, -0.85, 1.9),
]

@onready var _world: Node3D = _tank.get_node("Tank")
@onready var _fish_group: Node3D = _world.get_node("Fish")
@onready var _egg_group: Node3D = _tank.get_node("Eggs")
@onready var _food_group: Node3D = _tank.get_node("Pellets")
@onready var _audio = %TankAudio
@onready var _status: Label = %FishPanel.get_node("Details/Status")
@onready var _rename: LineEdit = %RenameFish
@onready var _shop: MenuButton = %Shop
@onready var _inventory_bar: Control = $Controls/Inventory
@onready var _inventory_button: Button = %InventoryToggle
@onready var _props := {
	"grass": _world.get_node("Plants/WaterGrass6") as Node3D,
	"wood": _world.get_node("Hardscape/DriftwoodBranch") as Node3D,
	"lamp": %PlacedLamp as Node3D,
}
@onready var _returns: MenuButton = %Returns
@onready var _dialog: PanelContainer = %CareDialog
@onready var _journal: Journal = $Controls/BreedingJournal

var save_path := "user://aquarium_care.dat"
var clock_override: Callable
var _state := State.new()
var _actors: Dictionary = {}
var _ids: Dictionary = {}
var _hunger_icons: Dictionary = {}
var _inventory_snapshot: Dictionary = {}
var _eggs: Dictionary = {}
var _pellets: Array[Food] = []
var _preferred := 0
var _aiming := false
var _feed_key := ""
var _placing_key := ""
var _school_time := 0.0
var _preview_yaw := 0.0
var _placement_point := Vector2.ZERO
var _pointer := Vector2.ZERO
var _batch_received := false
var _last_tick := -1
var _time_floor := 0
var _wall_start := 0
var _ticks_start := 0
var _toast_until := 0
var _dialog_fish := 0
var _return_chime := false
var _default_fov: float
var _highlight_id := 0
var _highlight_until := 0


func _ready() -> void:
	super()
	_default_fov = _base_fov
	_wall_start = int(Time.get_unix_time_from_system())
	_ticks_start = Time.get_ticks_msec()
	for child in _fish_group.get_children():
		_fish_group.remove_child(child)
		child.queue_free()
	_state.open(save_path, _now())
	if _state.data.is_empty():
		$Controls/CareBar.hide()
		_show_notice(_state.last_error, 9999.0)
		return
	_time_floor = _state.data.saved_at
	_wall_start = maxi(_wall_start, _time_floor)
	var notices_before: int = _state.data.notices.size()
	_state.settle(_now())
	_return_chime = _state.data.notices.size() > notices_before
	_shop.get_popup().id_pressed.connect(_buy)
	_returns.get_popup().id_pressed.connect(_open_notice)
	%FeedFish.pressed.connect(_begin_feed)
	%RenameFish.text_submitted.connect(_rename_selected)
	%ViewFamily.pressed.connect(_view_family)
	%RehomeFish.pressed.connect(_open_rehome)
	%Journal.pressed.connect(_show_journal)
	_journal.dismissed.connect(_close_overlay)
	_journal.locate_fish.connect(_locate_from_journal)
	%CloseDialog.pressed.connect(_close_overlay)
	%Confirm.pressed.connect(_confirm_dialog)
	_inventory_button.toggled.connect(_toggle_inventory)
	%RotateDecor.pressed.connect(_rotate_placement.bind(1.0))
	%ApplyDecor.pressed.connect(_confirm_placement)
	%CancelTool.pressed.connect(_cancel_tool)
	%AudioSettings.pressed.connect(_open_audio)
	%CloseAudio.pressed.connect(_close_overlay)
	_audio.bind_settings(%AudioPanel)
	_sync()


func _now() -> int:
	if clock_override.is_valid():
		_time_floor = maxi(_time_floor, int(clock_override.call()))
	else:
		var elapsed := (Time.get_ticks_msec() - _ticks_start) / 1000.0
		_time_floor = maxi(_time_floor, maxi(int(Time.get_unix_time_from_system()), _wall_start + int(elapsed)))
	return _time_floor


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_pointer = (make_input_local(event) as InputEventMouse).position
	elif event is InputEventScreenTouch:
		_pointer = (make_input_local(event) as InputEventScreenTouch).position
	if not (_aiming or not _placing_key.is_empty()):
		super(event)
		return
	if event.is_action_pressed("ui_cancel") or (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_cancel_tool()
		get_viewport().set_input_as_handled()
	elif not _placing_key.is_empty() and event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_Q, KEY_E]:
			_rotate_placement(-1.0 if event.physical_keycode == KEY_Q else 1.0)
			get_viewport().set_input_as_handled()
			return
	super(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _dialog.visible or %AudioPanel.visible or _journal.visible:
			_close_overlay()
			get_viewport().set_input_as_handled()
			return
		if _inventory_bar.visible:
			_inventory_button.button_pressed = false
			get_viewport().set_input_as_handled()
			return
	super(event)


func _tap_water(point: Vector2) -> void:
	if _dialog.visible or %AudioPanel.visible or _journal.visible:
		return
	if not _placing_key.is_empty():
		var hit: Variant = _floor_point(point)
		if hit is Vector2:
			_placement_point = hit
			_preview_placement()
	elif _aiming:
		var desired := _feed_point(point)
		var feed := _feed_key
		_cancel_feed()
		_drop(desired, feed)
	else:
		super(point)


func _process(delta: float) -> void:
	super(delta)
	if _state.data.is_empty():
		return
	var now := _now()
	if now != _last_tick:
		_last_tick = now
		var before: int = _state.data.notices.size()
		if _state.settle(now):
			_sync()
			_announce_live(before)
		_update_card()
		if _journal.visible:
			_journal.tick(now)
	_school_time += delta
	_update_school()
	_tick_food(now)
	_update_hunger_icons(now)
	for id: int in _eggs:
		var egg: Node3D = _eggs[id]
		var entry := _state.fish(id)
		var fraction := clampf(1.0 - (entry.born_at - now) / float(State.HATCH_SECONDS), 0, 1)
		for shell_index in 3:
			var shell := egg.get_node("Shell%d" % shell_index) as MeshInstance3D
			(shell.material_override as StandardMaterial3D).albedo_color.a = 1.0 - fraction * 0.65
	if _aiming:
		%FeedAim.position = _world_to_ui(_feed_point(_pointer)) - Vector2(6, 11)
		%FeedAim.visible = true
	var newborn: Fish = _actors.get(_highlight_id)
	%BirthMarker.visible = is_instance_valid(newborn) and newborn.visible and Time.get_ticks_msec() < _highlight_until
	if %BirthMarker.visible:
		%BirthMarker.position = _world_to_ui(newborn.global_position + Vector3.UP * 0.34) - Vector2(6, 11)
	if Time.get_ticks_msec() >= _toast_until:
		%TankNotice.text = ""


func _sync() -> void:
	for id in _actors.keys():
		if not _state.data.fish.has(id):
			var actor: Fish = _actors[id]
			_ids.erase(actor)
			_hunger_icons[id].queue_free()
			_hunger_icons.erase(id)
			_actor_release(actor)
			_actors.erase(id)
	_stored.clear()
	for id: int in _state.data.fish:
		var entry := _state.fish(id)
		if entry.stage == "egg":
			if entry.stored:
				continue
			if not _eggs.has(id):
				var egg := (load("res://scenes/egg.tscn") as PackedScene).instantiate() as Node3D
				egg.position = Vector3(-0.72 + entry.slot * 0.47, -1.74, 2.34 - entry.slot * 0.08)
				for index in 3:
					var shell := egg.get_node("Shell%d" % index) as MeshInstance3D
					shell.material_override = shell.material_override.duplicate()
					(shell.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_egg_group.add_child(egg)
				_eggs[id] = egg
			continue
		if _eggs.has(id):
			_eggs[id].queue_free()
			_eggs.erase(id)
		if not _actors.has(id):
			_spawn_fish(id, entry)
		var fish: Fish = _actors[id]
		var adult: bool = entry.stage == "adult"
		fish.scale = Vector3.ONE * (1.0 if adult else 0.69)
		if entry.species == State.CARDINAL:
			fish.marker_drop = 0.23 if adult else 0.18
		else:
			fish.marker_drop = 0.42 if adult else 0.29
			fish.get_node("%Body").set_instance_shader_parameter("silver_strength", 1.0 if adult else 0.56)
		fish.set_in_tank(not entry.stored)
		if entry.stored:
			_stored.append(fish)
	_refresh_storage()
	_refresh_menus()
	_refresh_inventory()
	_apply_decor()
	_update_card()
	if _journal.visible:
		_journal.refresh(_now())


func _spawn_fish(id: int, entry: Dictionary) -> void:
	var cardinal: bool = entry.species == State.CARDINAL
	var scene := "res://scenes/cardinal.tscn" if cardinal else "res://scenes/betta.tscn"
	var actor := (load(scene) as PackedScene).instantiate() as Fish
	actor.name = "Fish%d" % id
	actor.fish_name = _state.title(entry) if cardinal else entry.name
	if cardinal:
		actor.appearance = "紅色下腹 · 藍色亮帶"
		actor.tail_speed = 12.0
		actor.tail_swing = 0.4
		actor.mouth_tip = 0.35
	else:
		var betta := actor as Betta
		betta.long_tail = (entry.traits & 1) != 0
		betta.silver = (entry.traits & 2) != 0
	actor.position = HOMES[entry.slot]
	actor.phase = float(entry.slot) * 0.37
	actor.swim_period = 12.0 + entry.slot * 1.3
	actor.swim_span = Vector3(1.35 if entry.slot < 4 else 1.12, 0.39, 0.82)
	actor.start_facing_left = entry.slot % 2 == 1
	_fish_group.add_child(actor)
	_actors[id] = actor
	_ids[actor] = id
	var icon := (load("res://scenes/hunger_icon.tscn") as PackedScene).instantiate() as TextureRect
	icon.name = "Hunger%d" % id
	%HungerIcons.add_child(icon)
	_hunger_icons[id] = icon


func _update_school() -> void:
	var school: Array[Fish] = []
	for id: int in _actors:
		var fish: Fish = _actors[id]
		if _state.fish(id).species == State.CARDINAL:
			fish.school_slot = -1
			if fish.visible:
				school.append(fish)
	if school.size() < 3:
		return
	for index in school.size():
		school[index].school_slot = index
		school[index].school_time = _school_time


func _update_hunger_icons(now: int) -> void:
	var view := Rect2(Vector2.ZERO, size)
	for id: int in _hunger_icons:
		var icon: TextureRect = _hunger_icons[id]
		var actor: Fish = _actors[id]
		var point := _world_to_ui(actor.global_position + Vector3.UP * actor.marker_drop)
		var icon_rect := Rect2(point - Vector2(icon.size.x * 0.5, icon.size.y), icon.size)
		icon.visible = _state.can_eat(id, now) and view.encloses(icon_rect)
		if icon.visible:
			icon.position = icon_rect.position.round()


func _actor_release(actor: Fish) -> void:
	actor.set_in_tank(false)
	actor.queue_free()


func _select(fish: Fish) -> void:
	var changed := _selected != fish
	super(fish)
	if changed and not _state.data.is_empty():
		_audio.sound("panel")
	if fish:
		var entry := _state.fish(_selected_id())
		_rename.text = entry.get("name", "")
		_update_card()


func _selected_id() -> int:
	return _ids.get(_selected, 0)


func _update_card() -> void:
	var id := _selected_id()
	if not _panel.visible or id == 0:
		return
	var now := _now()
	var entry := _state.fish(id)
	var young: bool = entry.stage == "juvenile"
	_status.text = "幼魚" if young else "成魚"
	if _selected.school_slot >= 0:
		_status.text += " · 群游"
	%Hunger.text = "想吃" if _state.can_eat(id, now) else "吃飽了 · %s" % _time_text(entry.last_meal + State.MEAL_SECONDS - now)
	%Growth.visible = young or entry.breed_at > now
	%Growth.text = "成長 %s · 已吃 %d／2 餐" % [
		_time_text(entry.born_at + State.GROW_SECONDS - now), mini(entry.meals, 2)
	] if young else "繁殖準備 %s" % _time_text(entry.breed_at - now)
	%ViewFamily.visible = entry.parents.size() == 2


func _rename_selected(value: String) -> void:
	var id := _selected_id()
	if id == 0:
		return
	if _state.rename_fish(id, value, _now()):
		var entry := _state.fish(id)
		_selected.fish_name = _state.title(entry) if entry.species == State.CARDINAL else entry.name
		_fish_name.text = _selected.display_name()
		_rename.text = entry.name
		_rename.release_focus()
		_refresh_menus()
	else:
		_show_notice(_state.last_error)


func _store_selected() -> void:
	var id := _selected_id()
	if id != 0 and _state.store_fish(id, true, _now()):
		_cancel_feed()
		_select(null)
		_sync()
	elif id != 0:
		_show_notice(_state.last_error)


func _restore(index: int) -> void:
	if index not in range(_stored.size()):
		return
	var fish := _stored[index]
	if _state.store_fish(_ids[fish], false, _now()):
		_sync()
		_select(fish)
	else:
		_show_notice(_state.last_error)


func _begin_feed(feed := "") -> void:
	_cancel_placement()
	if feed.is_empty() and _selected_id() == 0:
		return
	if not _pellets.is_empty():
		_show_notice("先等這撮餌吃完或沉下去。")
		return
	_preferred = _selected_id()
	_feed_key = feed
	_aiming = true
	_panel.hide()
	_inventory_button.button_pressed = false
	_update_tool_buttons()
	_show_notice("點水面投餌")


func _cancel_feed() -> void:
	if _aiming:
		_aiming = false
		%FeedAim.hide()
		_update_tool_buttons()
		_show_notice("", 0.0)


func _feed_point(mouse: Vector2) -> Vector3:
	var pixel := mouse * Vector2(_tank.size) / size
	var ray := _camera.project_ray_normal(pixel)
	var fallback := _selected.global_position if is_instance_valid(_selected) else Vector3(0, 0.4, 0.8)
	var plane := Plane(Vector3.BACK, fallback.z)
	var point: Variant = plane.intersects_ray(_camera.project_ray_origin(pixel), ray)
	var world: Vector3 = point if point is Vector3 else fallback
	return Vector3(clampf(world.x, -5.5, 5.5), clampf(world.y + 0.13, -1.62, 2.65), world.z)


func _world_to_ui(world: Vector3) -> Vector2:
	return _camera.unproject_position(world) * size / Vector2(_tank.size)


func _drop(point: Vector3, feed: String) -> void:
	if not _pellets.is_empty():
		return
	if not feed.is_empty() and not _state.spend_feed(feed, _now()):
		_show_notice(_state.last_error)
		return
	_refresh_inventory()
	_batch_received = false
	for i in range(-1, 2):
		var food := (load("res://scenes/food.tscn") as PackedScene).instantiate() as Food
		food.position = point + Vector3(i * 0.17, abs(i) * 0.07, i * 0.08)
		food.show_ripple = i == 0
		if not feed.is_empty():
			food.sink_speed = State.FEED[feed][3]
			food.color = State.FEED[feed][4]
		_food_group.add_child(food)
		_pellets.append(food)
	_audio.sound("splash")


func _tick_food(now: int) -> void:
	if _pellets.is_empty():
		return
	var eligible := []
	for id: int in _actors:
		if _state.can_eat(id, now):
			eligible.append(id)
	var busy := []
	for pellet in _pellets:
		if pellet.fish_id > 0 and pellet.fish_id not in eligible:
			var previous: Fish = _actors.get(pellet.fish_id)
			if is_instance_valid(previous):
				previous.food_target = null
			pellet.fish_id = -1
		elif pellet.fish_id > 0:
			busy.append(pellet.fish_id)
	if _preferred in eligible and _preferred not in busy:
		_reserve_closest(_preferred, busy)
	for pellet in _pellets.duplicate():
		if pellet.age >= Food.LIFETIME:
			_clear_pellet(pellet)
			continue
		if pellet.fish_id <= 0:
			var nearest := 0
			var limit := _reach(pellet)
			for id: int in eligible:
				var dist: float = _actors[id].global_position.distance_to(pellet.global_position)
				if id not in busy and dist < limit:
					nearest = id
					limit = dist
			if nearest != 0:
				_reserve(pellet, nearest, busy)
		if pellet.fish_id > 0:
			var actor: Fish = _actors[pellet.fish_id]
			if actor.can_bite_food(pellet.global_position):
				var before: int = _state.data.notices.size()
				if _state.feed(pellet.fish_id, now):
					_batch_received = true
					actor.peck()
					_audio.sound("peck")
					if pellet.fish_id == _preferred:
						_show_notice("%s吃飽了 · +2 XP" % actor.display_name())
					_clear_pellet(pellet)
					_sync()
					_announce_live(before)
				else:
					_show_notice(_state.last_error)
					_clear_pellet(pellet)
	if _pellets.is_empty() and not _batch_received:
		_show_notice("附近的魚都吃飽了" if eligible.is_empty() else "試著投在魚附近")


func _reserve_closest(id: int, busy: Array) -> void:
	var best: Food
	var checked := INF
	for pellet in _pellets:
		var distance: float = _actors[id].global_position.distance_to(pellet.global_position)
		if pellet.fish_id <= 0 and distance < minf(checked, _reach(pellet)):
			best = pellet
			checked = distance
	if best:
		_reserve(best, id, busy)


func _reserve(pellet: Food, id: int, busy: Array) -> void:
	pellet.fish_id = id
	busy.append(id)
	_actors[id].food_target = pellet


func _reach(pellet: Food) -> float:
	return clampf((Food.LIFETIME - pellet.age - 0.4) * 1.6, 0.0, 5.0)


func _clear_pellet(pellet: Food) -> void:
	var fish: Fish = _actors.get(pellet.fish_id)
	if is_instance_valid(fish):
		fish.food_target = null
	_pellets.erase(pellet)
	pellet.queue_free()


func _time_text(seconds: int) -> String:
	var left := maxi(seconds, 0)
	return "%d:%02d" % [left / 60, left % 60]


func _show_notice(message: String, duration := 3.4) -> void:
	%TankNotice.text = message
	_toast_until = Time.get_ticks_msec() + int(duration * 1000)


func _refresh_menus() -> void:
	var menu := _shop.get_popup()
	menu.clear()
	var data := _state.data
	for id in State.EGG_CHOICES:
		var price := _state.egg_price(id)
		var unlocked := _state.egg_unlocked(id)
		var price_text := "%d 金" % price if price else "免費救援卵"
		if not unlocked:
			price_text = "孵出第一胎後解鎖"
		menu.add_icon_item(load("res://assets/items/%s.png" % EGG_ICONS[id]),
			"%s · %s" % [_state.egg_title(id), price_text], id)
		menu.set_item_disabled(menu.item_count - 1,
			not unlocked or data.coins < price or data.fish.size() >= data.capacity)
	menu.add_separator("飼料")
	for index in State.FEED.size():
		var key: String = State.FEED.keys()[index]
		var item: Array = State.FEED[key]
		menu.add_icon_item(load("res://assets/items/%s.png" % key),
			"%s ×%d · %d 金" % [item[0], item[2], item[1]], 10 + index)
		menu.set_item_disabled(menu.item_count - 1, data.coins < item[1])

	menu.add_separator("裝飾")
	for index in State.DECOR.size():
		var key: String = State.DECOR.keys()[index]
		var item: Array = State.DECOR[key]
		var owned: bool = data.decor.has(key)
		var caption := "已購買" if owned else "%d 金" % item[1]
		if _state.level() < item[2]:
			caption += " · Lv.%d" % item[2]
		menu.add_icon_item(load("res://assets/items/%s.png" % key), "%s · %s" % [item[0], caption], 20 + index)
		menu.set_item_disabled(menu.item_count - 1, owned or _state.level() < item[2] or data.coins < item[1])
	menu.add_separator("魚缸")
	var expansion := "擴成 8 格 · 30 金" if _state.level() >= 2 else "擴缸 · Lv.2 解鎖"
	menu.add_item("已擴成 8 格" if data.capacity == 8 else expansion, 3)
	menu.set_item_disabled(menu.item_count - 1, data.capacity == 8 or _state.level() < 2 or data.coins < 30)
	%Balance.text = "Lv.%d    %d 金    %d/%d" % [_state.level(), data.coins, data.fish.size(), data.capacity]
	%Balance.tooltip_text = "%d XP · %d／%d 缸位" % [data.xp, data.fish.size(), data.capacity]
	_stored_menu.text = str(_stored.size())

	_returns.visible = not data.notices.is_empty()
	_returns.text = str(data.notices.size())
	menu = _returns.get_popup()
	menu.clear()
	for index in data.notices.size():
		var notice: Dictionary = data.notices[index]
		var entry := _state.fish(notice.id)
		var label: String = {"egg": "親魚產卵", "hatch": "孵化", "adult": "成年"}[notice.kind]
		menu.add_item(label if notice.kind == "egg" else "%s · %s" % [label, _state.title(entry)], index)


func _buy(option: int) -> void:
	_cancel_feed()
	_cancel_placement()
	var now := _now()
	var success := false
	if option in State.EGG_CHOICES:
		success = _state.buy(option, now)
	elif option == 3:
		success = _state.expand(now)
	elif option - 10 in range(State.FEED.size()):
		success = _state.buy_feed(State.FEED.keys()[option - 10], now)
	elif option - 20 in range(State.DECOR.size()):
		success = _state.buy_decor(State.DECOR.keys()[option - 20], now)
	if success:
		_sync()
		if option == 3:
			_show_notice("魚缸擴成 8 格")
	else:
		_show_notice(_state.last_error if not _state.last_error.is_empty() else "目前無法購買。")


func _refresh_inventory() -> void:
	var eggs := {}
	for id: int in _state.data.fish:
		var entry := _state.fish(id)
		if entry.stage == "egg" and entry.stored:
			var choice: int = State.CARDINAL_EGG if entry.species == State.CARDINAL else entry.traits
			if not eggs.has(choice):
				eggs[choice] = []
			eggs[choice].append(id)
	var snapshot := {"eggs": eggs, "decor": _state.data.decor.duplicate(true), "feed": _state.data.feed.duplicate()}
	if _inventory_snapshot == snapshot:
		return
	_inventory_snapshot = snapshot
	var slots := %ItemSlots as GridContainer
	for child in slots.get_children():
		if child != %InventoryEmpty:
			slots.remove_child(child)
			child.queue_free()
	for choice in eggs:
		var ids: Array = eggs[choice]
		var texture_key: String = EGG_ICONS.get(choice, "long_egg")
		var title: String = _state.egg_title(choice)
		var button := _add_inventory_slot(texture_key, title, ids.size())
		button.name = "Egg%d" % choice
		_add_item_actions(button, "egg", "孵化一顆", ids[0])
	for key: String in State.FEED:
		var count: int = _state.data.feed.get(key, 0)
		if count == 0:
			continue
		var button := _add_inventory_slot(key, State.FEED[key][0], count)
		_add_item_actions(button, key, "投餌")
	for key: String in State.DECOR:
		if not _state.data.decor.has(key):
			continue
		var placed: bool = _state.data.decor[key] != null
		var button := _add_inventory_slot(key, State.DECOR[key][0])
		_add_item_actions(button, key, "移動／旋轉" if placed else "擺放")
		if placed:
			button.get_popup().add_item("收回道具欄", STORE_DECOR)
	%InventoryEmpty.visible = slots.get_child_count() == 1
	var kinds := slots.get_child_count() - 1
	_inventory_button.text = str(kinds) if kinds > 0 else ""


func _add_inventory_slot(key: String, caption: String, count := 1) -> MenuButton:
	var button := (load("res://scenes/item_slot.tscn") as PackedScene).instantiate() as MenuButton
	button.name = key
	button.icon = load("res://assets/items/%s.png" % key)
	button.text = str(count) if count > 1 else ""
	button.tooltip_text = caption
	%ItemSlots.add_child(button)
	return button


func _add_item_actions(button: MenuButton, key: String, use_label: String, egg_id := 0) -> void:
	var actions := button.get_popup()
	actions.add_theme_constant_override("v_separation", 24)
	actions.add_theme_font_size_override("font_size", 18)
	actions.add_separator(button.tooltip_text)
	actions.add_item(use_label, USE_ITEM)
	var price := _state.resale_value(key, egg_id)
	actions.add_item("賣出 · +%d 金" % price if price > 0 else "賣出 · 0 金", SELL_ITEM)
	actions.id_pressed.connect(_use_inventory_action.bind(key, egg_id))
	actions.about_to_popup.connect(func() -> void: _place_item_menu.call_deferred(actions, button))


func _place_item_menu(menu: PopupMenu, button: MenuButton) -> void:
	if not is_instance_valid(menu) or not menu.visible:
		return
	var above := roundi(_inventory_bar.get_global_rect().position.y) - menu.size.y - 6
	if above >= 0:
		var right := roundi(button.get_global_rect().end.x)
		menu.position = Vector2i(maxi(0, right - menu.size.x), above)


func _toggle_inventory(opened: bool) -> void:
	_inventory_bar.visible = opened
	if opened:
		_select(null)
		_audio.sound("panel")


func _use_inventory_action(action: int, key: String, egg_id: int) -> void:
	if action == SELL_ITEM:
		var price := _state.resale_value(key, egg_id)
		if _state.sell_item(key, _now(), egg_id):
			_sync()
			_show_notice("+%d 金" % price if price > 0 else "已賣出")
		else:
			_show_notice(_state.last_error)
	elif action == STORE_DECOR:
		if _state.remove_decor(key, _now()):
			_sync()
		else:
			_show_notice(_state.last_error)
	elif key == "egg":
		_incubate(egg_id)
	elif State.FEED.has(key):
		_begin_feed(key)
	else:
		_begin_placement(key)


func _incubate(id: int) -> void:
	_cancel_placement()
	_cancel_feed()
	if _state.incubate(id, _now()):
		_sync()
		_inventory_button.button_pressed = false
		_show_notice("魚卵已放入孵化盤 · 1:30")
	else:
		_show_notice(_state.last_error)


func _begin_placement(key: String) -> void:
	_select(null)
	_placing_key = key
	_inventory_button.button_pressed = false
	var placement: Variant = _state.data.decor[key]
	_preview_yaw = placement.yaw if placement != null else 0.0
	_placement_point = placement.position if placement != null else Vector2.ZERO
	_show_notice("點缸底選位置")
	_update_tool_buttons()
	_preview_placement()


func _floor_point(point: Vector2) -> Variant:
	var pixel := point * Vector2(_tank.size) / size
	var plane := Plane(Vector3.UP, FLOOR_HEIGHT)
	var hit: Variant = plane.intersects_ray(_camera.project_ray_origin(pixel), _camera.project_ray_normal(pixel))
	if not hit is Vector3:
		return null
	return Vector2(
		clampf(hit.x, State.FLOOR_LIMIT.position.x, State.FLOOR_LIMIT.end.x),
		clampf(hit.z, State.FLOOR_LIMIT.position.y, State.FLOOR_LIMIT.end.y))


func _preview_placement() -> void:
	_pose_prop(_placing_key, {"position": _placement_point, "yaw": _preview_yaw})
	_props[_placing_key].process_mode = Node.PROCESS_MODE_DISABLED


func _rotate_placement(direction: float) -> void:
	if _placing_key.is_empty():
		return
	_preview_yaw = wrapf(_preview_yaw + ROTATION_STEP * direction, -PI, PI)
	_preview_placement()


func _confirm_placement() -> void:
	if _placing_key.is_empty():
		return
	if _state.place_decor(_placing_key, _placement_point, _preview_yaw, _now()):
		_placing_key = ""
		_update_tool_buttons()
		_sync()
		_show_notice("已擺放")
	else:
		_show_notice(_state.last_error)


func _cancel_placement() -> void:
	if not _placing_key.is_empty():
		_pose_prop(_placing_key, _state.data.decor[_placing_key])
		_placing_key = ""
		_update_tool_buttons()
		_show_notice("", 0.0)


func _cancel_tool() -> void:
	_cancel_feed()
	_cancel_placement()


func _update_tool_buttons() -> void:
	var placing := not _placing_key.is_empty()
	%RotateDecor.visible = placing
	%ApplyDecor.visible = placing
	%ToolButtons.visible = placing or _aiming
	_inventory_button.visible = not %ToolButtons.visible


func _apply_decor() -> void:
	var data := _state.data
	var fov := _default_fov * (1.15 if data.capacity == 8 else 1.0)
	if not is_equal_approx(fov, _base_fov):
		_base_fov = fov
		_set_zoom(_zoom)
	for key in _props:
		if key != _placing_key:
			_pose_prop(key, data.decor.get(key))


func _pose_prop(key: String, placement: Variant) -> void:
	var prop: Node3D = _props[key]
	prop.visible = placement != null
	prop.process_mode = Node.PROCESS_MODE_INHERIT if prop.visible else Node.PROCESS_MODE_DISABLED
	if prop.visible:
		var point: Vector2 = placement.position
		var height := -1.92 if key == "wood" else FLOOR_HEIGHT
		prop.position = Vector3(point.x, height, point.y)
		prop.rotation.y = placement.yaw


func _open_notice(index: int) -> void:
	_cancel_placement()
	_cancel_feed()
	if index not in range(_state.data.notices.size()):
		return
	var notice: Dictionary = _state.data.notices[index]
	var actor: Fish = _actors.get(notice.id)
	if not _state.dismiss_notice(index, _now()):
		_show_notice(_state.last_error)
		return
	if _return_chime and notice.kind == "hatch":
		_return_chime = false
		_audio.sound("hatch")
	if actor and actor.visible:
		_journal.hide()
		_focus_fish(actor)
	elif actor:
		_show_notice("%s在收起清單裡。" % actor.display_name())
	elif _eggs.has(notice.id):
		_show_notice("孵化中 · %s" % _time_text(_state.fish(notice.id).born_at - _now()))
	_refresh_menus()


func _announce_live(from_index: int) -> void:
	for index in range(from_index, _state.data.notices.size()):
		var notice: Dictionary = _state.data.notices[index]
		if notice.kind == "egg":
			_show_notice("親魚產下一顆卵")
			continue
		var entry := _state.fish(notice.id)
		_show_notice("%s %s" % [_state.title(entry), "孵化了" if notice.kind == "hatch" else "長成成魚了"])
		if notice.kind == "hatch":
			_highlight_id = notice.id
			_highlight_until = Time.get_ticks_msec() + 6000
			_audio.sound("moon" if entry.traits == 3 and _state.data.discovered[3] == entry.born_at else "hatch")


func _open_audio() -> void:
	_inventory_button.button_pressed = false
	_journal.hide()
	_cancel_placement()
	_cancel_feed()
	_dialog.hide()
	_panel.hide()
	%AudioPanel.show()


func _close_overlay() -> void:
	_journal.hide()
	_dialog.hide()
	%AudioPanel.hide()
	if is_instance_valid(_selected):
		_select(_selected)


func _open_rehome() -> void:
	_dialog_fish = _selected_id()
	if _dialog_fish == 0:
		return
	_inventory_button.button_pressed = false
	_journal.hide()
	_cancel_tool()
	%AudioPanel.hide()
	_panel.hide()
	%DialogText.text = "送養 %s，騰出 1 格。家系紀錄會保留。" % _state.title(_state.fish(_dialog_fish))
	_dialog.show()


func _confirm_dialog() -> void:
	if _state.data.fish.has(_dialog_fish) and _state.rehome(_dialog_fish, _now()):
		_select(null)
		_close_overlay()
		_sync()
		_show_notice("魚隻已送養")
	else:
		_show_notice(_state.last_error if not _state.last_error.is_empty() else "目前無法執行這項操作。")


func _view_family() -> void:
	if _selected_id() != 0:
		_show_journal(_selected_id())


func _show_journal(child_id := 0) -> void:
	_inventory_button.button_pressed = false
	_cancel_placement()
	_cancel_feed()
	_dialog.hide()
	%AudioPanel.hide()
	_panel.hide()
	_journal.present(_state, _now(), child_id)


func _locate_from_journal(id: int) -> void:
	var actor: Fish = _actors.get(id)
	if not is_instance_valid(actor) or not actor.visible:
		return
	_journal.hide()
	_focus_fish(actor)


func _focus_fish(actor: Fish) -> void:
	_reset_view()
	if size.aspect() < MIN_FRAME_ASPECT:
		_pan.x = _camera.to_local(actor.global_position).x
		_apply_pan()
	_select(actor)
