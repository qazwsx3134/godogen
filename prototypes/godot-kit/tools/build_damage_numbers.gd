extends SceneTree
## One-time authoring tool. Existing scenes are refused; maintain saved scenes in the editor.
const Builder = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	var label := Label3D.new()
	label.name = "Number"
	label.text = "128"
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	var result: Dictionary = {"ok": true}
	if not FileAccess.file_exists("res://addons/proto_kit/damage_number_3d.tscn"):
		result = Builder.save_scene(label, "res://addons/proto_kit/damage_number_3d.tscn")
	else:
		label.free()
	if not result.ok:
		push_error(str(result))
		quit(1)
		return
	var root := Node3D.new()
	root.name = "DamageNumbers3D"
	root.set_script(load("res://addons/proto_kit/damage_numbers_3d.gd"))
	root.number_scene = load("res://addons/proto_kit/damage_number_3d.tscn")
	var preview: Node = Builder.instance("res://addons/proto_kit/damage_number_3d.tscn")
	Builder.add(root, preview, "Preview")
	result = Builder.save_scene(root, "res://addons/proto_kit/damage_numbers_3d.tscn")
	if not result.ok:
		push_error(str(result))
	quit(0 if result.ok else 1)
