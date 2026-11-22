extends SceneTree
## Authoring tool: writes the city item scenes in scenes/buildings/ (maps instance them): ruined blocks,
## skyline towers and street props (T-wall roadblock, elevated rail, lamp, utility pole, wrecked car,
## signboard), and the detailed mesh of ruined_wall.tscn's main slab.
##   godot --headless --path . --script res://tools/build_ruined_buildings.gd
## Each building is a grid of bays; every bay has its own floor count, so one corner can be collapsed.
## A façade is piers + spandrels (window holes show the dark interior or, on towers, glass); the
## ground floor is a storefront with half-closed shutters; broken bays get jagged pier stubs and rebar,
## and rubble piles at the collapsed corner. Towers are one box per bay with the window grid painted by
## shaders/tower_windows.gdshader (they are only seen from far away). All boxes merge into one mesh per material (3 draw calls
## per building), saved to assets/buildings/*.res.
## The scenes hold only the merged meshes and per-bay collision, so re-running overwrites them;
## move or rotate buildings in the map scenes, not here.
const B := preload("res://addons/proto_kit/scene_builder.gd")
const Concrete := preload("res://materials/weathered_concrete.tres")
const Steel := preload("res://materials/burnt_steel.tres")
const Rust := preload("res://materials/rusted_armor.tres")
const Cover := preload("res://scripts/breakable_cover.gd")
const OUT := "res://assets/buildings/"

var rng := RandomNumberGenerator.new()
var parts := {}  # material key -> SurfaceTool
var box_mesh := BoxMesh.new()

## id, bays (x, z), bay size (m), storey (m), floors, collapse (0..1), seed, tower, collapse corner (+x side, z sign)
const VARIANTS := [
	["ruined_block_a", Vector2i(4, 4), Vector2(3.25, 4.0), 4.0, 4, 0.75, 11, false, -1.0],
	["ruined_block_b", Vector2i(4, 4), Vector2(3.25, 4.0), 4.0, 5, 0.6, 23, false, 1.0],
	["ruined_block_c", Vector2i(4, 4), Vector2(3.25, 4.0), 4.0, 7, 0.55, 37, false, 0.0],
	["skyline_tower_a", Vector2i(5, 5), Vector2(3.6, 4.0), 3.6, 10, 0.35, 41, true, -1.0],
	["skyline_tower_b", Vector2i(5, 5), Vector2(3.6, 4.0), 3.6, 15, 0.45, 53, true, 1.0],
	["skyline_tower_c", Vector2i(5, 5), Vector2(3.6, 4.0), 3.6, 21, 0.3, 67, true, 0.0],
]

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var interior := StandardMaterial3D.new()
	interior.albedo_color = Color("#0f1113")
	interior.roughness = 1.0
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#22323d")
	glass.metallic = 0.7
	glass.roughness = 0.18
	DirAccess.make_dir_recursive_absolute(OUT)
	ResourceSaver.save(interior, "res://materials/ruin_interior.tres")
	ResourceSaver.save(glass, "res://materials/ruin_glass.tres")
	var sign := StandardMaterial3D.new()
	sign.albedo_color = Color("#7d3a2a")
	sign.roughness = 0.9
	ResourceSaver.save(sign, "res://materials/ruin_sign.tres")
	var ok := true
	for v: Array in VARIANTS:
		var fill: Material = load("res://materials/ruin_interior.tres")
		if v[7]:
			var windows := ShaderMaterial.new()
			windows.shader = load("res://shaders/tower_windows.gdshader")
			windows.set_shader_parameter("cell", Vector3(v[2].x, v[3], v[2].y))
			windows.set_shader_parameter("origin", Vector3(-v[1].x * v[2].x * 0.5, 0, -v[1].y * v[2].y * 0.5))
			fill = windows
		ok = _building(v, fill) and ok
	ok = _props(load("res://materials/ruin_interior.tres"), load("res://materials/ruin_sign.tres")) and ok
	quit(0 if ok else 1)

func box(key: String, size: Vector3, center: Vector3, rot := Vector3.ZERO) -> void:
	if not parts.has(key):
		parts[key] = SurfaceTool.new()
		parts[key].begin(Mesh.PRIMITIVE_TRIANGLES)
	box_mesh.size = size
	parts[key].append_from(box_mesh, 0, Transform3D(Basis.from_euler(rot), center))

