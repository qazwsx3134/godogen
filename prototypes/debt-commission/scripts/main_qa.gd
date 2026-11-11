extends RefCounted

## main.gd 的 QA 快照：只在 ?qa=1 的 Web 版把畫面狀態寫給瀏覽器檢查（tools/browser_check.mjs）讀。

const RoundView = preload("res://scripts/round_view.gd")
const DESIGN_WIDTH: float = 1920.0
const CSS_PX: float = DESIGN_WIDTH / 720.0

const PUBLISH_SEC: float = 0.2

var m: DebtMain
var _elapsed: float = 0.0


## With ?qa=1, publishes the state every PUBLISH_SEC.
func process(delta: float) -> void:
	if not m._qa_enabled:
		return
	_elapsed += delta
	if _elapsed >= PUBLISH_SEC:
		_elapsed = 0.0
		publish_qa_state()


func _init(main: DebtMain) -> void:
	m = main


func detect_qa_mode() -> void:
	m._qa_enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval(
		"new URLSearchParams(window.location.search).get('qa') === '1'"))


## Written just before the frame draws, once containers have laid out this frame's changes, so a
## test never reads the rows of a sheet or menu that is still being arranged.
func publish_qa_state() -> void:
	if m._qa_enabled and not RenderingServer.frame_pre_draw.is_connected(_write_qa_state):
		RenderingServer.frame_pre_draw.connect(_write_qa_state, CONNECT_ONE_SHOT)


