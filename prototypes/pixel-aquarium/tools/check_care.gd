extends SceneTree

const State = preload("res://scripts/care_state.gd")
const ROOM := preload("res://scenes/care.tscn")
var _clock := 1_790_000_000
var _test_id := "%d-%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
var _path := "user://care-test-%s.dat" % _test_id
var _audio_path := "user://audio-test-%s.dat" % _test_id
var _room: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _enter()
	var state: State = _room._state
	assert(state.data.coins == 60 and state.data.fish.size() == 1)
	assert(state.fish(1).traits == 1 and state.fish(1).stage == "juvenile")
	_check_offline_breeding()
	var captures := OS.get_cmdline_user_args()

	await _pick(1)
	assert(_room.get_node("%FishPanel").visible)
	assert(_room.get_node("%Hunger").text == "想吃")
	assert(_room._hunger_icons[1].visible)
	var field := _room.get_node("%RenameFish") as LineEdit
	field.text_submitted.emit("月米")
	assert(state.fish(1).name == "月米")
	assert(_room.get_node("%FishName").text == "月米")
	if not captures.is_empty():
		await _capture(captures[0] + "-starter.png")
	await _feed(1, 1)
	assert(state.data.xp == 2)
	assert(not state.can_eat(1, _clock))
	assert(not _room._hunger_icons[1].visible)
	assert(not state.feed(1, _clock))
	var shop := _room.get_node("%Shop").get_popup() as PopupMenu
	assert(shop.get_item_id(0) == 2)
	shop.id_pressed.emit(2)
	assert(state.data.coins == 45 and state.fish(2).stage == "egg" and state.fish(2).stored)
	assert(_room.get_node("TankView/Eggs").get_child_count() == 0)
	assert(state.data.xp == 2)
	var egg_slot := _room.get_node("%ItemSlots/Egg2") as MenuButton
	assert(egg_slot.tooltip_text == "銀紋卵")
	assert(not _room.get_node("Controls/Inventory").visible)
	while not _room._pellets.is_empty():
		await process_frame
	_clock += State.HATCH_SECONDS + 5
	await _frames()
	assert(state.fish(2).stage == "egg" and state.fish(2).stored)
	assert(_room._hunger_icons[1].visible)
	_room.queue_free()
	await process_frame
	await _enter()
	state = _room._state
	assert(state.fish(2).stored)
	egg_slot = _room.get_node("%ItemSlots/Egg2")
	await _button("%InventoryToggle")
	assert(egg_slot.is_visible_in_tree())
	if not captures.is_empty():
		await _capture(captures[0] + "-inventory.png")
	await _button("%ItemSlots/Egg2")
	assert(egg_slot.get_popup().visible)
	egg_slot.get_popup().id_pressed.emit(1)
	egg_slot.get_popup().hide()
	await _frames()
	assert(not state.fish(2).stored and state.fish(2).born_at == _clock + State.HATCH_SECONDS)
	assert(not _room.has_node("%ItemSlots/Egg2"))
	assert(_room.get_node("TankView/Eggs").get_child_count() == 1)
	_clock += State.HATCH_SECONDS
	await _frames()
	assert(state.fish(2).stage == "juvenile" and state.fish(2).meals == 0)
	await _feed(2, 1)
	if state.fish(1).meals < 2:
		await _feed(1, 2)
	_clock += State.MEAL_SECONDS
	await _frames()
	await _feed(2, 2)
	_clock = state.fish(2).born_at + State.GROW_SECONDS
	await _frames()
	assert(state.fish(1).stage == "adult" and state.fish(2).stage == "adult")
	assert(state.data.coins == 90 and state.data.xp == 35 + 2 * (state.fish(1).meals + state.fish(2).meals))
	assert(not _room.has_node("%BreedFish") and state.fish(3).is_empty())
	_clock += State.PAIR_SECONDS
	await _frames()
	assert(state.fish(3).stage == "egg" and state.fish(3).parents == [1, 2])
	assert(state.fish(3).clutch == 1 and state.fish(1).breed_at == _clock + State.BREED_SECONDS)
	assert(state.data.notices.back().kind == "egg")
	var birth_log := _room.get_node("%Returns").get_popup() as PopupMenu
	assert(birth_log.get_item_text(birth_log.item_count - 1) == "親魚產卵")
	var traits: int = state.fish(3).traits
	_room.queue_free()
	await process_frame
	_clock += State.HATCH_SECONDS
	await _enter()
	state = _room._state
	assert(state.fish(3).stage == "juvenile" and state.fish(3).traits == traits)
	assert(state.data.achievements.get("第二代", false))
	var coins: int = state.data.coins
	var xp: int = state.data.xp
	assert(not state.settle(_clock))
	assert(state.data.coins == coins and state.data.xp == xp)
	assert(not state.settle(_clock - 50))
	assert(_room.get_node("%Returns").visible)
	var returns := _room.get_node("%Returns").get_popup() as PopupMenu
	returns.id_pressed.emit(returns.item_count - 1)
	await _frames()
	assert(_room.get_node("%FishPanel").visible)
	assert(_room.get_node("%ViewFamily").visible)
	await _button("%ViewFamily")
	var journal := _room._journal as Control
	assert(journal.visible)
	var tabs := journal.get_node("%JournalTabs") as TabContainer
	assert(tabs.current_tab == 1)
	assert("月米" in journal.get_node("%FirstParent").text)
	assert("首胎" in journal.get_node("%History").get_item_text(0))
	assert("第 1 胎" in journal.get_node("%FamilyDate").text)
	if not captures.is_empty():
		await _capture(captures[0] + "-family.png")
	tabs.current_tab = 2
	await _frames()
	assert("配對準備中" in journal.get_node("%PairStatus").text)
	_clock += State.BREED_SECONDS - State.HATCH_SECONDS
	await _frames()
	assert("缸位已滿" in journal.get_node("%PairStatus").text)
	assert("孵化中" in journal.get_node("%HatchStatus").text and state.fish(4).clutch == 2)
	tabs.current_tab = 1
	var locate := journal.get_node("%FindChild") as Button
	await _click(locate.get_global_rect().get_center())
	assert(_room._selected_id() == 3 and not journal.visible)
	await _button("%StoreFish")
	assert(state.fish(3).stored)
	_room.get_node("%StoredFish").get_popup().id_pressed.emit(0)
	assert(not state.fish(3).stored)
	_room.get_node("%Shop").get_popup().id_pressed.emit(3)
	assert(state.data.capacity == 8)
	var catalog := _room.get_node("%Shop").get_popup() as PopupMenu
	catalog.id_pressed.emit(10)
	catalog.id_pressed.emit(11)
	catalog.id_pressed.emit(20)
	catalog.id_pressed.emit(21)
	assert(state.data.feed == {"flake": 5, "sinking": 5})
	assert(state.data.decor.has("grass") and state.data.decor.grass == null)
	assert(not _room.get_node("TankView/Tank/Plants/WaterGrass6").visible)
	await _frames()
	var inventory := _room.get_node("Controls/Inventory") as Control
	assert(absf(inventory.get_global_rect().end.x - (_room.size.x - 12.0)) < 1.0)
	await _button("%InventoryToggle")
	assert(inventory.visible)
	await _button("%ItemSlots/grass")
	var grass := _room.get_node("%ItemSlots/grass") as MenuButton
	assert(grass.get_popup().visible)
	grass.get_popup().id_pressed.emit(1)
	grass.get_popup().hide()
	var floor := Vector3(1.76, -2.28, 0.64)
	await _click(_room._world_to_ui(floor))
	await _button("%RotateDecor")
	await _frames()
	assert(_room._placing_key == "grass" and state.data.decor.grass == null)
	if not captures.is_empty():
		await _capture(captures[0] + "-placement.png")
	await _button("%ApplyDecor")
	var saved: Dictionary = state.data.decor.grass.duplicate()
	assert(saved.position.distance_to(Vector2(floor.x, floor.z)) < 0.001)
	assert(is_equal_approx(saved.yaw, PI / 6.0))
	assert(_room.get_node("TankView/Tank/Plants/WaterGrass6").visible)
	_room.get_node("%ItemSlots/grass").get_popup().id_pressed.emit(1)
	await _click(_room._world_to_ui(Vector3(-2.5, -2.28, 1.4)))
	_key(KEY_Q)
	await _button("%CancelTool")
	await _frames()
	assert(saved == state.data.decor.grass)
	_room.get_node("%ItemSlots/grass").get_popup().id_pressed.emit(0)
	assert(state.data.decor.has("grass") and state.data.decor.grass == null)
	_room.get_node("%ItemSlots/grass").get_popup().id_pressed.emit(1)
	_key(KEY_E)
	await _click(_room._world_to_ui(floor))
	await _button("%ApplyDecor")
	assert(state.data.decor.grass == saved)
	assert(state.place_decor("wood", Vector2(1.0, 0.0), 0.0, _clock))
	_room._sync()
	assert(_room.get_node("TankView/Tank/Hardscape/DriftwoodBranch").visible)
	_room.get_node("%ItemSlots/wood").get_popup().id_pressed.emit(2)
	assert(not state.data.decor.has("wood"))
	assert(not _room.get_node("TankView/Tank/Hardscape/DriftwoodBranch").visible)

	var far_point: Vector2 = _room._world_to_ui(Vector3(5.1, 2.59, 0.8))
	_room.get_node("%ItemSlots/flake").get_popup().id_pressed.emit(1)
	_key(KEY_ESCAPE)
	assert(state.data.feed.flake == 5)
	_room.get_node("%ItemSlots/flake").get_popup().id_pressed.emit(2)
	assert(state.data.feed.flake == 4)
	_room.get_node("%ItemSlots/sinking").get_popup().id_pressed.emit(1)
	await _button("%ZoomIn")
	var water := _room.size * Vector2(0.5, 0.46)
	await _drag_touch(water, water + Vector2(66, 22))
	assert(_room._camera.h_offset < 0.0 and _room._camera.v_offset > 0.0)
	assert(_room._aiming and _room._pellets.is_empty() and state.data.feed.sinking == 5)
	await _button("%ZoomReset")
	assert(is_zero_approx(_room._camera.h_offset) and is_zero_approx(_room._camera.v_offset))
	await _click(far_point)
	assert(state.data.feed.sinking == 4 and not _room._pellets.is_empty())
	assert(is_equal_approx(_room._pellets[0].sink_speed, 0.60))

	await _button("%AudioSettings")
	var music := _room.get_node("%AudioPanel/Rows").get_child(1).get_node("Slider") as HSlider
	music.value = 0
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Water")))

	_room.queue_free()
	await process_frame
	await _enter()
	state = _room._state
	assert(state.data.capacity == 8 and state.data.decor.grass == saved)
	assert(state.data.feed == {"flake": 4, "sinking": 4})
	assert(_room.has_node("%ItemSlots/grass"))
	assert(state.data.coins == coins - 61 and state.data.xp == xp)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert(not state.fish(3).stored)
	var legacy_path := _path + ".legacy"
	var legacy_data := state.data.duplicate(true)
	legacy_data.version = 1
	legacy_data.erase("feed")
	legacy_data.decor = {"grass": 3, "wood": 0, "lamp": 1}
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_var(legacy_data)
	file.close()
	var legacy := State.new()
	legacy.open(legacy_path, _clock)
	assert(legacy.data.version == State.VERSION and legacy.data.coins == state.data.coins)
	assert(legacy.data.decor.grass.position.is_equal_approx(Vector2(2.8, -0.41)))
	assert(legacy.data.decor.wood == null and legacy.data.decor.lamp != null)
	var version2: Dictionary = state.data.duplicate(true)
	version2.version = 2
	for roster in [version2.fish, version2.archive]:
		for entry: Dictionary in roster.values():
			entry.erase("species")
	var version2_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	version2_file.store_var(version2)
	version2_file.close()
	var migrated := State.new()
	migrated.open(legacy_path, _clock)
	assert(migrated.data.version == State.VERSION and migrated.fish(1).species == State.BETTA)
	assert(migrated.fish(1).name == "月米" and migrated.data.feed == state.data.feed)
	assert(migrated.data.decor == state.data.decor and migrated.fish(3).parents == [1, 2])
	var version3 := state.data.duplicate(true)
	version3.version = 3
	version3.fish[1].breed_at = 0
	var version3_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	version3_file.store_var(version3)
	version3_file.close()
	var adopted := State.new()
	adopted.open(legacy_path, _clock)
	assert(adopted.data.version == State.VERSION and adopted.fish(1).breed_at == _clock + State.PAIR_SECONDS)
	assert(adopted.fish(2).breed_at == state.fish(2).breed_at)
	assert(state.rehome(1, _clock))
	_room._sync()
	_room._show_journal(3)
	journal = _room._journal
	assert("月米" in journal.get_node("%FirstParent").text)
	assert(journal.get_node("%History").item_count == 1)
	assert(state.rehome(3, _clock))
	_room._sync()
	var archived := journal.get_node("%FindChild") as Button
	assert(archived.disabled and archived.text == "已送養")
	DirAccess.remove_absolute(legacy_path)
	DirAccess.remove_absolute(_path)
	DirAccess.remove_absolute(_audio_path)
	_room.queue_free()
	await _frames()
	print("Care flow passed: feeding, automatic breeding, offline hatch, inventory resale, touch pan and placement.")
	quit()


