extends SceneTree
## Authoring tool for the 養成 screen in the 墨綠暖白 look (ui/theme.tres; the roster after
## art_src/ui_concepts/revision_d/growth_roster.png, the hero page after detail_refinement_v2/hero_detail.png). Applied
## 2026-10-22 over the earlier growth.tscn and hero_card.tscn. It overwrites scenes/hero_card.tscn, hero_page.tscn and
## growth.tscn: run it again only after checking that none of them was edited by hand since. growth.tscn holds no
## MultiMesh, so this one can run headless:
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_growth.gd
## hero_card.tscn  one hero: rarity as the background colour, class icon, 行／長 chips, a red dot, the picture, Lv and ★
## hero_page.tscn  one hero's page: name, rarity and class, Lv / cap with EXP, 突破 ★, 強度, 設為隊長; the portrait; 招牌技
##                 (SSR) or 晉升 (N / R); 職業加成; the shard cost; 突破 and 派去行軍
## growth.tscn     the roster (gold, shards and 一鍵養成, 行軍小隊, class tabs, the class level panel, the hero grid)
##                 with hero_page.tscn over it; a page of home.tscn, above its nav bar

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PushSim = preload("res://domain/push_sim.gd")
const CARD := "res://scenes/hero_card.tscn"
const PAGE := "res://scenes/hero_page.tscn"
const GROWTH := "res://scenes/growth.tscn"
const THEME := "res://ui/theme.tres"
const PORTRAIT := "res://assets/heroes/portraits/sword.png"
## The painted backdrop (tools/pack_stage_art.py "ui"); a gradient until it exists.
const PAGE_BG := "res://assets/ui/hero_page_bg.png"
const HEROES := "res://assets/heroes/heroes.png"
const TEXT := Color("ece6dc")
const GOLD := Color("d9b26e")
const BRONZE := Color("c9a06a")
const MARCH := Color("9fd08f")
const LINE := Color("a9875a")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_card(), CARD, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_page(), PAGE, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_growth(), GROWTH, {"overwrite": true, "expected_refs": [CARD, PAGE]}).ok
	quit(0 if ok else 1)


