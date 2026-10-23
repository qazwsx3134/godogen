extends SceneTree
## Authoring tool for the push HUD in the 墨綠暖白 look (ui/theme.tres; layout after
## art_src/ui_concepts/revision_d/battle.png). Applied 2026-10-22 over the earlier hud.tscn, part_button.tscn and
## skill_callout.tscn (built by build_scenes / build_squads / build_skills / build_growth). It overwrites all three: run
## it again only after checking that none of them was edited by hand since.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_hud.gd
## hud.tscn:
##   Top        stage (1-1) and boss name, phase pill, timer box; boss HP bar; survivors and damage per second
##   BannerStrip  the call of the moment (a framed strip with a "!" square), under the top panel
##   SkillCallout an SSR's 招牌技 card, sliding in under the banner
##   Coach      a first-push hint over the field (main.gd shows each once per save)
##   Parts      the three part buttons that follow the boss (腿, 持棍手臂, 角)
##   Bottom     跳過集結; the three squad tabs; morale with the hint; 全員歸位 and 大招
##   Result     the result panel with the 推王戰報, 挑戰下一關 (after a first clear), 再來一場, 前往養成, 回營地
##   PauseMenu  暫停 pauses the push: 繼續, 設定 (settings_panel.tscn), 撤退回營地

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PushSim = preload("res://domain/push_sim.gd")
const HUD := "res://scenes/hud.tscn"
const PART := "res://scenes/part_button.tscn"
const CALLOUT := "res://scenes/skill_callout.tscn"
const REPORT := "res://scenes/push_report.tscn"
const SETTINGS := "res://scenes/settings_panel.tscn"
const THEME := "res://ui/theme.tres"
const FLAGS := ["res://assets/flags/melee.png", "res://assets/flags/ranged.png", "res://assets/flags/support.png"]
const GOLD := Color("d9b26e")
const TEXT := Color("ece6dc")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_part(), PART, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_callout(), CALLOUT, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_hud(), HUD, {"overwrite": true, "expected_refs": [PART, CALLOUT, REPORT, SETTINGS]}).ok
	quit(0 if ok else 1)


func _part() -> Button:
	var button := Button.new()
	button.name = "PartButton"
	button.set_script(load("res://scripts/part_button.gd"))
	button.theme = load(THEME)
	button.theme_type_variation = &"PartButton"
	button.custom_minimum_size = Vector2(132, 60)
	button.size = button.custom_minimum_size
	button.text = "角"
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HpBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -16.0
	bar.offset_bottom = -8.0
	bar.show_percentage = false
	bar.value = 70.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(button, SceneBuilder.unique(bar), "Bar")
	return button


func _callout() -> Control:
	var root := Control.new()
	root.name = "SkillCallout"
	root.set_script(load("res://scripts/skill_callout.gd"))
	root.theme = load(THEME)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(500, 124)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, panel, "Panel")
	var row := SceneBuilder.add(panel, HBoxContainer.new(), "Row") as HBoxContainer
	row.add_theme_constant_override(&"separation", 14)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"Pill"
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(row, frame, "Frame")
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(88, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = load("res://assets/heroes/portraits/mage.png")
	SceneBuilder.add(frame, SceneBuilder.unique(portrait), "Portrait")
	var text := SceneBuilder.add(row, VBoxContainer.new(), "Text") as VBoxContainer
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 0)
	SceneBuilder.add(text, SceneBuilder.unique(_label("「隕石術」", 34, GOLD, &"Heading")), "SkillName")
	SceneBuilder.add(text, SceneBuilder.unique(_label("SSR 法‧溫嘉", 22, TEXT)), "HeroLine")
	SceneBuilder.add(text, SceneBuilder.unique(_label("隕石砸向瞄準的部位", 20, TEXT, &"Dim")), "Desc")
	return root


