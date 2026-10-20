extends SceneTree
## Authors scenes/cast_actor.tscn (one cast member: sprite quad + blob shadow, the sheet picked by `character` at run
## time) and scenes/blocker.tscn (the same body with blocker.gd: a story blocker Luffy has to punch through).
## One-time tool: existing scenes are skipped.
##   godot --headless --path prototypes/luffy-marineford --script res://tools/build_cast_actor.gd

const Builder = preload("res://addons/proto_kit/scene_builder.gd")


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var ok: bool = _body("CastActor", "res://scripts/cast_actor.gd", "res://scenes/cast_actor.tscn")
	ok = _body("Blocker", "res://scripts/blocker.gd", "res://scenes/blocker.tscn") and ok
	quit(0 if ok else 1)


func _body(node_name: String, script: String, path: String) -> bool:
	var root := Node3D.new()
	root.name = node_name
	root.set_script(load(script))
	root.set(&"xray_path", NodePath(""))
	root.set(&"shadow_path", NodePath(""))
	var blob := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	blob.mesh = plane
	blob.material_override = load("res://materials/blob_shadow.tres")
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.scale = Vector3.ONE
	Builder.add(root, blob, "Blob")
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	sprite.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = load("res://addons/proto_kit/sprite3d.gdshader")
	material.set_shader_parameter(&"use_instance_custom", false)
	sprite.material_override = material
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.scale = Vector3(2.4, 2.4, 2.4)
	Builder.add(root, sprite, "Sprite")
	var result: Dictionary = Builder.save_scene(root, path)
	print(node_name, ": ", result)
	return result.ok
