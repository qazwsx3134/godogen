extends SceneTree
## Explicit one-time authoring; existing blade scene is preserved unless --overwrite is supplied.
const B = preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:
	var auto := Node3D.new()
	auto.name="AutoBlades"
	auto.set_script(load("res://scripts/auto_blades.gd"))
	var sweeps := B.add(auto,Node3D.new(),"Sweeps")
	sweeps.visible=false
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(0.8,0.95,1.0,0.7)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for side: int in 2:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in 12:
			var a := deg_to_rad(-76.0+side*76.0+i*76.0/12.0)
			var b := a+deg_to_rad(76.0/12.0)
			var inner_a := Vector3(sin(a)*2.4,1.1,cos(a)*2.4)
			var outer_a := Vector3(sin(a)*3.3,1.1,cos(a)*3.3)
			var inner_b := Vector3(sin(b)*2.4,1.1,cos(b)*2.4)
			var outer_b := Vector3(sin(b)*3.3,1.1,cos(b)*3.3)
			for vertex: Vector3 in [inner_a,outer_a,inner_b,inner_b,outer_a,outer_b]: surface.add_vertex(vertex)
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh=surface.commit()
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		B.add(sweeps,mesh,"LeftSweep" if side==0 else "RightSweep")
	B.add(auto,AudioStreamPlayer3D.new(),"Sound")
	var ok: bool = B.save_scene(auto,"res://scenes/auto_blades.tscn",{"overwrite":"--overwrite" in OS.get_cmdline_user_args()}).ok
	var opened := B.open_scene("res://scenes/walker_combat.tscn")
	if not opened.root.has_node("AutoBlades"):
		B.add(opened.root,B.instance("res://scenes/auto_blades.tscn"),"AutoBlades")
		var refs: Array = opened.refs.duplicate()
		refs.append("res://scenes/auto_blades.tscn")
		ok=B.save_scene(opened.root,"res://scenes/walker_combat.tscn",{"overwrite":true,"expected_refs":refs}).ok and ok
	else: opened.root.free()
	quit(0 if ok else 1)
