extends "res://tools/check_care.gd"


func _run() -> void:
	await _enter()
	var state: State = _room._state
	var shop := _room.get_node("%Shop").get_popup() as PopupMenu
	assert(shop.is_item_disabled(shop.get_item_index(State.CARDINAL_EGG)))
	assert(not state.buy(State.CARDINAL_EGG, _clock) and state.data.coins == 60)

	# Start with grown betta parents to exercise the real unlock without repeating care smoke.
	state.fish(1).stage = "adult"
	state._add(2, _clock - State.GROW_SECONDS, "adult")
	_clock += State.HATCH_SECONDS
	await _frames()
	assert(state.data.achievements.has("第二代"))
	assert(state.store_fish(2, true, _clock))
	assert(not shop.is_item_disabled(shop.get_item_index(State.CARDINAL_EGG)))
	state.data.xp = maxi(state.data.xp, 40)
	shop.id_pressed.emit(3)
	var prior_coins: int = state.data.coins
	for index in 3:
		shop.id_pressed.emit(State.CARDINAL_EGG)
	assert(state.data.coins == prior_coins - 3 * State.CARDINAL_PRICE)
	var egg_slot := _room.get_node("%ItemSlots/Egg4") as MenuButton
	assert(egg_slot.text == "3" and egg_slot.tooltip_text == "紅蓮燈卵")
	for id in range(4, 7):
		assert(state.fish(id).species == State.CARDINAL and state.fish(id).stored)
		var slot := _room.get_node("%ItemSlots/Egg4") as MenuButton
		slot.get_popup().id_pressed.emit(1)
	assert(not _room.has_node("%ItemSlots/Egg4"))

	_clock += State.HATCH_SECONDS
	await _frames()
	assert(state.data.discovered.has(State.CARDINAL_EGG))
	for index in 3:
		var actor: Node3D = _room._actors[index + 4]
		assert(actor.display_name() == "紅蓮燈" and actor.school_slot == index)
		assert(actor.scale.is_equal_approx(Vector3.ONE * 0.69))
	var tetra: Node3D = _room._actors[4]
	for frame in 105:
		await process_frame
	assert(tetra.global_position.distance_to(_room._actors[5].global_position) < 1.45)
	_room._select(tetra)
	await _frames()
	assert("群游" in _room.get_node("Controls/FishPanel/Details/Status").text)
	await _button("%FeedFish")
	await _click(_room._world_to_ui(tetra.global_position + Vector3(0.44, 0.12, 0)))
	for frame in 400:
		if state.fish(4).meals == 1:
			break
		await process_frame
	assert(state.fish(4).meals == 1 and tetra._peck_left > 0.0)
	for id in [5, 6]:
		if state.fish(id).meals == 0:
			assert(state.feed(id, _clock))
	while not _room._pellets.is_empty():
		await process_frame
	_clock += State.MEAL_SECONDS
	for id in range(4, 7):
		assert(state.feed(id, _clock))
	_clock += State.GROW_SECONDS - State.MEAL_SECONDS
	await _frames()
	for id in range(4, 7):
		assert(state.fish(id).stage == "adult")
	assert(state.next_pair().first == 4 and state.next_pair().second == 5)

	_room._select(tetra)
	await _frames()
	var captures := OS.get_cmdline_user_args()
	if not captures.is_empty():
		await _capture(captures[0] + "-school.png")
	_clock += State.PAIR_SECONDS
	await _frames()
	assert(state.fish(7).species == State.CARDINAL and state.fish(7).parents == [4, 5])
	_room.queue_free()
	await process_frame
	_clock += State.HATCH_SECONDS
	await _enter()
	state = _room._state
	assert(state.fish(7).stage == "juvenile" and state.fish(7).species == State.CARDINAL)
	assert(state.fish(1).species == State.BETTA and state.fish(7).clutch == 1)
	assert(state.store_fish(7, true, _clock) and state.store_fish(6, true, _clock))
	_room._sync()
	await _frames()
	assert(_room._actors[4].school_slot == -1)
	_room._show_journal(7)
	assert(_room._journal.get_node("%ChildName").text == "紅蓮燈")
	assert(_room._journal.get_node("%FindChild").disabled)
	if not captures.is_empty():
		await _capture(captures[0] + "-lineage.png")
	_room.queue_free()
	await _frames()
	DirAccess.remove_absolute(_path)
	print("Cardinal flow passed: unlock, purchase, hatch, school, feed, pair and reload.")
	quit()