func _write_qa_state() -> void:
	if not m.is_inside_tree():
		return
	var current: Dictionary = m._runner_current()
	var snapshot: Dictionary = m._runner.snapshot()
	var choices: Array = []
	for index: int in range(m._choice_buttons.size()):
		if index < m._current_options.size() and _tappable(m._choice_buttons[index]):
			choices.append({"id": m._dict_string(m._current_options[index], "id"),
				"label": m._dict_string(m._current_options[index], "label"), "rect": _rect(m._choice_buttons[index])})
	var controls: Dictionary = {}
	var named: Dictionary = {
		"begin": m._begin_button, "continue": m._continue_button, "title_load": m._title_load_button, "dialogue": m._dialog_panel,
		"log": m._log_button, "auto": m._auto_button, "advance": m._advance_button,
		"menu": m._choice_sheet.menu_button if m._choice_sheet.is_visible_in_tree() else m._menu_button, "menu_close": m._menu_close, "log_close": m._log_close,
		"restart": m._restart_button, "title": m._end_title_button, "investigate_continue": m._investigation_continue_button,
		"investigate_collapse": m._dialog_panel.investigation_collapse, "investigate_expand": m._investigate_bar.get("expand_button"),
		"investigate_folded_continue": m._investigate_bar.get("continue_button"),
		"boke_previous": m._boke_previous_button, "boke_next": m._boke_next_button,
		"boke_listen": m._boke_listen_button, "boke_tsukkomi": m._boke_tsukkomi_button,
		"game_over_retry": m._game_over_retry_button, "game_over_title": m._game_over.title_button,
		"result_next": m._chapter_result.get("next_button"), "result_title": m._chapter_result.get("title_button"),
		"chapter_close": m._chapter_select.get("close_button"), "settings_close": m._settings_panel.get("close_button"),
		"chapter_credits": m._chapter_select.get("credits_button"), "credits_close": m._credits_roll.get("close_button"),
		"chapter_gallery": m._chapter_select.get("gallery_button"), "gallery_close": m._gallery.get("close_button"),
		"gallery_tab_pictures": m._gallery.get("pictures_tab"), "gallery_tab_music": m._gallery.get("music_tab"),
		"title_settings": m._title_screen.settings_button, "story_switch": m._title_screen.story_switch,
		"censor": m._choice_sheet.censor_bar if m._choice_sheet.censor_bar.is_visible_in_tree() else m._dialog_panel.censor_bar,
		"super": m._choice_sheet.super_button,
	}
	if m._dialog_panel.skip_button != null:
		named["skip"] = m._dialog_panel.skip_button
	for item_id: String in m._menu_items.keys():
		named["menu_" + item_id] = m._menu_items[item_id]
	var chapter_rows: Dictionary = m._chapter_select.call("rows")
	for story_id: String in chapter_rows.keys():
		named["chapter_" + story_id] = chapter_rows[story_id]
	var setting_buttons: Dictionary = m._settings_panel.call("buttons")
	for setting_id: String in setting_buttons.keys():
		named["setting_" + setting_id] = setting_buttons[setting_id]
	# While 目錄 is open its dim covers everything else, so only its own controls can be tapped.
	var modal: Control = m._menu_overlay if m._menu_overlay.visible else null
	var gallery_items: Dictionary = m._gallery.call("items")
	for item_id: String in gallery_items.keys():
		named["gallery_" + item_id] = gallery_items[item_id]
	for panel: Control in [m._settings_panel, m._chapter_select, m._credits_roll, m._gallery]:  # opened over the title or 目錄
		if panel.visible:
			modal = panel
	for control_name: String in named.keys():
		var control: Control = named[control_name]
		if _tappable(control) and (modal == null or modal.is_ancestor_of(control)):
			controls[control_name] = _rect(control)
	var hotspot_state: Array[Dictionary] = []
	for raw_hotspot: Variant in current.get("hotspots", []):
		if not raw_hotspot is Dictionary:
			continue
		var hotspot: Dictionary = raw_hotspot as Dictionary
		var hotspot_id: String = m._dict_string(hotspot, "id")
		var spot: Control = m._hotspots.get(hotspot_id) as Control
		var hit: Rect2 = m._investigation.hotspot_hit_rect(spot) if spot != null and is_instance_valid(spot) else Rect2()
		# `rect` only while a tap there would reach the spot: on screen and not under the reading box.
		# A character's spot is their whole portrait, so it reports the part above the box.
		var reach: Rect2 = hit
		var covered: bool = m._dialog_panel.visible and m._dialog_panel.get_global_rect().intersects(hit)
		if hotspot.has("character") and covered:
			reach.end.y = minf(reach.end.y, m._dialog_panel.get_global_rect().position.y)
			covered = false
		if m._investigate_bar.visible:  # the translucent strip passes input; only its buttons cover spots
			for name: String in ["expand_button", "continue_button"]:
				var bar_button: Control = m._investigate_bar.get(name) as Control
				if bar_button != null and bar_button.is_visible_in_tree():
					reach = _rect_without_control(reach, bar_button.get_global_rect())
		var reachable: bool = reach.has_area() and Rect2(m._game.global_position, m._game.size).encloses(reach) and not covered
		hotspot_state.append({
			"id": hotspot_id,
			"label": m._dict_string(hotspot, "label"),
			"checked": bool(hotspot.get("checked", false)),
			"pos": hotspot.get("pos", []),
			"screen_rect": {"x": hit.position.x, "y": hit.position.y, "width": hit.size.x, "height": hit.size.y},
			"rect": {"x": reach.position.x, "y": reach.position.y, "width": reach.size.x, "height": reach.size.y} if reachable else {},
		})
	# 舞台中央空白處：點畫面任一處也能推進。
	if m._dialog_panel.is_visible_in_tree() or m._ui_hidden:
		var stage: Rect2 = Rect2(m._game.position + Vector2(m._game.size.x * 0.35, m._game.size.y * 0.3),
			Vector2(m._game.size.x * 0.3, m._game.size.y * 0.08))
		controls["stage"] = {"x": stage.position.x, "y": stage.position.y, "width": stage.size.x, "height": stage.size.y}
	if m._qte != null and is_instance_valid(m._qte):  # the whole screen answers the QTE
		controls["qte"] = _rect(m._qte)
	if m._round.placard_open():  # the part of the board a tap reaches (at least 48 CSS px tall to count)
		var board: Rect2 = m._round.placard_hit_rect()
		if board.size.y >= 48.0 * CSS_PX * m._panel_scale - 1.0 and board.size.x > 0.0:
			controls["placard"] = {"x": board.position.x, "y": board.position.y, "width": board.size.x, "height": board.size.y}
	for key: String in m._topic_buttons.keys():
		var topic: Button = m._topic_buttons[key] as Button
		if is_instance_valid(topic) and _tappable(topic) and modal == null:
			controls[key.replace(":", "_")] = _rect(topic)
	if m._menu_overlay.visible:  # the dimmed margin beside the panel
		var dim: Rect2 = Rect2(m._game.position + Vector2(0.0, m._game.size.y * 0.5 - 60.0), Vector2(14.0 * CSS_PX * m._panel_scale, 120.0))
		controls["menu_dim"] = {"x": dim.position.x, "y": dim.position.y, "width": dim.size.x, "height": dim.size.y}
	var visible_slots: Array = []
	if m._slot_overlay.visible:
		for local_index: int in range(m._slot_card_buttons.size()):
			var card: Button = m._slot_card_buttons[local_index]
			if not card.is_visible_in_tree() or local_index >= m._slot_visible_entries.size():
				continue
			var entry: Dictionary = m._slot_visible_entries[local_index].duplicate(true)
			entry["rect"] = _rect(card)
			visible_slots.append(entry)
			if not m._slot_confirmation_overlay.visible:
				controls["slot_%d" % int(entry["index"])] = _rect(card)
		if not m._slot_confirmation_overlay.visible:
			for pair: Array in [["slot_prev", m._slot_prev_button], ["slot_next", m._slot_next_button],
				["slot_close", m._slot_close_button]]:
				var name: String = str(pair[0])
				var button: Control = pair[1] as Control
				if button.is_visible_in_tree() and not (button is BaseButton and (button as BaseButton).disabled):
					controls[name] = _rect(button)
			if m._slot_auto_button.is_visible_in_tree() and not m._slot_auto_button.disabled:
				controls["slot_auto"] = _rect(m._slot_auto_button)
	if m._slot_confirmation_overlay.visible:
		controls["slot_confirm_yes"] = _rect(m._slot_confirm_yes)
		controls["slot_confirm_no"] = _rect(m._slot_confirm_no)
	var sprites: Dictionary = {}
	for actor_id: String in m._sprites.keys():
		var sprite: Control = m._sprites[actor_id]
		sprites[actor_id] = {"visible": sprite.visible, "expression": str(sprite.get("expression")),
			"focused": sprite.modulate.r > 0.9, "position": str(m._actor_slots.get(actor_id, "center"))}
	var state: Dictionary = {
		# While the menu pops in, its rows are scaled and not yet laid out: report busy until it settles.
		# The director's sheet springs in the same way.
		"screen": "tutorial" if m._tutorial != null and m._tutorial.visible else "busy" if (m._screen == DebtMain.Screen.MENU and m._menu_panel.scale != Vector2.ONE) or m._choice_sheet.is_popping() else m._screen_mode,
		"text": m._visible_text,
		"full_text": m._full_text,
		"speaker": m._current_speaker,
		"node_id": m._dict_string(current, "node_id", m._dict_string(snapshot, "node_id")),
		"source_id": m._dict_string(current,"source_id", m._dict_string(RoundView.line(current), "source_id")),
		"step_index": int(current.get("step_index", snapshot.get("step_index", -1))),
		"flags": snapshot.get("flags", {}),
		"items": snapshot.get("items", []),
		"background": m._current_bg_id,
		"text_complete": m._text_complete,
		"ui_hidden": m._ui_hidden,
		"auto": m._auto,
		"skip": m._skip,
		"audio_muted": m._audio_muted,
		"result": m._runner.chapter_result() if m._screen == DebtMain.Screen.RESULT else {},
		# Read from progress_path (and each story's JSON), so only on the screens that show it.
		"cleared": m._story_choices.map(func(choice: Dictionary) -> Dictionary:
			return {"id": str(choice["id"]), "grade": m._cleared_grade(str(choice["id"])), "endings": m._ending_note(choice)})
			if m._screen in [DebtMain.Screen.TITLE, DebtMain.Screen.CHAPTER_SELECT, DebtMain.Screen.RESULT] else [],
		"ending_rows": m._chapter_select.call("ending_rows") if m._screen == DebtMain.Screen.CHAPTER_SELECT else [],
		"credits": {"rolling": bool(m._credits_roll.get("rolling")), "lines": m._credits_roll.call("lines")}
			if m._screen == DebtMain.Screen.CREDITS else {},
		"gallery": {"tab": str(m._gallery.get("tab")), "playing": str(m._gallery.get("playing_id")),
			"viewer": bool(m._gallery.call("viewer_open")), "bg": m._library.unlocked_ids(m._gallery_key("bg")), "bgm": m._library.unlocked_ids(m._gallery_key("bgm"))}
			if m._screen == DebtMain.Screen.GALLERY else {},
		"settings": m._settings.duplicate(),
		"ui_style": m._ui_style_id,
		"toast": m._toast.text if m._toast.visible else "",
		"viewport": {"width": m.get_viewport_rect().size.x, "height": m.get_viewport_rect().size.y},
		"game": _rect(m._game),
		"dialog": _rect(m._dialog_panel) if m._dialog_panel.is_visible_in_tree() else {},
		"investigate_bar": _rect(m._investigate_bar) if m._investigate_bar.is_visible_in_tree() else {},
		"investigate_backdrop": _rect(m._investigate_bar.get("panel") as Control) if m._investigate_bar.is_visible_in_tree() else {},
		"investigate_backdrop_opacity": (m._investigate_bar.get("panel") as Control).self_modulate.a,
		"quickbar": _rect(m._quickbar) if m._quickbar.is_visible_in_tree() else {},
		"choice_sheet": _rect(m._choice_sheet) if m._choice_sheet.is_visible_in_tree() else {},
		"choice_viewport": _rect(m._choice_sheet.choices_scroll) if m._choice_sheet.is_visible_in_tree() else {},
		"name_plate": _rect(m._name_plate) if m._name_plate.is_visible_in_tree() else {},
		"sprites": sprites,
		"placard": {"text": str(m._placard_holder.call("placard_text")) if m._placard_holder != null else "",
			"glowing": m._placard_holder != null and bool(m._placard_holder.call("placard_glowing")),
			"holder_visible": m._placard_holder != null and m._placard_holder.visible,
			"tappable": m._round.placard_open()},
		"log_scroll": {"value": m._log_scroll.scroll_vertical, "max": m._log_scroll.get_v_scroll_bar().max_value - m._log_scroll.size.y},
		"choices": choices,
		"choice": choice_qa_state(current),
		"phase3": {
			"enabled": m._phase3_enabled,
			"gameplay": snapshot.get("gameplay", {}),
			"inventory": snapshot.get("items", []),
			"hotspots": hotspot_state,
			"investigation": {"place": m._dict_string(current, "place"), "place_label": m._dict_string(current, "place_label"),
				"talk": (current.get("talk", []) as Array).map(func(topic: Dictionary) -> String: return str(topic["id"])),
				"moves": (current.get("moves", []) as Array).map(func(move: Dictionary) -> String: return str(move["id"])),
				"complete": bool(current.get("complete", false)), "progress": current.get("progress", [])}
				if m._command_op(current) == "investigate" else {},
			"pan": {"offset": m._pan, "min": m._pan_range.x, "max": m._pan_range.y,
				"vertical_offset": m._pan_y, "vertical_min": m._pan_y_range.x, "vertical_max": m._pan_y_range.y},
			"investigate_collapsed": m._investigate_collapsed,
			"boke_screen_mode": m._saves.effective_boke_ui_mode() if m._command_op(current) == "boke_round" else "",
			"boke_line_index": int(current.get("line_index", -1)),
			"boke_line_count": (current.get("lines", []) as Array).size(),
			"boke_listened": RoundView.listened(current),
			"boke_listen_available": RoundView.can_listen(current),
			"round": {
				"mode": str(current.get("mode", "")), "combo": int(current.get("combo", 0)),
				"caught": current.get("caught_line_ids", []), "super_available": bool(current.get("super_available", false)),
				"super_label": m._choice_sheet.super_button.text,
				"aura_active": m._phase3_hud.glasses.get_children().any(func(icon: Node) -> bool: return bool(icon.get("charged")) and not bool(icon.get("broken"))),
				"censor": RoundView.censor(current), "placard": RoundView.placard(current), "qte_active": m._qte != null,
				"qte_elapsed": m._qte.call("elapsed") if m._qte != null else 0.0,
				# Browser clock (ms) at which the rings meet, so a route can aim a tap without polling lag.
				"qte_meet_ms": Time.get_unix_time_from_system() * 1000.0 + (m._qte.duration - float(m._qte.call("elapsed"))) * 1000.0
					if m._qte != null else 0.0,
				"last_qte_offset": m._last_qte_offset,
			},
			"timer_remaining": m._boke_time_remaining,
			"timer_active": m._command_op(current) == "boke_round" and m._saves.effective_boke_ui_mode() == "tsukkomi",
			"timer_paused": m._command_op(current) == "boke_round" and m._saves.effective_boke_ui_mode() == "tsukkomi" and m._screen != DebtMain.Screen.TSUKKOMI,
			"checkpoint_ready": not (snapshot.get("checkpoint", {}) as Dictionary).is_empty(),
			"game_over_active": bool(snapshot.get("game_over_active", false)),
			"last_result": m._last_boke_result,
		},
		"beam_active": m._overlay_layer.get_children().any(func(node: Node) -> bool: return node.scene_file_path == "res://scenes/ui/beam.tscn"),
		"comedy": m._comedy_layer.qa_state(),
		"controls": controls,
		"slot_page": m._slot_page,
		"slots": visible_slots,
	}
	JavaScriptBridge.eval("window.__debtQA=Object.freeze(%s);" % JSON.stringify(state))


