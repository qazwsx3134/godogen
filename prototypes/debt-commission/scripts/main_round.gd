extends RefCounted

## main.gd 的裝傻回合：證言與選詞、消音條、伊莉莎白的牌子、超必殺、QTE 與 Game Over 重試。

const RoundView = preload("res://scripts/round_view.gd")
const QteRing = preload("res://scripts/qte_ring.gd")
const QTE_SCENE: PackedScene = preload("res://scenes/ui/qte_ring.tscn")
const SETTINGS_SCRIPT: Script = preload("res://scripts/settings.gd")
const DialogueText: Script = preload("res://scripts/dialogue_text.gd")
const DESIGN_WIDTH: float = 1920.0
const CSS_PX: float = DESIGN_WIDTH / 720.0
## Why a take went cold, shown after the miss toast (keyed by the runner's round action).
const MISS_CAUSE: Dictionary = {"timeout": "時間到", "option": "這個選項不對", "whiff": "這句沒有槽點", "qte": "時機沒抓到"}

var m: DebtMain
## The whole seconds the tsukkomi countdown last showed; the HUD and QA refresh when it changes.
var last_display_second: int = -1


## Runs the tsukkomi countdown while its options are up; true when it ran out this frame (the
## timeout is being resolved, so nothing else should act on the frame).
func process(delta: float) -> bool:
	if m._screen != DebtMain.Screen.TSUKKOMI or m._story_busy:
		return false
	m._boke_time_remaining = maxf(0.0, m._boke_time_remaining - delta)
	m._choice_sheet.set_timer(m._boke_time_remaining, m._timer_total(m._current_command), false)
	var displayed_second: int = ceili(m._boke_time_remaining)
	if displayed_second != last_display_second:
		last_display_second = displayed_second
		m._refresh_phase3_hud()
		m._qa_ctl.publish_qa_state()
	if m._boke_time_remaining <= 0.0:
		on_boke_timeout()
		return true
	return false


func _init(main: DebtMain) -> void:
	m = main


func present_boke_round(command: Dictionary, restored: bool, requested_ui_mode: String = "") -> void:
	m._pending_round_mode = ""
	m._line_generation += 1
	var round_id: String = m._dict_string(command,"id")
	if not m._round_stages.has(round_id):
		var stage_payload: Dictionary = m._saves.build_save_payload("")
		m._round_stages[round_id] = {"background": stage_payload.get("background",m._current_bg_id),
			"sprites": stage_payload.get("sprites",{}).duplicate(true), "bgm": m._effects.current_bgm}
	var target_ui_mode: String = requested_ui_mode
	if target_ui_mode.is_empty():
		target_ui_mode = m._restored_boke_ui_mode if restored and not m._restored_boke_ui_mode.is_empty() else "boke_round"
	if target_ui_mode not in ["boke_round", "tsukkomi"]:
		target_ui_mode = "boke_round"
	if RoundView.automatic(command):  # combo lines open their slot at once
		target_ui_mode = "qte" if RoundView.action(command) == "qte" else "tsukkomi"
	close_qte()
	m._current_command = command.duplicate(true)
	m._current_speaker = RoundView.speaker(command)
	m._hide_story_parts()  # the round controls come back below
	m._game_over_retry_button.visible = false
	m._clear_choices()
	m._set_auto(false)
	m._set_skip(false)
	m._screen = DebtMain.Screen.BOKE_ROUND
	m._story_busy = false
	m._dialog_layer.visible = true
	m._dialog_panel.visible = true
	m._boke_controls.visible = not RoundView.automatic(command)
	m._tutorial_ctl.maybe_tutorial.call_deferred("boke_round")
	m._dialog_panel.set_reading_enabled(false)
	m._set_name_plate(m._current_speaker, false)
	m._focus_speaker(m._current_speaker, str(RoundView.line(command).get("expression", command.get("expression", "annoyed"))))
	m._layout()
	m._line_plan = DialogueText.compile(RoundView.text(command), m._text_interval(), m._text_label.get_theme_font_size("normal_font_size"))
	m._full_text = str(m._line_plan["plain"])
	m._set_text_tone("body")
	m._set_visible_text(m._full_text, true)
	_render_round_bar()
	var line_index: int = int(command.get("line_index", 0))
	m._current_line_key = "%s:%s:%s" % [m._line_key(command, "boke"), m._dict_string(RoundView.line(command), "id"), line_index]
	m._line_logged = m._history_has_key(m._current_line_key)
	var type_line: bool = bool((command.get("rules", {}) as Dictionary).get("type_lines", false)) and not m._line_logged \
		and (not restored or requested_ui_mode in ["", "boke_round"])
	if type_line:
		m._pending_round_mode = target_ui_mode if RoundView.automatic(command) else ""
		m._boke_time_remaining = 0.0
		m._set_visible_text("", false)
		m._typewriter(m._line_generation)
		m._refresh_phase3_hud()
		m._qa_ctl.publish_qa_state()
		return
	if not m._line_logged:
		m._append_history({"key": m._current_line_key, "kind": "say", "speaker": m._current_speaker, "text": m._full_text})
		m._line_logged = true
	match target_ui_mode:
		"tsukkomi":
			present_tsukkomi_options(command, restored)
		"qte":
			start_qte(command)
		_:
			m._boke_time_remaining = 0.0
			m._boke_timer_round_id = ""
			m._restored_boke_timer_remaining = -1.0
			m._restored_boke_ui_mode = ""
			m._screen = DebtMain.Screen.BOKE_ROUND
			m._current_options.clear()
	m._refresh_phase3_hud()
	m._qa_ctl.publish_qa_state()


