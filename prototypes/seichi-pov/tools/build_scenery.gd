extends SceneTree
## Production tool: places the village, trees and far mountains from layout.json and
## baked/cliff_top.json, then saves spots/hokage_rock/baked/scenery.tscn + *.res.
## The game never runs this. Re-running overwrites scenery.tscn, so diff it first.
##
##   godot --path prototypes/seichi-pov --script res://tools/build_scenery.gd
## Run it WITHOUT --headless: the dummy renderer drops MultiMesh instance data, and the
## saved .res would hold all-zero transforms.

const SPOT := "res://spots/hokage_rock/"
const OUT := SPOT + "baked/"
const SEED := 11

const WALLS := [Color(0.80, 0.76, 0.66), Color(0.76, 0.72, 0.62), Color(0.84, 0.80, 0.71), Color(0.70, 0.64, 0.53)]
const ROOFS := [Color(0.70, 0.27, 0.20), Color(0.66, 0.40, 0.24), Color(0.32, 0.50, 0.50), Color(0.58, 0.30, 0.22), Color(0.45, 0.33, 0.28)]
const LEAVES := [Color(0.24, 0.40, 0.18), Color(0.30, 0.46, 0.20), Color(0.20, 0.34, 0.17), Color(0.34, 0.48, 0.24)]

var rng := RandomNumberGenerator.new()
var layout: Dictionary
var cliff_edge: Array


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("build_scenery.gd must run without --headless (MultiMesh data would be lost)")
		quit(1)
		return
	rng.seed = SEED
	layout = JSON.parse_string(FileAccess.get_file_as_string(SPOT + "layout.json"))
	cliff_edge = JSON.parse_string(FileAccess.get_file_as_string(OUT + "cliff_top.json"))["edge"]

	var houses := _place_houses()
	var trees := _place_trees(houses.parks)

	var root := Node3D.new()
	root.name = "Scenery"
	var vc_mat := StandardMaterial3D.new()
	vc_mat.vertex_color_use_as_albedo = true
	vc_mat.vertex_color_is_srgb = true
	vc_mat.roughness = 0.9
	ResourceSaver.save(vc_mat, OUT + "vertex_color_mat.tres")
	vc_mat = load(OUT + "vertex_color_mat.tres")

	var box := BoxMesh.new()
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 12
	cyl.rings = 0
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	var tank := CylinderMesh.new()
	tank.radial_segments = 8
	tank.rings = 0
	tank.top_radius = 1.0
	tank.bottom_radius = 1.0
	tank.height = 1.0
	var canopy := SphereMesh.new()
	canopy.radial_segments = 6
	canopy.rings = 2
	canopy.radius = 1.0
	canopy.height = 2.0

	var sets := {
		"HouseWalls": [box, houses.walls],
		"HouseRoofs": [box, houses.roofs],
		"Towers": [cyl, houses.towers],
		"TowerCaps": [cyl, houses.caps],
		"Tanks": [tank, houses.tanks],
	}
	# trees split by region so the camera cone culls whole groups; they cast no shadow
	for region: String in trees:
		sets["Trees" + region] = [canopy, trees[region]]
	for node_name: String in sets:
		var pair: Array = sets[node_name]
		var mm := _multimesh(pair[0], pair[1])
		var path := OUT + node_name.to_snake_case() + ".multimesh.res"
		ResourceSaver.save(mm, path)
		var back: MultiMesh = load(path)
		if back.instance_count != pair[1].size() or not back.get_instance_transform(0).is_equal_approx(pair[1][0][0]):
			push_error("read-back mismatch: " + path)
			quit(1)
			return
		var inst := MultiMeshInstance3D.new()
		inst.name = node_name
		inst.multimesh = load(path)
		inst.material_override = vc_mat
		if node_name.begins_with("Trees"):
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(inst)
		inst.owner = root
		print("%s: %d instances" % [node_name, pair[1].size()])

	for ring: Dictionary in [
		{"name": "Hills", "radii": [620.0, 760.0, 980.0], "h": [25.0, 95.0], "segments": 72, "seed": 5},
		{"name": "Mountains", "radii": [1300.0, 1750.0, 2400.0], "h": [140.0, 360.0], "segments": 96, "seed": 9},
	]:
		var mesh := _ring_mesh(ring)
		var mpath: String = OUT + String(ring.name).to_snake_case() + ".mesh.res"
		ResourceSaver.save(mesh, mpath)
		var mi := MeshInstance3D.new()
		mi.name = ring.name
		mi.mesh = load(mpath)
		mi.material_override = vc_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.owner = root

	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, OUT + "scenery.tscn")
	print("scenery.tscn saved: ", error_string(err), " nodes=", root.get_child_count())
	root.free()
	quit(0 if err == OK else 1)