func _enter() -> void:
	_room = ROOM.instantiate()
	_room.save_path = _path
	_room.clock_override = func() -> int: return _clock
	var audio := _room.get_node("TankAudio")
	audio.settings_path = _audio_path
	audio.playback_requested = false
	root.add_child(_room)
	await _frames()


func _check_offline_breeding() -> void:
	var path := _path + ".offline"
	var state := State.new()
	state.open(path, _clock)
	assert(state.buy(2, _clock))
	assert(state.sell_item("egg", _clock, 2) and state.data.coins == 52)
	assert(not state.sell_item("egg", _clock, 2))
	state.fish(1).stage = "adult"
	state._add(2, _clock - 300, "adult")
	state._add(0, _clock - 300, "adult", [], 0, State.CARDINAL)
	assert(state.store_fish(3, true, _clock))
	assert(state.next_pair().is_empty() and not state.settle(_clock + 700))
	assert(state.store_fish(3, false, _clock))
	assert(not state.settle(_clock + State.PAIR_SECONDS - 1))
	var back := State.new()
	back.open(path, _clock + 700)
	assert(back.settle(_clock + 700))
	assert(back.fish(5).stage == "juvenile" and back.fish(5).parents == [1, 3])
	assert(back.fish(5).born_at == _clock + State.PAIR_SECONDS + State.HATCH_SECONDS)
	assert(back.data.notices[0].kind == "egg" and back.data.notices[1].kind == "hatch")
	assert(back.data.fish.size() == back.data.capacity and back.data.achievements.has("第二代"))
	var reopened := State.new()
	reopened.open(path, _clock + 700)
	assert(not reopened.settle(_clock + 700) and reopened.data == back.data)
	DirAccess.remove_absolute(path)


