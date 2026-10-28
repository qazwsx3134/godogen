extends SceneTree
## The flat white look (2026-10-28, the author's pick after the 刀劍神域 reference shots in docs/ui-reference/sao/:
## layout language only: near-opaque white windows over the landscape, white rows and buttons with thin grey borders,
## orange for the selected or main thing, grey ink). Writes the shared styles ui/sao_*.tres (edit one file to restyle
## every node of that role), then points each listed scene's style overrides at them by role and turns its brown and
## navy ink grey. A node is classed by the style it has now (the paper frame, the cream cards, the blue / gold / green
## buttons, the navy bars), so it can run on any page built from the Taskbar Hero parts. Focus styles become empty
## (they draw over the button's content).
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/sao_style.gd -- <scene> [<scene> ...]
## With no scenes it only writes the styles.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const DIR := "res://ui/"
const INK := Color(0.30, 0.31, 0.29)
const SOFT := Color(0.52, 0.53, 0.50)
const ORANGE := Color(0.83, 0.61, 0.09)
const ORANGE_DARK := Color(0.68, 0.48, 0.05)
const LINE := Color(0.80, 0.80, 0.78)
## The nav icons' baked square background; the discs match it so the squares vanish.
const DISC := Color(0.2, 0.259, 0.357)
const MARK := &"sao_style"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_styles()
	var ok: bool = true
	for path: String in OS.get_cmdline_user_args():
		ok = _restyle(path if path.begins_with("res://") else "res://" + path) and ok
	quit(0 if ok else 1)


func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.corner_detail = 4
	b.content_margin_left = 8
	b.content_margin_right = 8
	return b


func _write_styles() -> void:
	var window: StyleBoxFlat = _flat(Color(0.96, 0.96, 0.95, 1.0), Color(0.86, 0.86, 0.84), 2, 8)
	window.shadow_color = Color(0, 0, 0, 0.30)
	window.shadow_size = 10
	window.shadow_offset = Vector2(0, 4)
	var bar: StyleBoxFlat = _flat(Color(0.12, 0.14, 0.17, 0.80), Color(1, 1, 1, 0.35), 0, 0)
	bar.border_width_bottom = 2
	# A window's title strip: a shade darker, an etched line under it.
	var title: StyleBoxFlat = _flat(Color(0.90, 0.90, 0.88, 1), Color(0.57, 0.57, 0.57), 0, 8)
	title.border_width_bottom = 2
	title.corner_radius_bottom_left = 0
	title.corner_radius_bottom_right = 0
	# Sections inside a window are not boxes: a thin line above each.
	var section: StyleBoxFlat = _flat(Color(1, 1, 1, 0), LINE, 0, 0)
	section.border_width_top = 2
	var ring: StyleBoxFlat = _flat(Color(1, 1, 1, 0), Color(0.86, 0.88, 0.91), 3, 60)
	var ring_on: StyleBoxFlat = _flat(Color(1, 1, 1, 0), ORANGE, 5, 60)
	ring_on.shadow_color = Color(ORANGE, 0.55)
	ring_on.shadow_size = 8
	# The slanted HP gauge (the SAO kit's bars): a dark track and three fills by how much is left.
	var gauge: StyleBoxFlat = _flat(Color(0.08, 0.09, 0.11, 0.55), Color(1, 1, 1, 0.75), 2, 0)
	gauge.skew = Vector2(0.5, 0)
	# HUD layer (over the battle): dark glass with a thin light frame; frames alone; the diamond (rotated in the scene).
	var glass: StyleBoxFlat = _flat(Color(0.14, 0.15, 0.17, 0.62), Color(0.88, 0.90, 0.92, 0.75), 1, 2)
	var frame: StyleBoxFlat = _flat(Color(0.08, 0.09, 0.11, 0.45), Color(0.88, 0.90, 0.92, 0.85), 1, 1)
	var diamond: StyleBoxFlat = _flat(Color(0.14, 0.15, 0.17, 0.85), Color(0.95, 0.96, 0.97, 0.95), 2, 2)
	var styles := {
		"sao_hud_glass": glass,
		"sao_hud_frame": frame,
		"sao_diamond": diamond,
		"sao_gauge_cyan": _skewed(Color(0.25, 0.78, 0.90)),
		"sao_gauge_boss": _skewed(Color(0.86, 0.18, 0.24)),
		"sao_gauge": gauge,
		"sao_gauge_green": _skewed(Color(0.55, 0.82, 0.18)),
		"sao_gauge_yellow": _skewed(Color(0.95, 0.80, 0.15)),
		"sao_gauge_red": _skewed(Color(0.90, 0.25, 0.22)),
		"sao_window": window,
		"sao_titlebar": title,
		"sao_section": section,
		"sao_card": _flat(Color(1, 1, 1, 1), Color(0.84, 0.84, 0.82), 2, 6),
		"sao_inset": _flat(Color(0.91, 0.91, 0.89, 1), LINE, 2, 6),
		"sao_selected": _flat(Color(1.0, 0.96, 0.86, 1), ORANGE, 4, 6),
		"sao_button": _flat(Color(0.98, 0.98, 0.97, 1), Color(0.72, 0.72, 0.70), 2, 8),
		# A button worth pressing now (突破 affordable, 升級 with potions): white with a thick gold edge.
		"sao_attention": _flat(Color(1.0, 0.98, 0.92, 1), ORANGE, 4, 8),
		"sao_button_hover": _flat(Color(1.0, 0.98, 0.92, 1), ORANGE, 3, 8),
		"sao_primary": _flat(ORANGE, ORANGE_DARK, 2, 8),
		"sao_primary_hover": _flat(Color(0.92, 0.70, 0.18), Color(1, 1, 1, 0.9), 3, 8),
		"sao_disabled": _flat(Color(0.88, 0.88, 0.87, 1), Color(0.80, 0.80, 0.78), 2, 8),
		"sao_bar": bar,
		"sao_chip": _flat(Color(1, 1, 1, 0.92), Color(1, 1, 1, 0), 0, 30),
		"sao_nav": _flat(Color(0.96, 0.96, 0.95, 0.94), LINE, 2, 18),
		"sao_nav_active": _flat(ORANGE, Color(1, 1, 1, 0.95), 3, 18),
		"sao_disc": _flat(DISC, DISC, 0, 60),
		"sao_ring": ring,
		"sao_ring_active": ring_on,
		"sao_track": _flat(Color(0.82, 0.82, 0.80, 1), Color(0.70, 0.70, 0.68), 1, 3),
		"sao_fill": _flat(Color(0.55, 0.80, 0.22, 1), Color(0.55, 0.80, 0.22, 1), 0, 3),
	}
	for key: String in styles:
		ResourceSaver.save(styles[key], DIR + key + ".tres")


