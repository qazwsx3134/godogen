extends Control

const Session = preload("res://scripts/game_session.gd")
const Room = preload("res://ui/room_view.gd")
const Icon = preload("res://ui/pixel_icon.gd")
const Meter = preload("res://ui/timing_meter.gd")
const Sound = preload("res://ui/sound.gd")
const Model = preload("res://domain/pet_model.gd")
const Care = preload("res://domain/care_service.gd")
const Battle = preload("res://domain/battle_service.gd")

const INK: Color = Color("344c43")
const MUTED: Color = Color("65715f")
const CREAM: Color = Color("f4efdf")
const GREEN: Color = Color("607b58")
const ORANGE: Color = Color("b97755")
const SPECIES: Dictionary = {"sprout": "芽芽", "bloom": "葉角獸", "ember": "暖焰獸", "moss": "苔甲獸", "breeze": "風耳獸"}
const TRAIN_NAMES: Dictionary = {"power": "力量", "guard": "防禦", "swift": "敏捷"}

var session: Node
var sound: Node
var room: Control
var pet_name: Label
var stage_label: Label
var room_caption: Label
var toast: Label
var need_labels: Dictionary = {}
var need_bars: Dictionary = {}
var health_line: Label
var hatch_bar: ProgressBar
var hatch_label: Label
var status_panel: VBoxContainer
var egg_panel: VBoxContainer
var overlay: Control
var modal_content: VBoxContainer
var modal_title: Label
var modal_panel: PanelContainer
var day_label: Label
var footer_label: Label
var last_modal: String = ""
var training_active: bool = false
var battle_playing: bool = false
var modal_generation: int = 0
var safe_margin: MarginContainer
var heading_font: FontVariation

func _ready() -> void:
	_theme()
	sound = Sound.new()
	add_child(sound)
	session = Session.new()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--save-path="):
			session.save_path = argument.trim_prefix("--save-path=")
	add_child(session)
	_build_home()
	session.changed.connect(_refresh)
	session.feedback.connect(_feedback)
	session.milestone.connect(_milestone)
	_refresh()
	get_viewport().size_changed.connect(_safe_area)
	_safe_area()
	if not session.state.get("pending_battle", {}).is_empty() and not session.state.pending_battle.get("settled", true):
		call_deferred("_battle_report")

func _theme() -> void:
	var game_theme := Theme.new()
	var body_font := FontVariation.new()
	body_font.base_font = preload("res://assets/fonts/NotoSansTC.ttf")
	body_font.variation_opentype = {2003265652: 450.0}
	heading_font = FontVariation.new()
	heading_font.base_font = body_font.base_font
	heading_font.variation_opentype = {2003265652: 650.0}
	game_theme.default_font = body_font
	game_theme.default_font_size = 17
	game_theme.set_color("font_color", "Label", INK)
	game_theme.set_color("font_color", "Button", INK)
	game_theme.set_color("font_hover_color", "Button", INK)
	game_theme.set_color("font_pressed_color", "Button", INK)
	game_theme.set_color("font_focus_color", "Button", INK)
	game_theme.set_color("font_disabled_color", "Button", MUTED)
	game_theme.set_stylebox("normal", "Button", _style(Color("ece6d2"), 12, Color("d4cdb5"), 1))
	game_theme.set_stylebox("hover", "Button", _style(Color("f8f3e4"), 12, Color("aeb797"), 2))
	game_theme.set_stylebox("pressed", "Button", _style(Color("d9dfc4"), 12, GREEN, 2))
	game_theme.set_stylebox("disabled", "Button", _style(Color("e2dfd1"), 12, Color("d2cebf"), 1))
	game_theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 12, ORANGE, 2))
	game_theme.set_constant("outline_size", "Label", 0)
	game_theme.set_constant("separation", "VBoxContainer", 12)
	game_theme.set_constant("separation", "HBoxContainer", 12)
	theme = game_theme

