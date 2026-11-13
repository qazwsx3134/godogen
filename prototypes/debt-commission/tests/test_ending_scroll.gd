extends "res://addons/proto_kit/test_kit.gd"
## The ending: the screen goes dark, the scroll (scenes/ui/chapter_result_gintama.tscn) unrolls with the
## `end` text and ending (or the `result` numbers and grade), and only a tap brings up 重玩 and 回標題.

const STORY: String = "res://data/showcase_story.json"
const FILES: Array[String] = ["user://ending-scroll.save", "user://ending-scroll.cfg", "user://ending-scroll-progress.cfg"]
var game: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = STORY
	game.save_path = FILES[0]
	game.settings_path = FILES[1]
	game.progress_path = FILES[2]
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)

	# `end`: 結束展示 from the menu.
	game._on_begin_pressed()
	await _read_until(func() -> bool: return game._screen_mode == "choice", "the menu")
	game._on_choice_pressed("finish")
	await _read_until(func() -> bool: return game._screen_mode == "end", "the end")
	var scroll: Control = game._chapter_result
	_expect(scroll.visible and scroll.heading.text.contains("看完了全部功能") and not scroll.stats.visible
		and not scroll.grade_row.visible, "an end shows the scroll with its text and ending, without numbers")
	_expect(scroll.dim.modulate.a < 0.5, "the dark comes in, not at once")
	await create_timer(scroll.dim_in + scroll.unroll + 0.2).timeout
	_expect(is_equal_approx(scroll.dim.modulate.a, 1.0) and (scroll.dim as ColorRect).color.a > 0.99, "then the screen is fully dark")
	_expect(scroll.tap_hint.visible and is_zero_approx(scroll.buttons.modulate.a) and scroll.restart_button.disabled
		and scroll.title_button.disabled, "the buttons wait, hidden and inert, under 點一下繼續")
	_expect(game._restart_button == scroll.restart_button and game._end_title_button == scroll.title_button,
		"重玩 and 回標題 are the scroll's")
	_tap_screen()
	await create_timer(scroll.buttons_in + 0.1).timeout
	_expect(scroll.buttons_shown() and not scroll.restart_button.disabled and is_equal_approx(scroll.buttons.modulate.a, 1.0)
		and not scroll.tap_hint.visible, "a tap brings up the buttons")
	scroll.restart_button.pressed.emit()
	await _read_until(func() -> bool: return game._screen_mode in ["story", "choice"], "重玩 starts over")
	_expect(not scroll.visible and game._runner.node_id == "menu", "重玩 closes the scroll and starts the story again")

	# `result`: the director's 收工 card; 畫面效果：減少 shows it at once, still waiting for the tap.
	game._on_setting_changed("motion", 1)
	await _read_until(func() -> bool: return game._screen_mode == "choice", "the menu again")
	game._on_choice_pressed("advanced")
	await _read_until(func() -> bool: return game._screen_mode == "choice" and game._runner.node_id == "adv_director", "the director choice", true)
	game._on_choice_pressed("wrap_up")
	await _read_until(func() -> bool: return game._screen_mode == "result", "the result", true)
	_expect(scroll.visible and scroll.stats.visible and scroll.grade_row.visible and is_equal_approx(scroll.dim.modulate.a, 1.0)
		and not scroll.buttons_shown(), "a result shows its numbers and grade at once with reduced motion, buttons waiting")
	_tap_screen()
	await _frames(2)
	_expect(scroll.buttons_shown(), "the tap brings up the result's buttons")
	scroll.title_button.pressed.emit()
	await _frames(3)
	_expect(game._screen_mode == "title" and not scroll.visible, "回標題 goes to the title")
	game.queue_free()
	await _frames(2)
	for path: String in FILES:
		for suffix: String in ["", ".bak"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_finish("ENDING SCROLL")


func _tap_screen() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 200)
	Input.parse_input_event(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)


## Reads on; a round is answered by a player who knows the answers (play_through), QTEs hit dead on.
func _read_until(done: Callable, label: String, play_through: bool = false) -> void:
	var deadline: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline:
		if done.call():
			return
		match game._screen_mode:
			"story":
				if game._story_busy:
					game._on_screen_tap()
				elif game._text_complete:
					game._advance_current_line()
				else:
					game._complete_current_line()
			"investigate" when play_through:
				var command: Dictionary = game._current_command
				for spot: Dictionary in command.get("hotspots", []):
					game._investigation.collect_hotspot(str(spot["id"]))
				if game._screen_mode == "investigate":
					game._investigation.on_investigation_continue_pressed()
			"boke_round" when play_through:
				var command: Dictionary = game._current_command
				var line: Dictionary = command.get("current_line", {}) as Dictionary
				if str(command.get("mode", "")) == "testimony":
					var lines: Array = command.get("lines", [])
					for i: int in lines.size():
						if lines[i].has("slot") and not (command.get("caught_line_ids", []) as Array).has(lines[i]["id"]):
							if int(command.get("line_index", 0)) != i:
								game._set_boke_line(i)
							break
					line = (game._current_command.get("current_line", {}) as Dictionary)
				if not (line.get("censor", {}) as Dictionary).is_empty():
					game._round.on_censor_pressed()
				elif not (line.get("placard", {}) as Dictionary).is_empty():
					game._round.on_placard_pressed()
				else:
					game._on_boke_tsukkomi_pressed()
			"tsukkomi" when play_through:
				game._on_boke_option_pressed(str(game._current_options[0]["id"]))
			"qte" when play_through:
				game._round._on_qte_resolved(true, 0.0)
		await _frames(1)
	_expect(false, "timed out before %s (at %s %s)" % [label, game._screen_mode, game._runner.node_id])
