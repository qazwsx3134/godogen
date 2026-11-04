extends SceneTree
## One-off authoring tool for 流程圖: creates scenes/ui/flowchart_panel.tscn with its item scene
## flow_box.tscn, and adds 流程圖 (%Flowchart) to the 章節選擇 header. Layout follows
## gallery_panel.tscn; colours come from the ui_style_role metadata. Skips whatever already exists;
## after it runs the scenes are the source files. Re-packing chapter_select.tscn drops the property
## overrides on its preview card instances, so the %Flowchart button there was inserted by hand from
## this tool's output; diff before letting it save over an existing scene again.
##   godot --headless --path . --script res://tools/add_flowchart_scenes.gd

const BOX_PATH: String = "res://scenes/ui/flow_box.tscn"
const PANEL_PATH: String = "res://scenes/ui/flowchart_panel.tscn"
const SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"


func _init() -> void:
	if not ResourceLoader.exists(BOX_PATH) and not _save(_box(), BOX_PATH, 4):
		return
	if not ResourceLoader.exists(PANEL_PATH) and not _save(_panel(), PANEL_PATH, 20):
		return
	if not _add_flowchart_button():
		return
	quit()


## One scene of the chart: a small kind tag (起點／分歧／結局) over its title; ？？？ until reached.
## The panel places and sizes it; it never takes input, so dragging over it pans the chart.
func _box() -> Button:
	var box: Button = Button.new()
	box.name = "FlowBox"
	box.size = Vector2(440, 150)
	box.focus_mode = Control.FOCUS_NONE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("ui_style_role", "selector")
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16.0
	column.offset_top = 10.0
	column.offset_right = -16.0
	column.offset_bottom = -10.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(box, column)
	var kind: Label = Label.new()
	kind.name = "Kind"
	kind.unique_name_in_owner = true
	kind.text = "分歧"
	kind.add_theme_font_size_override("font_size", 28)
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind.set_meta("ui_style_role", "muted")
	_own(column, kind)
	var title: Label = Label.new()
	title.name = "Title"
	title.unique_name_in_owner = true
	title.text = "銀時的證言"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.max_lines_visible = 2
	title.add_theme_font_size_override("font_size", 36)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_meta("ui_style_role", "body")
	_own(column, title)
	return box


## Header (流程圖, ‹ story ›, ×), the progress line, and a scroll holding the chart canvas.
func _panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "FlowchartPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_script(load("res://scripts/flowchart_panel.gd"))
	panel.set_meta("ui_style_role", "log")
	var margins: MarginContainer = MarginContainer.new()
	margins.name = "Margins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	_own(panel, margins)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 16)
	_own(margins, layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 112)
	header.add_theme_constant_override("separation", 16)
	_own(layout, header)
	var heading: Label = Label.new()
	heading.name = "Heading"
	heading.text = "流程圖"
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 52)
	heading.set_meta("ui_style_role", "accent")
	_own(header, heading)
	_own(header, _button("Prev", "‹", 52, Vector2(132.92308, 132.92308), "standard"))
	var story_name: Label = Label.new()
	story_name.name = "StoryName"
	story_name.unique_name_in_owner = true
	story_name.text = "第一章・冰箱是空的"
	story_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	story_name.add_theme_font_size_override("font_size", 40)
	story_name.set_meta("ui_style_role", "body")
	_own(header, story_name)
	_own(header, _button("Next", "›", 52, Vector2(132.92308, 132.92308), "standard"))
	_own(header, _button("Close", "×", 60, Vector2(132.92308, 132.92308), "standard"))
	var progress: Label = Label.new()
	progress.name = "Progress"
	progress.unique_name_in_owner = true
	progress.text = "已走過 3/11・結局 0/2"
	progress.add_theme_font_size_override("font_size", 34)
	progress.set_meta("ui_style_role", "muted")
	_own(layout, progress)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.unique_name_in_owner = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_own(layout, scroll)
	var canvas: Control = Control.new()
	canvas.name = "Canvas"
	canvas.unique_name_in_owner = true
	canvas.custom_minimum_size = Vector2(1720, 600)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_own(scroll, canvas)
	for index: int in range(2):
		var preview: Button = (load(BOX_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Button
		preview.name = "Preview%d" % index
		preview.position = Vector2(48 + index * 560, 48)
		_own(canvas, preview)
	return panel


func _add_flowchart_button() -> bool:
	var select: Node = (load(SELECT_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var header: Node = select.get_node("Margins/Layout/Header")
	if header.has_node("Flowchart"):
		print("chapter_select already has Flowchart")
		select.free()
		return true
	var before: int = _count(select)
	var button: Button = _button("Flowchart", "流程圖", 38, Vector2(0, 132.92308), "standard")
	header.add_child(button)
	header.move_child(button, header.get_node("Gallery").get_index())
	button.owner = select
	return _pack_over(select, SELECT_PATH, before + 1)


func _button(node_name: String, text: String, font_size: int, minimum: Vector2, role: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.text = text
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", font_size)
	button.set_meta("ui_style_role", role)
	return button


## false (exit code 1 set) when packing, the node count or saving fails.
func _pack_over(root: Node, path: String, expected: int) -> bool:
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		return _fail("pack " + path)
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	root.free()
	if after != expected:
		return _fail("%s: node count %d, expected %d" % [path, after, expected])
	if ResourceSaver.save(packed, path) != OK:
		return _fail("save " + path)
	print("%s: %d nodes" % [path, after])
	return true


func _save(root: Node, path: String, expected: int) -> bool:
	return _pack_over(root, path, expected)


func _own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var root: Node = parent if parent.owner == null else parent.owner
	child.owner = root


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