func _style(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text: String, font_size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 22:
		label.add_theme_font_override("font", heading_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _paragraph(parent: Node, text: String, font_size: int = 16, color: Color = MUTED) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, callback: Callable, primary: bool = false, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 60)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not node_name.is_empty():
		button.name = node_name
	if primary:
		button.add_theme_stylebox_override("normal", _style(GREEN, 12))
		button.add_theme_stylebox_override("hover", _style(Color("738c66"), 12))
		button.add_theme_stylebox_override("pressed", _style(Color("49654d"), 12))
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_hover_color", CREAM)
		button.add_theme_color_override("font_pressed_color", CREAM)
		button.add_theme_color_override("font_focus_color", CREAM)
	button.pressed.connect(func() -> void:
		sound.play("tap")
		callback.call()
	)
	return button

func _bar(color: Color = GREEN, height: int = 8) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background: StyleBoxFlat = _style(Color("dcdcc9"), height / 2)
	var fill: StyleBoxFlat = _style(color, height / 2)
	for style in [background, fill]:
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _build_home() -> void:
	var background := ColorRect.new()
	background.color = Color("e8e3d3")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	safe_margin = MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	safe_margin.add_child(scroll)
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(left)
	var margin := MarginContainer.new()
	margin.custom_minimum_size.x = 456
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	center.add_child(margin)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(right)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	brand.add_child(_label("P O C K E T   C O M P A N I O N", 10, MUTED))
	brand.add_child(_label("口袋怪獸日記", 26))
	var collection := _button("冊", _collection, false, "Collection")
	collection.custom_minimum_size = Vector2(60, 60)
	collection.size_flags_horizontal = Control.SIZE_SHRINK_END
	collection.tooltip_text = "收藏冊"
	header.add_child(collection)
	var settings := _button("···", _settings, false, "Settings")
	settings.custom_minimum_size = Vector2(60, 60)
	settings.size_flags_horizontal = Control.SIZE_SHRINK_END
	settings.tooltip_text = "聲音、作息與開發工具"
	header.add_child(settings)
	var identity := HBoxContainer.new()
	column.add_child(identity)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(names)
	pet_name = _label("等一個小夥伴", 23)
	names.add_child(pet_name)
	stage_label = _label("初始蛋 · 一段陪伴，從這裡開始", 13, MUTED)
	names.add_child(stage_label)
	day_label = _label("DAY 01", 13, GREEN)
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.add_child(day_label)
	var frame := PanelContainer.new()
	var frame_style := _style(Color("626e58"), 16, Color("535e4e"), 2)
	frame_style.content_margin_left = 4
	frame_style.content_margin_right = 4
	frame_style.content_margin_top = 6
	frame_style.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", frame_style)
	column.add_child(frame)
	room = Room.new()
	room.custom_minimum_size = Vector2(432, 264)
	frame.add_child(room)
	room_caption = _label("YOUR LITTLE PLACE IN THE WORLD", 10, MUTED)
	room_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(room_caption)
	status_panel = VBoxContainer.new()
	status_panel.add_theme_constant_override("separation", 8)
	column.add_child(status_panel)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 20)
	status_panel.add_child(needs)
	for entry in [["fullness", "飽食", Color("a7b27b")], ["mood", "心情", Color("c29175")], ["energy", "精力", Color("88a29a")]]:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 6)
		needs.add_child(cell)
		var label := _label(str(entry[1]), 14)
		cell.add_child(label)
		need_labels[entry[0]] = label
		var bar := _bar(entry[2], 8)
		cell.add_child(bar)
		need_bars[entry[0]] = bar
	health_line = _label("", 13, MUTED)
	status_panel.add_child(health_line)
	egg_panel = VBoxContainer.new()
	egg_panel.add_theme_constant_override("separation", 8)
	column.add_child(egg_panel)
	hatch_label = _label("散步，喚醒蛋裡的小宇宙。", 16)
	egg_panel.add_child(hatch_label)
	hatch_bar = _bar(GREEN, 10)
	egg_panel.add_child(hatch_bar)
	var action_grid := GridContainer.new()
	action_grid.columns = 4
	action_grid.add_theme_constant_override("h_separation", 10)
	action_grid.add_theme_constant_override("v_separation", 10)
	column.add_child(action_grid)
	var actions: Array = [["scale", "體重計", _scale], ["food", "食物", _food], ["train", "訓練", _training], ["battle", "對戰", _battle], ["clean", "清潔", _clean], ["lights", "燈光", _lights], ["heal", "療護", _heal], ["steps", "散步", _steps]]
	for action in actions:
		var button := _button("", action[2], false, str(action[0]).capitalize())
		button.custom_minimum_size = Vector2(102, 82)
		action_grid.add_child(button)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.add_theme_constant_override("separation", 0)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		var icon := Icon.new()
		icon.kind = action[0]
		content.add_child(icon)
		var label := _label(action[1], 15)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(label)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", _style(Color("f1ecdc"), 12))
	column.add_child(note)
	toast = _paragraph(note, "今天也一起慢慢長大吧。", 14, MUTED)
	toast.custom_minimum_size.y = 32
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer_label = _label("", 11, MUTED)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer_label)

func _safe_area() -> void:
	if not is_instance_valid(safe_margin):
		return
	var top: int = 0
	var bottom: int = 0
	if OS.get_name() in ["Android", "iOS"]:
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		var factor: float = size.y / maxf(window_size.y, 1)
		top = int(safe.position.y * factor)
		bottom = int((window_size.y - safe.end.y) * factor)
	safe_margin.add_theme_constant_override("margin_top", top)
	safe_margin.add_theme_constant_override("margin_bottom", bottom)
	_modal_safe_area()

func _modal_safe_area() -> void:
	if not is_instance_valid(modal_panel):
		return
	modal_panel.offset_top = maxi(56, safe_margin.get_theme_constant("margin_top") + 12)
	modal_panel.offset_bottom = -maxi(40, safe_margin.get_theme_constant("margin_bottom") + 12)

