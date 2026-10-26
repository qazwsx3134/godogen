extends SceneTree
## Authoring tool, never run on launch/import. Inspect the diff before --replace.
## godot --headless --path . --script res://tools/import_polish_art.gd -- --activate [--replace] [--new-walk]
## Imports whichever complete asset sets exist; missing sets are reported and retained as existing art.
const ART := "res://assets/art/polish-v2/"
const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
var replace: bool = false


func _initialize() -> void:
	replace = "--replace" in OS.get_cmdline_user_args()
	var boss := false
	var oak := false
	if FileAccess.file_exists(ART + "gatekeeper.png"):
		boss = _boss()
	if FileAccess.file_exists(ART + "oak.png"):
		oak = _oak()
	var poses := ["captain-walk-a-corrected" if "--new-walk" in OS.get_cmdline_user_args() else "captain-walk-a", "captain-walk-b", "captain-attack-anticipation", "captain-attack-impact"]
	var complete := true
	for name: String in poses:
		complete = complete and FileAccess.file_exists(ART + name + ".png")
	if complete:
		_captain(poses)
	else:
		print("Captain: keep current atlas until all four poses exist")
	if "--activate" in OS.get_cmdline_user_args():
		_activate(boss, oak)
	quit()


func _image(name: String) -> Image:
	var image := Image.load_from_file(ART + name + ".png")
	assert(image != null and not image.is_empty(), "Image must load: " + name)
	return image


## Ignore sub-visible alpha specks when locating feet and packing; originals remain untouched.
func _solid_bounds(image: Image) -> Rect2i:
	var min_at := Vector2i(image.get_width(), image.get_height())
	var max_at := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				min_at = min_at.min(Vector2i(x, y))
				max_at = max_at.max(Vector2i(x, y))
	assert(max_at.x >= 0, "No solid pixels")
	return Rect2i(min_at, max_at - min_at + Vector2i.ONE)


func _pack_single(image: Image, cell: int) -> Image:
	var source := image.get_region(_solid_bounds(image))
	var scale := minf(float(cell - 32) / source.get_width(), float(cell - 32) / source.get_height())
	source.resize(roundi(source.get_width() * scale), roundi(source.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	var atlas := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i((cell - source.get_width()) / 2, cell - 16 - source.get_height()))
	return atlas


func _texture(image: Image, name: String) -> Texture2D:
	DirAccess.make_dir_recursive_absolute("res://resources/textures")
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var path := "res://resources/textures/%s_illustrated.res" % name
	assert(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) == OK)
	return load(path)


