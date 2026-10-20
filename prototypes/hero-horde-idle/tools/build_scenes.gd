extends SceneTree
## One-time authoring tool: writes the slice's theme, materials, meshes and scenes.
##   uv run --with pillow tools/make_placeholder_art.py            (art first)
##   godot --headless --path prototypes/hero-horde-idle --editor --quit
##   godot --headless --path prototypes/hero-horde-idle --script res://tools/build_scenes.gd
## Existing files are skipped (scenes) or kept (resources), so hand edits survive a rerun; delete a file to rebuild
## it. After the first run the saved .tscn/.tres files are the source: edit them in the editor, not here.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const Army = preload("res://scripts/army.gd")
const PushSim = preload("res://domain/push_sim.gd")

const HEROES := "res://assets/sprites/heroes.png"
const BOSS := "res://assets/sprites/boss.png"
const GROUND := "res://assets/sprites/ground.png"
const FONT := "res://ui/fonts/NotoSansTC.ttf"
const BOSS_AT := Vector3(3.7, 0.0, 0.0)
const BOSS_CELL_M := 128 * 0.0375
## This game's look on the shared sprite3d shader: side-view sprites leaned like pokebonk.com, real run frames
## (no bob), 1 px foot strip.
const LOOK := {"lean": 0.35, "bob": 0.0, "hit_squash": 0.3}

var _failed: bool = false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var theme: Theme = _keep(_theme(), "res://ui/theme.tres")
	var heroes_mat: ShaderMaterial = _material("res://materials/heroes.tres", "res://addons/proto_kit/sprite3d.gdshader",
		_with({"atlas": load(HEROES), "frames": Vector2(9, 6), "foot_gutter": 1.0 / 32.0, "use_instance_custom": true,
			"use_instance_color": true}, [LOOK]))
	var boss_mat: ShaderMaterial = _material("res://materials/boss.tres", "res://addons/proto_kit/sprite3d.gdshader",
		_with({"atlas": load(BOSS), "frames": Vector2(3, 1), "foot_gutter": 2.0 / 128.0,
			"outline": Color(1.0, 0.25, 0.2, 1.0)}, [LOOK]))
	var shadow_mat: ShaderMaterial = _material("res://materials/shadow.tres", "res://addons/proto_kit/sprite3d_shadow.gdshader",
		{"color": Color(0.12, 0.2, 0.1), "strength": 0.45, "stepped": true})
	var hero_mesh: ArrayMesh = _actor_mesh(shadow_mat, heroes_mat, "res://meshes/hero_mesh.tres")
	var bolt_mesh: QuadMesh = _keep(_bolt_mesh(), "res://meshes/bolt_mesh.tres")
	var ground_mat: StandardMaterial3D = _keep(_ground_material(), "res://materials/ground.tres")
	var zone_mat: ShaderMaterial = _material("res://materials/zone_tile.tres", "res://shaders/zone_tile.gdshader", {})
	if _failed:
		quit(1)
		return

	_save(_hud(theme), "res://scenes/hud.tscn", [])
	_save(_zone_tile(zone_mat), "res://scenes/zone_tile.tscn", [])
	_save(_main(hero_mesh, bolt_mesh, boss_mat, shadow_mat, ground_mat), "res://scenes/main.tscn",
		["res://scenes/hud.tscn", "res://scenes/zone_tile.tscn"])
	quit(1 if _failed else 0)