func _skewed(c: Color) -> StyleBoxFlat:
	var b: StyleBoxFlat = _flat(c, c.lightened(0.3), 0, 0)
	b.skew = Vector2(0.5, 0)
	b.border_width_top = 3
	return b


func _style(key: String) -> StyleBox:
	return load(DIR + key + ".tres")


## What role a style plays, from what it looks like now: "window", "section", "inset", "selected", "button",
## "primary", "bar", "chip", "nav", "track", "fill" ("" = leave it).
func _role(box: StyleBox, node: Node, prop: String) -> String:
	if box == null:
		return ""
	var path: String = box.resource_path
	if path.begins_with(DIR + "sao_"):
		return ""
	if path.ends_with("blue.tres") or path.ends_with("green.tres"):
		return "button"
	if path.ends_with("gold.tres"):
		return "primary"
	if path.ends_with("card.tres"):
		return "section"
	if path.ends_with("slot.tres"):
		return "inset"
	if path.ends_with("slot_selected.tres") or path.ends_with("stage_selected.tres"):
		return "selected"
	if box is StyleBoxTexture:
		return "window" if node is Panel else ""
	if box is StyleBoxEmpty:
		return ""
	var flat := box as StyleBoxFlat
	if flat == null:
		return ""
	var c: Color = flat.bg_color
	if prop == "fill":
		return "fill"
	if prop == "background":
		return "track"
	if c.a < 0.5:
		return ""
	var warm: bool = c.r > 0.8 and c.r > c.b + 0.08
	if warm:
		if flat.border_width_top >= 4:
			return "selected"
		return "section" if c.r >= 0.95 else "inset"
	if c.b > c.r and c.v < 0.6:
		if node is Button:
			return "nav" if node.get_parent() != null and node.get_parent().name == "Navigation" else "button"
		return "bar" if node.name == "Backdrop" else "chip"
	return ""