func _boss() -> bool:
	var output := "res://scenes/actors/gatekeeper_illustrated.tscn"
	if FileAccess.file_exists(output) and not replace:
		print("Keep authored ", output)
		return true
	var image := _image("gatekeeper")
	assert(image.get_width() == image.get_height(), "Boss input must be square")
	var box := _solid_bounds(image)
	assert(box.has_area() and box.size.y < image.get_height(), "Boss needs transparent margins")
	var sheet := Sheet.new()
	var normalized := _pack_single(image, 1024)
	sheet.atlas = _texture(normalized, "gatekeeper")
	image = normalized
	box = _solid_bounds(image)
	sheet.columns = 1
	sheet.rows = 1
	sheet.cell_px = image.get_width()
	sheet.foot_px = image.get_height() - (box.end.y - 1)
	sheet.meters_per_px = 3.4 / float(box.size.y)
	sheet.directions = 1
	for name: String in ["idle", "walk", "attack", "skill", "down"]:
		sheet.anims[name] = {"cell": 0, "n": 1, "d": [30], "loop": name in ["idle", "walk"]}
	assert(ResourceSaver.save(sheet, "res://resources/sheets/gatekeeper.tres") == OK)
	sheet.take_over_path("res://resources/sheets/gatekeeper.tres")
	var actor := (load("res://scenes/actors/actor.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	actor.set_script(load("res://game/illustrated_boss.gd"))
	actor.name = "Gatekeeper"
	actor.kind_id = "gatekeeper"
	actor.sheet = sheet
	actor.head_height = 3.6
	actor.nameplate_color = Color("efcf99")
	actor.get_node("Visual").sheet = sheet
	# Saved editor representation, independent of running _ready().
	var sprite: MeshInstance3D = actor.get_node("Visual/Sprite")
	var material: ShaderMaterial = sprite.material_override.duplicate()
	material.set_shader_parameter("atlas", sheet.atlas)
	material.set_shader_parameter("frames", Vector2.ONE)
	material.set_shader_parameter("foot_gutter", float(sheet.foot_px) / sheet.cell_px)
	sprite.material_override = material
	sprite.scale = Vector3.ONE * sheet.cell_px * sheet.meters_per_px
	actor.get_node("Visual/Shadow").scale = Vector3.ONE * 3.0
	actor.get_node("Nameplate").position.y = 3.92
	actor.get_node("HpBar").position.y = 3.68
	_save_scene(actor, output)
	actor.free()
	return true


func _oak() -> bool:
	var output := "res://scenes/props/oak_illustrated.tscn"
	if FileAccess.file_exists(output) and not replace:
		print("Keep authored ", output)
		return true
	var image := _image("oak")
	assert(image.get_width() == image.get_height(), "Oak input must be square")
	var box := _solid_bounds(image)
	assert(box.has_area() and box.size.y < image.get_height(), "Oak needs transparent margins")
	var normalized := _pack_single(image, 1024)
	image = normalized
	box = _solid_bounds(image)
	var texture := _texture(image, "oak")
	var prop := Node3D.new()
	prop.name = "Oak"
	prop.set_script(load("res://game/illustrated_prop.gd"))
	prop.block_radius = 0.5
	var sprite := MeshInstance3D.new()
	sprite.name = "Illustration"
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0, 0.5, 0)
	sprite.mesh = quad
	sprite.scale = Vector3.ONE * (4.2 * image.get_height() / float(box.size.y))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sprite3d_hd.gdshader")
	material.set_shader_parameter("atlas", texture)
	material.set_shader_parameter("frames", Vector2.ONE)
	material.set_shader_parameter("foot_gutter", float(image.get_height() - (box.end.y - 1)) / image.get_height())
	material.set_shader_parameter("bob", 0.0)
	material.set_shader_parameter("hit_squash", 0.0)
	material.set_shader_parameter("see_through_enabled", true)
	material.set_shader_parameter("see_through", 0.8)
	sprite.material_override = material
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.add_child(sprite)
	sprite.owner = prop
	_save_scene(prop, output)
	prop.free()
	return true


func _captain(poses: Array) -> void:
	var output := "res://assets/sprites/captain-v2.png"
	if FileAccess.file_exists(output) and not replace:
		print("Keep authored ", output)
		return
	var old := Image.load_from_file("res://assets/sprites/captain.png")
	var master := Image.load_from_file("res://art_src/chars/captain/master/master_rgba.png")
	assert(old != null and master != null)
	var idle := old.get_region(Rect2i(0, 0, 512, 512))
	var scale_master := float(idle.get_used_rect().size.y) / master.get_used_rect().size.y
	# Wider cells preserve body scale when a sword extends sideways (7 * 576 = 4032 px).
	const CELL := 576
	var atlas := Image.create(CELL * 7, CELL, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(idle, Rect2i(0, 0, 512, 512), Vector2i(32, 64))
	atlas.blit_rect(old, Rect2i(512 * 4, 0, 512, 512), Vector2i(CELL * 5 + 32, 64))
	atlas.blit_rect(old, Rect2i(512 * 5, 0, 512, 512), Vector2i(CELL * 6 + 32, 64))
	for i in poses.size():
		if i < 2 and "--new-walk" not in OS.get_cmdline_user_args():
			atlas.blit_rect(old, Rect2i(512 * (i + 1), 0, 512, 512), Vector2i(CELL * (i + 1) + 32, 64))
			continue
		var image := _image(poses[i])
		var factor := scale_master * master.get_width() / image.get_width()
		var frame := image.get_region(_solid_bounds(image))
		var size := Vector2i(roundi(frame.get_width() * factor), roundi(frame.get_height() * factor))
		assert(size.x <= CELL - 4 and size.y <= CELL - 10, "Pose exceeds cell; review scale/pose instead of shrinking silently")
		frame.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(frame, Rect2i(Vector2i.ZERO, size), Vector2i((i + 1) * CELL + (CELL - size.x) / 2, CELL - 8 - size.y))
	assert(atlas.save_png(output) == OK)
	print("Captain atlas saved; reimport before activating its sheet")


func _save_scene(node: Node, path: String) -> void:
	var count := node.find_children("*", "", true, false).size()
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene, path) == OK)
	var back := (ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	assert(back.find_children("*", "", true, false).size() == count, "Packed scene lost nodes")
	back.free()
	print("Saved ", path)


func _activate(boss: bool, oak: bool) -> void:
	var field := (load("res://scenes/field.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var replacements := {}
	if boss: replacements["res://scenes/actors/gatekeeper.tscn"] = "res://scenes/actors/gatekeeper_illustrated.tscn"
	if oak: replacements["res://scenes/props/oak.tscn"] = "res://scenes/props/oak_illustrated.tscn"
	for group_name: String in ["Monsters", "Props"]:
		var group := field.get_node(group_name)
		for old: Node3D in group.get_children():
			if not replacements.has(old.scene_file_path): continue
			var next: Node3D = (load(replacements[old.scene_file_path]) as PackedScene).instantiate()
			next.name = old.name
			next.transform = old.transform
			if group_name == "Props": next.block_radius = old.block_radius
			var index := old.get_index()
			group.remove_child(old)
			group.add_child(next)
			group.move_child(next, index)
			next.owner = field
			old.free()
	if boss:
		for actor: Node in field.get_node("Monsters").get_children():
			if actor.kind_id == "gatekeeper":
				actor.sheet = load("res://resources/sheets/gatekeeper.tres")
	if FileAccess.file_exists(ART + "ground.png"):
		var material := field.get_node("Ground").material_override as ShaderMaterial
		material.set_shader_parameter("painted_grass", load(ART + "ground.png"))
		material.set_shader_parameter("painted_grass_mix", 0.7)
	if FileAccess.file_exists("res://assets/sprites/captain-v2.png.import"):
		var sheet: Resource = load("res://resources/sheets/leader.tres").duplicate(true)
		sheet.atlas = load("res://assets/sprites/captain-v2.png")
		sheet.columns = 7
		sheet.cell_px = 576
		sheet.anims.attack = {"cell": 4, "n": 1, "d": [20], "loop": false}
		sheet.anims.anticipation = {"cell": 3, "n": 1, "d": [60], "loop": true}
		sheet.anims.down.cell = 5
		sheet.anims.skill = {"cell": 4, "n": 1, "d": [15], "loop": false}
		assert(ResourceSaver.save(sheet, "res://resources/sheets/leader_polish.tres") == OK)
		sheet.take_over_path("res://resources/sheets/leader_polish.tres")
		field.get_node("Party/Leader").sheet = sheet
	_save_scene(field, "res://scenes/field.tscn")
	field.free()
