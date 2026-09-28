extends SceneTree

const ROOT_DIR: String = "res://"
const KNIGHT_COLOR: Color = Color(0.78, 0.66, 0.40, 1.0)
const SLIME_COLOR: Color = Color(0.44, 0.66, 0.56, 1.0)
const INK: Color = Color(0.06, 0.15, 0.16, 1.0)
const DEEP_TEAL: Color = Color(0.035, 0.086, 0.09, 1.0)
const PANEL: Color = Color(0.09, 0.20, 0.20, 1.0)
const PANEL_LIGHT: Color = Color(0.12, 0.25, 0.24, 1.0)
const PARCHMENT: Color = Color(0.92, 0.87, 0.72, 1.0)
const MUTED: Color = Color(0.70, 0.73, 0.66, 1.0)
const GOLD: Color = Color(0.83, 0.65, 0.34, 1.0)
const RUST: Color = Color(0.62, 0.31, 0.24, 1.0)
const SAGE: Color = Color(0.48, 0.69, 0.53, 1.0)

var _failed: bool = false
var _theme: Theme

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--patch-review-fixes"):
		call_deferred("_patch_review_scenes")
	else:
		call_deferred("_build")

func _patch_review_scenes() -> void:
	var shared_theme: Theme = ResourceLoader.load(
		"res://ui/expedition_theme.tres", "Theme", ResourceLoader.CACHE_MODE_IGNORE
	) as Theme
	if shared_theme == null:
		push_error("Cannot load the authored expedition theme for targeted scene patching.")
		quit(1)
		return

	var main_scene: Control = _load_scene_for_patch("res://main.tscn") as Control
	if main_scene == null:
		quit(1)
		return
	main_scene.theme = shared_theme
	for button_path: String in [
		"SafeMargin/MainLayout/ViewToolbar/AdventureButton",
		"SafeMargin/MainLayout/ViewToolbar/PartyButton",
		"SafeMargin/MainLayout/ActionToolbar/PauseButton",
		"SafeMargin/MainLayout/ActionToolbar/SaveButton",
	]:
		var button: Button = main_scene.get_node_or_null(button_path) as Button
		if button == null:
			push_error("Main scene is missing authored button: %s" % button_path)
			_failed = true
			main_scene.free()
			quit(1)
			return
		button.custom_minimum_size.y = 48.0
	var saved_main: PackedScene = _save_scene(
		"res://main.tscn", main_scene,
		[
			"res://scenes/ui/overview_screen.tscn",
			"res://scenes/ui/party_details.tscn",
			"res://scenes/ui/adventure_strip.tscn",
		]
	)
	if saved_main == null or not _verify_external_theme(saved_main, shared_theme.resource_path):
		quit(1)
		return

	var party_scene: Control = _load_scene_for_patch("res://scenes/ui/party_details.tscn") as Control
	if party_scene == null:
		quit(1)
		return
	party_scene.theme = shared_theme
	var badge: Control = party_scene.get_node_or_null(
		"PartyScroll/PartyContent/HeroCard/HeroContent/HeroTitleRow/HeroBadge"
	) as Control
	var title_content: Control = party_scene.get_node_or_null(
		"PartyScroll/PartyContent/HeroCard/HeroContent/HeroTitleRow/HeroTitleContent"
	) as Control
	if badge == null or title_content == null:
		push_error("Party screen is missing its authored portrait or details column.")
		_failed = true
		party_scene.free()
		quit(1)
		return
	badge.custom_minimum_size = Vector2(88.0, badge.custom_minimum_size.y)
	badge.size_flags_horizontal = Control.SIZE_FILL
	title_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var saved_party: PackedScene = _save_scene("res://scenes/ui/party_details.tscn", party_scene)
	if saved_party == null or not _verify_external_theme(saved_party, shared_theme.resource_path):
		quit(1)
		return

	var arena_scene: Node2D = _load_scene_for_patch("res://scenes/combat/combat_arena.tscn") as Node2D
	if arena_scene == null:
		quit(1)
		return
	var slime: Node = arena_scene.get_node_or_null("SlimeUnit")
	var knight: Node = arena_scene.get_node_or_null("KnightUnit")
	if slime == null or knight == null:
		push_error("Combat arena is missing an authored actor instance.")
		_failed = true
		arena_scene.free()
		quit(1)
		return
	arena_scene.set_editable_instance(knight, true)
	arena_scene.set_editable_instance(slime, true)
	var knight_visual: CanvasItem = knight.get_node_or_null("Visuals/KnightVisual") as CanvasItem
	var knight_slime_visual: CanvasItem = knight.get_node_or_null("Visuals/SlimeVisual") as CanvasItem
	var inherited_knight: CanvasItem = slime.get_node_or_null("Visuals/KnightVisual") as CanvasItem
	var authored_slime: CanvasItem = slime.get_node_or_null("Visuals/SlimeVisual") as CanvasItem
	if knight_visual == null or knight_slime_visual == null \
			or inherited_knight == null or authored_slime == null:
		push_error("An actor instance is missing its authored variant visuals.")
		_failed = true
		arena_scene.free()
		quit(1)
		return
	knight_visual.visible = true
	knight_slime_visual.visible = false
	inherited_knight.visible = false
	authored_slime.visible = true
	var saved_arena: PackedScene = _save_scene(
		"res://scenes/combat/combat_arena.tscn", arena_scene,
		["res://scenes/combat/unit.tscn"]
	)
	if saved_arena == null:
		quit(1)
		return

	if _failed:
		quit(1)
		return
	print("TARGETED REVIEW SCENE PATCH COMPLETE: existing scene trees packed and verified in place.")
	quit(0)