func _building(v: Array, fill: Material) -> bool:
	var id: String = v[0]
	var bays: Vector2i = v[1]
	var bay: Vector2 = v[2]
	var storey: float = v[3]
	var floors: int = v[4]
	var collapse: float = v[5]
	var tower: bool = v[7]
	rng.seed = v[6]
	parts.clear()
	var size := Vector2(bays.x * bay.x, bays.y * bay.y)
	# Collapse profile: bays near the broken corner lose floors; a few others lose their top floor.
	var corner := Vector2(bays.x - 0.5, (bays.y - 1) * (0.5 + 0.5 * v[8]))
	var reach := maxf(bays.x, bays.y) * collapse * 1.4
	var h := {}
	for i in bays.x:
		for j in bays.y:
			var d := Vector2(i, j).distance_to(corner)
			var cut := int(round((1.0 - d / reach) * floors * collapse * 1.3)) if d < reach else 0
			if rng.randf() < 0.3: cut += 1
			h[Vector2i(i, j)] = clampi(floors - cut, 1, floors)
	var height := func(c: Vector2i) -> int: return h.get(c, 0)
	var t := 0.35 if not tower else 0.25          # façade thickness
	var pier := 0.45 if not tower else 0.18       # half a pier at each bay edge
	var spandrel := 1.3 if not tower else 0.8
	var blast := Vector3i(bays.x - 1, rng.randi_range(0, bays.y - 1), rng.randi_range(1, maxi(1, floors - 3)))
	var body := StaticBody3D.new()
	body.name = id.to_pascal_case()
	body.collision_layer = 1
	for c: Vector2i in h:
		var top: int = h[c]
		var center := Vector3(-size.x * 0.5 + (c.x + 0.5) * bay.x, 0, -size.y * 0.5 + (c.y + 0.5) * bay.y)
		var damaged := top < floors
		var perimeter := c.x == 0 or c.y == 0 or c.x == bays.x - 1 or c.y == bays.y - 1
		if tower:  # far away: one painted box per bay
			box("fill", Vector3(bay.x, top * storey, bay.y), center + Vector3.UP * (top * storey * 0.5))
			if damaged: _roof(center, bay, top * storey, true, true, perimeter)
			continue
		# Dark interior behind the window holes; the roof slab caps every bay.
		if perimeter: box("fill", Vector3(bay.x - 1.0, top * storey - 0.3, bay.y - 1.0), center + Vector3.UP * (top * storey * 0.5))
		_roof(center, bay, top * storey, damaged, tower, perimeter)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(bay.x, top * storey, bay.y)
		collision.shape = shape
		collision.position = center + Vector3.UP * (top * storey * 0.5)
		if not tower: B.add(body, collision, "Bay%d_%d" % [c.x, c.y])
		else: collision.free()
		for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var lower: int = height.call(c + Vector2i(int(n.x), int(n.z)))
			if lower >= top: continue
			var along := Vector3(-n.z, 0, n.x)
			var width := bay.y if n.x != 0.0 else bay.x
			var face := center + n * ((bay.x if n.x != 0.0 else bay.y) * 0.5 - t * 0.5)
			var dims := func(w: float, hh: float) -> Vector3: return (along.abs() * w + n.abs() * t + Vector3.UP * hh)
			for f in range(lower, top):
				var y := f * storey
				var hole := not tower and c.x == blast.x and c.y == blast.y and f == blast.z and n == Vector3.RIGHT
				var last := f == top - 1 and damaged
				for edge: float in [-1.0, 1.0]:  # piers at both bay edges; neighbours add up to one column
					var ph := storey if not (last and rng.randf() < 0.5) else storey * rng.randf_range(0.3, 0.8)
					if hole and edge > 0: ph = storey * 0.4
					box("concrete", dims.call(pier, ph), face + along * edge * (width - pier) * 0.5 + Vector3.UP * (y + ph * 0.5))
				if f == 0 and not tower:
					_storefront(face, along, n, width - pier * 2.0, storey)
				elif not hole:
					var sw := width if not last else width * rng.randf_range(0.4, 1.0)
					box("concrete", dims.call(sw, spandrel), face + along * (width - sw) * 0.5 * signf(rng.randf() - 0.5) + Vector3.UP * (y + spandrel * 0.5))
				if hole:
					box("concrete", Vector3(bay.x - 0.6, 0.3, bay.y - 0.6), center + Vector3.UP * y)
					_rubble(center + Vector3.UP * (y + 0.15) + n * 0.8, 1.2, 4, 0.7)
	if not tower:
		var pile := Vector3(size.x * 0.5 + 1.0, 0, -size.y * 0.5 + (corner.y + 0.5) * bay.y)
		_rubble(pile, 4.0, int(10 + 18 * collapse), 1.4)
		for k in 2:  # fallen slab pieces leaning on the pile
			box("concrete", Vector3(rng.randf_range(3, 5), 0.3, rng.randf_range(2, 3.5)),
				pile + Vector3(rng.randf_range(0.5, 2.5), 0.9, rng.randf_range(-3, 3)),
				Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0, TAU), rng.randf_range(0.35, 0.7)))
	if not _merge(id, body, {"concrete": Concrete, "steel": Steel, "fill": fill}, not tower): return false
	return B.save_scene(body, "res://scenes/buildings/%s.tscn" % id, {"overwrite": true}).ok

