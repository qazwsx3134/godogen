extends RefCounted
## A tiny HD-2D diorama made of kit modules only, from placeholder art drawn in code: the reference for how the
## pieces fit, and what tests/test_proto_kit.gd and tools/hd2d_gallery.gd build. A game builds the same tree in its
## own authoring script and saves it as scenes (hero-horde-idle stage.tscn, march_view.tscn are full examples).
##   var demo: Node = Hd2dDemo.build(Vector2(720, 1280))    # add to the tree; demo.step(game_delta) each frame
## Layer stack, back to front: WorldEnvironment (hd2d_look) and the sun -> ground plane -> pixel_card3d props and
## characters (sprite3d for crowds) -> ground_decal marks and pixel_vfx3d rings under the characters -> chunks ->
## the vignette CanvasLayer -> the HUD (here a march_strip along the bottom).

const Hd2dLook = preload("res://addons/proto_kit/hd2d_look.gd")
const M_PER_PX := 0.025


static func build(view: Vector2 = Vector2(720, 1280)) -> Node:
	var root := _Runner.new()
	root.name = "Hd2dDemo"
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)

	var stage := Node3D.new()
	stage.name = "Stage"
	stage.set_script(load("res://addons/proto_kit/hd2d_stage.gd"))
	world.add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Hd2dLook.environment()
	env.camera_attributes = Hd2dLook.camera_attributes()
	_own(stage, env, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_own(stage, sun, "Sun", true)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	ground.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = ImageTexture.create_from_image(_checker())
	floor_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_material.uv1_scale = Vector3(30.0 / (32 * M_PER_PX * 2.0), 30.0 / (32 * M_PER_PX * 2.0), 1.0)
	ground.material_override = floor_material
	_own(stage, ground, "Ground")
	var torches := Node3D.new()
	_own(stage, torches, "FlickerLights", true)
	var torch := OmniLight3D.new()
	torch.light_color = Color(1.0, 0.55, 0.2)
	torch.light_energy = 2.0
	torch.omni_range = 4.0
	torch.position = Vector3(-2.0, 1.2, -1.0)
	torches.add_child(torch)
	torch.owner = stage
	for spec: Array in [[_tree(), Vector3(-3.5, 0, -3.0), false], [_tree(), Vector3(3.0, 0, -4.0), true],
			[_rock(), Vector3(1.5, 0, -1.5), false], [_figure(Color(0.35, 0.55, 0.95)), Vector3(-0.8, 0, 0.5), false],
			[_figure(Color(0.6, 0.85, 0.45)), Vector3(1.8, 0, 0.8), true]]:
		var card := MeshInstance3D.new()
		card.set_script(load("res://addons/proto_kit/pixel_card3d.gd"))
		card.set(&"texture", ImageTexture.create_from_image(spec[0]))
		card.set(&"flip", spec[2])
		card.position = spec[1]
		_own(stage, card, "")

	var mark := MeshInstance3D.new()
	mark.name = "Warning"
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	mark.mesh = quad
	var decal := ShaderMaterial.new()
	decal.shader = load("res://addons/proto_kit/ground_decal.gdshader")
	mark.material_override = decal
	mark.position = Vector3(1.8, 0.03, 0.8)
	mark.scale = Vector3(2.4, 1.0, 2.4)
	mark.set_instance_shader_parameter(&"fill", 0.6)
	mark.set_instance_shader_parameter(&"inner_alpha", 0.1)
	mark.set_instance_shader_parameter(&"texels", Vector2(48.0, 48.0))
	world.add_child(mark)

	world.add_child(_fx())
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.set_script(load("res://addons/proto_kit/shot_camera.gd"))
	camera.fov = 40.0
	camera.position = Vector3(0.0, 9.0, 10.0)
	camera.rotation_degrees = Vector3(-42.0, 0.0, 0.0)
	world.add_child(camera)

	var shade := CanvasLayer.new()
	shade.name = "Vignette"
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = Hd2dLook.vignette_material()
	shade.add_child(rect)
	root.add_child(shade)
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.layer = 2
	var strip := _strip(Vector2(view.x, 260.0))
	strip.position = Vector2(0.0, view.y - 280.0)
	hud.add_child(strip)
	root.add_child(hud)
	return root


## Steps the demo on game time and pops an effect now and then.
class _Runner extends Node:
	var t: float = 0.0
	var _next: float = 0.3

	func _ready() -> void:
		get_node(^"Hud/MarchStrip").set_process(false)

	func step(dt: float) -> void:
		t += dt
		var stage: Node = get_node(^"World/Stage")
		stage.step_lights(dt)
		var fx: Node = get_node(^"World/Fx")
		if t >= _next:
			_next += 1.2
			fx.ring(Vector3(1.8, 0.0, 0.8), 1.6, &"slam", 0.5)
			fx.burst(Vector3(1.8, 0.2, 0.8), 24, &"rock", 3.0, 3.0, 4)
		fx.step(dt)
		get_node(^"Hud/MarchStrip").step(dt)


static func _fx() -> Node3D:
	var fx := Node3D.new()
	fx.name = "Fx"
	fx.set_script(load("res://addons/proto_kit/pixel_vfx3d.gd"))
	var chunks := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var chunk_material := StandardMaterial3D.new()
	chunk_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chunk_material.vertex_color_use_as_albedo = true
	box.material = chunk_material
	mm.mesh = box
	chunks.multimesh = mm
	_own(fx, chunks, "Chunks", true)
	var rings := Node3D.new()
	_own(fx, rings, "Rings", true)
	var ring_material := ShaderMaterial.new()
	ring_material.shader = load("res://addons/proto_kit/pixel_vfx3d_ring.gdshader")
	for k: int in 4:
		var ring := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		ring.mesh = plane
		ring.material_override = ring_material
		ring.visible = false
		rings.add_child(ring)
		ring.owner = fx
	return fx


static func _strip(size: Vector2) -> Control:
	var strip := Control.new()
	strip.name = "MarchStrip"
	strip.set_script(load("res://addons/proto_kit/march_strip.gd"))
	strip.size = size
	strip.clip_contents = true
	for key: String in ["Far", "Ground"]:
		var layer := TextureRect.new()
		layer.texture = ImageTexture.create_from_image(_hills() if key == "Far" else _checker())
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var m := ShaderMaterial.new()
		m.shader = load("res://addons/proto_kit/parallax_layer.gdshader")
		m.set_shader_parameter(&"tex", layer.texture)
		m.set_shader_parameter(&"mirror", key == "Far")
		if key == "Ground":
			m.set_shader_parameter(&"tiles", Vector2(size.x / 64.0, 1.0))
		layer.material = m
		layer.position = Vector2(0.0, 0.0 if key == "Far" else size.y - 64.0)
		layer.size = Vector2(size.x, size.y - 64.0 if key == "Far" else 64.0)
		_own(strip, layer, key, true)
	var props := Control.new()
	_own(strip, props, "Props", true)
	var tree := TextureRect.new()
	tree.texture = ImageTexture.create_from_image(_tree())
	tree.size = Vector2(64.0, 96.0)
	tree.position = Vector2(size.x * 0.6, size.y - 150.0)
	props.add_child(tree)
	tree.owner = strip
	var heroes := Control.new()
	_own(strip, heroes, "Heroes", true)
	for k: int in 3:
		var hero := TextureRect.new()
		hero.texture = ImageTexture.create_from_image(_figure(Color(0.35 + 0.2 * k, 0.55, 0.95 - 0.2 * k)))
		hero.size = Vector2(48.0, 64.0)
		hero.position = Vector2(40.0 + k * 52.0, size.y - 124.0)
		heroes.add_child(hero)
		hero.owner = strip
	var enemy := TextureRect.new()
	enemy.texture = ImageTexture.create_from_image(_figure(Color(0.6, 0.85, 0.45)))
	enemy.size = Vector2(56.0, 72.0)
	enemy.position = Vector2(size.x, size.y - 132.0)
	_own(strip, enemy, "Enemy", true)
	var bar := ProgressBar.new()
	bar.size = Vector2(40.0, 8.0)
	bar.show_percentage = false
	_own(strip, bar, "EnemyHp", true)
	var popups := Control.new()
	_own(strip, popups, "Popups", true)
	for k: int in 4:
		var label := Label.new()
		popups.add_child(label)
		label.owner = strip
	return strip


## Adds `child` to `parent`, owned by `parent` (so %Name lookups from `parent` find it).
static func _own(parent: Node, child: Node, node_name: String, unique: bool = false) -> void:
	if not node_name.is_empty():
		child.name = node_name
	parent.add_child(child, true)
	child.owner = parent
	child.unique_name_in_owner = unique


static func _checker() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y: int in 32:
		for x: int in 32:
			var light: bool = (x / 8 + y / 8) % 2 == 0
			img.set_pixel(x, y, Color(0.36, 0.5, 0.3) if light else Color(0.3, 0.44, 0.26))
	return img


static func _hills() -> Image:
	var img := Image.create(96, 48, false, Image.FORMAT_RGBA8)
	for y: int in 48:
		for x: int in 96:
			var ridge: float = 26.0 + 8.0 * sin(x / 96.0 * TAU) + 4.0 * sin(x / 96.0 * TAU * 3.0)
			img.set_pixel(x, y, Color(0.5, 0.55, 0.75).lerp(Color(0.95, 0.75, 0.6), y / 48.0) if y < ridge
				else Color(0.32, 0.38, 0.5))
	return img


static func _tree() -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	for y: int in 48:
		for x: int in 32:
			var crown: bool = y < 34 and absi(x - 16) <= (y + 2) * 14 / 34
			var trunk: bool = y >= 34 and absi(x - 16) <= 2
			if crown:
				img.set_pixel(x, y, Color(0.2, 0.42, 0.24) if (x + y) % 5 else Color(0.32, 0.56, 0.3))
			elif trunk:
				img.set_pixel(x, y, Color(0.36, 0.24, 0.16))
	return img


static func _rock() -> Image:
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	for y: int in 16:
		for x: int in 24:
			if Vector2((x - 12) / 12.0, (y - 16) / 15.0).length() < 1.0:
				img.set_pixel(x, y, Color(0.55, 0.53, 0.5) if y > 6 else Color(0.7, 0.68, 0.64))
	return img


static func _figure(body: Color) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	for y: int in 24:
		for x: int in 16:
			var head: bool = Vector2(x - 8, y - 5).length() < 4.0
			var torso: bool = y >= 9 and y < 20 and absi(x - 8) <= 4
			var legs: bool = y >= 20 and (absi(x - 6) <= 1 or absi(x - 10) <= 1)
			if head:
				img.set_pixel(x, y, Color(0.96, 0.82, 0.68))
			elif torso:
				img.set_pixel(x, y, body)
			elif legs:
				img.set_pixel(x, y, body.darkened(0.4))
	return img
