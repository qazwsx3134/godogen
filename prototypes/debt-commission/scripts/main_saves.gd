extends RefCounted

## main.gd 的存讀檔：自動／快速／手動欄位、存檔內容的建立與驗證、讀檔還原、欄位選擇面板與存檔備份。

const StoryRunner = preload("res://scripts/story_runner.gd")
const SETTINGS_SCRIPT: Script = preload("res://scripts/settings.gd")
const SAVE_TRANSFER: Script = preload("res://scripts/save_transfer.gd")
const STORY_LIBRARY: Script = preload("res://scripts/story_library.gd")
const ATOMIC_FILE: Script = preload("res://addons/proto_kit/atomic_file.gd")
const SAVE_SLOTS_SCRIPT: Script = preload("res://scripts/save_slots.gd")
const SAVE_SCHEMA: int = 3
const STORY_CHOICE_PATH: String = "user://story_choice.cfg"
const DEFAULT_BOKE_TIMER_SECONDS: float = 8.0

var m: DebtMain


func _init(main: DebtMain) -> void:
	m = main


## Every file a backup holds: each story's saves, progress, settings and the UI choices.
func backup_paths() -> Array[String]:
	return SAVE_TRANSFER.backup_paths(m._story_choices, [m.progress_path, m.settings_path, STORY_CHOICE_PATH])


## 匯出存檔: the Web build downloads the backup; a desktop build asks where to write it.
func export_saves() -> void:
	var now: String = Time.get_datetime_string_from_system()
	var text: String = SAVE_TRANSFER.export_text(backup_paths(), now)
	var file_name: String = "debt-commission-saves-%s.json" % now.replace(":", "").replace("T", "-")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		m._show_toast("已下載存檔備份")
		return
	_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, file_name, func(path: String) -> void:
		m._show_toast("已匯出存檔備份" if ATOMIC_FILE.write_text(path, text) == OK else "存檔備份寫入失敗"))


## 匯入存檔 (from the title only): the player picks a backup file, which replaces every save.
func import_saves() -> void:
	if m._screen != DebtMain.Screen.SETTINGS or m._settings_return != DebtMain.Screen.TITLE:
		return
	if OS.has_feature("web"):
		_pick_web_backup()
		return
	_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "", func(path: String) -> void:
		import_backup_text(FileAccess.get_file_as_string(path)))


## Checks a backup and, when it is good, replaces the saves with it and starts again from the
## title. A bad file changes nothing and says why.
func import_backup_text(text: String) -> bool:
	var allowed: Array[String] = backup_paths()
	var parsed: Dictionary = SAVE_TRANSFER.parse_import(text, allowed)
	var error: String = str(parsed["error"])
	if error.is_empty():
		error = SAVE_TRANSFER.apply_import(parsed["files"], allowed)
	if not error.is_empty():
		m._show_toast(error)
		return false
	_reload_after_import()
	return true


func _reload_after_import() -> void:
	if m.get_tree().current_scene == m:
		m.get_tree().reload_current_scene.call_deferred()
		return
	# Main inside another scene (tests): read the imported settings, progress and saves back in place.
	m._settings = SETTINGS_SCRIPT.load_settings(m.settings_path)
	m._library = STORY_LIBRARY.new(m.stories_path, m.progress_path, m.packs_root)
	m._story_choices = m._library.stories
	m._close_settings()
	m._refresh_title()
	m._show_toast("已匯入存檔")


## The browser's file picker; its text comes back through a JavaScript callback.
func _pick_web_backup() -> void:
	m._web_backup_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
		import_backup_text(str(args[0]) if not args.is_empty() else ""))
	JavaScriptBridge.get_interface("window").debtImportBackup = m._web_backup_callback
	JavaScriptBridge.eval("""(() => {
		const input = document.createElement('input');
		input.type = 'file';
		input.accept = '.json,application/json';
		input.addEventListener('change', () => {
			const file = input.files && input.files[0];
			if (file) file.text().then(text => window.debtImportBackup(text), () => window.debtImportBackup(''));
		});
		input.click();
	})()""", true)


