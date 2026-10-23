extends SceneTree
## One-time authoring tool, applied 2026-10-22. Existing detail scene is never overwritten.
## Normal startup/import/tests only consume the saved scenes. Review scene diffs before regeneration.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const OUT := "res://scenes/hero_detail.tscn"
const IVORY := Color("e9e5d6")
const BRONZE := Color("b5966b")
const MUTED := Color("a9b4a7")
var serif: Font

func _initialize() -> void:
	build.call_deferred()

func add(parent: Node, child: Node, key: String) -> Node:
	return B.add(parent, B.unique(child), key)

func label(parent: Node, key: String, text: String, font_size: int, color: Color = IVORY, ornate: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if ornate:
		node.add_theme_font_override("font", serif)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(parent, node, key)
	return node

func texture(parent: Node, key: String, path: String) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(parent, node, key)
	return node

func rect(node: Control, bounds: Rect2) -> void:
	node.anchor_left = bounds.position.x
	node.anchor_top = bounds.position.y
	node.anchor_right = bounds.end.x
	node.anchor_bottom = bounds.end.y

func rule(parent: Node, key: String) -> void:
	var node := ColorRect.new()
	node.color = Color(BRONZE, 0.48)
	node.custom_minimum_size.y = 1
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(parent, node, key)

func style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.set_content_margin_all(12)
	return box

func button(parent: Node, key: String, text: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 80
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_override("font", serif)
	node.add_theme_font_size_override("font_size", 30)
	var ink := Color("172d27")
	node.add_theme_color_override("font_color", ink if primary else IVORY)
	node.add_theme_color_override("font_hover_color", ink if primary else IVORY)
	node.add_theme_color_override("font_pressed_color", ink if primary else IVORY)
	node.add_theme_color_override("font_disabled_color", Color("78877a"))
	node.add_theme_stylebox_override("normal", style(IVORY if primary else Color(ink, 0.7), BRONZE))
	node.add_theme_stylebox_override("hover", style(Color("d9c9a7") if primary else Color("30483b"), IVORY))
	node.add_theme_stylebox_override("pressed", style(Color("b8aa8a") if primary else Color("0d211c"), BRONZE))
	node.add_theme_stylebox_override("disabled", style(Color("253a30"), Color("526253")))
	var focus := style(Color.TRANSPARENT, IVORY)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
	add(parent, node, key)
	return node

func build() -> void:
	if FileAccess.file_exists(OUT):
		print("Already applied; refusing to regenerate editable scenes.")
		quit(0)
		return
	# Extract only accepted art components; text and controls remain real scene nodes.
	DirAccess.make_dir_recursive_absolute("res://assets/ui/detail")
	DirAccess.make_dir_recursive_absolute("res://assets/ui/portraits")
	var mockup := Image.load_from_file("res://art_src/ui_concepts/detail_refinement_v2/hero_detail.png")
	mockup.get_region(Rect2i(63, 1241, 125, 125)).save_png("res://assets/ui/detail/slash.png")
	mockup.get_region(Rect2i(63, 1462, 121, 118)).save_png("res://assets/ui/detail/class_sword.png")
	for hero: String in ["shield", "sword", "spear", "bow", "mage", "healer"]:
		var image := Image.load_from_file("res://art_src/hd2/%s/candidate-01.png" % hero)
		image.get_region(image.get_used_rect()).save_png("res://assets/ui/portraits/%s.png" % hero)
	# Import generated PNGs before running this tool a second time with --build.
	if not "--build" in OS.get_cmdline_user_args():
		print("Art extracted. Run editor import, then this tool with -- --build.")
		quit(0)
		return
	serif = load("res://ui/fonts/NotoSerifTC-Bold.otf")
	var root := Control.new()
	root.name = "HeroDetail"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://ui/theme.tres")
	root.set_script(load("res://scripts/hero_detail.gd"))
	var bg := ColorRect.new()
	bg.color = Color("142923")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add(root, bg, "InkBackground")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	add(root, margin, "SafeMargins")
	var col := add(margin, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override("separation", 10)
	var header := add(col, HBoxContainer.new(), "Header") as HBoxContainer
	header.add_theme_constant_override("separation", 18)
	var back := button(header, "Back", "〈 英雄名冊")
	back.custom_minimum_size.y = 64
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state: String in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var spacer := add(header, Control.new(), "HeaderSpace") as Control
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(header, "Gold", "1280 金幣", 24, BRONZE)
	label(header, "Shards", "3 素材", 24)
	var hero := add(col, Control.new(), "HeroStage") as Control
	hero.custom_minimum_size.y = 440
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.clip_contents = true
	var gate := texture(hero, "Ruins", "res://assets/stage/props/gate.png")
	rect(gate, Rect2(0.26, 0.02, 0.88, 0.73))
	gate.modulate = Color(0.28, 0.37, 0.29, 0.42)
	for k: int in 3:
		var tree := texture(hero, "Forest%d" % k, "res://assets/stage/props/pine.png")
		rect(tree, Rect2(-0.16 + k * 0.47, 0.04 + k * 0.12, 0.6, 0.85))
		tree.modulate = Color(0.12, 0.24, 0.18, 0.65)
	var ground := texture(hero, "StoneGround", "res://assets/stage/cliff.png")
	rect(ground, Rect2(-0.08, 0.77, 1.2, 0.42))
	ground.modulate = Color(0.42, 0.51, 0.39, 0.6)
	var portrait := texture(hero, "Portrait", "res://assets/ui/portraits/sword.png")
	rect(portrait, Rect2(0.18, 0.14, 0.84, 0.84))
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var stats := add(hero, VBoxContainer.new(), "IdentityColumn") as VBoxContainer
	rect(stats, Rect2(0.02, 0.05, 0.47, 0.60))
	stats.add_theme_constant_override("separation", 10)
	var name_label := label(stats, "DetailName", "蘿德", 76, IVORY, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rule(stats, "NameRule")
	label(stats, "Identity", "SSR  │  劍士", 32, BRONZE, true)
	var gap := add(stats, Control.new(), "IdentitySpace") as Control
	gap.custom_minimum_size.y = 30
	label(stats, "DetailLine", "Lv 4 / 10", 44, IVORY, true)
	var exp_bar := add(stats, ProgressBar.new(), "Exp") as ProgressBar
	exp_bar.show_percentage = false
	exp_bar.custom_minimum_size = Vector2(190, 7)
	exp_bar.value = 40
	exp_bar.add_theme_stylebox_override("background", style(Color("48574b"), Color.TRANSPARENT))
	exp_bar.add_theme_stylebox_override("fill", style(BRONZE, Color.TRANSPARENT))
	label(stats, "Stars", "突破  ★ 0", 28)
	label(stats, "Power", "英雄強度 ×2.98", 19, MUTED)
	rule(col, "StageRule")
	label(col, "Overview", "概覽", 32, IVORY, true)
	rule(col, "OverviewRule")
	label(col, "SignatureHeading", "招牌技", 25, IVORY, true)
	var skill := add(col, HBoxContainer.new(), "SignatureRow") as HBoxContainer
	skill.add_theme_constant_override("separation", 24)
	skill.custom_minimum_size.y = 112
	var icon := texture(skill, "SkillIcon", "res://assets/ui/detail/slash.png")
	icon.custom_minimum_size = Vector2(104, 104)
	var skill_text := add(skill, VBoxContainer.new(), "SkillText") as VBoxContainer
	skill_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_text.alignment = BoxContainer.ALIGNMENT_CENTER
	label(skill_text, "SkillName", "斷鋼斬", 34, IVORY, true)
	var desc := label(skill_text, "SkillDesc", "重擊，連部位一起削", 23, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skill_stat := add(skill, VBoxContainer.new(), "SkillStat") as VBoxContainer
	skill_stat.custom_minimum_size.x = 132
	skill_stat.alignment = BoxContainer.ALIGNMENT_CENTER
	label(skill_stat, "SkillCaption", "強化", 23, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(skill_stat, "SkillBonus", "+0%", 44, IVORY, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule(col, "SkillRule")
	label(col, "ClassHeading", "職業加成", 25, IVORY, true)
	var class_row := add(col, HBoxContainer.new(), "ClassRow") as HBoxContainer
	class_row.add_theme_constant_override("separation", 24)
	class_row.custom_minimum_size.y = 106
	var flag := texture(class_row, "ClassIcon", "res://assets/ui/detail/class_sword.png")
	flag.custom_minimum_size = Vector2(104, 104)
	var class_text := add(class_row, VBoxContainer.new(), "ClassText") as VBoxContainer
	class_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_text.alignment = BoxContainer.ALIGNMENT_CENTER
	label(class_text, "ClassLevel", "職業等級 14", 30, IVORY, true)
	var class_desc := label(class_text, "ClassDesc", "提升同職業英雄的能力。", 22, MUTED)
	class_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var class_stat := add(class_row, VBoxContainer.new(), "ClassStat") as VBoxContainer
	class_stat.custom_minimum_size.x = 154
	class_stat.alignment = BoxContainer.ALIGNMENT_CENTER
	label(class_stat, "ClassCaption", "全劍士英雄", 22, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(class_stat, "ClassMultiplier", "×2.72", 42, IVORY, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule(col, "ClassRule")
	var target_row := add(col, HBoxContainer.new(), "CostRow") as HBoxContainer
	var cost := label(target_row, "Cost", "突破素材 1 ／ 持有 3", 24)
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var target := add(target_row, OptionButton.new(), "MarchTarget") as OptionButton
	for k: int in 5:
		target.add_item("行軍第 %d 格" % (k + 1))
	target.add_theme_font_size_override("font_size", 22)
	target.add_theme_stylebox_override("normal", style(Color("142923"), Color("526253")))
	target.add_theme_stylebox_override("hover", style(Color("30483b"), BRONZE))
	target.add_theme_stylebox_override("pressed", style(Color("142923"), BRONZE))
	var buttons := add(col, HBoxContainer.new(), "Actions") as HBoxContainer
	buttons.add_theme_constant_override("separation", 20)
	button(buttons, "Ascend", "突破（1 素材）", true).size_flags_stretch_ratio = 1.5
	button(buttons, "SendMarch", "派去行軍")
	var feedback := label(col, "Feedback", "", 21, MUTED)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ok: bool = B.save_scene(root, OUT).ok
	if ok:
		var growth: Node = (load("res://scenes/growth.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		var old: Node = growth.get_node("Margins/Column/Detail")
		old.get_parent().remove_child(old)
		old.free()
		var detail: Control = B.instance(OUT)
		detail.visible = false
		add(growth, detail, "Detail")
		ok = B.save_scene(growth, "res://scenes/growth.tscn", {"overwrite": true, "expected_refs": [OUT, "res://scenes/hero_card.tscn"]}).ok
	quit(0 if ok else 1)
