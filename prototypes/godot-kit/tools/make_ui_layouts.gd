extends SceneTree
## Applied 2026-10-25. One-time authoring tool; existing scenes are skipped, never overwritten.
## Run with godot --headless --path prototypes/godot-kit --script res://tools/make_ui_layouts.gd.
## Layouts are static editable starting points; consuming games wire signals and hotkeys.

const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const UiTheme = preload("res://addons/proto_kit/ui/ui_theme.gd")
const THEME_DIRECTORY: String = "res://addons/proto_kit/ui/themes/"
const DIRECTORY: String = "res://addons/proto_kit/ui/layouts/"
const REQUIRED: Dictionary = {
	"idle_split_panel": ["Stage", "ProgressTrack", "Tabs", "SpeedButton"],
	"tabbed_modal": ["PrevTab", "NextTab", "Tabs", "Scroll", "Close"],
	"card_draft": ["Title", "Cards", "Reroll", "Banish", "Detail"],
	"settings_list": ["Tabs", "Rows", "Back", "Reset"],
	"quest_list": ["Count", "Sections", "RowTemplate"],
	"hud_arpg": ["Portrait", "HpBar", "WaveBar", "Timer", "SkillBar", "AutoWeapon", "AutoSkill"],
	"result_report": ["Stamp", "Rows", "Flavor", "Buttons"],
	"dialogue_portrait": ["Name", "Portrait", "Text", "Skip", "Next"]
}


func _initialize() -> void:
	_generate.call_deferred()


func _generate() -> void:
	var ok: bool = ensure_themes()
	if not ok:
		quit(1)
		return
	for id: String in REQUIRED:
		var scene: Control = make_layout(id)
		var result: Dictionary = Builder.save_scene(scene, DIRECTORY + id + ".tscn")
		ok = bool(result.ok) and ok
	print("UI LAYOUTS GENERATED" if ok else "FAIL UI LAYOUT GENERATION")
	quit(0 if ok else 1)


static func ensure_themes() -> bool:
	DirAccess.make_dir_recursive_absolute(THEME_DIRECTORY)
	for id: String in UiTheme.ids():
		var path: String = THEME_DIRECTORY + id + ".tres"
		if FileAccess.file_exists(path):
			continue
		var error: Error = ResourceSaver.save(UiTheme.build(id), path)
		if error != OK:
			push_error("Cannot save shared theme: " + path)
			return false
	return true


static func _add(parent: Node, child: Control, node_name: String = "", unique: bool = false) -> Control:
	if unique:
		Builder.unique(child)
	return Builder.add(parent, child, node_name) as Control