func _file_dialog(mode: FileDialog.FileMode, file_name: String, done: Callable) -> void:
	var dialog: FileDialog = FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.json ; 存檔備份"])
	dialog.current_file = file_name
	dialog.file_selected.connect(func(path: String) -> void:
		dialog.queue_free()
		done.call(path))
	dialog.canceled.connect(dialog.queue_free)
	m.add_child(dialog)
	dialog.popup_centered_ratio(0.8)


func build_slot_picker() -> void:
	m._slot_overlay = preload("res://scenes/ui/save_slots_panel.tscn").instantiate()
	m._game.add_child(m._slot_overlay)
	m._slot_overlay.visible = false
	m._slot_panel = m._slot_overlay.get_node("%SlotPanel")
	m._slot_title = m._slot_overlay.get_node("%SlotTitle")
	m._slot_page_label = m._slot_overlay.get_node("%SlotPage")
	m._slot_close_button = m._slot_overlay.get_node("%SlotClose")
	m._slot_prev_button = m._slot_overlay.get_node("%SlotPrev")
	m._slot_next_button = m._slot_overlay.get_node("%SlotNext")
	m._slot_auto_button = m._slot_overlay.get_node("%SlotAuto")
	m._slot_close_button.pressed.connect(close_slot_picker)
	m._slot_prev_button.pressed.connect(func() -> void: _change_slot_page(-1))
	m._slot_next_button.pressed.connect(func() -> void: _change_slot_page(1))
	m._slot_auto_button.pressed.connect(_load_autosave_from_picker)
	m._slot_overlay.get_node("%SlotDim").gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_slot_picker())
	for local_index in SAVE_SLOTS_SCRIPT.PAGE_SIZE:
		var card: Button = m._slot_overlay.get_node("%Cards").get_child(local_index)
		card.pressed.connect(on_slot_card_pressed.bind(local_index))
		m._slot_card_buttons.append(card)
		m._slot_card_numbers.append(card.get_node("%Number"))
		m._slot_card_titles.append(card.get_node("%SlotTitle"))
		m._slot_card_times.append(card.get_node("%SavedTime"))
		m._slot_card_previews.append(card.get_node("%Preview"))
	m._slot_confirmation_overlay = m._slot_overlay.get_node("SlotConfirmationOverlay")
	m._slot_confirmation_overlay.visible = false
	m._slot_confirmation_panel = m._slot_confirmation_overlay.get_node("%ConfirmationPanel")
	m._slot_confirmation_label = m._slot_confirmation_overlay.get_node("%Question")
	m._slot_confirm_yes = m._slot_confirmation_overlay.get_node("%SlotConfirmYes")
	m._slot_confirm_no = m._slot_confirmation_overlay.get_node("%SlotConfirmNo")
	m._slot_confirm_yes.pressed.connect(confirm_slot_overwrite)
	m._slot_confirm_no.pressed.connect(cancel_slot_confirmation)
	m._slot_confirmation_overlay.get_node("%Dim").gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.is_pressed() and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			cancel_slot_confirmation())


func layout_slot_picker(width: float, height: float, top: float, bottom: float) -> void:
	if m._slot_overlay != null:
		m._fit_panel_area(m._slot_overlay, Rect2(0.0,top,width,bottom-top))


func _load_from_menu() -> void:
	open_slot_picker("load")


