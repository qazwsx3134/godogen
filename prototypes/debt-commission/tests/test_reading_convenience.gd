extends "res://addons/proto_kit/test_kit.gd"
const Slots=preload("res://scripts/save_slots.gd")
func _init() -> void:_run.call_deferred()
func _run() -> void:
	root.size=Vector2i(390,844)
	var game=load("res://main.tscn").instantiate()
	game.story_path="res://tests/fixtures/reading_convenience_story.json"
	game.save_path="user://test_reading_convenience.save"
	game.ui_preference_path="user://test_reading_convenience_ui.cfg"
	game.settings_path="user://test_reading_convenience_settings.cfg"
	for base in [game.save_path,Slots.quick_path(game.save_path)]:
		for suffix in ["",".bak",".tmp",".old"]:
			if FileAccess.file_exists(base+suffix):DirAccess.remove_absolute(base+suffix)
	root.add_child(game)
	await _frames(3)
	game._on_begin_pressed()
	await _until(func() -> bool:return game._screen_mode=="story", "first reading line")
	game._complete_current_line()
	var first=game._build_save_payload("")
	for field: String in ["round_stages", "investigation_pans", "investigation_home_casts"]:
		var malformed=first.duplicate(true)
		malformed[field]=["wrong metadata"]
		_expect(not game._apply_save_payload(malformed) and game._full_text=="第一句。", "malformed %s is rejected before changing the live game" % field)
	var bad_pan=first.duplicate(true)
	bad_pan.investigation_pans={"home": NAN}
	_expect(not game._validate_save_payload(bad_pan), "non-finite pan offsets cannot enter a save")
	var bad_stage=first.duplicate(true)
	bad_stage.round_stages={"round": {"background":"yorozuya_living_room", "sprites":{}, "bgm":"bgm_daily"}}
	_expect(not game._validate_save_payload(bad_stage), "incomplete checkpoint cast is rejected")

	_expect(game._quick_save(),"quick save writes a separate valid slot")
	game._advance_current_line()
	await _until(func() -> bool:return game._full_text=="第二句。", "advance over flags and material")
	game._complete_current_line()
	_expect(game._runner.flags.remembered and game._runner.items.has("milk_bottle"),"second line owns intervening flags and material")
	_expect(game._rollback_line(),"reading can return to the preceding line")
	_expect(not game._runner.flags.remembered and game._runner.items.is_empty(),"rollback restores flags and removes a future material")
	_expect(game._current_bg_id=="yorozuya_living_room" and game._effects.current_bgm=="bgm_daily" and game._history.size()==1,"rollback restores stage, music and log")
	_expect(not game._rollback_line(),"rollback cannot pass the beginning of the segment")
	game._on_setting_changed("font_size",2)
	game._on_setting_changed("paper_opacity",0)
	_expect(game._text_label.get_theme_font_size("normal_font_size")==58,"dialogue font size applies immediately")
	_expect(is_equal_approx(game._dialog_panel.get_node("PaperAndToolbar/Panel/Frame/PaperCutout").modulate.a,0.65) \
		and game._text_label.modulate.a==1.0 and game._name_label.modulate.a==1.0,"paper transparency keeps text and name opaque")
	game._advance_current_line()
	await _until(func() -> bool:return game._full_text=="第二句。", "return to second line")
	game._complete_current_line()
	_expect(game._quick_save(),"second quick save retains the previous quick state as backup")
	var file=FileAccess.open(Slots.quick_path(game.save_path),FileAccess.WRITE)
	file.store_var("corrupted quick primary")
	file.close()
	_expect(game._quick_load() and game._full_text=="第一句。","quick load falls back to a valid backup")
	_expect(not game._rollback.available(),"loading clears ephemeral rollback history")
	_expect(game._read_save_payload(Slots.manual_path(game.save_path,1)).is_empty(),"quick slot is isolated from the 18 manual slots")
	game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool:return game._full_text=="第二句。", "second line again")
	game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool:return game._full_text=="第三句。", "third line")
	game._complete_current_line()
	game._advance_current_line()
	await _until(func() -> bool:return game._screen_mode=="choice", "choice boundary")
	_expect(not game._rollback.available() and not game._rollback_line(),"rollback cannot cross a choice")
	game._on_choice_pressed("go")
	await _until(func() -> bool:return game._screen_mode=="story", "new segment after choice")
	_expect(not game._rollback.available(),"a new segment cannot roll back into the prior branch")
	game.queue_free()
	await _frames(2)
	_finish("READING CONVENIENCE TESTS")
