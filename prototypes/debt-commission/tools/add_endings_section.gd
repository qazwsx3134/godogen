extends SceneTree
## One-off authoring tool: adds 結局收集 to scenes/ui/chapter_select.tscn (a heading and an %Endings list with
## two preview rows) and creates scenes/ui/ending_row.tscn. Skips whatever already exists; after it runs the
## scenes are the source files.
##   godot --headless --path . --script res://tools/add_endings_section.gd

const SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const ROW_PATH: String = "res://scenes/ui/ending_row.tscn"


func _init() -> void:
	if not ResourceLoader.exists(ROW_PATH):
		var row: Label = Label.new()
		row.name = "EndingRow"
		row.custom_minimum_size = Vector2(0, 72)
		row.add_theme_font_size_override("font_size", 36)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.text = "第一章｜這次真的是定春"
		row.set_meta("ui_style_role", "body")
		var packed_row: PackedScene = PackedScene.new()
		packed_row.pack(row)
		_check(ResourceSaver.save(packed_row, ROW_PATH), ROW_PATH)
		row.free()
	var select: Node = (load(SELECT_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var list: Node = select.get_node("Margins/Layout/Scroll/List")
	if list.has_node("Endings"):
		print("chapter_select already has Endings")
		select.free()
		quit()
		return
	var before: int = _count(select)
	var heading: Label = Label.new()
	heading.name = "EndingsHeading"
	heading.text = "結局收集"
	heading.set_meta("ui_style_role", "muted")
	var endings: VBoxContainer = VBoxContainer.new()
	endings.name = "Endings"
	endings.unique_name_in_owner = true
	endings.add_theme_constant_override("separation", 4)
	var anchor: Node = list.get_node("SamplesHeading")
	list.add_child(heading)
	list.move_child(heading, anchor.get_index())
	list.add_child(endings)
	list.move_child(endings, anchor.get_index())
	heading.owner = select
	endings.owner = select
	var row_scene: PackedScene = load(ROW_PATH) as PackedScene
	for preview: Array in [["Preview0", "第一章｜這次真的是定春"], ["Preview1", "第一章｜？？？"]]:
		var row: Label = row_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Label
		row.name = preview[0]
		row.text = preview[1]
		endings.add_child(row)
		row.owner = select
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(select), "pack")
	var after: int = _count(packed.instantiate())
	if after != before + 4:
		push_error("node count %d -> %d, expected +4" % [before, after])
		quit(1)
		return
	_check(ResourceSaver.save(packed, SELECT_PATH), SELECT_PATH)
	print("chapter_select: %d -> %d nodes" % [before, after])
	select.free()
	quit()


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _check(err: Error, what: String) -> void:
	if err != OK:
		push_error("%s failed: %s" % [what, error_string(err)])
		quit(1)
