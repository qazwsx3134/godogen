extends SceneTree
## Renders the sprite3d shaders for judging them without a game: a ring of eight placeholder actors, each facing
## outward (so the one nearest the camera faces it, the right one faces screen right...), seen from three camera
## pitches, plus a MultiMesh crowd showing outline roles, a hit flash and a dissolve. Saves one PNG of four panels.
## Each placeholder row shows its row number as a pixel digit (a mirrored row shows the digit flipped) and a nose
## on the side it faces. Renders, so run it on a virtual display, never on the user's desktop:
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path <project> --resolution 480x360 \
##     --rendering-method gl_compatibility -s res://addons/proto_kit/sprite3d_gallery.gd -- /tmp/sprite3d.png
const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const Actor = preload("res://addons/proto_kit/sprite3d_actor.gd")
const PITCHES := [25.0, 35.0, 45.0]
const CELL := 32
const DIGITS := ["111101101101111", "010110010010111", "111001111100111", "111001111001111", "101101111001001"]

var out: String
var camera: Camera3D
var shots: Array[Image] = []
var crowd: MultiMeshInstance3D
var actors: Array[Node3D] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out = args[0] if not args.is_empty() else "user://sprite3d_gallery.png"
	_run.call_deferred()


func _run() -> void:
	var sheet: Resource = _placeholder_sheet()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("8fb3d9")
	root.add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_mat.albedo_color = Color("6f8f4e")
	ground.material_override = ground_mat
	root.add_child(ground)
	for i: int in 8:
		var a := deg_to_rad(i * 45.0)
		var dir := Vector3(sin(a), 0.0, cos(a))  # i = 0 points at the camera (+Z), then clockwise from above
		var actor := _actor(sheet)
		actor.position = dir * 2.2
		actor.facing = dir
		actor.outline = Color(1, 1, 1, 1) if i == 0 else Color(1, 1, 1, 0)
		root.add_child(actor)
		actors.append(actor)
	camera = Camera3D.new()
	camera.fov = 50.0
	root.add_child(camera)
	camera.make_current()
	for pitch: float in PITCHES:
		var p := deg_to_rad(pitch)
		camera.position = Vector3(0.0, sin(p) * 9.0, cos(p) * 9.0)
		camera.look_at(Vector3(0.0, 0.6, 0.0))
		await _shot()
	for actor: Node3D in actors:
		actor.visible = false
	crowd = _crowd(sheet)
	root.add_child(crowd)
	camera.position = Vector3(0.0, sin(deg_to_rad(30.0)) * 7.0, cos(deg_to_rad(30.0)) * 7.0)
	camera.look_at(Vector3(0.0, 0.6, 0.0))
	await _shot()
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var sheet_img := Image.create(w * shots.size(), h, false, Image.FORMAT_RGBA8)
	for i: int in shots.size():
		shots[i].convert(Image.FORMAT_RGBA8)
		sheet_img.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	sheet_img.save_png(out)
	print("sprite3d gallery: ", out)
	quit(0)


func _shot() -> void:
	for i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	shots.append(root.get_texture().get_image())


func _actor(sheet: Resource) -> Node3D:
	var actor: Node3D = Actor.new()
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	var sprite := MeshInstance3D.new()
	sprite.name = "Sprite"
	sprite.mesh = quad
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/proto_kit/sprite3d.gdshader")
	m.set_shader_parameter(&"bob", 0.0)
	sprite.material_override = m
	actor.add_child(sprite)
	var shadow := MeshInstance3D.new()
	shadow.name = "Shadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	shadow.mesh = plane
	var sm := ShaderMaterial.new()
	sm.shader = load("res://addons/proto_kit/sprite3d_shadow.gdshader")
	shadow.material_override = sm
	actor.add_child(shadow)
	actor.sheet = sheet
	actor.anim = &"idle"
	return actor


func _crowd(sheet: Resource) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	mm.mesh = quad
	mm.instance_count = 8
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/proto_kit/sprite3d.gdshader")
	sheet.apply(m)
	m.set_shader_parameter(&"use_instance_custom", true)
	m.set_shader_parameter(&"use_instance_color", true)
	m.set_shader_parameter(&"bob", 0.0)
	var s: float = sheet.size_m()
	# Roles none..ally, then a hit flash, a half dissolve, a poison tint, and a tumble.
	for i: int in 8:
		var basis := Basis.from_scale(Vector3(s, s, s))
		if i == 7:
			basis = Basis(Vector3.BACK, 0.8).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(basis, Vector3((i - 3.5) * 1.0, 0.0, 0.0)))
		var role := i if i <= 4 else 0
		var tint := Color(0.6, 1.0, 0.5) if i == 6 else Color.WHITE
		mm.set_instance_color(i, Sheet.instance_color(tint, role))
		mm.set_instance_custom_data(i, Sheet.instance_custom(sheet.cell(&"idle", 0, 0).x, 1.0 if i == 5 else 0.0, 1, 0.0, 0.5 if i == 6 else 0.0))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = m
	return node


## Five drawn rows (front, front-right, right, back-right, back), one frame each: a body with the row digit and a
## nose on the facing side (front rows: low, back rows: none).
func _placeholder_sheet() -> Resource:
	var img := Image.create(CELL * 1, CELL * 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hues := [0.0, 0.12, 0.33, 0.55, 0.75]
	for row: int in 5:
		var oy := row * CELL
		var body := Color.from_hsv(hues[row], 0.6, 0.9)
		for y: int in range(6, CELL - 2):
			for x: int in range(9, 23):
				img.set_pixel(x, oy + y, body if y > 11 else body.darkened(0.3))
		var digit: String = DIGITS[row]
		for k: int in 15:
			if digit[k] == "1":
				img.set_pixel(14 + k % 3, oy + 16 + k / 3, Color.BLACK)
		var nose_x: int = [15, 22, 23, 22, -1][row]
		if nose_x >= 0:
			for y: int in range(8, 11):
				img.set_pixel(nose_x, oy + y, Color.WHITE)
				img.set_pixel(mini(nose_x + 1, CELL - 2), oy + y, Color.WHITE)
	var sheet: Resource = Sheet.new()
	sheet.atlas = ImageTexture.create_from_image(img)
	sheet.columns = 1
	sheet.rows = 5
	sheet.cell_px = CELL
	sheet.foot_px = 2
	sheet.meters_per_px = 0.05
	sheet.directions = 8
	sheet.mirror = true
	sheet.anims = {"idle": {"cell": 0, "n": 1, "d": [60], "loop": true}}
	return sheet
