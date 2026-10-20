extends SceneTree
## Authors scenes/fist_streak.tscn: the FistStreak root and a pool of three arm quads sharing the streak material.
##   godot --headless --path prototypes/luffy-marineford --script res://tools/build_fist_streak.gd
## Applied 2026-10-20. The scene is the source now: edit it in the editor; rerunning skips the existing file.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var root := Node3D.new()
	root.name = "FistStreak"
	root.set_script(load("res://scripts/fist_streak.gd"))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/fist_streak.gdshader")
	material.render_priority = 1
	var quad := QuadMesh.new()
	for i: int in 3:
		var arm := MeshInstance3D.new()
		arm.mesh = quad
		arm.material_override = material
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Shown in the editor as a sample arm thrown forward; hidden at run time.
		arm.transform = Transform3D(Basis(Vector3(3.5, 0, 0), Vector3(0, 0.42, 0), Vector3(0, 0, 1)), Vector3(1.75, 1.1, -0.2 * i))
		SceneBuilder.add(root, arm, "Arm%d" % (i + 1))
	var result: Dictionary = SceneBuilder.save_scene(root, "res://scenes/fist_streak.tscn")
	print("fist_streak: ", result)
	quit(0 if result.ok else 1)
