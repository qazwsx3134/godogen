extends SceneTree
## One-off authoring tool: adds 存檔備份 (a rule, a label and %SavesExport／%SavesImport) to the end of
## both 設定 panels, copied from their 吐槽輔助 row so each edition keeps its own look. Skips a panel
## that already has it; after it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_backup_row.gd

const PANELS: Array[String] = ["res://scenes/ui/settings_panel.tscn", "res://scenes/ui/settings_panel_gintama.tscn"]


func _init() -> void:
	for path: String in PANELS:
		if not _add_row(path):
			quit(1)
			return
	quit()


func _add_row(path: String) -> bool:
	var panel: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var rows: Node = panel.find_child("Rows", true, false)
	if rows.has_node("Saves"):
		print("%s already has Saves" % path)
		panel.free()
		return true
	var before: int = _count(panel)
	var assist_row: HBoxContainer = rows.get_node("Assist") as HBoxContainer
	var added: Array[Node] = []
	if rows.has_node("AssistRule"):
		added.append(_copy(rows.get_node("AssistRule"), "SavesRule"))
	var label: Label = _copy(rows.get_node("AssistLabel"), "SavesLabel") as Label
	label.text = "存檔備份（換裝置或重灌前先匯出）"
	added.append(label)
	var row: HBoxContainer = _copy(assist_row, "Saves") as HBoxContainer
	row.unique_name_in_owner = false
	added.append(row)
	for node: Node in added:
		rows.add_child(node)
		_own(node, panel)
	for index: int in range(row.get_child_count()):
		var button: Button = row.get_child(index) as Button
		button.name = ["SavesExport", "SavesImport"][index]
		button.text = ["匯出存檔", "匯入存檔"][index]
		button.unique_name_in_owner = true
		button.toggle_mode = false
		button.button_pressed = false
		button.button_group = null
	var packed: PackedScene = PackedScene.new()
	if packed.pack(panel) != OK:
		push_error("pack failed: " + path)
		return false
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	var expected: int = before + _count_all(added)
	panel.free()
	if after != expected:
		push_error("%s node count %d, expected %d" % [path, after, expected])
		return false
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
		return false
	print("%s: %d -> %d nodes" % [path, before, after])
	return true


func _copy(node: Node, new_name: String) -> Node:
	var copy: Node = node.duplicate()
	copy.name = new_name
	return copy


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children():
		_own(child, owner_node)


func _count_all(nodes: Array[Node]) -> int:
	var total: int = 0
	for node: Node in nodes:
		total += _count(node)
	return total


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