func _refresh() -> void:
	var state: Dictionary = session.state
	var pet: Dictionary = state.get("pet", {})
	room.update_state(state)
	sound.configure(state.settings)
	status_panel.visible = not pet.is_empty()
	egg_panel.visible = pet.is_empty()
	if pet.is_empty():
		pet_name.text = "等一個小夥伴"
		stage_label.text = "初始蛋 · 一段陪伴，從這裡開始"
		var egg: Dictionary = state.get("egg", {})
		var target: int = int(egg.get("target_steps", 500))
		var credited: int = int(egg.get("credited_steps", 0))
		if egg.get("mode", "steps") == "time":
			var remaining: int = maxi(86400 - (session.now() - int(egg.get("started_at", session.now()))), 0)
			hatch_label.text = "時間孵化  ·  還有 %s" % _duration(remaining)
			hatch_bar.value = clampf((86400.0 - remaining) / 86400.0 * 100.0, 0.0, 100.0)
		else:
			hatch_label.text = "本顆蛋的散步日記  ·  %d / %d 步" % [credited, target]
			hatch_bar.value = float(credited) / maxi(target, 1) * 100.0
		day_label.text = "DAY 01"
	else:
		pet_name.text = str(pet.get("name", "芽芽"))
		stage_label.text = "%s · %s" % [Model.stage_name(pet), _pet_mood(pet)]
		day_label.text = "DAY %02d" % (1 + int((session.now() - int(pet.born_at)) / 86400))
		for key in need_labels:
			var title: String = {"fullness": "飽食", "mood": "心情", "energy": "精力"}[key]
			need_labels[key].text = "%s  %d" % [title, roundi(float(pet.get(key, 0)))]
			need_bars[key].value = float(pet.get(key, 0))
		health_line.text = "健康 %d  ·  清潔 %d  ·  %s" % [int(pet.get("health", 100)), int(pet.get("cleanliness", 100)), "房間很乾淨" if pet.get("poop", []).is_empty() else "有 %d 份便便待清理" % pet.poop.size()]
	var local: Dictionary = Time.get_datetime_dict_from_unix_time(session.now() + int(state.settings.get("timezone_offset_minutes", 0)) * 60)
	room_caption.text = "小房間  /  %02d:%02d     ·     把平凡的日子，養成喜歡的樣子" % [local.hour, local.minute]
	footer_label.text = "開發版 · 模擬步數 · 本機日記已保存" if session.debug_enabled else "本機日記 · 時間孵化可用"
	if not session.last_save_ok:
		footer_label.text = "存檔失敗 · 請保留遊戲並確認可用空間"

func _pet_mood(pet: Dictionary) -> String:
	var conditions: Dictionary = pet.get("conditions", {})
	if conditions.get("hibernating", false): return "休眠中，等你輕輕喚醒"
	if pet.get("behavior", "idle") == "sleeping": return "做一個軟綿綿的夢"
	if conditions.get("sick", false): return "有點不舒服，需要療護"
	if conditions.get("injured", false): return "受傷了，陪牠休息一下"
	if float(pet.get("fullness", 0)) < 30: return "肚子咕嚕咕嚕叫"
	if float(pet.get("energy", 0)) < 25: return "打了個大大的哈欠"
	if float(pet.get("mood", 0)) > 65: return "今天也很喜歡你"
	return "正在觀察窗外的小世界"

func _feedback(message: String, action: String) -> void:
	toast.text = message
	room.play(action)
	sound.play(action)
	if session.state.settings.get("vibration", true) and action in ["train", "hatch", "evolve"]:
		Input.vibrate_handheld(35)

func _milestone(kind: String, message: String) -> void:
	_close()
	room.play(kind)
	sound.play(kind)
	var box := _open("新的故事，長出來了。", "破殼紀念" if kind == "hatch" else "成長紀念")
	var preview := Room.new()
	preview.custom_minimum_size = Vector2(288, 176)
	box.add_child(preview)
	preview.update_state(session.state)
	preview.play(kind)
	_paragraph(box, message, 20, INK)
	_paragraph(box, "這一刻已經寫進成長日記。你可以在體重計裡重看紀錄。")
	box.add_child(_button("你好呀，%s！" % str(session.state.pet.get("name", "小夥伴")), _close, true, "MilestoneContinue"))

func _open(title: String, subtitle: String = "") -> VBoxContainer:
	_close()
	modal_generation += 1
	overlay = Control.new()
	overlay.name = "Modal"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.17, 0.24, 0.20, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := PanelContainer.new()
	modal_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = 56
	panel.offset_bottom = -40
	panel.add_theme_stylebox_override("panel", _style(CREAM, 22, Color("d2cbb2"), 2))
	overlay.add_child(panel)
	_modal_safe_area()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	if not subtitle.is_empty():
		names.add_child(_label(subtitle, 12, MUTED))
	modal_title = _label(title, 24)
	modal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(modal_title)
	var close_button := _button("×", _close, false, "CloseModal")
	close_button.custom_minimum_size = Vector2(60, 60)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	modal_content = VBoxContainer.new()
	modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_content.add_theme_constant_override("separation", 15)
	scroll.add_child(modal_content)
	close_button.grab_focus()
	return modal_content

func _close() -> void:
	modal_generation += 1
	training_active = false
	battle_playing = false
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null
	modal_panel = null

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_instance_valid(overlay):
		_close()
		get_viewport().set_input_as_handled()

func _need_pet() -> bool:
	if session.state.get("pet", {}).is_empty():
		_feedback("小夥伴還在蛋裡，先一起完成孵化吧。", "idle")
		_steps()
		return false
	return true

