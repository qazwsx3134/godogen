extends SceneTree
## Authoring tool for the fused home screen (docs/FUSION.md), on Taskbar Hero's seven pages (copied from
## prototypes/taskbar-hero/scenes/pages with their components, atlas regions, fonts and theme). Applied 2026-10-27.
## It opens each copied page, retitles it, hides what this game has no use for, adds the rows, grids and buttons it
## needs, marks the nodes the page script reads as unique names, attaches the script and saves it back; then it
## builds scenes/march_unit.tscn's hero sprite, scenes/march_arena.tscn and scenes/home.tscn. A page that already has
## its script is skipped (it was applied and may since be edited by hand); home.tscn and march_arena.tscn are only
## written when missing.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_fusion_ui.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PAGE := "res://scenes/pages/%s.tscn"
const UNIT := "res://scenes/march_unit.tscn"
const ARENA := "res://scenes/march_arena.tscn"
const HOME := "res://scenes/home.tscn"
const HEADER := "res://scenes/components/header.tscn"
const NAV := "res://scenes/components/navigation.tscn"
const TRAINING_ROW := "res://scenes/components/training_row.tscn"
const BAG_CARD := "res://scenes/components/equipment_bag_card.tscn"
const THEME := "res://ui/reference_theme.tres"
const SETTINGS := "res://scenes/settings_panel.tscn"
const BOLD := "res://fonts/NotoSansCJKtc-Bold.otf"
const PAGES := [["overview", "Overview"], ["train", "Train"], ["backpack", "Backpack"], ["heroes", "Heroes"],
	["equipment", "Equipment"], ["adventure", "Adventure"], ["store", "Store"]]
const INK := Color("4a3424")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _unit()
	if not FileAccess.file_exists(PAGE % "heroes"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PAGE % "monster"), ProjectSettings.globalize_path(PAGE % "heroes"))
	for spec: Array in PAGES:
		ok = _page(spec[0]) and ok
	ok = _arena() and ok
	ok = _home() and ok
	quit(0 if ok else 1)


# --- helpers ----------------------------------------------------------------------------------------------------

func _u(root: Node, path: String) -> Node:
	var n: Node = root.get_node(path)
	n.unique_name_in_owner = true
	return n


func _place(c: Control, pos: Vector2, size: Vector2) -> void:
	c.position = pos
	c.size = size


func _hide(root: Node, paths: Array) -> void:
	for p: String in paths:
		var n: CanvasItem = root.get_node_or_null(p)
		if n != null:
			n.visible = false


## A copy of an existing node of the page (its fonts and colours come along), placed and named.
func _copy(root: Node, from: String, name: String, pos: Vector2, size: Vector2, text: String = "") -> Control:
	var c: Control = root.get_node(from).duplicate()
	c.name = name
	root.add_child(c)
	_place(c, pos, size)
	if text != "" and "text" in c:
		c.text = text
	c.unique_name_in_owner = true
	return c


## A button in the reference style: `style` is blue, green or gold (ui/<style>.tres), white bold text.
func _button(text: String, style: String, font_size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	var box: StyleBox = load("res://ui/%s.tres" % style)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_font_override(&"font", load(BOLD))
	b.add_theme_font_size_override(&"font_size", font_size)
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color("fff6d8"))
	b.add_theme_color_override(&"font_disabled_color", Color(1, 1, 1, 0.45))
	return b


func _scroll(root: Node, name: String, pos: Vector2, size: Vector2) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.name = name
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(s)
	_place(s, pos, size)
	s.unique_name_in_owner = true
	return s


func _into(child: Control, parent: Control) -> void:
	child.get_parent().remove_child(child)
	child.owner = null
	parent.add_child(child)
	child.position = Vector2.ZERO
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _page(key: String) -> bool:
	var path: String = PAGE % key
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_script() != null:
		root.free()
		print("skip %s: already applied" % path)
		return true
	var nav: Node = root.get_node_or_null("Navigation")
	if nav != null:
		root.remove_child(nav)
		nav.free()
	_u(root, "BattleSocket")
	var refs: Array = opened.refs.filter(func(r: String) -> bool: return r != NAV and r != "res://scenes/components/monster_card.tscn")
	match key:
		"overview": _overview(root)
		"train": refs.append(TRAINING_ROW); _train(root)
		"backpack": _backpack(root)
		"heroes": _heroes(root)
		"equipment": _equipment(root)
		"adventure": _adventure(root)
		"store": _store(root)
	root.set_script(load("res://scripts/pages/%s_page.gd" % key))
	if key == "overview":
		refs.append(BAG_CARD)
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": refs}).ok


