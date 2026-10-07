extends SceneTree
## One-time authoring for the second weapon batch (docs/horde-spec.md): tofu zone, ring, rider projectiles and the hero's umbrella.
## Run: godot --headless --path . --script res://tools/add_weapons.gd
## Applied 2026-10-07. Skips itself once tofu.tscn exists; after that edit the scenes directly.
const B = preload("res://addons/proto_kit/scene_builder.gd")

func _initialize() -> void:
	build.call_deferred()

func P(flat: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in range(0, flat.size(), 2):
		points.append(Vector2(flat[i], flat[i + 1]))
	return points

func circle(radius: float, steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in steps:
		points.append(Vector2.RIGHT.rotated(TAU * i / steps) * radius)
	return points

func poly(parent: Node, node_name: String, color: String, points: PackedVector2Array, at: Vector2 = Vector2.ZERO, alpha: float = 1.0) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.color = Color(color)
	shape.color.a = alpha
	shape.polygon = points
	shape.position = at
	B.add(parent, shape, node_name)
	return shape

func line(parent: Node, node_name: String, color: String, points: PackedVector2Array, width: float, closed: bool = false) -> Line2D:
	var stroke := Line2D.new()
	stroke.default_color = Color(color)
	stroke.points = points
	stroke.width = width
	stroke.closed = closed
	B.add(parent, stroke, node_name)
	return stroke

func projectile(node_name: String, radius: float, face: bool) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.set_script(load("res://scripts/projectile.gd"))
	root.radius = radius
	root.face_travel = face
	var visual := Node2D.new()
	visual.position = Vector2(0, -6)
	B.add(root, B.unique(visual), "Visual")
	return root

func save(node: Node, path: String) -> void:
	var result: Dictionary = B.save_scene(node, path, {"overwrite": true})
	if not result.ok:
		quit(1)

func build() -> void:
	if FileAccess.file_exists("res://scenes/tofu.tscn"):
		print("skip: weapons already authored; edit the scenes directly")
		quit()
		return
	# Tofu stand: a green stink pool with a fried tofu block and three wavy fumes.
	var tofu := projectile("TofuZone", 70.0, false)
	var tv := tofu.get_node("Visual")
	poly(tv, "Pool", "8fbf3a", circle(70.0), Vector2.ZERO, 0.3)
	poly(tv, "PoolEdge", "6f9a2a", circle(54.0), Vector2.ZERO, 0.25)
	poly(tv, "BlockOutline", "13202d", P([-11, -9, 11, -9, 11, 9, -11, 9]), Vector2(0, -4))
	poly(tv, "Block", "c98a3d", P([-9, -7, 9, -7, 9, 7, -9, 7]), Vector2(0, -4))
	for i: int in 3:
		line(tv, "Fume%d" % (i + 1), "b5e06a", P([0, 0, 4, -8, -4, -16, 0, -24]), 3.0).position = Vector2(-14 + i * 14, -14)
	save(tofu, "res://scenes/tofu.tscn")
	# Ring toss: a thick orange ring that drags enemies in.
	var ring := projectile("RingToss", 90.0, false)
	var rv := ring.get_node("Visual")
	line(rv, "Outer", "ff8a2e", circle(82.0, 28), 9.0, true)
	line(rv, "Inner", "ffe08a", circle(56.0, 24), 4.0, true)
	poly(rv, "Fill", "ffb347", circle(82.0, 28), Vector2.ZERO, 0.12)
	save(ring, "res://scenes/ring.tscn")
	# Rider: a passing scooter drawn facing +x; the projectile rotates it along its heading.
	var rider := projectile("RiderCharge", 26.0, true)
	var dv := rider.get_node("Visual")
	poly(dv, "WheelBack", "13202d", circle(9.0, 12), Vector2(-20, 6))
	poly(dv, "WheelFront", "13202d", circle(9.0, 12), Vector2(20, 6))
	poly(dv, "BodyOutline", "13202d", P([-26, -9, 26, -9, 30, 6, -24, 8]), Vector2(0, 2))
	poly(dv, "Body", "26377a", P([-23, -6, 24, -6, 26, 4, -21, 5]), Vector2(0, 2))
	poly(dv, "TailLight", "ff3b30", P([-27, -4, -23, -4, -23, 1, -27, 1]), Vector2(0, 2))
	poly(dv, "Rider", "1c2a55", P([-8, -22, 4, -22, 6, -6, -10, -6]), Vector2(0, 2))
	poly(dv, "Helmet", "f4f5fb", circle(8.0, 14), Vector2(-2, -26))
	save(rider, "res://scenes/rider.tscn")
	# Umbrella over the hero's shoulder; shown while a hit can still be absorbed.
	var hero := B.instance("res://scenes/player.tscn")
	var umbrella := Node2D.new()
	umbrella.visible = false
	umbrella.position = Vector2(-26, -62)
	B.add(hero.get_node("Motion"), B.unique(umbrella), "Umbrella")
	poly(umbrella, "HandleOutline", "13202d", P([-1.5, -2, 1.5, -2, 1.5, 20, -1.5, 20]))
	var canopy := PackedVector2Array()
	for i: int in 9:
		canopy.append(Vector2(-18, 0).rotated(PI * i / 8.0 + PI) * Vector2(1, 1))
	poly(umbrella, "CanopyOutline", "13202d", canopy, Vector2(0, 0)).scale = Vector2(1.12, 1.12)
	poly(umbrella, "Canopy", "6fb8ff", canopy)
	save(hero, "res://scenes/player.tscn")
	quit()
