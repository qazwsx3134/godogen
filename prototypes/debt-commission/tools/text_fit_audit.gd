extends "res://tools/shots_chapter1.gd"
## B14: plays chapter 1 at the largest reading size and, on every screen it reaches, lists text
## that does not fit: a Label or button whose text is cut (lines hidden, clipped or trimmed), a
## RichTextLabel taller than its box, text cut by a clipping parent (scroll boxes excepted), or
## text running off the game area. Screens: title, 設定, 章節選擇, 製作名單, 鑑賞 (both tabs), every line up to the
## search, the search and its folded bar, 回顧, 目錄, 存檔, 案件檔, the round, the tsukkomi sheet, the
## QTE, Game Over and the chapter result. Each screen is also saved as a PNG. Needs a window:
##   Godot --path . --resolution 780x1688 --script res://tools/text_fit_audit.gd -- <out_dir>
## (on a Retina Mac 780x1688 is a 390 CSS px phone, 640x1136 a 320 one). Exit code 1 when anything
## is cut; <out_dir>/text_fit.json has the details.

var _issues: Array[Dictionary] = []
## Labels shortened with an ellipsis on purpose (the chapter name beside a long speaker name):
## reported, not failed.
var _notes: Array[Dictionary] = []
var _screens: Array[String] = []


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://text_fit"
	DirAccess.make_dir_recursive_absolute(_out)
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("settings", "font_size", 2)
	settings.save("user://shots_settings.cfg")
	_game = MAIN.instantiate() as Control
	_game.story_path = "res://data/chapter1_story.json"
	_game.save_path = "user://shots_chapter1.save"
	_game.settings_path = "user://shots_settings.cfg"
	_game.progress_path = "user://shots_progress.cfg"
	root.add_child(_game)
	await _frames(5)
	await _audit("title")
	_game.call("_open_settings")
	await _audit("settings")
	_game.call("_close_settings")
	_game.call("_open_chapter_select")
	await _audit("chapter_select")
	_game.call("_open_credits")
	await _audit("credits")
	_game._credits_roll.call("close")
	_game.call("_open_gallery")
	await _audit("gallery_pictures")
	_game._gallery.call("show_tab", "music")
	await _audit("gallery_music")
	_game._gallery.call("close")
	_game.call("_close_chapter_select")
	_game.call("_on_begin_pressed")
	# Every line up to the search, each fully shown.
	var seen: Dictionary = {}
	for i: int in range(6000):
		if _game._screen_mode == "investigate":
			break
		if _game._screen_mode == "story" and not _game._story_busy:
			if not _game._text_complete:
				_game.call("_complete_current_line")
			else:
				var key: String = "%s/%d" % [_game._runner.node_id, _game._runner.step_index]
				if not seen.has(key):
					seen[key] = true
					await _audit("line " + key, false)
				_game.call("_advance_current_line")
		await process_frame
	await _audit("investigate")
	_game.call("_set_investigation_collapsed", true)
	await _audit("investigate_bar")
	_game.call("_set_investigation_collapsed", false)
	_game.call("_open_log")
	await _audit("log")
	_game.call("_close_log")
	_game.call("_open_menu")
	await _audit("menu")
	_game.call("_open_slot_picker", "save")
	await _audit("save_slots")
	_game.call("_close_slot_picker")
	if _game._screen_mode == "menu":
		_game.call("_close_menu")
	for spot: String in CLUES:
		_game.call("_collect_hotspot", spot)
		if not await _play_until(func() -> bool: return _game._screen_mode == "investigate", "back to search"):
			return _quit(1)
	_game.call("_open_case_file", "materials")
	await _audit("case_file")
	_game.call("_close_case_file")
	_game.call("_on_investigation_continue_pressed")
	if not await _play_until(func() -> bool: return _game._screen_mode == "boke_round", "round 1"):
		return _quit(1)
	_game.call("_complete_current_line")
	await _audit("round")
	_game.call("_on_boke_tsukkomi_pressed")
	await _frames(20)
	await _audit("tsukkomi")
	_game.call("_start_qte", {"current_line": {"qte": {"duration": 30.0, "late_after": 31.0}}})
	await _audit("qte")
	_game.call("_close_qte")
	_game._game_over.open("新八的本體已損毀・從本回合重試")
	await _audit("game_over")
	_game._game_over.visible = false
	var result: Control = _game._chapter_result
	result.call("show_result", {"title": "第一章・萬事屋冰箱草莓牛奶失竊事件", "ending_title": "試毒試到一滴不剩", "grade": "S",
		"caught": 12, "tries": 12, "perfect": 12, "max_combo": 5, "hidden": 1, "hidden_total": 1, "glasses": 5, "max_glasses": 5,
		"line": {"text": "這副眼鏡，今天還算有用阿魯。"}}, "神樂", true, "劇本 測試作者｜繪 畫師甲、畫師乙")
	result.visible = true
	await _audit("result")
	var report: Dictionary = {"screens": _screens, "issues": _issues, "notes": _notes}
	var file: FileAccess = FileAccess.open(_out.path_join("text_fit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	for issue: Dictionary in _issues:
		print("CUT ", issue["screen"], " | ", issue["node"], " | ", issue["reason"], " | ", issue["text"])
	print("TEXT FIT %s: %d screens, %d cut, %d shortened with an ellipsis on purpose" % [
		"OK" if _issues.is_empty() else "FAILED", _screens.size(), _issues.size(), _notes.size()])
	_quit(0 if _issues.is_empty() else 1)


func _audit(screen: String, shoot: bool = true) -> void:
	await _frames(12)
	_screens.append(screen)
	var game_rect: Rect2 = Rect2(_game._game.global_position, _game._game.size)
	_walk(_game, screen, game_rect)
	if shoot:
		await _shot(screen.replace(" ", "_").replace("/", "_"), 1)


func _walk(node: Node, screen: String, game_rect: Rect2) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node.name == &"Hotspots":
		return  # spots ride on the dragged background picture and leave the screen with it
	if node is Control:
		var reason: String = _cut(node as Control, game_rect)
		if not reason.is_empty():
			var entry: Dictionary = {"screen": screen, "node": str(_game.get_path_to(node)), "reason": reason, "text": _text_of(node as Control)}
			if reason == "trimmed" and (node as Label).text_overrun_behavior in [TextServer.OVERRUN_TRIM_ELLIPSIS, TextServer.OVERRUN_TRIM_WORD_ELLIPSIS]:
				entry["reason"] = "ellipsis (by design)"
				_notes.append(entry)
			else:
				_issues.append(entry)
	for child: Node in node.get_children():
		_walk(child, screen, game_rect)


func _cut(control: Control, game_rect: Rect2) -> String:
	var text: String = _text_of(control)
	if text.strip_edges().is_empty() or control.modulate.a < 0.05:
		return ""
	var rect: Rect2 = control.get_global_rect()
	if control is Label:
		var label: Label = control as Label
		if label.get_line_count() > label.get_visible_line_count() and label.max_lines_visible < 0:
			return "lines hidden (%d of %d shown)" % [label.get_visible_line_count(), label.get_line_count()]
		if label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or label.clip_text:
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and _width(label, label.text) > label.size.x + 1.0:
				return "trimmed"
	elif control is Button:
		var button: Button = control as Button
		var inner: float = button.size.x - _margins(button)
		if button.autowrap_mode == TextServer.AUTOWRAP_OFF and (button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) \
				and _width(button, button.text) > inner + 1.0:
			return "button text trimmed"
	elif control is RichTextLabel:
		var rich: RichTextLabel = control as RichTextLabel
		if not rich.fit_content and not rich.scroll_active and rich.get_content_height() > rich.size.y + 2.0 \
				and rich.visible_ratio >= 1.0:
			return "rich text taller than its box (%d > %d)" % [rich.get_content_height(), rich.size.y]
	else:
		return ""
	# Inside a scroll box, scrolling up and down is how a row is read: only its width must fit.
	var scroll: ScrollContainer = _ancestor_scroll(control)
	var bounds: Rect2 = scroll.get_global_rect() if scroll != null else game_rect
	var clip: Control = _clipping_parent(control, scroll)
	if clip != null:
		bounds = bounds.intersection(clip.get_global_rect())
	var fits_across: bool = rect.position.x >= bounds.position.x - 2.0 and rect.end.x <= bounds.end.x + 2.0
	var fits_down: bool = scroll != null or (rect.position.y >= bounds.position.y - 2.0 and rect.end.y <= bounds.end.y + 2.0)
	if not fits_across or not fits_down:
		return "cut by %s" % (str(_game.get_path_to(clip)) if clip != null else ("its scroll box" if scroll != null else "the screen edge"))
	return ""


func _ancestor_scroll(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null and node != _game:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


## The nearest clipping ancestor below the scroll box (the game area itself is the screen edge).
func _clipping_parent(control: Control, scroll: ScrollContainer) -> Control:
	var node: Node = control.get_parent()
	while node != null and node != _game._game and node != scroll:
		if node is Control and (node as Control).clip_contents:
			return node as Control
		node = node.get_parent()
	return null


func _text_of(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is Button:
		return (control as Button).text
	if control is RichTextLabel:
		return (control as RichTextLabel).get_parsed_text()
	return ""


func _width(control: Control, text: String) -> float:
	var font: Font = control.get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x


func _margins(button: Button) -> float:
	var box: StyleBox = button.get_theme_stylebox("normal")
	var icon: float = button.icon.get_width() + button.get_theme_constant("h_separation") if button.icon != null else 0.0
	return (box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT) if box != null else 0.0) + icon