func _action_row(box: VBoxContainer, text: String, action: String) -> void:
	var reason: String = Care.can_act(session.state, action, session.now())
	var button := _button(text, func() -> void:
		var result: Dictionary = session.act(action)
		if bool(result.get("ok", false)):
			_close()
		else:
			_paragraph(box, str(result.get("message", "現在無法操作")), 14, ORANGE)
	, false, action.capitalize())
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason
	box.add_child(button)
	if not reason.is_empty():
		_paragraph(box, reason, 13, ORANGE)

func _scale() -> void:
	if not _need_pet(): return
	room.play("happy")
	var pet: Dictionary = session.state.pet
	var stats: Dictionary = Model.stats(pet)
	var box := _open("%s 的成長日記" % pet.name, "SCALE  /  體重計")
	var weight := _paragraph(box, "%.1f kg" % float(pet.weight), 38, INK)
	var start: float = maxf(float(pet.weight) - 2.0, 0.0)
	var tween := weight.create_tween()
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(weight): weight.text = "%.1f kg" % value
	, start, float(pet.weight), 0.65)
	var ideal: Vector2 = Model.ideal_weight(pet)
	_paragraph(box, "理想範圍 %.1f–%.1f kg · 體重不等於戰力" % [ideal.x, ideal.y])
	_paragraph(box, "%s  /  %s\n年齡 %s\n健康 %d · 清潔 %d\n飽食 %d · 心情 %d · 精力 %d" % [SPECIES.get(pet.species, pet.species), Model.stage_name(pet), _duration(session.now() - int(pet.born_at)), pet.health, pet.cleanliness, pet.fullness, pet.mood, pet.energy], 17, INK)
	_paragraph(box, "攻擊 %d    防禦 %d    敏捷 %d\n戰鬥 HP %d（與養成健康分開）\n戰績 %d 勝 / %d 敗 / %d 平" % [stats.attack, stats.defense, stats.agility, stats.max_hp, pet.wins, pet.losses, pet.draws], 17, INK)
	_paragraph(box, _evolution_hint(pet), 16, GREEN)
	_paragraph(box, "力量 %d · 防禦 %d · 敏捷 %d\n已完成 %d 次訓練 · 照顧失誤 %d 次\n累積睡眠 %s" % [pet.training.power, pet.training.guard, pet.training.swift, pet.training_count, pet.care_mistakes, _duration(int(pet.sleep_seconds))])
	if not pet.get("evolutions", []).is_empty():
		box.add_child(_button("重看成長演出", func() -> void: _milestone("evolve", "每一步，都長成了現在的你。")))
	if session.state.get("egg", {}).get("hatched", false):
		box.add_child(_button("重看破殼紀念", func() -> void: _milestone("hatch", "還記得初次見面的那一天嗎？")))
	_paragraph(box, "最近的成長紀錄", 18, INK)
	var history: Array = pet.get("history", [])
	for index in range(history.size() - 1, maxi(history.size() - 9, -1), -1):
		_paragraph(box, _history_text(history[index]), 14)

func _evolution_hint(pet: Dictionary) -> String:
	if pet.stage == "baby":
		return "成長線索：幼年滿 2 小時，會長出新的葉角。\n還需 %s" % _duration(maxi(7200 - (session.now() - int(pet.stage_started_at)), 0))
	if pet.stage == "mature":
		return "這段成長已開花結果。收藏牠的日記，就能迎接下一顆蛋。"
	var tendency: String = "power"
	for key in ["guard", "swift"]:
		if int(pet.training[key]) > int(pet.training[tendency]): tendency = key
	return "牠最近特別喜歡%s訓練。\n成長期滿 24 小時 + 3 次訓練即可進化。\n時間還需 %s · 訓練 %d / 3\n同分時：力量 → 防禦 → 敏捷。" % [TRAIN_NAMES[tendency], _duration(maxi(86400 - (session.now() - int(pet.stage_started_at)), 0)), pet.training_count]

func _food() -> void:
	if not _need_pet(): return
	var box := _open("今天想吃點什麼？", "MEAT  /  食物")
	_paragraph(box, "正餐填飽肚子，點心帶來一點好心情。吃飽時會拒食，適量最舒服。", 18, INK)
	_action_row(box, "營養正餐  ·  飽食 +25", "meal")
	_action_row(box, "莓果點心  ·  心情 +%d" % int(Care.balance().care.snack.mood), "snack")
	_paragraph(box, "餵食後會安排排泄，記得回來整理小房間。體重與照顧紀錄也會一起保存。")

func _clean() -> void:
	if not _need_pet(): return
	var box := _open("把小房間整理好", "TOILET  /  清潔")
	_paragraph(box, "待清理：%d 份\n預計排泄：%d 次" % [session.state.pet.poop.size(), session.state.pet.poop_queue.size()], 20, INK)
	_action_row(box, "清理便便與房間", "clean")
	_paragraph(box, "便便堆積會影響心情與健康。一次整理，就能重新舒服地生活。")

func _lights() -> void:
	if not _need_pet(): return
	var box := _open("留一盞溫柔的燈", "LIGHTS  /  作息")
	var pet: Dictionary = session.state.pet
	_paragraph(box, "目前%s · %s" % ["開燈" if pet.lights_on else "關燈", _pet_mood(pet)], 18, INK)
	_action_row(box, "關燈休息" if pet.lights_on else "開燈", "lights")
	if pet.conditions.get("hibernating", false):
		_action_row(box, "輕輕喚醒小夥伴", "wake")
	_paragraph(box, "只有到了作息時間，或精力偏低，才會入睡。關燈後不會立刻回滿精力；睡眠依經過時間恢復。")
	box.add_child(_button("調整每日作息", _settings))

