extends SceneTree
## Authoring tool for the 招募 page in the 墨綠暖白 look (ui/theme.tres), after the author's pick of the round3
## mockups (art_src/ui_concepts/round3/B_recruit.png: the banner hero large in a tavern, 卡池倒數, 保底, 近期獲得,
## 單抽／十連), with rarity as card background colour instead of the mockup's frames. Applied 2026-10-22. It
## overwrites the scenes below: run it again only after checking that none was edited by hand since.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_recruit.gd
## pull_card.tscn  one pulled hero: hero_card.tscn, name, note
## recruit.tscn    a page of home.tscn, above its nav bar; overlays 機率說明, 商店 and the results
## store.tscn      the Store autoload (scripts/store.gd): the test ad card

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const CARD := "res://scenes/hero_card.tscn"
const PULL := "res://scenes/pull_card.tscn"
const PAGE := "res://scenes/recruit.tscn"
const STORE := "res://scenes/store.tscn"
const THEME := "res://ui/theme.tres"
const BG_ART := "res://assets/ui/bg/recruit.png"
const BG_FALLBACK := "res://assets/ui/hero_page_bg.png"
const HERO_ART := "res://assets/heroes/portraits/sword.png"
const TICKET := "res://assets/ui/items/m_ticket.png"
const TEXT := Color("ece6dc")
const GOLD := Color("d9b26e")
const MARCH := Color("9fd08f")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_pull_card(), PULL, {"overwrite": true, "expected_refs": [CARD]}).ok
	ok = ok and SceneBuilder.save_scene(_page(), PAGE, {"overwrite": true, "expected_refs": [PULL]}).ok
	ok = ok and SceneBuilder.save_scene(_store(), STORE, {"overwrite": true}).ok
	quit(0 if ok else 1)


func _pull_card() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.name = "PullCard"
	root.set_script(load("res://scripts/pull_card.gd"))
	root.theme = load(THEME)
	root.add_theme_constant_override(&"separation", 2)
	var card: Button = SceneBuilder.instance(CARD)
	card.custom_minimum_size = Vector2(124, 168)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	SceneBuilder.add(root, SceneBuilder.unique(card), "Card")
	var hero_name := _label("蘿德", 22, TEXT, &"Heading")
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_name.clip_text = true
	SceneBuilder.add(root, SceneBuilder.unique(hero_name), "HeroName")
	var note := _label("素材 +8", 17, GOLD)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(root, SceneBuilder.unique(note), "Note")
	return root