func open_slot_picker(mode: String) -> void:
	if mode not in ["save", "load"]:
		return
	var return_screen: DebtMain.Screen = m._screen
	if return_screen == DebtMain.Screen.MENU:
		m._slot_return_screen = "menu"
		return_screen = m._mode_before_overlay
		m._menu_overlay.visible = false
	elif return_screen not in [DebtMain.Screen.TITLE, DebtMain.Screen.STORY, DebtMain.Screen.CHOICE, DebtMain.Screen.END, DebtMain.Screen.INVESTIGATE, DebtMain.Screen.BOKE_ROUND, DebtMain.Screen.TSUKKOMI]:
		return
	else:
		m._slot_return_screen = DebtMain.screen_name(return_screen)
	if mode == "save" and return_screen not in [DebtMain.Screen.STORY, DebtMain.Screen.CHOICE, DebtMain.Screen.END, DebtMain.Screen.INVESTIGATE, DebtMain.Screen.BOKE_ROUND, DebtMain.Screen.TSUKKOMI]:
		return
	m._mode_before_overlay = return_screen
	m._slot_typewriter_paused = return_screen == DebtMain.Screen.STORY and not m._text_complete
	if m._slot_typewriter_paused:
		m._line_generation += 1
	m._slot_mode = mode
	m._slot_page = 0
	m._slot_pending_index = -1
	m._slot_confirmation_overlay.visible = false
	m._slot_title.text = "選擇存檔位" if mode == "save" else "選擇讀取存檔"
	m._screen = DebtMain.Screen.SAVE_SLOTS if mode == "save" else DebtMain.Screen.LOAD_SLOTS
	m._refresh_phase3_hud()
	await m.get_tree().process_frame
	m._slot_preview_png = _capture_preview_png()
	m._slot_overlay.visible = true
	_refresh_slot_page()
	m._qa_ctl.publish_qa_state()


func _change_slot_page(delta: int) -> void:
	m._slot_page = clampi(m._slot_page + delta, 0, SAVE_SLOTS_SCRIPT.PAGE_COUNT - 1)
	_refresh_slot_page()
	m._qa_ctl.publish_qa_state()


func _refresh_slot_page() -> void:
	if m._slot_panel == null:
		return
	m._slot_visible_entries.clear()
	m._slot_page_label.text = "%d / %d" % [m._slot_page + 1, SAVE_SLOTS_SCRIPT.PAGE_COUNT]
	m._slot_prev_button.disabled = m._slot_page <= 0
	m._slot_next_button.disabled = m._slot_page >= SAVE_SLOTS_SCRIPT.PAGE_COUNT - 1
	var can_save: bool = saveable_current_state()
	var autosave: Dictionary = read_save_payload(m.save_path)
	m._slot_auto_button.visible = m._slot_mode == "load" and not autosave.is_empty()
	m._slot_auto_button.disabled = autosave.is_empty()
	for local_index: int in range(m._slot_card_buttons.size()):
		var slot_index: int = m._slot_page * SAVE_SLOTS_SCRIPT.PAGE_SIZE + local_index + 1
		var path: String = SAVE_SLOTS_SCRIPT.manual_path(m.save_path, slot_index)
		var occupied: bool = _slot_file_exists(path)
		var payload: Dictionary = read_save_payload(path)
		var valid: bool = not payload.is_empty()
		var chapter: String = str(payload.get("chapter", payload.get("node_id", ""))) if valid else ""
		var saved_at: String = _payload_saved_time(payload, path) if valid else ""
		m._slot_visible_entries.append({"index": slot_index, "occupied": occupied, "valid": valid,
			"chapter": chapter, "saved_at": saved_at})
		var button: Button = m._slot_card_buttons[local_index]
		var number_label: Label = m._slot_card_numbers[local_index]
		var title_label: Label = m._slot_card_titles[local_index]
		var time_label: Label = m._slot_card_times[local_index]
		var preview: TextureRect = m._slot_card_previews[local_index]
		button.disabled = m._slot_mode == "load" and not valid or m._slot_mode == "save" and not can_save
		number_label.text = "%02d" % slot_index
		if valid:
			chapter = str(payload.get("chapter", payload.get("node_id", "存檔")))
			var node_id: String = str(payload.get("node_id", ""))
			title_label.text = chapter if node_id.is_empty() or node_id == chapter else "%s\n%s" % [chapter, node_id]
			time_label.text = saved_at
			preview.texture = _decode_preview(str(payload.get("preview_png", "")))
			preview.visible = preview.texture != null
		else:
			preview.texture = null
			preview.visible = false  # an empty slot's text starts at the card's edge
			time_label.text = ""
			if occupied:
				var snapshot: Dictionary = m._runner.snapshot() as Dictionary
				var older: bool = not m._other_version_of(read_raw_save_payload(path), str(snapshot.get("story_id", "")),
					str(snapshot.get("version", ""))).is_empty()
				if m._slot_mode == "load":
					title_label.text = "舊版劇本的存檔（無法讀取）" if older else "資料無效或不相容"
				else:
					title_label.text = "舊版劇本的存檔・確認後覆寫" if older else "無效資料・確認後覆寫"
			else:
				title_label.text = "空白存檔位" if m._slot_mode == "save" else "尚無存檔"
		var card_role: String = "slot_card" if valid else ("slot_card_invalid" if occupied else "slot_card_empty")
		m._set_button_style(button, card_role)
		button.visible = true


