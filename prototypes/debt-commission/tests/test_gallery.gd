extends "res://addons/proto_kit/test_kit.gd"
## 鑑賞: backgrounds and music met in play are recorded once in progress.cfg (story_library.gd);
## 章節選擇's 鑑賞 lists every catalog picture and track with a file, the unmet ones as ？？？; a
## seen picture opens full screen, a heard track plays while the story music pauses, and back
## closes the viewer, then the gallery.

const Library = preload("res://scripts/story_library.gd")
const FILES: Array[String] = ["user://gallery_test_progress.cfg", "user://gallery_test_ui.cfg",
	"user://gallery_test_settings.cfg", "user://gallery_test.save", "user://gallery_test.save.bak"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_library_records()
	_cleanup()
	await _play_and_browse()
	_cleanup()
	_finish("GALLERY TESTS")


func _library_records() -> void:
	var library: RefCounted = Library.new("res://data/stories.json", FILES[0])
	library.unlock("bg", "yorozuya_kitchen")
	library.unlock("bg", "yorozuya_kitchen")
	library.unlock("bgm", "bgm_daily")
	library.unlock("bg", "")
	var reread: RefCounted = Library.new("res://data/stories.json", FILES[0])
	_expect(reread.unlocked_ids("bg") == ["yorozuya_kitchen"] and reread.unlocked_ids("bgm") == ["bgm_daily"],
		"unlocks are kept once each and survive a new library: %s %s" % [reread.unlocked_ids("bg"), reread.unlocked_ids("bgm")])


func _play_and_browse() -> void:
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate() as Control
	game.story_path = "res://data/chapter1_story.json"
	game.save_path = FILES[3]
	game.progress_path = FILES[0]
	game.settings_path = FILES[2]
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	for i: int in range(4000):
		if game._screen_mode == "investigate":
			break
		if game._screen_mode == "story" and not game._story_busy:
			if game._text_complete:
				game._advance_current_line()
			else:
				game._complete_current_line()
		await _frames(1)
	_expect(game._screen_mode == "investigate", "chapter 1 reaches the search")
	_expect(game._library.unlocked_ids("bg") == ["yorozuya_kitchen", "yorozuya_living_room"]
		and game._library.unlocked_ids("bgm") == [game.TITLE_BGM, "bgm_daily"],
		"the title music, then the kitchen, the living room and 日常 are met on the way: %s %s" % [game._library.unlocked_ids("bg"), game._library.unlocked_ids("bgm")])
	game._show_title()
	await _frames(2)
	var story_music: String = game._effects.current_bgm  # whatever plays behind the title
	game._open_chapter_select()
	await _frames(2)
	game._chapter_select.gallery_button.pressed.emit()
	await _frames(3)
	var gallery: Control = game._gallery
	_expect(game._screen_mode == "gallery" and gallery.visible and gallery.tab == "pictures", "鑑賞 opens on 畫廊")
	var items: Dictionary = gallery.items()
	_expect(items.keys().filter(func(k: String) -> bool: return k.begins_with("picture_")).size() == 3,
		"every background with a picture is listed: %s" % [items.keys()])
	var kitchen: Button = items["picture_yorozuya_kitchen"]
	var outside: Button = items["picture_yorozuya_exterior"]
	_expect(not kitchen.disabled and kitchen.get_node("%Caption").text == "萬事屋廚房" and kitchen.get_node("%Thumb").texture != null,
		"a seen picture shows its thumbnail and name")
	_expect(outside.disabled and outside.get_node("%Caption").text == "？？？" and outside.get_node("%Thumb").texture == null,
		"an unseen one is ？？？ with no picture")
	kitchen.pressed.emit()
	_expect(gallery.viewer_open(), "a seen picture opens full screen")
	_cancel()
	await _frames(2)
	_expect(not gallery.viewer_open() and game._screen_mode == "gallery", "back closes the picture first")
	gallery.music_tab.pressed.emit()
	await _frames(2)
	_expect(gallery.tab == "music" and gallery.get_node("%Progress").text.begins_with("已聽過 2/"), "音樂 counts what was heard")
	var daily: Button = gallery.items()["track_bgm_daily"]
	var locked: Button = gallery.items()["track_bgm_gintama_01"]
	_expect(not daily.disabled and daily.text == "♪ 日常" and locked.disabled and locked.text == "？？？",
		"a heard track can play, an unheard one is ？？？")
	daily.pressed.emit()
	await _frames(2)
	_expect(gallery.playing_id == "bgm_daily" and daily.text == "■ 日常" and game._effects.current_bgm == "",
		"a track plays and the story music pauses")
	_cancel()
	await _frames(2)
	_expect(game._screen_mode == "chapter_select" and not gallery.visible and gallery.playing_id == ""
		and game._effects.current_bgm == story_music,
		"back closes 鑑賞, stops the preview and brings back the music that played before (%s, now %s)" % [story_music, game._effects.current_bgm])
	game.queue_free()
	await _frames(2)


func _cancel() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)


func _cleanup() -> void:
	for path: String in FILES:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
