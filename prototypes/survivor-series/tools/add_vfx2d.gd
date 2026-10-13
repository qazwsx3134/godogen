extends SceneTree
## One-off (2026-10-14): wires VFX 2D Free into the scenes: a pixel smoke cloud in smoke.tscn (the soft puffs
## hidden) and its CC BY 4.0 credit line on the menu. Refuses to run twice (smoke.tscn has Cloud).
##   godot --headless --path . -s tools/add_vfx2d.gd
const VFX2D = preload("res://addons/vfx_2d/vfx_2d.gd")

func _init() -> void:
	var smoke: Node2D = _open("res://scenes/smoke.tscn")
	if smoke.has_node("Cloud"):
		push_error("already applied; edit the scenes directly")
		smoke.free()
		quit(1)
		return
	smoke.get_node("Puffs").visible = false
	var cloud: Node2D = VFX2D.new()
	cloud.name = "Cloud"
	cloud.effect = "smoke"
	cloud.autoplay = false
	cloud.free_when_done = false
	cloud.pixel_size = 3
	cloud.size = Vector2(190, 170)
	cloud.position = Vector2(0, -22)
	cloud.set_param(&"color_core", Color("d8d2e2"))
	cloud.set_param(&"color_mid", Color("9a90b0"))
	cloud.set_param(&"color_edge", Color(0.36, 0.3, 0.46, 0.6))
	smoke.add_child(cloud)
	cloud.owner = smoke
	cloud.unique_name_in_owner = true
	_save(smoke, "res://scenes/smoke.tscn")
	var menu: Node = _open("res://scenes/menu.tscn")
	var column: Node = menu.get_node("Center/Box/Column")
	var credit := Label.new()
	credit.name = "Credits"
	credit.text = "特效：VFX 2D Free by heyheythere（CC BY 4.0）"
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.add_theme_font_size_override("font_size", 11)
	credit.add_theme_color_override("font_color", Color("b9b0d6"))
	column.add_child(credit)
	credit.owner = menu
	_save(menu, "res://scenes/menu.tscn")
	quit()

func _open(path: String) -> Node:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)

func _save(root: Node, path: String) -> void:
	var nodes: int = _count(root)
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate()
	assert(_count(check) == nodes, "%s lost nodes" % path)
	check.free()
	print("vfx2d: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