func on_slot_card_pressed(local_index: int) -> void:
	if local_index < 0 or local_index >= SAVE_SLOTS_SCRIPT.PAGE_SIZE:
		return
	var slot_index: int = m._slot_page * SAVE_SLOTS_SCRIPT.PAGE_SIZE + local_index + 1
	var path: String = SAVE_SLOTS_SCRIPT.manual_path(m.save_path, slot_index)
	if m._slot_mode == "save":
		if not saveable_current_state():
			return
		if _slot_file_exists(path):
			m._slot_pending_index = slot_index
			m._slot_confirmation_label.text = "覆寫第 %02d 格的存檔？" % slot_index
			m._slot_confirmation_overlay.visible = true
			m._screen = DebtMain.Screen.SLOT_CONFIRM
			m._qa_ctl.publish_qa_state()
		else:
			_write_manual_slot(slot_index)
		return
	if m._slot_mode == "load":
		var payload: Dictionary = read_save_payload(path)
		if not payload.is_empty():
			load_payload_from_picker(payload, "已讀取第 %02d 格" % slot_index)


func confirm_slot_overwrite() -> void:
	if m._slot_pending_index < 1:
		return
	var selected_index: int = m._slot_pending_index
	m._slot_confirmation_overlay.visible = false
	m._slot_pending_index = -1
	_write_manual_slot(selected_index)


func cancel_slot_confirmation() -> void:
	if not m._slot_confirmation_overlay.visible:
		return
	m._slot_confirmation_overlay.visible = false
	m._slot_pending_index = -1
	m._screen = DebtMain.Screen.SAVE_SLOTS
	m._qa_ctl.publish_qa_state()


func _write_manual_slot(slot_index: int) -> void:
	var path: String = SAVE_SLOTS_SCRIPT.manual_path(m.save_path, slot_index)
	var payload: Dictionary = build_save_payload(m._slot_preview_png)
	if payload.is_empty() or not bool(SAVE_SLOTS_SCRIPT.write_atomic(path, payload, validate_save_payload)):
		m._show_toast("存檔失敗，原有資料已保留")
		_refresh_slot_page()
		m._qa_ctl.publish_qa_state()
		return
	close_slot_picker()
	m._show_toast("已存到第 %02d 格" % slot_index)


func _load_autosave_from_picker() -> void:
	var payload: Dictionary = read_save_payload(m.save_path)
	if not payload.is_empty():
		load_payload_from_picker(payload, "已讀取自動存檔")


func load_payload_from_picker(payload: Dictionary, message: String) -> void:
	if not validate_save_payload(payload):
		return
	m._cancel_generation()
	m._set_auto(false)
	m._set_skip(false)
	if not apply_save_payload(payload):
		return
	close_slot_picker(false)
	m._set_ui_hidden(false)
	m._show_story_screen()
	m._render_restored_current()
	m._show_toast(message if save_game() else "已讀檔，但續讀存檔更新失敗")