func _page() -> Control:
	var root := Control.new()
	root.name = "Recruit"
	root.set_script(load("res://scripts/recruit_page.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	root.clip_contents = true
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.texture = load(BG_ART if ResourceLoader.exists(BG_ART) else BG_FALLBACK)
	SceneBuilder.add(root, bg, "Background")
	SceneBuilder.add(root, _shade(), "Shade")

	var margins := _margins_box(20, 36, 20, 20)
	SceneBuilder.add(root, margins, "Margins")
	var col := SceneBuilder.add(margins, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 10)

	var top := SceneBuilder.add(col, HBoxContainer.new(), "Top") as HBoxContainer
	top.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(top, _label("招募", 44, TEXT, &"Heading"), "Title")
	_spacer(top)
	_currency(top, "金幣", "4820", "Gold")
	_currency(top, "招募券", "12", "Tickets")
	var shop := Button.new()
	shop.text = "商店"
	shop.custom_minimum_size = Vector2(110, 60)
	shop.add_theme_font_size_override(&"font_size", 24)
	SceneBuilder.add(top, SceneBuilder.unique(shop), "ShopButton")

	# The 限時卡池 stage: the banner hero large, the name and tag at the upper left.
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(0, 300)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(col, stage, "Stage")
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 150.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.texture = load(HERO_ART)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(stage, SceneBuilder.unique(art), "BannerArt")
	var heading := VBoxContainer.new()
	heading.position = Vector2(4, 4)
	heading.add_theme_constant_override(&"separation", 2)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(stage, heading, "Heading")
	SceneBuilder.add(heading, _outlined("限時卡池", 30, TEXT), "Pool")
	SceneBuilder.add(heading, SceneBuilder.unique(_outlined("蘿德", 64, TEXT)), "BannerName")
	SceneBuilder.add(heading, SceneBuilder.unique(_outlined("SSR　｜　劍士", 28, GOLD)), "BannerTag")

	var timer_row := SceneBuilder.add(col, HBoxContainer.new(), "TimerRow") as HBoxContainer
	timer_row.add_theme_constant_override(&"separation", 12)
	var timer_title := _label("卡池倒數", 22, TEXT, &"Dim")
	timer_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(timer_row, timer_title, "CountdownTitle")
	SceneBuilder.add(timer_row, SceneBuilder.unique(_label("02:18:36", 34, GOLD, &"Heading")), "Countdown")
	_spacer(timer_row)
	var rates := Button.new()
	rates.text = "機率說明"
	rates.custom_minimum_size = Vector2(150, 56)
	rates.add_theme_font_size_override(&"font_size", 22)
	SceneBuilder.add(timer_row, SceneBuilder.unique(rates), "RatesButton")

	var pity := PanelContainer.new()
	SceneBuilder.add(col, pity, "Pity")
	var pity_col := SceneBuilder.add(pity, VBoxContainer.new(), "Column") as VBoxContainer
	pity_col.add_theme_constant_override(&"separation", 6)
	var pity_row := SceneBuilder.add(pity_col, HBoxContainer.new(), "Row") as HBoxContainer
	SceneBuilder.add(pity_row, _label("保底", 22, TEXT, &"Dim"), "Title")
	SceneBuilder.add(pity_row, SceneBuilder.unique(_label("再 23 抽必出 SSR", 28, TEXT, &"Heading")), "PityLine")
	(pity_row.get_child(1) as Label).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(pity_row.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(pity_row, SceneBuilder.unique(_label("7／30", 22, TEXT, &"Dim")), "PityCount")
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = 30
	bar.value = 7
	SceneBuilder.add(pity_col, SceneBuilder.unique(bar), "PityBar")

	SceneBuilder.add(col, _label("近期獲得", 22, TEXT, &"Dim"), "RecentTitle")
	var recent := HBoxContainer.new()
	recent.alignment = BoxContainer.ALIGNMENT_CENTER
	recent.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(col, SceneBuilder.unique(recent), "Recent")
	for k: int in 5:
		SceneBuilder.add(recent, SceneBuilder.instance(PULL), "Recent_%d" % k)

	var ad := Button.new()
	ad.text = "看廣告　免費單抽"
	ad.custom_minimum_size = Vector2(0, 56)
	ad.add_theme_font_size_override(&"font_size", 22)
	SceneBuilder.add(col, SceneBuilder.unique(ad), "AdPull")
	var buttons := SceneBuilder.add(col, HBoxContainer.new(), "Buttons") as HBoxContainer
	buttons.add_theme_constant_override(&"separation", 16)
	for spec: Array in [["Single", "單抽", "招募券 ×1", false], ["Ten", "十連", "招募券 ×10", true]]:
		var button := Button.new()
		button.text = "%s\n%s" % [spec[1], spec[2]]
		button.custom_minimum_size = Vector2(0, 100)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 28)
		if spec[3]:
			button.theme_type_variation = &"PrimaryButton"
		SceneBuilder.add(buttons, SceneBuilder.unique(button), spec[0])
	var toast := _label("", 20, MARCH)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(col, SceneBuilder.unique(toast), "Toast")

	_rates_overlay(root)
	_shop_overlay(root)
	_results_overlay(root)
	return root


func _rates_overlay(root: Control) -> void:
	var panel_col := _dialog(root, "RatesOverlay", "機率說明")
	var text := _label("N　55%", 24, TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	SceneBuilder.add(panel_col, SceneBuilder.unique(text), "RatesText")
	SceneBuilder.add(panel_col, _label("每次招募各自獨立計算；保底次數跨卡池保留。", 19, TEXT, &"Dim"), "Note")
	_close(panel_col, "RatesClose")


func _shop_overlay(root: Control) -> void:
	var panel_col := _dialog(root, "ShopOverlay", "商店")
	var note := _label("測試商店：不會真的扣款", 20, Color("d9735a"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(panel_col, SceneBuilder.unique(note), "ShopNote")
	var products := VBoxContainer.new()
	products.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(panel_col, SceneBuilder.unique(products), "Products")
	for k: int in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		SceneBuilder.add(products, row, "Product_%d" % k)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(TICKET):
			icon.texture = load(TICKET)
		SceneBuilder.add(row, icon, "Icon")
		var words := SceneBuilder.add(row, VBoxContainer.new(), "Words") as VBoxContainer
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override(&"separation", 0)
		var product_name := _label("招募券 ×10", 26, TEXT, &"Heading")
		SceneBuilder.add(words, product_name, "Name")
		SceneBuilder.add(words, _label("多送 10 張", 18, GOLD), "Tag")
		var buy := Button.new()
		buy.theme_type_variation = &"PrimaryButton"
		buy.text = "NT$ 90"
		buy.custom_minimum_size = Vector2(170, 64)
		buy.add_theme_font_size_override(&"font_size", 24)
		SceneBuilder.add(row, buy, "Buy")
	var restore := Button.new()
	restore.text = "恢復購買"
	restore.custom_minimum_size = Vector2(0, 56)
	restore.add_theme_font_size_override(&"font_size", 22)
	SceneBuilder.add(panel_col, SceneBuilder.unique(restore), "Restore")
	_close(panel_col, "ShopClose")


func _results_overlay(root: Control) -> void:
	var panel_col := _dialog(root, "ResultsOverlay", "招募結果")
	(panel_col.get_child(0) as Label).unique_name_in_owner = true
	panel_col.get_child(0).name = "ResultsTitle"
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	SceneBuilder.add(panel_col, SceneBuilder.unique(grid), "ResultCards")
	for k: int in 10:
		SceneBuilder.add(grid, SceneBuilder.instance(PULL), "Result_%d" % k)
	var text := _label("英雄之魂化為突破素材 +18", 22, GOLD)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(panel_col, SceneBuilder.unique(text), "ResultsText")
	_close(panel_col, "ResultsClose")


## A centred dialog over a dimmed page, hidden; returns its column (title first).
func _dialog(root: Control, key: String, title: String) -> VBoxContainer:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	SceneBuilder.add(root, SceneBuilder.unique(overlay), key)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.03, 0.8)
	SceneBuilder.add(overlay, dim, "Dim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(overlay, center, "Center")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	SceneBuilder.add(center, panel, "Panel")
	var col := SceneBuilder.add(panel, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 14)
	var heading := _label(title, 38, TEXT, &"Heading")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(col, heading, "Title")
	SceneBuilder.add(col, HSeparator.new(), "Rule")
	return col


func _close(parent: Node, key: String) -> void:
	var close := Button.new()
	close.theme_type_variation = &"PrimaryButton"
	close.text = "好"
	close.custom_minimum_size = Vector2(0, 76)
	close.add_theme_font_size_override(&"font_size", 30)
	SceneBuilder.add(parent, SceneBuilder.unique(close), key)


func _store() -> CanvasLayer:
	var root := CanvasLayer.new()
	root.name = "Store"
	root.layer = 90
	root.set_script(load("res://scripts/store.gd"))
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.theme = load(THEME)
	overlay.visible = false
	SceneBuilder.add(root, SceneBuilder.unique(overlay), "AdOverlay")
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.92)
	SceneBuilder.add(overlay, dim, "Dim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(overlay, center, "Center")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 360)
	SceneBuilder.add(center, panel, "Panel")
	var col := SceneBuilder.add(panel, VBoxContainer.new(), "Column") as VBoxContainer
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 20)
	var title := _label("廣告（測試）", 34, TEXT, &"Heading")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(col, SceneBuilder.unique(title), "AdTitle")
	var body := _label("這裡會播放獎勵廣告", 24, TEXT, &"Dim")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(col, body, "Body")
	var count := _label("3 秒後領取獎勵", 28, GOLD)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(col, SceneBuilder.unique(count), "AdCount")
	return root


func _outlined(value: String, size: int, color: Color) -> Label:
	var label := _label(value, size, color, &"Heading")
	label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.05, 0.04))
	label.add_theme_constant_override(&"outline_size", 8)
	return label


func _currency(parent: Node, caption: String, value: String, key: String) -> void:
	var title := _label(caption, 20, TEXT, &"Dim")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(parent, title, key + "Title")
	var number := _label(value, 32, GOLD, &"Heading")
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(parent, SceneBuilder.unique(number), key)


func _shade() -> TextureRect:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := Gradient.new()
	fade.set_color(0, Color(0.06, 0.1, 0.09, 0.3))
	fade.set_color(1, Color(0.06, 0.1, 0.09, 0.97))
	fade.add_point(0.45, Color(0.06, 0.1, 0.09, 0.15))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128
	shade.texture = texture
	return shade


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


func _label(value: String, size: int, color: Color, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = value
	label.theme_type_variation = variation
	label.add_theme_font_size_override(&"font_size", size)
	if variation != &"Dim":
		label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
