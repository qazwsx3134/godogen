extends SceneTree
## Authoring tool for the game shell (ui/theme.tres look). Applied 2026-10-22. Writes:
##   scenes/app.tscn             the App autoload: the fade between screens
##   scenes/settings_panel.tscn  設定: 音效 slider, 震動 toggle, 關閉
##   scenes/stage_row.tscn       one 關卡 in the list: label, boss, region, state
##   scenes/march_view.tscn      the 營地's idle 行軍 view (scrolling layers, the 行軍小隊, a monster, popups)
##   scenes/reward_row.tscn      one line of a reward list: icon on its rarity colour, name, amount
##   scenes/camp.tscn            營地 page: gold and shards, 設定, title, the 行軍 view with its hours, countdown and
##                               領取, the next stage card (boss, 戰力／推薦, 推王), the 離線戰報 (also 行軍收穫 after a
##                               領取: the rewards listed by section) and settings overlays
##   scenes/stages.tscn          關卡 page: every stage by region (stage_row.tscn instances)
##   scenes/home.tscn            the main screen: the 營地, 養成 (growth.tscn), 招募 (recruit.tscn), 道具 (items.tscn)
##                               and 關卡 pages above the nav bar (an icon over each name, assets/ui/nav when made)
## It overwrites them: run it again only after checking that none was edited by hand since. Headless is fine:
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_shell.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const APP := "res://scenes/app.tscn"
const SETTINGS := "res://scenes/settings_panel.tscn"
const ROW := "res://scenes/stage_row.tscn"
const CAMP := "res://scenes/camp.tscn"
const STAGES := "res://scenes/stages.tscn"
const MARCH_VIEW := "res://scenes/march_view.tscn"
const BOSS := "res://assets/stage/boss.png"
const HOME := "res://scenes/home.tscn"
const GROWTH := "res://scenes/growth.tscn"
const ITEMS := "res://scenes/items.tscn"
const RECRUIT := "res://scenes/recruit.tscn"
const REWARD_ROW := "res://scenes/reward_row.tscn"
const NAV_ICONS := "res://assets/ui/nav/%s.png"
## Height of the nav bar at the bottom of home.tscn.
const NAV_H := 116
const THEME := "res://ui/theme.tres"
const BG := "res://assets/ui/hero_page_bg.png"
const TEXT := Color("ece6dc")
const GOLD := Color("d9b26e")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_app(), APP, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_settings(), SETTINGS, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_row(), ROW, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_march_view(), MARCH_VIEW, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_reward_row(), REWARD_ROW, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_camp(), CAMP, {"overwrite": true, "expected_refs": [SETTINGS, MARCH_VIEW]}).ok
	ok = ok and SceneBuilder.save_scene(_stages(), STAGES, {"overwrite": true, "expected_refs": [ROW]}).ok
	ok = ok and SceneBuilder.save_scene(_home(), HOME, {"overwrite": true, "expected_refs": [CAMP, GROWTH, RECRUIT, ITEMS, STAGES]}).ok
	quit(0 if ok else 1)


func _app() -> CanvasLayer:
	var app := CanvasLayer.new()
	app.name = "App"
	app.set_script(load("res://scripts/app.gd"))
	app.layer = 100
	var fade := ColorRect.new()
	fade.color = Color("0b1210")
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(app, SceneBuilder.unique(fade), "Fade")
	return app