func close_slot_picker(resume_story: bool = true) -> void:
	if m._slot_overlay == null or not m._slot_overlay.visible:
		return
	m._slot_overlay.visible = false
	m._slot_confirmation_overlay.visible = false
	m._slot_pending_index = -1
	m._slot_mode = ""
	var return_to_menu: bool = resume_story and m._slot_return_screen == "menu"
	m._screen = DebtMain.Screen.MENU if return_to_menu else m._mode_before_overlay
	m._menu_overlay.visible = return_to_menu
	m._refresh_phase3_hud()
	if resume_story and m._mode_before_overlay == DebtMain.Screen.STORY:
		if m._slot_typewriter_paused and not m._text_complete:
			m._typewriter(m._line_generation)
		elif not return_to_menu and m._skip:
			m._skip_step(m._line_generation)
		elif not return_to_menu and m._auto:
			m._auto_step(m._line_generation)
	m._slot_typewriter_paused = false
	m._slot_return_screen = ""
	m._qa_ctl.publish_qa_state()


func rollback_line() -> bool:
	var mode: DebtMain.Screen = m._mode_before_overlay if m._screen == DebtMain.Screen.MENU else m._screen
	if mode != DebtMain.Screen.STORY or not m._rollback.available():
		return false
	var payload: Dictionary = m._rollback.take()
	m._rolling_back = true
	var restored: bool = apply_save_payload(payload)
	m._rolling_back = false
	if not restored:
		return false
	m._set_auto(false)
	m._set_skip(false)
	m._close_overlays()
	m._show_story_screen()
	m._render_restored_current()
	save_game()
	m._show_toast("已回到上一句")
	return true


func quick_save() -> bool:
	if not saveable_current_state():
		return false
	var payload: Dictionary = build_save_payload("")
	var written: bool = SAVE_SLOTS_SCRIPT.write_atomic(SAVE_SLOTS_SCRIPT.quick_path(m.save_path), payload, validate_save_payload)
	m._show_toast("已快速存檔" if written else "快速存檔失敗，原有資料已保留")
	m._refresh_menu_rows()
	return written


func quick_load() -> bool:
	var payload: Dictionary = read_save_payload(SAVE_SLOTS_SCRIPT.quick_path(m.save_path))
	if payload.is_empty() or not apply_save_payload(payload):
		m._show_toast("尚無可讀取的快速存檔")
		return false
	m._set_auto(false)
	m._set_skip(false)
	m._close_overlays()
	m._set_ui_hidden(false)
	m._show_story_screen()
	m._render_restored_current()
	save_game()
	m._show_toast("已快速讀檔")
	return true


func save_game() -> bool:
	if not saveable_current_state():
		return false
	var payload: Dictionary = build_save_payload("")
	return not payload.is_empty() and bool(SAVE_SLOTS_SCRIPT.write_atomic(m.save_path, payload, validate_save_payload))


func saveable_current_state() -> bool:
	return m._runner != null and not m._story_busy and m._command_op(m._runner_current()) in [
		"say", "choice", "end", "result", "investigate", "boke_round"]


