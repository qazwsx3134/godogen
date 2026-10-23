extends SceneTree
## One-off authoring tool for 署名 and 製作名單: creates scenes/ui/credits_roll.tscn with its item
## scenes credits_section.tscn and credits_entry.tscn, adds 製作名單 (%Credits) to the chapter select
## header and a %Credit line to both chapter result scenes. Skips whatever already exists; after it
## runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_credits_scenes.gd

const ROLL_PATH: String = "res://scenes/ui/credits_roll.tscn"
const SECTION_PATH: String = "res://scenes/ui/credits_section.tscn"
const ENTRY_PATH: String = "res://scenes/ui/credits_entry.tscn"
const SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const RESULT_PATHS: Array[String] = ["res://scenes/ui/chapter_result.tscn", "res://scenes/ui/chapter_result_gintama.tscn"]
const INK: Color = Color("#fffdf5")


func _init() -> void:
	if not ResourceLoader.exists(SECTION_PATH):
		var section: Label = _label("CreditsSection", "第一章・萬事屋冰箱草莓牛奶失竊事件", 50, "title_overlay")
		section.custom_minimum_size = Vector2(0, 120)
		section.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		if not _save(section, SECTION_PATH, 1):
			return
	if not ResourceLoader.exists(ENTRY_PATH):
		var entry: VBoxContainer = VBoxContainer.new()
		entry.name = "CreditsEntry"
		entry.add_theme_constant_override("separation", 8)
		var role: Label = _label("Role", "劇本", 34, "scene_overlay")
		role.modulate = Color(1, 1, 1, 0.78)
		_own(entry, role)
		_own(entry, _label("Names", "作者名字", 44, "scene_overlay"))
		if not _save(entry, ENTRY_PATH, 3):
			return
	if not ResourceLoader.exists(ROLL_PATH):
		if not _save(_roll(), ROLL_PATH, 12):
			return
	if not _add_credits_button():
		return
	for path: String in RESULT_PATHS:
		if not _add_result_credit(path):
			return
	quit()


## Full screen: a dark dim, 製作名單 at the top, the rolling list in a scroll box, 關閉 at the bottom.
func _roll() -> Control:
	var roll: Control = Control.new()
	roll.name = "CreditsRoll"
	roll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roll.set_script(load("res://scripts/credits_roll.gd"))
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.035, 0.045, 0.075, 0.95)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_own(roll, dim)
	var heading: Label = _label("Heading", "製作名單", 56, "title_overlay")
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 48.0
	heading.offset_bottom = 160.0
	_own(roll, heading)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.unique_name_in_owner = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 72.0
	scroll.offset_top = 180.0
	scroll.offset_right = -72.0
	scroll.offset_bottom = -220.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_own(roll, scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Roll"
	list.unique_name_in_owner = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 44)
	_own(scroll, list)
	var lead_in: Control = Control.new()
	lead_in.name = "LeadIn"
	lead_in.unique_name_in_owner = true
	lead_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(list, lead_in)
	var section: Label = (load(SECTION_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Label
	section.name = "PreviewSection"
	_own(list, section)
	var entry: Control = (load(ENTRY_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Control
	entry.name = "PreviewEntry"
	_own(list, entry)
	var end: Label = _label("End", "— 完 —", 44, "scene_overlay")
	end.unique_name_in_owner = true
	end.custom_minimum_size = Vector2(0, 240)
	_own(list, end)
	var close: Button = Button.new()
	close.name = "Close"
	close.unique_name_in_owner = true
	close.text = "關閉"
	close.custom_minimum_size = Vector2(332.3077, 132.92308)
	close.add_theme_font_size_override("font_size", 44)
	close.set_meta("ui_style_role", "primary")
	close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close.offset_left = -166.0
	close.offset_right = 166.0
	close.offset_top = -180.0
	close.offset_bottom = -48.0
	_own(roll, close)
	return roll


func _add_credits_button() -> bool:
	var select: Node = (load(SELECT_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var header: Node = select.get_node("Margins/Layout/Header")
	if header.has_node("Credits"):
		print("chapter_select already has Credits")
		select.free()
		return true
	var before: int = _count(select)
	var button: Button = Button.new()
	button.name = "Credits"
	button.unique_name_in_owner = true
	button.text = "製作名單"
	button.custom_minimum_size = Vector2(0, 132.92308)
	button.add_theme_font_size_override("font_size", 38)
	button.set_meta("ui_style_role", "standard")
	header.add_child(button)
	header.move_child(button, header.get_node("Close").get_index())
	button.owner = select
	return _pack_over(select, SELECT_PATH, before + 1)


func _add_result_credit(path: String) -> bool:
	var result: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var column: Node = result.find_child("Column", true, false)  # Center/Column, or Center/Card/Column on washi
	if column.has_node("Credit"):
		print("%s already has Credit" % path)
		result.free()
		return true
	var before: int = _count(result)
	var quote: Label = column.get_node("Quote") as Label
	var credit: Label = Label.new()
	credit.name = "Credit"
	credit.unique_name_in_owner = true
	credit.text = "劇本 作者名字｜繪 畫師名字"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit.add_theme_font_size_override("font_size", 30)
	if quote.has_theme_color_override("font_color"):
		credit.add_theme_color_override("font_color", quote.get_theme_color("font_color"))
	credit.modulate = Color(1, 1, 1, 0.72)
	column.add_child(credit)
	column.move_child(credit, column.get_node("Buttons").get_index())
	credit.owner = result
	return _pack_over(result, path, before + 1)


## false (exit code 1 set) when packing, the node count or saving fails.
func _pack_over(root: Node, path: String, expected: int) -> bool:
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(root), "pack " + path):
		return false
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	root.free()
	if after != expected:
		push_error("%s: node count %d, expected %d" % [path, after, expected])
		quit(1)
		return false
	if not _check(ResourceSaver.save(packed, path), path):
		return false
	print("%s: %d nodes" % [path, after])
	return true


func _save(root: Node, path: String, expected: int) -> bool:
	return _pack_over(root, path, expected)


func _label(node_name: String, text: String, font_size: int, role: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.set_meta("ui_style_role", role)
	return label


## Adds `child` under `parent` owned by the scene root `parent` belongs to (or `parent` itself).
func _own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var root: Node = parent if parent.owner == null else parent.owner
	child.owner = root  # an instanced item scene keeps owning its own children


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


## false (and exit code 1) when err is an error; callers stop there.
func _check(err: Error, what: String) -> bool:
	if err != OK:
		push_error("%s failed: %s" % [what, error_string(err)])
		quit(1)
		return false
	return true
