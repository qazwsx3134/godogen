extends SceneTree
## Authoring tool: builds seal-meadow's materials, terrain mesh, foliage, props, player, monsters, HUD,
## the meadow map and main.tscn. Run only while authoring:
##   xvfb-run godot --path . --script res://tools/build_world.gd            (skips files that exist)
##   xvfb-run godot --path . --script res://tools/build_world.gd -- --overwrite   (check git diff first)
## Not --headless: its dummy renderer drops MultiMesh transforms, so every grass tuft would sit at the origin.
## Once the scenes are hand-edited in the editor, do not overwrite them.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const TerrainHeight = preload("res://scripts/terrain_height.gd")

const PALETTE := {
	"bark": Color("7a5232"), "pine": Color("2f7d4a"), "pine_light": Color("3f9a5a"),
	"leaf": Color("4fae55"), "leaf_light": Color("7fcf6a"), "stone": Color("a49fb6"),
	"stone_dark": Color("8f8ba3"), "wood": Color("a8794a"), "wood_dark": Color("7d5634"),
	"sign": Color("ecd6a4"),
}
## Placeholder sprites borrowed from skybound-blades until this game's own art exists.
const MONSTERS := {
	"slime": {"name": "蓬蓬果凍", "sheet": "meadow_slime", "level": 1, "hp": 32, "damage": 3, "speed": 2.2,
		"aggressive": false, "xp": 8, "head": 1.0},
	"boar": {"name": "刺莓野豬", "sheet": "briar_boar", "level": 4, "hp": 70, "damage": 7, "speed": 2.6,
		"aggressive": false, "xp": 18, "head": 1.35},
	"hound": {"name": "遺跡獵犬", "sheet": "ruin_hound", "level": 6, "hp": 95, "damage": 10, "speed": 3.2,
		"aggressive": true, "xp": 30, "head": 1.3},
}

var overwrite: bool = false
var mats: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	overwrite = OS.get_cmdline_user_args().has("--overwrite")
	rng.seed = 20261026
	_make_materials()
	var ok := true
	for step: Callable in [_build_props, _build_actors, _build_hud, _build_meadow, _build_main]:
		ok = step.call() and ok
	quit(0 if ok else 1)


# --- helpers -------------------------------------------------------------------------------------

func _save(root: Node, path: String, refs: Array = []) -> bool:
	return SceneBuilder.save_scene(root, path, {"overwrite": overwrite, "expected_refs": refs}).ok