func build_save_payload(preview_png: String) -> Dictionary:
	var runner_snapshot: Dictionary = m._runner.snapshot() as Dictionary
	if runner_snapshot.is_empty():
		return {}
	var sprites: Dictionary = {}
	for actor_id: String in m._sprites.keys():
		var sprite: Control = m._sprites[actor_id] as Control
		# A fading exit is already absent in the story, even while its last frames are visible.
		var on_stage: bool = sprite.visible and m._motion.character_kind(sprite) != "leave"
		sprites[actor_id] = {"visible": on_stage, "expression": str(sprite.get("expression")),
			"position": str(m._actor_slots.get(actor_id, "center")),
			"lighting": str(sprite.get_meta("portrait_lighting", "auto")),
			"entrance_transition": str(sprite.get_meta("entrance_transition", "fade"))}
	var current: Dictionary = m._runner_current()
	var payload: Dictionary = {
		"schema": SAVE_SCHEMA,
		"version": SAVE_SCHEMA,
		"story_id": str(runner_snapshot.get("story_id", "")),
		"runner": runner_snapshot,
		"background": m._current_bg_id,
		"sprites": sprites,
		"history": m._history.duplicate(true),
		"chapter": str(current.get("node_title", current.get("node_id", ""))),
		"node_id": str(runner_snapshot.get("node_id", "")),
		"saved_at": Time.get_datetime_string_from_system(false, false),
		"preview_png": preview_png,
		"bgm": m._effects.current_bgm,
		"round_stages": m._round_stages.duplicate(true),
		"investigation_pans": m._investigation_pans.duplicate(true),
		"investigation_pans_y": m._investigation_pans_y.duplicate(true),
		"investigation_home_casts": m._investigation_home_casts.duplicate(true),
	}
	if m._command_op(current) == "boke_round":
		var boke_ui_mode: String = effective_boke_ui_mode()
		if boke_ui_mode not in ["boke_round", "tsukkomi"]:
			boke_ui_mode = "boke_round"  # a QTE restarts when its line comes back
		payload["boke_ui_screen"] = boke_ui_mode
		if boke_ui_mode == "tsukkomi":
			payload["boke_timer_remaining"] = m._boke_time_remaining
	return payload


func effective_boke_ui_mode() -> String:
	if m._screen in [DebtMain.Screen.MENU, DebtMain.Screen.LOG, DebtMain.Screen.SAVE_SLOTS, DebtMain.Screen.LOAD_SLOTS, DebtMain.Screen.SLOT_CONFIRM]:
		return DebtMain.screen_name(m._mode_before_overlay)
	return m._screen_mode


func read_save_payload(path: String = "") -> Dictionary:
	var target_path: String = m.save_path if path.is_empty() else path
	for candidate_path: String in [target_path, target_path + ".bak", target_path + ".bak.old",
		target_path + ".old", target_path + ".tmp"]:
		var payload: Dictionary = read_raw_save_payload(candidate_path)
		if not payload.is_empty() and validate_save_payload(payload):
			return payload
	return {}


func read_raw_save_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = file.get_var(false)
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _valid_saved_cast(cast: Variant) -> bool:
	if not cast is Dictionary:
		return false
	for actor_id: String in m._actors:
		var pose: Variant = cast.get(actor_id)
		if not pose is Dictionary or not pose.get("visible") is bool or not m._slot_markers.has(str(pose.get("position", ""))) or typeof(pose.get("expression", "")) != TYPE_STRING:
			return false
		if pose.get("lighting", "auto") not in ["dim", "lit", "auto"] or pose.get("entrance_transition", "fade") not in StoryRunner.VALID_CHARACTER_TRANSITIONS:
			return false
	return true


