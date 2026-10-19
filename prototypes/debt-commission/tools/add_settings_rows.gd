extends SceneTree
## One-off authoring tool: appends 畫面效果, 吐槽輔助 and 介面風格 to both settings scenes by copying the
## 紙面透明度 row (its rule, label and buttons), so each new row looks like the ones above it. Skips a
## scene that already has them; after it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_settings_rows.gd

const SCENES: Array[String] = ["res://scenes/ui/settings_panel.tscn", "res://scenes/ui/settings_panel_gintama.tscn"]
## [row node name, label text, button texts]
const ROWS: Array = [
	["Motion", "畫面效果", ["標準", "減少震動與閃光"]],
	["Assist", "吐槽輔助", ["標準", "寬鬆"]],
	["UiStyle", "介面風格", ["映畫", "委託簿", "分鏡", "銀魂和紙"]],
]


func _init() -> void:
	for path: String in SCENES:
		_add_rows(path)
	quit()


func _add_rows(path: String) -> void:
	var panel: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var rows: Node = panel.find_child("Rows", true, false)
	if rows.has_node("Motion"):
		print("%s already has the rows" % path)
		panel.free()
		return
	var before: int = _count(panel)
	var template_row: Node = rows.get_node("PaperOpacity")
	var template_label: Label = rows.get_node("PaperOpacityLabel") as Label
	var template_rule: Node = rows.get_node_or_null("PaperOpacityRule")
	var gintama_marker: String = "◆ " if template_label.text.begins_with("◆") else ""
	var added: int = 0
	for spec: Array in ROWS:
		var row_name: String = spec[0]
		if template_rule != null:
			added += _append(rows, template_rule.duplicate(), row_name + "Rule", panel)
		var label: Label = template_label.duplicate() as Label
		label.text = gintama_marker + str(spec[1])
		added += _append(rows, label, row_name + "Label", panel)
		var row: Container = template_row.duplicate() as Container
		var texts: Array = spec[2]
		while row.get_child_count() > texts.size():
			var extra: Node = row.get_child(row.get_child_count() - 1)
			row.remove_child(extra)
			extra.free()
		while row.get_child_count() < texts.size():
			row.add_child(row.get_child(0).duplicate())
		# Each row is its own group of toggles (the copies would otherwise join 紙面透明度's group).
		var group: ButtonGroup = ButtonGroup.new() if (row.get_child(0) as Button).button_group != null else null
		for index: int in range(texts.size()):
			var button: Button = row.get_child(index) as Button
			button.button_group = group
			button.name = "%s%d" % [row_name, index]
			button.text = texts[index]
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		added += _append(rows, row, row_name, panel)
	var packed: PackedScene = PackedScene.new()
	if packed.pack(panel) != OK:
		push_error("pack failed: " + path)
		quit(1)
		return
	var after: int = _count(packed.instantiate())
	if after != before + added:
		push_error("%s node count %d -> %d, expected +%d" % [path, before, after, added])
		quit(1)
		return
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
		quit(1)
		return
	print("%s: %d -> %d nodes" % [path, before, after])
	panel.free()


## Adds node (with its children) at the end of rows, owned by the scene; returns how many nodes that is.
func _append(rows: Node, node: Node, node_name: String, owner_node: Node) -> int:
	node.name = node_name
	rows.add_child(node)
	return _own(node, owner_node)


func _own(node: Node, owner_node: Node) -> int:
	node.owner = owner_node
	var total: int = 1
	for child: Node in node.get_children():
		total += _own(child, owner_node)
	return total


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
