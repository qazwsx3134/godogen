extends "res://addons/proto_kit/test_kit.gd"
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/"
func _initialize() -> void:
	_build.call_deferred()
func _build() -> void:
	var trail := Node3D.new()
	trail.name = "WeaponSmear"
	trail.set_script(load(BASE + "weapon_smear.gd"))
	trail.set_meta("vfx_id", "weapon-smear")
	trail.set_meta("vfx_source", "00gamedevs")
	var layers := Node3D.new()
	B.add(trail, B.unique(layers), "Layers")
	for index: int in 3:
		var part := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.orientation = PlaneMesh.FACE_Z
		plane.size = Vector2(1.4, 0.4)
		part.mesh = plane
		var material := ShaderMaterial.new()
		material.resource_local_to_scene = true
		material.shader = load(BASE + "spatial_weapon_smear_%d.gdshader" % index)
		material.render_priority = index
		part.material_override = material
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		B.add(layers, part, "Layer%d" % index)
	_save(trail, BASE + "weapon-smear.tscn")
	var impact := CanvasLayer.new()
	impact.name = "ImpactFrame"
	impact.layer = 100
	impact.set_script(load(BASE + "impact_frame.gd"))
	impact.set_meta("vfx_id", "impact-frame")
	impact.set_meta("vfx_source", "00gamedevs")
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = load(BASE + "canvas_impact_frame.gdshader")
	overlay.material = material
	B.add(impact, B.unique(overlay), "Overlay")
	_save(impact, BASE + "impact-frame.tscn")
	_trail_demo()
	_impact_demo()
	_finish("SPECIAL THREEJS AUTHORING")
func _trail_demo() -> void:
	var stage := Node3D.new()
	stage.name = "WeaponTrailPreview"
	stage.set_script(load(BASE + "trail_demo.gd"))
	B.add(stage, B.unique(B.instance(BASE + "weapon-smear.tscn")), "Trail")
	var pivot := Node3D.new()
	B.add(stage, B.unique(pivot), "Weapon")
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 1.4, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.7, 0.85, 1)
	mesh.material = material
	blade.mesh = mesh
	blade.position.y = 0.7
	B.add(pivot, blade, "Blade")
	var animation := Animation.new()
	animation.length = 1.4
	animation.loop_mode = Animation.LOOP_LINEAR
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath("Weapon:rotation_degrees"))
	for frame: Array in [[0.0,-65.0],[0.35,65.0],[0.7,-65.0],[1.05,65.0],[1.4,-65.0]]:
		animation.track_insert_key(track, frame[0], Vector3(15, 0, frame[1]))
	var library := AnimationLibrary.new()
	library.add_animation(&"swing", animation)
	var player := AnimationPlayer.new()
	player.add_animation_library(&"", library)
	B.add(stage, B.unique(player), "Swing")
	_save(stage, BASE + "weapon_demo.tscn", [BASE + "weapon-smear.tscn"])
func _impact_demo() -> void:
	var stage := Node3D.new()
	stage.name = "ImpactFramePreview"
	stage.set_script(load(BASE + "impact_demo.gd"))
	B.add(stage, B.unique(B.instance(BASE + "impact-frame.tscn")), "Impact")
	var target := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = 2.0
	mesh.radius = 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.85, 0.93, 1.0)
	mesh.material = material
	target.mesh = mesh
	target.position.y = 1.0
	B.add(stage, target, "PreviewTarget")
	_save(stage, BASE + "impact_demo.tscn", [BASE + "impact-frame.tscn"])
func _save(node: Node, path: String, refs: Array = []) -> void:
	var result := B.save_scene(node, path, {"expected_refs": refs})
	_expect(result.ok, path)