# --- pages ------------------------------------------------------------------------------------------------------

func _overview(root: Control) -> void:
	_place(root.get_node("ContentPanel"), Vector2(8, 525), Vector2(925, 995))
	(root.get_node("PageTitle") as Label).text = "遠征總覽"
	var status: Label = _u(root, "OverviewHint")
	status.name = "MarchStatus"
	_place(status, Vector2(34, 601), Vector2(873, 42))
	_place(root.get_node("HeroSummaryFrame"), Vector2(27, 650), Vector2(886, 300))
	var portrait: TextureRect = _u(root, "HeroSummaryPortrait")
	portrait.name = "LeaderPortrait"
	_place(portrait, Vector2(44, 664), Vector2(120, 120))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var leader: Label = _u(root, "HeroSummaryName")
	leader.name = "LeaderName"
	_place(leader, Vector2(180, 664), Vector2(715, 44))
	var line: Label = _u(root, "SessionTotals")
	line.name = "SquadLine"
	_place(line, Vector2(180, 714), Vector2(715, 70))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.name = "SquadRow"
	row.add_theme_constant_override(&"separation", 14)
	root.add_child(row)
	_place(row, Vector2(44, 796), Vector2(855, 76))
	row.unique_name_in_owner = true
	for k: int in 5:
		SceneBuilder.add(row, SceneBuilder.instance(BAG_CARD), "SquadCard%d" % k)
	_copy(root, "SquadLine", "BondLabel", Vector2(44, 884), Vector2(855, 60))
	_copy(root, "HeroSummaryFrame", "TodoFrame", Vector2(27, 962), Vector2(886, 252)).unique_name_in_owner = false
	_copy(root, "LogTitle", "TodoTitle", Vector2(46, 968), Vector2(838, 42), "可以做的事").unique_name_in_owner = false
	var todo := VBoxContainer.new()
	todo.name = "TodoList"
	todo.add_theme_constant_override(&"separation", 8)
	root.add_child(todo)
	_place(todo, Vector2(44, 1014), Vector2(852, 192))
	todo.unique_name_in_owner = true
	for k: int in 4:
		var b: Button = _button("", "blue", 23)
		b.name = "Todo%d" % k
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		todo.add_child(b)
	_place(root.get_node("LogFrame"), Vector2(27, 1226), Vector2(886, 280))
	_place(root.get_node("LogTitle"), Vector2(46, 1234), Vector2(838, 42))
	_place(_u(root, "CombatLogScroll"), Vector2(44, 1280), Vector2(845, 214))
	var log: Label = _u(root, "CombatLogScroll/CombatLog")
	log.text = "小隊出發了。"


func _train(root: Control) -> void:
	(root.get_node("PageTitle") as Label).text = "全軍訓練"
	(_u(root, "TrainingSubtitle") as Label).text = "花金幣訓練全軍，立即生效；劍術與耐力是戰力的主要來源。"
	var list: VBoxContainer = _u(root, "TrainingList")
	var scroll: ScrollContainer = _scroll(root, "TrainingScroll", Vector2(26, 650), Vector2(889, 856))
	_into(list, scroll)
	for k: int in range(list.get_child_count(), 6):
		SceneBuilder.add(list, SceneBuilder.instance(TRAINING_ROW), "TrainingRow%d" % k)


