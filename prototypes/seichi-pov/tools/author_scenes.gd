extends SceneTree
## One-time authoring tool: writes the editable scenes and materials. After the first run
## those files are the source; edit them in the editor. Existing files are skipped unless
## `-- --force` is passed (then diff before committing).
##
##   godot --headless --path prototypes/seichi-pov --script res://tools/author_scenes.gd

const SPOT := "res://spots/hokage_rock/"
const BAKED := SPOT + "baked/"
const PAPER := Color("F7F2E5")
const INK := Color("2A241A")
const INK_SOFT := Color("8A8172")
const SEAL := Color("A63B2A")

var force := false
var font: FontFile


func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	font = load("res://assets/fonts/NotoSansTC.ttf")
	_materials()
	_save_scene(_viewer(), "res://viewer/viewer.tscn")
	_save_scene(_hud(), "res://ui/hud.tscn")
	_save_scene(_spot(), SPOT + "hokage_rock.tscn")
	_save_scene(_main(), "res://main.tscn")
	quit(0)


# ------------------------------------------------------------------ helpers
func _save_res(res: Resource, path: String) -> void:
	if FileAccess.file_exists(path) and not force:
		print("skip ", path)
		return
	print("save ", path, ": ", error_string(ResourceSaver.save(res, path)))


func _save_scene(root: Node, path: String) -> void:
	if FileAccess.file_exists(path) and not force:
		print("skip ", path)
		root.free()
		return
	var count := _count(root)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, path)
	var back: Node = (load(path) as PackedScene).instantiate()
	print("save %s: %s nodes=%d reloaded=%d" % [path, error_string(err), count, _count(back)])
	back.free()
	root.free()


func _count(n: Node) -> int:
	var c := 1
	for child in n.get_children():
		c += _count(child)
	return c


func _add(parent: Node, child: Node, owner: Node, child_name: String, unique := false) -> Node:
	child.name = child_name
	parent.add_child(child)
	child.owner = owner
	child.unique_name_in_owner = unique
	return child