func validate_save_payload(payload: Dictionary) -> bool:
	# Schema 3 saves written before background/position/thumbnail metadata are
	# migrated by supplying the same defaults the scene uses for a new game.
	var schema: int = int(payload.get("schema", payload.get("version", -1)))
	var version: int = int(payload.get("version", schema))
	if schema != SAVE_SCHEMA or version > SAVE_SCHEMA or version < 1:
		return false
	var runner_snapshot: Variant = payload.get("runner")
	var sprites: Variant = payload.get("sprites")
	var history: Variant = payload.get("history")
	if not runner_snapshot is Dictionary or not sprites is Dictionary or not history is Array:
		return false
	if m._runner == null:
		return false
	var current_snapshot: Dictionary = m._runner.snapshot() as Dictionary
	var story_id: String = str(current_snapshot.get("story_id", ""))
	if str(payload.get("story_id", str((runner_snapshot as Dictionary).get("story_id", "")))) != story_id:
		return false
	if str((runner_snapshot as Dictionary).get("story_id", "")) != story_id:
		return false
	var background_id: String = str(payload.get("background", m._default_background_id()))
	if not m._backgrounds.has(background_id):
		return false
	for actor_id: String in m._actors.keys():
		var state: Variant = (sprites as Dictionary).get(actor_id)
		if not state is Dictionary or not (state as Dictionary).get("visible") is bool:
			return false
		var default_position: String = str((m._actors[actor_id] as Dictionary).get("slot", "center"))
		if not m._slot_markers.has(str((state as Dictionary).get("position", default_position))):
			return false
		if typeof((state as Dictionary).get("expression", "neutral")) != TYPE_STRING:
			return false
		if state.get("lighting", "auto") not in ["dim", "lit", "auto"] or state.get("entrance_transition", "fade") not in StoryRunner.VALID_CHARACTER_TRANSITIONS:
			return false
	for entry: Variant in history as Array:
		if not entry is Dictionary:
			return false
	if payload.has("saved_at") and typeof(payload["saved_at"]) != TYPE_STRING:
		return false
	if payload.has("preview_png") and typeof(payload["preview_png"]) != TYPE_STRING:
		return false
	if payload.has("bgm") and typeof(payload["bgm"]) != TYPE_STRING:
		return false
	if payload.has("boke_timer_remaining"):
		var remaining: Variant = payload["boke_timer_remaining"]
		if (typeof(remaining) != TYPE_INT and typeof(remaining) != TYPE_FLOAT) or float(remaining) < 0.0:
			return false
	if payload.has("boke_ui_screen"):
		if typeof(payload["boke_ui_screen"]) != TYPE_STRING or str(payload["boke_ui_screen"]) not in ["boke_round", "tsukkomi"]:
			return false
	# Save validation uses independent mutable state, sharing the loaded story definition.
	for key: String in ["round_stages", "investigation_pans", "investigation_pans_y", "investigation_home_casts"]:
		if not payload.get(key, {}) is Dictionary:
			return false
	for key: String in ["investigation_pans", "investigation_pans_y"]:
		for pan: Variant in (payload.get(key, {}) as Dictionary).values():
			if typeof(pan) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(pan)):
				return false
	for stage: Variant in (payload.get("round_stages", {}) as Dictionary).values():
		if not stage is Dictionary or not m._backgrounds.has(str(stage.get("background", ""))) or typeof(stage.get("bgm", "")) != TYPE_STRING or not _valid_saved_cast(stage.get("sprites")):
			return false
	for cast: Variant in (payload.get("investigation_home_casts", {}) as Dictionary).values():
		if not _valid_saved_cast(cast):
			return false
	if m._save_validation_probe == null:
		m._save_validation_probe = m._runner.create_validation_probe() as RefCounted
	var probe: RefCounted = m._save_validation_probe
	if probe == null or not bool(probe.call("restore", runner_snapshot)):
		return false
	var probe_current: Dictionary = probe.call("current") as Dictionary
	var probe_op: String = m._command_op(probe_current)
	if payload.has("boke_ui_screen") or payload.has("boke_timer_remaining"):
		if probe_op != "boke_round":
			return false
		var saved_boke_ui_mode: String = str(payload.get("boke_ui_screen",
			"tsukkomi" if payload.has("boke_timer_remaining") else "boke_round"))
		if payload.has("boke_timer_remaining") and saved_boke_ui_mode != "tsukkomi":
			return false
	if payload.has("boke_timer_remaining"):
		# Saved with 吐槽輔助 寬鬆 the clock can hold more than the step's seconds; restore clamps it.
		var max_remaining: float = float(probe_current.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)) * \
			SETTINGS_SCRIPT.ASSIST_TIMER_FACTOR
		if float(payload["boke_timer_remaining"]) > max_remaining:
			return false
	return true


func has_valid_save() -> bool:
	return not read_save_payload().is_empty()


