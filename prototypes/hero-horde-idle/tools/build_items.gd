extends SceneTree
## Authoring tool for the 道具 page in the 墨綠暖白 look (ui/theme.tres), after the author's backpack reference
## (docs/hd-2.5d/backpack.PNG: tabs over a grid of icons on rarity-coloured backgrounds with counts) and the round3
## mockups (art_src/ui_concepts/round3/A_items.png: the 職業武庫 row, the detail panel with 強化). Applied 2026-10-22.
## It overwrites scenes/item_cell.tscn and scenes/items.tscn: run it again only after checking that neither was edited
## by hand since.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_items.gd
## item_cell.tscn  one slot: rarity background, icon, 新 badge, caption, corner text (count / Lv / ★), the wearer's
##                 picture (hidden), selected frame
## items.tscn      gold, 強化石, 一鍵裝備; tabs 裝備／遺物／素材; the 職業武庫 (6 cells); the 專屬飾品 of the 行軍小隊
##                 (5 cells, after round3 A_items.png, the author's pick); the bag grid; the detail panel; a page of
##                 home.tscn, above its nav bar

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PushSim = preload("res://domain/push_sim.gd")
const CELL := "res://scenes/item_cell.tscn"
const PAGE := "res://scenes/items.tscn"
const THEME := "res://ui/theme.tres"
const ICON := "res://assets/ui/items/w_sword.png"
const TEXT := Color("ece6dc")
const GOLD := Color("d9b26e")
const MARCH := Color("9fd08f")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = SceneBuilder.save_scene(_cell(), CELL, {"overwrite": true}).ok
	ok = ok and SceneBuilder.save_scene(_page(), PAGE, {"overwrite": true, "expected_refs": [CELL]}).ok
	quit(0 if ok else 1)