func _main(hero_mesh: ArrayMesh, bolt_mesh: Mesh, boss_mat: Material, shadow_mat: Material, ground_mat: Material) -> Node3D:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))

	var camera := Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 40.0
	var eye := Vector3(1.1, 11.5, 9.5)
	camera.transform = Transform3D(Basis.looking_at(Vector3(1.1, 0.0, -0.6) - eye, Vector3.UP), eye)
	SceneBuilder.add(main, SceneBuilder.unique(camera), "Camera")

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	ground.material_override = ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(main, ground, "Ground")

	var boss := Node3D.new()
	boss.set_script(load("res://scripts/boss.gd"))
	boss.position = BOSS_AT
	SceneBuilder.add(main, SceneBuilder.unique(boss), "Boss")
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	sprite.mesh = quad
	sprite.scale = Vector3.ONE * BOSS_CELL_M
	sprite.material_override = boss_mat
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(boss, SceneBuilder.unique(sprite), "BossSprite")
	var shadow := MeshInstance3D.new()
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2.ONE
	shadow.mesh = shadow_plane
	shadow.scale = Vector3(BOSS_CELL_M, 1.0, BOSS_CELL_M)
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(boss, shadow, "BossShadow")
	var weak := Marker3D.new()
	weak.position = Vector3(0.1, 2.0, 0.3)
	SceneBuilder.add(boss, SceneBuilder.unique(weak), "WeakPointAnchor")

	var zones := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(zones), "Zones")
	var defaults := PushSim.new()
	for z: int in PushSim.ZONES:
		var tile: Node3D = SceneBuilder.instance("res://scenes/zone_tile.tscn")
		tile.position = Vector3(defaults.zone_center[z].x, 0.0, defaults.zone_center[z].y)
		tile.set(&"zone_index", z)
		SceneBuilder.add(zones, tile, "Zone_" + PushSim.ZONE_NAMES[z])

	var army := MultiMeshInstance3D.new()
	army.set_script(Army)
	army.multimesh = _army_preview(hero_mesh)
	army.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	army.custom_aabb = AABB(BOSS_AT + Vector3(-20.0, -2.0, -12.0), Vector3(30.0, 8.0, 24.0))
	SceneBuilder.add(main, SceneBuilder.unique(army), "Army")

	var bolts := MultiMeshInstance3D.new()
	bolts.set_script(load("res://scripts/bolts.gd"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bolt_mesh
	bolts.multimesh = mm
	bolts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolts.custom_aabb = army.custom_aabb
	SceneBuilder.add(main, SceneBuilder.unique(bolts), "Bolts")

	SceneBuilder.add(main, SceneBuilder.unique(SceneBuilder.instance("res://scenes/hud.tscn")), "Hud")
	return main


## The opening formation as saved instances, so the editor shows the six zones full of heroes without running.
func _army_preview(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	var sim := PushSim.new()
	mm.instance_count = sim.cls.size()
	var size: float = 32 * 0.0375
	for i: int in sim.cls.size():
		var at := Vector3(sim.goal[i].x, 0.0, sim.goal[i].y)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * size), at))
		mm.set_instance_custom_data(i, Sprite3DSheet.instance_custom(sim.cls[i] * 9 + 4, 0.0, 1, 0.0))
		mm.set_instance_color(i, Sprite3DSheet.instance_color(Army.tint(i), Army.role(sim.rarity[i])))
	return mm