func _backpack(root: Control) -> void:
	(root.get_node("PageTitle") as Label).text = "背包"
	(_u(root, "BackpackSubtitle") as Label).text = "裝備、遺物與素材。點選物品看詳情，不要的可以分解成強化石。"
	var filters: HBoxContainer = _u(root, "FilterRow")
	var names: Array = ["全部", "武器", "飾品", "遺物", "素材"]
	for k: int in filters.get_child_count():
		(filters.get_child(k) as Button).text = names[k]
	_place(root.get_node("InventoryFrame"), Vector2(21, 720), Vector2(899, 592))
	_place(root.get_node("ItemsGridScroll"), Vector2(35, 736), Vector2(870, 562))
	(_u(root, "ItemsGridScroll/ItemsGrid") as GridContainer).columns = 5
	var empty: Label = _u(root, "EmptyState")
	empty.text = "這個分類沒有東西。"
	_place(empty, Vector2(111, 990), Vector2(719, 62))
	_copy(root, "InventoryFrame", "InfoFrame", Vector2(21, 1322), Vector2(899, 186)).unique_name_in_owner = false
	_copy(root, "BackpackSubtitle", "InfoName", Vector2(40, 1332), Vector2(600, 44), "點選物品看詳情")
	var info: Label = _copy(root, "BackpackSubtitle", "InfoText", Vector2(40, 1376), Vector2(600, 124), "")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var salvage: Button = _button("分解", "green")
	salvage.name = "SalvageButton"
	root.add_child(salvage)
	_place(salvage, Vector2(660, 1334), Vector2(244, 76))
	salvage.unique_name_in_owner = true
	var auto: Button = _button("自動分解：關", "blue", 23)
	auto.name = "AutoSalvageButton"
	root.add_child(auto)
	_place(auto, Vector2(660, 1418), Vector2(244, 76))
	auto.unique_name_in_owner = true


