extends SceneTree
## godot --headless --path . -s tests/test_ui.gd

func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var demo: Control = load("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var title := demo.get_node("%Bag").get_parent() as Control
	var start := demo.get_node("%Bag") as JuicyButton
	if not _ok(start.modulate.a == 0.0, "children start transparent"): return
	if not _ok(start.visible, "visible untouched"): return
	await create_timer(0.6).timeout
	if not _ok(is_equal_approx(start.modulate.a, 1.0) and start.offset_transform_scale.is_equal_approx(Vector2.ONE)): return
	# scale_ratio: long button animates less
	var long := demo.get_node("%Long") as JuicyButton
	if not _ok(long.scale_ratio() < start.scale_ratio(), "longer -> smaller ratio"): return
	if not _ok(long.scale_ratio() >= 0.5): return
	# hover squash then return to rotation 0
	start.mouse_entered.emit()
	await create_timer(0.05).timeout
	if not _ok(start.offset_transform_rotation != 0.0 and start.offset_transform_scale != Vector2.ONE and start.scale == Vector2.ONE): return
	var pitches := {}
	for i in 8:
		start.mouse_entered.emit()
		var ps: float = start.last_sfx.pitch_scale
		if not _ok(absf(ps - 1.0) <= start.pitch_jitter, "pitch within jitter"): return
		pitches[ps] = true
	if not _ok(pitches.size() > 1, "pitch varies"): return
	start.mouse_exited.emit()
	if not _ok(start.last_sfx.stream == start.unhover_sound, "unhover plays its sound"): return
	await create_timer(0.3).timeout
	if not _ok(is_zero_approx(start.offset_transform_rotation) and start.offset_transform_scale.is_equal_approx(Vector2.ONE)): return
	# shadow directions
	if not _ok(demo.get_node("%MenuToggle/Shadow").offset_left < 0): return
	if not _ok(demo.get_node("%Plus/Shadow").offset_left == 0): return
	# tween_once via plain assignment
	var plus := demo.get_node("%Plus") as JuicyButton
	var plus_rect := plus.get_global_rect()
	var tap := InputEventMouseButton.new()
	tap.position = plus_rect.get_center()
	tap.global_position = tap.position
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	root.push_input(tap, true)
	await create_timer(0.17).timeout
	if not _ok(plus.offset_transform_scale.is_equal_approx(Vector2.ONE * plus.press_scale), "button compresses while held"): return
	if not _ok(plus.get_global_rect() == plus_rect, "press leaves the button layout intact"): return
	var release := tap.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame; await process_frame
	var counter := demo.get_node("%Counter") as Label
	if not _ok(counter.text == "1" and counter.offset_transform_scale != Vector2.ONE, "counter punched"): return
	await create_timer(0.2).timeout
	if not _ok(plus.offset_transform_scale.x > plus.press_scale, "button rebounds after release"): return
	# visibility-triggered menu, visible of children untouched
	var toggle_pos := (demo.get_node("%MenuToggle") as Control).global_position
	demo.get_node("%MenuToggle").pressed.emit()
	await process_frame
	var audio := demo.get_node("%Menu/Items/Audio") as Control
	if not _ok(audio.visible and audio.modulate.a == 0.0): return
	await create_timer(0.6).timeout
	if not _ok(is_equal_approx(audio.modulate.a, 1.0)): return
	if not _ok((demo.get_node("%MenuToggle") as Control).global_position == toggle_pos, "menu overlay must not move layout"): return
	demo.get_node("%Back").pressed.emit()
	await process_frame
	if not _ok(not demo.get_node("%Overlay").visible, "back closes overlay"): return
	var head := demo.get_node("%Menu/Items/MenuHead") as Control
	if not _ok(is_equal_approx(head.modulate.a, 1.0)): return
	# card hand: dummy slots expand/shrink, fan via offset transform
	var hand := demo.get_node("%Hand") as CardHand
	if not _ok(hand.live_slots().size() == 5, "5 cards"): return
	var first := hand.live_slots()[0]
	if not _ok(first.offset_transform_rotation < 0.0 and first.rotation == 0.0, "fan rotates visually"): return
	demo.get_node("%Draw").pressed.emit()
	await create_timer(0.3).timeout
	if not _ok(hand.live_slots().size() == 6 and is_equal_approx(hand.live_slots()[5].custom_minimum_size.x, hand.slot_width), "drawn slot expanded"): return
	var w := hand.get_combined_minimum_size().x
	hand.live_slots()[0].get_child(0).pressed.emit()
	await create_timer(0.4).timeout
	if not _ok(hand.get_child_count() == 5 and hand.get_combined_minimum_size().x < w, "played card removed, hand shrank"): return
	# inventory: open overlay, select -> move / merge / swap, loot stacks
	demo.get_node("%Bag").pressed.emit()
	await create_timer(0.6).timeout
	var inv := demo.get_node("%Inventory") as Inventory
	var sl := inv.slots()
	if not _ok(sl.size() == 24 and (demo.get_node("%Inventory/VBox/Grid") as GridContainer).columns == 6, "6-col grid of 24"): return
	if not _ok(is_equal_approx(sl[23].modulate.a, 1.0), "grid slots appeared"): return
	var apple := sl[0].item
	sl[0].pressed.emit(); sl[10].pressed.emit()
	if not _ok(sl[0].is_empty() and sl[10].item == apple and sl[10].count == 5, "move to empty"): return
	sl[1].pressed.emit(); sl[10].pressed.emit()
	if not _ok(sl[10].item != apple and sl[1].item == apple, "swap"): return
	inv.add_item(apple, 2)
	if not _ok(sl[1].count == 7, "loot stacks onto same item"): return
	await process_frame
	if not _ok(sl[1].get_node("%Count").text == "7", "count label"): return
	inv.get_node("%Close").pressed.emit()
	await process_frame
	if not _ok(not demo.get_node("%BagOverlay").visible, "close bag"): return
	print("ALL PASS")
	quit()


func _ok(cond: bool, msg := "") -> bool:
	if not cond:
		push_error("FAIL " + msg)
		quit(1)
	return cond