func _heal() -> void:
	if not _need_pet(): return
	var pet: Dictionary = session.state.pet
	var box := _open("慢慢來，會好起來的", "BANDAGE  /  療護")
	_paragraph(box, "受傷：%s\n生病：%s\n養成健康：%d / 100" % ["需要休養" if pet.conditions.get("injured", false) else "沒有受傷", "需要療護" if pet.conditions.get("sick", false) else "沒有生病", pet.health], 19, INK)
	_action_row(box, "繃帶  ·  處理受傷", "heal_injury")
	_action_row(box, "療護  ·  照顧生病", "heal_sickness")
	for key in pet.get("cooldowns", {}):
		if "heal" in str(key) and int(pet.cooldowns[key]) > session.now():
			_paragraph(box, "療護冷卻還有 %s" % _duration(int(pet.cooldowns[key]) - session.now()), 14, ORANGE)
	for key in pet.get("care_timers", {}):
		if int(pet.care_timers[key]) > session.now():
			_paragraph(box, "%s恢復倒數 %s" % ["傷勢" if key == "heal_injury" else "生病", _duration(int(pet.care_timers[key]) - session.now())], 16, GREEN)
	_paragraph(box, "受傷與生病可以同時存在；睡眠不會把它們直接清除。療護完成後仍需要休息。")