## Commits the boxes collected so far into one mesh per material, saved as assets/buildings/<id>_<key>.res.
## Breakable props get material_override so a falling section keeps its texture (breakable_cover.gd).
func _merge(id: String, body: Node3D, materials: Dictionary, shadows := true, override := false, fade := 0.0) -> bool:
	for key: String in materials:
		if not parts.has(key): continue
		var mesh: ArrayMesh = parts[key].commit()
		mesh.surface_set_material(0, materials[key])
		var path := OUT + "%s_%s.res" % [id, key]
		if ResourceSaver.save(mesh, path) != OK: return false
		var shown := MeshInstance3D.new()
		shown.mesh = load(path)
		if override: shown.material_override = materials[key]
		if not shadows: shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if fade > 0.0: shown.visibility_range_end = fade  # small props drop out past this distance
		B.add(body, shown, key.capitalize())
	parts.clear()
	return true

func _collider(body: Node3D, label: String, size: Vector3, center: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = center
	B.add(body, collision, label)

func _save_prop(id: String, body: Node3D, materials: Dictionary, override := false, shadows := true, fade := 0.0) -> bool:
	body.name = id.to_pascal_case()
	return _merge(id, body, materials, shadows, override, fade) and B.save_scene(body, "res://scenes/buildings/%s.tscn" % id, {"overwrite": true}).ok

## Street props, origin on the ground. Real-world sizes: the walker needs them for scale.
func _props(dark: Material, sign: Material) -> bool:
	rng.seed = 7
	var ok := true
	# T-wall roadblock (breakable cover, 12 m): six blast-wall panels on feet, one toppled.
	var wall := StaticBody3D.new()
	wall.set_script(Cover)
	wall.collision_layer = 9
	wall.set("durability", 150.0)
	var fallen := rng.randi_range(1, 4)
	for k in 6:
		var x := -5.0 + k * 2.0
		if k == fallen:
			box("concrete", Vector3(1.9, 0.35, 4.0), Vector3(x, 0.4, 1.6), Vector3(0.12, 0, 0.05))
			continue
		var tilt := Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.04, 0.04))
		box("concrete", Vector3(1.9, 4.0 - rng.randf_range(0, 0.6), 0.35), Vector3(x, 2.0, 0), tilt)
		box("concrete", Vector3(1.9, 0.5, 1.6), Vector3(x, 0.25, 0))
		box("steel", Vector3(0.5, 0.25, 0.08), Vector3(x, 4.05, 0))
	_collider(wall, "Collision", Vector3(12, 4, 1.6), Vector3(0, 2, 0))
	ok = _save_prop("t_wall_roadblock", wall, {"concrete": Concrete, "steel": Steel}, true) and ok
	# Elevated rail, 51 m: hammerhead piers, twin girders, deck with parapets, sleepers and rails;
	# the north end is snapped off with rebar and a dangling slab.
	var rail := StaticBody3D.new()
	rail.collision_layer = 1
	for z: float in [-18.0, 3.0, 24.0]:
		box("concrete", Vector3(3, 10, 3), Vector3(0, 5, z))
		box("concrete", Vector3(8, 1.2, 3.2), Vector3(0, 10.4, z))
		_collider(rail, "Pier%d" % int(z), Vector3(3, 10, 3), Vector3(0, 5, z))
	for x: float in [-2.5, 2.5]:
		box("steel", Vector3(0.8, 1.6, 51), Vector3(x, 11.4, 0))
		box("steel", Vector3(0.14, 0.16, 51), Vector3(x * 0.3, 12.5, 0))
	box("concrete", Vector3(9, 0.4, 51), Vector3(0, 12.2, 0))
	for x: float in [-4.4, 4.4]:
		box("concrete", Vector3(0.25, 1.0, 51), Vector3(x, 12.9, 0))
	for k in 40:
		box("concrete", Vector3(3.0, 0.15, 0.3), Vector3(0, 12.45, -24.5 + k * 1.25))
	for k in 10:
		box("steel", Vector3(0.06, rng.randf_range(0.8, 2.2), 0.06), Vector3(rng.randf_range(-4, 4), 12.2, 25.6), Vector3(rng.randf_range(0.6, 1.2), 0, rng.randf_range(-0.4, 0.4)))
	box("concrete", Vector3(5, 0.4, 6), Vector3(1.5, 9.8, 27.2), Vector3(-1.0, 0.2, 0.1))
	_collider(rail, "Deck", Vector3(9, 1.8, 51), Vector3(0, 11.6, 0))
	ok = _save_prop("elevated_rail", rail, {"concrete": Concrete, "steel": Steel}) and ok
	# Street lamp (8 m) and utility pole (10 m): no collision, too thin to matter.
	var lamp := Node3D.new()
	box("steel", Vector3(0.5, 0.6, 0.5), Vector3(0, 0.3, 0))
	box("steel", Vector3(0.18, 7.6, 0.18), Vector3(0, 3.8, 0))
	box("steel", Vector3(2.2, 0.12, 0.12), Vector3(1.0, 7.5, 0), Vector3(0, 0, 0.1))
	box("steel", Vector3(0.8, 0.18, 0.38), Vector3(2.1, 7.62, 0))
	ok = _save_prop("street_lamp", lamp, {"steel": Steel}, false, false, 110.0) and ok
	var pole := Node3D.new()
	box("concrete", Vector3(0.38, 10, 0.38), Vector3(0, 5, 0))
	box("steel", Vector3(2.6, 0.16, 0.16), Vector3(0, 9.2, 0))
	box("steel", Vector3(1.8, 0.14, 0.14), Vector3(0, 8.5, 0))
	for x: float in [-1.1, -0.4, 0.4, 1.1]:
		box("steel", Vector3(0.12, 0.3, 0.12), Vector3(x, 9.45, 0))
	box("steel", Vector3(0.7, 1.0, 0.7), Vector3(0, 7.2, 0.45))
	ok = _save_prop("utility_pole", pole, {"concrete": Concrete, "steel": Steel}, false, false, 110.0) and ok
	# Burnt-out car (4.3 m) on flat tyres, crumpled hood, gutted cabin.
	var car := StaticBody3D.new()
	car.collision_layer = 1
	box("rust", Vector3(4.3, 0.75, 1.8), Vector3(0, 0.62, 0))
	box("rust", Vector3(1.2, 0.35, 1.7), Vector3(1.6, 1.05, 0), Vector3(0, 0, -0.25))
	box("fill", Vector3(2.0, 0.6, 1.55), Vector3(-0.3, 1.3, 0))
	box("rust", Vector3(2.1, 0.08, 1.6), Vector3(-0.35, 1.62, 0), Vector3(0.06, 0, 0.04))
	for x: float in [-1.0, 0.0, 0.85]:
		for z: float in [-0.77, 0.77]:
			box("rust", Vector3(0.1, 0.6, 0.06), Vector3(x - 0.3, 1.3, z))
	for x: float in [-1.35, 1.35]:
		for z: float in [-0.85, 0.85]:
			box("steel", Vector3(0.6, 0.45, 0.25), Vector3(x, 0.22, z))
	_collider(car, "Collision", Vector3(4.3, 1.6, 1.8), Vector3(0, 0.8, 0))
	ok = _save_prop("wrecked_car", car, {"rust": Rust, "steel": Steel, "fill": dark}, false, true, 110.0) and ok
	# Billboard on two posts, panel hanging off one corner.
	var board := Node3D.new()
	for x: float in [-1.4, 1.4]:
		box("steel", Vector3(0.16, 5.0, 0.16), Vector3(x, 2.5, 0))
	box("steel", Vector3(3.4, 0.12, 0.12), Vector3(0, 3.55, 0))
	box("sign", Vector3(3.2, 1.6, 0.1), Vector3(0.1, 4.3, 0.1), Vector3(0, 0, -0.12))
	ok = _save_prop("signboard", board, {"steel": Steel, "sign": sign}, false, false, 110.0) and ok
	# ruined_wall.tscn Main (9 x 3.6 x 1.2): window hole, end pilasters, ragged top. Collision stays a box.
	box("concrete", Vector3(3.2, 3.6, 1.0), Vector3(-2.9, 0, 0))
	box("concrete", Vector3(3.0, 3.2, 1.0), Vector3(3.0, -0.2, 0))
	box("concrete", Vector3(2.8, 1.1, 1.0), Vector3(0.1, -1.25, 0))
	box("concrete", Vector3(2.8, 0.7, 1.0), Vector3(0.1, 1.45, 0))
	for x: float in [-4.2, 4.2]:
		box("concrete", Vector3(0.6, 3.6 if x < 0 else 3.0, 1.2), Vector3(x, 0 if x < 0 else -0.3, 0))
	box("concrete", Vector3(1.2, 0.6, 1.0), Vector3(-2.2, 2.0, 0), Vector3(0, 0, 0.3))
	var mesh: ArrayMesh = parts["concrete"].commit()
	mesh.surface_set_material(0, Concrete)
	parts.clear()
	ok = ResourceSaver.save(mesh, OUT + "ruined_wall_main.res") == OK and ok
	var opened := B.open_scene("res://scenes/ruined_wall.tscn")
	opened.root.get_node("Main/Surface").mesh = load(OUT + "ruined_wall_main.res")
	ok = B.save_scene(opened.root, "res://scenes/ruined_wall.tscn", {"overwrite": true, "expected_refs": opened.refs}).ok and ok
	return ok