static func _label(parent: Node, text: String, node_name: String = "", variant: String = "", unique: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = variant
	_add(parent, label, node_name, unique)
	return label


static func _button(parent: Node, text: String, node_name: String = "", height: float = 48.0, unique: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(parent, button, node_name, unique)
	return button


static func _bar(parent: Node, node_name: String, value: float, unique: bool = true) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.value = value
	bar.custom_minimum_size.y = 28
	bar.show_percentage = false
	_add(parent, bar, node_name, unique)
	return bar


static func _vbox(parent: Node, node_name: String = "", unique: bool = false) -> VBoxContainer:
	return _add(parent, VBoxContainer.new(), node_name, unique) as VBoxContainer


static func _hbox(parent: Node, node_name: String = "", unique: bool = false) -> HBoxContainer:
	return _add(parent, HBoxContainer.new(), node_name, unique) as HBoxContainer


static func _panel(parent: Node, node_name: String = "", unique: bool = false) -> VBoxContainer:
	var panel := _add(parent, PanelContainer.new(), node_name, unique)
	return _vbox(panel, "Content")


static func _scroll(parent: Node, node_name: String, unique: bool = true) -> VBoxContainer:
	var scroll := _add(parent, ScrollContainer.new(), node_name, unique) as ScrollContainer
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := _vbox(scroll, "Content")
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return content


static func _tabs(parent: Node, names: Array[String]) -> TabBar:
	var scroll := _add(parent, ScrollContainer.new(), "TabScroller") as ScrollContainer
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var tabs := _add(scroll, TabBar.new(), "Tabs", true) as TabBar
	tabs.custom_minimum_size.y = 48
	tabs.clip_tabs = false
	for title: String in names:
		tabs.add_tab(title)
	return tabs


static func make_layout(id: String) -> Control:
	var scene := Control.new()
	scene.name = id.to_pascal_case()
	scene.size = Vector2(390, 844)
	scene.theme = load(THEME_DIRECTORY + "dark_gothic.tres") as Theme
	scene.set_meta("ui_layout_id", id)
	var backdrop := _add(scene, Panel.new(), "Backdrop")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _add(scene, MarginContainer.new(), "SafeMargin") as MarginContainer
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var body := _vbox(margin, "Body")
	match id:
		"idle_split_panel": _idle(body)
		"tabbed_modal": _modal(body)
		"card_draft": _draft(body)
		"settings_list": _settings(body)
		"quest_list": _quests(body)
		"hud_arpg": _hud(body)
		"result_report": _result(body)
		"dialogue_portrait": _dialogue(body)
	Builder.own_nodes(scene)
	scene.set_meta("authored_node_count", Builder.count_nodes(scene))
	return scene


static func _idle(body: VBoxContainer) -> void:
	var heading := _hbox(body, "Heading")
	_label(heading, "迷霧林地", "HeadingText", "TitleLabel")
	var speed := _button(heading, "×2", "SpeedButton", 48, true)
	speed.size_flags_horizontal = Control.SIZE_SHRINK_END
	speed.custom_minimum_size.x = 72
	var stage := _panel(body, "Stage", true)
	(stage.get_parent() as Control).custom_minimum_size.y = 240
	(stage.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(stage, "第 03 關 · 林地守衛", "StageTitle", "CaptionLabel")
	var actors := _hbox(stage, "Actors")
	actors.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(actors, "◆\n勇者", "Hero")
	_label(actors, "✦\n守衛", "Enemy")
	_bar(body, "ProgressTrack", 62)
	var tabs := _add(body, TabContainer.new(), "Tabs", true) as TabContainer
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 300
	for title: String in ["屬性", "技能!", "裝備", "背包"]:
		var page := _vbox(tabs, title)
		if title == "屬性":
			_label(page, "戰力 1,280", "Power", "TitleLabel")
			_label(page, "攻擊 128\n生命 960\n護甲 42", "Stats")
		else:
			var grid := _add(page, GridContainer.new(), "Slots") as GridContainer
			grid.columns = 3
			for index: int in range(6):
				_button(grid, "◆" if index < 3 else "＋", "Slot%d" % index, 72)


static func _modal(body: VBoxContainer) -> void:
	var heading := _hbox(body, "Heading")
	_label(heading, "收藏圖鑑", "Title", "TitleLabel")
	var close := _button(heading, "×", "Close", 48, true)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size.x = 48
	var navigation := _hbox(body, "TabNavigation")
	_button(navigation, "‹ Q", "PrevTab", 48, true)
	_button(navigation, "E ›", "NextTab", 48, true)
	_tabs(body, ["角色!", "武器", "收藏", "成就"])
	var content := _scroll(body, "Scroll")
	_label(content, "已發現 3 / 8", "Found", "CaptionLabel")
	for index: int in range(8):
		var row := _panel(content, "Entry%d" % index)
		_label(row, "旅人 %02d" % (index + 1) if index < 3 else "鎖定 · 未知旅人", "Name")
		_label(row, "完成冒險目標以解鎖", "Description", "CaptionLabel")


static func _draft(body: VBoxContainer) -> void:
	_label(body, "新等級 12", "Title", "TitleLabel", true)
	_label(body, "選擇一項強化", "Subtitle", "CaptionLabel")
	var cards := _vbox(body, "Cards", true)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index: int in range(3):
		var card := _button(cards, ["烈焰斬 · Lv.2", "生命強化 · +20%", "疾風步 · Lv.1"][index], "Card%d" % index, 112)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := _hbox(body, "Actions")
	_button(actions, "重抽 ·3", "Reroll", 96, true)
	_button(actions, "放逐 ·1", "Banish", 96, true)
	var detail := _panel(body, "Detail", true)
	_label(detail, "烈焰斬", "Name")
	_label(detail, "目前 120 → 購買後 156\n火焰分支 2 / 3", "Description", "CaptionLabel")


static func _settings(body: VBoxContainer) -> void:
	_label(body, "設定", "Title", "TitleLabel")
	_tabs(body, ["遊戲", "音效", "畫面"])
	var rows := _scroll(body, "SettingsScroll")
	var entries := _vbox(rows, "Rows", true)
	for index: int in range(2):
		var row := _hbox(entries, "Setting%d" % index)
		row.custom_minimum_size.y = 96
		_label(row, ["語言", "畫質"][index], "Name")
		_button(row, "‹", "Previous", 96)
		_label(row, ["繁中", "高"][index], "Value")
		_button(row, "›", "Next", 96)
	var audio := _vbox(entries, "VolumeRow")
	audio.custom_minimum_size.y = 96
	_label(audio, "音樂 · 70%", "Name")
	var slider := _add(audio, HSlider.new(), "Volume") as HSlider
	slider.value = 70
	slider.custom_minimum_size.y = 48
	var buttons := _hbox(body, "Actions")
	_button(buttons, "返回", "Back", 96, true)
	_button(buttons, "重設", "Reset", 96, true)


static func _quests(body: VBoxContainer) -> void:
	var heading := _hbox(body, "Heading")
	_label(heading, "冒險目標", "Title", "TitleLabel")
	var count := _label(heading, "0 / 12", "Count", "CaptionLabel", true)
	count.size_flags_horizontal = Control.SIZE_SHRINK_END
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	var sections := _scroll(body, "QuestScroll")
	sections.name = "Sections"
	Builder.unique(sections)
	for index: int in range(2):
		_label(sections, "Fracture %d+" % index, "Tier%d" % index, "CaptionLabel")
		var row := _panel(sections, "RowTemplate" if index == 0 else "LockedRow", index == 0)
		var top := _hbox(row, "Heading")
		_label(top, "林地獵手" if index == 0 else "深層試煉", "Title")
		_label(top, "◆", "Reward")
		_label(row, "單局擊敗 100 個敵人" if index == 0 else "難度 1 解鎖", "Description", "CaptionLabel")
		var bar := _bar(row, "Progress", 35 if index == 0 else 0, false)
		bar.visible = index == 0
		_label(row, "35 / 100" if index == 0 else "鎖定 · 0 / 1", "Count", "CaptionLabel")


static func _hud(body: VBoxContainer) -> void:
	var top := _hbox(body, "Top")
	_label(top, "◆", "Portrait", "TitleLabel", true)
	var health := _vbox(top, "Health")
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(health, "旅人 · Lv.12", "Name", "CaptionLabel")
	_bar(health, "HpBar", 78)
	_label(body, "第 03 層 · 02:48", "Timer", "CaptionLabel", true)
	_bar(body, "WaveBar", 42)
	_label(body, "限時目標 · 擊敗守衛 0/1", "Objective", "CaptionLabel")
	var arena := _panel(body, "Arena")
	(arena.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(arena, "迷霧林地", "Area", "TitleLabel")
	var space := _label(arena, "✦     ◆     ✦", "Actors")
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	space.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var skills := _add(body, GridContainer.new(), "SkillBar", true) as GridContainer
	skills.columns = 3
	for index: int in range(6):
		_button(skills, ["斬擊", "火球", "閃避", "旋風", "護盾", "治療"][index], "Skill%d" % index, 72)
	var controls := _hbox(body, "AutoControls")
	var spacer := _add(controls, Control.new(), "Spacer")
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in ["AutoWeapon", "AutoSkill"]:
		var toggle := _button(controls, "武" if id == "AutoWeapon" else "技", id, 64, true)
		toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
		toggle.tooltip_text = "自動武器" if id == "AutoWeapon" else "自動技能"
		toggle.toggle_mode = true
		toggle.button_pressed = true
		toggle.custom_minimum_size.x = 64
		toggle.theme_type_variation = "RoundButton"


static func _result(body: VBoxContainer) -> void:
	_label(body, "冒險戰報", "Title", "TitleLabel")
	var stamp := _label(body, "勝利", "Stamp", "TitleLabel", true)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.custom_minimum_size.y = 120
	var rows := _panel(body, "Rows", true)
	(rows.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	for values: Array in [["到達層數", "03"], ["擊敗敵人", "128"], ["存活時間", "02:48"], ["獲得金幣", "+360"]]:
		var row := _hbox(rows, "Row")
		_label(row, values[0], "Field", "CaptionLabel")
		var value := _label(row, values[1], "Value")
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(body, "風停之後，旅途仍在繼續。", "Flavor", "CaptionLabel", true)
	var buttons := _hbox(body, "Buttons", true)
	_button(buttons, "營地", "Camp", 96)
	_button(buttons, "再出發", "Retry", 96)


static func _dialogue(body: VBoxContainer) -> void:
	var stage := _panel(body, "Stage")
	(stage.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(stage, "林間小徑", "Place", "TitleLabel")
	var portrait_row := _hbox(body, "PortraitRow")
	_label(portrait_row, "旅人", "Name", "", true)
	var portrait := _label(portrait_row, "◇", "Portrait", "TitleLabel", true)
	portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	portrait.custom_minimum_size.y = 72
	var dialogue := _panel(body, "Dialogue")
	_label(dialogue, "前方就是林地的出口。\n準備好了，我們就出發吧。", "Text", "", true)
	var actions := _hbox(dialogue, "Actions")
	_button(actions, "略過", "Skip", 48, true)
	_button(actions, "繼續 ›", "Next", 64, true)