func _duration(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	if seconds < 60: return "%d 秒" % seconds
	if seconds < 3600: return "%d 分" % int(ceil(seconds / 60.0))
	return "%d 小時 %d 分" % [int(seconds / 3600), int((seconds % 3600) / 60)]

func _history_text(item: Variant) -> String:
	if item is Dictionary:
		if item.has("message") or item.has("text"):
			return str(item.get("message", item.get("text", "")))
		var kind: String = str(item.get("type", item.get("event", "")))
		var names: Dictionary = {"meal": "享用營養正餐", "snack": "享用莓果點心", "clean": "整理了小房間", "wake": "醒來繼續陪伴", "lights_on": "打開小房間的燈", "lights_off": "關燈準備休息", "care_start": "開始療護", "care_complete": "療護完成", "hatch": "破殼，與你相遇", "evolution": "進入新的成長階段", "evolve": "進入新的成長階段", "care_mistake": "一次需求未及時照顧", "battle": "完成鄰里切磋", "poop": "需要清理房間"}
		if kind == "train": return "%s訓練 · 成長 +%d" % [TRAIN_NAMES.get(item.get("kind", "power"), ""), int(item.get("gain", 0))]
		if item.has("to") or item.has("species"):
			return "成長為 %s" % SPECIES.get(item.get("species", item.get("to", "")), "新的樣子")
		return str(names.get(kind, "一起度過一段成長時光"))
	return str(item)

func _training() -> void:
	if not _need_pet(): return
	var box := _open("練習一點，成長一點", "TRAINING  /  15 秒時機挑戰")
	_paragraph(box, "在指針進入中央綠色區域時點擊。三輪練習，每輪 5 秒；越接近中央，成長越多。", 18, INK)
	var reason: String = Care.can_act(session.state, "train", session.now())
	var caps: Dictionary = Care.balance().training.stage_caps.get(session.state.pet.stage, {})
	for kind in ["power", "guard", "swift"]:
		var cap: int = int(caps.get(kind, 3))
		var button := _button("%s訓練  ·  成長 %d / %d" % [TRAIN_NAMES[kind], int(session.state.pet.training[kind]), cap], _start_training.bind(kind), false, "Train" + kind.capitalize())
		var at_cap: bool = int(session.state.pet.training[kind]) >= cap
		button.disabled = not reason.is_empty() or at_cap
		box.add_child(button)
		if at_cap: _paragraph(box, "%s已達本階段上限，進化後能繼續成長。" % TRAIN_NAMES[kind], 13, ORANGE)
	if not reason.is_empty():
		_paragraph(box, reason, 15, ORANGE)
	_paragraph(box, "每次消耗精力並略降體重。每個成長階段有上限，訓練傾向會決定成熟後的樣子。")

func _start_training(kind: String) -> void:
	var reason: String = Care.can_act(session.state, "train", session.now())
	if not reason.is_empty():
		_feedback(reason, "idle")
		return
	var box := _open("%s訓練" % TRAIN_NAMES[kind], "瞄準中間的深綠色區域")
	training_active = true
	var generation: int = modal_generation
	var progress := _paragraph(box, "第 1 / 3 輪", 22, INK)
	var preview := Room.new()
	preview.custom_minimum_size = Vector2(288, 176)
	box.add_child(preview)
	preview.update_state(session.state)
	var meter := Meter.new()
	box.add_child(meter)
	var judgment := _paragraph(box, "準備好了，就點一下。", 19, GREEN)
	var grades: Array[int] = []
	var round_grade: Array[int] = [0]
	var hit := _button("就是現在！", func() -> void:
		if not training_active or round_grade[0] > 0: return
		round_grade[0] = meter.quality()
		meter.running = false
		judgment.text = ["", "普通  +1", "良好  +2", "完美！ +3"][round_grade[0]]
		preview.play("train")
		sound.play("train")
	, true, "TimingHit")
	box.add_child(hit)
	_paragraph(box, "離開訓練不會領取成長。每一輪只能判定一次。", 13)
	for round_index in 3:
		if generation != modal_generation or not training_active: return
		round_grade[0] = 0
		meter.running = true
		meter.phase = float(round_index) * 1.15
		for remaining in range(5, 0, -1):
			progress.text = "第 %d / 3 輪  ·  %d 秒" % [round_index + 1, remaining]
			await get_tree().create_timer(1.0).timeout
			if generation != modal_generation or not training_active: return
		grades.append(maxi(round_grade[0], 1))
		if round_grade[0] == 0:
			judgment.text = "普通  ·  下一輪再試試！"
	training_active = false
	var quality: int = clampi(roundi(float(grades[0] + grades[1] + grades[2]) / 3.0), 1, 3)
	var result: Dictionary = session.train(kind, quality)
	if generation != modal_generation: return
	box = _open("今天又進步了一點", "TRAINING  /  練習完成")
	_paragraph(box, "普通 / 良好 / 完美\n三輪成績：%d · %d · %d" % grades, 21, INK)
	_paragraph(box, str(result.get("message", "練習完成")), 18, GREEN)
	box.add_child(_button("回到小房間", _close, true, "TrainingDone"))

func _battle() -> void:
	if not _need_pet(): return
	var pending: Dictionary = session.state.get("pending_battle", {})
	if not pending.is_empty() and not pending.get("settled", true):
		_battle_report()
		return
	var box := _open("交個朋友，也切磋一下", "FIGHTING  /  鄰里對戰")
	_paragraph(box, "20–40 秒自動對戰 · 每場消耗 12 精力\n能力與結果在開始時保存，重開會接回同一場。", 16, INK)
	var stance := OptionButton.new()
	stance.name = "BattleStance"
	stance.custom_minimum_size.y = 60
	stance.add_item("均衡  ·  穩定攻守")
	stance.add_item("強攻  ·  攻擊↑ 防禦↓")
	stance.add_item("防守  ·  防禦↑ 攻擊↓")
	box.add_child(stance)
	var reason: String = Care.can_act(session.state, "battle", session.now())
	for npc in Battle.opponents():
		var id: String = str(npc.id)
		var button := _button("%s  →" % str(npc.name), func() -> void:
			var policy: String = ["balanced", "assault", "defend"][stance.selected]
			var result: Dictionary = session.begin_battle(id, policy)
			if result.get("ok", false): _battle_report()
			else: _paragraph(box, str(result.get("message", "現在無法對戰")), 15, ORANGE)
		, false, "Battle_" + id)
		button.disabled = not reason.is_empty()
		box.add_child(button)
		_paragraph(box, "%s\n攻 %d / 防 %d / 敏 %d" % [npc.get("description", ""), npc.attack, npc.defense, npc.agility], 14)
	if not reason.is_empty(): _paragraph(box, reason, 15, ORANGE)
	if not pending.is_empty():
		box.add_child(_button("重看上一場戰報", _battle_report))
	_paragraph(box, "好友非同步挑戰將在後續階段加入。這裡的對手都是本機 NPC。", 13)

func _battle_report() -> void:
	var battle: Dictionary = session.state.get("pending_battle", {})
	if battle.is_empty(): return
	var box := _open("%s  vs  %s" % [str(session.state.pet.get("name", "芽芽")), battle.npc_name], "FIGHTING  /  切磋戰報")
	var generation: int = modal_generation
	battle_playing = true
	var arena := Room.new()
	arena.custom_minimum_size = Vector2(288, 176)
	box.add_child(arena)
	arena.update_state(session.state)
	arena.arena(str(battle.enemy.get("species", "moss")))
	var player_max: int = int(battle.player.get("max_hp", 100))
	var enemy_max: int = int(battle.enemy.get("max_hp", 100))
	var hp_label := _paragraph(box, "我方 %d / %d  ·  對手 %d / %d" % [player_max, player_max, enemy_max, enemy_max], 17, INK)
	var player_bar := _bar(GREEN, 13)
	player_bar.max_value = player_max
	player_bar.value = player_max
	box.add_child(player_bar)
	var enemy_bar := _bar(ORANGE, 13)
	enemy_bar.max_value = enemy_max
	enemy_bar.value = enemy_max
	box.add_child(enemy_bar)
	var report := _paragraph(box, "互相打個招呼，準備開始！", 20, INK)
	report.custom_minimum_size.y = 95
	var skip := _button("跳過演出，查看結果", func() -> void:
		battle_playing = false
		_show_battle_result()
	, false, "SkipBattle")
	box.add_child(skip)
	_paragraph(box, "戰鬥 %s\n技能每場最多一次，至多 12 次行動。" % str(battle.id), 12)
	for round_data in battle.rounds:
		await get_tree().create_timer(2.1).timeout
		if generation != modal_generation or not battle_playing: return
		player_bar.value = int(round_data.player_hp)
		enemy_bar.value = int(round_data.enemy_hp)
		hp_label.text = "我方 %d / %d  ·  對手 %d / %d" % [round_data.player_hp, player_max, round_data.enemy_hp, enemy_max]
		report.text = str(round_data.text)
		arena.canvas.enemy_turn = round_data.actor == "enemy"
		arena.play("attack" if round_data.actor == "player" else "hit")
		sound.play("attack")
	await get_tree().create_timer(1.2).timeout
	if generation == modal_generation and battle_playing:
		_show_battle_result()

func _show_battle_result() -> void:
	var result: Dictionary = session.finish_battle()
	var battle: Dictionary = session.state.get("pending_battle", {})
	var outcome: String = str(battle.get("outcome", "draw"))
	var box := _open({"win": "贏了！一起開心一下", "loss": "下次會更好的", "draw": "旗鼓相當的好對手"}[outcome], "FIGHTING  /  已保存結果")
	_paragraph(box, str(result.get("message", "這場切磋已寫入日記。")), 19, INK)
	_paragraph(box, "輸贏都是成長的一部分。照顧與休息過後，再來挑戰吧。")
	box.add_child(_button("回到小房間", _close, true, "BattleDone"))
	_paragraph(box, "完整戰報", 18, INK)
	for entry in battle.get("rounds", []):
		_paragraph(box, str(entry.text), 14)

func _steps() -> void:
	var box := _open("每一小步，都算數", "WALKING  /  孵化日記")
	var state: Dictionary = session.state
	var egg: Dictionary = state.get("egg", {})
	var progress: int = int(egg.get("credited_steps", 0))
	var target: int = int(egg.get("target_steps", 500))
	_paragraph(box, "%d / %d 步" % [progress, target], 34, INK)
	var bar := _bar(GREEN, 15)
	bar.value = float(progress) / maxi(target, 1) * 100.0
	box.add_child(bar)
	_paragraph(box, "25% 晃動 → 50% 裂紋 → 75% 微光 → 100% 破殼", 14, GREEN)
	if egg.get("hatched", false):
		_paragraph(box, "這顆蛋已經孵化了。將成熟怪獸存入收藏冊後，再迎接下一顆蛋。", 18, INK)
	else:
		_paragraph(box, "只累積這顆蛋開始之後的步數。跨日會保留進度，超額步數不會存到下一顆蛋。")
	var sync: Dictionary = state.get("step_sync", state.get("step_status", {}))
	var last_sync: int = int(egg.get("last_sync", state.get("last_step_sync", sync.get("last_sync", 0))))
	var status_key: String = str(egg.get("sync_status", sync.get("status", "not_synced")))
	var status: String = {"ok": "已同步", "partial": "部分區間尚未回補", "denied": "尚未授權", "unavailable": "來源尚未可用", "delayed": "資料延遲，稍後重試", "hatched": "已完成孵化", "time_mode": "時間孵化中", "source_conflict": "來源不同，未重複累計", "invalid": "資料不完整，未入帳", "rollback": "裝置時間異常，暫停同步"}.get(status_key, "尚未同步")
	var local_sync: int = last_sync + int(state.settings.get("timezone_offset_minutes", 0)) * 60
	_paragraph(box, "來源：%s\n同步狀態：%s\n最後同步：%s" % ["Mock 模擬步數（開發版）" if session.debug_enabled else "尚未接上 iOS 計步，資料未知", status, "尚未同步" if last_sync <= 0 else Time.get_datetime_string_from_unix_time(local_sync, true)], 14)
	var today: Variant = sync.get("today_steps", state.get("today_steps", null))
	_paragraph(box, "今日步數：%s（與本顆蛋進度分開）" % ("尚未取得" if today == null else str(today)), 14)
	box.add_child(_button("重新同步", func() -> void:
		var old_generation: int = modal_generation
		session.sync_steps()
		if old_generation == modal_generation: _steps()
	, true, "SyncSteps"))
	if not egg.get("hatched", false):
		box.add_child(_button("使用 24 小時孵化", func() -> void:
			session.time_hatch()
			_steps()
		, false, "TimeHatch"))
		_paragraph(box, "沒有授權或無步數來源也能遊玩。時間孵化從本顆蛋開始時計算，最多等待 24 小時。", 13)
	if session.debug_enabled:
		_paragraph(box, "開發工具 · 以下都不是實際步數", 16, ORANGE)
		var row := HBoxContainer.new()
		box.add_child(row)
		row.add_child(_button("+100 步", _mock_steps.bind(100), false, "Mock100"))
		row.add_child(_button("+1,000 步", _mock_steps.bind(1000), false, "Mock1000"))
		for entry in [["normal", "正常同步"], ["denied", "模擬拒絕權限"], ["unavailable", "模擬無來源"], ["delayed", "模擬延遲資料"], ["duplicate", "模擬重複回傳"], ["reboot", "模擬手機重啟"]]:
			box.add_child(_button(entry[1], func() -> void:
				session.mock_mode(entry[0])
				_steps()
			))

func _mock_steps(count: int) -> void:
	var generation: int = modal_generation
	session.add_mock_steps(count)
	if generation == modal_generation: _steps()

func _collection() -> void:
	var box := _open("把一起長大的日子留下", "COLLECTION  /  收藏冊")
	var collection: Array = session.state.get("collection", [])
	_paragraph(box, "%d 位小夥伴的成長日記" % collection.size(), 21, INK)
	var pet: Dictionary = session.state.get("pet", {})
	if not pet.is_empty() and pet.get("stage", "") == "mature":
		_paragraph(box, "將%s的完整能力與培育紀錄留在收藏冊，開始養育下一顆蛋。" % pet.name)
		box.add_child(_button("珍藏這段日記，迎接新蛋", func() -> void:
			var confirm := _open("替這段日記繫上書籤", "COLLECTION  /  確認收藏")
			_paragraph(confirm, "收藏後，牠的能力與歷史都會留下。主房間會迎來一顆新的蛋。", 19, INK)
			confirm.add_child(_button("收藏並開始下一輪", func() -> void:
				session.archive()
				_close()
			, true, "ConfirmArchive"))
		))
	else:
		_paragraph(box, "小夥伴成熟後，就可以把完整的培育紀錄收藏在這裡。", 18, INK)
	if collection.is_empty():
		_paragraph(box, "01  暖焰獸  ·  喜歡力量練習\n02  苔甲獸  ·  喜歡防禦練習\n03  風耳獸  ·  喜歡敏捷練習", 19, GREEN)
	for individual in collection:
		var saved: Dictionary = individual.get("pet", individual)
		var stats: Dictionary = Model.stats(saved)
		_paragraph(box, "%s · %s\n攻 %d / 防 %d / 敏 %d\n訓練 %d 次 · %d 勝 %d 敗\n保留 %d 筆成長紀錄" % [saved.get("name", "芽芽"), SPECIES.get(saved.get("species", ""), "成熟體"), stats.attack, stats.defense, stats.agility, saved.get("training_count", 0), saved.get("wins", 0), saved.get("losses", 0), saved.get("history", []).size()], 17, INK)
		for entry in saved.get("evolutions", []):
			_paragraph(box, _history_text(entry), 13)

func _settings() -> void:
	var box := _open("照自己的步調生活", "SETTINGS  /  設定")
	for entry in [["sound", "互動音效"], ["music", "輕柔背景音樂"], ["vibration", "觸覺回饋"], ["auto_lights", "作息時段自動關燈"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[1]
		toggle.custom_minimum_size.y = 60
		toggle.button_pressed = bool(session.state.settings.get(entry[0], true))
		toggle.toggled.connect(func(value: bool) -> void: session.setting(entry[0], value))
		box.add_child(toggle)
	_paragraph(box, "音量", 16, INK)
	var volume := HSlider.new()
	volume.custom_minimum_size.y = 48
	volume.min_value = 0
	volume.max_value = 100
	volume.value = float(session.state.settings.get("volume", 0.65)) * 100
	volume.drag_ended.connect(func(_changed: bool) -> void: session.setting("volume", volume.value / 100.0))
	box.add_child(volume)
	for setting_name in ["sleep_hour", "wake_hour"]:
		_paragraph(box, "入睡時間" if setting_name == "sleep_hour" else "起床時間", 16, INK)
		var hour := OptionButton.new()
		hour.custom_minimum_size.y = 60
		for value in 24: hour.add_item("%02d:00" % value)
		hour.selected = int(session.state.settings.get(setting_name, 22 if setting_name == "sleep_hour" else 7))
		hour.item_selected.connect(func(index: int) -> void: session.setting(setting_name, index))
		box.add_child(hour)
	_paragraph(box, "作息使用玩家時區（UTC %+d 分）。需求衰減最多結算 12 小時，忙碌時會進入保護性休眠。" % int(session.state.settings.timezone_offset_minutes), 14)
	box.add_child(_button("更新為此裝置時區", func() -> void:
		session.setting("timezone_offset_minutes", int(Time.get_time_zone_from_system().bias))
		_settings()
	))
	_paragraph(box, "本版本可體驗完整養成。手機計步正在準備；目前可用時間孵化或開發版模擬來源。", 14)
	box.add_child(_button("製作與授權", _credits))
	if session.debug_enabled:
		_paragraph(box, "開發工具 · 僅開發版顯示", 18, ORANGE)
		_paragraph(box, "快轉會真實觸發照顧衰減、睡眠、療護與進化。24 小時快轉後可在燈光頁喚醒休眠。", 14)
		for entry in [[60, "+1 分鐘"], [1800, "+30 分鐘"], [7200, "+2 小時（幼年成長）"], [86400, "+24 小時（成熟檢查）"]]:
			box.add_child(_button(entry[1], func() -> void:
				var generation: int = modal_generation
				session.fast_forward(entry[0])
				if generation == modal_generation:
					_close()
					_feedback("已快轉 %s，狀態已保存。" % _duration(entry[0]), "idle")
			, false, "FastForward" + str(entry[0])))

func _credits() -> void:
	var box := _open("每一段陪伴，從這裡開始", "CREDITS  /  製作與授權")
	_paragraph(box, "怪獸、像素房間、介面圖示與合成音效為本遊戲原創。\n字型使用 Noto Sans TC，採 SIL Open Font License。", 17, INK)
	_paragraph(box, "Godot Engine", 22, INK)
	_paragraph(box, Engine.get_license_text(), 13)
	_paragraph(box, "Noto Sans TC", 22, INK)
	_paragraph(box, FileAccess.get_file_as_string("res://assets/fonts/OFL.txt"), 13)