## Roof slab; broken bays get a ragged, smaller slab, pier stubs and rebar sticking up.
func _roof(center: Vector3, bay: Vector2, y: float, damaged: bool, tower: bool, perimeter: bool) -> void:
	if not damaged:
		box("concrete", Vector3(bay.x + 0.02, 0.3, bay.y + 0.02), center + Vector3.UP * (y - 0.15))
		if perimeter and not tower: box("concrete", Vector3(bay.x, 0.9, bay.y) * Vector3(1, 1, 1), center + Vector3.UP * (y + 0.2))
		return
	var shrink := Vector2(rng.randf_range(0.55, 0.9), rng.randf_range(0.55, 0.9))
	var off := Vector3((1.0 - shrink.x) * bay.x * 0.5 * signf(rng.randf() - 0.5), 0, (1.0 - shrink.y) * bay.y * 0.5 * signf(rng.randf() - 0.5))
	box("concrete", Vector3(bay.x * shrink.x, 0.3, bay.y * shrink.y), center + off + Vector3.UP * (y - 0.15),
		Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08)))
	for k in (0 if tower else rng.randi_range(3, 6)):  # rebar is invisible from skyline distance
		var at := center + Vector3(rng.randf_range(-0.45, 0.45) * bay.x, y, rng.randf_range(-0.45, 0.45) * bay.y)
		var length := rng.randf_range(0.6, 1.8)
		box("steel", Vector3(0.07, length, 0.07), at + Vector3.UP * length * 0.4,
			Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
	if rng.randf() < 0.5:
		var stub := rng.randf_range(0.6, 2.4)
		box("concrete", Vector3(0.5, stub, 0.5), center + Vector3((bay.x - 0.5) * 0.5 * signf(rng.randf() - 0.5), y + stub * 0.5, (bay.y - 0.5) * 0.5 * signf(rng.randf() - 0.5)))

## Ground floor: open bays with rolled shutters at random heights (some fully open).
func _storefront(face: Vector3, along: Vector3, n: Vector3, width: float, storey: float) -> void:
	box("concrete", along.abs() * width + n.abs() * 0.4 + Vector3.UP * 0.6, face + Vector3.UP * (storey - 0.3))
	var drop := rng.randf_range(0.0, storey - 0.9)
	if drop > 0.4:
		box("steel", along.abs() * (width - 0.1) + n.abs() * 0.08 + Vector3.UP * drop, face - n * 0.2 + Vector3.UP * (storey - 0.6 - drop * 0.5))

## Low pile of tumbled blocks (kept under ~1.5 m so walker feet do not sink into it visibly).
func _rubble(at: Vector3, spread: float, count: int, size: float) -> void:
	for k in count:
		var s := Vector3(rng.randf_range(0.4, 1.0), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 1.0)) * size
		var p := at + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * spread
		box("concrete", s, p + Vector3.UP * s.y * 0.3, Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0, TAU), rng.randf_range(-0.4, 0.4)))
