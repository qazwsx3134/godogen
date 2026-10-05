extends SceneTree
## Writes scenes/ui/choice_item_director.tscn and scenes/ui/choice_sheet_director.tscn once, with
## PackedScene.pack() + ResourceSaver.save():
##   godot --headless --path . --script res://tools/make_director_scenes.gd [-- --force]
## The saved scenes are the source files from then on: edit them in the editor. The game and the tests
## never run this, and it refuses to overwrite a scene unless --force is given; check `git diff` first,
## since a rewrite drops hand edits. Each scene's node count and owners are checked before it is packed
## and after it is read back (the sample rows are instances of the item scene; their own nodes belong
## to them).
## The look: a black panel with yellow-and-black caution tape, the heading 導演選擇, the question in
## white, one clapperboard per option (a striped clapper stick, "SCENE 01" on the slate, the option
## beside it) and a footnote. It is the same in every UI edition, so it takes no edition colours.

const StripeScript: Script = preload("res://scripts/stripe_bar.gd")
const SheetScript: Script = preload("res://scripts/choice_sheet.gd")
const FONT_PATH: String = "res://assets/fonts/story-cjk.ttc"
const ITEM_PATH: String = "res://scenes/ui/choice_item_director.tscn"
const SHEET_PATH: String = "res://scenes/ui/choice_sheet_director.tscn"

const YELLOW: Color = Color("#ffd400")
const BLACK: Color = Color("#0c0c0d")
const SLATE: Color = Color("#1a1a1c")
const PAPER: Color = Color("#f4f1e8")
const DIM: Color = Color("#bdb59a")
## One CSS px of the 390 px wide reference, in the sheet's own pixels.
const CSS: float = 1080.0 / 390.0
const ROW_STATES: Array[String] = ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]
const SAMPLES: Array[String] = ["登勢闖進來", "電話突然響了", "定春帶回奇怪的東西"]

var _font: Font = null
var _fonts: Dictionary = {}


func _init() -> void:
	var force: bool = OS.get_cmdline_user_args().has("--force")
	for path: String in [ITEM_PATH, SHEET_PATH]:
		if FileAccess.file_exists(path) and not force:
			printerr("%s exists; it is the source now. Check git diff, then rerun with -- --force." % path)
			quit(1)
			return
	_font = load(FONT_PATH) as Font
	var ok: bool = _write(ITEM_PATH, _build_item())
	# The sheet instances the item scene, so the item is saved and read back first.
	ok = _write(SHEET_PATH, _build_sheet()) and ok
	quit(0 if ok else 1)


func _write(path: String, root: Control) -> bool:
	var expected: int = _all(root).size()
	for node: Node in _all(root):
		if node != root and not _belongs(node, root):
			printerr("%s: %s has no owner" % [path, root.get_path_to(node)])
			return false
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		printerr("%s: pack failed" % path)
		return false
	if ResourceSaver.save(packed, path) != OK:
		printerr("%s: save failed" % path)
		return false
	root.free()
	var reloaded: Node = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var actual: int = _all(reloaded).size()
	reloaded.free()
	print("%s: %d nodes built, %d after reading it back" % [path, expected, actual])
	return expected == actual


## A node is saved with the scene when the scene owns it, or when it is part of an instance the scene owns.
func _belongs(node: Node, root: Node) -> bool:
	if node.owner == root:
		return true
	return node.owner != null and node.owner.owner == root and node.owner.scene_file_path != ""


func _all(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_all(child))
	return nodes


# ---------------------------------------------------------------- one clapperboard row

