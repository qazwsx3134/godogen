extends "res://addons/proto_kit/test_kit.gd"
## While searching, the cast does not cover the room: in chapter 1's living room Gintoki (his mouth is
## a spot) stays see-through and Kagura (no spot on her) turns invisible; both are back, opaque, once a
## scene plays from the search, and the clue tag stays off the stage while searching.

const FILES: Array[String] = ["user://search_cast.save", "user://search_cast.save.bak", "user://search_cast_ui.cfg",
	"user://search_cast_settings.cfg", "user://search_cast_progress.cfg"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = "res://data/chapter1_story.json"
	game.save_path = FILES[0]
	game.settings_path = FILES[3]
	game.progress_path = FILES[4]
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _read_until(game, "investigate")
	var gintoki: Control = game._sprites["gintoki"]
	var kagura: Control = game._sprites["kagura"]
	_expect(gintoki.visible and is_equal_approx(gintoki.modulate.a, game.SEARCH_CAST_ALPHA),
		"Gintoki, whose mouth is a spot, stays see-through")
	_expect(kagura.visible and is_zero_approx(kagura.modulate.a), "Kagura, with no spot on her, turns invisible for the search")
	_test_offscreen_mouth(game, gintoki)
	game._collect_hotspot("desk_underside")
	await _frames(2)
	await _read_until(game, "investigate")
	_expect(is_zero_approx(kagura.modulate.a) and is_equal_approx(gintoki.modulate.a, game.SEARCH_CAST_ALPHA),
		"back in the search after the clue's scene, the same rule holds")
	_expect(not game._phase3_hud.clues.visible and game._phase3_hud.clue_header.text == "線索 ×1",
		"the found clue is counted but its tag stays off the stage while searching")
	game._on_talk_pressed("ch1_topic_2")
	await _frames(2)
	_expect(is_equal_approx(kagura.modulate.a, 1.0) and is_equal_approx(gintoki.modulate.a, 1.0),
		"a topic's scene brings the cast back, opaque")
	game.queue_free()
	await _frames(2)
	_cleanup()
	_finish("SEARCH CAST TESTS")


func _read_until(game: Control, mode: String) -> void:
	for i: int in range(4000):
		if game._screen_mode == mode:
			await _frames(2)
			return
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(false, "reached %s (at %s)" % [mode, game._screen_mode])


func _cleanup() -> void:
	for path: String in FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_offscreen_mouth(game: Control, actor: Control) -> void:
	var original: Vector2 = actor.global_position
	var screen := Rect2(game._game.global_position, game._game.size)
	var art: Rect2 = actor.call("art_rect")
	var region: Array = game._hotspot_data("gintoki_mouth").art_region
	var mouth := Rect2(art.position + art.size * Vector2(region[0], region[1]), art.size * Vector2(region[2], region[3]))
	actor.global_position.x += screen.position.x - mouth.end.x - 1.0
	game._place_cast_hotspots()
	var spot: Control = game._hotspots["gintoki_mouth"]
	var point := Vector2(screen.position.x + 1.0, mouth.get_center().y)
	_expect(not spot.visible, "a wholly offscreen mouth has no visible interaction target")
	var picker = load("res://scripts/investigation_picker.gd")
	var picked: String = picker.pick(point, {"gintoki_mouth": spot},
		{"gintoki_mouth": game._hotspot_data("gintoki_mouth")}, game._sprites, 48.0 * game.CSS_PX * game._panel_scale)
	_expect(picked.is_empty(), "touch expansion cannot bring an offscreen mouth back onto the screen")
	actor.global_position = original
	game._place_cast_hotspots()
	_expect(spot.visible, "returning the portrait to view restores its interaction target")