func _pick(id: int) -> void:
	var actor: Node3D = _room._actors[id]
	await _click(_room._world_to_ui(actor.global_position))


func _feed(id: int, target_meals: int) -> void:
	while not _room._pellets.is_empty():
		await process_frame
	if _room._state.fish(id).meals == target_meals:
		return
	await _pick(id)
	await _button("%FeedFish")
	var actor: Node3D = _room._actors[id]
	await _click(_room._world_to_ui(actor.global_position + Vector3(0.45, 0.12, 0)))
	var jaw := actor.get_node("Rig/LowerJaw") as Node3D
	var opened := jaw.visible and jaw.rotation.z < -0.18
	for frame in 500:
		opened = opened or (jaw.visible and jaw.rotation.z < -0.18)
		if _room._state.fish(id).meals == target_meals:
			break
		await process_frame
	assert(_room._state.fish(id).meals == target_meals, "Fish did not eat: %d" % id)
	assert(opened and actor._peck_left > 0.0)
	var captures := OS.get_cmdline_user_args()
	if id == 1 and target_meals == 1 and not captures.is_empty():
		await _capture(captures[0] + "-bite.png")
	for frame in 26:
		await process_frame
	assert(not jaw.visible and actor._peck_left <= 0.0)


func _button(path: String) -> void:
	var node := _room.get_node(path) as Control
	await _click(node.get_global_rect().get_center())


func _click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await _frames()


func _drag_touch(start: Vector2, end: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = start
	touch.pressed = true
	root.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.position = end
	drag.relative = end - start
	root.push_input(drag, true)
	var release := InputEventScreenTouch.new()
	release.position = end
	root.push_input(release, true)
	await _frames()


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)


func _frames() -> void:
	await physics_frame
	await physics_frame
	await process_frame


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
