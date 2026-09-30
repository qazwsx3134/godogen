extends SceneTree
## One-off authoring tool for the concept-art HUD pass (.claude/tasks/sugarcane-art/hud-brief.md).
## Restyles ui/theme.tres, ui/hud.tscn, ui/joystick.tscn and ui/result_panel.tscn in place (nodes
## it does not touch keep their ids) and creates ui/ability_slot.tscn and pickups/coin.tscn.
##
##   godot --headless --path . --script res://tools/restyle_hud.gd
##
## It has been applied. From here on the saved .tscn files are the source: edit them in the editor.
## Running it again is refused (hud.tscn already has %HpBar), because a second pass would duplicate
## nodes and overwrite hand edits.

const NAVY: Color = Color(0.106, 0.129, 0.188, 0.9)
const NAVY_DARK: Color = Color(0.075, 0.09, 0.13, 0.94)
const GOLD: Color = Color(0.91, 0.72, 0.29)
const INK: Color = Color(0.03, 0.035, 0.04)
const HP_GREEN: Color = Color(0.36, 0.78, 0.2)
const HERO_GREEN: Color = Color(0.42, 0.95, 0.28)
const BOSS_RED: Color = Color(0.96, 0.22, 0.18)
const EXP_BLUE: Color = Color(0.05, 0.76, 0.99)
const YELLOW: Color = Color(1.0, 0.8, 0.16)
const SLOT_GREEN: Color = Color(0.4, 0.88, 0.26)

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var probe: Node = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	var done: bool = probe.get_node_or_null("%HpBar") != null
	probe.free()
	if done:
		print("already restyled (hud.tscn has %HpBar): nothing to do")
		quit(0)
		return
	_restyle_theme()
	_save(_ability_slot(), "res://ui/ability_slot.tscn", ["Frame", "Swatch", "Initial", "Icon", "Pips"])
	_save(_restyle_joystick(), "res://ui/joystick.tscn", ["Base", "Knob"])
	_save(_coin(), "res://pickups/coin.tscn", ["Visual"])
	_save(_restyle_hud(), "res://ui/hud.tscn", ["Joystick", "RoomLabel", "LevelLabel", "ExpBar", "HpBar", "HpLabel",
		"HeroPortrait", "PlayerPanel", "BossPanel", "BossPortrait", "BossName", "BossBar", "BottomHeroPanel",
		"BottomPortrait", "BottomHpBar", "CoinIcon", "CoinLabel", "AbilityChips", "PauseButton", "PauseOverlay",
		"ResumeButton", "Fade", "Banner"])
	_save(_restyle_result_panel(), "res://ui/result_panel.tscn", ["Title", "Summary", "CoinsLabel", "RestartButton"])
	print("RESTYLE FAILED" if _failed else "RESTYLE OK")
	quit(1 if _failed else 0)

# --- saving ------------------------------------------------------------------

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _save(root: Node, path: String, required: Array) -> void:
	_own(root, root)
	var expected: int = _count(root)
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		error = ResourceSaver.save(packed, path)
	root.free()
	if error != OK:
		_fail("cannot save %s: %s" % [path, error_string(error)])
		return
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var check: Node = reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var actual: int = _count(check)
	if actual != expected:
		_fail("%s: %d nodes before pack, %d after reload" % [path, expected, actual])
	for node_name: String in required:
		if check.get_node_or_null("%" + node_name) == null:
			_fail("%s: missing %%%s after reload" % [path, node_name])
	print("saved: %s (%d nodes)" % [path, actual])
	check.free()

## Owner on every authored node (a node without one is silently dropped by pack()); sub-scene
## instances get an owner on their root only. The owner is set before the unique-name flag.
func _own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.has_meta(&"_unique"):
			child.remove_meta(&"_unique")
			child.unique_name_in_owner = true
		if child.scene_file_path.is_empty():
			_own(child, owner)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total

func _edit(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)