# ------------------------------------------------------------------ layout queries
func _road_clearance(p: Vector2) -> float:
	## Distance from p to the nearest road edge (negative inside a road or plaza).
	var best := INF
	for road: Dictionary in layout.roads:
		var pts: Array = road.pts
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - float(road.w) * 0.5
			best = minf(best, d)
	for plaza: Dictionary in layout.plazas:
		best = minf(best, p.distance_to(Vector2(plaza.c[0], plaza.c[1])) - float(plaza.r))
	return best


func _cliff_z(x: float) -> float:
	## Face z of the cliff at x (wings curve toward the village).
	var ax := absf(x)
	return 0.0 if ax < 180.0 else pow((ax - 180.0) / 250.0, 2.0) * 60.0


func _in_village(p: Vector2) -> bool:
	var v: Dictionary = layout.village
	return p.x > v.x0 and p.x < v.x1 and p.y > v.z0 and p.y < v.z1


# ------------------------------------------------------------------ placement
func _place_houses() -> Dictionary:
	var out := {"walls": [], "roofs": [], "towers": [], "caps": [], "tanks": [], "parks": []}
	var v: Dictionary = layout.village
	var step := 15.0
	var z: float = v.z0 + v.cliff_gap
	while z < v.z1:
		var x: float = v.x0
		while x < v.x1:
			var p := Vector2(x + rng.randf_range(-4, 4), z + rng.randf_range(-4, 4))
			x += step
			if p.y < _cliff_z(p.x) + v.cliff_gap or _road_clearance(p) < 6.5:
				continue
			if rng.randf() < 0.12:
				out.parks.append(p)
				continue
			var centre := clampf(1.0 - p.length() / 420.0, 0.0, 1.0)
			var roof: Color = ROOFS[rng.randi() % ROOFS.size()]
			var wall: Color = WALLS[rng.randi() % WALLS.size()]
			var top: float
			var footprint: float
			if rng.randf() < 0.28:
				var r := rng.randf_range(3.5, 5.5)
				var h := rng.randf_range(7.0, 12.0) + 6.0 * centre
				out.towers.append([Transform3D(Basis.from_scale(Vector3(r, h, r)), Vector3(p.x, h * 0.5, p.y)), wall])
				out.caps.append([Transform3D(Basis.from_scale(Vector3(r + 0.5, 0.7, r + 0.5)), Vector3(p.x, h + 0.35, p.y)), roof])
				top = h + 0.7
				footprint = r * 0.6
			else:
				var w := rng.randf_range(7.0, 11.0)
				var d := rng.randf_range(7.0, 11.0)
				var h := rng.randf_range(5.0, 9.0) + 5.0 * centre
				var yaw := deg_to_rad(rng.randf_range(-8, 8))
				var basis := Basis(Vector3.UP, yaw)
				out.walls.append([Transform3D(basis.scaled_local(Vector3(w, h, d)), Vector3(p.x, h * 0.5, p.y)), wall])
				out.roofs.append([Transform3D(basis.scaled_local(Vector3(w + 1.0, 0.7, d + 1.0)), Vector3(p.x, h + 0.35, p.y)), roof])
				top = h + 0.7
				footprint = minf(w, d) * 0.3
			if rng.randf() < 0.35:
				var tr := rng.randf_range(1.1, 1.7)
				var th := rng.randf_range(2.0, 2.6)
				var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * footprint
				out.tanks.append([Transform3D(Basis.from_scale(Vector3(tr, th, tr)), Vector3(p.x + off.x, top + th * 0.5, p.y + off.y)), Color(0.80, 0.84, 0.86)])
		z += step
	return out