func _restyle(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Node = opened.root
	if root == null:
		return false
	if root.has_meta(MARK):
		print("skip (styled): ", path)
		root.free()
		return true
	var count: int = 0
	for node: Node in _owned(root, root):
		count += _node(node)
	root.set_meta(MARK, true)
	print("%s: %d nodes restyled" % [path, count])
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": opened.refs}).ok


## root and every node it owns (not the insides of sub-scene instances).
func _owned(node: Node, root: Node) -> Array:
	var out: Array = [node]
	for child: Node in node.get_children():
		if child.owner == root or child == root:
			out.append_array(_owned(child, root))
	return out


func _node(node: Node) -> int:
	if not node is Control:
		return 0
	var c := node as Control
	var changed: int = 0
	if c is Panel or c is PanelContainer:
		var role: String = _role(c.get_theme_stylebox(&"panel") if c.has_theme_stylebox_override(&"panel") else null, c, "panel")
		if (role == "section" or role == "window") and c.name == "Frame":
			role = "card"
		if role != "":
			c.add_theme_stylebox_override(&"panel", _style("sao_" + role))
			changed = 1
		if c.name == "PaperFill":
			c.visible = false
	elif c is TextureRect and c.name == "BlankFill":
		# Pieces of the reference art's paper behind a card or button.
		c.visible = false
		changed = 1
	elif c is ProgressBar:
		for prop: String in ["background", "fill"]:
			if c.has_theme_stylebox_override(prop) and _role(c.get_theme_stylebox(prop), c, prop) != "":
				c.add_theme_stylebox_override(prop, _style("sao_track" if prop == "background" else "sao_fill"))
				changed = 1
	elif c is Button:
		changed = _button(c as Button)
	elif c is Label:
		changed = _ink(c, &"font_color")
		# Text that sat on a navy chip (the header's gold and 招募券) now sits on white.
		if c.name.ends_with("Badge") and c.has_theme_color_override(&"font_color"):
			c.add_theme_color_override(&"font_color", INK)
			c.add_theme_color_override(&"font_outline_color", INK)
			changed = 1
	return changed


func _button(b: Button) -> int:
	if not b.has_theme_stylebox_override(&"normal"):
		return _ink(b, &"font_color")
	var role: String = _role(b.get_theme_stylebox(&"normal"), b, "normal")
	if role == "" or role == "section" or role == "inset" or role == "selected" or role == "chip" or role == "bar":
		# Cards' transparent tap areas, slots: keep their look, drop the focus box that covers them.
		if role == "inset" or role == "selected":
			for state: String in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(state, _style("sao_inset"))
		b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		_ink(b, &"font_color")
		return 1
	var normal: String = {"button": "sao_button", "primary": "sao_primary", "nav": "sao_nav"}[role]
	var hover: String = {"button": "sao_button_hover", "primary": "sao_primary_hover", "nav": "sao_button_hover"}[role]
	b.add_theme_stylebox_override(&"normal", _style(normal))
	b.add_theme_stylebox_override(&"hover", _style(hover))
	b.add_theme_stylebox_override(&"pressed", _style(hover))
	b.add_theme_stylebox_override(&"disabled", _style("sao_disabled"))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var text: Color = Color.WHITE if role == "primary" else INK
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, text)
	b.add_theme_color_override(&"font_disabled_color", Color(0.55, 0.57, 0.60))
	if role != "primary":
		# Captions inside the button (the nav bar's) were white on navy.
		for l: Node in b.find_children("*", "Label", true, false):
			(l as Label).add_theme_color_override(&"font_color", INK)
			(l as Label).add_theme_color_override(&"font_outline_color", INK)
	return 1


## Brown and navy ink to grey (dark to INK, mid to SOFT); white, and coloured text (green 行軍中, red), stay.
func _ink(c: Control, key: StringName) -> int:
	if not c.has_theme_color_override(key):
		return 0
	var col: Color = c.get_theme_color(key)
	if col.s > 0.45 and col.v > 0.35:
		return 0
	if col.v < 0.42:
		c.add_theme_color_override(key, INK)
	elif col.v < 0.72 and col.s < 0.45:
		c.add_theme_color_override(key, SOFT)
	else:
		return 0
	if c.has_theme_color_override(&"font_outline_color") and c.get_theme_constant(&"outline_size") == 0:
		c.add_theme_color_override(&"font_outline_color", c.get_theme_color(key))
	return 1
