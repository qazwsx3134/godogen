extends SceneTree
## godot --headless --path . -s tests/test_fantasy.gd

func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var demo: Control = load("res://scenes/fantasy_demo.tscn").instantiate()
	root.add_child(demo)
	await create_timer(0.8).timeout
	var slots := demo.get_node("%Slots").get_children()
	if not _ok(slots.size() == 3 and slots[0].button_pressed and slots[0].get_node("Count").text == "3", "scene keeps slot counts and default selection"): return
	slots[1].button_pressed = true
	if not _ok(not slots[0].button_pressed, "ButtonGroup keeps one slot selected"): return
	var accept := demo.get_node("%Accept") as Button
	if not _ok(accept.get_theme_stylebox("normal") is StyleBoxTexture and demo.get_node("%NewGame").get_theme_stylebox("normal") is StyleBoxEmpty, "theme variations style the buttons"): return
	if not _ok(not demo.get_node("%NewGame/Shadow").visible and demo.get_node("%Continue/Shadow").visible, "text buttons drop the shadow"): return
	var fired := [false]
	demo.quest_accepted.connect(func(): fired[0] = true)
	accept.pressed.emit()
	if not _ok(fired[0] and accept.disabled and accept.text == "Quest accepted", "accepting the quest"): return
	print("ALL PASS")
	quit(0)


func _ok(cond: bool, msg := "") -> bool:
	if not cond:
		printerr("FAIL: ", msg)
		quit(1)
	return cond