func _cell() -> Button:
	var cell := Button.new()
	cell.name = "ItemCell"
	cell.set_script(load("res://scripts/item_cell.gd"))
	cell.theme = load(THEME)
	cell.toggle_mode = true
	cell.custom_minimum_size = Vector2(112, 112)
	cell.size = cell.custom_minimum_size
	# No frame: the rarity is the background; the selected cell gets a warm white one.
	for state: StringName in [&"normal", &"hover", &"disabled", &"focus"]:
		cell.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: StringName in [&"pressed", &"hover_pressed"]:
		cell.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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
	bg.self_modulate = Color("7a4fae")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(cell, SceneBuilder.unique(bg), "Bg")
	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10.0
	icon.offset_top = 8.0
	icon.offset_right = -10.0
	icon.offset_bottom = -14.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = load(ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(cell, SceneBuilder.unique(icon), "Icon")
	var fresh := ColorRect.new()
	fresh.color = Color("a8402f")
	fresh.position = Vector2(0, 0)
	fresh.size = Vector2(32, 26)
	fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(cell, SceneBuilder.unique(fresh), "New")
	var fresh_text := _label("新", 17, TEXT)
	fresh_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fresh_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fresh_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(fresh, fresh_text, "Text")
	var caption := _outlined("劍", 22)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	caption.offset_left = 6.0
	caption.offset_top = -32.0
	caption.offset_right = 60.0
	caption.offset_bottom = -2.0
	SceneBuilder.add(cell, SceneBuilder.unique(caption), "Caption")
	var corner := _outlined("×2", 22)
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.offset_left = -80.0
	corner.offset_top = -32.0
	corner.offset_right = -6.0
	corner.offset_bottom = -2.0
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(cell, SceneBuilder.unique(corner), "Corner")
	var face := TextureRect.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	face.offset_left = -50.0
	face.offset_top = -62.0
	face.offset_right = -4.0
	face.offset_bottom = -4.0
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	SceneBuilder.add(cell, SceneBuilder.unique(face), "Face")
	# The selected cell's warm white frame, over the background (item_cell.gd shows it while pressed).
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = TEXT
	border.set_border_width_all(4)
	border.set_corner_radius_all(4)
	frame.add_theme_stylebox_override(&"panel", border)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	SceneBuilder.add(cell, SceneBuilder.unique(frame), "Frame")
	return cell


func _page() -> Control:
	var root := Control.new()
	root.name = "Items"
	root.set_script(load("res://scripts/items_page.gd"))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load(THEME)
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture = _glow(Vector2(0.5, 0.0), Color("223a31"), Color("0d1613"), 1.1)
	SceneBuilder.add(root, bg, "Background")

	var margins := _margins_box(20, 36, 20, 24)
	SceneBuilder.add(root, margins, "Margins")
	var col := SceneBuilder.add(margins, VBoxContainer.new(), "Column") as VBoxContainer
	col.add_theme_constant_override(&"separation", 12)

	var top := SceneBuilder.add(col, HBoxContainer.new(), "Top") as HBoxContainer
	top.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(top, _label("道具", 44, TEXT, &"Heading"), "Title")
	_spacer(top)
	_currency(top, "金幣", "4820", "Gold")
	_currency(top, "強化石", "24", "Stones")
	var auto := Button.new()
	auto.text = "一鍵裝備"
	auto.custom_minimum_size = Vector2(150, 60)
	auto.add_theme_font_size_override(&"font_size", 24)
	SceneBuilder.add(top, SceneBuilder.unique(auto), "AutoEquip")

	var tabs := SceneBuilder.add(col, SceneBuilder.unique(HBoxContainer.new()), "Tabs") as HBoxContainer
	tabs.add_theme_constant_override(&"separation", 2)
	for spec: Array in [["TabEquip", "裝備"], ["TabRelic", "遺物"], ["TabMaterial", "素材"]]:
		var tab := Button.new()
		tab.theme_type_variation = &"TabButton"
		tab.text = spec[1]
		tab.toggle_mode = true
		tab.custom_minimum_size = Vector2(0, 72)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override(&"font_size", 30)
		SceneBuilder.add(tabs, SceneBuilder.unique(tab), spec[0])
	(tabs.get_child(0) as Button).button_pressed = true

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(col, panel, "ListPanel")
	var list := SceneBuilder.add(panel, VBoxContainer.new(), "Column") as VBoxContainer
	list.add_theme_constant_override(&"separation", 8)
	var armory := SceneBuilder.add(list, SceneBuilder.unique(VBoxContainer.new()), "Armory") as VBoxContainer
	armory.add_theme_constant_override(&"separation", 8)
	_title_row(armory, "職業武庫", "同職業英雄共用", "", "")
	var slots := SceneBuilder.add(armory, SceneBuilder.unique(HBoxContainer.new()), "ArmorySlots") as HBoxContainer
	slots.add_theme_constant_override(&"separation", 6)
	for c: int in PushSim.CLASS_NAMES.size():
		var slot: Button = SceneBuilder.instance(CELL)
		slot.custom_minimum_size = Vector2(0, 100)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(slots, slot, "Slot_%d" % c)
	var charms := SceneBuilder.add(list, SceneBuilder.unique(VBoxContainer.new()), "Charms") as VBoxContainer
	charms.add_theme_constant_override(&"separation", 8)
	_title_row(charms, "專屬飾品", "行軍小隊配戴，只加那名英雄", "", "")
	var charm_slots := SceneBuilder.add(charms, SceneBuilder.unique(HBoxContainer.new()), "CharmSlots") as HBoxContainer
	charm_slots.add_theme_constant_override(&"separation", 8)
	for k: int in 5:
		var slot: Button = SceneBuilder.instance(CELL)
		slot.custom_minimum_size = Vector2(0, 104)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(charm_slots, slot, "Charm_%d" % k)
	_gap(charms, 4)
	_title_row(list, "背包", "關卡王與行軍掉落", "SectionTitle", "SectionNote")
	SceneBuilder.add(list, HSeparator.new(), "Rule")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SceneBuilder.add(list, scroll, "Scroll")
	var cells := GridContainer.new()
	cells.columns = 5
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.add_theme_constant_override(&"h_separation", 8)
	cells.add_theme_constant_override(&"v_separation", 8)
	SceneBuilder.add(scroll, SceneBuilder.unique(cells), "Cells")
	for k: int in 5:
		var preview: Button = SceneBuilder.instance(CELL)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(cells, preview, "Preview_%d" % (k + 1))
	var empty := _label("背包是空的：打倒關卡王或行軍時會掉裝備", 22, TEXT, &"Dim")
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.visible = false
	SceneBuilder.add(list, SceneBuilder.unique(empty), "Empty")

	var detail := PanelContainer.new()
	SceneBuilder.add(col, SceneBuilder.unique(detail), "Detail")
	var row := SceneBuilder.add(detail, HBoxContainer.new(), "Row") as HBoxContainer
	row.add_theme_constant_override(&"separation", 14)
	var big: Button = SceneBuilder.instance(CELL)
	big.custom_minimum_size = Vector2(132, 132)
	big.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	big.focus_mode = Control.FOCUS_NONE
	SceneBuilder.add(row, SceneBuilder.unique(big), "DetailCell")
	var text := SceneBuilder.add(row, VBoxContainer.new(), "Text") as VBoxContainer
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 2)
	SceneBuilder.add(text, SceneBuilder.unique(_label("斷鋼長劍", 30, TEXT, &"Heading")), "DetailName")
	SceneBuilder.add(text, SceneBuilder.unique(_label("SR　劍職業武器　背包 ×1", 19, TEXT, &"Dim")), "DetailKind")
	SceneBuilder.add(text, SceneBuilder.unique(_label("劍職業全員強度 +18%", 23, GOLD)), "DetailEffect")
	var note := _label("目前裝備：鋼劍", 18, TEXT, &"Dim")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(text, SceneBuilder.unique(note), "DetailNote")
	var buttons := SceneBuilder.add(row, VBoxContainer.new(), "Buttons") as VBoxContainer
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	var main := Button.new()
	main.theme_type_variation = &"PrimaryButton"
	main.text = "裝備到劍武庫"
	main.custom_minimum_size = Vector2(210, 76)
	main.add_theme_font_size_override(&"font_size", 24)
	SceneBuilder.add(buttons, SceneBuilder.unique(main), "DetailMain")
	var salvage := Button.new()
	salvage.text = "分解　+8 強化石"
	salvage.custom_minimum_size = Vector2(210, 56)
	salvage.add_theme_font_size_override(&"font_size", 20)
	SceneBuilder.add(buttons, SceneBuilder.unique(salvage), "DetailSalvage")

	var toast := _label("一鍵裝備：每個職業換上最好的武器", 22, MARCH)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	SceneBuilder.add(col, SceneBuilder.unique(toast), "Toast")
	return root


func _title_row(parent: Node, title: String, note: String, title_key: String, note_key: String) -> void:
	var row := SceneBuilder.add(parent, HBoxContainer.new(), "TitleRow%d" % parent.get_child_count()) as HBoxContainer
	row.add_theme_constant_override(&"separation", 12)
	var heading := _label(title, 26, TEXT, &"Heading")
	SceneBuilder.add(row, SceneBuilder.unique(heading) if title_key != "" else heading, title_key if title_key != "" else "Title")
	_spacer(row)
	var dim := _label(note, 19, TEXT, &"Dim")
	dim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(row, SceneBuilder.unique(dim) if note_key != "" else dim, note_key if note_key != "" else "Note")


func _outlined(value: String, size: int) -> Label:
	var label := _label(value, size, TEXT, &"Heading")
	label.add_theme_color_override(&"font_outline_color", Color(0.04, 0.05, 0.04))
	label.add_theme_constant_override(&"outline_size", 6)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


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