func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _mesh(parent: Node, owner: Node, mesh_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	_add(parent, mi, owner, mesh_name)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cyl(r: float, h: float, segments := 32) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segments
	c.rings = 0
	return c


func _flat(bg: Color, radius := 10, border := Color.TRANSPARENT, border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


# ------------------------------------------------------------------ materials
func _materials() -> void:
	var relief := StandardMaterial3D.new()
	relief.albedo_texture = load(BAKED + "relief_albedo.png")
	relief.normal_enabled = true
	relief.normal_texture = load(BAKED + "relief_normal.png")
	relief.roughness = 0.95
	relief.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_save_res(relief, SPOT + "relief_mat.tres")

	var wing := StandardMaterial3D.new()
	wing.albedo_texture = load(BAKED + "rock_tile_albedo.png")
	wing.normal_enabled = true
	wing.normal_texture = load(BAKED + "rock_tile_normal.png")
	wing.roughness = 0.95
	wing.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_save_res(wing, SPOT + "wing_mat.tres")

	var ground := StandardMaterial3D.new()
	ground.albedo_texture = load(BAKED + "ground_albedo.png")
	ground.roughness = 1.0
	ground.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_save_res(ground, SPOT + "ground_mat.tres")


# ------------------------------------------------------------------ viewer
func _viewer() -> Node:
	var root := Node3D.new()
	root.name = "Viewer"
	root.set_script(load("res://viewer/viewer.gd"))
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 5000.0
	cam.position = Vector3(0, 1.6, 0)
	_add(root, cam, root, "Camera", true)
	return root


# ------------------------------------------------------------------ hud
func _hud() -> Node:
	var root := CanvasLayer.new()
	root.name = "HUD"
	root.set_script(load("res://ui/hud.gd"))

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	theme.set_stylebox("normal", "Button", _flat(Color(0.97, 0.95, 0.90, 0.88), 22, SEAL, 2))
	theme.set_stylebox("hover", "Button", _flat(Color(1, 0.98, 0.94, 0.95), 22, SEAL, 2))
	theme.set_stylebox("pressed", "Button", _flat(Color(0.90, 0.84, 0.76, 0.95), 22, SEAL, 2))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", SEAL)
	theme.set_font_size("font_size", "Button", 22)
	_save_res(theme, "res://ui/hud_theme.tres")

	var ui := Control.new()
	_add(root, ui, root, "Root")
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = load("res://ui/hud_theme.tres")

	var pad := Control.new()
	pad.set_script(load("res://ui/look_pad.gd"))
	_add(ui, pad, root, "LookPad", true)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)

	var stick := Control.new()
	stick.set_script(load("res://ui/move_stick.gd"))
	_add(ui, stick, root, "MoveStick", true)
	stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stick.offset_left = 48
	stick.offset_top = -248
	stick.offset_right = 248
	stick.offset_bottom = -48
	var base := Panel.new()
	_add(stick, base, root, "Base")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override("panel", _flat(Color(0.97, 0.95, 0.90, 0.22), 100, Color(0.97, 0.95, 0.90, 0.6), 2))
	var knob := Panel.new()
	_add(stick, knob, root, "Knob", true)
	knob.size = Vector2(76, 76)
	knob.position = Vector2(62, 62)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override("panel", _flat(Color(0.97, 0.95, 0.90, 0.85), 38, SEAL, 3))

	var top := MarginContainer.new()
	_add(ui, top, root, "TopBar")
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 28)
	var row := HBoxContainer.new()
	_add(top, row, root, "Row")
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	var title := Label.new()
	_add(row, title, root, "TitleLabel", true)
	title.text = "火影岩"
	title.add_theme_font_size_override("font_size", 30)
	var spacer := Control.new()
	_add(row, spacer, root, "Spacer")
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [["InfoButton", "介紹"], ["ZoomButton", "望遠鏡"], ["ResetButton", "回正"]]:
		var b := Button.new()
		_add(row, b, root, pair[0], true)
		b.text = pair[1]
		b.custom_minimum_size = Vector2(112, 56)

	var card := PanelContainer.new()
	_add(ui, card, root, "InfoCard", true)
	card.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	card.offset_left = 48
	card.offset_right = 548
	card.offset_top = -230
	card.offset_bottom = 230
	var card_style := _flat(Color(PAPER, 0.93), 6, Color(INK, 0.35), 1)
	card_style.content_margin_left = 36
	card_style.content_margin_right = 36
	card_style.content_margin_top = 30
	card_style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", card_style)
	var col := VBoxContainer.new()
	_add(card, col, root, "Column")
	col.add_theme_constant_override("separation", 12)
	var seal_line := ColorRect.new()
	_add(col, seal_line, root, "SealLine")
	seal_line.color = SEAL
	seal_line.custom_minimum_size = Vector2(56, 4)
	seal_line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var labels := [["CardTitle", 60, INK], ["CardSubtitle", 22, SEAL], ["CardIntro", 20, INK], ["CardSource", 15, INK_SOFT]]
	for spec in labels:
		var l := Label.new()
		_add(col, l, root, spec[0], true)
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(col.get_node("CardIntro") as Label).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var enter := Button.new()
	_add(col, enter, root, "EnterButton", true)
	enter.text = "進入展望台"
	enter.custom_minimum_size = Vector2(0, 60)
	return root


