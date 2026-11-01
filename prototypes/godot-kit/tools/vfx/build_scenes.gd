extends SceneTree
## One-time authoring tool. Saved scenes are maintained in the editor afterwards.
## Existing outputs are preserved. Never called by import, tests, or runtime.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const Frames = preload("res://addons/proto_kit/vfx/sheet_frames.gd")
const BASE := "res://addons/proto_kit/vfx/"
var good: bool = true

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	# An original, procedural ring calibration strip, not downloaded website art.
	var sheet_path := BASE + "demo_ring.tres"
	if not FileAccess.file_exists(sheet_path):
		var image := Image.create(32 * 12, 32, false, Image.FORMAT_RGBA8)
		for f: int in 12:
			var radius: float = 2.0 + float(f) * 1.05
			for y: int in 32:
				for x: int in 32:
					var distance: float = Vector2(x - 15.5, y - 15.5).length()
					if absf(distance - radius) < 1.3:
						image.set_pixel(f * 32 + x, y, Color(0.3, 0.85, 1.0, 1.0 - float(f) / 14.0))
		var texture := PortableCompressedTexture2D.new()
		texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		var frames := Frames.build(texture, 12, 16.0, true)
		good = ResourceSaver.save(frames, sheet_path) == OK and good
	var demo := load(sheet_path) as SpriteFrames
	var sprite := AnimatedSprite2D.new()
	sprite.name = "SheetEffect2D"
	sprite.set_script(load(BASE + "2d/sheet_effect.gd"))
	sprite.sprite_frames = demo
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_save(sprite, "2d/sheet_effect.tscn")
	var sprite3 := AnimatedSprite3D.new()
	sprite3.name = "SheetEffect3D"
	sprite3.set_script(load(BASE + "3d/sheet_effect.gd"))
	sprite3.sprite_frames = demo
	sprite3.pixel_size = 0.04
	sprite3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite3.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite3.shaded = false
	_save(sprite3, "3d/sheet_effect.tscn")
	var native2 := Node2D.new()
	native2.name = "PixelEffects2D"
	native2.set_script(load("res://addons/proto_kit/pixel_vfx.gd"))
	_save(native2, "2d/pixel_effects.tscn")
	_build_native3()
	_build_preview2()
	_build_preview3()
	quit(0 if good else 1)

func _build_native3() -> void:
	var fx := Node3D.new()
	fx.name = "PixelBurst3D"
	fx.set_script(load(BASE + "3d/pixel_burst.gd"))
	var chunks := MultiMeshInstance3D.new()
	chunks.multimesh = MultiMesh.new()
	chunks.multimesh.resource_local_to_scene = true
	chunks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	chunks.multimesh.use_colors = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	cube.material = material
	chunks.multimesh.mesh = cube
	_add(fx, chunks, "Chunks", true)
	var rings := _add(fx, Node3D.new(), "Rings", true)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = load("res://addons/proto_kit/pixel_vfx3d_ring.gdshader")
	for index: int in 12:
		var ring := MeshInstance3D.new()
		ring.mesh = PlaneMesh.new()
		ring.mesh.size = Vector2.ONE
		ring.material_override = ring_material
		ring.visible = index == 0
		ring.set_instance_shader_parameter("progress", 0.3)
		_add(rings, ring, "Ring%d" % index)
	_save(fx, "3d/pixel_burst.tscn")

func _build_preview2() -> void:
	var stage := Node2D.new()
	stage.name = "VfxPreview2D"
	stage.set_script(load(BASE + "preview_2d.gd"))
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2(0, 0), Vector2(900, 0), Vector2(900, 500), Vector2(0, 500)])
	background.color = Color(0.05, 0.07, 0.12)
	_add(stage, background, "Background")
	var fx := B.instance(BASE + "2d/pixel_effects.tscn") as Node2D
	fx.position = Vector2(180, 240)
	_add(stage, fx, "NativeEffects", true)
	var sheet := B.instance(BASE + "2d/sheet_effect.tscn") as AnimatedSprite2D
	sheet.position = Vector2(600, 240)
	sheet.scale = Vector2(4, 4)
	_add(stage, sheet, "Sheet")
	for item: Array in [["Native: burst / ring / explosion", Vector2(40, 55)], ["Sheet: replace SpriteFrames", Vector2(480, 55)]]:
		var label := Label.new()
		label.text = item[0]
		label.position = item[1]
		_add(stage, label, "Caption")
	_timer(stage)
	_save(stage, "preview_2d.tscn", [BASE + "2d/pixel_effects.tscn", BASE + "2d/sheet_effect.tscn"])

func _build_preview3() -> void:
	var stage := Node3D.new()
	stage.name = "VfxPreview3D"
	stage.set_script(load(BASE + "preview_3d.gd"))
	var camera := Camera3D.new()
	camera.position = Vector3(0, 5, 8)
	camera.rotation_degrees.x = -30
	camera.current = true
	_add(stage, camera, "Camera")
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 10)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.06, 0.08, 0.13)
	plane.material = material
	floor_mesh.mesh = plane
	_add(stage, floor_mesh, "Ground")
	_add(stage, B.instance(BASE + "3d/pixel_burst.tscn"), "NativeEffects", true)
	var sheet := B.instance(BASE + "3d/sheet_effect.tscn") as AnimatedSprite3D
	sheet.position = Vector3(2, 1, 0)
	_add(stage, sheet, "BillboardSheet")
	_timer(stage)
	_save(stage, "preview_3d.tscn", [BASE + "3d/pixel_burst.tscn", BASE + "3d/sheet_effect.tscn"])

func _timer(stage: Node) -> void:
	var timer := Timer.new()
	timer.wait_time = 1.8
	timer.autostart = true
	_add(stage, timer, "Replay", true)

func _add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	if unique:
		B.unique(child)
	return B.add(parent, child, node_name)

func _save(node: Node, relative: String, refs: Array = []) -> void:
	var result := B.save_scene(node, BASE + relative, {"expected_refs": refs})
	good = result.ok and good