func _tree(out: Array, pos: Vector3, scale: float) -> void:
	var r := rng.randf_range(3.5, 6.5) * scale
	var basis := Basis.from_scale(Vector3(r, r * rng.randf_range(1.0, 1.35), r))
	var c: Color = LEAVES[rng.randi() % LEAVES.size()]
	c = c.lightened(rng.randf_range(-0.05, 0.08))
	out.append([Transform3D(basis, pos + Vector3(0, r * 1.05, 0)), c])


func _tree_region(p: Vector3) -> String:
	if p.y > 3.0:
		return "CliffTop"
	if p.z > 200.0:
		return "Behind"
	return "Left" if p.x < 0.0 else "Right"


func _place_trees(parks: Array) -> Dictionary:
	var out := []
	for p: Vector2 in parks:
		for i in 3:
			_tree(out, Vector3(p.x + rng.randf_range(-5, 5), 0, p.y + rng.randf_range(-5, 5)), 0.8)
	# belt around the village, thinning outward
	var tries := 0
	while tries < 2600:
		tries += 1
		var p := Vector2(rng.randf_range(-560, 560), rng.randf_range(-20, 640))
		if _in_village(p) or p.y < _cliff_z(p.x) + 6.0 or _road_clearance(p) < 3.0:
			continue
		_tree(out, Vector3(p.x, 0, p.y), 1.0)
	# forest on the cliff top, just behind the edge
	for e: Array in cliff_edge:
		var top: float = e[1]
		if top < 4.0:
			continue
		for i in rng.randi_range(1, 3):
			var back := rng.randf_range(5.0, 45.0)
			_tree(out, Vector3(float(e[0]) + rng.randf_range(-2.5, 2.5), top, float(e[2]) - back), 1.1)
	var regions := {}
	for item: Array in out:
		var key := _tree_region((item[0] as Transform3D).origin - Vector3(0, (item[0] as Transform3D).basis.y.length() * 1.05, 0))
		if not regions.has(key):
			regions[key] = []
		regions[key].append(item)
	return regions


func _multimesh(mesh: Mesh, items: Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	return mm


func _ring_mesh(cfg: Dictionary) -> ArrayMesh:
	## Closed ring of ridges around the valley: inner foot, crest, outer foot.
	var noise := FastNoiseLite.new()
	noise.seed = cfg.seed
	noise.frequency = 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector2(0, 150)
	var n: int = cfg.segments
	var radii: Array = cfg.radii
	var hmin: float = cfg.h[0]
	var hmax: float = cfg.h[1]
	var rows := []
	for i in n + 1:
		var a := TAU * float(i % n) / n
		var dir := Vector2(sin(a), cos(a))
		var k := (noise.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0) + 1.0) * 0.5
		var crest := lerpf(hmin, hmax, k)
		var r_crest := lerpf(float(radii[1]), float(radii[1]) + 120.0, noise.get_noise_2d(a * 3.0, 7.0))
		var foot: Vector2 = centre + dir * float(radii[0])
		var mid := centre + dir * r_crest
		var back: Vector2 = centre + dir * float(radii[2])
		rows.append([Vector3(foot.x, -2.0, foot.y), Vector3(mid.x, crest, mid.y), Vector3(back.x, crest * 0.35, back.y)])
	var low := Color(0.22, 0.33, 0.20)
	var high := Color(0.42, 0.48, 0.45)
	for i in n:
		for j in 2:
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i + 1][j]
			var c: Vector3 = rows[i + 1][j + 1]
			var d: Vector3 = rows[i][j + 1]
			for tri: Array in [[a, c, b], [a, d, c]]:
				for p: Vector3 in tri:
					st.set_color(low.lerp(high, clampf(p.y / hmax, 0, 1)))
					st.add_vertex(p)
	st.generate_normals()
	return st.commit()
