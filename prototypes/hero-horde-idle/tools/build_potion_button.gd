extends SceneTree
## Applied 2026-10-28: a 經驗藥水 button in the 英雄 detail's action row (heroes_page.gd: one potion = one level for
## this hero, marching or not). Skips if it is there.
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_potion_button.gd

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const PATH := "res://scenes/pages/heroes.tscn"


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var opened: Dictionary = SceneBuilder.open_scene(PATH)
	var root: Control = opened.root
	var row: Node = root.get_node("HeroDetail/ActionRow")
	if row.get_node_or_null("PotionButton") != null:
		root.free()
		quit(0)
		return
	var b: Button = (row.get_node("CaptainButton") as Button).duplicate()
	b.text = "經驗藥水"
	b.unique_name_in_owner = false
	b.name = "PotionButton"
	row.add_child(b)
	SceneBuilder.unique(b)
	quit(0 if SceneBuilder.save_scene(root, PATH, {"overwrite": true, "expected_refs": opened.refs}).ok else 1)