func _save_res(res: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and not overwrite:
		return load(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		push_error("cannot save %s: %s" % [path, error_string(err)])
	return res


func _part(parent: Node, n: String, mesh: Mesh, mat: String, pos := Vector3.ZERO, scl := Vector3.ONE,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mats[mat]
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	return SceneBuilder.add(parent, mi, n)


func _sphere(r: float, seg: int = 7, rings: int = 5) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


func _cyl(top: float, bottom: float, h: float, seg: int = 7) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


func _height_at(x: float, z: float) -> float:
	return TerrainHeight.height(x, z)


# --- materials -----------------------------------------------------------------------------------

func _make_materials() -> void:
	var lowpoly: Shader = load("res://shaders/lowpoly.gdshader")
	for key: String in PALETTE:
		var m := ShaderMaterial.new()
		m.shader = lowpoly
		m.set_shader_parameter(&"albedo", PALETTE[key])
		mats[key] = _save_res(m, "res://materials/%s.tres" % key)
	var terrain := ShaderMaterial.new()
	terrain.shader = lowpoly
	terrain.set_shader_parameter(&"use_vertex_color", true)
	terrain.set_shader_parameter(&"rim_strength", 0.0)
	mats["terrain"] = _save_res(terrain, "res://materials/terrain.tres")
	var foliage := ShaderMaterial.new()
	foliage.shader = load("res://shaders/foliage.gdshader")
	mats["foliage"] = _save_res(foliage, "res://materials/foliage.tres")
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.36, 0.66, 0.92, 0.72)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic_specular = 0.8
	mats["water"] = _save_res(water, "res://materials/water.tres")
	var marker := StandardMaterial3D.new()
	marker.albedo_color = Color("aaf27a")
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats["marker"] = _save_res(marker, "res://materials/click_marker.tres")


# --- props ---------------------------------------------------------------------------------------

func _prop(n: String, block_radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = n
	root.set_meta(&"block_radius", block_radius)
	return root


func _build_props() -> bool:
	var ok := true
	var pine := _prop("Pine", 0.6)
	_part(pine, "Trunk", _cyl(0.16, 0.24, 1.2, 6), "bark", Vector3(0, 0.6, 0))
	_part(pine, "Low", _cyl(0.0, 1.35, 1.7), "pine", Vector3(0, 1.75, 0))
	_part(pine, "Mid", _cyl(0.0, 1.05, 1.45), "pine_light", Vector3(0, 2.6, 0))
	_part(pine, "Top", _cyl(0.0, 0.7, 1.2), "pine", Vector3(0, 3.4, 0))
	ok = _save(pine, "res://scenes/props/pine.tscn") and ok

	var oak := _prop("Oak", 0.7)
	_part(oak, "Trunk", _cyl(0.2, 0.3, 1.7, 6), "bark", Vector3(0, 0.85, 0))
	_part(oak, "Crown", _sphere(1.15), "leaf", Vector3(0, 2.4, 0))
	_part(oak, "CrownRight", _sphere(0.8), "leaf_light", Vector3(0.75, 2.05, 0.2))
	_part(oak, "CrownLeft", _sphere(0.85), "leaf_light", Vector3(-0.65, 2.1, -0.3))
	_part(oak, "CrownTop", _sphere(0.75), "leaf", Vector3(0, 3.1, 0.1))
	ok = _save(oak, "res://scenes/props/oak.tscn") and ok

	var rock := _prop("Rock", 0.9)
	_part(rock, "Big", _sphere(0.8, 6, 4), "stone", Vector3(0, 0.35, 0), Vector3(1.25, 0.75, 1.0))
	_part(rock, "Small", _sphere(0.45, 5, 3), "stone_dark", Vector3(0.85, 0.2, 0.3))
	ok = _save(rock, "res://scenes/props/rock.tscn") and ok

	var bush := _prop("Bush", 0.0)
	_part(bush, "Middle", _sphere(0.55, 7, 4), "leaf_light", Vector3(0, 0.35, 0))
	_part(bush, "Right", _sphere(0.45, 7, 4), "leaf", Vector3(0.45, 0.3, 0.2))
	_part(bush, "Left", _sphere(0.42, 7, 4), "leaf", Vector3(-0.4, 0.28, -0.1))
	ok = _save(bush, "res://scenes/props/bush.tscn") and ok

	var sign := _prop("Signpost", 0.35)
	_part(sign, "Post", _box(0.14, 1.7, 0.14), "wood", Vector3(0, 0.85, 0))
	_part(sign, "Board", _box(1.4, 0.48, 0.08), "sign", Vector3(0, 1.38, 0))
	_part(sign, "TrimTop", _box(1.48, 0.07, 0.11), "wood_dark", Vector3(0, 1.64, 0))
	_part(sign, "TrimBottom", _box(1.48, 0.07, 0.11), "wood_dark", Vector3(0, 1.12, 0))
	var label := Label3D.new()
	label.text = "蓬蓬草原"
	label.font_size = 52
	label.pixel_size = 0.006
	label.modulate = Color("5a3a1e")
	label.outline_size = 0
	label.position = Vector3(0, 1.38, 0.05)
	SceneBuilder.add(sign, label, "Title")
	ok = _save(sign, "res://scenes/props/signpost.tscn") and ok
	return ok


# --- terrain and foliage -------------------------------------------------------------------------

func _terrain_mesh() -> ArrayMesh:
	var cells := 84
	var half := TerrainHeight.HALF
	var step := half * 2.0 / cells
	var tint := FastNoiseLite.new()
	tint.seed = 99
	tint.frequency = 0.05
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in cells:
		for j in cells:
			var x0 := -half + i * step
			var z0 := -half + j * step
			var p: Array[Vector3] = []
			for corner: Vector2 in [Vector2(x0, z0), Vector2(x0 + step, z0), Vector2(x0, z0 + step),
					Vector2(x0 + step, z0 + step)]:
				p.append(Vector3(corner.x, _height_at(corner.x, corner.y), corner.y))
			for tri: Array in [[p[0], p[1], p[3]], [p[0], p[3], p[2]]]:
				var c: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
				var color := _ground_color(c, tint)
				for v: Vector3 in tri:
					st.set_color(color)
					st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _ground_color(c: Vector3, tint: FastNoiseLite) -> Color:
	var n := tint.get_noise_2d(c.x, c.z) * 0.5 + 0.5
	var color := Color("62a548").lerp(Color("8cc263"), n)
	var r := Vector2(c.x, c.z).length()
	color = color.lerp(Color("3f8a3a"), smoothstep(46.0, 66.0, r) * 0.7)
	if tint.get_noise_2d(c.x * 1.7 + 40.0, c.z * 1.7) > 0.42 and r < 44.0:
		color = Color("c2a26a").lerp(color, 0.25)
	if Vector2(c.x, c.z).distance_to(TerrainHeight.POND) < 8.5:
		color = Color("d1bb84")
	var jitter := rng.randf_range(-0.035, 0.035)
	return Color(color.r + jitter, color.g + jitter, color.b + jitter)


func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 5:
		var a := b * TAU / 5.0 + rng.randf_range(-0.3, 0.3)
		var side := Vector3(cos(a), 0, sin(a))
		var base := side * 0.05
		var across := Vector3(-side.z, 0, side.x) * 0.045
		var tip := base + side * rng.randf_range(0.06, 0.16) + Vector3.UP * rng.randf_range(0.28, 0.46)
		for v: Vector3 in [base - across, base + across, tip]:
			st.set_color(Color("8fd05a") if v == tip else Color("2e6e2a"))
			st.add_vertex(v)
	return st.commit()


func _flower_mesh(petal: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0, 0.32, 0)
	for v: Vector3 in [Vector3(-0.02, 0, 0), Vector3(0.02, 0, 0), top]:
		st.set_color(Color("4c9a3c"))
		st.add_vertex(v)
	for k in 6:
		var a0 := k * TAU / 6.0
		var a1 := (k + 1) * TAU / 6.0
		for v: Vector3 in [top, top + Vector3(cos(a0), 0.25, sin(a0)) * 0.1, top + Vector3(cos(a1), 0.25, sin(a1)) * 0.1]:
			st.set_color(Color("ffe27a") if v == top else petal)
			st.add_vertex(v)
	return st.commit()


func _scatter(mesh: Mesh, count: int, max_radius: float, scale_min: float, scale_max: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var placed: Array[Transform3D] = []
	while placed.size() < count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * max_radius
		var x := cos(a) * r
		var z := sin(a) * r
		if Vector2(x, z).distance_to(TerrainHeight.POND) < 7.5:
			continue
		var s := rng.randf_range(scale_min, scale_max)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		placed.append(Transform3D(basis, Vector3(x, _height_at(x, z), z)))
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, placed[i])
	return mm


func _foliage(parent: Node, n: String, mm: MultiMesh) -> void:
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mats["foliage"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(parent, node, n)


# --- actors --------------------------------------------------------------------------------------

func _actor(sheet: String, display: String, head: float, dissolve: bool) -> Node:
	var actor := SceneBuilder.instance("res://scenes/actors/actor.tscn")
	actor.set("sheet", load("res://resources/sheets/%s.tres" % sheet))
	actor.set("display_name", display)
	actor.set("head_height", head)
	actor.set("dissolve_on_down", dissolve)
	return actor


func _build_actors() -> bool:
	var ok := true
	var player := Node3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))
	# Paper doll rendered from Blender (tools/blender/): body sheet plus hair and weapon layers.
	var actor := _actor("test_chibi_body", "你", 1.8, false)
	actor.set("nameplate_color", Color("9fe0ff"))
	var layers: Array[Resource] = [load("res://resources/sheets/test_chibi_hair.tres"),
		load("res://resources/sheets/test_chibi_weapon.tres")]
	actor.set("layer_sheets", layers)
	SceneBuilder.add(player, actor, "Actor")
	ok = _save(player, "res://scenes/player.tscn", ["res://scenes/actors/actor.tscn"]) and ok
	for kind: String in MONSTERS:
		var d: Dictionary = MONSTERS[kind]
		var m := Node3D.new()
		m.name = kind.capitalize()
		m.set_script(load("res://scripts/monster.gd"))
		m.set("display_name", d.name)
		m.set("level", d.level)
		m.set("max_hp", d.hp)
		m.set("damage", d.damage)
		m.set("move_speed", d.speed)
		m.set("aggressive", d.aggressive)
		m.set("xp_reward", d.xp)
		SceneBuilder.add(m, _actor(d.sheet, d.name, d.head, true), "Actor")
		ok = _save(m, "res://scenes/monsters/%s.tscn" % kind, ["res://scenes/actors/actor.tscn"]) and ok
	return ok


# --- HUD -----------------------------------------------------------------------------------------

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.26, 0.82)
	sb.border_color = Color("e8c25a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	return sb


func _bar(n: String, fill: Color, height: float, text_name: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = n
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(4)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(4)
	bar.add_theme_stylebox_override(&"background", back)
	bar.add_theme_stylebox_override(&"fill", front)
	bar.value = 100
	SceneBuilder.unique(bar)
	if text_name != "":
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override(&"font_size", 12)
		label.add_theme_constant_override(&"outline_size", 4)
		label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
		SceneBuilder.add(bar, SceneBuilder.unique(label), text_name)
	return bar


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_hud() -> bool:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansTC.ttf")
	theme.default_font_size = 16
	theme.set_stylebox(&"panel", &"PanelContainer", _panel_style())
	theme.set_color(&"font_color", &"Label", Color("f4ead2"))
	theme = _save_res(theme, "res://ui/theme.tres") as Theme

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	SceneBuilder.add(hud, root, "Root")

	var status := PanelContainer.new()
	status.position = Vector2(12, 12)
	status.custom_minimum_size = Vector2(300, 0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, status, "Status")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 6)
	SceneBuilder.add(status, rows, "Rows")
	var head := HBoxContainer.new()
	SceneBuilder.add(rows, head, "Head")
	var name_label := _label("你", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(head, SceneBuilder.unique(name_label), "NameLabel")
	var level_label := _label("Lv 1", 18)
	level_label.add_theme_color_override(&"font_color", Color("ffd75e"))
	SceneBuilder.add(head, SceneBuilder.unique(level_label), "LevelLabel")
	SceneBuilder.add(rows, _bar("HpBar", Color("e0484f"), 18, "HpText"))
	SceneBuilder.add(rows, _bar("XpBar", Color("f2c14e"), 12, "XpText"))

	var target := PanelContainer.new()
	target.anchor_left = 0.5
	target.anchor_right = 0.5
	target.offset_left = -150
	target.offset_right = 150
	target.offset_top = 12
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(target), "TargetPanel")
	var target_rows := VBoxContainer.new()
	SceneBuilder.add(target, target_rows, "Rows")
	var target_name := _label("目標", 16)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(target_rows, SceneBuilder.unique(target_name), "TargetName")
	SceneBuilder.add(target_rows, _bar("TargetHpBar", Color("e0484f"), 12, ""))

	var log_panel := PanelContainer.new()
	log_panel.anchor_top = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 12
	log_panel.offset_top = -172
	log_panel.offset_right = 452
	log_panel.offset_bottom = -12
	log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, log_panel, "LogPanel")
	var log_box := RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_theme_font_size_override(&"normal_font_size", 14)
	SceneBuilder.add(log_panel, SceneBuilder.unique(log_box), "Log")

	var help := _label("左鍵：移動／攻擊（按住持續走）　右鍵拖曳：轉鏡頭　滾輪：縮放\nWASD：移動　空白鍵：打最近的怪　T：白天／黃昏", 14)
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = -560
	help.offset_right = -14
	help.offset_top = -56
	help.offset_bottom = -12
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_constant_override(&"outline_size", 6)
	help.add_theme_color_override(&"font_outline_color", Color(0.05, 0.08, 0.15, 0.85))
	SceneBuilder.add(root, help, "Help")
	return _save(hud, "res://ui/hud.tscn")


# --- meadow --------------------------------------------------------------------------------------

func _environment(top: Color, horizon: Color, bottom: Color, ambient: float, fog: Color) -> Environment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = bottom
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.fog_light_color = fog
	env.fog_density = 0.004
	return env


func _place(parent: Node, scene: String, count: int, r_min: float, r_max: float, taken: Array[Vector3],
		scale_min := 0.85, scale_max := 1.25) -> void:
	var tries := 0
	var made := 0
	while made < count and tries < count * 60:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(r_min, r_max)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(p.x, p.z).distance_to(TerrainHeight.POND) < 10.0:
			continue
		var clear := true
		for t in taken:
			if Vector2(p.x, p.z).distance_to(Vector2(t.x, t.z)) < t.y:
				clear = false
				break
		if not clear:
			continue
		taken.append(Vector3(p.x, 3.0, p.z))
		p.y = _height_at(p.x, p.z) - 0.05
		var prop := SceneBuilder.instance(scene) as Node3D
		prop.position = p
		prop.rotation.y = rng.randf() * TAU
		prop.scale = Vector3.ONE * rng.randf_range(scale_min, scale_max)
		SceneBuilder.add(parent, prop, scene.get_file().get_basename().capitalize())
		made += 1


func _build_meadow() -> bool:
	var mesh := _save_res(_terrain_mesh(), "res://assets/terrain_mesh.res") as ArrayMesh
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	shape = _save_res(shape, "res://assets/terrain_shape.res") as ConcavePolygonShape3D

	var meadow := Node3D.new()
	meadow.name = "Meadow"
	meadow.set_script(load("res://scripts/meadow.gd"))
	var day := _save_res(_environment(Color("3f86de"), Color("c4e3f6"), Color("4d6b3a"), 0.45, Color("cfe6f5")),
		"res://resources/env_day.tres")
	var dusk := _save_res(_environment(Color("141c4a"), Color("6a5498"), Color("1a2030"), 0.6, Color("5a5a9a")),
		"res://resources/env_dusk.tres")
	meadow.set("day_environment", day)
	meadow.set("dusk_environment", dusk)

	var env := WorldEnvironment.new()
	env.environment = day
	SceneBuilder.add(meadow, SceneBuilder.unique(env), "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	SceneBuilder.add(meadow, SceneBuilder.unique(sun), "Sun")

	var terrain := StaticBody3D.new()
	SceneBuilder.add(meadow, terrain, "Terrain")
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.material_override = mats["terrain"]
	SceneBuilder.add(terrain, ground, "Ground")
	var col := CollisionShape3D.new()
	col.shape = shape
	SceneBuilder.add(terrain, col, "Collision")

	var water := MeshInstance3D.new()
	water.mesh = _cyl(7.6, 7.6, 0.04, 20)
	water.material_override = mats["water"]
	water.position = Vector3(TerrainHeight.POND.x, TerrainHeight.water_level(), TerrainHeight.POND.y)
	SceneBuilder.add(meadow, water, "Pond")

	var foliage := Node3D.new()
	SceneBuilder.add(meadow, foliage, "Foliage")
	_foliage(foliage, "Grass", _save_res(_scatter(_tuft_mesh(), 3600, 62.0, 1.0, 1.7), "res://assets/grass.res"))
	var petals := {"FlowersPink": Color("ff9cc8"), "FlowersWhite": Color("fff6ea"), "FlowersBlue": Color("9cb8ff")}
	for n: String in petals:
		var mm := _scatter(_flower_mesh(petals[n]), 260, 50.0, 1.6, 2.2)
		_foliage(foliage, n, _save_res(mm, "res://assets/%s.res" % n.to_snake_case()))

	var props := Node3D.new()
	SceneBuilder.add(meadow, SceneBuilder.unique(props), "Props")
	var taken: Array[Vector3] = [Vector3(0, 9.0, 0)]  # (x, min distance, z): keep the start clear
	var sign := SceneBuilder.instance("res://scenes/props/signpost.tscn") as Node3D
	sign.position = Vector3(-2.5, _height_at(-2.5, 1.5), 1.5)
	sign.rotation_degrees.y = 15
	SceneBuilder.add(props, sign, "Signpost")
	_place(props, "res://scenes/props/pine.tscn", 46, 40.0, 64.0, taken, 0.9, 1.5)
	_place(props, "res://scenes/props/oak.tscn", 18, 14.0, 42.0, taken)
	_place(props, "res://scenes/props/rock.tscn", 20, 10.0, 50.0, taken, 0.7, 1.4)
	_place(props, "res://scenes/props/bush.tscn", 26, 8.0, 50.0, taken, 0.7, 1.3)

	var monsters := Node3D.new()
	SceneBuilder.add(meadow, SceneBuilder.unique(monsters), "Monsters")
	var spots := {"slime": [8, 9.0, 26.0], "boar": [6, 18.0, 36.0], "hound": [4, 30.0, 44.0]}
	for kind: String in spots:
		var s: Array = spots[kind]
		var made := 0
		while made < s[0]:
			var a := rng.randf() * TAU
			var r := rng.randf_range(s[1], s[2])
			var p := Vector3(cos(a) * r, 0, sin(a) * r)
			if Vector2(p.x, p.z).distance_to(TerrainHeight.POND) < 9.0:
				continue
			p.y = _height_at(p.x, p.z)
			var m := SceneBuilder.instance("res://scenes/monsters/%s.tscn" % kind) as Node3D
			m.position = p
			SceneBuilder.add(monsters, m, kind.capitalize())
			made += 1
	return _save(meadow, "res://scenes/meadow.tscn")


# --- main ----------------------------------------------------------------------------------------

func _build_main() -> bool:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	SceneBuilder.add(main, SceneBuilder.unique(SceneBuilder.instance("res://scenes/meadow.tscn")), "Meadow")
	var player := SceneBuilder.instance("res://scenes/player.tscn") as Node3D
	player.position = Vector3(0, _height_at(0, 4), 4)
	SceneBuilder.add(main, SceneBuilder.unique(player), "Player")

	var rig := Node3D.new()
	rig.set_script(load("res://scripts/camera_rig.gd"))
	rig.position = player.position + Vector3.UP
	rig.rotation_degrees = Vector3(-42, 0, 0)
	rig.set("target_path", NodePath("../Player"))
	SceneBuilder.add(main, SceneBuilder.unique(rig), "CameraRig")
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 14)
	cam.fov = 40.0
	cam.far = 300.0
	SceneBuilder.add(rig, cam, "Camera")

	var marker := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.4
	torus.rings = 12
	torus.ring_segments = 4
	marker.mesh = torus
	marker.material_override = mats["marker"]
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(main, SceneBuilder.unique(marker), "ClickMarker")

	SceneBuilder.add(main, SceneBuilder.unique(SceneBuilder.instance("res://ui/hud.tscn")), "HUD")
	return _save(main, "res://scenes/main.tscn",
		["res://scenes/meadow.tscn", "res://scenes/player.tscn", "res://ui/hud.tscn"])