func _settings() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.set_script(load("res://scripts/settings_panel.gd"))
	panel.theme = load(THEME)
	panel.custom_minimum_size = Vector2(560, 0)
	var col := SceneBuilder.add(panel, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 18)
	SceneBuilder.add(col, _label("設定", 40, TEXT, &"Heading"), "Title")
	SceneBuilder.add(col, HSeparator.new(), "Rule")
	var sfx_row := SceneBuilder.add(col, HBoxContainer.new(), "SfxRow") as HBoxContainer
	sfx_row.add_theme_constant_override(&"separation", 16)
	SceneBuilder.add(sfx_row, _label("音效", 28, TEXT), "Title")
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = 0.8
	slider.custom_minimum_size = Vector2(0, 56)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(sfx_row, SceneBuilder.unique(slider), "SfxSlider")
	var value := _label("80%", 26, GOLD, &"Heading")
	value.custom_minimum_size = Vector2(80, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(sfx_row, SceneBuilder.unique(value), "SfxValue")
	var haptic_row := SceneBuilder.add(col, HBoxContainer.new(), "HapticsRow") as HBoxContainer
	var haptic_title := _label("震動", 28, TEXT)
	haptic_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(haptic_row, haptic_title, "Title")
	var haptics := CheckButton.new()
	haptics.text = "開"
	haptics.button_pressed = true
	haptics.custom_minimum_size = Vector2(160, 64)
	haptics.add_theme_font_size_override(&"font_size", 26)
	SceneBuilder.add(haptic_row, SceneBuilder.unique(haptics), "Haptics")
	# 畫質 and 幀率: one pressed choice each (settings_panel.gd keeps them in step with the settings).
	for spec: Array in [["Quality", "畫質", ["省電", "標準", "高"], 1], ["Fps", "幀率", ["30", "60"], 1]]:
		var row := SceneBuilder.add(col, HBoxContainer.new(), spec[0] + "Row") as HBoxContainer
		row.add_theme_constant_override(&"separation", 16)
		var title := _label(spec[1], 28, TEXT)
		title.custom_minimum_size = Vector2(80, 0)
		SceneBuilder.add(row, title, "Title")
		var choices := HBoxContainer.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.add_theme_constant_override(&"separation", 8)
		SceneBuilder.add(row, SceneBuilder.unique(choices), spec[0] + "Choices")
		for k: int in spec[2].size():
			var choice := Button.new()
			choice.text = spec[2][k]
			choice.toggle_mode = true
			choice.button_pressed = k == spec[3]
			choice.custom_minimum_size = Vector2(0, 64)
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			choice.add_theme_font_size_override(&"font_size", 24)
			SceneBuilder.add(choices, choice, "Choice_%d" % k)
	var close := Button.new()
	close.text = "關閉"
	close.custom_minimum_size = Vector2(0, 84)
	SceneBuilder.add(col, SceneBuilder.unique(close), "Close")
	return panel


## One line of a reward list: the icon on a rarity-coloured square, the name, the amount.
func _reward_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "RewardRow"
	row.set_script(load("res://scripts/reward_row.gd"))
	row.theme = load(THEME)
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override(&"separation", 10)
	var bg := ColorRect.new()
	bg.custom_minimum_size = Vector2(52, 52)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bg.color = Color("2c3530")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(row, SceneBuilder.unique(bg), "IconBg")
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4.0
	icon.offset_top = 4.0
	icon.offset_right = -4.0
	icon.offset_bottom = -4.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load("res://assets/ui/items/m_gold.png")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(bg, SceneBuilder.unique(icon), "Icon")
	var title := _label("金幣", 22, TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	SceneBuilder.add(row, SceneBuilder.unique(title), "RowName")
	var amount := _label("+1280", 26, GOLD, &"Heading")
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(row, SceneBuilder.unique(amount), "Amount")
	return row


func _row() -> Button:
	var row := Button.new()
	row.name = "StageRow"
	row.set_script(load("res://scripts/stage_row.gd"))
	row.theme = load(THEME)
	row.theme_type_variation = &"CardButton"
	row.toggle_mode = true
	row.custom_minimum_size = Vector2(0, 104)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 20.0
	box.offset_right = -20.0
	box.add_theme_constant_override(&"separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(row, box, "Row")
	var label := _label("1-1", 44, GOLD, &"Heading")
	label.custom_minimum_size = Vector2(96, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(box, SceneBuilder.unique(label), "StageLabel")
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override(&"separation", 0)
	SceneBuilder.add(box, names, "Names")
	SceneBuilder.add(names, SceneBuilder.unique(_label("棍棒巨魔", 30, TEXT, &"Heading")), "BossName")
	SceneBuilder.add(names, SceneBuilder.unique(_label("首通獎勵　金幣 +1500　突破素材 +2", 20, TEXT, &"Dim")), "Note")
	var state := _label("挑戰", 26, GOLD)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(box, SceneBuilder.unique(state), "StateLabel")
	return row


func _camp() -> Control:
	var root := Control.new()
	root.name = "Camp"
	root.set_script(load("res://scripts/camp.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = load(BG)
	SceneBuilder.add(root, bg, "Background")
	SceneBuilder.add(root, _shade(), "Shade")

	var margins := _margins(32, 40, 32, 36)
	SceneBuilder.add(root, margins, "Margins")
	var col := SceneBuilder.add(margins, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 16)
	var top := SceneBuilder.add(col, HBoxContainer.new(), "Top") as HBoxContainer
	top.add_theme_constant_override(&"separation", 10)
	var gold_title := _label("金幣", 20, TEXT, &"Dim")
	gold_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(top, gold_title, "GoldTitle")
	SceneBuilder.add(top, SceneBuilder.unique(_label("1280", 32, GOLD, &"Heading")), "Gold")
	var shard_title := _label("突破素材", 20, TEXT, &"Dim")
	shard_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(top, shard_title, "ShardsTitle")
	SceneBuilder.add(top, SceneBuilder.unique(_label("3", 32, GOLD, &"Heading")), "Shards")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(top, spacer, "Spacer")
	var settings_button := Button.new()
	settings_button.text = "設定"
	settings_button.custom_minimum_size = Vector2(120, 64)
	settings_button.add_theme_font_size_override(&"font_size", 26)
	SceneBuilder.add(top, SceneBuilder.unique(settings_button), "SettingsButton")

	var title := _label("全員推王", 60, TEXT, &"Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_outline_color", Color(0.02, 0.04, 0.03))
	title.add_theme_constant_override(&"outline_size", 10)
	SceneBuilder.add(col, title, "Title")

	# The march squad, marching in real time: the idle view, then its hours and 領取.
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"Pill"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(col, frame, "MarchFrame")
	var view: Control = SceneBuilder.instance(MARCH_VIEW)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(frame, SceneBuilder.unique(view), "MarchView")
	var march := PanelContainer.new()
	SceneBuilder.add(col, march, "MarchPanel")
	var march_col := SceneBuilder.add(march, VBoxContainer.new(), "Column") as VBoxContainer
	march_col.add_theme_constant_override(&"separation", 8)
	var march_top := SceneBuilder.add(march_col, HBoxContainer.new(), "Top") as HBoxContainer
	march_top.add_theme_constant_override(&"separation", 12)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	SceneBuilder.add(march_top, lines, "Lines")
	SceneBuilder.add(lines, SceneBuilder.unique(_label("已累積 3 小時（上限 8）", 24, TEXT)), "MarchLine")
	SceneBuilder.add(lines, SceneBuilder.unique(_label("下一小時 42:10", 20, TEXT, &"Dim")), "MarchNext")
	var claim := Button.new()
	claim.theme_type_variation = &"PrimaryButton"
	claim.text = "領取 3 小時"
	claim.custom_minimum_size = Vector2(200, 72)
	claim.add_theme_font_size_override(&"font_size", 26)
	SceneBuilder.add(march_top, SceneBuilder.unique(claim), "Claim")
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"ExpBar"
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	bar.value = 30.0
	SceneBuilder.add(march_col, SceneBuilder.unique(bar), "MarchBar")
	var toast := _label("", 20, Color("9fd08f"))
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(march_col, SceneBuilder.unique(toast), "MarchToast")
	# 待辦: what can be done now (camp.gd fills up to three rows).
	var todo := PanelContainer.new()
	SceneBuilder.add(col, SceneBuilder.unique(todo), "TodoPanel")
	var todo_col := SceneBuilder.add(todo, VBoxContainer.new(), "Column") as VBoxContainer
	todo_col.add_theme_constant_override(&"separation", 2)
	SceneBuilder.add(todo_col, _label("待辦", 22, TEXT, &"Dim"), "Title")
	var todo_list := SceneBuilder.add(todo_col, SceneBuilder.unique(VBoxContainer.new()), "TodoList") as VBoxContainer
	todo_list.add_theme_constant_override(&"separation", 0)
	for text: String in ["•  行軍累積了 3 小時，可以領取", "•  劍 職業等級可以升到 19（370 金）", "•  行軍小隊有英雄可以突破（1 素材）"]:
		var row := Button.new()
		row.theme_type_variation = &"FlatButton"
		row.text = text
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 48)
		row.add_theme_font_size_override(&"font_size", 23)
		SceneBuilder.add(todo_list, row, "Todo_%d" % (todo_list.get_child_count() + 1))
	# The next stage: its boss, how strong the heroes are against what it asks, 推王.
	var card := PanelContainer.new()
	SceneBuilder.add(col, card, "NextCard")
	var card_row := SceneBuilder.add(card, HBoxContainer.new(), "Row") as HBoxContainer
	card_row.add_theme_constant_override(&"separation", 16)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(150, 150)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.flip_h = true
	thumb.texture = _boss_cell()
	SceneBuilder.add(card_row, SceneBuilder.unique(thumb), "BossThumb")
	var card_col := SceneBuilder.add(card_row, VBoxContainer.new(), "Column") as VBoxContainer
	card_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_col.add_theme_constant_override(&"separation", 6)
	SceneBuilder.add(card_col, SceneBuilder.unique(_label("黃昏要塞", 22, TEXT, &"Dim")), "RegionName")
	var stage_row := SceneBuilder.add(card_col, HBoxContainer.new(), "StageRow") as HBoxContainer
	stage_row.add_theme_constant_override(&"separation", 14)
	SceneBuilder.add(stage_row, SceneBuilder.unique(_label("1-1", 52, GOLD, &"Heading")), "StageLabel")
	var boss := _label("棍棒巨魔", 36, TEXT, &"Heading")
	boss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(stage_row, SceneBuilder.unique(boss), "BossName")
	SceneBuilder.add(card_col, SceneBuilder.unique(_label("我方戰力 870 ／ 推薦 950", 22, TEXT)), "PowerLine")
	var push := Button.new()
	push.theme_type_variation = &"PrimaryButton"
	push.text = "推王"
	push.custom_minimum_size = Vector2(0, 92)
	push.add_theme_font_size_override(&"font_size", 42)
	SceneBuilder.add(card_col, SceneBuilder.unique(push), "Push")
	# 離線戰報: shown on arrival when march hours are banked.
	var offline := _overlay()
	SceneBuilder.add(root, SceneBuilder.unique(offline), "OfflineReport")
	var offline_center := CenterContainer.new()
	offline_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(offline, offline_center, "Center")
	var offline_panel := PanelContainer.new()
	offline_panel.theme_type_variation = &"Dialog"
	offline_panel.custom_minimum_size = Vector2(620, 0)
	SceneBuilder.add(offline_center, offline_panel, "Panel")
	var offline_col := SceneBuilder.add(offline_panel, VBoxContainer.new(), "Column") as VBoxContainer
	offline_col.add_theme_constant_override(&"separation", 16)
	var offline_title := _label("離線戰報", 44, TEXT, &"Heading")
	offline_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(offline_col, SceneBuilder.unique(offline_title), "OfflineTitle")
	SceneBuilder.add(offline_col, HSeparator.new(), "Rule")
	var offline_text := _label("你不在的時候，行軍小隊走了 3 小時。", 26, TEXT)
	offline_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	offline_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	offline_text.custom_minimum_size = Vector2(540, 0)
	SceneBuilder.add(offline_col, SceneBuilder.unique(offline_text), "OfflineText")
	# What came back, by section (camp.gd fills the grids with reward_row.tscn lines after 領取).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	SceneBuilder.add(offline_col, SceneBuilder.unique(scroll), "OfflineScroll")
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(scroll, sections, "Sections")
	for spec: Array in [["Resources", "資源"], ["Gear", "裝備"], ["Heroes", "英雄升級"]]:
		var section := VBoxContainer.new()
		section.add_theme_constant_override(&"separation", 6)
		SceneBuilder.add(sections, SceneBuilder.unique(section), spec[0] + "Section")
		SceneBuilder.add(section, _label(spec[1], 22, TEXT, &"Dim"), "Title")
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 12)
		grid.add_theme_constant_override(&"v_separation", 8)
		SceneBuilder.add(section, SceneBuilder.unique(grid), spec[0] + "Grid")
		if spec[0] == "Resources":
			for k: int in 2:
				var preview: Control = SceneBuilder.instance(REWARD_ROW)
				preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				SceneBuilder.add(grid, preview, "Preview_%d" % k)
	var offline_claim := Button.new()
	offline_claim.theme_type_variation = &"PrimaryButton"
	offline_claim.text = "領取"
	offline_claim.custom_minimum_size = Vector2(0, 96)
	offline_claim.add_theme_font_size_override(&"font_size", 34)
	SceneBuilder.add(offline_col, SceneBuilder.unique(offline_claim), "OfflineClaim")
	# 看廣告: the claim's gold once more (shown after 領取, camp.gd).
	var offline_ad := Button.new()
	offline_ad.text = "看廣告　金幣再領一次"
	offline_ad.custom_minimum_size = Vector2(0, 72)
	offline_ad.add_theme_font_size_override(&"font_size", 26)
	offline_ad.visible = false
	SceneBuilder.add(offline_col, SceneBuilder.unique(offline_ad), "OfflineAd")

	var settings := _overlay()
	SceneBuilder.add(root, SceneBuilder.unique(settings), "SettingsOverlay")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(settings, center, "Center")
	SceneBuilder.add(center, SceneBuilder.unique(SceneBuilder.instance(SETTINGS)), "SettingsPanel")
	return root


## The boss's idle cell (the 營地's next-stage card and the 行軍 view's monster).
func _boss_cell() -> AtlasTexture:
	var cell := AtlasTexture.new()
	cell.atlas = load(BOSS)
	cell.region = Rect2(0, 0, 200, 200)
	return cell


## The 營地's idle 行軍 view (march_view.gd moves everything; this is the layout and an editor preview).
func _march_view() -> Control:
	const GROUND := 92.0
	## The band above the ground the heroes, the monster and the trees stand in (anchored to the bottom, so the view
	## can be any height).
	const FIELD := 230.0
	var root := Control.new()
	root.name = "MarchView"
	root.set_script(load("res://scripts/march_view.gd"))
	root.theme = load(THEME)
	root.clip_contents = true
	root.custom_minimum_size = Vector2(0, 300)
	root.size = Vector2(656, 420)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var far := TextureRect.new()
	far.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	far.offset_bottom = -GROUND
	far.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	far.texture = load(BG)
	far.material = _scroll_material(load(BG), Vector2(2.3, 1.0), true)
	far.self_modulate = Color(1.7, 1.75, 1.7)
	far.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(far), "Far")
	var props := _band(-GROUND - FIELD, -GROUND + 10.0)
	SceneBuilder.add(root, SceneBuilder.unique(props), "Props")
	for spec: Array in [["pine", 40.0, 0.85], ["boulder", 260.0, 1.0], ["oak", 380.0, 0.8], ["pine", 600.0, 0.7]]:
		var prop := TextureRect.new()
		var tex: Texture2D = load("res://assets/stage/props/%s.png" % spec[0])
		prop.texture = tex
		prop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.size = Vector2(tex.get_width(), tex.get_height()) * spec[2]
		prop.position = Vector2(spec[1], FIELD + 10.0 - prop.size.y)
		prop.modulate = Color(0.75, 0.82, 0.78)
		prop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SceneBuilder.add(props, prop, "Prop_%d" % props.get_child_count())
	var ground := TextureRect.new()
	ground.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -GROUND
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grass: Texture2D = load("res://assets/stage/grass.png")
	ground.texture = grass
	ground.material = _scroll_material(grass, Vector2(656.0 / 192.0, GROUND / 192.0), false)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(ground), "Ground")
	# The fight: heroes, the monster, its HP bar and the popups share the band's coordinates.
	var field := _band(-GROUND - FIELD, -GROUND + 12.0)
	SceneBuilder.add(root, field, "Field")
	var heroes := Control.new()
	heroes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heroes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(field, SceneBuilder.unique(heroes), "Heroes")
	for k: int in 5:
		var hero := TextureRect.new()
		hero.size = Vector2(120, 120)
		hero.position = Vector2(320.0 - k * 74.0, FIELD + 12.0 - 124.0 + (k % 2) * 12.0)
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cell := AtlasTexture.new()
		cell.atlas = load("res://assets/heroes/heroes.png")
		cell.region = Rect2((k % 4) * 48, [1, 0, 2, 3, 4][k] * 48, 48, 48)
		hero.texture = cell
		hero.material = load("res://materials/ui_sprite_dark.tres")
		hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SceneBuilder.add(heroes, hero, "Hero_%d" % (k + 1))
	var enemy := TextureRect.new()
	enemy.size = Vector2(150, 150)
	enemy.position = Vector2(470, FIELD + 12.0 - 152.0)
	enemy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy.flip_h = true
	enemy.texture = _boss_cell()
	enemy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(field, SceneBuilder.unique(enemy), "Enemy")
	var hp := ProgressBar.new()
	hp.theme_type_variation = &"HpBar"
	hp.size = Vector2(90, 10)
	hp.position = Vector2(500, FIELD + 12.0 - 166.0)
	hp.show_percentage = false
	hp.value = 60.0
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(field, SceneBuilder.unique(hp), "EnemyHp")
	var popups := Control.new()
	popups.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(field, SceneBuilder.unique(popups), "Popups")
	for k: int in 6:
		var popup := _label("128", 26, TEXT, &"FieldLabel")
		popup.add_theme_constant_override(&"outline_size", 8)
		popup.position = Vector2(480 + k * 20, 40)
		SceneBuilder.add(popups, popup, "Popup_%d" % (k + 1))
	var region := _label("行軍中‧黃昏要塞", 22, TEXT, &"FieldLabel")
	region.add_theme_constant_override(&"outline_size", 8)
	region.position = Vector2(14, 10)
	SceneBuilder.add(root, SceneBuilder.unique(region), "RegionLabel")
	var kills := _label("擊倒 0", 22, GOLD, &"FieldLabel")
	kills.add_theme_constant_override(&"outline_size", 8)
	kills.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kills.offset_left = -160.0
	kills.offset_right = -14.0
	kills.offset_top = 10.0
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(root, SceneBuilder.unique(kills), "KillLabel")
	return root


## A band across the bottom of the view, from `top` to `bottom` pixels off the bottom edge.
func _band(top: float, bottom: float) -> Control:
	var band := Control.new()
	band.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = top
	band.offset_bottom = bottom
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return band


func _scroll_material(tex: Texture2D, tiles: Vector2, mirror: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ui_scroll.gdshader")
	material.set_shader_parameter(&"tex", tex)
	material.set_shader_parameter(&"tiles", tiles)
	material.set_shader_parameter(&"mirror", mirror)
	return material


func _stages() -> Control:
	var root := Control.new()
	root.name = "Stages"
	root.set_script(load("res://scripts/stages.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = load(BG)
	SceneBuilder.add(root, bg, "Background")
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.08, 0.07, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, dim, "Dim")
	var margins := _margins(28, 40, 28, 20)
	SceneBuilder.add(root, margins, "Margins")
	var col := SceneBuilder.add(margins, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 12)
	SceneBuilder.add(col, _label("關卡", 48, TEXT, &"Heading"), "Title")
	SceneBuilder.add(col, HSeparator.new(), "Rule")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SceneBuilder.add(col, scroll, "Scroll")
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(scroll, SceneBuilder.unique(list), "StageList")
	SceneBuilder.add(list, _label("黃昏要塞", 24, TEXT, &"Dim"), "PreviewRegion")
	for k: int in 3:
		SceneBuilder.add(list, SceneBuilder.instance(ROW), "Preview_%d" % (k + 1))
	return root


## The screen between pushes: the pages (營地, 養成, 關卡) above a nav bar that switches between them.
func _home() -> Control:
	var root := Control.new()
	root.name = "Home"
	root.set_script(load("res://scripts/home.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0f1a16")
	SceneBuilder.add(root, bg, "Background")
	var pages := Control.new()
	pages.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pages.offset_bottom = -NAV_H
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(pages), "Pages")
	for spec: Array in [["CampPage", CAMP], ["GrowthPage", GROWTH], ["RecruitPage", RECRUIT], ["ItemsPage", ITEMS],
			["StagesPage", STAGES]]:
		var page: Control = SceneBuilder.instance(spec[1])
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.visible = spec[0] == "CampPage"
		SceneBuilder.add(pages, SceneBuilder.unique(page), spec[0])
	var nav := PanelContainer.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -NAV_H
	SceneBuilder.add(root, SceneBuilder.unique(nav), "NavBar")
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 0)
	SceneBuilder.add(nav, SceneBuilder.unique(buttons), "NavButtons")
	for spec: Array in [["NavCamp", "營地", "camp"], ["NavGrowth", "養成", "growth"], ["NavRecruit", "招募", "recruit"],
			["NavItems", "道具", "items"], ["NavStages", "關卡", "stages"]]:
		var button := Button.new()
		button.theme_type_variation = &"TabButton"
		button.toggle_mode = true
		button.text = spec[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 26)
		if ResourceLoader.exists(NAV_ICONS % spec[2]):
			button.icon = load(NAV_ICONS % spec[2])
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override(&"icon_max_width", 46)
		else:
			button.add_theme_font_size_override(&"font_size", 30)
		SceneBuilder.add(buttons, SceneBuilder.unique(button), spec[0])
		# The red dot: something to do on that page (home.gd).
		var dot := ColorRect.new()
		dot.color = Color("d9735a")
		dot.set_anchors_preset(Control.PRESET_CENTER_TOP)
		dot.offset_left = 40.0
		dot.offset_right = 54.0
		dot.offset_top = 22.0
		dot.offset_bottom = 36.0
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		SceneBuilder.add(button, dot, "Dot")
	return root


## A full-screen layer that dims what is under it and takes every tap.
func _overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.03, 0.75)
	SceneBuilder.add(overlay, dim, "Dim")
	overlay.visible = false
	return overlay


func _shade() -> TextureRect:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := Gradient.new()
	fade.set_color(0, Color(0.06, 0.1, 0.09, 0.35))
	fade.set_color(1, Color(0.06, 0.1, 0.09, 0.95))
	fade.add_point(0.4, Color(0.06, 0.1, 0.09, 0.1))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128
	shade.texture = texture
	return shade


func _margins(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := MarginContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override(&"margin_left", left)
	box.add_theme_constant_override(&"margin_top", top)
	box.add_theme_constant_override(&"margin_right", right)
	box.add_theme_constant_override(&"margin_bottom", bottom)
	return box


func _gap(parent: Node, height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(parent, gap, "Gap")


func _label(value: String, size: int, color: Color, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override(&"font_size", size)
	if variation != &"Dim":
		label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
