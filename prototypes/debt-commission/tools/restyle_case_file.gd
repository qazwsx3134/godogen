extends SceneTree
## One-off authoring tool: turns the detail area of scenes/ui/case_file_panel.tscn into a status card
## in the manner of an equipment sheet — a paper card (%CaseFileDetail) with a ◆ ribbon naming what it
## is, the name on a plaque, the order and use on the left of the picture in a ring, then ◆ 說明 and
## ◆ 拿來吐槽 sections. CaseFilePicture, CaseFileName, CaseFileText and CaseFileUse keep their names
## and move into the card. Skips a scene that already has the card; after it runs the scene is the
## source file.
##   godot --headless --path . --script res://tools/restyle_case_file.gd

const PATH: String = "res://scenes/ui/case_file_panel.tscn"


func _init() -> void:
	var panel: Node = (load(PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if panel.find_child("CaseFileDetail", true, false) != null:
		print("case_file_panel already has the status card")
		panel.free()
		quit()
		return
	var before: int = _count(panel)
	var layout: Node = panel.get_node("Margins/Layout")
	var picture: Control = layout.get_node("CaseFilePicture") as Control
	var name_label: Label = layout.get_node("CaseFileName") as Label
	var text: Label = layout.get_node("CaseFileText") as Label
	var use_row: Control = layout.get_node("UseRow") as Control
	var created: Array[Node] = []

	var detail: PanelContainer = PanelContainer.new()
	detail.name = "CaseFileDetail"
	detail.unique_name_in_owner = true
	detail.set_meta("ui_style_role", "confirmation")
	layout.add_child(detail)
	layout.move_child(detail, picture.get_index())
	detail.owner = panel
	created.append(detail)
	var column: VBoxContainer = _add(VBoxContainer.new(), "DetailColumn", detail, created)
	column.add_theme_constant_override("separation", 18)
	var kind: Label = _add(_label("◆ 吐槽素材情報", 34, "accent"), "CaseFileKind", column, created)
	kind.unique_name_in_owner = true
	var name_row: CenterContainer = _add(CenterContainer.new(), "NameRow", column, created)
	var plaque: PanelContainer = _add(PanelContainer.new(), "CaseFileNamePlaque", name_row, created)
	plaque.unique_name_in_owner = true
	plaque.custom_minimum_size = Vector2(560, 92)
	_move(name_label, plaque)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.remove_meta("ui_style_role")  # the plaque's ink, set with the plaque
	var top: HBoxContainer = _add(HBoxContainer.new(), "Top", column, created)
	top.add_theme_constant_override("separation", 24)
	var info: VBoxContainer = _add(VBoxContainer.new(), "Info", top, created)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 14)
	var order: Label = _add(_label("第 1 件／共 4 件", 32, "muted"), "CaseFileOrder", info, created)
	order.unique_name_in_owner = true
	var status: Label = _add(_label("可以拿來吐槽", 36, "body"), "CaseFileStatus", info, created)
	status.unique_name_in_owner = true
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ring: PanelContainer = _add(PanelContainer.new(), "CaseFileRing", top, created)
	ring.unique_name_in_owner = true
	ring.custom_minimum_size = Vector2(300, 300)
	_move(picture, ring)
	picture.custom_minimum_size = Vector2(0, 0)
	var rule: ColorRect = _add(ColorRect.new(), "Rule", column, created)
	rule.custom_minimum_size = Vector2(0, 3)
	rule.color = Color(0.22, 0.34, 0.45, 0.3)
	_add(_label("◆ 說明", 34, "accent"), "AboutHead", column, created)
	_move(text, column)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # keeps 。」 off the start of a line
	var use_head: Label = _add(_label("◆ 拿來吐槽", 34, "accent"), "CaseFileUseHead", column, created)
	use_head.unique_name_in_owner = true
	_move(use_row, column)
	var room: Control = _add(Control.new(), "WaveRoom", column, created)
	room.custom_minimum_size = Vector2(0, 72)  # the paper's waves and blossoms sit here, not on text
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var packed: PackedScene = PackedScene.new()
	if packed.pack(panel) != OK:
		_fail("pack")
		return
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	var named: bool = ["CaseFilePicture", "CaseFileName", "CaseFileText", "CaseFileUse", "CaseFileGrid"].all(
		func(node_name: String) -> bool: return check.find_child(node_name, true, false) != null)
	check.free()
	panel.free()
	if after != before + created.size() or not named:
		_fail("node count %d -> %d, expected +%d (names kept: %s)" % [before, after, created.size(), named])
		return
	if ResourceSaver.save(packed, PATH) != OK:
		_fail("save")
		return
	print("%s: %d -> %d nodes" % [PATH, before, after])
	quit()


func _add(node: Node, node_name: String, parent: Node, created: Array[Node]) -> Node:
	node.name = node_name
	parent.add_child(node)
	_own(node, parent.owner if parent.owner != null else parent)
	created.append(node)
	return node


## Moves an existing node (and its children) under `parent`, keeping the scene as their owner.
func _move(node: Node, parent: Node) -> void:
	var owner_node: Node = parent.owner if parent.owner != null else parent
	node.reparent(parent, false)
	_own(node, owner_node)


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children():
		_own(child, owner_node)


func _label(text: String, font_size: int, role: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.set_meta("ui_style_role", role)
	return label


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