func _instance(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _unique(node: Node) -> Node:
	node.set_meta(&"_unique", true)
	return node

func _add(parent: Node, child: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child)
	return child

# --- small builders ----------------------------------------------------------

## Anchors first, then offsets (changing an anchor rewrites the offsets).
func _place(c: Control, anchors: Vector4, offsets: Vector4) -> Control:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w
	return c

func _full(c: Control) -> Control:
	return _place(c, Vector4(0, 0, 1, 1), Vector4.ZERO)

func _at(c: Control, x: float, y: float, w: float, h: float) -> Control:
	return _place(c, Vector4.ZERO, Vector4(x, y, x + w, y + h))

func _box(color: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0,
		margin: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.corner_detail = 20 if radius > 30 else 8
	if border_w > 0:
		box.border_color = border
		box.set_border_width_all(border_w)
	if margin != Vector4.ZERO:
		box.content_margin_left = margin.x
		box.content_margin_top = margin.y
		box.content_margin_right = margin.z
		box.content_margin_bottom = margin.w
	return box

func _panel(node_name: String, style: StyleBox) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.add_theme_stylebox_override(&"panel", style)
	return panel

func _text(node_name: String, text: String, font_size: int, color: Color = Color.WHITE, outline: int = 0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", outline)
	return label

## Dark frame + coloured fill; the border is on both styles so the fill edge stays framed.
func _bar(node_name: String, fill: Color, back: Color, border_w: int, radius: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100
	bar.add_theme_stylebox_override(&"background", _box(back, radius, INK, border_w))
	bar.add_theme_stylebox_override(&"fill", _box(fill, radius, INK, border_w))
	return bar

## A TextureRect for art that brings its own frame. The child "Frame" is the stand-in ring that
## hud.gd shows only while the texture is empty; it draws behind its parent, so a texture set in
## the editor covers it there too (the game hides it once a texture is present).
func _portrait(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var frame: Panel = _panel("Frame", _box(Color(0.09, 0.1, 0.14), 100, GOLD, 4))
	frame.show_behind_parent = true
	_add(rect, _full(frame))
	return rect

## Everything except the joystick, the pause button and the pause overlay lets touches through,
## otherwise a control over the joystick area swallows "press anywhere".
func _ignore_all(node: Node) -> void:
	for child: Node in node.get_children():
		if not child is Control or child.name in [&"PauseOverlay", &"PauseButton", &"Joystick"]:
			continue
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if child.scene_file_path.is_empty():
			_ignore_all(child)

# --- theme -------------------------------------------------------------------

func _restyle_theme() -> void:
	var path: String = "res://ui/theme.tres"
	var theme: Theme = load(path) as Theme
	var border: Color = GOLD
	theme.set_stylebox(&"normal", &"Button", _box(NAVY, 20, border, 3))
	theme.set_stylebox(&"hover", &"Button", _box(Color(0.16, 0.2, 0.29, 0.95), 20, Color(1.0, 0.86, 0.42), 3))
	theme.set_stylebox(&"pressed", &"Button", _box(Color(0.07, 0.09, 0.14, 0.95), 20, Color(1.0, 0.86, 0.42), 3))
	theme.set_stylebox(&"disabled", &"Button", _box(Color(NAVY, 0.5), 20, Color(border, 0.45), 3))
	theme.set_stylebox(&"panel", &"Panel", _box(NAVY, 20, border, 3))
	theme.set_stylebox(&"panel", &"PanelContainer", _box(NAVY, 20, border, 3, Vector4(16, 12, 16, 12)))
	if ResourceSaver.save(theme, path) != OK:
		_fail("cannot save " + path)
	else:
		print("saved: ", path)

# --- coin and ability slot ---------------------------------------------------

func _ellipse(rx: float, ry: float, sides: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		var angle: float = TAU * i / sides
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func _poly(node_name: String, points: PackedVector2Array, color: Color, at: Vector2 = Vector2.ZERO) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.position = at
	return polygon

func _coin() -> Node:
	var root := Node2D.new()
	root.name = "Coin"
	root.set_script(load("res://pickups/pickup.gd"))
	root.set("kind", 2)   # Kind.COIN
	var visual: Node2D = _unique(Node2D.new()) as Node2D
	_add(root, visual, "Visual")
	visual.add_child(_poly("Rim", _ellipse(17, 17), Color(0.62, 0.4, 0.08)))
	visual.add_child(_poly("Face", _ellipse(14, 14), Color(0.99, 0.8, 0.22)))
	visual.add_child(_poly("Emboss", _ellipse(9.5, 9.5), Color(0.92, 0.69, 0.12)))
	var shine: Polygon2D = _poly("Shine", _ellipse(6, 2.6, 12), Color(1.0, 0.96, 0.62, 0.95), Vector2(-5, -6))
	shine.rotation = -0.8
	visual.add_child(shine)
	return root

func _ability_slot() -> Node:
	var root := VBoxContainer.new()
	root.name = "AbilitySlot"
	root.set_script(load("res://ui/ability_slot.gd"))
	root.add_theme_constant_override(&"separation", 6)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(104, 104)
	_add(root, icon_box, "IconBox")
	var frame: Panel = _panel("Frame", _box(Color(0.06, 0.08, 0.1, 0.96), 20, SLOT_GREEN, 5))
	_add(icon_box, _unique(_full(frame)))
	var swatch: Panel = _panel("Swatch", _box(Color.WHITE, 14))   # tinted by self_modulate, never by the shared style
	swatch.self_modulate = Color(0.4, 0.85, 0.35)
	_add(frame, _unique(_place(swatch, Vector4(0, 0, 1, 1), Vector4(16, 16, -16, -16))))
	_add(swatch, _unique(_full(_text("Initial", "穿", 50, Color.WHITE, 6))))
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_add(icon_box, _unique(_full(icon)), "Icon")
	var pips: Label = _text("Pips", "◆◆◇", 24, YELLOW)
	pips.custom_minimum_size = Vector2(0, 36)
	pips.add_theme_stylebox_override(&"normal", _box(Color(0.04, 0.05, 0.07, 0.72), 18, Color(0, 0, 0, 0), 0, Vector4(8, 0, 8, 0)))
	_add(root, _unique(pips))
	_ignore_all(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root

# --- joystick ----------------------------------------------------------------

func _restyle_joystick() -> Node:
	var root: Control = _edit("res://ui/joystick.tscn") as Control
	var base: Panel = root.get_node("%Base") as Panel
	# Parked bottom-left, anchored to the bottom edge; joystick.gd stores these offsets on _ready.
	_place(base, Vector4(0, 1, 0, 1), Vector4(22, -398, 312, -108))
	base.add_theme_stylebox_override(&"panel", _box(Color(0.12, 0.12, 0.14, 0.8), 145, Color(0.74, 0.74, 0.78, 0.85), 5))
	var knob: Panel = root.get_node("%Knob") as Panel
	_place(knob, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-62, -62, 62, 62))
	knob.add_theme_stylebox_override(&"panel", _box(Color(0.66, 0.66, 0.69, 0.96), 62, Color(0.88, 0.88, 0.92), 4))
	var up: Array[Vector2] = [Vector2(0, -11), Vector2(13, 9), Vector2(-13, 9)]
	var arrows: Array[String] = ["ArrowUp", "ArrowRight", "ArrowDown", "ArrowLeft"]
	for i: int in 4:
		var points := PackedVector2Array()
		for corner: Vector2 in up:
			points.append(corner.rotated(i * PI * 0.5).snapped(Vector2(0.01, 0.01)))
		var at: Vector2 = Vector2(145, 145) + Vector2.UP.rotated(i * PI * 0.5) * 106.0
		base.add_child(_poly(arrows[i], points, Color(0.78, 0.78, 0.82, 0.92), at.snapped(Vector2(0.01, 0.01))))
	base.move_child(knob, -1)
	(root.get_node("Hint") as Control).visible = false   # the concept art has no hint text
	return root

# --- HUD ---------------------------------------------------------------------

func _restyle_hud() -> Node:
	var root: Control = _edit("res://ui/hud.tscn") as Control
	for old: String in ["TopBar", "BossPanel"]:
		var gone: Node = root.get_node(old)
		root.remove_child(gone)
		gone.free()
	root.set("slot_scene", load("res://ui/ability_slot.tscn"))

	# Top bar: player block or boss block on the left, stage / pause / coins on the right.
	var top := MarginContainer.new()
	_place(top, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 152))
	top.add_theme_constant_override(&"margin_left", 15)
	top.add_theme_constant_override(&"margin_top", 12)
	top.add_theme_constant_override(&"margin_right", 21)
	_add(root, top, "TopBar")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	_add(top, row, "Row")
	var left := Control.new()
	left.custom_minimum_size = Vector2(0, 130)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add(row, left, "Left")

	# Player block (normal rooms): HP bar with LV box on its left end, thin EXP bar, portrait on top.
	var player := Control.new()
	_add(left, _unique(_full(player)), "PlayerPanel")
	var hp_bar: ProgressBar = _bar("HpBar", HP_GREEN, Color(0.05, 0.07, 0.05, 0.94), 4, 10)
	hp_bar.value = 100
	_add(player, _unique(_at(hp_bar, 107, 42, 481, 41)))
	_add(hp_bar, _unique(_full(_text("HpLabel", "520 / 520", 28, Color.WHITE, 6))))
	var exp_bar: ProgressBar = _bar("ExpBar", EXP_BLUE, Color(0.04, 0.06, 0.1, 0.94), 2, 6)
	exp_bar.value = 60
	_add(player, _unique(_at(exp_bar, 117, 88, 471, 12)))
	var level: Label = _text("LevelLabel", "LV 12", 28)
	level.add_theme_stylebox_override(&"normal", _box(Color(0.06, 0.06, 0.08, 0.96), 12, Color(0.92, 0.92, 0.96, 0.9), 2, Vector4(10, 0, 10, 0)))
	_add(player, _unique(_at(level, 97, 18, 137, 48)))
	_add(player, _unique(_at(_portrait("HeroPortrait"), 0, 0, 115, 115)))

	# Boss block (boss rooms): long red bar, name tag, portrait. Hidden here; hud.gd toggles it.
	var boss := Control.new()
	boss.visible = false
	_add(left, _unique(_full(boss)), "BossPanel")
	var boss_bar: ProgressBar = _bar("BossBar", BOSS_RED, Color(0.07, 0.09, 0.13, 0.95), 4, 10)
	boss_bar.value = 62
	_add(boss, _unique(_place(boss_bar, Vector4(0, 0, 1, 0), Vector4(95, 48, 0, 88))))
	var boss_name: Label = _text("BossName", "BOSS", 30, Color(1.0, 0.94, 0.78))
	boss_name.add_theme_stylebox_override(&"normal", _box(Color(0.06, 0.07, 0.1, 0.9), 10, Color(0, 0, 0, 0), 0, Vector4(14, 0, 14, 0)))
	_add(boss, _unique(_at(boss_name, 125, 2, 220, 48)))
	_add(boss, _unique(_at(_portrait("BossPortrait"), 0, 0, 115, 115)))

	# Right column: STAGE box + pause, coin box under them.
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 28)
	_add(row, right, "Right")
	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override(&"separation", 12)
	stage_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_add(right, stage_row, "StageRow")
	var stage_box := PanelContainer.new()
	stage_box.custom_minimum_size = Vector2(0, 64)
	stage_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stage_box.add_theme_stylebox_override(&"panel", _box(NAVY_DARK, 18, Color(1, 1, 1, 0.1), 2, Vector4(20, 2, 22, 2)))
	_add(stage_row, stage_box, "StageBox")
	var stage_text := HBoxContainer.new()
	stage_text.add_theme_constant_override(&"separation", 12)
	_add(stage_box, stage_text, "StageText")
	_add(stage_text, _text("StageLabel", "STAGE", 28))
	_add(stage_text, _unique(_text("RoomLabel", "03", 40, YELLOW)))
	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(68, 68)
	pause.add_theme_font_size_override(&"font_size", 34)
	_add(stage_row, _unique(pause), "PauseButton")
	var coin_row := HBoxContainer.new()
	coin_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_add(right, coin_row, "CoinRow")
	var coin_box := PanelContainer.new()
	coin_box.custom_minimum_size = Vector2(0, 46)
	coin_box.add_theme_stylebox_override(&"panel", _box(NAVY_DARK, 23, Color(1, 1, 1, 0.1), 2, Vector4(6, 2, 20, 2)))
	_add(coin_row, coin_box, "CoinBox")
	var coin_content := HBoxContainer.new()
	coin_content.add_theme_constant_override(&"separation", 8)
	_add(coin_box, coin_content, "CoinContent")
	var coin_icon: TextureRect = _portrait("CoinIcon")
	coin_icon.custom_minimum_size = Vector2(40, 40)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(coin_icon.get_node("Frame") as Panel).add_theme_stylebox_override(&"panel", _box(Color(0.98, 0.78, 0.2), 20, Color(0.62, 0.4, 0.08), 3))
	_add(coin_content, _unique(coin_icon))
	var coin_label: Label = _text("CoinLabel", "328", 30)
	coin_label.custom_minimum_size = Vector2(84, 0)
	_add(coin_content, _unique(coin_label))

	# Boss room: the hero's HP moves to the bottom centre (portrait + 5-segment bar). Hidden here.
	var bottom := Control.new()
	bottom.visible = false
	_place(bottom, Vector4(0.5, 1, 0.5, 1), Vector4(-196, -208, 228, -86))
	_add(root, _unique(bottom), "BottomHeroPanel")
	var bottom_bar: ProgressBar = _bar("BottomHpBar", HERO_GREEN, Color(0.08, 0.11, 0.12, 0.95), 4, 12)
	bottom_bar.value = 80
	_add(bottom, _unique(_at(bottom_bar, 115, 25, 309, 45)))
	for i: int in 4:   # dividers at 20 / 40 / 60 / 80 %
		var cut := ColorRect.new()
		cut.color = Color(INK, 0.9)
		var x: float = 0.2 * (i + 1)
		_add(bottom_bar, _place(cut, Vector4(x, 0, x, 1), Vector4(-2, 0, 2, 0)), "Cut%d" % (i + 1))
	_add(bottom, _unique(_at(_portrait("BottomPortrait"), 0, 0, 122, 122)))

	# Ability slots, bottom centre, nudged right of the joystick: the row is centred 80px right of the
	# screen centre so that even 5 slots stay clear of the parked joystick. The three sample slots
	# only fill the editor view; hud.gd removes them on _ready.
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chips.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chips.add_theme_constant_override(&"separation", 18)
	_place(chips, Vector4(0.5, 1, 0.5, 1), Vector4(80, -266, 80, -118))
	_add(root, _unique(chips), "AbilityChips")
	for i: int in 3:
		_add(chips, _instance("res://ui/ability_slot.tscn"), "SampleSlot%d" % (i + 1))

	root.move_child(top, 1)
	root.move_child(bottom, 2)
	root.move_child(chips, 3)
	_ignore_all(root)

	# Banner: big white text, thick black outline.
	var banner: Label = root.get_node("Banner") as Label
	banner.add_theme_font_size_override(&"font_size", 104)
	banner.add_theme_color_override(&"font_color", Color.WHITE)
	banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	banner.add_theme_constant_override(&"outline_size", 26)
	banner.offset_top = -300.0
	banner.offset_bottom = -140.0
	return root

# --- result panel ------------------------------------------------------------

func _restyle_result_panel() -> Node:
	var root: Control = _edit("res://ui/result_panel.tscn") as Control
	var summary: Node = root.get_node("%Summary")
	var coins: Label = _text("CoinsLabel", "金幣 328", 48, Color(1.0, 0.85, 0.3), 8)
	summary.get_parent().add_child(_unique(coins))
	summary.get_parent().move_child(coins, summary.get_index() + 1)
	return root