## The round bar for _current_command (scripts/round_view.gd decides what it shows).
func _render_round_bar() -> void:
	var command: Dictionary = m._current_command
	var index: int = int(command.get("line_index", 0))
	var browse: bool = RoundView.navigable(command)
	m._boke_previous_button.visible = browse
	m._boke_next_button.visible = browse
	m._boke_previous_button.disabled = index <= 0
	m._boke_next_button.disabled = index >= (command.get("lines", []) as Array).size() - 1
	m._boke_line_label.text = RoundView.index_text(command)
	var heard: bool = RoundView.listened(command)
	m._boke_listen_button.visible = RoundView.can_listen(command)
	m._boke_listen_button.disabled = heard
	m._boke_listen_button.text = "已聽過" if heard else "聽下去"
	m._boke_tsukkomi_button.disabled = RoundView.action(command).is_empty()
	m._boke_tsukkomi_button.text = "已接住" if RoundView.caught(command) else m._term("rebut") + "！"
	m._dialog_panel.censor_bar.visible = RoundView.censor(command)


func present_tsukkomi_options(command: Dictionary, restored: bool) -> void:
	m._current_command = command.duplicate(true)
	var round_id: String = m._dict_string(command, "id")
	var timer_seconds: float = m._timer_total(command)
	if m._boke_timer_round_id != round_id:
		if restored and m._restored_boke_timer_remaining >= 0.0:
			m._boke_time_remaining = clampf(m._restored_boke_timer_remaining, 0.0, timer_seconds)
		else:
			m._boke_time_remaining = timer_seconds
		m._boke_timer_round_id = round_id
		last_display_second = -1
		m._restored_boke_timer_remaining = -1.0
	m._restored_boke_ui_mode = ""
	m._screen = DebtMain.Screen.TSUKKOMI
	m._boke_controls.visible = false
	m._current_options.clear()
	for option_variant: Variant in RoundView.options(command):
		if option_variant is Dictionary:
			m._current_options.append((option_variant as Dictionary).duplicate(true))
	m._sheet_prompt = m._full_text
	m._sheet_timed = true
	m._sheet_perspective = "pov"
	m._sheet_note = ""
	m._sheet_tones = PackedStringArray()
	m._sheet_censor = RoundView.censor(command)
	m._sheet_super = bool(command.get("super_available", false))
	m._show_choice_sheet()


