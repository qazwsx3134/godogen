extends SceneTree
## One-off authoring tool: puts both chapter result scenes' centred card in a full-screen scroll box
## (Scroll > Center > Card). A card that fits stays centred as before; on a short phone with a long
## chapter title the card scrolls instead of running off the screen. The card lets drags through to
## the scroll box. Skips a scene that already has Scroll; after it runs the scenes are the source.
##   godot --headless --path . --script res://tools/add_result_scroll.gd

const PATHS: Array[String] = ["res://scenes/ui/chapter_result.tscn", "res://scenes/ui/chapter_result_gintama.tscn"]


func _init() -> void:
	for path: String in PATHS:
		if not _wrap(path):
			quit(1)
			return
	quit()


func _wrap(path: String) -> bool:
	var result: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if result.has_node("Scroll"):
		print("%s already has Scroll" % path)
		result.free()
		return true
	var before: int = _count(result)
	var center: Control = result.get_node("Center") as Control
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	result.add_child(scroll)
	result.move_child(scroll, center.get_index())
	scroll.owner = result
	center.reparent(scroll, false)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_own(center, result)
	var card: Control = center.get_child(0) as Control
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var packed: PackedScene = PackedScene.new()
	if packed.pack(result) != OK:
		push_error("pack failed: " + path)
		return false
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	var still_named: bool = check.get_node("Scroll/Center") != null and check.find_child("Next", true, false) != null
	check.free()
	result.free()
	if after != before + 1 or not still_named:
		push_error("%s: node count %d -> %d, expected +1" % [path, before, after])
		return false
	if ResourceSaver.save(packed, path) != OK:
		push_error("save failed: " + path)
		return false
	print("%s: %d -> %d nodes" % [path, before, after])
	return true


## Reparenting keeps the nodes but not their owner; the whole moved branch belongs to the scene.
func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child: Node in node.get_children():
		_own(child, owner_node)


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
