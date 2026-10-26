extends SceneTree
## One-time authoring tool. Existing scenes are skipped; normal startup never runs this file.
## Change saved scenes in the editor. Inspect diffs before an intentional rebuild.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const Catalog = preload("res://domain/catalog.gd")
var _theme: Theme
var _catalog: RefCounted
var _ok: bool = true


func _init() -> void:
	_build.call_deferred()


func _build() -> void:
	_catalog = Catalog.new()
	if not _catalog.errors.is_empty():
		push_error(str(_catalog.errors))
		quit(1)
		return
	_theme = _make_theme()
	ResourceSaver.save(_theme, "res://scenes/theme.tres")
	await _actor()
	_number()
	_unit_card()
	_item_card()
	_stage_card()
	_talent_card()
	_lane()
	_roster()
	_equipment()
	_map()
	_talents()
	_codex()
	_report()
	_main()
	print("DREAMLING SAVED SCENES ", "PASSED" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _save(node: Node, path: String, refs: Array = []) -> void:
	if path in ["res://scenes/panels/roster_panel.tscn", "res://scenes/panels/map_panel.tscn", "res://scenes/panels/talent_panel.tscn"]:
		var content: Control = node.get_child(0)
		node.remove_child(content)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_add(node, scroll, "PanelScroll")
		scroll.add_child(content)
		_expand(content)
	var overwrite: bool = "--overwrite-authored" in OS.get_cmdline_user_args()
	var result: Dictionary = B.save_scene(node, path, {"expected_refs": refs, "overwrite": overwrite})
	_ok = _ok and result.ok


func _add(parent: Node, child: Node, name: String, unique: bool = false) -> Node:
	B.add(parent, child, name)
	if unique: B.unique(child)
	return child


func _label(parent: Node, name: String, text: String, size: int = 18, tint: String = "dce2ed", unique: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color(tint))
	return _add(parent, node, name, unique)


func _button(parent: Node, name: String, text: String, unique: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 34
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return _add(parent, node, name, unique)


func _vbox(parent: Node, name: String, gap: int = 10, unique: bool = false) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return _add(parent, node, name, unique)


func _hbox(parent: Node, name: String, gap: int = 12) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return _add(parent, node, name)


func _margin(parent: Node, name: String, padding: int = 16) -> MarginContainer:
	var node := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		node.add_theme_constant_override("margin_" + side, padding)
	return _add(parent, node, name)


func _expand(node: Control, vertical: bool = false) -> void:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vertical: node.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _wrap(node: Label) -> void:
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _style(color: String, border: String = "343b50", padding: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color)
	box.border_color = Color(border)
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansTC.otf")
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("dce2ed"))
	theme.set_color("font_color", "Button", Color("ddd9ed"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	theme.set_color("font_disabled_color", "Button", Color("727e94"))
	theme.set_stylebox("normal", "Button", _style("292c41", "4a4561", 8))
	theme.set_stylebox("hover", "Button", _style("35374f", "aaa0d6", 8))
	theme.set_stylebox("pressed", "Button", _style("49425f", "c6b6ec", 8))
	theme.set_stylebox("disabled", "Button", _style("1b2030", "2d3445", 8))
	var focus: StyleBoxFlat = _style("00000000", "d8c28c", 8)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("panel", "PanelContainer", _style("191f2e", "33394e", 14))
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", _style("202638", "374156", 12))
	theme.set_type_variation("SelectedCard", "PanelContainer")
	theme.set_stylebox("panel", "SelectedCard", _style("2b2e42", "b7a2de", 12))
	theme.set_stylebox("background", "ProgressBar", _style("101722", "101722", 0))
	theme.set_stylebox("fill", "ProgressBar", _style("99c9b0", "99c9b0", 0))
	theme.set_font_size("font_size", "ProgressBar", 1)
	for key: String in ["background", "fill"]:
		var bar_style: StyleBoxFlat = theme.get_stylebox(key, "ProgressBar")
		bar_style.set_corner_radius_all(2)
	theme.set_stylebox("panel", "TabContainer", _style("171d2b", "363b50", 14))
	theme.set_stylebox("tab_selected", "TabContainer", _style("303047", "b7a2de", 11))
	theme.set_stylebox("tab_unselected", "TabContainer", _style("1c2232", "34394c", 11))
	theme.set_stylebox("tab_hovered", "TabContainer", _style("30354b", "77718e", 11))
	theme.set_font_size("font_size", "TabContainer", 20)
	theme.set_color("font_selected_color", "TabContainer", Color("eddfc4"))
	theme.set_color("font_unselected_color", "TabContainer", Color("929fb7"))
	return theme


func _actor() -> void:
	var root := Node2D.new()
	root.name = "UnitActor"
	root.set_script(load("res://scripts/actor_view.gd"))
	var shadow := Polygon2D.new()
	var points := PackedVector2Array()
	for i: int in 24:
		var angle: float = TAU * i / 24.0
		points.append(Vector2(cos(angle) * 46, sin(angle) * 7))
	shadow.polygon = points
	shadow.color = Color(0.03, 0.04, 0.07, 0.4)
	_add(root, shadow, "Shadow")
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/sprites/briar_boar.png")
	sprite.hframes = 5
	sprite.centered = false
	sprite.offset = Vector2(-256, -504)
	sprite.scale = Vector2.ONE * 0.36
	_add(root, sprite, "Body", true)
	var name_label: Label = _label(root, "ActorName", "苔角", 14, "c3edcf", true)
	name_label.position = Vector2(-50, -166)
	name_label.size = Vector2(100, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", _theme.default_font)
	var hp := ProgressBar.new()
	hp.theme = _theme
	hp.position = Vector2(-43, -137)
	hp.size = Vector2(86, 7)
	hp.show_percentage = false
	hp.value = 100
	_add(root, hp, "Health", true)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(-17,-95),Vector2(0,-116),Vector2(17,-95),Vector2(36,-80),Vector2(17,-65),Vector2(0,-43),Vector2(-17,-65),Vector2(-36,-80)])
	flash.color = Color(1, 0.93, 0.72, 0.8)
	flash.visible = false
	_add(root, flash, "HitFlash", true)
	# Theme minimum-size invalidation is deferred; resolve before serializing.
	get_root().add_child(root)
	await process_frame
	await process_frame
	hp.size = Vector2(86, 7)
	get_root().remove_child(root)
	_save(root, "res://scenes/world/unit_actor.tscn")


func _number() -> void:
	var root := Label.new()
	root.name = "FloatingNumber"
	root.set_script(load("res://scripts/floating_number.gd"))
	root.text = "24"
	root.add_theme_font_override("font", _theme.default_font)
	root.add_theme_font_size_override("font_size", 23)
	root.add_theme_color_override("font_shadow_color", Color("10131d"))
	root.add_theme_constant_override("shadow_offset_x", 2)
	root.add_theme_constant_override("shadow_offset_y", 2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_save(root, "res://scenes/world/floating_number.tscn")


func _unit_card() -> void:
	var root := PanelContainer.new()
	root.name = "UnitCard"
	root.theme_type_variation = "Card"
	root.custom_minimum_size = Vector2(212, 162)
	root.set_script(load("res://scripts/unit_card.gd"))
	var body: VBoxContainer = _vbox(root, "Body", 6)
	var top: HBoxContainer = _hbox(body, "Top", 6)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(68, 68)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/briar_boar.png")
	atlas.region = Rect2(0, 80, 512, 432)
	portrait.texture = atlas
	_add(top, portrait, "Portrait", true)
	var labels: VBoxContainer = _vbox(top, "Labels", 4)
	_expand(labels)
	_label(labels, "CardName", "苔角  Lv.1", 19, "e7dec9", true)
	_label(labels, "CardRole", "森靈 · 守護", 15, "a4b0c5", true)
	_label(labels, "CardStats", "攻 15 · 血 176", 15, "b5c4bd", true)
	var xp := ProgressBar.new()
	xp.custom_minimum_size.y = 4
	xp.show_percentage = false
	_add(body, xp, "CardXP", true)
	var buttons: HBoxContainer = _hbox(body, "Actions", 8)
	_expand(_button(buttons, "Inspect", "查看", true))
	_expand(_button(buttons, "Deploy", "上陣", true))
	_save(root, "res://scenes/items/unit_card.tscn")


func _item_card() -> void:
	var root := PanelContainer.new()
	root.name = "EquipmentCard"
	root.theme_type_variation = "Card"
	root.custom_minimum_size = Vector2(242, 184)
	root.set_script(load("res://scripts/equipment_card.gd"))
	var body: VBoxContainer = _vbox(root, "Body", 6)
	var top: HBoxContainer = _hbox(body, "Top")
	_label(top, "ItemIcon", "刃", 32, "c8b3e8", true)
	var labels: VBoxContainer = _vbox(top, "Labels", 2)
	_label(labels, "ItemName", "旅人短刃", 18, "e8d7b4", true)
	_label(labels, "ItemKind", "武器", 14, "929fb7", true)
	_label(body, "ItemStats", "攻擊 6（+6）\n生命 0（+0）· 甲 0", 16, "c1cbdc", true)
	_label(body, "ItemOwner", "背包中 · 售價 15", 14, "98ad9d", true)
	var actions: HBoxContainer = _hbox(body, "Actions", 6)
	_expand(_button(actions, "EquipItem", "穿戴", true))
	_button(actions, "LockItem", "鎖定", true)
	_button(actions, "SellItem", "出售", true)
	_save(root, "res://scenes/items/equipment_card.tscn")


func _stage_card() -> void:
	var root := PanelContainer.new()
	root.name = "StageCard"
	root.theme_type_variation = "Card"
	root.custom_minimum_size = Vector2(365, 158)
	root.set_script(load("res://scripts/stage_card.gd"))
	var body: VBoxContainer = _vbox(root, "Body", 5)
	var row: HBoxContainer = _hbox(body, "Title")
	_label(row, "StageNumber", "01 — 01", 16, "aaa1ce", true)
	_label(row, "StageName", "霧林邊境", 22, "e7d8b7", true)
	_label(body, "StageDescription", "柔軟的草地，第一段旅程", 16, "aebbd0", true)
	_label(body, "StageReward", "擊殺 9 金／9 EXP · 三波遭遇", 15, "98baa9", true)
	_button(body, "Travel", "前往挑戰", true)
	_save(root, "res://scenes/items/stage_card.tscn")


func _talent_card() -> void:
	var root := PanelContainer.new()
	root.name = "TalentCard"
	root.theme_type_variation = "Card"
	root.custom_minimum_size = Vector2(365, 140)
	root.set_script(load("res://scripts/talent_card.gd"))
	var body: VBoxContainer = _vbox(root, "Body", 8)
	_label(body, "TalentName", "勇氣  0／5", 22, "e0ccaa", true)
	_label(body, "TalentDescription", "每級：全隊攻擊 +8%", 16, "b4c1d5", true)
	_button(body, "BuyTalent", "提升 · 60 金", true)
	_save(root, "res://scenes/items/talent_card.tscn")


func _lane() -> void:
	var root := Control.new()
	root.name = "BattleLane"
	root.custom_minimum_size.y = 190
	root.clip_contents = true
	root.set_script(load("res://scripts/battle_lane.gd"))
	for spec: Array in [["Sky", "sky", 0.0], ["FarLayer", "far", 0.14], ["MidLayer", "mid", 0.45], ["Ground", "ground", 0.90]]:
		var texture := TextureRect.new()
		texture.texture = load("res://assets/backgrounds/%s.png" % spec[1])
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture.anchor_top = float(spec[2])
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if spec[0] in ["FarLayer", "MidLayer"]:
			var material := ShaderMaterial.new()
			material.shader = load("res://assets/scroll.gdshader")
			texture.material = material
			texture.modulate = Color("a1abbf") if spec[0] == "FarLayer" else Color("b1a6b9")
		_add(root, texture, spec[0], spec[0] != "Ground")
	var ground := ColorRect.new()
	ground.color = Color("212637")
	ground.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ground.offset_top = -22
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, ground, "GroundEdge")
	var actors := Node2D.new()
	_add(root, actors, "Actors", true)
	for spec: Array in [["PreviewGuardian", 350.0, "moss"], ["PreviewStriker", 220.0, "ember"], ["PreviewEnemy", 850.0, "moss"]]:
		var actor: Node2D = B.instance("res://scenes/world/unit_actor.tscn")
		actor.position = Vector2(float(spec[1]), 166)
		actor.species_id = spec[2]
		actor.display_name = _catalog.units[spec[2]].name
		_add(actors, actor, spec[0])
	var numbers := Control.new()
	numbers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, numbers, "Numbers", true)
	_save(root, "res://scenes/world/battle_lane.tscn", ["res://scenes/world/unit_actor.tscn"])


func _panel(name: String) -> MarginContainer:
	var root := MarginContainer.new()
	root.name = name
	for side: String in ["top", "bottom", "left", "right"]:
		root.add_theme_constant_override("margin_" + side, 4)
	return root


func _roster() -> void:
	var root: MarginContainer = _panel("RosterPanel")
	var body: HBoxContainer = _hbox(root, "Columns", 20)
	var left: VBoxContainer = _vbox(body, "Roster", 10)
	_expand(left)
	_label(left, "Title", "同行夥伴", 22, "dfd1b5")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_add(left, grid, "UnitCards", true)
	for id: String in _catalog.units:
		var card: Control = B.instance("res://scenes/items/unit_card.tscn")
		card.definition_id = id
		_add(grid, card, id.capitalize())
	var detail := PanelContainer.new()
	detail.custom_minimum_size.x = 360
	_add(body, detail, "Details")
	var box: VBoxContainer = _vbox(detail, "DetailBody", 10)
	_label(box, "DetailName", "苔角 · 守護", 25, "e8d7b5", true)
	_label(box, "DetailTags", "森靈 ／ 大地", 17, "b5a4d6", true)
	var description: Label = _label(box, "DetailDescription", "厚實的苔甲守住最前排。和另一名森靈同行，整隊生命提高15%。", 17, "b5c1d4", true)
	_wrap(description)
	_label(box, "DetailStats", "生命 176\n攻擊 15\n護甲 24\n攻擊間隔 1.65 秒", 18, "d2ddda", true)
	var xp: Label = _label(box, "DetailXP", "Lv.1 · EXP 0／36", 16, "8fa1b9", true)
	_wrap(xp)
	var spacer := Control.new()
	_expand(spacer, true)
	_add(box, spacer, "Spacer")
	_button(box, "Train", "訓練升級 · 18 金", true)
	var recruit: Button = _button(box, "Recruit", "邀請同行", true)
	recruit.visible = false
	_save(root, "res://scenes/panels/roster_panel.tscn", ["res://scenes/items/unit_card.tscn"])


func _equipment() -> void:
	var root: MarginContainer = _panel("EquipmentPanel")
	var body: VBoxContainer = _vbox(root, "Body", 12)
	var top: HBoxContainer = _hbox(body, "Selection", 12)
	_label(top, "Title", "為夥伴準備行裝", 22, "dfd1b5")
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(150, 36)
	picker.add_item("苔角")
	_add(top, picker, "EquipUnit", true)
	var spacer := Control.new()
	_expand(spacer)
	_add(top, spacer, "Spacer")
	_button(top, "ClaimPending", "領取待領裝備（0）", true)
	var slots: HBoxContainer = _hbox(body, "Slots", 14)
	for spec: Array in [["Weapon", "武器"], ["Armor", "護具"]]:
		var panel := PanelContainer.new()
		_expand(panel)
		_add(slots, panel, str(spec[0]) + "Slot")
		var row: HBoxContainer = _hbox(panel, "Row", 12)
		_label(row, "Caption", spec[1], 17, "a89ac7")
		_expand(_label(row, str(spec[0]) + "Name", "未穿戴", 18, "dce2ed", true))
		_button(row, "Remove" + str(spec[0]), "卸下", true)
	_label(body, "Hint", "括號顯示與目前穿戴的差值。鎖定可保護裝備；滿包掉落會保存在待領箱。", 16, "9caac0")
	var scroll := ScrollContainer.new()
	_expand(scroll, true)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_add(body, scroll, "GearScroll")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_expand(grid)
	_add(scroll, grid, "GearCards", true)
	for i: int in 3:
		_add(grid, B.instance("res://scenes/items/equipment_card.tscn"), "PreviewGear%d" % i)
	_save(root, "res://scenes/panels/equipment_panel.tscn", ["res://scenes/items/equipment_card.tscn"])


func _map() -> void:
	var root: MarginContainer = _panel("MapPanel")
	var body: VBoxContainer = _vbox(root, "Body", 10)
	_label(body, "Title", "旅程地圖", 23, "dfd1b5")
	_label(body, "Description", "關卡首次完成會獲得額外金幣與裝備。卡關時，可關閉自動前進並回到舊獵場。", 17, "a8b5cb")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_add(body, grid, "StageCards", true)
	for i: int in _catalog.stages.size():
		var card: Control = B.instance("res://scenes/items/stage_card.tscn")
		card.stage_index = i
		_add(grid, card, "Stage%d" % i)
	_save(root, "res://scenes/panels/map_panel.tscn", ["res://scenes/items/stage_card.tscn"])


func _talents() -> void:
	var root: MarginContainer = _panel("TalentPanel")
	var body: VBoxContainer = _vbox(root, "Body", 10)
	_label(body, "Title", "旅途天賦", 23, "dfd1b5")
	_label(body, "Hint", "勇氣 → 結伴／流轉     根脈 → 拾光／甘霖回響。購買後，下波套用新的隊伍能力。", 17, "a8b5cb")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_add(body, grid, "TalentCards", true)
	for definition: Dictionary in _catalog.talents:
		var card: Control = B.instance("res://scenes/items/talent_card.tscn")
		card.talent_id = definition.id
		_add(grid, card, str(definition.id).capitalize())
	_save(root, "res://scenes/panels/talent_panel.tscn", ["res://scenes/items/talent_card.tscn"])


func _rich(parent: Node, name: String, text: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = text
	rich.add_theme_font_size_override("normal_font_size", 18)
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return _add(parent, rich, name, true)


func _codex() -> void:
	var root: MarginContainer = _panel("CodexPanel")
	_rich(root, "CodexText", "[font_size=24]旅途中的六位夢靈[/font_size]\n\n苔角 · 森靈／守護\n燼尾 · 獸靈／突襲\n露露 · 森靈／療癒\n\n探索新的獵場，遇見更多同行夥伴。")
	_save(root, "res://scenes/panels/codex_panel.tscn")


func _report() -> void:
	var root: MarginContainer = _panel("ReportPanel")
	var row: HBoxContainer = _hbox(root, "Columns", 22)
	var left: RichTextLabel = _rich(row, "StatsText", "[font_size=24]這趟旅程[/font_size]\n\n傷害與治療貢獻會記在這裡。")
	left.custom_minimum_size.x = 440
	_rich(row, "Journal", "00:00  旅程開始了。")
	_save(root, "res://scenes/panels/report_panel.tscn")


func _main() -> void:
	var root := Control.new()
	root.name = "DreamlingTrails"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme
	root.set_script(load("res://scripts/main.gd"))
	var background := ColorRect.new()
	background.color = Color("0f1522")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, background, "Background")
	var margin: MarginContainer = _margin(root, "OuterMargin", 16)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body: VBoxContainer = _vbox(margin, "BodyRows", 8, true)
	var header: HBoxContainer = _hbox(body, "Header", 16)
	var brand: VBoxContainer = _vbox(header, "Brand", 2)
	_expand(brand)
	_label(brand, "HeaderTitle", "夢靈遠行", 30, "e9d8b2", true)
	_label(brand, "Subtitle", "DREAMLING TRAILS  /  讓小小的旅程，慢慢變強", 14, "8f9eb8")
	_label(header, "Collection", "同行 3／6 · 擊倒 0", 17, "a6b6c6", true)
	_label(header, "Gold", "100 金", 24, "ebca8b", true)
	_button(header, "Pause", "暫停", true)
	_button(header, "Sound", "聲音：關", true)
	_button(header, "Save", "儲存", true)
	var help := PanelContainer.new()
	help.add_theme_stylebox_override("panel", _style("191f2e", "33394e", 5))
	_add(body, help, "HelpBar", true)
	var help_row: HBoxContainer = _hbox(help, "Row")
	var help_text: Label = _label(help_row, "HelpText", "先看小隊自動作戰。卡關時加入露露補血，或在天賦購買「結伴」開第三格。", 17, "bfcab9")
	_wrap(help_text)
	_button(help_row, "DismissHelp", "知道了", true)
	var battle := PanelContainer.new()
	_add(body, battle, "BattlePanel")
	var battle_rows: VBoxContainer = _vbox(battle, "Rows", 7)
	var status: HBoxContainer = _hbox(battle_rows, "Status", 18)
	_expand(_label(status, "CurrentStage", "01-01 霧林邊境", 21, "e4d1ad", true))
	_label(status, "BattleState", "第 1／3 波 · 敵人 3", 17, "a6b8ce", true)
	var auto := CheckButton.new()
	auto.text = "自動前進"
	auto.button_pressed = true
	_add(status, auto, "AutoAdvance", true)
	var lane: Control = B.instance("res://scenes/world/battle_lane.tscn")
	_add(battle_rows, lane, "BattleLane", true)
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 4
	progress.show_percentage = false
	_add(battle_rows, progress, "StageProgress", true)
	var party: HBoxContainer = _hbox(body, "PartySummary", 12)
	_label(party, "PartyStatus", "上陣 2／2 · 配置已生效", 16, "ada2cf", true)
	_expand(_label(party, "BondSummary", "2名同族可啟動羈絆", 16, "a5c4b4", true))
	var pages := TabContainer.new()
	_expand(pages, true)
	pages.custom_minimum_size.y = 350
	_add(body, pages, "Pages", true)
	var refs: Array = ["res://scenes/world/battle_lane.tscn"]
	var index: int = 0
	for spec: Array in [["RosterPanel", "roster", "夢靈"], ["EquipmentPanel", "equipment", "裝備"], ["MapPanel", "map", "地圖"], ["TalentPanel", "talent", "天賦"], ["CodexPanel", "codex", "圖鑑"], ["ReportPanel", "report", "戰報"]]:
		var path: String = "res://scenes/panels/%s_panel.tscn" % spec[1]
		var panel: Control = B.instance(path)
		_add(pages, panel, spec[0], true)
		pages.set_tab_title(index, spec[2])
		refs.append(path)
		index += 1
	var recovery: Label = _label(body, "RecoveryNotice", "", 16, "f0a99e", true)
	_wrap(recovery)
	recovery.visible = false
	var toast: Label = _label(body, "Toast", "先看隊伍自動作戰；每次調整都會在下一波一起生效。", 17, "d8dccb", true)
	toast.custom_minimum_size.y = 25
	toast.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var footer: HBoxContainer = _hbox(body, "Footer", 12)
	_expand(_label(footer, "BagSummary", "背包 1／36 · 待領 0／64", 14, "8191aa", true))
	_label(footer, "SaveStatus", "每20秒自動儲存 · 關閉後暫停收益", 14, "8191aa", true)
	var driver := Node.new()
	driver.set_script(load("res://scripts/simulation_driver.gd"))
	_add(root, driver, "SimulationDriver", true)
	var sound := Node.new()
	sound.set_script(load("res://scripts/sfx.gd"))
	sound.voices = 5
	sound.volume_db = -14.0
	_add(root, sound, "Sfx", true)
	_save(root, "res://scenes/main.tscn", refs)