func on_boke_tsukkomi_pressed() -> void:
	if m._screen != DebtMain.Screen.BOKE_ROUND or m._story_busy:
		return
	if not m._text_complete:
		m._complete_current_line()
		return
	match RoundView.action(m._current_command):
		"options":
			present_tsukkomi_options(m._current_command, false)
			m._saves.save_game()
			m._refresh_phase3_hud()
			m._qa_ctl.publish_qa_state()
		"qte":
			start_qte(m._current_command)
		"whiff":
			round_action(func() -> Dictionary: return m._runner.whiff_boke(), "（空揮）", "boke_round")


## Hands one round move to the runner and plays its outcome.
func round_action(move: Callable, label: String, prior_ui_mode: String, feedback: String = "") -> void:
	m._story_busy = true
	m._screen = DebtMain.Screen.BUSY
	_resolve_boke_presentation(move.call() as Dictionary, label, prior_ui_mode, feedback)


## The censor bar, torn off while reading (no timer) or while the options run.
func on_censor_pressed() -> void:
	if m._screen not in [DebtMain.Screen.BOKE_ROUND, DebtMain.Screen.TSUKKOMI] or m._story_busy or not RoundView.censor(m._current_command):
		return
	round_action(func() -> Dictionary: return m._runner.resolve_censor(), "（撕下消音條）", m._screen_mode)


## The placard, pointed at while reading (no timer) or while the options run; like the censor bar.
func on_placard_pressed() -> void:
	if not placard_open():
		return
	round_action(func() -> Dictionary: return m._runner.resolve_placard(), "（指著牌子）", m._screen_mode)


## The placard answers the current line: it is on stage, the round shows that line, nothing busy.
func placard_open() -> bool:
	if m._placard_holder == null or not m._placard_holder.visible or m._runner == null or m._story_busy:
		return false
	return m._screen in [DebtMain.Screen.BOKE_ROUND, DebtMain.Screen.TSUKKOMI] and bool((m._runner.placard_view() as Dictionary).get("tappable", false))


## The board on screen grown to at least 48 CSS px each way (like a hotspot), inside the game
## area and above the reading box or options sheet (a tap there belongs to them).
func placard_hit_rect() -> Rect2:
	var rect: Rect2 = m._placard_holder.call("placard_rect")
	var least: float = 48.0 * CSS_PX * m._panel_scale
	var grow: Vector2 = (Vector2(least, least) - rect.size).max(Vector2.ZERO) * 0.5
	rect = rect.grow_individual(grow.x, grow.y, grow.x, grow.y).intersection(Rect2(m._game.global_position, m._game.size))
	for panel: Control in [m._dialog_panel, m._choice_sheet]:
		var top: float = panel.get_global_rect().position.y
		if panel.is_visible_in_tree() and rect.end.y > top:
			rect.size.y = maxf(0.0, top - rect.position.y)
	return rect


## The runner decides what the placard says; it glows while its line is up on the timed sheet.
func refresh_placard() -> void:
	if m._placard_holder == null or m._runner == null or not m._story_ready:
		return
	var view: Dictionary = m._runner.placard_view() as Dictionary
	m._placard_holder.call("set_placard", str(view.get("text", "")),
		bool(view.get("tappable", false)) and m._screen == DebtMain.Screen.TSUKKOMI)
	if bool(view.get("tappable", false)) and m._placard_holder.visible:
		# While the board answers the line, its holder steps in front of the speaker, lit.
		m._char_layer.move_child(m._placard_holder, -1)
		m._placard_holder.modulate = Color.WHITE


func on_super_pressed() -> void:
	if m._screen != DebtMain.Screen.TSUKKOMI or m._story_busy or not bool(m._current_command.get("super_available", false)):
		return
	round_action(func() -> Dictionary: return m._runner.use_super(), m._words("{super}{rebut}"), "tsukkomi", m._words("{super}{rebut}！全部戳破"))


func start_qte(command: Dictionary) -> void:
	close_qte()
	m._screen = DebtMain.Screen.QTE
	m._qte = QTE_SCENE.instantiate() as QteRing
	m._overlay_layer.add_child(m._qte)
	m._qte.resolved.connect(_on_qte_resolved)
	m._qte.set_style(m._ui_style_id)
	m._qte.start(RoundView.qte(command))
	m._qa_ctl.publish_qa_state()