## The `choice` field of the QA snapshot while a `choice` step has its options up (else {}): the look the
## step asks for (`perspective`, whose thought `pov`, the director's `note`, each row's `tones`) and the
## sheet that really holds it (`director`, or the edition's id).
func choice_qa_state(current: Dictionary) -> Dictionary:
	if m._command_op(current) != "choice" or m._choice_buttons.is_empty():
		return {}
	var director: bool = m._dict_string(current, "perspective", "pov") == "director"
	var tones: Array = []
	for option: Dictionary in m._current_options:
		tones.append(m._dict_string(option, "tone"))
	return {"perspective": "director" if director else "pov",
		"pov": "" if director else m._dict_string(current, "pov", m._default_pov()),
		"note": m._dict_string(current, "note"),
		"sheet": "director" if m._choice_sheet.perspective == "director" else m._choice_sheet.style_id,
		"tones": tones}


## Visible, enabled, and not scrolled or clipped out of view (a menu row below the fold is not).
func _tappable(control: Control) -> bool:
	if not control.is_visible_in_tree() or (control is BaseButton and (control as BaseButton).disabled):
		return false
	var area: Rect2 = control.get_global_rect()
	var parent: Node = control.get_parent()
	while parent is Control:
		if (parent as Control).clip_contents and not (parent as Control).get_global_rect().grow(0.5).encloses(area):
			return false
		parent = parent.get_parent()
	return true


## Largest rectangular part of a hotspot outside an interactive control, for the QA bridge.
func _rect_without_control(area: Rect2, control: Rect2) -> Rect2:
	if not area.intersects(control):
		return area
	var overlap: Rect2 = area.intersection(control)
	var candidates: Array[Rect2] = [
		Rect2(area.position, Vector2(overlap.position.x - area.position.x, area.size.y)),
		Rect2(Vector2(overlap.end.x, area.position.y), Vector2(area.end.x - overlap.end.x, area.size.y)),
		Rect2(area.position, Vector2(area.size.x, overlap.position.y - area.position.y)),
		Rect2(Vector2(area.position.x, overlap.end.y), Vector2(area.size.x, area.end.y - overlap.end.y)),
	]
	var largest: Rect2 = Rect2()
	for candidate: Rect2 in candidates:
		if candidate.has_area() and candidate.get_area() > largest.get_area():
			largest = candidate
	return largest


func _rect(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}