func _hud() -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(load("res://scripts/hud.gd"))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load(THEME)
	SceneBuilder.add(hud, root, "Root")

	# Top panel.
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins(top, 16, 28, 16, 0)
	SceneBuilder.add(root, top, "Top")
	var top_panel := PanelContainer.new()
	top_panel.theme_type_variation = &"HudPanel"
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(top, top_panel, "TopPanel")
	var top_box := SceneBuilder.add(top_panel, VBoxContainer.new(), "TopBox") as VBoxContainer
	top_box.add_theme_constant_override(&"separation", 8)
	var title_row := SceneBuilder.add(top_box, HBoxContainer.new(), "TitleRow") as HBoxContainer
	title_row.add_theme_constant_override(&"separation", 10)
	var pause := Button.new()
	pause.text = "暫停"
	pause.custom_minimum_size = Vector2(84, 64)
	pause.add_theme_font_size_override(&"font_size", 22)
	SceneBuilder.add(title_row, SceneBuilder.unique(pause), "Pause")
	var stage_label := _label("1-1", 26, GOLD, &"Heading")
	stage_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(title_row, SceneBuilder.unique(stage_label), "StageLabel")
	var boss_name := _label("棍棒巨魔", 32, TEXT, &"Heading")
	boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(title_row, SceneBuilder.unique(boss_name), "BossName")
	var phase_pill := _pill()
	phase_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(title_row, phase_pill, "PhasePill")
	SceneBuilder.add(phase_pill, SceneBuilder.unique(_label("第一階段", 22, TEXT)), "PhaseLabel")
	var timer_box := _pill()
	timer_box.custom_minimum_size = Vector2(104, 0)
	SceneBuilder.add(title_row, timer_box, "TimerBox")
	var timer := _label("150", 44, TEXT, &"Heading")
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(timer_box, SceneBuilder.unique(timer), "TimerLabel")
	var hp := ProgressBar.new()
	hp.theme_type_variation = &"HpBar"
	hp.custom_minimum_size = Vector2(0, 30)
	hp.show_percentage = false
	hp.value = 100.0
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(top_box, SceneBuilder.unique(hp), "BossHp")
	var hp_label := _label("100%", 22, TEXT, &"FieldLabel")
	hp_label.add_theme_constant_override(&"outline_size", 6)
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(hp, SceneBuilder.unique(hp_label), "BossHpLabel")
	var dps := _label("存活 100／100　總輸出 0／秒", 20, TEXT, &"Dim")
	dps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(top_box, SceneBuilder.unique(dps), "DpsLabel")

	# The call of the moment, under the top panel.
	var strip := PanelContainer.new()
	strip.theme_type_variation = &"HudPanel"
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_left = 16.0
	strip.offset_right = -16.0
	strip.offset_top = 214.0
	strip.offset_bottom = 274.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(strip), "BannerStrip")
	var strip_row := SceneBuilder.add(strip, HBoxContainer.new(), "Row") as HBoxContainer
	strip_row.add_theme_constant_override(&"separation", 14)
	var bang_box := ColorRect.new()
	bang_box.custom_minimum_size = Vector2(40, 40)
	bang_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bang_box.color = Color("b5432f")
	bang_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(strip_row, SceneBuilder.unique(bang_box), "Bang")
	var bang := _label("!", 30, TEXT, &"Heading")
	bang.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bang.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bang.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(bang_box, bang, "Mark")
	var banner := _label("重砸！ 把旗子拖出紅圈！", 30, TEXT, &"Heading")
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(strip_row, SceneBuilder.unique(banner), "Banner")

	# Part buttons (hud.gd moves them onto the boss each frame).
	var parts := Control.new()
	parts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(parts), "Parts")
	for spec: Array in [["PartLegs", 0, 380.0], ["PartArm", 1, 470.0], ["PartHorns", 2, 560.0]]:
		var part: Button = SceneBuilder.instance(PART)
		part.part_index = spec[1]
		part.position = Vector2(540.0, spec[2])
		part.size = Vector2(132, 60)
		SceneBuilder.add(parts, part, spec[0])

	var callout: Control = SceneBuilder.instance(CALLOUT)
	# An instance keeps only the offsets set on it: under the banner, at the left edge.
	callout.position = Vector2(0.0, 290.0)
	callout.size = Vector2(500, 124)
	SceneBuilder.add(root, SceneBuilder.unique(callout), "SkillCallout")

	# First-push hints, above the bottom panel; taps go through to the field.
	var coach := PanelContainer.new()
	coach.theme_type_variation = &"HudPanel"
	coach.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	coach.offset_left = 48.0
	coach.offset_right = -48.0
	coach.offset_top = -470.0
	coach.offset_bottom = -380.0
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coach.visible = false
	SceneBuilder.add(root, SceneBuilder.unique(coach), "Coach")
	var coach_text := _label("按住旗子拖動，整團就會跟著走", 26, TEXT)
	coach_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(coach, SceneBuilder.unique(coach_text), "CoachText")

	# Bottom panel.
	var bottom := MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margins(bottom, 16, 0, 16, 28)
	SceneBuilder.add(root, bottom, "Bottom")
	var bottom_box := SceneBuilder.add(bottom, VBoxContainer.new(), "BottomBox") as VBoxContainer
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_box.add_theme_constant_override(&"separation", 10)
	var skip_row := SceneBuilder.add(bottom_box, HBoxContainer.new(), "SkipRow") as HBoxContainer
	skip_row.alignment = BoxContainer.ALIGNMENT_END
	skip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skip := Button.new()
	skip.text = "跳過集結 ▶"
	skip.custom_minimum_size = Vector2(220, 72)
	SceneBuilder.add(skip_row, SceneBuilder.unique(skip), "SkipMuster")
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HudPanel"
	SceneBuilder.add(bottom_box, panel, "BottomPanel")
	var box := SceneBuilder.add(panel, VBoxContainer.new(), "Box") as VBoxContainer
	box.add_theme_constant_override(&"separation", 12)
	var tabs := SceneBuilder.add(box, SceneBuilder.unique(HBoxContainer.new()), "SquadTabs") as HBoxContainer
	tabs.add_theme_constant_override(&"separation", 8)
	for s: int in PushSim.SQUADS:
		var tab := Button.new()
		tab.theme_type_variation = &"CardButton"
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 84)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.text = "%s\n%d 人" % [PushSim.SQUAD_NAMES[s], [52, 33, 15][s]]
		tab.add_theme_font_size_override(&"font_size", 24)
		tab.add_theme_constant_override(&"icon_max_width", 30)
		tab.add_theme_constant_override(&"h_separation", 10)
		tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var flag := AtlasTexture.new()
		flag.atlas = load(FLAGS[s])
		flag.region = Rect2(0, 0, flag.atlas.get_width() / 2.0, flag.atlas.get_height())
		tab.icon = flag
		SceneBuilder.add(tabs, tab, "Squad_%d" % s)
	var morale_row := SceneBuilder.add(box, HBoxContainer.new(), "MoraleRow") as HBoxContainer
	morale_row.add_theme_constant_override(&"separation", 12)
	SceneBuilder.add(morale_row, _label("士氣", 24, TEXT), "MoraleTitle")
	var morale := ProgressBar.new()
	morale.theme_type_variation = &"MoraleBar"
	morale.custom_minimum_size = Vector2(0, 22)
	morale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	morale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	morale.show_percentage = false
	morale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(morale_row, SceneBuilder.unique(morale), "Morale")
	SceneBuilder.add(morale_row, SceneBuilder.unique(_label("拖旗子，或點地面移動", 20, TEXT, &"Dim")), "Hint")
	var actions := SceneBuilder.add(box, HBoxContainer.new(), "Actions") as HBoxContainer
	actions.add_theme_constant_override(&"separation", 12)
	for spec: Array in [["Regroup", "全員歸位", &""], ["Volley", "大招", &"PrimaryButton"]]:
		var button := Button.new()
		button.text = spec[1]
		button.theme_type_variation = spec[2]
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 34)
		SceneBuilder.add(actions, SceneBuilder.unique(button), spec[0])

	# Result.
	var result := Control.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(result), "Result")
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.03, 0.6)
	SceneBuilder.add(result, dim, "Dim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(result, center, "Center")
	var result_panel := PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(600, 0)
	SceneBuilder.add(center, result_panel, "Panel")
	var result_box := SceneBuilder.add(result_panel, VBoxContainer.new(), "PanelBox") as VBoxContainer
	result_box.add_theme_constant_override(&"separation", 16)
	var title := _label("推王成功！", 52, GOLD, &"Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(result_box, SceneBuilder.unique(title), "ResultTitle")
	var detail := _label("剩 30.0 秒　存活 85 人", 28, TEXT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(result_box, SceneBuilder.unique(detail), "ResultDetail")
	var rewards := _label("獲得：金幣 +840　突破素材 +3", 24, GOLD)
	rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(result_box, SceneBuilder.unique(rewards), "Rewards")
	SceneBuilder.add(result_box, SceneBuilder.unique(SceneBuilder.instance(REPORT)), "Report")
	for spec: Array in [["NextStage", "挑戰下一關", &"PrimaryButton"], ["Retry", "再來一場", &""],
			["GoGrow", "前往養成", &"PrimaryButton"]]:
		var button := Button.new()
		button.text = spec[1]
		button.theme_type_variation = spec[2]
		button.custom_minimum_size = Vector2(0, 92)
		SceneBuilder.add(result_box, SceneBuilder.unique(button), spec[0])
	var camp := Button.new()
	camp.theme_type_variation = &"FlatButton"
	camp.text = "回營地"
	camp.custom_minimum_size = Vector2(0, 64)
	SceneBuilder.add(result_box, SceneBuilder.unique(camp), "ResultCamp")

	# Pause: runs while the tree is paused.
	var pause_layer := Control.new()
	pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_layer.visible = false
	SceneBuilder.add(root, SceneBuilder.unique(pause_layer), "PauseMenu")
	var pause_dim := ColorRect.new()
	pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_dim.color = Color(0.02, 0.04, 0.03, 0.7)
	SceneBuilder.add(pause_layer, pause_dim, "Dim")
	var pause_center := CenterContainer.new()
	pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(pause_layer, pause_center, "Center")
	var pause_panel := PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(520, 0)
	SceneBuilder.add(pause_center, SceneBuilder.unique(pause_panel), "PausePanel")
	var pause_col := SceneBuilder.add(pause_panel, VBoxContainer.new(), "Column") as VBoxContainer
	pause_col.add_theme_constant_override(&"separation", 16)
	var pause_title := _label("暫停", 44, TEXT, &"Heading")
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(pause_col, pause_title, "Title")
	for spec: Array in [["Resume", "繼續", &"PrimaryButton"], ["PauseSettings", "設定", &""], ["Retreat", "撤退回營地（這場不算）", &""]]:
		var button := Button.new()
		button.text = spec[1]
		button.theme_type_variation = spec[2]
		button.custom_minimum_size = Vector2(0, 92)
		SceneBuilder.add(pause_col, SceneBuilder.unique(button), spec[0])
	var settings_center := CenterContainer.new()
	settings_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(pause_layer, settings_center, "SettingsCenter")
	var settings: Control = SceneBuilder.instance(SETTINGS)
	settings.visible = false
	SceneBuilder.add(settings_center, SceneBuilder.unique(settings), "SettingsPanel")
	return hud


func _pill() -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill


func _margins(box: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	box.add_theme_constant_override(&"margin_left", left)
	box.add_theme_constant_override(&"margin_top", top)
	box.add_theme_constant_override(&"margin_right", right)
	box.add_theme_constant_override(&"margin_bottom", bottom)


func _label(value: String, size: int, color: Color, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override(&"font_size", size)
	if variation != &"Dim":
		label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
