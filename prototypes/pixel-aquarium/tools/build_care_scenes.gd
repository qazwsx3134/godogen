## Authoring command for a copy without the saved care scenes.
extends "res://tools/build_scenes.gd"

const CARE := "res://scenes/care.tscn"
const EGG := "res://scenes/egg.tscn"
const FOOD := "res://scenes/food.tscn"
const SLOT := "res://scenes/item_slot.tscn"
const JOURNAL := "res://scenes/breeding_journal.tscn"
const HUNGER := "res://scenes/hunger_icon.tscn"
const CARE_THEME := "res://assets/care_notebook.tres"
const INK := Color("#482b20")
const MUTED_INK := Color("#67442e")


func _initialize() -> void:
	for path in [CARE, EGG, FOOD, SLOT, HUNGER, JOURNAL, CARE_THEME]:
		if FileAccess.file_exists(path):
			push_error("Compare edits in a fresh project copy: " + path)
			quit(1)
			return
	_make_care.call_deferred()


func _make_care() -> void:
	var betta: Node3D = load(BETTA_PATH).instantiate()
	if not betta.has_node("Rig/LowerJaw"):
		_add_betta_mouth(betta.get_node("Rig"))
		if not _save(betta, BETTA_PATH):
			quit(1)
			return
	else:
		betta.free()
	quit(0 if ResourceSaver.save(_notebook_theme(), CARE_THEME) == OK
		and _save(_egg(), EGG) and _save(_food(), FOOD) and _save(_item_slot(), SLOT)
		and _save(_hunger_icon(), HUNGER) and _save(_journal(), JOURNAL) and _save(_care(), CARE) else 1)


func _item_slot() -> MenuButton:
	var slot := MenuButton.new()
	slot.name = "ItemSlot"
	slot.flat = false
	slot.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	slot.custom_minimum_size = Vector2(58, 52)
	slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slot.expand_icon = true
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_theme_constant_override("icon_max_width", 26)
	return slot


func _hunger_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "HungerIcon"
	icon.texture = load("res://assets/items/hunger.png")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(18, 18)
	return icon


func _egg() -> Node3D:
	var egg := Node3D.new()
	egg.name = "EggClutch"
	var dish := CylinderMesh.new()
	dish.top_radius = 0.36
	dish.bottom_radius = 0.28
	dish.height = 0.077
	var tray := _mesh(egg, "Tray", dish, _material("#426971", false), Vector3.ZERO)
	tray.scale.z = 0.88
	for index in 3:
		_ball(egg, "Shell%d" % index, Vector3(0.14, 0.18, 0.14), Vector3(-0.16 + index * 0.16, 0.11, 0.028 * index),
			_material("#c9d9ad"))
	return egg


func _food() -> Node3D:
	var food := Node3D.new()
	food.name = "Food"
	food.set_script(load("res://scripts/food.gd"))
	_ball(food, "Pellet", Vector3.ONE * 0.068, Vector3.ZERO, _material("#f3b37f"))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.10
	torus.outer_radius = 0.115
	torus.rings = 12
	torus.ring_segments = 5
	_mesh(food, "Ripple", torus, _material("#83b9b2"), Vector3.ZERO)
	return food


