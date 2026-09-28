extends SceneTree
## One-shot scene authoring tool. Run only when intentionally replacing these UI scenes.
## Runtime startup and tests load the saved .tscn files and never invoke this script.

const PAGE_IDS: Array[String] = ["overview", "train", "backpack", "monster", "equipment", "adventure", "store"]
const NAV_IDS: Array[String] = ["train", "backpack", "monster", "equipment", "adventure", "store"]
const NAV_LABELS: Array[String] = ["訓練", "背包", "怪獸", "裝備", "冒險", "商店"]
const STAT_KEYS: Array[String] = ["attack", "defense", "health", "speed", "crit", "regen"]
const STAT_LABELS: Array[String] = ["攻擊", "防禦", "生命", "速度", "暴擊", "回復"]
const SLOT_KEYS: Array[String] = ["weapon", "shield", "armor", "helmet", "boots", "accessory"]
const SLOT_LABELS: Array[String] = ["武器", "盾牌", "盔甲", "頭盔", "靴子", "飾品"]
const MONSTER_SLOT_KEYS: Array[String] = ["necklace", "badge", "armor", "claws", "cape", "accessory"]
const MONSTER_SLOT_LABELS: Array[String] = ["項圈", "徽章", "護甲", "利爪", "披風", "飾品"]
const INK := Color("20283e")
const MUTED := Color("756b68")
const PAPER := Color("ead5bd")
const BLUE := Color("344b6d")
const NAVY := Color("1b263b")
const GOLD := Color("efc96f")

var manifest: Dictionary = {}
var textures: Dictionary = {}
var styles: Dictionary = {}
var font_body: Font
var font_bold: Font
var theme: Theme

func _init() -> void:
	call_deferred("build")