func apply_save_payload(payload: Dictionary) -> bool:
	if m._phase3_hud != null:
		m._phase3_hud.reset_pops()
	if not validate_save_payload(payload) or not bool(m._runner.restore(payload["runner"])):
		return false
	m._cancel_generation()
	if not m._rolling_back:
		m._rollback.clear()
	var restored_current: Dictionary = m._runner_current()
	if m._command_op(restored_current) == "boke_round":
		m._restored_boke_ui_mode = str(payload.get("boke_ui_screen",
			"tsukkomi" if payload.has("boke_timer_remaining") else "boke_round"))
		if m._restored_boke_ui_mode == "tsukkomi":
			m._restored_boke_timer_remaining = float(payload.get("boke_timer_remaining",
				restored_current.get("timer_seconds", DEFAULT_BOKE_TIMER_SECONDS)))
		else:
			m._restored_boke_timer_remaining = -1.0
		m._boke_timer_round_id = ""
		m._boke_time_remaining = maxf(0.0, m._restored_boke_timer_remaining)
	else:
		m._restored_boke_timer_remaining = -1.0
		m._restored_boke_ui_mode = ""
		m._boke_timer_round_id = ""
		m._boke_time_remaining = 0.0
	m._apply_background(str(payload.get("background", m._default_background_id())))
	m._investigation.forget_search_cast()
	var sprites: Dictionary = payload["sprites"]
	for actor_id: String in m._sprites.keys():
		var state: Dictionary = sprites.get(actor_id, {"visible": false}) as Dictionary
		var sprite: Control = m._sprites[actor_id]
		var default_position: String = str((m._actors[actor_id] as Dictionary).get("slot", "center"))
		m._actor_slots[actor_id] = str(state.get("position", default_position))
		sprite.visible = bool(state.get("visible", false))
		sprite.set_meta("portrait_lighting", state.get("lighting", "auto"))
		sprite.set_meta("entrance_transition", state.get("entrance_transition", "fade"))
		sprite.modulate = m._portrait_color(sprite, true)
		sprite.call("set_expression", str(state.get("expression", "neutral")))
		m._layout_sprite(actor_id)
	m._previous_power = int((m._runner.gameplay as Dictionary).get("power", 0))
	m._round_stages = (payload.get("round_stages",{}) as Dictionary).duplicate(true)
	m._investigation_pans = (payload.get("investigation_pans",{}) as Dictionary).duplicate(true)
	m._investigation_pans_y = (payload.get("investigation_pans_y",{}) as Dictionary).duplicate(true)
	m._investigation_home_casts = (payload.get("investigation_home_casts",{}) as Dictionary).duplicate(true)
	m._history.clear()
	for entry: Variant in payload["history"]:
		m._history.append((entry as Dictionary).duplicate(true))
	m._effects.play_bgm(str(payload.get("bgm", "")))  # saves before music existed have none
	return true


func delete_save() -> void:
	for path: String in [m.save_path, m.save_path + ".bak", m.save_path + ".bak.old", m.save_path + ".old",
		m.save_path + ".tmp", m.save_path + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _capture_preview_png() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var viewport_texture: ViewportTexture = m.get_viewport().get_texture()
	if viewport_texture == null:
		return ""
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		return ""
	image.resize(135, 240, Image.INTERPOLATE_LANCZOS)
	var png: PackedByteArray = image.save_png_to_buffer()
	return Marshalls.raw_to_base64(png) if not png.is_empty() else ""


func _decode_preview(encoded: String) -> Texture2D:
	if encoded.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _payload_saved_time(payload: Dictionary, path: String) -> String:
	var saved_at: String = str(payload.get("saved_at", ""))
	if not saved_at.is_empty():
		var date_time: PackedStringArray = saved_at.replace("T", " ").split(" ")
		if date_time.size() >= 2 and date_time[0].length() >= 10:
			return "%s %s" % [date_time[0].substr(5, 5), date_time[1].substr(0, 5)]
		return saved_at.replace("T", " ")
	if FileAccess.file_exists(path):
		return "較早的存檔"
	if FileAccess.file_exists(path + ".bak"):
		return "備份存檔"
	return "較早的存檔"


func _slot_file_exists(path: String) -> bool:
	for candidate: String in [path, path + ".bak", path + ".bak.old", path + ".old", path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			return true
	return false
