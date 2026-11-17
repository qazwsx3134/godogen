extends SceneTree
## Authors scenes/boss_pillar.tscn (the Boss's pillar rain; behaviour in scripts/boss_pillar.gd).
## The saved scene is the editable source; rerunning overwrites it.
## godot --headless --path . --script res://tools/build_boss_pillar.gd
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const HEIGHT := 8.0
const RADIUS := 0.3

func _initialize() -> void:
	quit(0 if _run() else 1)

func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.85
	m.roughness = 0.45
	return m

func _run() -> bool:
	var root := StaticBody3D.new()
	root.name = "BossPillar"
	root.set_script(load("res://scripts/boss_pillar.gd"))
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = RADIUS + 0.05
	cylinder.height = HEIGHT
	shape.shape = cylinder
	shape.position.y = HEIGHT * 0.5
	Builder.add(root, shape, "Collision")
	var model := Node3D.new()
	Builder.add(root, model, "Model")
	# A plain iron-grey round bar (origin = the bottom end, which goes into the ground).
	var body := MeshInstance3D.new()
	var bar := CylinderMesh.new()
	bar.top_radius = RADIUS
	bar.bottom_radius = RADIUS
	bar.height = HEIGHT
	bar.radial_segments = 12
	bar.rings = 1
	body.mesh = bar
	body.position.y = HEIGHT * 0.5
	body.material_override = _metal(Color(0.34, 0.35, 0.37))
	Builder.add(model, body, "Bar")
	# Warning ring on the ground where it will land (top_level: placed by drop()).
	var marker := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2(3.4, 3.4)
	marker.mesh = quad
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.albedo_color = Color(1.0, 0.15, 0.05, 0.9)
	red.albedo_texture = load("res://assets/vfx/ring.png")
	red.no_depth_test = true  # a warning must read through grass and over slopes
	red.render_priority = 1
	marker.material_override = red
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.top_level = true
	Builder.add(root, marker, "Marker")
	var react := Node.new()
	react.set_script(load("res://addons/proto_kit/hit_react3d.gd"))
	react.set("squash", 0.04)
	react.set("knock_distance", 0.08)
	Builder.add(root, react, "HitReact")
	return Builder.save_scene(root, "res://scenes/boss_pillar.tscn", {"overwrite": true}).ok