func _card() -> Button:
	var card := Button.new()
	card.name = "HeroCard"
	card.set_script(load("res://scripts/hero_card.gd"))
	card.theme = load(THEME)
	card.theme_type_variation = &"CardButton"
	card.toggle_mode = true
	card.custom_minimum_size = Vector2(150, 210)
	card.size = card.custom_minimum_size
	# No frame: the rarity is the background; a selected card (a march slot) gets a warm white one.
	for state: StringName in [&"normal", &"hover", &"disabled", &"focus"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: StringName in [&"pressed", &"hover_pressed"]:
		card.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shade := Gradient.new()
	shade.set_color(0, Color(1.0, 1.0, 1.0))
	shade.set_color(1, Color(0.42, 0.42, 0.42))
	var shade_tex := GradientTexture2D.new()
	shade_tex.gradient = shade
	shade_tex.fill_from = Vector2(0.5, 0.0)
	shade_tex.fill_to = Vector2(0.5, 1.0)
	shade_tex.width = 4
	shade_tex.height = 64
	bg.texture = shade_tex
	bg.self_modulate = Color("b88a34")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(card, SceneBuilder.unique(bg), "Bg")
	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_bottom = 0.78
	portrait.offset_left = 8.0
	portrait.offset_top = 14.0
	portrait.offset_right = -8.0
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := AtlasTexture.new()
	sprite.atlas = load(HEROES)
	sprite.region = Rect2(4 * 48 + 4, 48 + 4, 40, 42)
	portrait.texture = sprite
	portrait.material = load("res://materials/ui_sprite_dark.tres")
	SceneBuilder.add(card, SceneBuilder.unique(portrait), "Portrait")
	var icon := TextureRect.new()
	icon.position = Vector2(6, 6)
	icon.size = Vector2(28, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = load("res://assets/ui/class/sword.png")
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(card, SceneBuilder.unique(icon), "ClassIcon")
	var chips := HBoxContainer.new()
	chips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chips.offset_left = -64.0
	chips.offset_right = -6.0
	chips.offset_top = 8.0
	chips.offset_bottom = 30.0
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override(&"separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(card, chips, "Chips")
	for spec: Array in [["MarchChip", "行", MARCH], ["CaptainChip", "長", GOLD]]:
		var badge := ColorRect.new()
		badge.color = Color(spec[2], 0.95)
		badge.custom_minimum_size = Vector2(24, 22)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		SceneBuilder.add(chips, SceneBuilder.unique(badge), spec[0])
		var text := _label(spec[1], 15, Color("1d201b"))
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		SceneBuilder.add(badge, text, "Text")
	# Lv and stars on a dark strip at the bottom.
	var strip := ColorRect.new()
	strip.color = Color(0.03, 0.04, 0.03, 0.55)
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -52.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(card, strip, "Strip")
	var level := _label("Lv.12", 21, TEXT, &"Heading")
	level.position = Vector2(8, 0)
	SceneBuilder.add(strip, SceneBuilder.unique(level), "Level")
	var stars := HBoxContainer.new()
	stars.position = Vector2(8, 26)
	stars.add_theme_constant_override(&"separation", 0)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(strip, stars, "Stars")
	SceneBuilder.add(stars, SceneBuilder.unique(_label("★★", 17, GOLD)), "StarsOn")
	SceneBuilder.add(stars, SceneBuilder.unique(_label("★★★", 17, Color(1, 1, 1, 0.22))), "StarsOff")
	# The red dot: this hero can be ascended now.
	var dot := ColorRect.new()
	dot.color = Color("d9735a")
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -10.0
	dot.offset_right = 6.0
	dot.offset_top = -6.0
	dot.offset_bottom = 10.0
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(card, SceneBuilder.unique(dot), "Dot")
	# The selected card's warm white frame, over the background (hero_card.gd shows it while pressed).
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = Color("ece6dc")
	border.set_border_width_all(4)
	border.set_corner_radius_all(4)
	frame.add_theme_stylebox_override(&"panel", border)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	SceneBuilder.add(card, SceneBuilder.unique(frame), "Frame")
	return card


func _page() -> Control:
	var page := Control.new()
	page.name = "HeroPage"
	page.set_script(load("res://scripts/hero_page.gd"))
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.theme = load(THEME)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture = _glow(Vector2(0.66, 0.3), Color("2b4136"), Color("0f1a16"), 0.75)
	if ResourceLoader.exists(PAGE_BG):
		bg.texture = load(PAGE_BG)
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	SceneBuilder.add(page, bg, "Background")
	# Darkens the lower page under the sections and buttons.
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := Gradient.new()
	fade.set_color(0, Color(0.06, 0.1, 0.09, 0.0))
	fade.set_color(1, Color(0.06, 0.1, 0.09, 0.92))
	fade.add_point(0.45, Color(0.06, 0.1, 0.09, 0.0))
	var fade_tex := GradientTexture2D.new()
	fade_tex.gradient = fade
	fade_tex.fill_from = Vector2(0.5, 0.0)
	fade_tex.fill_to = Vector2(0.5, 1.0)
	fade_tex.width = 4
	fade_tex.height = 128
	shade.texture = fade_tex
	SceneBuilder.add(page, shade, "Shade")
	# The hero stands on the right, in a pool of light; the stats sit over the left of the same area.
	var ground := TextureRect.new()
	ground.texture = _glow(Vector2(0.5, 0.5), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0.5)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.position = Vector2(250, 510)
	ground.size = Vector2(440, 70)
	SceneBuilder.add(page, ground, "Ground")
	var portrait := TextureRect.new()
	portrait.position = Vector2(240, 96)
	portrait.size = Vector2(450, 450)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = load(PORTRAIT)
	SceneBuilder.add(page, SceneBuilder.unique(portrait), "Portrait")

	var margins := _margins_box(32, 20, 32, 16)
	SceneBuilder.add(page, margins, "Margins")
	var col := SceneBuilder.add(margins, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 12)
	var top := SceneBuilder.add(col, HBoxContainer.new(), "Top") as HBoxContainer
	top.add_theme_constant_override(&"separation", 10)
	var back := Button.new()
	back.theme_type_variation = &"FlatButton"
	back.text = "‹ 英雄名冊"
	back.custom_minimum_size = Vector2(0, 64)
	SceneBuilder.add(top, SceneBuilder.unique(back), "Back")
	_spacer(top)
	_currency(top, "金幣", "1280", "Gold")
	_currency(top, "素材", "3", "Shards")

	# Name, rarity and class, level: over the left of the hero area.
	var stats := VBoxContainer.new()
	stats.custom_minimum_size = Vector2(0, 450)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override(&"separation", 6)
	SceneBuilder.add(col, stats, "Stats")
	var hero_name := _label("蘿德", 80, TEXT, &"Heading")
	SceneBuilder.add(stats, SceneBuilder.unique(hero_name), "HeroName")
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(240, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	SceneBuilder.add(stats, rule, "NameRule")
	var identity := SceneBuilder.add(stats, HBoxContainer.new(), "Identity") as HBoxContainer
	identity.add_theme_constant_override(&"separation", 14)
	SceneBuilder.add(identity, SceneBuilder.unique(_label("SSR", 36, GOLD, &"Heading")), "Rarity")
	var bar := VSeparator.new()
	bar.custom_minimum_size = Vector2(0, 32)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(identity, bar, "Bar")
	SceneBuilder.add(identity, SceneBuilder.unique(_label("劍士", 32, TEXT)), "ClassName")
	_gap(stats, 12)
	var lv := SceneBuilder.add(stats, HBoxContainer.new(), "LevelRow") as HBoxContainer
	lv.add_theme_constant_override(&"separation", 8)
	var lv_title := _label("Lv", 40, BRONZE, &"Heading")
	lv_title.size_flags_vertical = Control.SIZE_SHRINK_END
	SceneBuilder.add(lv, lv_title, "LvTitle")
	SceneBuilder.add(lv, SceneBuilder.unique(_label("4", 96, TEXT, &"Heading")), "Level")
	var cap := _label("／10", 36, TEXT, &"Heading")
	cap.size_flags_vertical = Control.SIZE_SHRINK_END
	SceneBuilder.add(lv, SceneBuilder.unique(cap), "Cap")
	var exp_bar := ProgressBar.new()
	exp_bar.theme_type_variation = &"ExpBar"
	exp_bar.custom_minimum_size = Vector2(250, 10)
	exp_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	exp_bar.show_percentage = false
	exp_bar.value = 40.0
	SceneBuilder.add(stats, SceneBuilder.unique(exp_bar), "Exp")
	_gap(stats, 8)
	SceneBuilder.add(stats, SceneBuilder.unique(_label("突破 ★0／5", 28, TEXT)), "AscendLine")
	SceneBuilder.add(stats, SceneBuilder.unique(_label("強度 ×1.00", 24, TEXT, &"Dim")), "PowerLine")
	_gap(stats, 6)
	var captain := Button.new()
	captain.text = "設為隊長"
	captain.custom_minimum_size = Vector2(190, 52)
	captain.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	captain.add_theme_font_size_override(&"font_size", 24)
	SceneBuilder.add(stats, SceneBuilder.unique(captain), "CaptainToggle")

	SceneBuilder.add(col, HSeparator.new(), "Rule")
	# 招牌技 (SSR), or the next rarity step (N / R).
	var sig := _section(col, "SigSection", "招牌技")
	var sig_row := _row(sig)
	_icon(sig_row, "SigIcon")
	var sig_text := _text_column(sig_row)
	SceneBuilder.add(sig_text, SceneBuilder.unique(_label("斷鋼斬", 36, TEXT, &"Heading")), "SigName")
	var sig_desc := _label("重擊，連部位一起削。\n開戰 10 秒起，每 28 秒施放一次。", 22, TEXT, &"Dim")
	SceneBuilder.add(sig_text, SceneBuilder.unique(sig_desc), "SigDesc")
	_value_column(sig_row, "強化", "+0%", "SigBonus")
	var promote := _section(col, "PromoteSection", "晉升")
	var promote_row := _row(promote)
	var promote_text := _text_column(promote_row)
	SceneBuilder.add(promote_text, SceneBuilder.unique(_label("再突破 2 次 → R", 32, TEXT, &"Heading")), "PromoteName")
	var promote_desc := _label("每突破 2 次升一階稀有度，最高 SR。", 22, TEXT, &"Dim")
	SceneBuilder.add(promote_text, SceneBuilder.unique(promote_desc), "PromoteDesc")
	_value_column(promote_row, "目前", "N", "RarityNow")
	promote.visible = false
	# 職業加成.
	var bonus := _section(col, "ClassSection", "職業加成")
	var bonus_row := _row(bonus)
	_icon(bonus_row, "ClassIcon")
	var bonus_text := _text_column(bonus_row)
	var level_row := SceneBuilder.add(bonus_text, HBoxContainer.new(), "LevelRow") as HBoxContainer
	level_row.add_theme_constant_override(&"separation", 10)
	var level_title := _label("職業等級", 28, TEXT)
	level_title.size_flags_vertical = Control.SIZE_SHRINK_END
	SceneBuilder.add(level_row, level_title, "Title")
	SceneBuilder.add(level_row, SceneBuilder.unique(_label("14", 44, TEXT, &"Heading")), "ClassLevel")
	SceneBuilder.add(bonus_text, _label("提升同職業每一位英雄的能力。", 22, TEXT, &"Dim"), "ClassDesc")
	_value_column(bonus_row, "全職業英雄", "×2.72", "ClassMult")

	_spacer_v(col)
	SceneBuilder.add(col, SceneBuilder.unique(_label("突破素材 1／持有 3", 24, TEXT, &"Dim")), "CostLine")
	var buttons := SceneBuilder.add(col, HBoxContainer.new(), "Buttons") as HBoxContainer
	buttons.add_theme_constant_override(&"separation", 16)
	var ascend := Button.new()
	ascend.theme_type_variation = &"PrimaryButton"
	ascend.text = "突破（1 素材）"
	ascend.custom_minimum_size = Vector2(0, 88)
	ascend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ascend.size_flags_stretch_ratio = 1.3
	ascend.add_theme_font_size_override(&"font_size", 34)
	SceneBuilder.add(buttons, SceneBuilder.unique(ascend), "Ascend")
	var send := Button.new()
	send.text = "派去行軍（第 1 格）"
	send.custom_minimum_size = Vector2(0, 88)
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.add_theme_font_size_override(&"font_size", 26)
	SceneBuilder.add(buttons, SceneBuilder.unique(send), "SendMarch")
	return page


func _growth() -> Control:
	var root := Control.new()
	root.name = "Growth"
	root.set_script(load("res://scripts/growth.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture = _glow(Vector2(0.5, 0.0), Color("223a31"), Color("0d1613"), 1.1)
	SceneBuilder.add(root, bg, "Background")

	var roster := _margins_box(20, 36, 20, 24)
	SceneBuilder.add(root, SceneBuilder.unique(roster), "Roster")
	var col := SceneBuilder.add(roster, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 12)

	var top := SceneBuilder.add(col, HBoxContainer.new(), "Top") as HBoxContainer
	top.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(top, _label("養成", 44, TEXT, &"Heading"), "Title")
	_spacer(top)
	_currency(top, "金幣", "1280", "Gold")
	_currency(top, "素材", "3", "Shards")
	var auto := Button.new()
	auto.text = "一鍵養成"
	auto.custom_minimum_size = Vector2(150, 60)
	auto.add_theme_font_size_override(&"font_size", 24)
	SceneBuilder.add(top, SceneBuilder.unique(auto), "AutoSpend")

	var march := PanelContainer.new()
	SceneBuilder.add(col, march, "MarchPanel")
	var march_row := SceneBuilder.add(march, HBoxContainer.new(), "Row") as HBoxContainer
	march_row.add_theme_constant_override(&"separation", 8)
	var march_title := SceneBuilder.add(march_row, VBoxContainer.new(), "Title") as VBoxContainer
	march_title.alignment = BoxContainer.ALIGNMENT_CENTER
	SceneBuilder.add(march_title, _label("行軍\n小隊", 26, TEXT, &"Heading"), "Name")
	SceneBuilder.add(march_title, _label("只有他們\n拿經驗", 16, TEXT, &"Dim"), "Note")
	var slots := SceneBuilder.add(march_row, SceneBuilder.unique(HBoxContainer.new()), "MarchSlots") as HBoxContainer
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override(&"separation", 6)
	for k: int in 5:
		var slot: Button = SceneBuilder.instance(CARD)
		slot.custom_minimum_size = Vector2(0, 184)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(slots, slot, "Slot_%d" % (k + 1))

	var tabs := SceneBuilder.add(col, SceneBuilder.unique(HBoxContainer.new()), "ClassTabs") as HBoxContainer
	tabs.add_theme_constant_override(&"separation", 2)
	var heroes: Texture2D = load(HEROES)
	for c: int in PushSim.CLASS_NAMES.size():
		var tab := Button.new()
		tab.theme_type_variation = &"TabButton"
		tab.text = PushSim.CLASS_NAMES[c]
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 72)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tab.add_theme_font_size_override(&"font_size", 28)
		tab.add_theme_constant_override(&"h_separation", 2)
		var icon := AtlasTexture.new()
		icon.atlas = heroes
		icon.region = Rect2(4 * 48 + 6, c * 48 + 4, 36, 42)
		tab.icon = icon
		SceneBuilder.add(tabs, tab, "Tab_%d" % c)
	SceneBuilder.add(col, HSeparator.new(), "TabRule")

	var class_panel := PanelContainer.new()
	SceneBuilder.add(col, class_panel, "ClassPanel")
	var class_row := SceneBuilder.add(class_panel, HBoxContainer.new(), "Row") as HBoxContainer
	class_row.add_theme_constant_override(&"separation", 16)
	_icon(class_row, "ClassIcon")
	var class_text := _text_column(class_row)
	var title_row := SceneBuilder.add(class_text, HBoxContainer.new(), "TitleRow") as HBoxContainer
	title_row.add_theme_constant_override(&"separation", 10)
	var class_title := _label("劍 職業等級", 26, TEXT)
	class_title.size_flags_vertical = Control.SIZE_SHRINK_END
	SceneBuilder.add(title_row, SceneBuilder.unique(class_title), "ClassTitle")
	SceneBuilder.add(title_row, SceneBuilder.unique(_label("14", 48, GOLD, &"Heading")), "ClassLevel")
	var mult_row := SceneBuilder.add(class_text, HBoxContainer.new(), "MultRow") as HBoxContainer
	mult_row.add_theme_constant_override(&"separation", 10)
	var mult_title := _label("全職業英雄", 22, TEXT, &"Dim")
	mult_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(mult_row, mult_title, "Title")
	SceneBuilder.add(mult_row, SceneBuilder.unique(_label("×2.72", 32, TEXT, &"Heading")), "ClassMult")
	var class_up := Button.new()
	class_up.theme_type_variation = &"PrimaryButton"
	class_up.text = "升級　272 金"
	class_up.custom_minimum_size = Vector2(220, 88)
	class_up.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	class_up.add_theme_font_size_override(&"font_size", 28)
	SceneBuilder.add(class_row, SceneBuilder.unique(class_up), "ClassUp")

	var roster_panel := PanelContainer.new()
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(col, roster_panel, "RosterPanel")
	var roster_col := SceneBuilder.add(roster_panel, VBoxContainer.new(), "Column") as VBoxContainer
	roster_col.add_theme_constant_override(&"separation", 8)
	SceneBuilder.add(roster_col, SceneBuilder.unique(_label("劍職英雄　20 人", 26, TEXT, &"Heading")), "RosterTitle")
	SceneBuilder.add(roster_col, HSeparator.new(), "Rule")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SceneBuilder.add(roster_col, scroll, "Scroll")
	var cards := GridContainer.new()
	cards.columns = 4
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override(&"h_separation", 8)
	cards.add_theme_constant_override(&"v_separation", 8)
	SceneBuilder.add(scroll, SceneBuilder.unique(cards), "Cards")
	for k: int in 4:
		var preview: Button = SceneBuilder.instance(CARD)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(cards, preview, "Preview_%d" % (k + 1))
	var hint := _label("點英雄看詳情、突破、派去行軍", 20, TEXT, &"Dim")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(roster_col, hint, "Hint")

	var toast := _label("行軍回來了：金幣 +1300", 22, MARCH)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(col, SceneBuilder.unique(toast), "Toast")

	var page: Control = SceneBuilder.instance(PAGE)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	SceneBuilder.add(root, SceneBuilder.unique(page), "HeroPage")
	return root


## A titled section of the hero page: title, rule, then the row the caller fills.
func _section(parent: Node, key: String, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override(&"separation", 8)
	SceneBuilder.add(parent, SceneBuilder.unique(section), key)
	SceneBuilder.add(section, _label(title, 24, TEXT, &"Dim"), "Title")
	SceneBuilder.add(section, HSeparator.new(), "Rule")
	return section


func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	SceneBuilder.add(parent, row, "Row")
	return row


## A framed 96 px pixel icon (the face of the class).
func _icon(parent: Node, key: String) -> void:
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"Pill"
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(parent, frame, key + "Frame")
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(88, 88)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var face := AtlasTexture.new()
	face.atlas = load(PORTRAIT)
	face.region = Rect2(32, 14, 67, 67)
	icon.texture = face
	SceneBuilder.add(frame, SceneBuilder.unique(icon), key)


func _text_column(parent: Node) -> VBoxContainer:
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 4)
	SceneBuilder.add(parent, text, "Text")
	return text


## The right-hand column of a section: a vertical rule, a caption and the value under it.
func _value_column(parent: Node, caption: String, value: String, key: String) -> void:
	var rule := VSeparator.new()
	SceneBuilder.add(parent, rule, "ValueRule")
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(170, 0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	SceneBuilder.add(parent, column, "Value")
	var title := _label(caption, 22, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(column, title, "Caption")
	var number := _label(value, 46, TEXT, &"Heading")
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(column, SceneBuilder.unique(number), key)


func _currency(parent: Node, caption: String, value: String, key: String) -> void:
	var title := _label(caption, 20, TEXT, &"Dim")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(parent, title, key + "Title")
	var number := _label(value, 32, GOLD, &"Heading")
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(parent, SceneBuilder.unique(number), key)


func _margins_box(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var box := MarginContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override(&"margin_left", left)
	box.add_theme_constant_override(&"margin_top", top)
	box.add_theme_constant_override(&"margin_right", right)
	box.add_theme_constant_override(&"margin_bottom", bottom)
	return box


func _spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(parent, spacer, "Spacer")


func _spacer_v(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(parent, spacer, "Fill")


func _gap(parent: Node, height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(parent, gap, "Gap%d" % parent.get_child_count())


## A radial glow (centre colour fading to the edge colour), for backgrounds.
func _glow(center: Vector2, inner: Color, outer: Color, reach: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = center
	texture.fill_to = center + Vector2(reach, 0.0)
	texture.width = 128
	texture.height = 128
	return texture


func _label(value: String, size: int, color: Color, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override(&"font_size", size)
	if variation != &"Dim":
		label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
