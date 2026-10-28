extends SceneTree
## Applied 2026-10-28: the 天賦 star map grows from 9 to 18 nodes (domain/talents.gd) in six rows: attack on the
## left, the march in the middle, HP on the right. %TalentTree goes inside %TalentScroll (the same rect on the page)
## and is taller than it, so the map scrolls. Skips the page if Node17 is already there.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_talent_tree.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const Talents = preload("res://domain/talents.gd")
const PATH := "res://scenes/pages/train.tscn"
const NODE := "res://scenes/components/talent_node.tscn"
## Each node's place in %TalentTree.
const NODE_AT := {0: Vector2(110, 10), 5: Vector2(370, 10), 1: Vector2(630, 10),
	2: Vector2(20, 200), 4: Vector2(370, 200), 3: Vector2(720, 200),
	7: Vector2(20, 390), 6: Vector2(220, 390), 12: Vector2(410, 390), 8: Vector2(630, 390),
	9: Vector2(220, 580), 13: Vector2(410, 580), 10: Vector2(630, 580),
	14: Vector2(220, 770), 11: Vector2(410, 770), 15: Vector2(630, 770),
	16: Vector2(20, 960), 17: Vector2(720, 960)}
const TREE_SIZE := Vector2(869, 1146)


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var opened: Dictionary = SceneBuilder.open_scene(PATH)
	var root: Control = opened.root
	var tree: Control = root.get_node("TalentTree")
	if tree.get_node_or_null("Node%d" % (Talents.count() - 1)) != null:
		print("skip: the tree has every node")
		root.free()
		quit(0)
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "TalentScroll"
	root.add_child(scroll)
	root.move_child(scroll, tree.get_index())
	scroll.position = tree.position
	scroll.size = tree.size
	SceneBuilder.unique(scroll)
	root.remove_child(tree)
	scroll.add_child(tree)
	tree.position = Vector2.ZERO
	tree.custom_minimum_size = TREE_SIZE
	tree.size = TREE_SIZE
	for k: int in Talents.count():
		var node: Control = tree.get_node_or_null("Node%d" % k)
		if node == null:
			node = SceneBuilder.add(tree, SceneBuilder.instance(NODE), "Node%d" % k)
			(node.get_node("Title") as Label).text = Talents.ROWS[k].name
		node.position = NODE_AT[k]
	(root.get_node("TrainingSubtitle") as Label).text = "用金幣點亮節點，全軍立即變強；越下面的要先打倒樓層王、練高英雄等級。"
	var ok: bool = SceneBuilder.save_scene(root, PATH, {"overwrite": true, "expected_refs": opened.refs}).ok
	quit(0 if ok else 1)