func _load_scene_for_patch(path: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		push_error("Cannot load authored scene for targeted patching: %s" % path)
		_failed = true
		return null
	return packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _verify_external_theme(packed: PackedScene, expected_path: String) -> bool:
	var probe: Control = packed.instantiate() as Control
	var actual_path: String = probe.theme.resource_path if probe.theme != null else ""
	probe.free()
	if actual_path != expected_path:
		push_error("Scene theme should reference %s, got %s" % [expected_path, actual_path])
		_failed = true
		return false
	return true

func _build() -> void:
	for directory: String in [
		"res://data/units", "res://domain/combat", "res://autoload", "res://scripts",
		"res://scenes/combat", "res://scenes/ui", "res://ui", "res://tools", "res://tests",
	]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if not _validate_scripts():
		quit(1)
		return

	_build_theme()
	if _failed:
		quit(1)
		return
	var knight_data: Resource = _build_unit_data(
		"res://data/units/knight.tres", "knight", "騎士", "前衛  ·  近戰自動戰鬥",
		"hero", 82, 16, 5, 86.0, 1.25, 54.0, 0, 2.2
	)
	var slime_data: Resource = _build_unit_data(
		"res://data/units/slime.tres", "slime", "史萊姆", "邊境魔物  ·  近距離反擊",
		"enemy", 48, 11, 1, 48.0, 0.9, 46.0, 8, 2.0
	)
	if knight_data == null or slime_data == null:
		quit(1)
		return

	var unit_scene: PackedScene = _build_unit_scene(knight_data)
	if unit_scene == null:
		quit(1)
		return
	var arena_scene: PackedScene = _build_arena_scene(unit_scene, knight_data, slime_data)
	var overview_scene: PackedScene = _build_overview_scene()
	var party_scene: PackedScene = _build_party_scene(knight_data)
	if arena_scene == null or overview_scene == null or party_scene == null:
		quit(1)
		return
	var strip_scene: PackedScene = _build_adventure_strip_scene(arena_scene, knight_data, slime_data)
	if strip_scene == null:
		quit(1)
		return
	var main_scene: PackedScene = _build_main_scene(overview_scene, party_scene, strip_scene)
	if main_scene == null or _failed:
		quit(1)
		return
	print("BUILD COMPLETE: authored scenes saved; regular project startup does not run this builder.")
	quit(0)

func _validate_scripts() -> bool:
	var script_paths: Array[String] = [
		"res://data/unit_data.gd", "res://domain/combat/damage_rules.gd",
		"res://autoload/game.gd", "res://autoload/event_bus.gd", "res://autoload/data_registry.gd",
		"res://autoload/save_manager.gd", "res://autoload/inventory_manager.gd", "res://autoload/progression_manager.gd",
		"res://scripts/combat_unit.gd", "res://scripts/combat_arena.gd", "res://scripts/main.gd",
		"res://scripts/overview_screen.gd", "res://scripts/party_details.gd",
		"res://scripts/adventure_strip.gd", "res://scripts/session_status.gd",
	]
	var valid: bool = true
	for path: String in script_paths:
		var script: Script = load(path) as Script
		if script == null or not script.can_instantiate():
			push_error("Script failed to load before scene build: %s" % path)
			valid = false
	return valid

func _build_theme() -> void:
	var font: Font = load("res://fonts/wqy-zenhei.ttc") as Font
	if font == null:
		push_error("Cannot load bundled WenQuanYi Zen Hei TTC font.")
		_failed = true
		return
	_theme = Theme.new()
	_theme.default_font = font
	_theme.default_font_size = 15
	_theme.set_color("font_color", "Label", PARCHMENT)
	_theme.set_color("font_color", "Button", INK)
	_theme.set_color("font_hover_color", "Button", INK)
	_theme.set_color("font_pressed_color", "Button", INK)
	_theme.set_color("font_disabled_color", "Button", MUTED)
	_theme.set_font_size("font_size", "Label", 14)
	_theme.set_font_size("font_size", "Button", 14)
	var error: Error = ResourceSaver.save(_theme, "res://ui/expedition_theme.tres")
	if error != OK:
		push_error("Cannot save Theme: %s" % error_string(error))
		_failed = true
		return
	_theme = ResourceLoader.load(
		"res://ui/expedition_theme.tres", "Theme", ResourceLoader.CACHE_MODE_IGNORE
	) as Theme
	if _theme == null:
		push_error("Cannot reload saved shared Theme resource.")
		_failed = true

func _build_unit_data(path: String, id: String, display_name: String, role: String, unit_faction: String,
		max_hp: int, attack: int, defense: int, move_speed: float, attack_speed: float,
		attack_range: float, reward: int, respawn_delay: float) -> Resource:
	var script: Script = load("res://data/unit_data.gd") as Script
	var data: Resource = script.new()
	data.set("unit_id", id)
	data.set("display_name", display_name)
	data.set("role_description", role)
	data.set("faction", unit_faction)
	data.set("max_health", max_hp)
	data.set("attack", attack)
	data.set("defense", defense)
	data.set("move_speed", move_speed)
	data.set("attack_speed", attack_speed)
	data.set("attack_range", attack_range)
	data.set("gold_reward", reward)
	data.set("respawn_delay", respawn_delay)
	var error: Error = ResourceSaver.save(data, path)
	if error != OK:
		push_error("Cannot save UnitData at %s: %s" % [path, error_string(error)])
		_failed = true
		return null
	return load(path)

func _build_unit_scene(knight_data: Resource) -> PackedScene:
	var root := Node2D.new()
	root.name = "Unit"
	root.set_script(load("res://scripts/combat_unit.gd"))
	root.set("unit_data", knight_data)
	root.set("faction", "hero")

	var visuals := Node2D.new()
	visuals.name = "Visuals"
	root.add_child(visuals)
	var shadow := _polygon("Shadow", PackedVector2Array([
		Vector2(-24, -1), Vector2(-20, -9), Vector2(0, -12), Vector2(20, -8),
		Vector2(25, -1), Vector2(18, 4), Vector2(-17, 4),
	]), Color(0.02, 0.05, 0.05, 0.68))
	visuals.add_child(shadow)

	var knight := Node2D.new()
	knight.name = "KnightVisual"
	knight.unique_name_in_owner = true
	visuals.add_child(knight)
	knight.add_child(_polygon("Cape", PackedVector2Array([
		Vector2(-13, -21), Vector2(-3, -31), Vector2(13, -22), Vector2(16, 4),
		Vector2(10, 17), Vector2(-11, 14), Vector2(-17, 3),
	]), RUST))
	knight.add_child(_polygon("Tabard", PackedVector2Array([
		Vector2(-10, -23), Vector2(10, -23), Vector2(13, -2), Vector2(7, 16),
		Vector2(-8, 16), Vector2(-14, -2),
	]), Color(0.83, 0.77, 0.60, 1.0)))
	knight.add_child(_polygon("ArmorShoulder", PackedVector2Array([
		Vector2(-17, -24), Vector2(-9, -30), Vector2(-4, -21), Vector2(-9, -12), Vector2(-18, -15),
	]), Color(0.55, 0.67, 0.61, 1.0)))
	knight.add_child(_polygon("Helmet", PackedVector2Array([
		Vector2(-11, -31), Vector2(-6, -41), Vector2(7, -40), Vector2(13, -31),
		Vector2(11, -23), Vector2(-10, -23),
	]), Color(0.75, 0.68, 0.48, 1.0)))
	knight.add_child(_polygon("Visor", PackedVector2Array([
		Vector2(-8, -31), Vector2(9, -31), Vector2(8, -27), Vector2(-7, -27),
	]), INK))
	knight.add_child(_polygon("Sword", PackedVector2Array([
		Vector2(16, -21), Vector2(21, -20), Vector2(35, -43), Vector2(31, -46),
	]), Color(0.80, 0.83, 0.76, 1.0)))
	knight.add_child(_polygon("SwordGuard", PackedVector2Array([
		Vector2(13, -22), Vector2(25, -18), Vector2(23, -15), Vector2(12, -19),
	]), GOLD))
	knight.add_child(_polygon("Shield", PackedVector2Array([
		Vector2(-23, -14), Vector2(-13, -18), Vector2(-12, -1), Vector2(-19, 6), Vector2(-26, -1),
	]), Color(0.14, 0.34, 0.33, 1.0)))
	knight.add_child(_polygon("ShieldMark", PackedVector2Array([
		Vector2(-20, -11), Vector2(-16, -12), Vector2(-16, -2), Vector2(-20, 1),
	]), GOLD))

	var slime := Node2D.new()
	slime.name = "SlimeVisual"
	slime.unique_name_in_owner = true
	visuals.add_child(slime)
	slime.add_child(_polygon("Body", PackedVector2Array([
		Vector2(-23, 4), Vector2(-21, -5), Vector2(-16, -13), Vector2(-9, -17),
		Vector2(-3, -28), Vector2(6, -25), Vector2(12, -16), Vector2(20, -9),
		Vector2(23, 2), Vector2(18, 8), Vector2(-18, 8),
	]), SLIME_COLOR))
	slime.add_child(_polygon("Shine", PackedVector2Array([
		Vector2(-13, -12), Vector2(-7, -20), Vector2(-3, -19), Vector2(-7, -9),
	]), Color(0.72, 0.84, 0.69, 0.9)))
	slime.add_child(_polygon("EyeLeft", PackedVector2Array([
		Vector2(-8, -12), Vector2(-4, -14), Vector2(-1, -11), Vector2(-2, -6), Vector2(-7, -6),
	]), INK))
	slime.add_child(_polygon("EyeRight", PackedVector2Array([
		Vector2(8, -11), Vector2(12, -12), Vector2(14, -8), Vector2(12, -4), Vector2(8, -5),
	]), INK))

	var health_back := _polygon("HealthBackground", PackedVector2Array([
		Vector2(-26, -51), Vector2(26, -51), Vector2(26, -41), Vector2(-26, -41),
	]), Color(0.02, 0.06, 0.06, 0.95))
	root.add_child(health_back)
	var health_fill := _polygon("HealthFill", PackedVector2Array([
		Vector2(-24, -49), Vector2(24, -49), Vector2(24, -43), Vector2(-24, -43),
	]), SAGE)
	health_fill.unique_name_in_owner = true
	root.add_child(health_fill)

	return _save_scene("res://scenes/combat/unit.tscn", root)

func _build_arena_scene(unit_scene: PackedScene, knight_data: Resource, slime_data: Resource) -> PackedScene:
	var root := Node2D.new()
	root.name = "CombatArena"
	var camera := Camera2D.new()
	camera.name = "BattleCamera"
	camera.unique_name_in_owner = true
	camera.position = Vector2(180, 54)
	root.add_child(camera)
	root.set_script(load("res://scripts/combat_arena.gd"))
	root.add_child(_polygon("Sky", PackedVector2Array([
		Vector2(0, 0), Vector2(360, 0), Vector2(360, 108), Vector2(0, 108),
	]), Color(0.10, 0.25, 0.24, 1.0)))
	root.add_child(_polygon("DistantHill", PackedVector2Array([
		Vector2(0, 54), Vector2(37, 42), Vector2(78, 52), Vector2(122, 39),
		Vector2(164, 50), Vector2(204, 38), Vector2(250, 52), Vector2(302, 41),
		Vector2(360, 52), Vector2(360, 89), Vector2(0, 89),
	]), Color(0.15, 0.32, 0.29, 1.0)))
	root.add_child(_polygon("NearHill", PackedVector2Array([
		Vector2(0, 70), Vector2(43, 61), Vector2(90, 73), Vector2(143, 61),
		Vector2(193, 73), Vector2(251, 60), Vector2(310, 72), Vector2(360, 64),
		Vector2(360, 108), Vector2(0, 108),
	]), Color(0.19, 0.34, 0.30, 1.0)))
	root.add_child(_polygon("CombatFloor", PackedVector2Array([
		Vector2(0, 84), Vector2(360, 84), Vector2(360, 108), Vector2(0, 108),
	]), Color(0.12, 0.23, 0.21, 1.0)))
	var floor_line := Line2D.new()
	floor_line.name = "HorizonLine"
	floor_line.points = PackedVector2Array([Vector2(0, 84), Vector2(360, 84)])
	floor_line.width = 1.5
	floor_line.default_color = Color(0.65, 0.53, 0.34, 0.58)
	root.add_child(floor_line)
	root.add_child(_polygon("StoneLeft", PackedVector2Array([
		Vector2(26, 81), Vector2(32, 75), Vector2(41, 78), Vector2(44, 84), Vector2(27, 85),
	]), Color(0.37, 0.43, 0.37, 1.0)))
	root.add_child(_polygon("StoneRight", PackedVector2Array([
		Vector2(315, 83), Vector2(322, 76), Vector2(330, 79), Vector2(334, 85),
	]), Color(0.40, 0.46, 0.38, 1.0)))

	var knight_spawn := Marker2D.new()
	knight_spawn.name = "KnightSpawn"
	knight_spawn.position = Vector2(73, 78)
	root.add_child(knight_spawn)
	var slime_spawn := Marker2D.new()
	slime_spawn.name = "SlimeSpawn"
	slime_spawn.position = Vector2(287, 78)
	root.add_child(slime_spawn)

	var knight: Node = unit_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	knight.name = "KnightUnit"
	knight.unique_name_in_owner = true
	knight.position = knight_spawn.position
	knight.set("unit_data", knight_data)
	knight.set("faction", "hero")
	root.add_child(knight)
	root.set_editable_instance(knight, true)
	var knight_visual: CanvasItem = knight.get_node("Visuals/KnightVisual") as CanvasItem
	var knight_slime_visual: CanvasItem = knight.get_node("Visuals/SlimeVisual") as CanvasItem
	knight_visual.visible = true
	knight_slime_visual.visible = false

	var slime: Node = unit_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	slime.name = "SlimeUnit"
	slime.unique_name_in_owner = true
	slime.position = slime_spawn.position
	slime.set("unit_data", slime_data)
	slime.set("faction", "enemy")
	root.add_child(slime)
	root.set_editable_instance(slime, true)
	var inherited_knight: CanvasItem = slime.get_node("Visuals/KnightVisual") as CanvasItem
	var authored_slime: CanvasItem = slime.get_node("Visuals/SlimeVisual") as CanvasItem
	inherited_knight.visible = false
	authored_slime.visible = true

	return _save_scene("res://scenes/combat/combat_arena.tscn", root, ["res://scenes/combat/unit.tscn"])

func _build_overview_scene() -> PackedScene:
	var root := Control.new()
	root.name = "OverviewScreen"
	root.set_script(load("res://scripts/overview_screen.gd"))
	root.theme = _theme
	_full_rect(root)

	var scroll := ScrollContainer.new()
	scroll.name = "OverviewScroll"
	_full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "OverviewContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var header := _panel("RegionCard", PANEL_LIGHT, GOLD, 12, Vector2(0, 56))
	content.add_child(header)
	var header_box := VBoxContainer.new()
	header_box.name = "RegionContent"
	header_box.add_theme_constant_override("separation", 2)
	header.add_child(header_box)
	var section_kicker := _label("RegionKicker", "邊境遠征  /  常駐戰鬥", 12, GOLD)
	header_box.add_child(section_kicker)
	var stage_title := _label("StageTitle", "第 1-1 區  ·  苔原邊境", 19, PARCHMENT)
	stage_title.unique_name_in_owner = true
	header_box.add_child(stage_title)

	var summary := _panel("ProgressCard", PANEL, Color(0.20, 0.39, 0.36, 1.0), 12, Vector2(0, 85))
	content.add_child(summary)
	var summary_box := VBoxContainer.new()
	summary_box.name = "ProgressContent"
	summary_box.add_theme_constant_override("separation", 5)
	summary.add_child(summary_box)
	summary_box.add_child(_label("ProgressTitle", "遠征成果", 15, GOLD))
	var totals := _label("CombatTotals", "擊倒 0  ·  金幣 0", 20, PARCHMENT)
	totals.unique_name_in_owner = true
	summary_box.add_child(totals)
	summary_box.add_child(_label("ProgressHint", "金幣隨擊倒累積；目前用來記錄冒險成果。", 12, MUTED))

	var guidance := _panel("TacticsCard", PANEL, Color(0.16, 0.31, 0.30, 1.0), 12, Vector2(0, 104))
	content.add_child(guidance)
	var guidance_box := VBoxContainer.new()
	guidance_box.name = "TacticsContent"
	guidance_box.add_theme_constant_override("separation", 5)
	guidance.add_child(guidance_box)
	guidance_box.add_child(_label("TacticsTitle", "騎士的行動", 15, GOLD))
	var tactic_text := _label(
		"TacticsDescription",
		"自動尋找最近的史萊姆，移動到攻擊距離後出手。雙方倒下後會短暫休整，再回到原本的戰場位置。",
		14, PARCHMENT
	)
	tactic_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_box.add_child(tactic_text)

	var feed := _panel("CombatRecordCard", PANEL, Color(0.36, 0.34, 0.23, 1.0), 12, Vector2(0, 83))
	content.add_child(feed)
	var feed_box := VBoxContainer.new()
	feed_box.name = "CombatRecordContent"
	feed_box.add_theme_constant_override("separation", 5)
	feed.add_child(feed_box)
	feed_box.add_child(_label("CombatRecordTitle", "現地紀錄", 14, GOLD))
	var feedback := _label("CombatFeedback", "騎士正在搜尋附近的史萊姆。", 14, PARCHMENT)
	feedback.unique_name_in_owner = true
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed_box.add_child(feedback)

	return _save_scene("res://scenes/ui/overview_screen.tscn", root)

func _build_party_scene(knight_data: Resource) -> PackedScene:
	var root := Control.new()
	root.name = "PartyDetailsScreen"
	root.set_script(load("res://scripts/party_details.gd"))
	root.theme = _theme
	_full_rect(root)

	var scroll := ScrollContainer.new()
	scroll.name = "PartyScroll"
	_full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "PartyContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var intro := _panel("PartyIntroCard", PANEL_LIGHT, GOLD, 12, Vector2(0, 48))
	content.add_child(intro)
	var intro_box := VBoxContainer.new()
	intro_box.name = "PartyIntroContent"
	intro_box.add_theme_constant_override("separation", 2)
	intro.add_child(intro_box)
	intro_box.add_child(_label("PartyKicker", "隊伍資料  /  出戰狀態", 12, GOLD))
	intro_box.add_child(_label("PartyHeading", "目前出戰夥伴", 18, PARCHMENT))

	var hero_card := _panel("HeroCard", PANEL, Color(0.20, 0.39, 0.36, 1.0), 12, Vector2(0, 95))
	content.add_child(hero_card)
	var hero_box := VBoxContainer.new()
	hero_box.name = "HeroContent"
	hero_box.add_theme_constant_override("separation", 4)
	_hero_card_inner(hero_box, knight_data)
	hero_card.add_child(hero_box)

	var stats_card := _panel("HeroStatsCard", PANEL, Color(0.16, 0.31, 0.30, 1.0), 12, Vector2(0, 117))
	content.add_child(stats_card)
	var stats_box := VBoxContainer.new()
	stats_box.name = "HeroStatsContent"
	stats_box.add_theme_constant_override("separation", 7)
	stats_card.add_child(stats_box)
	stats_box.add_child(_label("StatsHeading", "基礎能力", 15, GOLD))
	var grid := GridContainer.new()
	grid.name = "StatsGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	stats_box.add_child(grid)
	var health_stat := _label("HealthStat", "生命　%d" % int(knight_data.get("max_health")), 15, PARCHMENT)
	health_stat.unique_name_in_owner = true
	grid.add_child(health_stat)
	var attack_stat := _label("AttackStat", "攻擊　%d" % int(knight_data.get("attack")), 15, PARCHMENT)
	attack_stat.unique_name_in_owner = true
	grid.add_child(attack_stat)
	var defense_stat := _label("DefenseStat", "防禦　%d" % int(knight_data.get("defense")), 15, PARCHMENT)
	defense_stat.unique_name_in_owner = true
	grid.add_child(defense_stat)
	var speed_stat := _label("SpeedStat", "移動　%d" % roundi(float(knight_data.get("move_speed"))), 15, PARCHMENT)
	speed_stat.unique_name_in_owner = true
	grid.add_child(speed_stat)
	var attack_speed_stat := _label("AttackSpeedStat", "攻擊速度　%.2f / 秒" % float(knight_data.get("attack_speed")), 14, PARCHMENT)
	attack_speed_stat.unique_name_in_owner = true
	grid.add_child(attack_speed_stat)

	var status_card := _panel("PartyStatusCard", PANEL, Color(0.36, 0.34, 0.23, 1.0), 12, Vector2(0, 57))
	content.add_child(status_card)
	var status_box := VBoxContainer.new()
	status_box.name = "PartyStatusContent"
	status_box.add_theme_constant_override("separation", 5)
	status_card.add_child(status_box)
	status_box.add_child(_label("PartyStatusHeading", "冒險狀態", 14, GOLD))
	var party_status := _label("PartyStatus", "目前擊倒 0 隻敵人，持有 0 金幣。", 13, PARCHMENT)
	party_status.unique_name_in_owner = true
	party_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(party_status)

	return _save_scene("res://scenes/ui/party_details.tscn", root)

func _hero_card_inner(parent: VBoxContainer, data: Resource) -> void:
	var title_row := HBoxContainer.new()
	title_row.name = "HeroTitleRow"
	title_row.add_theme_constant_override("separation", 10)
	parent.add_child(title_row)
	var badge := _panel("HeroBadge", Color(0.17, 0.35, 0.33, 1.0), GOLD, 10, Vector2(88, 50))
	badge.size_flags_horizontal = Control.SIZE_FILL
	title_row.add_child(badge)
	var badge_text := _label("HeroBadgeMark", "騎", 25, GOLD)
	badge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_text)
	var hero_titles := VBoxContainer.new()
	hero_titles.name = "HeroTitleContent"
	hero_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_titles.add_theme_constant_override("separation", 1)
	title_row.add_child(hero_titles)
	var hero_name := _label("HeroName", str(data.get("display_name")), 20, PARCHMENT)
	hero_name.unique_name_in_owner = true
	hero_titles.add_child(hero_name)
	var role_label := _label("RoleLabel", str(data.get("role_description")), 13, MUTED)
	role_label.unique_name_in_owner = true
	role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_titles.add_child(role_label)