## One zone: ground tile (its PlaneMesh size is the zone's rectangle) and a billboard label at the back edge.
func _zone_tile(zone_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "ZoneTile"
	root.set_script(load("res://scripts/zone_tile.gd"))
	var tile := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = PushSim.ZONE_HALF * 2.0
	tile.mesh = plane
	tile.position = Vector3(0.0, 0.02, 0.0)
	tile.material_override = zone_mat
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	SceneBuilder.add(root, SceneBuilder.unique(tile), "Tile")
	var label := Label3D.new()
	label.text = "近2  17人"
	label.font = load(FONT)
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.outline_render_priority = 1
	label.position = Vector3(0.0, 0.1, -PushSim.ZONE_HALF.y + 0.05)
	SceneBuilder.add(root, SceneBuilder.unique(label), "ZoneLabel")
	return root


func _hud(theme: Theme) -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(load("res://scripts/hud.gd"))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	SceneBuilder.add(hud, root, "Root")

	var top := _margins(Control.PRESET_TOP_WIDE, 24, 36, 24, 0)
	SceneBuilder.add(root, top, "Top")
	var top_box := VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_constant_override(&"separation", 6)
	SceneBuilder.add(top, top_box, "TopBox")
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override(&"separation", 16)
	SceneBuilder.add(top_box, title_row, "TitleRow")
	var boss_name := _label("關卡王・棍棒巨魔", 30)
	boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SceneBuilder.add(title_row, boss_name, "BossName")
	SceneBuilder.add(title_row, SceneBuilder.unique(_label("第一階段", 26)), "PhaseLabel")
	SceneBuilder.add(title_row, SceneBuilder.unique(_label("150", 48)), "TimerLabel")
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 36)
	hp.show_percentage = false
	hp.value = 100.0
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_theme_stylebox_override(&"fill", _box(Color(0.86, 0.22, 0.2), 6, Color(0, 0, 0, 0), 0))
	SceneBuilder.add(top_box, SceneBuilder.unique(hp), "BossHp")
	var hp_label := _label("100%", 24)
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(hp, SceneBuilder.unique(hp_label), "BossHpLabel")
	var dps := _label("存活 100／100   總輸出 0／秒", 24)
	dps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(top_box, SceneBuilder.unique(dps), "DpsLabel")

	var banner := _label("重砸！ 移開紅區！", 46)
	banner.anchor_left = 0.0
	banner.anchor_right = 1.0
	banner.anchor_top = 0.17
	banner.anchor_bottom = 0.17
	banner.offset_top = -40.0
	banner.offset_bottom = 40.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override(&"outline_size", 12)
	SceneBuilder.add(root, SceneBuilder.unique(banner), "Banner")

	for spec: Array in [["ArrowLeft", "◀"], ["ArrowRight", "▶"]]:
		var arrow := Button.new()
		arrow.text = spec[1]
		arrow.size = Vector2(104, 104)
		arrow.position = Vector2(80, 600)
		arrow.add_theme_font_size_override(&"font_size", 44)
		for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
			arrow.add_theme_stylebox_override(state, _box(Color(0.16, 0.2, 0.36, 0.85), 52, Color.WHITE, 5))
		SceneBuilder.add(root, SceneBuilder.unique(arrow), spec[0])

	var weak := Button.new()
	weak.text = "弱點"
	weak.size = Vector2(124, 124)
	weak.position = Vector2(540, 520)
	weak.add_theme_font_size_override(&"font_size", 30)
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		weak.add_theme_color_override(key, Color(0.35, 0.12, 0.05))
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		weak.add_theme_stylebox_override(state, _box(Color(1.0, 0.85, 0.2, 0.85), 62, Color.WHITE, 6))
	SceneBuilder.add(root, SceneBuilder.unique(weak), "WeakPoint")

	var bottom := _margins(Control.PRESET_BOTTOM_WIDE, 24, 0, 24, 32)
	SceneBuilder.add(root, bottom, "Bottom")
	var bottom_box := VBoxContainer.new()
	bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_box.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(bottom, bottom_box, "BottomBox")
	var skip_row := HBoxContainer.new()
	skip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_row.alignment = BoxContainer.ALIGNMENT_END
	SceneBuilder.add(bottom_box, skip_row, "SkipRow")
	var skip := Button.new()
	skip.text = "跳過集結 ▶"
	skip.custom_minimum_size = Vector2(0, 72)
	SceneBuilder.add(skip_row, SceneBuilder.unique(skip), "SkipMuster")
	SceneBuilder.add(bottom_box, SceneBuilder.unique(_label("選區：近2　17 人", 28)), "ZoneLabel")
	var morale_row := HBoxContainer.new()
	morale_row.add_theme_constant_override(&"separation", 12)
	SceneBuilder.add(bottom_box, morale_row, "MoraleRow")
	var morale_title := _label("士氣", 28)
	morale_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SceneBuilder.add(morale_row, morale_title, "MoraleTitle")
	var morale := ProgressBar.new()
	morale.custom_minimum_size = Vector2(0, 30)
	morale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	morale.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	morale.show_percentage = false
	morale.mouse_filter = Control.MOUSE_FILTER_IGNORE
	morale.add_theme_stylebox_override(&"fill", _box(Color(1.0, 0.78, 0.2), 6, Color(0, 0, 0, 0), 0))
	SceneBuilder.add(morale_row, SceneBuilder.unique(morale), "Morale")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 12)
	SceneBuilder.add(bottom_box, actions, "Actions")
	for spec: Array in [["Regroup", "全員歸位"], ["Volley", "大招"]]:
		var b := Button.new()
		b.text = spec[1]
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		SceneBuilder.add(actions, SceneBuilder.unique(b), spec[0])

	var result := Control.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(result), "Result")
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(result, dim, "Dim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(result, center, "Center")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	SceneBuilder.add(center, panel, "Panel")
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override(&"separation", 18)
	SceneBuilder.add(panel, panel_box, "PanelBox")
	for spec: Array in [["ResultTitle", "推王成功！", 52], ["ResultDetail", "剩 30.0 秒　存活 85 人", 30]]:
		var l := _label(spec[1], spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		SceneBuilder.add(panel_box, SceneBuilder.unique(l), spec[0])
	var retry := Button.new()
	retry.text = "再來一場"
	retry.custom_minimum_size = Vector2(0, 96)
	SceneBuilder.add(panel_box, SceneBuilder.unique(retry), "Retry")
	return hud


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(FONT)
	theme.default_font_size = 30
	theme.set_color(&"font_outline_color", &"Label", Color(0.05, 0.04, 0.1))
	theme.set_constant(&"outline_size", &"Label", 8)
	theme.set_stylebox(&"normal", &"Button", _box(Color(0.16, 0.2, 0.36, 0.92), 18, Color(0.85, 0.88, 1.0), 4))
	theme.set_stylebox(&"hover", &"Button", _box(Color(0.22, 0.27, 0.46, 0.95), 18, Color.WHITE, 4))
	theme.set_stylebox(&"pressed", &"Button", _box(Color(0.32, 0.38, 0.62, 1.0), 18, Color.WHITE, 4))
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	theme.set_stylebox(&"disabled", &"Button", _box(Color(0.12, 0.12, 0.16, 0.75), 18, Color(0.4, 0.4, 0.45), 4))
	theme.set_color(&"font_disabled_color", &"Button", Color(0.55, 0.55, 0.6))
	theme.set_font_size(&"font_size", &"Button", 32)
	theme.set_stylebox(&"background", &"ProgressBar", _box(Color(0.05, 0.05, 0.1, 0.8), 6, Color(0.85, 0.88, 1.0), 3))
	theme.set_stylebox(&"panel", &"PanelContainer", _box(Color(0.1, 0.12, 0.24, 0.96), 24, Color(0.85, 0.88, 1.0), 4))
	return theme


func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(GROUND)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(30.0, 30.0, 1.0)
	return m


func _bolt_mesh() -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	quad.material = m
	return quad


## Shadow plane (surface 0) and feet-pivoted sprite quad (surface 1) sharing one MultiMesh instance buffer.
func _actor_mesh(shadow: Material, sprite: Material, path: String) -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	mesh.surface_set_material(0, shadow)
	mesh.surface_set_material(1, sprite)
	return _keep(mesh, path)


func _margins(preset: int, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(preset)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_WIDE else Control.GROW_DIRECTION_END
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override(&"margin_left", left)
	m.add_theme_constant_override(&"margin_top", top)
	m.add_theme_constant_override(&"margin_right", right)
	m.add_theme_constant_override(&"margin_bottom", bottom)
	return m


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	return label


func _box(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.border_color = border
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	return box


func _save(root: Node, path: String, refs: Array) -> void:
	var result: Dictionary = SceneBuilder.save_scene(root, path, {"expected_refs": refs})
	if not result.ok:
		_failed = true
	elif not result.skipped:
		_strip_nulls(path)


func _keep(resource: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("cannot save %s: %s" % [path, error_string(error)])
		_failed = true
		return resource
	print("saved: ", path)
	_strip_nulls(path)
	return load(path)


## A headless save writes every shader uniform it did not set as `= null`, which hides the shader's default.
func _strip_nulls(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var kept: PackedStringArray = []
	for line: String in text.split("\n"):
		if not (line.begins_with("shader_parameter/") and line.ends_with(" = null")):
			kept.append(line)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(kept))


func _material(path: String, shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return _keep(m, path)


func _with(params: Dictionary, extras: Array) -> Dictionary:
	for extra: Dictionary in extras:
		params.merge(extra)
	return params
