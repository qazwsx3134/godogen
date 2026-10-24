extends SceneTree
## Authoring tool for the RO combat slice: shaders, sheets, meshes, actor/prop/fx scenes, UI
## theme, HUD and the field. Saved scenes are the editable source; game start, import and tests
## never run this. Existing scenes are skipped; `-- --force <name,...>` rebuilds named outputs
## (check `git diff` first: hand edits in those files are replaced).
##
##   timeout 300 godot --headless --path . --script res://tools/build_slice.gd [-- --force field,hud]
##
## Applied 2026-10-24 (first build).

const B = preload("res://addons/proto_kit/scene_builder.gd")
const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const FONT := "res://assets/fonts/NotoSansTC.ttf"
const KIT_SHADER := "res://addons/proto_kit/sprite3d.gdshader"
const HD_SHADER := "res://shaders/sprite3d_hd.gdshader"

## kind -> world height of the idle pose (m), anims, nameplate head height.
const ACTORS := {
	"leader": {"art": "captain", "name": "隊長", "head": 2.0, "dissolve": false, "party": true},
	"guardian": {"art": "guardian", "name": "盾衛", "head": 2.05, "dissolve": false, "party": true},
	"support": {"art": "medic", "name": "援護", "head": 1.95, "dissolve": false, "party": true},
	"meadow_slime": {"art": "meadow_slime", "name": "草原史萊姆", "head": 0.95, "dissolve": true, "party": false},
	"briar_boar": {"art": "briar_boar", "name": "荊棘野豬", "head": 1.35, "dissolve": true, "party": false},
	"ruin_hound": {"art": "ruin_hound", "name": "遺跡獵犬", "head": 1.35, "dissolve": true, "party": false},
}
const PARTY_ANIMS := {
	"idle": {"cell": 0, "n": 1, "d": [60], "loop": true},
	"walk": {"cell": 1, "n": 2, "d": [9, 9], "loop": true},
	"attack": {"cell": 3, "n": 1, "d": [20], "loop": false},
	"down": {"cell": 4, "n": 1, "d": [60], "loop": false},
	"skill": {"cell": 5, "n": 1, "d": [32], "loop": false},
}
const MONSTER_ANIMS := {
	"idle": {"cell": 0, "n": 1, "d": [60], "loop": true},
	"walk": {"cell": 1, "n": 2, "d": [11, 11], "loop": true},
	"attack": {"cell": 3, "n": 1, "d": [22], "loop": false},
	"down": {"cell": 4, "n": 1, "d": [60], "loop": false},
}
const CELL_PX := 512
const METERS_PER_PX := 0.0042

var font: Font
var force: PackedStringArray = []
var problems: int = 0
var materials: Dictionary = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--force")
	if at >= 0 and at + 1 < args.size():
		force = args[at + 1].split(",")
	_build.call_deferred()


func _build() -> void:
	font = load(FONT)
	make_hd_shader()
	make_sheets()
	make_meshes()
	make_actor()
	for prop: String in ["boulder", "pillar", "pillar_broken", "oak", "pine", "wall", "arch", "crystal", "blocker", "tent", "campfire", "banner"]:
		make_prop(prop)
	make_camp()
	make_boss()
	make_fx()
	make_theme()
	make_party_row()
	make_item_row()
	make_camp_panel()
	make_hud()
	make_field()
	print("build_slice: %s" % ("ok" if problems == 0 else "%d problem(s)" % problems))
	quit(0 if problems == 0 else 1)


# --- Shared helpers -------------------------------------------------------------

func save(root: Node, path: String, refs: Array = []) -> void:
	var name := path.get_file().get_basename()
	var result: Dictionary = B.save_scene(root, path, {"expected_refs": refs, "overwrite": name in force})
	if not result.ok:
		problems += 1
	elif result.skipped:
		print("  skip (exists): ", path)
	else:
		print("  saved: ", path, " nodes=", result.nodes)