# ------------------------------------------------------------------ spot
func _spot() -> Node:
	var root := Node3D.new()
	root.name = "HokageRock"
	root.set_script(load("res://spots/spot.gd"))
	root.display_name = "火影岩"
	root.subtitle = "木葉隱村 · 歷代火影的臉"
	root.intro = "刻在木葉村後方岩壁上的歷代火影頭像。由左至右為初代千手柱間、二代千手扉間、三代猿飛日斬、四代波風湊。\n\n你站在村子中央的展望台上：左下搖桿走動，拖曳畫面環顧，雙指或「望遠鏡」拉近細看。"
	root.source_note = "私人同人原型，非官方內容；造型依動畫印象程序生成。"

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.85)
	sky_mat.sky_horizon_color = Color(0.74, 0.83, 0.92)
	sky_mat.ground_horizon_color = Color(0.74, 0.83, 0.92)
	sky_mat.ground_bottom_color = Color(0.30, 0.36, 0.30)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.78, 0.88)
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	_add(root, we, root, "WorldEnvironment")

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -30, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_add(root, sun, root, "Sun", true)

	var cliff := MeshInstance3D.new()
	cliff.mesh = load(BAKED + "cliff.obj")
	_add(root, cliff, root, "Cliff")
	cliff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cliff.set_surface_override_material(0, load(SPOT + "relief_mat.tres"))
	cliff.set_surface_override_material(1, load(SPOT + "wing_mat.tres"))
	print("cliff surfaces: ", cliff.mesh.get_surface_count())

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(900, 900)
	_mesh(root, root, "Ground", ground_mesh, Vector3(0, 0, 190), load(SPOT + "ground_mat.tres"))
	var outer := PlaneMesh.new()
	outer.size = Vector2(9000, 9000)
	var outer_mi := _mesh(root, root, "OuterGround", outer, Vector3(0, -0.2, 0), _mat(Color(0.33, 0.47, 0.24), 1.0))
	outer_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var scenery: Node = (load(BAKED + "scenery.tscn") as PackedScene).instantiate()
	_add(root, scenery, root, "Scenery")

	var hall := Node3D.new()
	_add(root, hall, root, "HokageHall")
	hall.position = Vector3(0, 0, 44)
	var red := _mat(Color(0.74, 0.30, 0.20))
	_mesh(hall, root, "Body", _cyl(17.0, 20.0, 40), Vector3(0, 10, 0), red)
	_mesh(hall, root, "Band", _cyl(17.4, 2.0, 40), Vector3(0, 16.5, 0), _mat(Color(0.55, 0.18, 0.14)))
	_mesh(hall, root, "Roof", _cyl(18.2, 0.9, 40), Vector3(0, 20.45, 0), _mat(Color(0.48, 0.20, 0.16)))
	_mesh(hall, root, "Upper", _cyl(9.0, 6.0, 32), Vector3(0, 23.9, 0), red)
	_mesh(hall, root, "UpperRoof", _cyl(9.8, 0.7, 32), Vector3(0, 27.2, 0), _mat(Color(0.48, 0.20, 0.16)))
	var disc := _mesh(hall, root, "SignDisc", _cyl(4.6, 0.3, 32), Vector3(0, 10.5, 17.05), _mat(Color(0.95, 0.93, 0.88)))
	disc.rotation_degrees = Vector3(90, 0, 0)
	var kanji := Label3D.new()
	kanji.text = "火"
	kanji.font = font
	kanji.font_size = 256
	kanji.pixel_size = 0.026
	kanji.modulate = Color(0.62, 0.16, 0.12)
	kanji.outline_size = 0
	kanji.shaded = true
	kanji.position = Vector3(0, 10.5, 17.25)
	_add(hall, kanji, root, "Kanji")

	var platform := Node3D.new()
	_add(root, platform, root, "Platform")
	platform.position = Vector3(0, 0, 172)
	var wood := _mat(Color(0.47, 0.34, 0.24))
	var dark_wood := _mat(Color(0.32, 0.23, 0.17))
	_mesh(platform, root, "Tower", _box(Vector3(8, 25, 6)), Vector3(0, 12.5, 0), dark_wood)
	_mesh(platform, root, "Deck", _box(Vector3(9.6, 0.5, 7.4)), Vector3(0, 25.25, 0), wood)
	var rail_y := [26.15, 26.6]
	for i in rail_y.size():
		_mesh(platform, root, "RailFront%d" % i, _box(Vector3(9.6, 0.1, 0.1)), Vector3(0, rail_y[i], -3.65), dark_wood)
		_mesh(platform, root, "RailBack%d" % i, _box(Vector3(9.6, 0.1, 0.1)), Vector3(0, rail_y[i], 3.65), dark_wood)
		_mesh(platform, root, "RailLeft%d" % i, _box(Vector3(0.1, 0.1, 7.4)), Vector3(-4.75, rail_y[i], 0), dark_wood)
		_mesh(platform, root, "RailRight%d" % i, _box(Vector3(0.1, 0.1, 7.4)), Vector3(4.75, rail_y[i], 0), dark_wood)
	var k := 0
	for x in [-4.75, -1.6, 1.6, 4.75]:
		for z in [-3.65, 3.65]:
			_mesh(platform, root, "Post%d" % k, _box(Vector3(0.16, 1.2, 0.16)), Vector3(x, 26.1, z), dark_wood)
			k += 1

	var viewer: Node3D = (load("res://viewer/viewer.tscn") as PackedScene).instantiate()
	_add(platform, viewer, root, "Viewer", true)
	viewer.position = Vector3(0, 25.5, 0)
	viewer.half_extents = Vector2(4.2, 3.1)
	return root


# ------------------------------------------------------------------ main
func _main() -> Node:
	var root := Node.new()
	root.name = "Main"
	root.set_script(load("res://main.gd"))
	var spot: Node = (load(SPOT + "hokage_rock.tscn") as PackedScene).instantiate()
	_add(root, spot, root, "Spot", true)
	var hud: Node = (load("res://ui/hud.tscn") as PackedScene).instantiate()
	_add(root, hud, root, "HUD", true)
	return root