func _build_adventure_strip_scene(arena_scene: PackedScene, knight_data: Resource, slime_data: Resource) -> PackedScene:
	var root := PanelContainer.new()
	root.name = "AdventureStrip"
	root.set_script(load("res://scripts/adventure_strip.gd"))
	root.theme = _theme
	root.custom_minimum_size = Vector2(0, 184)
	root.add_theme_stylebox_override("panel", _style(PANEL_LIGHT, GOLD, 13, 10))

	var layout := VBoxContainer.new()
	layout.name = "StripLayout"
	layout.add_theme_constant_override("separation", 5)
	root.add_child(layout)
	var header := HBoxContainer.new()
	header.name = "StripHeader"
	header.add_theme_constant_override("separation", 5)
	layout.add_child(header)
	var stage := _label("StripStage", "遠征紀錄  ·  第 1-1 區", 13, GOLD)
	stage.unique_name_in_owner = true
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(stage)
	var totals := _label("StripTotals", "擊倒 0  ·  金幣 0", 13, PARCHMENT)
	totals.unique_name_in_owner = true
	totals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(totals)

	var battlefield := SubViewportContainer.new()
	battlefield.name = "Battlefield"
	battlefield.stretch = true
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.custom_minimum_size = Vector2(0, 91)
	layout.add_child(battlefield)
	var viewport := SubViewport.new()
	viewport.name = "BattleViewport"
	viewport.size = Vector2i(360, 108)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	battlefield.add_child(viewport)
	var arena_instance: Node = arena_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	arena_instance.name = "CombatArena"
	viewport.add_child(arena_instance)

	var vitals := HBoxContainer.new()
	vitals.name = "UnitVitals"
	vitals.add_theme_constant_override("separation", 9)
	layout.add_child(vitals)
	var knight_vitals := _make_vitals("KnightVitals", "騎士  82 / 82", "StripKnightHealthText", "StripKnightHealth", GOLD)
	vitals.add_child(knight_vitals)
	var slime_vitals := _make_vitals("SlimeVitals", "史萊姆  48 / 48", "StripSlimeHealthText", "StripSlimeHealth", SAGE)
	vitals.add_child(slime_vitals)
	var combat_status := _label("StripCombatStatus", "自動索敵  ·  靠近後攻擊", 12, PARCHMENT)
	combat_status.unique_name_in_owner = true
	combat_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(combat_status)

	return _save_scene(
		"res://scenes/ui/adventure_strip.tscn",
		root,
		["res://scenes/combat/combat_arena.tscn"]
	)