func save_resource(res: Resource, path: String) -> Resource:
	var name := path.get_file().get_basename()
	if ResourceLoader.exists(path) and not name in force:
		return load(path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s: %d" % [path, err])
		problems += 1
		return res
	res.take_over_path(path)
	return res


func add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	if unique:
		B.unique(child)
	return B.add(parent, child, node_name)


func mesh_node(parent: Node, node_name: String, mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	add(parent, node, node_name)
	return node


func shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return m


func quad(size: Vector2, offset: Vector3 = Vector3.ZERO) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = offset
	return q


func flat_plane(size: Vector2) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = size
	return p


# --- Shader and sheets ---------------------------------------------------------

## The kit shader with linear, mipmapped sampling for HD illustration atlases. Generated so it
## cannot drift from the kit: everything except the sampler line is the kit's text.
func make_hd_shader() -> void:
	var text := FileAccess.get_file_as_string(KIT_SHADER)
	var nearest := "uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;"
	if not text.contains(nearest):
		push_error("kit sprite3d shader changed: sampler line not found")
		problems += 1
		return
	text = text.replace(nearest, "uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;")
	text = "// GENERATED by tools/build_slice.gd from %s: HD (linear) sampling. Do not edit.\n%s" % [KIT_SHADER, text]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shaders"))
	var file := FileAccess.open(HD_SHADER, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func make_sheets() -> void:
	for kind: String in ACTORS:
		var spec: Dictionary = ACTORS[kind]
		var sheet := Sheet.new()
		var atlas_path := "res://assets/sprites/%s.png" % spec.art
		if ResourceLoader.exists(atlas_path):
			sheet.atlas = load(atlas_path)
		sheet.cell_px = CELL_PX
		sheet.foot_px = 8
		sheet.meters_per_px = METERS_PER_PX
		sheet.directions = 1
		sheet.mirror = true
		sheet.columns = 6 if spec.party else 5
		sheet.rows = 1
		sheet.anims = PARTY_ANIMS if spec.party else MONSTER_ANIMS
		save_resource(sheet, "res://resources/sheets/%s.tres" % kind)


# --- Low-poly meshes ------------------------------------------------------------

## Faceted (flat-normal) copy of a primitive, with a per-face colour jitter. Normals are computed
## per triangle here (a second SurfaceTool pass would drop the colours) and oriented like the
## primitive's own smooth normals, so faces point outward whatever the winding.
func faceted(primitive: Mesh, color: Color, jitter: float = 0.0, seed: int = 1) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(primitive, 0)
	st.deindex()
	var arrays := st.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var smooth: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	var colors := PackedColorArray()
	colors.resize(verts.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(0, verts.size(), 3):
		var n := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
		n = n.normalized() if n.length() > 1e-6 else Vector3.UP
		if n.dot(smooth[i] + smooth[i + 1] + smooth[i + 2]) < 0.0:
			n = -n
		var c := color.lightened(rng.randf_range(0.0, jitter)) if rng.randf() < 0.5 else color.darkened(rng.randf_range(0.0, jitter))
		for k in 3:
			normals[i + k] = n
			colors[i + k] = c
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


func vertex_color_material(roughness: float = 0.92) -> StandardMaterial3D:
	if materials.has(roughness):
		return materials[roughness]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	materials[roughness] = save_resource(m, "res://resources/materials/low_poly_%d.tres" % int(roughness * 100))
	return materials[roughness]


func sphere(radius: float, height: float, segments: int = 7, rings: int = 4) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = segments
	s.rings = rings
	return s


func cylinder(top: float, bottom: float, height: float, sides: int = 7) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func make_meshes() -> void:
	var stone := Color("8a826f")
	var meshes := {
		"rock": faceted(sphere(0.9, 1.3, 7, 4), Color("6e6a62"), 0.12, 3),
		"pillar": faceted(cylinder(0.42, 0.48, 2.8, 8), stone, 0.08, 4),
		"pillar_stub": faceted(cylinder(0.4, 0.48, 1.2, 8), stone, 0.1, 5),
		"plinth": faceted(box(Vector3(1.3, 0.35, 1.3)), stone.darkened(0.1), 0.06, 6),
		"trunk": faceted(cylinder(0.16, 0.26, 1.7, 6), Color("6b4a31"), 0.08, 7),
		"canopy": faceted(sphere(1.15, 1.7, 8, 5), Color("4f8a3c"), 0.14, 8),
		"canopy_small": faceted(sphere(0.8, 1.2, 7, 4), Color("5d9a45"), 0.14, 9),
		"pine_cone": faceted(cylinder(0.0, 1.0, 1.6, 7), Color("2f6b46"), 0.1, 10),
		"wall": faceted(box(Vector3(2.6, 1.2, 0.6)), stone, 0.1, 11),
		"wall_top": faceted(box(Vector3(1.4, 0.5, 0.6)), stone.darkened(0.05), 0.1, 12),
		"blade": faceted(cylinder(0.0, 0.05, 0.42, 4), Color("7fb04f"), 0.18, 13),
		"lintel": faceted(box(Vector3(4.2, 0.6, 0.9)), stone, 0.08, 14),
		"crystal": faceted(cylinder(0.0, 0.32, 1.3, 5), Color("7fe3e0"), 0.15, 15),
		"cliff": faceted(cylinder(1.0, 0.55, 1.0, 9), Color("665e51"), 0.12, 16),
		"tent": faceted(cylinder(0.0, 1.3, 1.6, 6), Color("c9b48a"), 0.08, 17),
		"log": faceted(cylinder(0.12, 0.12, 0.9, 6), Color("6b4a31"), 0.1, 18),
		"flame": faceted(cylinder(0.0, 0.22, 0.55, 5), Color("ffb347"), 0.15, 19),
		"pole": faceted(cylinder(0.05, 0.06, 2.6, 5), Color("5a4330"), 0.05, 20),
		"flag": faceted(box(Vector3(0.9, 0.55, 0.04)), Color("2f7f86"), 0.06, 21),
		"golem_torso": faceted(box(Vector3(1.7, 1.5, 1.1)), Color("7a7366"), 0.12, 22),
		"golem_head": faceted(box(Vector3(0.8, 0.7, 0.75)), Color("857d6f"), 0.1, 23),
		"golem_arm": faceted(box(Vector3(0.5, 1.5, 0.5)), Color("6f685c"), 0.12, 24),
		"golem_leg": faceted(box(Vector3(0.6, 0.9, 0.6)), Color("665f53"), 0.12, 25),
		"golem_eye": faceted(box(Vector3(0.5, 0.1, 0.05)), Color("7fe3e0"), 0.0, 26),
	}
	for name: String in meshes:
		save_resource(meshes[name], "res://resources/meshes/%s.res" % name)


func lowpoly(name: String) -> Mesh:
	return load("res://resources/meshes/%s.res" % name)


# --- Actor ----------------------------------------------------------------------

func make_actor() -> void:
	var root := Node3D.new()
	root.name = "Actor"
	root.set_script(load("res://game/actor_view.gd"))
	var visual := add(root, Node3D.new(), "Visual") as Node3D
	visual.set_script(load("res://addons/proto_kit/sprite3d_actor.gd"))
	var body := shader_material(HD_SHADER, {"frames": Vector2(6, 1), "foot_gutter": 8.0 / CELL_PX, "lean": 0.85,
		"bob": 0.0, "alpha_cut": 0.45, "light": 1.0, "hit_squash": 0.35, "flash_color": Color(1.0, 0.95, 0.85)})
	var sprite := mesh_node(visual, "Sprite", quad(Vector2.ONE, Vector3(0, 0.5, 0)), body)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.scale = Vector3.ONE * CELL_PX * METERS_PER_PX
	var shadow := mesh_node(visual, "Shadow", flat_plane(Vector2.ONE),
		shader_material("res://addons/proto_kit/sprite3d_shadow.gdshader", {"strength": 0.42}))
	shadow.scale = Vector3.ONE * CELL_PX * METERS_PER_PX
	var plate := add(root, Label3D.new(), "Nameplate") as Label3D
	plate.font = font
	plate.font_size = 30
	plate.pixel_size = 0.0075
	plate.outline_size = 8
	plate.outline_modulate = Color(0.05, 0.05, 0.07, 0.9)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 2
	plate.position = Vector3(0, 2.35, 0)
	plate.text = "名稱"
	var bar := mesh_node(root, "HpBar", quad(Vector2(1.0, 0.12)), shader_material("res://shaders/hp_bar.gdshader"),
		Vector3(0, 2.1, 0))
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := mesh_node(root, "SelectRing", flat_plane(Vector2(1.6, 1.6)),
		shader_material("res://shaders/select_ring.gdshader", {"tint": Color(1.0, 0.42, 0.32)}), Vector3(0, 0.03, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	save(root, "res://scenes/actors/actor.tscn")


# --- Props ----------------------------------------------------------------------

func make_prop(kind: String) -> void:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.set_script(load("res://game/prop.gd"))
	var mat := vertex_color_material()
	var radius := 0.0
	match kind:
		"boulder":
			mesh_node(root, "Rock", lowpoly("rock"), mat, Vector3(0, 0.45, 0))
			mesh_node(root, "Rock2", lowpoly("rock"), mat, Vector3(0.75, 0.2, 0.35)).scale = Vector3.ONE * 0.45
			radius = 0.95
		"pillar":
			mesh_node(root, "Plinth", lowpoly("plinth"), mat, Vector3(0, 0.17, 0))
			mesh_node(root, "Column", lowpoly("pillar"), mat, Vector3(0, 1.74, 0))
			radius = 0.6
		"pillar_broken":
			mesh_node(root, "Plinth", lowpoly("plinth"), mat, Vector3(0, 0.17, 0))
			var stub := mesh_node(root, "Stub", lowpoly("pillar_stub"), mat, Vector3(0, 0.94, 0))
			stub.rotation_degrees = Vector3(4, 20, -3)
			var fallen := mesh_node(root, "Fallen", lowpoly("pillar_stub"), mat, Vector3(1.1, 0.4, 0.4))
			fallen.rotation_degrees = Vector3(0, 35, 88)
			radius = 0.75
		"oak":
			mesh_node(root, "Trunk", lowpoly("trunk"), mat, Vector3(0, 0.85, 0))
			mesh_node(root, "Canopy", lowpoly("canopy"), mat, Vector3(0, 2.4, 0))
			mesh_node(root, "Canopy2", lowpoly("canopy_small"), mat, Vector3(0.7, 2.0, 0.3))
			mesh_node(root, "Canopy3", lowpoly("canopy_small"), mat, Vector3(-0.6, 2.2, -0.4))
			radius = 0.5
		"pine":
			mesh_node(root, "Trunk", lowpoly("trunk"), mat, Vector3(0, 0.6, 0)).scale = Vector3(0.8, 0.7, 0.8)
			for i in 3:
				var cone := mesh_node(root, "Tier%d" % i, lowpoly("pine_cone"), mat, Vector3(0, 1.6 + i * 0.75, 0))
				cone.scale = Vector3.ONE * (1.25 - i * 0.3)
			radius = 0.45
		"wall":
			mesh_node(root, "Base", lowpoly("wall"), mat, Vector3(0, 0.6, 0))
			mesh_node(root, "Top", lowpoly("wall_top"), mat, Vector3(-0.5, 1.45, 0))
			radius = 1.2
		"arch":
			for x: float in [-1.7, 1.7]:
				mesh_node(root, "Plinth%s" % ("L" if x < 0 else "R"), lowpoly("plinth"), mat, Vector3(x, 0.17, 0))
				mesh_node(root, "Column%s" % ("L" if x < 0 else "R"), lowpoly("pillar"), mat, Vector3(x, 1.74, 0))
			mesh_node(root, "Lintel", lowpoly("lintel"), mat, Vector3(0, 3.4, 0))
			radius = 0.0  # the posts block individually: place the arch at the field edge
		"crystal":
			for i in 3:
				var c := mesh_node(root, "Shard%d" % i, lowpoly("crystal"), vertex_color_material(0.35),
					Vector3([0.0, 0.35, -0.3][i], 0.6, [0.0, 0.2, 0.25][i]))
				c.rotation_degrees = Vector3([0, 18, -14][i], 0, [0, -16, 12][i])
				c.scale = Vector3.ONE * [1.0, 0.7, 0.6][i]
			radius = 0.45
		"blocker":
			radius = 0.6  # invisible: blocks where another prop's geometry stands (arch posts)
		"tent":
			mesh_node(root, "Canvas", lowpoly("tent"), mat, Vector3(0, 0.8, 0))
			radius = 1.1
		"campfire":
			for i in 3:
				var wood := mesh_node(root, "Log%d" % i, lowpoly("log"), mat, Vector3(0, 0.1, 0))
				wood.rotation_degrees = Vector3(0, i * 60.0, 90)
			var flame := mesh_node(root, "Flame", lowpoly("flame"), vertex_color_material(0.35), Vector3(0, 0.38, 0))
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var light := add(root, OmniLight3D.new(), "Glow") as OmniLight3D
			light.position = Vector3(0, 0.8, 0)
			light.light_color = Color("ffb35c")
			light.light_energy = 1.4
			light.omni_range = 4.5
			radius = 0.45
		"banner":
			mesh_node(root, "Pole", lowpoly("pole"), mat, Vector3(0, 1.3, 0))
			mesh_node(root, "Flag", lowpoly("flag"), mat, Vector3(0.48, 2.25, 0))
			radius = 0.2
	var gizmo := TorusMesh.new()
	gizmo.inner_radius = 0.96
	gizmo.outer_radius = 1.0
	var gizmo_mat := StandardMaterial3D.new()
	gizmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gizmo_mat.albedo_color = Color(1.0, 0.3, 0.2)
	var g := mesh_node(root, "BlockGizmo", gizmo, gizmo_mat, Vector3(0, 0.05, 0))
	g.visible = false
	root.block_radius = radius
	save(root, "res://scenes/props/%s.tscn" % kind)


# --- Camp and boss ------------------------------------------------------------------

func make_camp() -> void:
	var root := Node3D.new()
	root.name = "Camp"
	root.set_script(load("res://game/camp.gd"))
	var ring := mesh_node(root, "SafeRing", flat_plane(Vector2(2.0, 2.0)),
		shader_material("res://shaders/select_ring.gdshader", {"tint": Color(0.55, 0.95, 0.6), "dashes": 18.0, "speed": 0.15}),
		Vector3(0, 0.03, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.radius = 3.0
	save(root, "res://scenes/camp.tscn")


## Placeholder floor guardian: low-poly stone golem (no HD art yet). Same node contract as actor.tscn.
func make_boss() -> void:
	var root := Node3D.new()
	root.name = "Gatekeeper"
	root.set_script(load("res://game/boss_view.gd"))
	root.kind_id = "gatekeeper"
	root.head_height = 3.4
	root.nameplate_color = Color("ffb08a")
	var visual := add(root, Node3D.new(), "Visual") as Node3D
	var mat := vertex_color_material()
	var body := add(visual, Node3D.new(), "Body") as Node3D
	mesh_node(body, "LegL", lowpoly("golem_leg"), mat, Vector3(-0.45, 0.45, 0))
	mesh_node(body, "LegR", lowpoly("golem_leg"), mat, Vector3(0.45, 0.45, 0))
	mesh_node(body, "Torso", lowpoly("golem_torso"), mat, Vector3(0, 1.65, 0))
	var head := add(body, Node3D.new(), "Head") as Node3D
	head.position = Vector3(0, 2.75, 0.05)
	mesh_node(head, "Skull", lowpoly("golem_head"), mat)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("7fe3e0")
	eye_mat.emission_enabled = true
	eye_mat.emission = Color("7fe3e0")
	eye_mat.emission_energy_multiplier = 2.0
	mesh_node(head, "Eyes", lowpoly("golem_eye"), eye_mat, Vector3(0, 0.05, 0.39))
	for side: Array in [["ArmL", -1.15], ["ArmR", 1.15]]:
		var pivot := add(body, Node3D.new(), side[0]) as Node3D
		pivot.position = Vector3(side[1], 2.2, 0)
		mesh_node(pivot, "Stone", lowpoly("golem_arm"), mat, Vector3(0, -0.7, 0))
	var shadow := mesh_node(visual, "Shadow", flat_plane(Vector2(3.2, 3.2)),
		shader_material("res://addons/proto_kit/sprite3d_shadow.gdshader", {"strength": 0.45}), Vector3(0, 0.02, 0))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate := add(root, Label3D.new(), "Nameplate") as Label3D
	plate.font = font
	plate.font_size = 34
	plate.pixel_size = 0.0075
	plate.outline_size = 8
	plate.outline_modulate = Color(0.05, 0.05, 0.07, 0.9)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.no_depth_test = true
	plate.render_priority = 2
	plate.position = Vector3(0, 3.7, 0)
	plate.text = "守門者"
	var bar := mesh_node(root, "HpBar", quad(Vector2(2.2, 0.18)), shader_material("res://shaders/hp_bar.gdshader"),
		Vector3(0, 3.5, 0))
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node(root, "SelectRing", flat_plane(Vector2(3.4, 3.4)),
		shader_material("res://shaders/select_ring.gdshader", {"tint": Color(1.0, 0.42, 0.32)}), Vector3(0, 0.03, 0))
	save(root, "res://scenes/actors/gatekeeper.tscn")


# --- Effects --------------------------------------------------------------------

func make_fx() -> void:
	var label := Label3D.new()
	label.name = "FloatingText"
	label.font = font
	label.font_size = 64
	label.pixel_size = 0.0065
	label.outline_size = 14
	label.outline_modulate = Color(0.06, 0.04, 0.03, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 4
	label.text = "128"
	save(label, "res://scenes/fx/floating_text.tscn")
	_fx("hit_burst", quad(Vector2(1.5, 1.5)), "res://shaders/fx_burst.gdshader", 0.28, Vector3.ZERO)
	_fx("slash_arc", quad(Vector2(2.0, 2.0)), "res://shaders/fx_slash.gdshader", 0.2, Vector3.ZERO)
	_fx("ground_pulse", flat_plane(Vector2(3.0, 3.0)), "res://shaders/fx_ground_pulse.gdshader", 0.6, Vector3(0, 0.04, 0))
	var pillar := cylinder(0.75, 0.75, 4.5, 16)
	pillar.cap_top = false
	pillar.cap_bottom = false
	_fx("light_pillar", pillar, "res://shaders/fx_light_pillar.gdshader", 1.3, Vector3(0, 2.25, 0))
	_fx("ground_warning", flat_plane(Vector2(2.0, 2.0)), "res://shaders/ground_warning.gdshader", 2.0, Vector3(0, 0.05, 0))


func _fx(name: String, mesh: Mesh, shader: String, duration: float, offset: Vector3) -> void:
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	root.set_script(load("res://game/fx.gd"))
	root.duration = duration
	var m := mesh_node(root, "Mesh", mesh, shader_material(shader), offset)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	save(root, "res://scenes/fx/%s.tscn" % name)


# --- UI ---------------------------------------------------------------------------

func box_style(bg: Color, border: Color, radius: int, border_w: int = 2, margin: Vector2 = Vector2(14, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin.x
	s.content_margin_right = margin.x
	s.content_margin_top = margin.y
	s.content_margin_bottom = margin.y
	s.anti_aliasing = true
	return s


func make_theme() -> void:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 22
	var gold := Color(0.86, 0.72, 0.44, 0.75)
	t.set_stylebox("panel", "PanelContainer", box_style(Color(0.06, 0.08, 0.1, 0.8), gold, 12))
	t.set_color("font_color", "Label", Color("ede6d6"))
	t.set_color("font_outline_color", "Label", Color(0.03, 0.03, 0.04, 0.9))
	t.set_constant("outline_size", "Label", 5)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg: Color = {"normal": Color(0.1, 0.13, 0.16, 0.92), "hover": Color(0.16, 0.2, 0.24, 0.95),
			"pressed": Color(0.42, 0.33, 0.16, 0.96), "disabled": Color(0.08, 0.09, 0.1, 0.6),
			"focus": Color(0, 0, 0, 0)}[state]
		var border: Color = gold if state != "disabled" else Color(0.4, 0.38, 0.33, 0.4)
		if state == "focus":
			border = Color(1.0, 0.9, 0.6, 0.0)
		t.set_stylebox(state, "Button", box_style(bg, border, 14))
		var round := box_style(bg, border, 999, 3, Vector2(8, 8))
		t.set_stylebox(state, "RoundButton", round)
	t.set_type_variation("RoundButton", "Button")
	t.set_color("font_color", "Button", Color("f3ead6"))
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.58, 0.53, 0.7))
	t.set_color("font_pressed_color", "Button", Color("fff4d8"))
	t.set_constant("outline_size", "Button", 4)
	t.set_color("font_outline_color", "Button", Color(0.03, 0.03, 0.04, 0.85))
	t.set_stylebox("background", "ProgressBar", box_style(Color(0.03, 0.04, 0.05, 0.85), Color(0, 0, 0, 0.9), 6, 1, Vector2.ZERO))
	t.set_stylebox("fill", "ProgressBar", box_style(Color("7fcf5e"), Color(0, 0, 0, 0), 6, 0, Vector2.ZERO))
	t.set_type_variation("ExpBar", "ProgressBar")
	t.set_stylebox("fill", "ExpBar", box_style(Color("6fb7f0"), Color(0, 0, 0, 0), 4, 0, Vector2.ZERO))
	t.set_stylebox("background", "ExpBar", box_style(Color(0.02, 0.03, 0.05, 0.85), Color(0, 0, 0, 0), 4, 0, Vector2.ZERO))
	t.set_type_variation("EnemyBar", "ProgressBar")
	t.set_stylebox("fill", "EnemyBar", box_style(Color("e0614e"), Color(0, 0, 0, 0), 6, 0, Vector2.ZERO))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 30)
	t.set_color("font_color", "TitleLabel", Color("f5d991"))
	t.set_type_variation("SmallLabel", "Label")
	t.set_font_size("font_size", "SmallLabel", 18)
	t.set_color("font_color", "SmallLabel", Color("cfc7b4"))
	t.set_font_size("font_size", "CheckButton", 22)
	save_resource(t, "res://ui/theme.tres")


func label(parent: Node, name: String, text: String, unique: bool = false, variation: String = "") -> Label:
	var l := add(parent, Label.new(), name, unique) as Label
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != "":
		l.theme_type_variation = variation
	return l


func vbox(parent: Node, name: String, gap: int = 6, unique: bool = false) -> VBoxContainer:
	var b := add(parent, VBoxContainer.new(), name, unique) as VBoxContainer
	b.add_theme_constant_override("separation", gap)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func hbox(parent: Node, name: String, gap: int = 8) -> HBoxContainer:
	var b := add(parent, HBoxContainer.new(), name) as HBoxContainer
	b.add_theme_constant_override("separation", gap)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func panel(parent: Node, name: String, unique: bool = false) -> PanelContainer:
	return add(parent, PanelContainer.new(), name, unique) as PanelContainer


func button(parent: Node, name: String, text: String, size: Vector2, round_style: bool = false, toggle: bool = false) -> Button:
	var b := add(parent, Button.new(), name, true) as Button
	b.text = text
	b.custom_minimum_size = size
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	if round_style:
		b.theme_type_variation = &"RoundButton"
	return b


func bar(parent: Node, name: String, variation: String, height: float, unique: bool = true) -> ProgressBar:
	var p := add(parent, ProgressBar.new(), name, unique) as ProgressBar
	p.custom_minimum_size = Vector2(0, height)
	p.show_percentage = false
	p.value = 70
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation != "":
		p.theme_type_variation = variation
	return p


## edges = Rect2(left, top, right, bottom) offsets from the preset's anchors (not x, y, w, h).
func anchored(control: Control, preset: Control.LayoutPreset, edges: Rect2) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = edges.position.x
	control.offset_top = edges.position.y
	control.offset_right = edges.size.x
	control.offset_bottom = edges.size.y


func make_party_row() -> void:
	var row := PanelContainer.new()
	row.name = "PartyRow"
	row.set_script(load("res://ui/party_row.gd"))
	row.custom_minimum_size = Vector2(330, 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vbox(row, "Rows", 4)
	var top := hbox(v, "Top")
	label(top, "MemberName", "隊長", true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(top, "MemberState", "", true, "SmallLabel").add_theme_color_override("font_color", Color("9cf08a"))
	label(top, "MemberHp", "135 / 135", true, "SmallLabel")
	bar(v, "MemberBar", "", 14)
	save(row, "res://ui/party_row.tscn")


func make_item_row() -> void:
	var row := PanelContainer.new()
	row.name = "ItemRow"
	row.set_script(load("res://ui/item_row.gd"))
	row.custom_minimum_size = Vector2(0, 104)
	var h := hbox(row, "Row", 12)
	var text := vbox(h, "Text", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	label(text, "RowTitle", "見習長劍", true)
	label(text, "RowDetail", "攻擊 +6", true, "SmallLabel")
	var actions := hbox(h, "RowActions", 8)
	B.unique(actions)
	for i in 3:
		var b := add(actions, Button.new(), "Action%d" % i) as Button
		b.text = "動作"
		b.custom_minimum_size = Vector2(150, 96)
		b.focus_mode = Control.FOCUS_NONE
	save(row, "res://ui/item_row.tscn")


func make_camp_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "CampPanel"
	panel.set_script(load("res://ui/camp_panel.gd"))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -380
	panel.offset_bottom = 380
	var v := vbox(panel, "Rows", 10)
	var top := hbox(v, "Top", 16)
	label(top, "CampTitle", "營地", false, "TitleLabel")
	var header := label(top, "CampHeader", "金幣 0 · 倉庫 0", true)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button(top, "CampClose", "關閉", Vector2(150, 96))
	var tabs := add(v, TabContainer.new(), "CampTabs", true) as TabContainer
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 26)
	# Page node names are the tab titles (TabContainer shows a child's name).
	for page_name: String in ["補給", "倉庫", "委託", "裝備"]:
		var scroll := add(tabs, ScrollContainer.new(), page_name) as ScrollContainer
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := vbox(scroll, "List", 8)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.mouse_filter = Control.MOUSE_FILTER_PASS
	save(panel, "res://ui/camp_panel.tscn")


func make_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://ui/hud.gd"))
	var frame := add(hud, Control.new(), "Frame") as Control
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme = load("res://ui/theme.tres")

	# Top-left: resources and party.
	var top_left := vbox(frame, "TopLeft", 8)
	anchored(top_left, Control.PRESET_TOP_LEFT, Rect2(24, 20, 540, 520))
	var res := panel(top_left, "Resources")
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var res_row := hbox(res, "Row", 14)
	label(res_row, "LevelLabel", "Lv.1", true, "TitleLabel")
	label(res_row, "GoldIcon", "金幣", false, "SmallLabel").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label(res_row, "GoldLabel", "0", true)
	label(res_row, "MaterialIcon", "綠芯", false, "SmallLabel").size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label(res_row, "MaterialLabel", "0", true)
	var party_list := vbox(top_left, "PartyList", 6, true)
	for i in 3:
		add(party_list, B.instance("res://ui/party_row.tscn"), "Member%d" % (i + 1))
	var auto_potion := button(top_left, "AutoPotionButton", "自動喝藥：60% 以下", Vector2(330, 104), false, true)
	auto_potion.button_pressed = true
	var menu_row := hbox(top_left, "MenuRow", 10)
	button(menu_row, "BagButton", "背包 B", Vector2(160, 104))
	button(menu_row, "CampButton", "營地 C", Vector2(160, 104))
	button(menu_row, "RetreatButton", "撤退 T", Vector2(160, 104))

	# Top-center: target frame and status.
	var top_center := vbox(frame, "TopCenter", 6)
	anchored(top_center, Control.PRESET_CENTER_TOP, Rect2(-230, 20, 230, 140))
	var target := panel(top_center, "TargetFrame", true)
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := vbox(target, "Rows", 4)
	label(tv, "TargetName", "草原史萊姆  Lv.1", true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar(tv, "TargetBar", "EnemyBar", 16)
	var status := label(top_center, "StatusLabel", "待命", true, "SmallLabel")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Top-right: zoom and pause.
	var top_right := hbox(frame, "TopRight", 10)
	anchored(top_right, Control.PRESET_TOP_RIGHT, Rect2(-366, 20, -24, 124))
	top_right.alignment = BoxContainer.ALIGNMENT_END
	button(top_right, "ZoomInButton", "＋", Vector2(104, 104), true)
	button(top_right, "ZoomOutButton", "－", Vector2(104, 104), true)
	button(top_right, "PauseButton", "暫停", Vector2(104, 104), true)

	# Left-middle: quest tracker.
	var quest := panel(frame, "QuestPanel")
	# Right side, between the top-right buttons and the action cluster; the left holds the party and the log.
	anchored(quest, Control.PRESET_CENTER_RIGHT, Rect2(-388, -300, -24, -70))
	var qv := vbox(quest, "Rows", 6)
	label(qv, "QuestTitle", "委託 · 草原清掃", false, "TitleLabel")
	label(qv, "QuestProgress", "草原史萊姆  0 / 5", true)
	label(qv, "QuestReward", "報酬  50 EXP · 30 金幣", true, "SmallLabel")
	button(qv, "ClaimButton", "回報委託", Vector2(0, 104))

	# Bottom-left: combat log above the EXP bar.
	var feed := vbox(frame, "Feed", 2, true)
	anchored(feed, Control.PRESET_BOTTOM_LEFT, Rect2(28, -220, 820, -52))
	feed.alignment = BoxContainer.ALIGNMENT_END
	for i in 5:
		var line := label(feed, "Line%d" % i, "", false, "SmallLabel")
		line.add_theme_constant_override("outline_size", 6)
	var exp_box := add(frame, Control.new(), "ExpRow") as Control
	anchored(exp_box, Control.PRESET_BOTTOM_WIDE, Rect2(0, -30, 0, 0))
	exp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var exp_bar := bar(exp_box, "ExpBar", "ExpBar", 30)
	exp_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var exp_label := label(exp_box, "ExpLabel", "EXP 0 / 200", true, "SmallLabel")
	exp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Bottom-right: the action cluster (thumb zone on phones).
	var cluster := add(frame, Control.new(), "ActionCluster", true) as Control
	anchored(cluster, Control.PRESET_BOTTOM_RIGHT, Rect2(-420, -362, -24, -44))
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skill := button(cluster, "SkillButton", "", Vector2(164, 164), true)
	skill.position = Vector2(232, 154)
	var ring := add(skill, TextureProgressBar.new(), "SkillCooldown", true) as TextureProgressBar
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.fill_mode = TextureProgressBar.FILL_COUNTER_CLOCKWISE
	ring.texture_progress = _disc_texture(Color(0.02, 0.03, 0.05, 0.78))
	ring.nine_patch_stretch = true
	ring.value = 0
	var skill_label := label(skill, "SkillName", "裂空斬\nQ", false)
	skill_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var skill_time := label(skill, "SkillTime", "", true, "TitleLabel")
	skill_time.set_anchors_preset(Control.PRESET_FULL_RECT)
	skill_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_time.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var auto := button(cluster, "AutoButton", "", Vector2(124, 124), true, true)
	auto.position = Vector2(92, 194)
	var auto_label := label(auto, "AutoLabel", "自動\n狩獵", true)
	auto_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	auto_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for spec: Array in [["TonicButton", "TonicCount", "藥水 E", Vector2(118, 58)], ["EmergencyButton", "EmergencyCount", "急救 R", Vector2(262, 14)]]:
		var b := button(cluster, spec[0], "", Vector2(110, 110), true)  # ≥104 design px = 44 pt on a 390 pt phone
		b.position = spec[3]
		var name_label := label(b, "Name", spec[2], false, "SmallLabel")
		name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_label.offset_top = 22
		var count := label(b, spec[1], "×5", true, "TitleLabel")
		count.set_anchors_preset(Control.PRESET_FULL_RECT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.offset_bottom = -18

	# Center: toast.
	var toast := label(frame, "Toast", "", true, "TitleLabel")
	anchored(toast, Control.PRESET_CENTER_TOP, Rect2(-400, 170, 400, 220))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 8)

	_modal(frame, "PausePanel", "暫停", func(v: VBoxContainer) -> void:
		button(v, "ResumeButton", "繼續冒險", Vector2(360, 104))
		button(v, "PauseRestartButton", "重新開始本輪", Vector2(360, 104))
		label(v, "SettingsTitle", "設定", false, "SmallLabel")
		for spec: Array in [["DamageNumbersCheck", "傷害數字", "damage_numbers"], ["ShakeCheck", "畫面震動", "screen_shake"], ["HapticsCheck", "手機震動", "haptics"]]:
			var c := add(v, CheckButton.new(), spec[0], true) as CheckButton
			c.text = spec[1]
			c.button_pressed = true
			c.custom_minimum_size = Vector2(360, 104)
			c.focus_mode = Control.FOCUS_NONE
			c.set_meta("setting", spec[2]))
	_modal(frame, "TripPanel", "遠征結算", func(v: VBoxContainer) -> void:
		var trip := label(v, "TripSummary", "擊倒 0 隻", true)
		trip.custom_minimum_size = Vector2(560, 0)
		trip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button(v, "TripClose", "好", Vector2(360, 104)))
	var camp_dim := add(frame, ColorRect.new(), "CampLayer", true) as ColorRect
	camp_dim.color = Color(0.02, 0.03, 0.05, 0.5)
	camp_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add(camp_dim, B.instance("res://ui/camp_panel.tscn"), "CampPanel")
	_modal(frame, "RotatePanel", "請將手機轉為橫向", func(v: VBoxContainer) -> void:
		label(v, "RotateHint", "橫向畫面才能看清戰場，冒險已暫停。", false).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER)
	_modal(frame, "EndPanel", "冒險結束", func(v: VBoxContainer) -> void:
		var summary := label(v, "EndSummary", "抵達 Lv.1 · 擊倒 0 隻", true)
		summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.custom_minimum_size = Vector2(520, 0)
		button(v, "RestartButton", "再出發一次", Vector2(360, 104)))
	save(hud, "res://ui/hud.tscn", ["res://ui/party_row.tscn", "res://ui/camp_panel.tscn"])


func _modal(frame: Control, name: String, title: String, fill: Callable) -> void:
	var dim := add(frame, ColorRect.new(), name, true) as ColorRect
	dim.color = Color(0.02, 0.03, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := add(dim, CenterContainer.new(), "Center") as CenterContainer
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := panel(center, "Box")
	var v := vbox(box, "Rows", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	label(v, "Title", title, false, "TitleLabel").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fill.call(v)


func _disc_texture(color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.96, 1.0])
	g.colors = PackedColorArray([color, color, Color(color, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


# --- Field ------------------------------------------------------------------------

func make_field() -> void:
	var field := Node3D.new()
	field.name = "Field"
	field.set_script(load("res://game/field.gd"))

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5f9fd8")
	sky_mat.sky_horizon_color = Color("cfe3ee")
	sky_mat.ground_horizon_color = Color("cfe3ee")
	sky_mat.ground_bottom_color = Color("8fbfe0")
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color("c9dde9")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	var world := add(field, WorldEnvironment.new(), "WorldEnvironment") as WorldEnvironment
	world.environment = env

	var sun := add(field, DirectionalLight3D.new(), "Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.7
	sun.directional_shadow_max_distance = 60.0

	# Floating island: grass top, faceted cliff skirt, scattered edge rocks.
	var ground_mat := shader_material("res://materials/meadow.gdshader")
	var ground := mesh_node(field, "Ground", flat_plane(Vector2(34, 24)), ground_mat)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cliffs := add(field, Node3D.new(), "Cliffs") as Node3D
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var edge_points: Array[Vector2] = []
	for i in 13:
		edge_points.append(Vector2(-17.0 + i * 34.0 / 12.0, -12.0))
		edge_points.append(Vector2(-17.0 + i * 34.0 / 12.0, 12.0))
	for i in 9:
		edge_points.append(Vector2(-17.0, -12.0 + i * 24.0 / 8.0))
		edge_points.append(Vector2(17.0, -12.0 + i * 24.0 / 8.0))
	var rim := _multimesh(cliffs, "Rim", lowpoly("cliff"), edge_points.size())
	for i in edge_points.size():
		var p: Vector2 = edge_points[i]
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(rng.randf_range(2.2, 3.0), rng.randf_range(4.6, 6.0), rng.randf_range(2.2, 3.0)))
		rim.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(p.x, -2.4, p.y)))
	var under := mesh_node(cliffs, "Underside", lowpoly("cliff"), vertex_color_material(), Vector3(0, -3.2, 0))
	under.scale = Vector3(19, 6, 13)

	var props := add(field, Node3D.new(), "Props", true) as Node3D
	var layout := [
		["arch", Vector3(-12.5, 0, -8.6), 0.0, 1.0], ["blocker", Vector3(-14.2, 0, -8.6), 0.0, 1.0],
		["blocker", Vector3(-10.8, 0, -8.6), 0.0, 1.0],
		["oak", Vector3(-15.0, 0, 6.5), 0.0, 1.1], ["oak", Vector3(13.8, 0, -8.2), 40.0, 1.2], ["oak", Vector3(4.5, 0, 9.4), 10.0, 1.0],
		["pine", Vector3(-15.6, 0, -2.0), 0.0, 1.0], ["pine", Vector3(15.4, 0, 3.5), 0.0, 1.15], ["pine", Vector3(10.5, 0, 9.6), 0.0, 0.9],
		["boulder", Vector3(-3.5, 0, -2.2), 20.0, 1.0], ["boulder", Vector3(6.0, 0, 4.2), 70.0, 1.2], ["boulder", Vector3(1.5, 0, -7.0), 0.0, 0.8],
		["pillar_broken", Vector3(-6.5, 0, 5.0), 30.0, 1.0], ["pillar_broken", Vector3(9.0, 0, -3.0), 120.0, 1.0],
		["pillar", Vector3(2.0, 0, 2.5), 0.0, 1.0], ["wall", Vector3(-1.0, 0, 7.6), 8.0, 1.0], ["wall", Vector3(11.5, 0, 6.4), -30.0, 1.0],
		["crystal", Vector3(12.5, 0, -1.0), 0.0, 1.0], ["crystal", Vector3(-9.5, 0, -6.0), 45.0, 0.8],
	]
	var counts := {}
	for spec: Array in layout:
		var kind: String = spec[0]
		counts[kind] = int(counts.get(kind, 0)) + 1
		var prop := add(props, B.instance("res://scenes/props/%s.tscn" % kind), "%s%d" % [kind.to_pascal_case(), counts[kind]]) as Node3D
		prop.position = spec[1]
		prop.rotation_degrees.y = spec[2]
		prop.scale = Vector3.ONE * spec[3]
	# Grass: one MultiMesh of blades (one draw call), clumped into tufts.
	var blades := _multimesh(field, "Grass", lowpoly("blade"), 46 * 7)
	blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var i := 0
	for tuft in 46:
		var centre := Vector3(rng.randf_range(-16, 16), 0, rng.randf_range(-11, 11))
		var size := rng.randf_range(0.8, 1.4)
		for b in 7:
			var tilt := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-18, 18)), rng.randf_range(0, TAU),
				deg_to_rad(rng.randf_range(-18, 18)))).scaled(Vector3.ONE * size * rng.randf_range(0.7, 1.3))
			var offset := Vector3(rng.randf_range(-0.3, 0.3), 0.2 * size, rng.randf_range(-0.3, 0.3))
			blades.multimesh.set_instance_transform(i, Transform3D(tilt, centre + offset))
			i += 1

	var camp := add(field, B.instance("res://scenes/camp.tscn"), "Camp", true) as Node3D
	camp.position = Vector3(-11.0, 0, 0.6)
	for spec: Array in [["tent", Vector3(-13.2, 0, -1.4), 30.0], ["campfire", Vector3(-11.0, 0, 1.6), 0.0],
			["banner", Vector3(-8.6, 0, -1.6), 0.0]]:
		var piece := add(props, B.instance("res://scenes/props/%s.tscn" % spec[0]), String(spec[0]).to_pascal_case()) as Node3D
		piece.position = spec[1]
		piece.rotation_degrees.y = spec[2]

	var party := add(field, Node3D.new(), "Party", true) as Node3D
	for spec: Array in [["Leader", "leader", Vector3(-10.4, 0, 0.2)], ["Guardian", "guardian", Vector3(-11.8, 0, 0.9)], ["Support", "support", Vector3(-9.6, 0, 1.4)]]:
		_place_actor(party, spec[0], spec[1], spec[2])
	var monsters := add(field, Node3D.new(), "Monsters", true) as Node3D
	var spawns := [
		["meadow_slime", Vector3(-5.5, 0, 1.5)], ["meadow_slime", Vector3(-6.0, 0, -4.0)], ["meadow_slime", Vector3(-1.0, 0, 4.5)],
		["meadow_slime", Vector3(-2.0, 0, -5.5)], ["briar_boar", Vector3(3.5, 0, -3.5)], ["briar_boar", Vector3(5.5, 0, 1.0)],
		["briar_boar", Vector3(1.0, 0, 6.0)], ["ruin_hound", Vector3(10.0, 0, 1.5)], ["ruin_hound", Vector3(8.0, 0, 5.5)],
	]
	var m := 0
	for spec: Array in spawns:
		m += 1
		_place_actor(monsters, "%s%d" % [String(spec[0]).to_pascal_case(), m], spec[0], spec[1])

	var boss := add(monsters, B.instance("res://scenes/actors/gatekeeper.tscn"), "Gatekeeper") as Node3D
	boss.position = Vector3(11.5, 0, -6.0)
	boss.rotation_degrees.y = -135.0

	var marker := mesh_node(field, "MoveMarker", flat_plane(Vector2(1.2, 1.2)),
		shader_material("res://shaders/select_ring.gdshader", {"tint": Color(0.5, 0.9, 1.0), "dashes": 6.0, "speed": 1.5}))
	B.unique(marker)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.visible = false
	add(field, Node3D.new(), "Effects", true)

	var rig := add(field, Node3D.new(), "CameraRig", true) as Node3D
	rig.position = Vector3(-10.4, 0, 0.2)
	rig.rotation_degrees.y = 0.0
	var cam := add(rig, Camera3D.new(), "Camera", true) as Camera3D
	cam.fov = 34.0
	cam.near = 0.3
	cam.far = 200.0
	cam.set_meta("pitch_deg", 40.0)
	var pitch := deg_to_rad(40.0)
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * 15.0
	cam.rotation_degrees.x = -40.0

	var sfx := add(field, Node.new(), "Sfx", true)
	sfx.set_script(load("res://game/sfx.gd"))
	var time := add(field, Node.new(), "TimeControl", true)
	time.set_script(load("res://addons/proto_kit/time_control.gd"))
	time.process_mode = Node.PROCESS_MODE_ALWAYS
	add(field, B.instance("res://ui/hud.tscn"), "HUD")
	var refs := ["res://scenes/actors/actor.tscn", "res://ui/hud.tscn", "res://scenes/props/oak.tscn",
		"res://scenes/camp.tscn", "res://scenes/actors/gatekeeper.tscn"]
	save(field, "res://scenes/field.tscn", refs)


func _multimesh(parent: Node, name: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var node := add(parent, MultiMeshInstance3D.new(), name) as MultiMeshInstance3D
	node.multimesh = mm
	node.material_override = vertex_color_material()
	return node


func _place_actor(parent: Node, node_name: String, kind: String, at: Vector3) -> void:
	var spec: Dictionary = ACTORS[kind]
	var actor := add(parent, B.instance("res://scenes/actors/actor.tscn"), node_name) as Node3D
	actor.position = at
	actor.kind_id = kind
	actor.sheet = load("res://resources/sheets/%s.tres" % kind)
	actor.dissolve_on_down = spec.dissolve
	actor.head_height = spec.head
	if spec.party:
		actor.nameplate_color = Color("bfe6ff") if kind != "leader" else Color("ffe4a3")
		actor.show_nameplate = kind == "leader"
