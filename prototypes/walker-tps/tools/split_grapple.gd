extends SceneTree
## One-time authoring: moves Launch0/1, Cable0/1, Pin0/1 of walker_combat.tscn under a new Grapple node
## (scripts/grapple.gd), keeping their transforms. Refuses when Grapple already exists.
##   godot --headless --path . --script res://tools/split_grapple.gd
const B = preload("res://addons/proto_kit/scene_builder.gd")
const MOVED := ["Launch0", "Cable0", "Pin0", "Launch1", "Cable1", "Pin1"]

func _initialize() -> void:
	var opened := B.open_scene("res://scenes/walker_combat.tscn")
	var root: Node = opened.root
	if root.has_node("Grapple"):
		print("Grapple already exists; nothing to do")
		root.free()
		quit(0)
		return
	var before := B.count_nodes(root)
	var grapple := Node3D.new()
	grapple.set_script(load("res://scripts/grapple.gd"))
	B.put(root, grapple, "Grapple", 0)
	for node_name: String in MOVED:
		var node: Node3D = root.get_node(node_name)
		var keep := node.transform
		root.remove_child(node)
		grapple.add_child(node)
		node.transform = keep
	B.own_nodes(root)
	var ok: bool = B.count_nodes(root) == before + 1
	if not ok: push_error("node count changed unexpectedly")
	ok = B.save_scene(root, "res://scenes/walker_combat.tscn", {"overwrite": true, "expected_refs": opened.refs}).ok and ok
	quit(0 if ok else 1)