func _make_vitals(node_name: String, label_text: String, label_unique_name: String,
		bar_unique_name: String, fill_color: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	var label := _label(label_unique_name, label_text, 11, PARCHMENT)
	label.unique_name_in_owner = true
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.name = bar_unique_name
	bar.unique_name_in_owner = true
	bar.custom_minimum_size = Vector2(0, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0
	bar.max_value = 82 if node_name == "KnightVitals" else 48
	bar.value = bar.max_value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(INK, INK, 4, 1))
	bar.add_theme_stylebox_override("fill", _style(fill_color, fill_color, 4, 1))
	box.add_child(bar)
	return box

func _build_main_scene(overview_scene: PackedScene, party_scene: PackedScene, strip_scene: PackedScene) -> PackedScene:
	var root := Control.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	root.theme = _theme
	_full_rect(root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = DEEP_TEAL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_rect(backdrop)
	root.add_child(backdrop)

	var safe_margin := MarginContainer.new()
	safe_margin.name = "SafeMargin"
	_full_rect(safe_margin)
	safe_margin.add_theme_constant_override("margin_left", 13)
	safe_margin.add_theme_constant_override("margin_top", 12)
	safe_margin.add_theme_constant_override("margin_right", 13)
	safe_margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(safe_margin)

	var layout := VBoxContainer.new()
	layout.name = "MainLayout"
	layout.add_theme_constant_override("separation", 7)
	safe_margin.add_child(layout)

	var top := _panel("TopBar", PANEL, Color(0.45, 0.40, 0.26, 1.0), 12, Vector2(0, 66))
	layout.add_child(top)
	var top_rows := VBoxContainer.new()
	top_rows.name = "TopBarRows"
	top_rows.add_theme_constant_override("separation", 2)
	top.add_child(top_rows)
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.add_theme_constant_override("separation", 6)
	top_rows.add_child(title_row)
	var title := _label("GameTitle", "遠征紀事", 21, PARCHMENT)
	title_row.add_child(title)
	var title_spacer := Control.new()
	title_spacer.name = "TitleSpacer"
	title_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_spacer)
	var gold_label := _label("GoldBadge", "金幣  %d" % 0, 14, GOLD)
	gold_label.unique_name_in_owner = true
	title_row.add_child(gold_label)
	var subtitle := _label("HeaderSubtitle", "苔原邊境  ·  Stage 1-1", 12, MUTED)
	top_rows.add_child(subtitle)

	var views := HBoxContainer.new()
	views.name = "ViewToolbar"
	views.add_theme_constant_override("separation", 7)
	layout.add_child(views)
	var adventure_button := _button("AdventureButton", "遠征總覽", true, Vector2(0, 48))
	adventure_button.unique_name_in_owner = true
	adventure_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views.add_child(adventure_button)
	var party_button := _button("PartyButton", "隊伍資料", false, Vector2(0, 48))
	party_button.unique_name_in_owner = true
	party_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views.add_child(party_button)

	var actions := HBoxContainer.new()
	actions.name = "ActionToolbar"
	actions.add_theme_constant_override("separation", 7)
	layout.add_child(actions)
	var pause_button := _button("PauseButton", "暫停", false, Vector2(0, 48))
	pause_button.unique_name_in_owner = true
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(pause_button)
	var save_button := _button("SaveButton", "手動存檔", true, Vector2(0, 48))
	save_button.unique_name_in_owner = true
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save_button)

	var session_panel := _panel("SessionPanel", Color(0.12, 0.27, 0.25, 1.0), Color(0.28, 0.43, 0.36, 1.0), 9, Vector2(0, 28))
	layout.add_child(session_panel)
	var session_status := _label("SessionStatus", "自動戰鬥進行中  ·  Stage 1-1 持續挑戰", 12, PARCHMENT)
	session_status.unique_name_in_owner = true
	session_status.set_script(load("res://scripts/session_status.gd"))
	session_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	session_panel.add_child(session_status)

	var screen_deck := Control.new()
	screen_deck.name = "ScreenDeck"
	screen_deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen_deck.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_deck.custom_minimum_size = Vector2(0, 110)
	layout.add_child(screen_deck)
	var overview_instance: Control = overview_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Control
	overview_instance.name = "OverviewScreen"
	overview_instance.unique_name_in_owner = true
	_full_rect(overview_instance)
	screen_deck.add_child(overview_instance)
	var party_instance: Control = party_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Control
	party_instance.name = "PartyDetailsScreen"
	party_instance.unique_name_in_owner = true
	party_instance.visible = false
	_full_rect(party_instance)
	screen_deck.add_child(party_instance)

	var strip_instance: PanelContainer = strip_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as PanelContainer
	strip_instance.name = "AdventureStrip"
	strip_instance.unique_name_in_owner = true
	layout.add_child(strip_instance)

	return _save_scene(
		"res://main.tscn",
		root,
		[
			"res://scenes/ui/overview_screen.tscn",
			"res://scenes/ui/party_details.tscn",
			"res://scenes/ui/adventure_strip.tscn",
		]
	)