## tapped=false: the ring ran out. offset: seconds from the moment the rings met.
func _on_qte_resolved(tapped: bool, offset: float) -> void:
	if m._screen != DebtMain.Screen.QTE or m._story_busy:
		return
	close_qte()
	offset = judged_qte_offset(offset)
	m._last_qte_offset = offset
	round_action(func() -> Dictionary: return m._runner.resolve_qte(tapped, offset), "", "qte")


## The offset the runner judges: 吐槽輔助 寬鬆 widens the window by judging a proportionally smaller one.
func judged_qte_offset(offset: float) -> float:
	return offset / SETTINGS_SCRIPT.ASSIST_QTE_WINDOW_FACTOR if int(m._settings.get("assist", 0)) == 1 else offset


func close_qte() -> void:
	if m._qte != null and is_instance_valid(m._qte):
		m._qte.queue_free()
	m._qte = null


func on_boke_previous_pressed() -> void:
	set_boke_line(int(m._current_command.get("line_index", 0)) - 1)


func on_boke_next_pressed() -> void:
	set_boke_line(int(m._current_command.get("line_index", 0)) + 1)


func set_boke_line(index: int) -> void:
	if m._screen != DebtMain.Screen.BOKE_ROUND or m._story_busy:
		return
	if not bool(m._runner.set_boke_line(index)):
		return
	present_boke_round(m._runner_current(), true)
	m._saves.save_game()


func on_boke_listen_pressed() -> void:
	if m._screen != DebtMain.Screen.BOKE_ROUND or m._story_busy:
		return
	if not m._text_complete:
		m._complete_current_line()
		return
	if RoundView.is_v2(m._current_command):
		# The runner has jumped into the line's listen scene; play it, it leads back to the round.
		if bool(m._runner.listen_boke_line()):
			m._story_busy = true
			m._screen = DebtMain.Screen.BUSY
			m._start_drive()
		return
	if not bool(m._runner.listen_boke_line()):
		return
	var line: Dictionary = m._current_command.get("current_line", {}) as Dictionary
	var followup: String = m._dict_string(line, "listen")
	m._append_history({"key": m._current_line_key + ":listen", "kind": "say", "speaker": m._current_speaker, "text": followup})
	present_boke_round(m._runner_current(), true)
	m._saves.save_game()


func on_boke_option_pressed(option_id: String) -> void:
	if m._screen != DebtMain.Screen.TSUKKOMI or m._story_busy:
		return
	var option_label: String = option_id
	for option: Dictionary in m._current_options:
		if m._dict_string(option, "id") == option_id:
			option_label = m._dict_string(option, "label", option_id)
			break
	m._story_busy = true
	m._screen = DebtMain.Screen.BUSY
	var result: Dictionary = m._runner.resolve_boke(option_id) as Dictionary
	_resolve_boke_presentation(result, option_label, "tsukkomi", "", true)


