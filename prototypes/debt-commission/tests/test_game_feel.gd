extends "res://addons/proto_kit/test_kit.gd"
## Game feel: each of the player's moments has one tier (stage_effects.gd FEEDBACK) that buzzes the
## phone and, for a miss or Game Over, shakes the stage; the story's own shakes buzz too; the HUD pops
## what changed; the toast pops in and fades. 畫面效果：減少 turns all of it off; skipping plays none.

const StageEffects = preload("res://scripts/stage_effects.gd")
const ROUND_HUD: PackedScene = preload("res://scenes/ui/round_hud.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_tiers()
	await _test_hud()
	await _test_toast()
	_finish("GAME FEEL")


func _effects() -> Array:
	var layer: Control = Control.new()
	var overlay: Control = Control.new()
	root.add_child(layer)
	root.add_child(overlay)
	var effects: Node = StageEffects.new()
	root.add_child(effects)
	effects.call("setup", [layer] as Array[Control], overlay, {})
	effects.haptics.set("_supported", 1)  # this desktop has no motor; let the rules run as on a phone
	var clock: Array[int] = [0]
	effects.haptics.clock = func() -> int:
		clock[0] += 500  # each buzz comes well apart from the last, so only the tiers decide
		return clock[0]
	var buzzes: Array[int] = []
	effects.haptics.vibrated.connect(func(ms: int, _strength: float) -> void: buzzes.append(ms))
	return [effects, layer, overlay, buzzes]


func _test_tiers() -> void:
	var made: Array = _effects()
	var effects: Node = made[0]
	var layer: Control = made[1]
	var buzzes: Array[int] = made[3]
	var durations: PackedInt32Array = effects.haptics.durations_ms
	effects.call("feedback", "perfect")
	_expect(buzzes == [durations[1]] and layer.position == Vector2.ZERO, "a perfect retort thumps without shaking: %s" % [buzzes])
	await create_timer(0.2).timeout
	effects.call("feedback", "weak")
	var weak_player: AudioStreamPlayer = effects.get("_feedback_player")
	_expect(buzzes[-1] == durations[0] and weak_player.stream != null and weak_player.playing,
		"a weak retort ticks and plays its softer slap")
	await create_timer(0.2).timeout
	effects.call("feedback", "miss")
	await _frames(2)
	_expect(buzzes.size() == 3 and buzzes[-1] == durations[1] and layer.position != Vector2.ZERO, "a miss thumps and shakes the stage")
	await create_timer(0.3).timeout
	_expect(layer.position == Vector2.ZERO, "the shake settles back")
	var player: AudioStreamPlayer = effects.get("_feedback_player")
	_expect(player.stream != null, "a miss sounds its glass crack on the feedback player")
	effects.call("feedback", "game_over")
	_expect(buzzes[-1] == durations[2], "Game Over is the heaviest buzz")
	await create_timer(0.5).timeout
	effects.call("play", {"op": "shake", "strength": "small"}, false)
	_expect(buzzes[-1] == durations[0], "the story's small shake ticks")
	var count: int = buzzes.size()
	await create_timer(0.3).timeout
	effects.call("feedback", "clue", true)
	_expect(buzzes.size() == count and effects.get("last_feedback") == "game_over", "skipping plays no feedback")
	effects.set("reduce_motion", true)
	effects.call("feedback", "power_full")
	_expect(buzzes.size() == count, "畫面效果：減少 never buzzes")
	_expect(effects.get("last_feedback") == "power_full", "the moment is still recorded")
	effects.call("feedback", "no_such_moment")
	_expect(effects.get("last_feedback") == "power_full", "an unknown moment does nothing")
	for node: Node in made.slice(0, 3):
		node.queue_free()
	await _frames(2)


func _test_hud() -> void:
	var hud: Control = ROUND_HUD.instantiate() as Control
	root.add_child(hud)
	await _frames(2)
	hud.call("show_stats", 5, 5, 0, 100, 0)
	await _frames(1)
	var icons: Node = hud.get("glasses")
	_expect((icons.get_child(4) as Control).scale == Vector2.ONE, "the first show pops nothing")
	hud.call("show_stats", 4, 5, 30, 100, 1)  # read at once: a container re-sorting resets scale for a frame
	_expect((icons.get_child(4) as Control).scale.x > 1.05, "the pair that just broke pops")
	_expect((icons.get_child(3) as Control).scale == Vector2.ONE, "the pairs still whole stay put")
	_expect((hud.get("power_value") as Control).scale.x > 1.05 and (hud.get("combo") as Control).scale.x > 1.05,
		"power and combo pop when they rise")
	await _frames(2)  # past the container's re-sort, which resets scale
	var label: Control = hud.get("power_value")
	_expect(label.scale.x > 1.0 or not (label.get_meta("pop_tween") as Tween).is_running(),
		"the power pop survives its container re-sorting (scale %.2f)" % label.scale.x)
	await create_timer(0.4).timeout
	_expect((icons.get_child(4) as Control).scale.is_equal_approx(Vector2.ONE), "the pop springs back")
	hud.call("reset_pops")  # what main.gd does when a save loads or a story starts
	hud.call("show_stats", 2, 5, 90, 100, 3)
	_expect((icons.get_child(2) as Control).scale == Vector2.ONE and (icons.get_child(3) as Control).scale == Vector2.ONE,
		"after a load the HUD shows the saved count without popping breaks")
	hud.call("show_stats", 5, 5, 0, 100, 0)
	hud.set("reduce_motion", true)
	hud.call("show_stats", 3, 5, 60, 100, 2)
	_expect((icons.get_child(3) as Control).scale == Vector2.ONE, "畫面效果：減少 keeps the HUD still")
	_expect(is_equal_approx((hud.get("power_bar") as ProgressBar).value, 60.0), "the numbers change at once either way")
	hud.queue_free()
	await _frames(2)


func _test_toast() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "res://tests/fixtures/stories/phase3_story.json"
	game.stories_path = "res://tests/fixtures/stories.json"
	game.save_path = "user://game_feel_test.save"
	game.settings_path = "user://game_feel_test.cfg"
	game.progress_path = "user://game_feel_test_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	game._show_toast("取得線索：草莓牛奶")
	await _frames(1)
	_expect(game._toast.visible and game._toast.scale.x < 1.0, "the toast pops in")
	await create_timer(1.3).timeout
	_expect(game._toast.visible and game._toast.modulate.a < 0.9, "it fades over its last moment")
	await create_timer(0.25).timeout
	_expect(not game._toast.visible and is_equal_approx(game._toast.modulate.a, 1.0), "then hides, ready for the next one")
	game._on_setting_changed("motion", 1)
	game._show_toast("取得線索：鞋櫃")
	await _frames(1)
	_expect(game._toast.scale == Vector2.ONE and is_equal_approx(game._toast.modulate.a, 1.0), "畫面效果：減少 shows it plainly")
	game.queue_free()
	await _frames(2)
	for path: String in ["user://game_feel_test.save", "user://game_feel_test.cfg", "user://game_feel_test_progress.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