func _button(node_name: String, caption: String, primary: bool, minimum: Vector2) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.custom_minimum_size = minimum
	button.focus_mode = Control.FOCUS_ALL
	var base_color: Color = GOLD if primary else Color(0.18, 0.34, 0.32, 1.0)
	var hover_color: Color = Color(0.91, 0.74, 0.43, 1.0) if primary else Color(0.28, 0.45, 0.41, 1.0)
	button.add_theme_stylebox_override("normal", _style(base_color, GOLD, 10, 7))
	button.add_theme_stylebox_override("hover", _style(hover_color, PARCHMENT, 10, 7))
	button.add_theme_stylebox_override("pressed", _style(Color(0.63, 0.48, 0.25, 1.0), GOLD, 10, 7))
	button.add_theme_stylebox_override("focus", _style(base_color, PARCHMENT, 10, 7))
	button.add_theme_stylebox_override("disabled", _style(PANEL, MUTED, 10, 7))
	button.add_theme_color_override("font_color", INK if primary else PARCHMENT)
	button.add_theme_color_override("font_hover_color", INK if primary else PARCHMENT)
	button.add_theme_color_override("font_pressed_color", PARCHMENT)
	button.add_theme_font_size_override("font_size", 14)
	return button

func _panel(node_name: String, fill: Color, border: Color, radius: int, minimum: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = minimum
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(fill, border, radius, 10))
	return panel