func build() -> void:
	font_body = load("res://fonts/NotoSansCJKtc-Medium.otf") as Font
	font_bold = load("res://fonts/NotoSansCJKtc-Bold.otf") as Font
	assert(font_body != null, "NotoSansCJKtc-Medium.otf is required")
	assert(font_bold != null, "NotoSansCJKtc-Bold.otf is required")
	theme = Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 26
	ResourceSaver.save(theme, "res://ui/reference_theme.tres")
	_make_assets()
	_make_components()
	_make_header()
	_make_navigation()
	for page_id in PAGE_IDS:
		_make_page(page_id)
	_make_main()
	var file := FileAccess.open("res://assets/atlas/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("REFERENCE UI SCENES AUTHORED")
	quit()

func _root_of(node: Node) -> Node:
	var current := node
	while current.get_parent() != null:
		current = current.get_parent()
	return current

func attach(parent: Node, child: Node, id: String) -> Node:
	child.name = id
	parent.add_child(child)
	var scene_root := _root_of(parent)
	child.owner = scene_root
	if not child.scene_file_path.is_empty():
		scene_root.set_editable_instance(child, true)
	return child

func rect(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.offset_left = x
	control.offset_top = y
	control.offset_right = x + width
	control.offset_bottom = y + height

func base(id: String, width: float = 941.0, height: float = 1672.0) -> Control:
	var control := Control.new()
	control.name = id
	control.custom_minimum_size = Vector2(width, height)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.theme = theme
	return control

func atlas(id: String, source: String, region: Rect2) -> AtlasTexture:
	if textures.has(id):
		return textures[id] as AtlasTexture
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/reference/%s.png" % source) as Texture2D
	assert(texture.atlas != null, "Missing reference image: " + source)
	texture.region = region
	texture.filter_clip = true
	var path := "res://assets/atlas/%s.tres" % id
	assert(ResourceSaver.save(texture, path) == OK, "Cannot save atlas texture: " + path)
	textures[id] = texture
	manifest[id] = {
		"source": source + ".png",
		"rect": [region.position.x, region.position.y, region.size.x, region.size.y],
		"usage": "art region only; UI copy, state and clickable controls are separate scene nodes"
	}
	return texture

func image(parent: Node, id: String, texture: Texture2D, bounds: Rect2) -> TextureRect:
	var control := TextureRect.new()
	control.texture = texture
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_SCALE
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach(parent, control, id)
	rect(control, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	return control

func _flat(background: Color, edge: Color = Color("c5aa8c"), border: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = edge
	style.set_border_width_all(border)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.corner_detail = 2
	return style

func _make_styles() -> void:
	styles["paper"] = _flat(Color("f1dfc9"), Color("c5aa8c"), 2)
	styles["card"] = _flat(Color("f7e8d5"), Color("ccb49a"), 2)
	styles["slot"] = _flat(Color("e6cfb5"), Color("bea68c"), 2)
	styles["slot_selected"] = _flat(Color("e9d5bb"), Color("dfaa4a"), 4)
	styles["blue"] = _flat(Color("415d85"), Color("8ca0bd"), 3)
	styles["blue_hover"] = _flat(Color("54739d"), Color("f3d78f"), 3)
	styles["blue_pressed"] = _flat(Color("2c405f"), Color("f3d78f"), 3)
	styles["green"] = _flat(Color("4e9661"), Color("c0e28e"), 3)
	styles["green_hover"] = _flat(Color("60aa70"), Color("f1df9b"), 3)
	styles["gold"] = _flat(Color("f0cf70"), Color("a97b33"), 4)
	styles["nav"] = _flat(Color("2d3d5a"), Color("7286a6"), 3)
	styles["nav_active"] = _flat(Color("354b6b"), Color("f3d28a"), 4)
	styles["transparent"] = StyleBoxEmpty.new()
	var paper_frame := StyleBoxTexture.new()
	paper_frame.texture = atlas("paper_border_only", "equipment", Rect2(8, 527, 925, 994))
	paper_frame.texture_margin_left = 18
	paper_frame.texture_margin_top = 18
	paper_frame.texture_margin_right = 18
	paper_frame.texture_margin_bottom = 18
	paper_frame.draw_center = false
	styles["paper_frame"] = paper_frame
	for style_id in ["paper_frame", "paper", "card", "slot", "slot_selected", "blue", "green", "gold", "nav", "nav_active"]:
		var save_path := "res://ui/%s.tres" % style_id
		assert(ResourceSaver.save(styles[style_id], save_path) == OK, "Cannot save UI style: " + style_id)

func panel(parent: Node, id: String, bounds: Rect2, kind: String = "card") -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style_key := "paper_frame" if kind == "paper_frame" else kind
	node.add_theme_stylebox_override("panel", styles.get(style_key, styles["card"]))
	attach(parent, node, id)
	rect(node, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	if kind == "paper_frame":
		var fill := Panel.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.add_theme_stylebox_override("panel", _flat(PAPER, Color.TRANSPARENT, 0))
		fill.show_behind_parent = true
		attach(node, fill, "PaperFill")
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.offset_left = 18
		fill.offset_top = 18
		fill.offset_right = -18
		fill.offset_bottom = -18
	return node

func label(parent: Node, id: String, value: String, bounds: Rect2, font_size: int = 26, color: Color = INK, centered: bool = false, bold: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", color)
	node.add_theme_constant_override("outline_size", 0)
	if bold:
		node.add_theme_font_override("font", font_bold)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach(parent, node, id)
	rect(node, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	return node

func button(parent: Node, id: String, value: String, bounds: Rect2, action: String, kind: String = "blue", font_size: int = 25) -> Button:
	var node := Button.new()
	node.text = value
	node.set_meta("action", action)
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", font_bold)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color.WHITE if kind in ["blue", "nav", "nav_active"] else INK)
	node.add_theme_color_override("font_disabled_color", Color("847a70"))
	node.add_theme_stylebox_override("normal", styles.get(kind, styles["blue"]))
	node.add_theme_stylebox_override("hover", styles["blue_hover"] if kind == "blue" else styles.get(kind, styles["blue"]))
	node.add_theme_stylebox_override("pressed", styles["blue_pressed"] if kind == "blue" else styles.get(kind, styles["blue"]))
	node.add_theme_stylebox_override("disabled", styles.get("slot", styles["card"]))
	node.add_theme_stylebox_override("focus", styles["slot_selected"])
	attach(parent, node, id)
	rect(node, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	return node

func bar(parent: Node, id: String, bounds: Rect2, value: float = 0.0) -> ProgressBar:
	var node := ProgressBar.new()
	node.min_value = 0
	node.max_value = 100
	node.value = value
	node.show_percentage = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("background", _flat(Color("26344c"), Color("71829c"), 2))
	node.add_theme_stylebox_override("fill", _flat(Color("88ca76"), Color("88ca76"), 0))
	attach(parent, node, id)
	rect(node, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	return node

func _make_assets() -> void:
	_make_styles()
	atlas("portrait", "idel", Rect2(19, 10, 97, 90))
	atlas("coin", "idel", Rect2(500, 29, 45, 45))
	atlas("gem", "idel", Rect2(704, 27, 44, 49))
	atlas("gear", "idel", Rect2(865, 27, 50, 48))
	atlas("battle_sky", "equipment", Rect2(0, 100, 941, 248))
	atlas("hero_fullbody", "equipment", Rect2(45, 686, 183, 239))
	atlas("battle_tree_strip", "equipment", Rect2(0, 360, 56, 110))
	atlas("battle_lower_strip", "equipment", Rect2(420, 360, 140, 110))
	atlas("battle_ground", "equipment", Rect2(0, 470, 941, 55))
	atlas("title_train", "train", Rect2(63, 796, 147, 146))
	atlas("title_backpack", "backpack", Rect2(37, 734, 85, 76))
	atlas("title_monster", "monster", Rect2(50, 674, 269, 243))
	atlas("title_equipment", "equipment", Rect2(514, 1550, 92, 84))
	atlas("title_adventure", "adventure", Rect2(48, 792, 122, 94))
	atlas("title_store", "store", Rect2(74, 743, 115, 85))
	var nav_regions: Array[Rect2] = [
		Rect2(44, 1546, 83, 70), Rect2(196, 1545, 83, 70), Rect2(347, 1545, 88, 70),
		Rect2(510, 1546, 98, 70), Rect2(661, 1542, 90, 70), Rect2(816, 1545, 88, 70)
	]
	for i in nav_regions.size():
		atlas("nav_%d" % i, "equipment", nav_regions[i])
	for i in 4:
		atlas("training_%d" % i, "train", Rect2(52, 994 + i * 132, 96, 89))
	var monster_regions: Array[Rect2] = [
		Rect2(62, 1297, 176, 119), Rect2(283, 1297, 168, 118),
		Rect2(500, 1297, 170, 118), Rect2(719, 1297, 167, 118)
	]
	for i in monster_regions.size():
		atlas("monster_%d" % i, "monster", monster_regions[i])
	atlas("pet_detail", "monster", Rect2(50, 674, 269, 243))
	atlas("pet_overview", "idel", Rect2(40, 984, 260, 219))
	var item_regions: Array[Rect2] = [
		Rect2(77, 937, 91, 98), Rect2(245, 951, 99, 84), Rect2(414, 938, 110, 97),
		Rect2(580, 944, 122, 91), Rect2(756, 942, 119, 93), Rect2(67, 1141, 116, 99),
		Rect2(240, 1144, 112, 96), Rect2(414, 1145, 111, 95), Rect2(597, 1144, 90, 96),
		Rect2(756, 1148, 118, 92)
	]
	for i in item_regions.size():
		atlas("item_%d" % i, "backpack", item_regions[i])
	var equipment_icon_x: Array[int] = [39, 164, 289, 414, 539, 664, 789]
	for i in 15:
		var row: int = 0 if i < 7 else 1
		var col: int = i % 7
		var top: int = 1315 if row == 0 else 1420
		if i < 14:
			atlas("equipment_item_%d" % i, "equipment", Rect2(equipment_icon_x[col], top, 100, 72))
		else:
			atlas("equipment_item_14", "backpack", Rect2(756, 1148, 118, 92))
	for i in 4:
		atlas("stage_%d" % i, "adventure", Rect2(68 + i * 213, 1134, 130, 99))
		atlas("reward_%d" % i, "adventure", Rect2(61 + i * 96, 1358, 83, 84))
	var product_regions: Array[Rect2] = [
		Rect2(48, 930, 175, 136), Rect2(276, 928, 161, 138),
		Rect2(503, 930, 161, 134), Rect2(752, 928, 115, 137)
	]
	for i in product_regions.size():
		atlas("product_%d" % i, "store", product_regions[i])
	atlas("chapter_scenery", "adventure", Rect2(421, 900, 482, 188))
	atlas("gift", "store", Rect2(41, 1314, 295, 154))
	atlas("shop_coin", "store", Rect2(49, 1070, 37, 40))
	atlas("shop_gem", "store", Rect2(303, 1070, 41, 40))
	atlas("store_decoration", "store", Rect2(451, 721, 463, 117))
	atlas("video_icon", "store", Rect2(692, 1368, 62, 59))

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _own_all(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		if child.owner == null and child.scene_file_path.is_empty():
			child.owner = scene_root
		_own_all(child, scene_root)

func save_scene(node: Node, path: String) -> void:
	_own_all(node, node)
	var expected_nodes := _count_nodes(node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK, "PackedScene.pack failed: " + path)
	assert(ResourceSaver.save(packed, path) == OK, "ResourceSaver.save failed: " + path)
	var reopened := (load(path) as PackedScene).instantiate()
	assert(_count_nodes(reopened) == expected_nodes, "Owner / child-scene mismatch: " + path)
	print("AUTHORED ", path, " nodes=", expected_nodes)
	reopened.free()
	node.free()

func component(parent: Node, path: String, id: String) -> Control:
	var instance := (load(path) as PackedScene).instantiate() as Control
	attach(parent, instance, id)
	return instance

func _make_components() -> void:
	var card := base("EquipmentItemCard", 164, 145)
	panel(card, "Frame", Rect2(0, 0, 164, 145), "card")
	image(card, "Icon", atlas("item_0", "backpack", Rect2(77, 937, 91, 98)), Rect2(46, 7, 72, 67))
	label(card, "Title", "短劍", Rect2(5, 76, 154, 31), 22, INK, true, true)
	label(card, "Level", "Lv.1", Rect2(5, 108, 73, 27), 19, MUTED, true)
	label(card, "EquippedBy", "", Rect2(78, 108, 81, 27), 16, Color("4f825d"), true)
	var select := button(card, "SelectButton", "", Rect2(0, 0, 164, 145), "backpack_item:", "transparent", 18)
	select.add_theme_stylebox_override("hover", _flat(Color(0.2, 0.26, 0.34, 0.16), Color("f0c76d"), 3))
	select.add_theme_stylebox_override("pressed", _flat(Color(0.2, 0.26, 0.34, 0.20), Color("f0c76d"), 3))
	save_scene(card, "res://scenes/components/equipment_item_card.tscn")

	var compact_card := base("EquipmentBagCard", 118, 70)
	panel(compact_card, "Frame", Rect2(0, 0, 118, 70), "card")
	var compact_icon := image(compact_card, "Icon", atlas("equipment_item_0", "equipment", Rect2(39, 1315, 100, 72)), Rect2(39, 3, 40, 37))
	compact_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var compact_title := label(compact_card, "Title", "", Rect2(0, 0, 1, 1), 14, INK, true, true)
	compact_title.visible = false
	label(compact_card, "Level", "Lv.1", Rect2(7, 43, 104, 23), 14, MUTED, true)
	var compact_owner := label(compact_card, "EquippedBy", "", Rect2(0, 0, 1, 1), 11, Color("4f825d"), true)
	compact_owner.visible = false
	var compact_select := button(compact_card, "SelectButton", "", Rect2(0, 0, 118, 70), "equipment_item:", "transparent", 14)
	compact_select.add_theme_stylebox_override("hover", _flat(Color(0.2, 0.26, 0.34, 0.16), Color("f0c76d"), 2))
	compact_select.add_theme_stylebox_override("pressed", _flat(Color(0.2, 0.26, 0.34, 0.20), Color("f0c76d"), 2))
	save_scene(compact_card, "res://scenes/components/equipment_bag_card.tscn")

	var monster := base("MonsterCard", 211, 430)
	panel(monster, "Frame", Rect2(0, 0, 211, 430), "card")
	image(monster, "Icon", atlas("monster_0", "monster", Rect2(62, 1297, 176, 119)), Rect2(39, 18, 133, 118))
	label(monster, "Level", "Lv.1", Rect2(8, 139, 195, 36), 22, INK, true, true)
	label(monster, "Title", "怪獸名稱", Rect2(8, 173, 195, 42), 27, INK, true, true)
	label(monster, "Status", "未部署", Rect2(9, 214, 193, 32), 19, MUTED, true)
	button(monster, "InspectButton", "查看", Rect2(13, 271, 185, 58), "monster:0", "blue", 23)
	button(monster, "DeploymentButton", "部署", Rect2(13, 344, 185, 61), "deploy:sprout", "green", 23)
	save_scene(monster, "res://scenes/components/monster_card.tscn")

	var training := base("TrainingRow", 881, 190)
	panel(training, "Frame", Rect2(0, 0, 881, 190), "card")
	image(training, "Icon", atlas("training_0", "train", Rect2(52, 994, 96, 89)), Rect2(18, 38, 103, 104))
	label(training, "Title", "劍術", Rect2(138, 16, 210, 48), 32, INK, false, true)
	label(training, "TrainingLevel", "Lv.0", Rect2(140, 67, 150, 34), 23, MUTED)
	label(training, "Description", "提升主角的基礎攻擊力。", Rect2(140, 104, 443, 34), 21, MUTED)
	label(training, "CurrentValue", "目前攻擊：—", Rect2(354, 22, 270, 36), 21, INK)
	label(training, "NextCost", "下一級費用：—", Rect2(354, 65, 270, 36), 21, MUTED)
	button(training, "TrainButton", "立即提升", Rect2(665, 51, 195, 82), "train:0", "blue", 23)
	save_scene(training, "res://scenes/components/training_row.tscn")

	var stage := base("StageCard", 164, 203)
	panel(stage, "Frame", Rect2(0, 0, 164, 203), "card")
	image(stage, "Icon", atlas("stage_0", "adventure", Rect2(68, 1134, 130, 99)), Rect2(12, 13, 140, 115))
	label(stage, "Title", "目前進度", Rect2(8, 130, 148, 37), 25, INK, true, true)
	label(stage, "Status", "開放", Rect2(8, 165, 148, 28), 19, MUTED, true)
	button(stage, "SelectButton", "", Rect2(0, 0, 164, 203), "stage:0", "transparent", 18)
	stage.get_node("SelectButton").add_theme_stylebox_override("hover", _flat(Color(0.2, 0.26, 0.34, 0.12), Color("e9bd5d"), 3))
	save_scene(stage, "res://scenes/components/stage_card.tscn")

	var product := base("ProductCard", 215, 416)
	panel(product, "Frame", Rect2(0, 0, 215, 416), "card")
	label(product, "Title", "金幣袋", Rect2(7, 8, 201, 42), 27, INK, true, true)
	image(product, "Icon", atlas("product_0", "store", Rect2(48, 930, 175, 136)), Rect2(25, 59, 165, 139))
	label(product, "Quantity", "× 10,000", Rect2(6, 199, 203, 42), 24, INK, true, true)
	label(product, "Description", "供強化與冒險使用。", Rect2(10, 245, 195, 77), 20, MUTED, true)
	button(product, "BuyButton", "查看商品", Rect2(13, 334, 189, 65), "buy:0", "green", 22)
	save_scene(product, "res://scenes/components/product_card.tscn")

func _make_header() -> void:
	var root := base("Header", 941, 100)
	var background := panel(root, "Backdrop", Rect2(0, 0, 941, 100), "blue")
	background.add_theme_stylebox_override("panel", _flat(Color("2a354d"), Color("2a354d"), 0))
	var avatar := button(root, "AvatarButton", "", Rect2(13, 6, 83, 88), "page:overview", "card", 18)
	image(avatar, "Portrait", atlas("portrait", "idel", Rect2(19, 10, 97, 90)), Rect2(0, 0, 83, 88))
	label(root, "LevelLabel", "Lv. 1", Rect2(111, 13, 246, 38), 27, Color.WHITE, false, true)
	bar(root, "ExperienceBar", Rect2(111, 57, 258, 19), 0)
	panel(root, "GoldFrame", Rect2(411, 19, 204, 62), "blue")
	image(root, "GoldIcon", atlas("coin", "idel", Rect2(500, 29, 45, 45)), Rect2(421, 26, 42, 44))
	label(root, "GoldBadge", "500", Rect2(466, 24, 138, 49), 25, Color("ffe19a"), true, true)
	panel(root, "GemFrame", Rect2(627, 19, 162, 62), "blue")
	image(root, "GemIcon", atlas("gem", "idel", Rect2(704, 27, 44, 49)), Rect2(638, 24, 39, 47))
	label(root, "GemBadge", "320", Rect2(681, 23, 98, 50), 25, Color("9bd9fb"), true, true)
	var settings := button(root, "SettingsButton", "", Rect2(837, 12, 84, 76), "settings", "nav", 18)
	image(settings, "Gear", atlas("gear", "idel", Rect2(865, 27, 50, 48)), Rect2(15, 13, 52, 50))
	save_scene(root, "res://scenes/components/header.tscn")

func _make_navigation() -> void:
	var root := base("Navigation", 941, 122)
	var group := ButtonGroup.new()
	for i in NAV_IDS.size():
		var x := 12 + i * 153
		var nav_kind := "nav"
		var nav_button := button(root, "%sButton" % NAV_IDS[i].capitalize(), "", Rect2(x, 0, 143, 119), "page:" + NAV_IDS[i], nav_kind, 20)
		nav_button.button_group = group
		nav_button.toggle_mode = true
		nav_button.add_theme_stylebox_override("normal", styles["nav"])
		nav_button.add_theme_stylebox_override("hover", styles["nav_active"])
		nav_button.add_theme_stylebox_override("pressed", styles["nav_active"])
		var nav_icon := image(nav_button, "Icon", atlas("nav_%d" % i, "equipment", [
			Rect2(44, 1546, 83, 70), Rect2(196, 1545, 83, 70), Rect2(347, 1545, 88, 70),
			Rect2(510, 1546, 98, 70), Rect2(661, 1542, 90, 70), Rect2(816, 1545, 88, 70)
		][i]), Rect2(38, 4, 67, 69))
		nav_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label(nav_button, "Caption", NAV_LABELS[i], Rect2(0, 75, 143, 38), 23, Color.WHITE, true, true)
	save_scene(root, "res://scenes/components/navigation.tscn")

func _scenery(page: Control) -> void:
	image(page, "DistantLandscape", atlas("battle_sky", "equipment", Rect2(0, 100, 941, 248)), Rect2(0, 100, 941, 260))
	image(page, "LowerLandscape0", atlas("battle_tree_strip", "equipment", Rect2(0, 360, 56, 110)), Rect2(0, 360, 56, 110))
	var ranges: Array[Vector2i] = [Vector2i(56, 420), Vector2i(420, 560), Vector2i(560, 941)]
	var patch_index := 0
	for segment_index in ranges.size():
		var x := ranges[segment_index].x
		var end_x := ranges[segment_index].y
		while x < end_x:
			var width := mini(140, end_x - x)
			var node_name := "LowerLandscape%d" % (segment_index + 1) if segment_index == 1 else "LowerPatch%d_%d" % [segment_index, patch_index]
			var lower := atlas("battle_lower_%d" % patch_index, "equipment", Rect2(420, 360, width, 110))
			image(page, node_name, lower, Rect2(x, 360, width, 110))
			x += width
			patch_index += 1
	image(page, "Ground", atlas("battle_ground", "equipment", Rect2(0, 470, 941, 55)), Rect2(0, 470, 941, 55))
	var socket := Node2D.new()
	socket.name = "BattleSocket"
	socket.position = Vector2(0, 470)
	page.add_child(socket)
	socket.owner = _root_of(page)

func _page_panel(page: Control, top: int) -> void:
	panel(page, "ContentPanel", Rect2(8, top, 925, 1520 - top), "paper_frame")

func _title(page: Control, text: String, icon_id: String = "") -> void:
	if not icon_id.is_empty():
		var icon_texture: Texture2D = textures.get(icon_id) as Texture2D
		image(page, "PageIcon", icon_texture, Rect2(28, 541, 66, 61))
	label(page, "PageTitle", text, Rect2(104 if not icon_id.is_empty() else 31, 538, 475, 66), 42, INK, false, true)

func _make_page(id: String) -> void:
	var page := base(id.capitalize())
	page.set_meta("page_id", id)
	_scenery(page)
	_page_panel(page, 950 if id == "overview" else 525)
	match id:
		"overview": _overview(page)
		"train": _train(page)
		"backpack": _backpack(page)
		"monster": _monster(page)
		"equipment": _equipment(page)
		"adventure": _adventure(page)
		"store": _store(page)
	var nav := component(page, "res://scenes/components/navigation.tscn", "Navigation")
	rect(nav, 0, 1536, 941, 122)
	save_scene(page, "res://scenes/pages/%s.tscn" % id)

func _overview(page: Control) -> void:
	_title(page, "戰鬥總覽")
	label(page, "OverviewHint", "遠征進行中", Rect2(34, 1021, 873, 42), 25, MUTED, false, true)
	panel(page, "HeroSummaryFrame", Rect2(27, 1070, 886, 145), "card")
	image(page, "HeroSummaryPortrait", atlas("portrait", "idel", Rect2(19, 10, 97, 90)), Rect2(44, 1083, 95, 105))
	label(page, "HeroSummaryName", "主角與遠征夥伴", Rect2(157, 1084, 400, 44), 28, INK, false, true)
	label(page, "SessionTotals", "擊倒 0 隻　·　金幣 0", Rect2(157, 1134, 715, 43), 23, MUTED)
	panel(page, "LogFrame", Rect2(27, 1233, 886, 253), "card")
	label(page, "LogTitle", "戰鬥紀錄", Rect2(46, 1241, 838, 42), 27, INK, false, true)
	var log_scroll := ScrollContainer.new()
	log_scroll.name = "CombatLogScroll"
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	attach(page, log_scroll, "CombatLogScroll")
	rect(log_scroll, 44, 1288, 845, 182)
	var log := label(log_scroll, "CombatLog", "自動戰鬥已就緒。切換分頁時，戰場狀態會持續保留。", Rect2(0, 0, 810, 150), 22, MUTED)
	log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _train(page: Control) -> void:
	_title(page, "主角訓練", "title_train")
	label(page, "TrainingSubtitle", "即時提升主角屬性；每次點擊購買一級。", Rect2(33, 602, 864, 36), 22, MUTED)
	var rows := VBoxContainer.new()
	rows.name = "TrainingList"
	rows.add_theme_constant_override("separation", 11)
	attach(page, rows, "TrainingList")
	rect(rows, 26, 650, 889, 820)
	var titles: Array[String] = ["劍術", "耐力", "速度", "休息"]
	var descriptions: Array[String] = ["提升主角的基礎攻擊力。", "提升主角的基礎生命值。", "提升主角的基礎移動速度。", "提升主角的生命回復。"]
	for i in 4:
		var row := component(rows, "res://scenes/components/training_row.tscn", "TrainingRow%d" % i)
		row.custom_minimum_size = Vector2(889, 190)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.get_node("Icon").texture = textures["training_%d" % i]
		row.get_node("Title").text = titles[i]
		row.get_node("Description").text = descriptions[i]
		row.get_node("TrainButton").set_meta("action", "train:%d" % i)

func _filter_button(parent: Node, id: String, text: String, action: String, group: ButtonGroup, active: bool = false, width: int = 162) -> Button:
	var control := button(parent, id, text, Rect2(0, 0, width, 54), action, "blue" if active else "card", 21)
	control.toggle_mode = true
	control.button_group = group
	control.button_pressed = active
	control.custom_minimum_size = Vector2(width, 54)
	if not active:
		control.add_theme_color_override("font_color", INK)
	return control

func _make_grid_scroll(parent: Node, id: String, bounds: Rect2, columns: int, child_size: Vector2) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.name = id + "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	attach(parent, scroll, id + "Scroll")
	rect(scroll, bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)
	var grid := GridContainer.new()
	grid.name = id
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.custom_minimum_size = Vector2(0, 0)
	attach(scroll, grid, id)
	return grid

func _backpack(page: Control) -> void:
	_title(page, "冒險背包", "title_backpack")
	label(page, "BackpackSubtitle", "裝備會依所選分類排列；點選物品可檢視資訊。", Rect2(33, 601, 868, 36), 21, MUTED)
	var filters := HBoxContainer.new()
	filters.name = "FilterRow"
	filters.add_theme_constant_override("separation", 7)
	attach(page, filters, "FilterRow")
	rect(filters, 28, 647, 885, 59)
	var group := ButtonGroup.new()
	var filter_keys: Array[String] = ["all", "weapon", "armor", "accessory", "other"]
	var filter_labels: Array[String] = ["全部", "武器", "防具", "飾品", "其他"]
	for i in filter_keys.size():
		var tab := _filter_button(filters, "Filter" + filter_keys[i].capitalize(), filter_labels[i], "filter:" + filter_keys[i], group, i == 0, 170)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel(page, "InventoryFrame", Rect2(21, 720, 899, 773), "card")
	_make_grid_scroll(page, "ItemsGrid", Rect2(35, 736, 870, 735), 5, Vector2(164, 145))
	var empty := label(page, "EmptyState", "背包中沒有符合條件的裝備。", Rect2(111, 989, 719, 62), 27, MUTED, true)
	empty.visible = true

func _make_stat_labels(parent: Node, prefix: String, x: int, y: int, width: int, spacing: int, size: int) -> void:
	for i in STAT_KEYS.size():
		var row_y := y + i * spacing
		label(parent, prefix + STAT_KEYS[i].capitalize(), "%s　—" % STAT_LABELS[i], Rect2(x, row_y, width, spacing), size, INK)

func _monster(page: Control) -> void:
	_title(page, "怪獸圖鑑", "title_monster")
	label(page, "DetailHint", "查看怪獸與隊伍狀態；部署操作獨立於圖鑑選取。", Rect2(33, 601, 872, 36), 21, MUTED)
	panel(page, "DetailPanel", Rect2(22, 646, 897, 289), "card")
	panel(page, "PortraitFrame", Rect2(39, 660, 205, 260), "slot")
	image(page, "DetailPortrait", atlas("pet_detail", "monster", Rect2(50, 674, 269, 243)), Rect2(48, 666, 187, 244))
	label(page, "PetName", "怪獸名稱", Rect2(272, 659, 340, 46), 32, INK, false, true)
	label(page, "PetLevel", "Lv.1", Rect2(272, 707, 142, 36), 22, INK)
	bar(page, "PetExperience", Rect2(417, 717, 280, 18), 0)
	label(page, "PetExperienceText", "0 / 0", Rect2(710, 703, 187, 35), 21, MUTED, true)
	label(page, "PetDeploymentStatus", "未部署", Rect2(272, 746, 605, 32), 20, MUTED)
	_make_stat_labels(page, "PetStat", 272, 784, 292, 40, 22)
	_make_stat_labels(page, "PetBonus", 571, 784, 316, 40, 21)
	panel(page, "CollectionPanel", Rect2(22, 950, 897, 548), "card")
	label(page, "CollectionTitle", "我的怪獸", Rect2(39, 960, 476, 45), 29, INK, false, true)
	label(page, "CollectionCount", "已部署 0 隻", Rect2(577, 960, 319, 45), 23, MUTED, false, true)
	label(page, "CollectionSubTitle", "點「查看」切換詳情；以「部署／撤下」獨立管理同行名單。", Rect2(39, 1003, 858, 35), 19, MUTED)
	var grid := GridContainer.new()
	grid.name = "MonsterGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 8)
	attach(page, grid, "MonsterGrid")
	rect(grid, 32, 1047, 876, 437)
	for i in 4:
		var card := component(grid, "res://scenes/components/monster_card.tscn", "MonsterCard%d" % i)
		card.custom_minimum_size = Vector2(211, 430)
		card.get_node("Icon").texture = textures["monster_%d" % i]
		card.get_node("InspectButton").set_meta("action", "monster:%d" % i)
		card.get_node("DeploymentButton").set_meta("action", "deploy:%d" % i)

func _equipment(page: Control) -> void:
	label(page, "EquipmentTitle", "裝備管理", Rect2(29, 537, 320, 53), 39, INK, false, true)
	var tabs := ButtonGroup.new()
	var manage := button(page, "ManagementTab", "裝備管理", Rect2(551, 538, 176, 51), "equipment_tab:manage", "blue", 21)
	manage.button_group = tabs
	manage.toggle_mode = true
	manage.button_pressed = true
	var upgrade := button(page, "UpgradeTab", "裝備強化", Rect2(737, 538, 176, 51), "equipment_tab:upgrade", "card", 21)
	upgrade.button_group = tabs
	upgrade.toggle_mode = true
	panel(page, "HeroEquipmentPanel", Rect2(18, 622, 905, 318), "card")
	label(page, "HeroSectionTitle", "主角裝備", Rect2(34, 624, 165, 39), 26, INK, false, true)
	var hero_target := button(page, "UseHeroButton", "裝備給主角", Rect2(203, 621, 170, 41), "equipment_owner:hero", "blue", 18)
	hero_target.toggle_mode = true
	image(page, "HeroPortrait", atlas("hero_fullbody", "equipment", Rect2(45, 686, 183, 239)), Rect2(40, 665, 160, 209))
	label(page, "HeroLevel", "Lv.1", Rect2(36, 881, 170, 36), 20, MUTED, true)
	var hero_slots := GridContainer.new()
	hero_slots.name = "HeroSlotGrid"
	hero_slots.columns = 3
	hero_slots.add_theme_constant_override("h_separation", 5)
	hero_slots.add_theme_constant_override("v_separation", 6)
	attach(page, hero_slots, "HeroSlotGrid")
	rect(hero_slots, 218, 663, 366, 258)
	var hero_slot_icons: Array[int] = [0, 3, 4, 5, 6, 7]
	for i in SLOT_KEYS.size():
		var slot := button(hero_slots, "HeroSlot%d" % i, "", Rect2(0, 0, 118, 122), "equipment_slot:hero:" + SLOT_KEYS[i], "slot", 16)
		slot.custom_minimum_size = Vector2(118, 122)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_icon := image(slot, "Icon", textures["equipment_item_%d" % hero_slot_icons[i]], Rect2(39, 7, 40, 39))
		slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label(slot, "SlotLabel", SLOT_LABELS[i], Rect2(2, 49, 114, 30), 16, INK, true, true)
		label(slot, "LevelLabel", "未裝備", Rect2(2, 82, 114, 27), 14, MUTED, true)
	panel(page, "HeroStatsPanel", Rect2(599, 645, 307, 281), "slot")
	label(page, "HeroStatsHeading", "主角屬性　基礎 + 裝備", Rect2(610, 650, 284, 35), 18, MUTED, false, true)
	_make_stat_labels(page, "HeroStat", 612, 690, 279, 38, 19)

	panel(page, "MonsterEquipmentPanel", Rect2(18, 950, 905, 290), "card")
	label(page, "MonsterSectionTitle", "怪獸裝備", Rect2(34, 954, 154, 42), 26, INK, false, true)
	var monster_target := button(page, "UseMonsterButton", "裝備給此怪獸", Rect2(186, 958, 168, 40), "equipment_owner:selected_monster", "blue", 17)
	monster_target.toggle_mode = true
	var selector_group := ButtonGroup.new()
	for i in 4:
		var select := button(page, "EquipmentMonster%d" % i, "怪獸 %d" % (i + 1), Rect2(363 + i * 136, 958, 131, 40), "equipment_monster:%d" % i, "card", 17)
		select.button_group = selector_group
		select.toggle_mode = true
		select.button_pressed = i == 0
		select.add_theme_color_override("font_color", INK)
	image(page, "EquipmentMonsterPortrait", atlas("monster_0", "monster", Rect2(62, 1297, 176, 119)), Rect2(36, 1005, 164, 170))
	label(page, "EquipmentMonsterLevel", "Lv.1", Rect2(37, 1175, 162, 34), 20, MUTED, true)
	var monster_slots := GridContainer.new()
	monster_slots.name = "MonsterSlotGrid"
	monster_slots.columns = 3
	monster_slots.add_theme_constant_override("h_separation", 5)
	monster_slots.add_theme_constant_override("v_separation", 6)
	attach(page, monster_slots, "MonsterSlotGrid")
	rect(monster_slots, 207, 1004, 378, 220)
	var monster_slot_icons: Array[int] = [8, 9, 10, 11, 12, 14]
	for i in MONSTER_SLOT_KEYS.size():
		var slot := button(monster_slots, "MonsterSlot%d" % i, "", Rect2(0, 0, 122, 106), "equipment_slot:selected_monster:" + MONSTER_SLOT_KEYS[i], "slot", 16)
		slot.custom_minimum_size = Vector2(122, 106)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_icon := image(slot, "Icon", textures["equipment_item_%d" % monster_slot_icons[i]], Rect2(41, 4, 40, 37))
		slot_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		label(slot, "SlotLabel", MONSTER_SLOT_LABELS[i], Rect2(2, 43, 118, 28), 15, INK, true, true)
		label(slot, "LevelLabel", "未裝備", Rect2(2, 73, 118, 24), 13, MUTED, true)
	panel(page, "MonsterStatsPanel", Rect2(599, 1000, 307, 226), "slot")
	label(page, "MonsterStatsHeading", "怪獸屬性　基礎 + 裝備", Rect2(610, 1002, 284, 34), 18, MUTED, false, true)
	_make_stat_labels(page, "EquipmentMonsterStat", 612, 1036, 279, 31, 18)

	panel(page, "EquipmentInventoryPanel", Rect2(20, 1250, 900, 270), "card")
	label(page, "InventoryTitle", "裝備背包", Rect2(34, 1252, 159, 42), 25, INK, false, true)
	var filter_row := HBoxContainer.new()
	filter_row.name = "EquipmentFilterRow"
	filter_row.add_theme_constant_override("separation", 4)
	attach(page, filter_row, "EquipmentFilterRow")
	rect(filter_row, 194, 1255, 711, 39)
	var filters := ButtonGroup.new()
	var categories: Array[String] = ["all", "weapon", "armor", "accessory", "other"]
	var captions: Array[String] = ["全部", "武器", "防具", "飾品", "其他"]
	for i in categories.size():
		var control := _filter_button(filter_row, "EquipmentFilter" + categories[i].capitalize(), captions[i], "equipment_filter:" + categories[i], filters, i == 0, 138)
		control.custom_minimum_size = Vector2(138, 39)
		control.add_theme_font_size_override("font_size", 17)
	panel(page, "EquipmentGridFrame", Rect2(31, 1300, 878, 158), "slot")
	var equipment_scroll := _make_grid_scroll(page, "EquipmentItemsGrid", Rect2(37, 1303, 866, 151), 7, Vector2(118, 70))
	equipment_scroll.add_theme_constant_override("h_separation", 4)
	equipment_scroll.add_theme_constant_override("v_separation", 4)
	label(page, "EquipmentEmptyState", "目前沒有相容的裝備。", Rect2(260, 1347, 410, 50), 23, MUTED, true)
	label(page, "ManagementHint", "點選裝備即可穿戴；點選已裝備欄位可選取卸下。", Rect2(38, 1461, 637, 39), 17, MUTED)
	label(page, "SelectedItemInfo", "尚未選取裝備", Rect2(38, 1461, 286, 39), 18, INK, false, true)
	label(page, "SelectedItemCost", "強化費用：—", Rect2(328, 1461, 324, 39), 17, MUTED)
	button(page, "UnequipButton", "卸下欄位", Rect2(690, 1460, 212, 41), "unequip", "card", 17)
	button(page, "UpgradeButton", "強化選取裝備", Rect2(690, 1460, 212, 41), "upgrade", "green", 17)
	page.get_node("SelectedItemInfo").visible = false
	page.get_node("SelectedItemCost").visible = false
	page.get_node("UnequipButton").visible = false
	page.get_node("UpgradeButton").visible = false

func _adventure(page: Control) -> void:
	_title(page, "冒險旅程", "title_adventure")
	button(page, "ChapterButton", "目前遠征章節　⌄", Rect2(556, 541, 355, 54), "chapter", "card", 21)
	panel(page, "ChapterPanel", Rect2(25, 615, 890, 174), "card")
	image(page, "ChapterLandscape", atlas("chapter_scenery", "adventure", Rect2(421, 900, 482, 188)), Rect2(493, 625, 405, 151))
	label(page, "ChapterTitle", "綠風平原", Rect2(46, 634, 430, 49), 31, INK, false, true)
	label(page, "ChapterDescription", "微風吹過的遠征起點。\n擊敗敵人以獲得金幣與怪獸經驗。", Rect2(48, 685, 445, 87), 21, MUTED)
	label(page, "RouteTitle", "關卡路線", Rect2(37, 803, 836, 45), 28, INK, false, true)
	var stages := GridContainer.new()
	stages.name = "StageGrid"
	stages.columns = 4
	stages.add_theme_constant_override("h_separation", 42)
	attach(page, stages, "StageGrid")
	rect(stages, 38, 850, 863, 210)
	for i in 4:
		var stage := component(stages, "res://scenes/components/stage_card.tscn", "StageCard%d" % i)
		stage.custom_minimum_size = Vector2(164, 203)
		stage.get_node("Icon").texture = textures["stage_%d" % i]
		stage.get_node("Title").text = "目前進度" if i == 0 else "接續路線"
		stage.get_node("Status").text = "遠征中" if i == 0 else "持續推進"
		stage.get_node("SelectButton").set_meta("action", "stage:%d" % i)
		if i > 0:
			stage.get_node("SelectButton").disabled = true
			stage.get_node("Icon").modulate = Color(0.56, 0.58, 0.62, 0.82)
	panel(page, "RewardsPanel", Rect2(30, 1082, 878, 149), "slot")
	label(page, "RewardsTitle", "可能獲得", Rect2(48, 1087, 206, 37), 22, MUTED, false, true)
	for i in 4:
		image(page, "RewardIcon%d" % i, textures["reward_%d" % i], Rect2(48 + i * 96, 1125, 75, 79))
	label(page, "LaunchNote", "戰鬥會沿用目前關卡進度，並持續向前推進。", Rect2(442, 1088, 438, 39), 20, MUTED)
	button(page, "DepartButton", "繼續遠征", Rect2(507, 1265, 365, 99), "depart", "gold", 31)
	label(page, "DepartHint", "自動戰鬥會在總覽及其他頁面持續。", Rect2(459, 1372, 465, 47), 19, MUTED, true)

func _store(page: Control) -> void:
	_title(page, "遠征商店", "title_store")
	label(page, "StoreSubtitle", "商品按鈕顯示本機商店資訊，不會進行付款或發放。", Rect2(33, 601, 872, 36), 20, MUTED)
	var products := HBoxContainer.new()
	products.name = "ProductGrid"
	products.add_theme_constant_override("separation", 8)
	attach(page, products, "ProductGrid")
	rect(products, 23, 650, 895, 430)
	var product_names: Array[String] = ["金幣袋", "寶石", "怪獸糧食", "回復藥水"]
	var product_amounts: Array[String] = ["× 10,000", "× 320", "× 10", "× 5"]
	var product_desc: Array[String] = ["強化與遠征用途。", "商店便利貨幣。", "怪獸成長素材。", "恢復全隊生命。"]
	for i in 4:
		var card := component(products, "res://scenes/components/product_card.tscn", "ProductCard%d" % i)
		card.custom_minimum_size = Vector2(215, 416)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.get_node("Title").text = product_names[i]
		card.get_node("Icon").texture = textures["product_%d" % i]
		card.get_node("Quantity").text = product_amounts[i]
		card.get_node("Description").text = product_desc[i]
		card.get_node("BuyButton").text = "查看商品"
		card.get_node("BuyButton").set_meta("action", "buy:%d" % i)
	panel(page, "GiftPanel", Rect2(26, 1115, 889, 351), "card")
	image(page, "GiftArt", textures["gift"], Rect2(45, 1132, 302, 212))
	label(page, "GiftTitle", "每日免費禮物", Rect2(372, 1144, 458, 51), 30, INK, false, true)
	label(page, "GiftDescription", "觀看獎勵廣告的外觀保留作為商店示範。\n此原型沒有廣告 SDK，也不會記錄領取狀態。", Rect2(372, 1200, 477, 93), 20, MUTED)
	button(page, "GiftButton", "查看免費禮物", Rect2(600, 1321, 271, 88), "gift", "blue", 23)

func _make_main() -> void:
	var root := base("TaskbarHero")
	root.set_script(load("res://scripts/main.gd"))
	var background := panel(root, "CanvasBackground", Rect2(0, 0, 941, 1672), "blue")
	background.add_theme_stylebox_override("panel", _flat(NAVY, NAVY, 0))
	var pages := base("Pages")
	attach(root, pages, "Pages")
	rect(pages, 0, 0, 941, 1672)
	for page_id in PAGE_IDS:
		var page := component(pages, "res://scenes/pages/%s.tscn" % page_id, page_id.capitalize())
		rect(page, 0, 0, 941, 1672)
		page.visible = page_id == "overview"
	var arena_scene := load("res://scenes/combat/reference_arena.tscn") as PackedScene
	assert(arena_scene != null, "Root-owned reference_arena.tscn must exist before UI authoring")
	var arena := arena_scene.instantiate() as Node2D
	attach(pages.get_node("Overview/BattleSocket"), arena, "CombatArena")
	arena.unique_name_in_owner = true
	arena.position = Vector2.ZERO
	var header := component(root, "res://scenes/components/header.tscn", "Header")
	rect(header, 0, 0, 941, 100)
	var dimmer := ColorRect.new()
	dimmer.name = "SettingsDimmer"
	dimmer.color = Color(0.025, 0.04, 0.065, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.visible = false
	attach(root, dimmer, "SettingsDimmer")
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var settings := panel(root, "SettingsPanel", Rect2(156, 382, 629, 696), "paper_frame")
	settings.mouse_filter = Control.MOUSE_FILTER_STOP
	settings.visible = false
	label(settings, "Title", "遠征設定", Rect2(48, 34, 533, 65), 42, INK, true, true)
	label(settings, "SaveNotice", "", Rect2(53, 112, 523, 73), 20, MUTED, true)
	settings.get_node("SaveNotice").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(settings, "PauseButton", "暫停戰鬥", Rect2(58, 209, 513, 74), "pause", "blue", 26)
	button(settings, "SaveButton", "儲存進度", Rect2(58, 300, 513, 74), "save", "blue", 26)
	button(settings, "HomeButton", "返回總覽", Rect2(58, 391, 513, 74), "page:overview", "card", 26)
	settings.get_node("HomeButton").add_theme_color_override("font_color", INK)
	button(settings, "CloseButton", "關閉", Rect2(58, 482, 513, 74), "settings", "card", 26)
	settings.get_node("CloseButton").add_theme_color_override("font_color", INK)
	label(settings, "DemoNotice", "資料會寫入本機存檔。", Rect2(48, 590, 533, 42), 20, MUTED, true)
	var message := panel(root, "MessagePanel", Rect2(80, 115, 781, 112), "blue")
	message.visible = false
	label(message, "MessageText", "", Rect2(24, 9, 733, 94), 23, Color.WHITE, true)
	message.get_node("MessageText").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_scene(root, "res://main.tscn")