func _build_item() -> Control:
	var item: Button = Button.new()
	item.name = "ChoiceItem"
	item.custom_minimum_size = Vector2(0.0, 150.0)
	item.text = SAMPLES[0]
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state: String in ROW_STATES:
		item.add_theme_stylebox_override(state, _card(state))
	for color_name: String in ["font_color", "font_focus_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		item.add_theme_color_override(color_name, PAPER)
	item.add_theme_color_override("font_disabled_color", DIM)
	item.add_theme_font_override("font", _bold(0.5))
	item.add_theme_font_size_override("font_size", 47)

	# The clapper stick: a striped bar along the top edge of the card.
	var stick: Control = _add(item, Control.new(), "Stick", item)
	stick.set_script(StripeScript)
	stick.set("color_a", PAPER)
	stick.set("color_b", Color("#101010"))
	stick.set("stripe_width", 34.0)
	stick.set("lean", 1.0)
	stick.clip_contents = true
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(stick, Vector4(0.0, 0.0, 1.0, 0.0), Vector4(4.0, 4.0, -4.0, 38.0))
	stick.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# The slate: "SCENE 01", numbered by choice_sheet.gd (index_format).
	var index: Label = _add(item, Label.new(), "Index", item, true) as Label
	_anchor(index, Vector4(0.0, 0.5, 0.0, 0.5), Vector4(20.0, -14.0, 212.0, 48.0))
	index.grow_vertical = Control.GROW_DIRECTION_BOTH
	index.text = "SCENE 01"
	index.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	index.add_theme_font_override("font", _bold(0.9))
	index.add_theme_font_size_override("font_size", 33)
	index.add_theme_color_override("font_color", YELLOW)

	var divider: ColorRect = _add(item, ColorRect.new(), "Divider", item) as ColorRect
	_anchor(divider, Vector4(0.0, 0.0, 0.0, 1.0), Vector4(222.0, 54.0, 225.0, -18.0))
	divider.grow_vertical = Control.GROW_DIRECTION_BOTH
	divider.color = Color(YELLOW, 0.55)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item


## A row's box: dark slate with a paper edge; hovering turns the edge yellow, pressing thickens it.
func _card(state: String) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = SLATE
	box.border_color = PAPER
	box.set_border_width_all(4)
	box.content_margin_left = 244.0   # the slate column and its divider
	box.content_margin_top = 58.0     # below the clapper stick
	box.content_margin_right = 28.0
	box.content_margin_bottom = 22.0
	match state:
		"hover":
			box.bg_color = Color("#262628")
			box.border_color = YELLOW
		"pressed", "hover_pressed", "focus":
			box.bg_color = Color("#3a3200")
			box.border_color = YELLOW
			box.set_border_width_all(6)
	return box


# ---------------------------------------------------------------- the sheet

func _build_sheet() -> Control:
	# Read from the file (not the cache the save above left): its instances then hold only what differs from it.
	var item_scene: PackedScene = ResourceLoader.load(ITEM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var root: MarginContainer = MarginContainer.new()
	root.name = "ChoiceSheet"
	root.set_script(SheetScript)
	root.anchor_top = 1.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	theme.default_font = _font
	root.theme = theme
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 0)
	root.set("perspective", "director")
	root.set("item_scene", item_scene)
	root.set("index_format", "SCENE %02d")
	root.set("count_format", "%s選一")
	root.set("count_in_chinese", true)

	# The panel springs in as a whole (choice_sheet.gd pop_in); it grows from the middle of its bottom edge.
	var panel: PanelContainer = _add(root, PanelContainer.new(), "Panel", root, true) as PanelContainer
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.pivot_offset_ratio = Vector2(0.5, 1.0)
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = BLACK
	frame.border_color = YELLOW
	frame.border_width_left = 6
	frame.border_width_right = 6
	frame.border_width_bottom = 6
	panel.add_theme_stylebox_override("panel", frame)

	var body: VBoxContainer = _box(panel, VBoxContainer.new(), "Body", 0)
	_tape(body, "TopTape", 36.0)
	var padding: MarginContainer = _add(body, MarginContainer.new(), "Padding", root) as MarginContainer
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_theme_constant_override("margin_left", 39)
	padding.add_theme_constant_override("margin_top", 30)
	padding.add_theme_constant_override("margin_right", 39)
	padding.add_theme_constant_override("margin_bottom", 30)
	var column: VBoxContainer = _box(padding, VBoxContainer.new(), "Column", 0)

	# 導演選擇 in the middle of the top. The whole sheet must stay narrower than the narrowest phone (320 CSS px
	# is 883 px of the sheet's own once scaled up), so nothing wide sits beside it.
	var banner: Label = _label(column, "Banner", "── 導演選擇 ──", 56, YELLOW, _bold(0.9, 4), true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_gap(column, "PromptGap", 16.0)
	var prompt: Label = _label(column, "Prompt", "接下來發生什麼？", 64, PAPER, _bold(0.8), true)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_constant_override("line_spacing", -4)
	var censor: Button = _add(column, Button.new(), "CensorBar", root, true) as Button
	censor.visible = false
	censor.text = "▇▇▇▇"
	censor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	censor.custom_minimum_size = Vector2(120.0, 133.0)

	_gap(column, "ListGap", 26.0)
	var scroll: ScrollContainer = _add(column, ScrollContainer.new(), "ChoicesScroll", root, true) as ScrollContainer
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows: VBoxContainer = _box(scroll, VBoxContainer.new(), "Choices", 20, true)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# What the editor shows: one instance of the item scene per sample line, each with its own number.
	for index: int in range(SAMPLES.size()):
		# GEN_EDIT_STATE_INSTANCE keeps what the item scene holds, so only the sample's own edits are saved.
		var sample: Button = item_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Button
		sample.name = "Sample%d" % (index + 1)
		rows.add_child(sample)
		sample.owner = root
		sample.set("layout_mode", 2)
		root.set_editable_instance(sample, true)
		sample.text = SAMPLES[index]
		(sample.get_node("%Index") as Label).text = "SCENE %02d" % (index + 1)

	_gap(column, "NoteGap", 18.0)
	var note: Label = _label(column, "Note", "※製作組經費有限", 38, DIM, _bold(0.5), true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_gap(column, "TimerGap", 22.0)
	var timer: HBoxContainer = _box(column, HBoxContainer.new(), "Timer", 25, true)
	timer.visible = false
	timer.custom_minimum_size = Vector2(0.0, 66.0)
	var timer_label: Label = _label(timer, "TimerLabel", "倒數", 39, DIM, null, false)
	timer_label.text = "倒數"
	var bar: ProgressBar = _add(timer, ProgressBar.new(), "TimerBar", root, true) as ProgressBar
	bar.custom_minimum_size = Vector2(122.0, 19.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 8.0
	bar.value = 5.0
	_label(timer, "TimerValue", "6 秒", 39, DIM, null, true)

	_gap(column, "FooterGap", 11.0)
	var footer: HBoxContainer = _box(column, HBoxContainer.new(), "Footer", 22)
	var feedback: Label = _label(footer, "Feedback", "選一個接下來的發展", 39, DIM, null, true)
	feedback.custom_minimum_size = Vector2(0.0, 48.0 * CSS)
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var count: Label = _label(footer, "Count", "三選一", 36, DIM, _bold(0.8), true)
	count.custom_minimum_size = Vector2(112.0, 0.0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var super_button: Button = _add(footer, Button.new(), "Super", root, true) as Button
	super_button.visible = false
	super_button.text = "超必殺！"
	super_button.custom_minimum_size = Vector2(210.0, 48.0 * CSS)
	var menu: Button = _add(footer, Button.new(), "Menu", root, true) as Button
	menu.text = "目錄"
	menu.custom_minimum_size = Vector2(177.0, 48.0 * CSS)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state: String in ROW_STATES:
		var button_box: StyleBoxFlat = StyleBoxFlat.new()
		button_box.draw_center = state != "normal" and state != "disabled"
		button_box.bg_color = Color(YELLOW, 0.16)
		button_box.border_color = YELLOW
		button_box.set_border_width_all(3 if state in ["normal", "hover", "disabled"] else 4)
		button_box.content_margin_left = 33.0
		button_box.content_margin_right = 33.0
		menu.add_theme_stylebox_override(state, button_box)
	for color_name: String in ["font_color", "font_focus_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_disabled_color"]:
		menu.add_theme_color_override(color_name, YELLOW)
	menu.add_theme_font_override("font", _bold(0.8))
	menu.add_theme_font_size_override("font_size", 39)

	_tape(body, "BottomTape", 20.0)
	return root


# ---------------------------------------------------------------- pieces

## A caution tape: yellow and black stripes across the full width of the panel.
func _tape(parent: Node, node_name: String, height: float) -> Control:
	var tape: Control = _add(parent, Control.new(), node_name, parent.owner if parent.owner != null else parent)
	tape.set_script(StripeScript)
	tape.set("color_a", YELLOW)
	tape.set("color_b", BLACK)
	tape.set("stripe_width", 40.0)
	tape.set("lean", 1.0)
	tape.clip_contents = true
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.custom_minimum_size = Vector2(0.0, height)
	return tape


func _box(parent: Node, box: BoxContainer, node_name: String, separation: int, unique: bool = false) -> BoxContainer:
	_add(parent, box, node_name, parent.owner if parent.owner != null else parent, unique)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


func _gap(parent: Node, node_name: String, height: float) -> void:
	var gap: Control = _add(parent, Control.new(), node_name, parent.owner)
	gap.custom_minimum_size = Vector2(0.0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(parent: Node, node_name: String, text: String, font_size: int, color: Color, font: Font, unique: bool) -> Label:
	var label: Label = _add(parent, Label.new(), node_name, parent.owner, unique) as Label
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


## One FontVariation per (embolden, glyph spacing), shared by every label that uses it.
func _bold(embolden: float, spacing: int = 0) -> FontVariation:
	var key: String = "%s/%d" % [embolden, spacing]
	if not _fonts.has(key):
		var variation: FontVariation = FontVariation.new()
		variation.base_font = _font
		variation.variation_embolden = embolden
		variation.spacing_glyph = spacing
		_fonts[key] = variation
	return _fonts[key]


func _add(parent: Node, node: Node, node_name: String, owner_node: Node, unique: bool = false) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node
	node.unique_name_in_owner = unique
	if node is Control:
		(node as Control).set("layout_mode", 2 if parent is Container else 1)
	return node


## Anchors (left, top, right, bottom shares) and offsets (px) in one go.
func _anchor(control: Control, shares: Vector4, offsets: Vector4) -> void:
	control.anchor_left = shares.x
	control.anchor_top = shares.y
	control.anchor_right = shares.z
	control.anchor_bottom = shares.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