func _resolve_boke_presentation(result: Dictionary, option_label: String = "", prior_ui_mode: String = "",
		feedback_override: String = "", show_comic: bool = false) -> void:
	if result.is_empty():
		m._story_busy = false
		present_boke_round(m._runner_current(), true, prior_ui_mode)
		return
	m._last_boke_result = m._dict_string(result, "result")
	m._boke_time_remaining = 0.0
	m._boke_timer_round_id = ""
	m._boke_controls.visible = false
	m._clear_choices()
	if not option_label.is_empty():
		m._append_history({"key": "%s:result:%s" % [m._current_line_key, m._last_boke_result], "kind": "choice", "text": option_label})
	var feedback: String = ""
	match m._last_boke_result:
		"perfect":
			feedback = m._words("完美{rebut}！{power} +30")
			m._effects.play_perfect_voice(int((m._runner.stats as Dictionary).get("perfect", 1)))
		"weak":
			feedback = m._words("普通{rebut}！{power} +10")
		"fail":
			feedback = m._words("{whiff}！{life} -1") if not bool(result.get("game_over", false)) else m._words("{life}耗盡・Game Over")
			var cause: String = str(MISS_CAUSE.get(m._dict_string(result, "action"), ""))
			if not cause.is_empty():
				feedback += "（%s）" % cause
		"hidden":
			feedback = m._words("放棄{rebut}・狀態不變")
	if not feedback_override.is_empty():
		feedback = feedback_override
	var moment: String = {"perfect": "perfect", "weak": "weak", "fail": "miss"}.get(m._last_boke_result, "")
	if moment == "miss" and bool(result.get("game_over", false)):
		moment = "game_over"
	m._effects.feedback(moment, m._skip)
	var power: int = int((m._runner.gameplay as Dictionary).get("power", 0))
	var maximum: int = int((m._runner.gameplay as Dictionary).get("max_power", 100))
	var filled_power: bool = power >= maximum and m._previous_power < maximum
	m._previous_power = power
	m._refresh_phase3_hud()
	if show_comic and not m._skip and m._last_boke_result in ["perfect", "weak"]:
		var line: String = option_label.strip_edges()
		if line.begins_with("吐槽："):
			line = line.trim_prefix("吐槽：").strip_edges()
		elif line.contains("反駁："):
			line = line.substr(line.find("反駁：") + "反駁：".length()).strip_edges()
		if not line.is_empty():
			var generation: int = m._generation
			m._recent_retort = line
			await m._play_manga_retort(line, m._default_pov(), generation)
			if generation != m._generation:
				return
	if filled_power:
		m._effects.feedback("power_full", m._skip)
		m._effects.play({"op": "cutin", "text": m._words("{power}全滿！"), "speaker": m._default_pov()}, m._skip)
		m._effects.play({"op": "se", "id": "power_up"}, m._skip)
	m._show_toast(feedback)
	m._start_drive()


func on_boke_timeout() -> void:
	if m._screen != DebtMain.Screen.TSUKKOMI or m._story_busy:
		return
	m._story_busy = true
	m._screen = DebtMain.Screen.BUSY
	var result: Dictionary = m._runner.timeout_boke() as Dictionary
	_resolve_boke_presentation(result, "", "tsukkomi")


func on_game_over_retry_pressed() -> void:
	if not m._phase3_enabled or m._runner == null or m._story_busy:
		return
	if not bool(m._runner.retry_checkpoint()):
		m._show_toast(m._runner_string("error_message", "目前沒有可重試的檢查點。"))
		return
	m._cancel_generation()
	m._rollback.clear()
	m._boke_timer_round_id = ""
	m._boke_time_remaining = 0.0
	m._restored_boke_timer_remaining = -1.0
	m._restored_boke_ui_mode = ""
	m._previous_power = int((m._runner.gameplay as Dictionary).get("power", 0))
	m._last_boke_result = "retry"
	var snapshot: Dictionary = m._runner.snapshot()
	var retry_round: String = str((snapshot.get("checkpoint",{}) as Dictionary).get("round_id",""))
	var stage: Dictionary = m._round_stages.get(retry_round,{})
	if not stage.is_empty():
		m._apply_background(str(stage["background"]))
		for actor: String in m._sprites.keys():
			var state: Dictionary = stage["sprites"].get(actor,{})
			m._actor_slots[actor] = str(state.get("position","center"))
			(m._sprites[actor] as Control).visible = bool(state.get("visible",false))
			m._sprites[actor].set_meta("portrait_lighting", state.get("lighting", "auto"))
			m._sprites[actor].set_meta("entrance_transition", state.get("entrance_transition", "fade"))
			m._sprites[actor].call("set_expression",str(state.get("expression","neutral")))
			m._layout_sprite(actor)
		m._effects.play_bgm(str(stage.get("bgm","")))
	m._story_busy = false
	m._screen = DebtMain.Screen.BUSY
	m._game_over.visible = false
	m._render_restored_current()
	m._refresh_phase3_hud()
	m._saves.save_game()
	m._qa_ctl.publish_qa_state()