func _heroes(root: Control) -> void:
	root.name = "Heroes"
	(root.get_node("PageTitle") as Label).text = "英雄名冊"
	(_u(root, "DetailHint") as Label).text = "點名冊裡的英雄看詳情；突破、上陣行軍、設為隊長都在這裡。"
	_u(root, "DetailPortrait")
	for p: String in ["PetName", "PetLevel", "PetExperience", "PetExperienceText"]:
		_u(root, p)
	_u(root, "PetDeploymentStatus").name = "PetStatus"
	var left: Array = ["PetStatAttack", "PetStatDefense", "PetStatHealth"]
	var right: Array = ["PetBonusAttack", "PetBonusDefense", "PetBonusHealth"]
	for k: int in 3:
		var a: Label = _u(root, left[k])
		a.name = "Stat%d" % k
		var b: Label = _u(root, right[k])
		b.name = "Skill%d" % k
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
	_hide(root, ["PetStatSpeed", "PetStatCrit", "PetStatRegen", "PetBonusSpeed", "PetBonusCrit", "PetBonusRegen"])
	var actions := HBoxContainer.new()
	actions.name = "ActionRow"
	actions.add_theme_constant_override(&"separation", 14)
	root.add_child(actions)
	_place(actions, Vector2(30, 944), Vector2(881, 62))
	for spec: Array in [["AscendButton", "突破", "gold"], ["MarchButton", "上陣行軍", "green"], ["CaptainButton", "設為隊長", "blue"]]:
		var b: Button = _button(spec[1], spec[2])
		b.name = spec[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(b)
		b.unique_name_in_owner = true
	_place(root.get_node("CollectionPanel"), Vector2(22, 1016), Vector2(897, 490))
	var title: Label = root.get_node("CollectionTitle")
	title.text = "我的英雄"
	_place(title, Vector2(39, 1022), Vector2(476, 45))
	_place(_u(root, "CollectionCount"), Vector2(500, 1022), Vector2(396, 45))
	var bond: Label = _u(root, "CollectionSubTitle")
	bond.name = "BondLine"
	_place(bond, Vector2(39, 1066), Vector2(858, 35))
	var forms := HBoxContainer.new()
	forms.name = "FormFilter"
	forms.add_theme_constant_override(&"separation", 10)
	root.add_child(forms)
	_place(forms, Vector2(39, 1106), Vector2(860, 48))
	forms.unique_name_in_owner = true
	for name: String in ["全部", "人類", "怪獸", "夢靈"]:
		var b: Button = _button(name, "blue", 22)
		b.name = "Form" + str(forms.get_child_count())
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		forms.add_child(b)
	var grid: GridContainer = root.get_node("MonsterGrid")
	for card: Node in grid.get_children():
		grid.remove_child(card)
		card.free()
	grid.name = "HeroGrid"
	grid.columns = 5
	grid.unique_name_in_owner = true
	var scroll: ScrollContainer = _scroll(root, "HeroScroll", Vector2(32, 1162), Vector2(876, 336))
	_into(grid, scroll)


func _equipment(root: Control) -> void:
	(root.get_node("EquipmentTitle") as Label).text = "裝備"
	_hide(root, ["ManagementTab", "UpgradeTab", "UseMonsterButton", "ManagementHint", "UnequipButton"])
	(root.get_node("HeroSectionTitle") as Label).text = "職業武庫"
	var up: Button = _u(root, "UseHeroButton")
	up.name = "UpgradeArmoryButton"
	up.text = "強化"
	_u(root, "HeroPortrait").name = "ArmoryIcon"
	_u(root, "HeroLevel").name = "ArmoryLevel"
	_u(root, "HeroSlotGrid").name = "ArmoryGrid"
	_u(root, "HeroStatsHeading").name = "ArmoryHeading"
	var stats: Array = ["Attack", "Defense", "Health", "Speed", "Crit", "Regen"]
	for k: int in 6:
		_u(root, "HeroStat" + stats[k]).name = "ArmoryLine%d" % k
		_u(root, "EquipmentMonsterStat" + stats[k]).name = "CharmLine%d" % k
	(root.get_node("MonsterSectionTitle") as Label).text = "專屬飾品"
	for k: int in 4:
		var pick: Button = _u(root, "EquipmentMonster%d" % k)
		pick.name = "SquadPick%d" % k
		_place(pick, Vector2(196 + 141 * k, 958), Vector2(136, 40))
	var fifth: Control = _copy(root, "SquadPick3", "SquadPick4", Vector2(196 + 141 * 4, 958), Vector2(136, 40))
	fifth.unique_name_in_owner = true
	_u(root, "EquipmentMonsterPortrait").name = "CharmHolderPortrait"
	_u(root, "EquipmentMonsterLevel").name = "CharmHolderLevel"
	var slot: Button = _u(root, "MonsterSlotGrid/MonsterSlot0")
	slot.name = "CharmSlot"
	_hide(root, ["MonsterSlotGrid/MonsterSlot1", "MonsterSlotGrid/MonsterSlot2", "MonsterSlotGrid/MonsterSlot3",
		"MonsterSlotGrid/MonsterSlot4", "MonsterSlotGrid/MonsterSlot5"])
	_u(root, "MonsterStatsHeading").name = "CharmHeading"
	var filters: HBoxContainer = _u(root, "EquipmentFilterRow")
	filters.name = "EquipFilter"
	var names: Array = ["全部", "武器", "飾品"]
	for k: int in filters.get_child_count():
		var b: Button = filters.get_child(k)
		b.visible = k < 3
		if k < 3:
			b.text = names[k]
	var grid: GridContainer = _u(root, "EquipmentItemsGridScroll/EquipmentItemsGrid")
	grid.name = "EquipGrid"
	grid.columns = 7
	_u(root, "EquipmentEmptyState").name = "EquipEmpty"
	var info: Label = _u(root, "SelectedItemInfo")
	_place(info, Vector2(38, 1461), Vector2(400, 39))
	_place(_u(root, "SelectedItemCost"), Vector2(442, 1461), Vector2(240, 39))
	var equip: Button = _u(root, "UpgradeButton")
	equip.name = "EquipButton"
	equip.text = "裝備"


func _adventure(root: Control) -> void:
	(root.get_node("PageTitle") as Label).text = "冒險"
	for p: String in ["ChapterButton", "ChapterTitle", "ChapterDescription", "RouteTitle", "StageGrid", "LaunchNote",
			"DepartButton", "DepartHint"]:
		_u(root, p)
	for k: int in 4:
		_u(root, "RewardIcon%d" % k)
	(root.get_node("RouteTitle") as Label).text = "關卡路線：點選關卡，決定小隊在哪裡行軍"
	(root.get_node("DepartButton") as Button).text = "挑戰關卡王"
	_copy(root, "DepartButton", "MarchHereButton", Vector2(60, 1265), Vector2(400, 99), "在此行軍")


func _store(root: Control) -> void:
	(root.get_node("PageTitle") as Label).text = "商店"
	for p: String in ["StoreSubtitle", "ProductGrid", "GiftArt", "GiftTitle", "GiftDescription", "GiftButton"]:
		_u(root, p)
	(root.get_node("GiftTitle") as Label).text = "每日免費招募"
	(root.get_node("GiftButton") as Button).text = "看廣告招募"
	_copy(root, "GiftButton", "RatesButton", Vector2(372, 1321), Vector2(210, 88), "機率說明")


# --- march strip and home ----------------------------------------------------------------------------------------

## The hero sprite of a march unit: a cell of heroes.png standing on the unit's feet; HP bars raised over it.
func _unit() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(UNIT)
	var root: Node2D = opened.root
	if root.get_node_or_null("HeroSprite") != null:
		root.free()
		return true
	var sprite := Sprite2D.new()
	sprite.name = "HeroSprite"
	sprite.texture = load("res://assets/heroes/heroes.png")
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(4 * 48, 0, 48, 48)
	sprite.scale = Vector2(2.0, 2.0)
	sprite.position = Vector2(-48.0, -92.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sprite)
	root.move_child(sprite, 1)
	sprite.unique_name_in_owner = true
	for bar: String in ["HealthBackground", "HealthFill"]:
		(root.get_node(bar) as Node2D).position.y = -60.0
	return SceneBuilder.save_scene(root, UNIT, {"overwrite": true, "expected_refs": opened.refs}).ok


func _arena() -> bool:
	if FileAccess.file_exists(ARENA):
		return true
	var arena := Node2D.new()
	arena.name = "MarchArena"
	arena.set_script(load("res://scripts/march_arena.gd"))
	var heroes: Node2D = SceneBuilder.add(arena, SceneBuilder.unique(Node2D.new()), "Heroes")
	var xs: Array = [0.0, -0.5, -3.1, -2.2, -2.6]
	for k: int in 5:
		var u: Node2D = SceneBuilder.add(heroes, SceneBuilder.instance(UNIT), "Hero%d" % k)
		u.position = Vector2(360.0 + xs[k] * 72.0, 0.0)
	var enemies: Node2D = SceneBuilder.add(arena, SceneBuilder.unique(Node2D.new()), "Enemies")
	for k: int in 3:
		var u: Node2D = SceneBuilder.add(enemies, SceneBuilder.instance(UNIT), "Enemy%d" % k)
		u.position = Vector2(560.0 + k * 110.0, 0.0)
		u.set("appearance", "SlimeVisual")
	var wave := Label.new()
	wave.text = "1-1 黃昏要塞　行軍中"
	wave.add_theme_font_override(&"font", load(BOLD))
	wave.add_theme_font_size_override(&"font_size", 26)
	wave.add_theme_color_override(&"font_color", Color.WHITE)
	wave.add_theme_color_override(&"font_outline_color", Color("1d2433"))
	wave.add_theme_constant_override(&"outline_size", 6)
	SceneBuilder.add(arena, SceneBuilder.unique(wave), "WaveLabel")
	wave.position = Vector2(20, -350)
	wave.size = Vector2(700, 40)
	return SceneBuilder.save_scene(arena, ARENA, {"expected_refs": [UNIT]}).ok


func _home() -> bool:
	if FileAccess.file_exists(HOME) and FileAccess.get_file_as_string(HOME).contains("node name=\"Pages\""):
		return true
	var home := Control.new()
	home.name = "Home"
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.theme = load(THEME)
	home.set_script(load("res://scripts/home.gd"))
	var back := ColorRect.new()
	back.color = Color("27304a")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(home, back, "Backdrop")
	var pages: Control = SceneBuilder.add(home, SceneBuilder.unique(Control.new()), "Pages")
	pages.set_anchors_preset(Control.PRESET_FULL_RECT)
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var refs: Array = [HEADER, NAV, ARENA]
	for spec: Array in PAGES:
		var page: Control = SceneBuilder.add(pages, SceneBuilder.unique(SceneBuilder.instance(PAGE % spec[0])), spec[1])
		page.set_anchors_preset(Control.PRESET_FULL_RECT)
		page.visible = spec[0] == "overview"
		refs.append(PAGE % spec[0])
	var arena: Node2D = SceneBuilder.add(home, SceneBuilder.unique(SceneBuilder.instance(ARENA)), "MarchArena")
	arena.position = Vector2(0, 470)
	SceneBuilder.add(home, SceneBuilder.unique(SceneBuilder.instance(HEADER)), "Header")
	var nav: Control = SceneBuilder.add(home, SceneBuilder.unique(SceneBuilder.instance(NAV)), "Navigation")
	nav.position = Vector2(0, 1536)
	# Red dots over the nav buttons (a page with something to do), in the nav scene's button order.
	var dots: Control = SceneBuilder.add(home, SceneBuilder.unique(Control.new()), "NavDots")
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k: int in nav.get_child_count():
		var button: Control = nav.get_child(k)
		var dot := TextureRect.new()
		dot.texture = load("res://assets/atlas/notification.tres")
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		SceneBuilder.add(dots, dot, "Dot%d" % k)
		dot.position = nav.position + button.position + Vector2(button.size.x - 34, -6)
		dot.size = Vector2(34, 34)
	var toast := Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_override(&"font", load(BOLD))
	toast.add_theme_font_size_override(&"font_size", 28)
	toast.add_theme_color_override(&"font_color", Color.WHITE)
	toast.add_theme_color_override(&"font_outline_color", Color("1d2433"))
	toast.add_theme_constant_override(&"outline_size", 8)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(home, SceneBuilder.unique(toast), "Toast")
	toast.position = Vector2(40, 1440)
	toast.size = Vector2(861, 80)
	_dialog(home)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	SceneBuilder.add(home, SceneBuilder.unique(overlay), "SettingsOverlay")
	var settings: Control = SceneBuilder.add(overlay, SceneBuilder.unique(SceneBuilder.instance(SETTINGS)), "SettingsPanel")
	settings.position = Vector2(110, 420)
	settings.size = Vector2(721, 760)
	refs.append(SETTINGS)
	return SceneBuilder.save_scene(home, HOME, {"overwrite": true, "expected_refs": refs}).ok


## The one dialog of the home screen (offline report, pull results, odds, item info): a shade, a paper panel, a
## title, a scrolling body, 好 and an optional second button (看廣告).
func _dialog(home: Control) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	SceneBuilder.add(home, SceneBuilder.unique(shade), "Dialog")
	var panel := Panel.new()
	panel.add_theme_stylebox_override(&"panel", load("res://ui/paper_frame.tres"))
	SceneBuilder.add(shade, SceneBuilder.unique(panel), "DialogPanel")
	panel.position = Vector2(60, 360)
	panel.size = Vector2(821, 860)
	# paper_frame draws only the border (draw_center off): a paper fill sits behind it, as in the pages.
	var fill := Panel.new()
	fill.show_behind_parent = true
	fill.add_theme_stylebox_override(&"panel", load("res://ui/paper.tres"))
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(panel, fill, "DialogFill")
	fill.offset_left = 18
	fill.offset_top = 18
	fill.offset_right = -18
	fill.offset_bottom = -18
	var title := Label.new()
	title.add_theme_font_override(&"font", load(BOLD))
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(panel, SceneBuilder.unique(title), "DialogTitle")
	title.position = Vector2(40, 36)
	title.size = Vector2(741, 60)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	SceneBuilder.add(panel, scroll, "DialogScroll")
	scroll.position = Vector2(56, 112)
	scroll.size = Vector2(709, 580)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override(&"font_size", 28)
	body.add_theme_color_override(&"font_color", INK)
	SceneBuilder.add(scroll, SceneBuilder.unique(body), "DialogBody")
	var ok: Button = _button("好", "green", 30)
	SceneBuilder.add(panel, SceneBuilder.unique(ok), "DialogOk")
	ok.position = Vector2(441, 724)
	ok.size = Vector2(320, 92)
	var alt: Button = _button("看廣告 金幣 ×2", "gold", 26)
	SceneBuilder.add(panel, SceneBuilder.unique(alt), "DialogAlt")
	alt.position = Vector2(60, 724)
	alt.size = Vector2(360, 92)
