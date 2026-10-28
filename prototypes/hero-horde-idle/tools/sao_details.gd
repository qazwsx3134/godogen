extends SceneTree
## Second pass of the flat white look (2026-10-28; tools/sao_style.gd first): round nav buttons (a dark disc behind
## the icon in a thin ring, on a dark bar; the shown page's ring turns gold: home.gd), a title strip on each listed
## page's window (and on the 英雄 page's %HeroDetail), and white item cards with a rarity stripe on the left (the
## page scripts colour %RarityBar). Each step skips a scene it already changed.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/sao_details.gd -- <page> [<page> ...]

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const NAV := "res://scenes/components/navigation.tscn"
const CARDS := ["res://scenes/components/equipment_item_card.tscn", "res://scenes/components/equipment_bag_card.tscn",
	"res://scenes/components/inventory_card.tscn"]
const UI := "res://ui/%s.tres"
## A page's title row (page coordinates), inside ContentPanel's border.
const TITLE_RECT := Rect2(10, 527, 921, 80)
const CAPTION := Color(0.90, 0.91, 0.92)
const STRIPE := 8.0
## Buttons that are the screen's main action: gold. Others in the list: the plain white button.
const PRIMARY := {"res://scenes/components/product_card.tscn": ["BuyButton"],
	"res://scenes/pages/adventure.tscn": ["DepartButton"]}
const PLAIN := {"res://scenes/pages/adventure.tscn": ["MarchHereButton"]}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ok: bool = _nav()
	for path: String in CARDS:
		ok = _card(path) and ok
	for path: String in PRIMARY:
		ok = _buttons(path) and ok
	for page: String in OS.get_cmdline_user_args():
		ok = _title(page if page.begins_with("res://") else "res://" + page) and ok
	quit(0 if ok else 1)


func _panel(style: String) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override(&"panel", load(UI % style))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _nav() -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(NAV)
	var root: Control = opened.root
	if root.get_node_or_null("Bar") != null:
		root.free()
		return true
	# Last child (home.gd and the tests take the buttons by index), drawn behind the buttons.
	var bar: Panel = _panel("sao_bar")
	bar.name = "Bar"
	bar.show_behind_parent = true
	for b: Node in root.get_children():
		if not b is Button:
			continue
		var button := b as Button
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var cx: float = button.size.x / 2.0
		var ring: Panel = _panel("sao_ring")
		ring.name = "Ring"
		button.add_child(ring)
		button.move_child(ring, 0)
		ring.position = Vector2(cx - 50, 0)
		ring.size = Vector2(100, 100)
		var disc: Panel = _panel("sao_disc")
		disc.name = "Disc"
		button.add_child(disc)
		button.move_child(disc, 1)
		disc.position = Vector2(cx - 45, 5)
		disc.size = Vector2(90, 90)
		var icon: TextureRect = button.get_node("Icon")
		icon.position = Vector2(cx - 31, 19)
		icon.size = Vector2(62, 62)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var caption: Label = button.get_node("Caption")
		caption.position = Vector2(0, 96)
		caption.size = Vector2(button.size.x, 26)
		caption.add_theme_font_size_override(&"font_size", 22)
		caption.add_theme_color_override(&"font_color", CAPTION)
		caption.add_theme_color_override(&"font_outline_color", CAPTION)
	root.add_child(bar)
	bar.position = Vector2(0, -8)
	bar.size = Vector2(941, 136)
	return SceneBuilder.save_scene(root, NAV, {"overwrite": true, "expected_refs": opened.refs}).ok


func _card(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_node_or_null("RarityBar") != null:
		root.free()
		return true
	var frame: Panel = root.get_node("Frame")
	frame.add_theme_stylebox_override(&"panel", load(UI % "sao_card"))
	var stripe := ColorRect.new()
	stripe.name = "RarityBar"
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.color = Color("8a8170")
	root.add_child(stripe)
	root.move_child(stripe, frame.get_index() + 1)
	stripe.position = Vector2(2, 4)
	stripe.size = Vector2(STRIPE, frame.size.y - 8)
	SceneBuilder.unique(stripe)
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": opened.refs}).ok


## A title strip over the page's window and, on the 英雄 page, over %HeroDetail's.
func _title(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	if root.get_node_or_null("TitleBar") != null:
		root.free()
		return true
	_strip(root, root.get_node("ContentPanel"), 0.0)
	var detail: Control = root.get_node_or_null("HeroDetail")
	if detail != null:
		_strip(detail, detail.get_node("Backdrop"), detail.position.y)
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": opened.refs}).ok


func _strip(parent: Control, window: Control, parent_y: float) -> void:
	var strip: Panel = _panel("sao_titlebar")
	strip.name = "TitleBar"
	parent.add_child(strip)
	parent.move_child(strip, window.get_index() + 1)
	strip.position = TITLE_RECT.position - Vector2(0, parent_y)
	strip.size = TITLE_RECT.size


func _buttons(path: String) -> bool:
	var opened: Dictionary = SceneBuilder.open_scene(path)
	var root: Control = opened.root
	var done: bool = true
	for n: String in PRIMARY.get(path, []) + PLAIN.get(path, []):
		var b: Button = root.get_node(n)
		var primary: bool = PRIMARY.get(path, []).has(n)
		var normal: StyleBox = load(UI % ("sao_primary" if primary else "sao_button"))
		if b.get_theme_stylebox(&"normal") != normal:
			done = false
		b.add_theme_stylebox_override(&"normal", normal)
		b.add_theme_stylebox_override(&"hover", load(UI % ("sao_primary_hover" if primary else "sao_button_hover")))
		b.add_theme_stylebox_override(&"pressed", load(UI % ("sao_primary_hover" if primary else "sao_button_hover")))
		b.add_theme_stylebox_override(&"disabled", load(UI % "sao_disabled"))
		b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		var ink: Color = Color.WHITE if primary else Color(0.30, 0.31, 0.29)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(key, ink)
		b.add_theme_color_override(&"font_disabled_color", Color(0.55, 0.56, 0.54))
	if done:
		root.free()
		return true
	return SceneBuilder.save_scene(root, path, {"overwrite": true, "expected_refs": opened.refs}).ok
