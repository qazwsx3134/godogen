extends "res://addons/proto_kit/test_kit.gd"
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const PATHS = {
 "res://scenes/ui/dialogue_log.tscn":8,
 "res://scenes/ui/log_entry.tscn":3,
 "res://scenes/ui/save_slot_card.tscn":8,
 "res://scenes/ui/save_overwrite_confirmation.tscn":10,
 "res://scenes/ui/save_slots_panel.tscn":74,
 "res://scenes/ui/end_controls.tscn":4,
}
func _init():_run.call_deferred()
func _nodes(n: Node) -> int:
	var count=1
	for child in n.get_children():count+=_nodes(child)
	return count
func _run() -> void:
	for path: String in PATHS:
		var scene=load(path).instantiate()
		_expect(_nodes(scene)==PATHS[path], "authored %s has its expected nodes before packing" % path)
		var count=_nodes(scene)
		var saved=Builder.save_scene(scene,"user://reading_scene_check.tscn",{"overwrite":true})
		_expect(saved.ok, "authored scene packs with owners")
		var packed=load("user://reading_scene_check.tscn").instantiate()
		_expect(_nodes(packed)==count, "packing preserves the editable tree")
		if path.ends_with("save_slots_panel.tscn"):
			for i in range(6):_expect(packed.find_child("Cards",true,false).get_child(i).scene_file_path.ends_with("save_slot_card.tscn"), "slot %d preserves its item scene reference" % i)
		packed.free()
	var game=load("res://main.tscn").instantiate()
	game.save_path="user://reading_scene_editor.save"
	game.ui_preference_path="user://reading_scene_editor_ui.cfg"
	root.add_child(game)
	await _frames(3)
	# These edits simulate the saved node properties, which layout/ready must not overwrite.
	var title=game._log_overlay.get_node("%LogClose")
	title.text="關閉紀錄（自訂）"
	var margins=game._log_overlay.get_node("Margins")
	margins.add_theme_constant_override("margin_left",61)
	game._layout()
	game._on_begin_pressed()
	await _frames(3)
	game._open_log()
	await _frames(3)
	_expect(title.text=="關閉紀錄（自訂）" and margins.get_theme_constant("margin_left")==61,"editor text and spacing survive ready, layout and opening")
	var source=FileAccess.get_file_as_string("res://scenes/ui/dialogue_log.tscn")
	game.queue_free()
	await _frames(2)
	_expect(FileAccess.get_file_as_string("res://scenes/ui/dialogue_log.tscn")==source,"runtime state never rewrites scene source")
	_finish("READING SCENES TESTS")