func _label(node_name: String, caption: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _style(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	return style

func _polygon(node_name: String, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	return polygon

func _full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _save_scene(path: String, scene_root: Node, expected_scene_refs: Array[String] = []) -> PackedScene:
	_assign_scene_owners(scene_root, scene_root, true)
	var before_count: int = _count_nodes(scene_root)
	var packed := PackedScene.new()
	var pack_error: Error = packed.pack(scene_root)
	if pack_error != OK:
		push_error("Cannot pack %s: %s" % [path, error_string(pack_error)])
		_failed = true
		scene_root.free()
		return null
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("Cannot save %s: %s" % [path, error_string(save_error)])
		_failed = true
		scene_root.free()
		return null

	var loaded: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if loaded == null:
		push_error("Cannot reload saved scene %s" % path)
		_failed = true
		scene_root.free()
		return null
	var state: SceneState = loaded.get_state()
	var scene_refs: Array[String] = []
	for index: int in range(state.get_node_count()):
		var referenced_scene: PackedScene = state.get_node_instance(index)
		if referenced_scene != null:
			scene_refs.append(referenced_scene.resource_path)
	for expected_ref: String in expected_scene_refs:
		if not scene_refs.has(expected_ref):
			push_error("Scene reference missing in %s: %s" % [path, expected_ref])
			_failed = true

	var instance: Node = loaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var after_count: int = _count_nodes(instance)
	if before_count != after_count:
		push_error("Node count mismatch in %s: authored %d, reloaded %d" % [path, before_count, after_count])
		_failed = true
	print("SCENE OK %s nodes=%d refs=%s" % [path, after_count, str(scene_refs)])
	instance.free()
	scene_root.free()
	return loaded

func _assign_scene_owners(node: Node, scene_root: Node, is_root: bool = false) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			_assign_scene_owners(child, scene_root)

func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