func _care() -> Control:
	var root: Control = load(AQUARIUM_PATH).instantiate()
	root.set_script(load("res://scripts/care.gd"))
	var ui: Control = root.get_node("Controls")
	ui.theme = load(CARE_THEME)
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var panel := ui.get_node("FishPanel") as PanelContainer
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -207.0
	panel.offset_top = 68.0
	panel.offset_bottom = 230.0
	panel.add_theme_stylebox_override("panel", _wood_frame("panel", 10))
	var zoom := ui.get_node("ZoomControls") as HBoxContainer
	zoom.offset_top = -62
	zoom.offset_bottom = -12
	for button: Button in zoom.get_children():
		button.custom_minimum_size.x = 44.0
		button.add_theme_font_size_override("font_size", 16)
	var details := panel.get_node("Details")
	details.get_node("Header/FishName").add_theme_color_override("font_color", INK)
	for key in ["Status", "Traits"]:
		details.get_node(key).add_theme_color_override("font_color", MUTED_INK)
	for name in ["SellFish", "BreedFish", "Separator"]:
		details.get_node(name).free()
	var store: Button = details.get_node("StoreFish")
	store.owner = null
	details.remove_child(store)
	_label(details, "Hunger", "", 14, INK)
	_label(details, "Growth", "", 14, MUTED_INK)
	var actions := _journal_box(details, "FishActions", true)
	var feed := _button(actions, "FeedFish", "投餌", "選擇飼料落點", 0)
	_icon(feed, "flake")
	actions.add_child(store)
	var rename := LineEdit.new()
	rename.name = "RenameFish"
	rename.unique_name_in_owner = true
	rename.placeholder_text = "輸入名字，按 Enter"
	rename.max_length = 18
	rename.custom_minimum_size.y = 32
	details.add_child(rename)
	var extra := _journal_box(details, "FishRecords", true)
	var family := _button(extra, "ViewFamily", "家系", "查看父母與胎次", 0)
	family.hide()
	_button(extra, "RehomeFish", "送養…", "確認後騰出魚位", 0)
	for button: Button in [feed, store, family, extra.get_node("RehomeFish")]:
		button.custom_minimum_size.y = 34
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
	var storage: MenuButton = ui.get_node("StoredFish")
	storage.offset_left = -68
	storage.offset_bottom = 60
	storage.tooltip_text = "收起的魚"
	storage.text = ""
	_icon(storage, "stored")

	var header := HBoxContainer.new()
	header.name = "CareBar"
	ui.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	header.position = Vector2(12, 12)
	header.add_theme_constant_override("separation", 5)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon(_menu(header, "Shop", "商店"), "shop")
	_icon(_button(header, "Journal", "", "育種手札", 48), "journal")
	_icon(_button(header, "AudioSettings", "", "聲音設定", 48), "sound")
	var returns := _menu(header, "Returns", "回缸紀錄")
	_icon(returns, "silver_egg")
	returns.hide()
	var balance := _label(header, "Balance", "", 16, Color("#fae3ae"))
	var badge := _notebook_box("#67412c", "#c18453", 4)
	badge.content_margin_left = 10.0
	badge.content_margin_right = 10.0
	balance.add_theme_stylebox_override("normal", badge)
	balance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.mouse_filter = Control.MOUSE_FILTER_PASS

	var footer := _label(ui, "TankNotice", "", 16, Color("#fae3ae"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_left = -194
	footer.offset_right = 194
	footer.offset_top = -112
	footer.offset_bottom = -83
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_color_override("font_shadow_color", Color("#152f35"))
	footer.add_theme_constant_override("shadow_offset_y", 1)

	var aim := _label(ui, "FeedAim", "◈", 15, Color("#fae3ae"))
	aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim.hide()
	var birth := _label(ui, "BirthMarker", "✦", 14, Color("#fae3ae"))
	birth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	birth.hide()

	var hunger_icons := Control.new()
	hunger_icons.name = "HungerIcons"
	hunger_icons.unique_name_in_owner = true
	hunger_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hunger_icons)
	hunger_icons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bag := _button(ui, "InventoryToggle", "", "背包", 58)
	bag.toggle_mode = true
	_icon(bag, "bag")
	_bottom_right(bag, Vector2(60, 58), 12)

	var tools := _journal_box(ui, "ToolButtons", true)
	tools.unique_name_in_owner = true
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon(_button(tools, "RotateDecor", "", "旋轉 30 度", 54), "rotate")
	_icon(_button(tools, "ApplyDecor", "", "確認擺放", 54), "check")
	_icon(_button(tools, "CancelTool", "", "取消", 54), "cancel")
	tools.get_node("ApplyDecor").theme_type_variation = &"NotebookPrimary"
	_bottom_right(tools, Vector2(172, 54), 12)
	tools.hide()

	var inventory := PanelContainer.new()
	inventory.name = "Inventory"
	inventory.mouse_force_pass_scroll_events = false
	inventory.add_theme_stylebox_override("panel", _wood_frame("leaf_panel", 16))
	ui.add_child(inventory)
	_bottom_right(inventory, Vector2(106, 60), 77)
	inventory.hide()

	var slots := GridContainer.new()
	slots.name = "ItemSlots"
	slots.unique_name_in_owner = true
	slots.columns = 4
	slots.add_theme_constant_override("h_separation", 4)
	slots.add_theme_constant_override("v_separation", 4)
	inventory.add_child(slots)
	var empty := _label(slots, "InventoryEmpty", "背包是空的", 14, MUTED_INK)
	empty.custom_minimum_size = Vector2(76, 37)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var modal := _card(ui, "CareDialog", Vector2(285, 212))
	var rows := VBoxContainer.new()
	rows.name = "Content"
	rows.add_theme_constant_override("separation", 8)
	modal.add_child(rows)
	_label(rows, "DialogTitle", "送養魚隻", 17, INK)
	var body := _label(rows, "DialogText", "", 15, MUTED_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(rows, "Confirm", "確認送養", "", 0).custom_minimum_size.y = 42
	_button(rows, "CloseDialog", "取消", "", 0).custom_minimum_size.y = 42

	var audio := _card(ui, "AudioPanel", Vector2(268, 180))
	var audio_rows := VBoxContainer.new()
	audio_rows.name = "Rows"
	audio_rows.add_theme_constant_override("separation", 8)
	audio.add_child(audio_rows)
	for caption in ["總音量", "音樂", "水聲", "音效"]:
		var row := HBoxContainer.new()
		audio_rows.add_child(row, true)
		var label := _label(row, "Caption", caption, 12, INK)
		label.unique_name_in_owner = false
		label.custom_minimum_size.x = 55
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 22
		row.add_child(slider)
	_button(audio_rows, "CloseAudio", "完成", "", 0)
	var mixer := Node.new()
	mixer.name = "TankAudio"
	mixer.unique_name_in_owner = true
	mixer.set_script(load("res://scripts/tank_audio.gd"))
	root.add_child(mixer)
	for specification in [["Harmony", &"Music", -4.0], ["Melody", &"Music", 0.0],
		["Water", &"Water", -6.0], ["Effect", &"Effects", -8.0], ["Cue", &"Effects", -6.0]]:
		var player := AudioStreamPlayer.new()
		player.name = specification[0]
		player.bus = specification[1]
		player.volume_db = specification[2]
		mixer.add_child(player)

	var journal := (load(JOURNAL) as PackedScene).instantiate() as Control
	ui.add_child(journal)
	journal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	journal.offset_left = -238
	journal.offset_right = 238
	journal.offset_top = -154
	journal.offset_bottom = 154

	var world := root.get_node("TankView")
	world.add_child(_lamp())
	for group in ["Eggs", "Pellets"]:
		var holder := Node3D.new()
		holder.name = group
		world.add_child(holder)
		holder.owner = root
	return root


func _journal() -> PanelContainer:
	var journal := PanelContainer.new()
	journal.name = "BreedingJournal"
	journal.set_script(load("res://scripts/breeding_journal.gd"))
	journal.mouse_force_pass_scroll_events = false
	journal.hide()
	journal.add_theme_stylebox_override("panel", _wood_frame("leaf_panel", 16))
	var rows := VBoxContainer.new()
	rows.name = "Content"
	rows.add_theme_constant_override("separation", 7)
	journal.add_child(rows)
	var header := _journal_box(rows, "Header", true)
	var title := _label(header, "JournalHeading", "育種手札", 18, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "CloseJournal", "關閉", "回到魚缸", 50)
	var tabs := TabContainer.new()
	tabs.name = "JournalTabs"
	tabs.unique_name_in_owner = true
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(tabs)

	var collection := _journal_box(tabs, "圖鑑")
	var phenotypes := _journal_box(collection, "Phenotypes")
	phenotypes.unique_name_in_owner = true
	var names := ["普通鬥魚", "長尾鬥魚", "銀紋鬥魚", "月影鬥魚", "紅蓮燈"]
	var traits := ["短尾 · 無銀紋", "長尾 · 無銀紋", "短尾 · 月牙銀紋", "長尾 · 月牙銀紋", "紅色下腹 · 藍色亮帶"]
	for index in names.size():
		var row := _journal_box(phenotypes, "Phenotype%d" % index, true)
		row.custom_minimum_size.y = 29
		var fish := _label(row, "Name", names[index], 12, INK)
		fish.unique_name_in_owner = false
		fish.custom_minimum_size.x = 92
		var trait_label := _label(row, "Traits", traits[index], 10, MUTED_INK)
		trait_label.unique_name_in_owner = false
		trait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var date := _label(row, "Date", "尚未發現", 10, MUTED_INK)
		date.unique_name_in_owner = false
		date.custom_minimum_size.x = 80
	var badges := _label(collection, "Achievements", "", 11, INK)
	badges.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var family := _journal_box(tabs, "家系")
	_label(family, "HistoryEmpty", "第一胎孵化後，這裡會記下子代與親魚。", 11, MUTED_INK)
	var columns := _journal_box(family, "FamilyColumns", true)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	var history := _journal_list(columns, "History")
	history.custom_minimum_size = Vector2(144, 125)
	var lineage := _journal_box(columns, "Lineage")
	lineage.unique_name_in_owner = true
	lineage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parents := _journal_box(lineage, "Parents", true)
	_lineage_card(parents, "FirstParent")
	_lineage_card(parents, "SecondParent")
	var arrow := _label(lineage, "ParentsToChild", "↓", 14, MUTED_INK)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lineage_card(lineage, "ChildName")
	_label(lineage, "FamilyDate", "", 10, MUTED_INK)
	_label(lineage, "FamilyBadge", "穩定月影家系", 10, INK)
	_button(lineage, "FindChild", "在缸中找到這尾魚", "", 0)

	var pairing := _journal_box(tabs, "育種")
	_label(pairing, "PairStatus", "等待兩尾同種成魚", 16, MUTED_INK)
	_label(pairing, "HatchStatus", "", 16, INK)
	return journal


func _journal_box(parent: Node, node_name: String, horizontal := false) -> BoxContainer:
	var node: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	node.name = node_name
	node.add_theme_constant_override("separation", 5)
	parent.add_child(node)
	return node


func _journal_list(parent: Node, node_name: String) -> ItemList:
	var list := ItemList.new()
	list.name = node_name
	list.unique_name_in_owner = true
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.mouse_force_pass_scroll_events = false
	parent.add_child(list)
	return list


func _lineage_card(parent: Node, node_name: String) -> void:
	var card := PanelContainer.new()
	card.name = node_name + "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _notebook_box("#f5dcae", "#ae764e", 5))
	parent.add_child(card)
	var text := _label(card, node_name, "", 11, INK)
	text.custom_minimum_size.y = 35
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _lamp() -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "PlacedLamp"
	lamp.unique_name_in_owner = true
	var frame := _material("#404b71", false)
	_box(lamp, "Foot", Vector3(0.48, 0.10, 0.37), Vector3(0, 0.05, 0), frame)
	_box(lamp, "Stand", Vector3(0.09, 0.49, 0.09), Vector3(-0.12, 0.27, 0), frame)
	_box(lamp, "Hood", Vector3(0.43, 0.18, 0.31), Vector3(0.03, 0.55, 0), frame)
	_box(lamp, "Diffuser", Vector3(0.055, 0.105, 0.24), Vector3(0.248, 0.537, 0), _material("#b4c7ff"))
	var beam := SpotLight3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0.24, 0.56, 0)
	beam.rotation_degrees = Vector3(-12, -90, 0)
	beam.light_color = Color("#94a6ff")
	beam.light_energy = 1.6
	beam.spot_range = 5.2
	beam.spot_angle = 34.0
	lamp.add_child(beam)
	lamp.hide()
	return lamp


func _menu(parent: Node, node_name: String, title: String) -> MenuButton:
	var button := MenuButton.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.tooltip_text = title
	button.flat = false
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.custom_minimum_size = Vector2(48, 48)
	parent.add_child(button)
	return button


func _icon(button: Button, key: String) -> void:
	button.icon = load("res://assets/items/%s.png" % key)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("icon_max_width", 26)
	if key in ["rotate", "check", "cancel", "sound"]:
		for state in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			button.add_theme_color_override("icon_%s_color" % state, Color("#627368"))


func _bottom_right(control: Control, dimensions: Vector2, inset: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	control.offset_left = -12.0 - dimensions.x
	control.offset_right = -12.0
	control.offset_top = -inset - dimensions.y
	control.offset_bottom = -inset
	control.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _card(parent: Control, node_name: String, dimensions: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.unique_name_in_owner = true
	card.add_theme_stylebox_override("panel", _wood_frame("panel", 11))
	parent.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -dimensions.x / 2
	card.offset_right = dimensions.x / 2
	card.offset_top = -dimensions.y / 2
	card.offset_bottom = dimensions.y / 2
	card.mouse_force_pass_scroll_events = false
	card.hide()
	return card


func _notebook_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/NotoSansTC.ttf")
	theme.default_font_size = 11
	var cream := _wood_frame("tile", 6)
	var hover := _wood_frame("tile_highlight", 6)
	var amber := hover
	var disabled := _notebook_box("#e4c79d", "#9b795a", 5)
	var focus := _notebook_box("#00000000", "#71472b", 5)
	focus.shadow_size = 0
	theme.set_type_variation("NotebookPrimary", "Button")
	for type in ["Button", "MenuButton", "NotebookPrimary"]:
		theme.set_stylebox("normal", type, amber if type == "NotebookPrimary" else cream)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, amber)
		theme.set_stylebox("hover_pressed", type, amber)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(state, type, INK)
		theme.set_color("font_disabled_color", type, MUTED_INK)
	theme.set_stylebox("panel", "PopupMenu", _wood_frame("panel", 7))
	theme.set_stylebox("hover", "PopupMenu", amber)
	for state in ["font_color", "font_hover_color", "font_separator_color"]:
		theme.set_color(state, "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", Color("#856b52"))
	theme.set_font_size("font_size", "PopupMenu", 17)
	theme.set_constant("icon_max_width", "PopupMenu", 24)
	theme.set_constant("v_separation", "PopupMenu", 20)
	theme.set_stylebox("normal", "LineEdit", cream)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED_INK)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_stylebox("panel", "TabContainer", _notebook_box("#fff1d4", "#ae764e", 5))
	theme.set_stylebox("tab_selected", "TabContainer", amber)
	theme.set_stylebox("tab_unselected", "TabContainer", cream)
	theme.set_stylebox("tab_hovered", "TabContainer", hover)
	for state in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		theme.set_color(state, "TabContainer", INK)
	theme.set_stylebox("panel", "ItemList", cream)
	theme.set_stylebox("selected", "ItemList", amber)
	theme.set_stylebox("selected_focus", "ItemList", amber)
	theme.set_color("font_color", "ItemList", INK)
	theme.set_color("font_selected_color", "ItemList", INK)
	return theme


func _wood_frame(kind: String, padding: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/notebook/%s.png" % kind)
	var slice := 22.0 if kind == "leaf_panel" else 9.0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, slice)
		style.set_content_margin(side, padding)
	return style


func _notebook_box(fill: String, border: String, padding: int) -> StyleBoxFlat:
	var style := _panel(Color(fill), Color(border))
	style.set_border_width_all(2)
	style.border_width_bottom = 3
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	style.anti_aliasing = false
	style.shadow_color = Color("#43231966")
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 2)
	return style
