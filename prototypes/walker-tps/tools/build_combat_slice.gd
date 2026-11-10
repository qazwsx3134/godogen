extends SceneTree
## Explicit authoring tool; new reusable scenes plus bounded edits to existing scene trees.
const B = preload("res://addons/proto_kit/scene_builder.gd")
var failed := false
func _initialize() -> void:
	if FileAccess.file_exists("res://scenes/combat_hud.tscn") and "--overwrite" not in OS.get_cmdline_user_args():
		print("Combat scenes already authored. Inspect scene edits before --overwrite.")
		quit()
		return
	build.call_deferred()
func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
func sphere(parent: Node, label: String, radius: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2
	mesh.radial_segments=8
	mesh.rings=4
	mi.mesh=mesh
	mi.material_override=material(color)
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	B.add(parent,mi,label)
	return mi
func save(node: Node, path: String, refs: Array = [], overwrite: bool = false) -> void:
	var r: Dictionary = B.save_scene(node,path,{"overwrite":overwrite,"expected_refs":refs})
	if not r.ok: failed=true
func label(parent: Node, name: String, text: String, pos: Vector2, font_size: int = 20) -> Label:
	var l := Label.new()
	l.text=text
	l.position=pos
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_constant_override("outline_size",5)
	l.add_theme_color_override("font_outline_color",Color(0.02,0.04,0.05,0.9))
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	B.add(parent,l,name)
	return l
func touch_button(parent: Node, name: String, action: String, pos: Vector2) -> void:
	var button := TouchScreenButton.new()
	button.position=pos
	button.action=action
	button.visibility_mode=TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
	var texture := GradientTexture2D.new()
	texture.width=120
	texture.height=100
	var g := Gradient.new()
	g.set_color(0,Color(0.08,0.18,0.21,0.8))
	g.set_color(1,Color(0.18,0.32,0.32,0.85))
	texture.gradient=g
	button.texture_normal=texture
	var shape := RectangleShape2D.new()
	shape.size=Vector2(120,100)
	button.shape=shape
	B.add(parent,button,name)
	label(button,"Label",name.to_upper(),Vector2(16,32),20)

func build() -> void:
	var impact := Node3D.new()
	impact.name="Impact"
	impact.set_script(load("res://scripts/combat_impact.gd"))
	sphere(impact,"Flash",0.6,Color(1,0.55,0.12))
	B.add(impact,AudioStreamPlayer3D.new(),"Sound")
	save(impact,"res://scenes/combat_impact.tscn")
	var bullet := Node3D.new()
	bullet.name="Projectile"
	bullet.set_script(load("res://scripts/combat_projectile.gd"))
	sphere(bullet,"Tracer",0.13,Color(1,0.86,0.3))
	save(bullet,"res://scenes/combat_projectile.tscn")
	var combat := Node3D.new()
	combat.name="Combat"
	combat.set_script(load("res://scripts/walker_combat.gd"))
	for side: int in 2:
		var launch := Marker3D.new()
		launch.position=Vector3(-1.05 if side==0 else 1.05,1.8,1.7)
		B.add(combat,launch,"Launch%d"%side)
		var cable := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius=0.025
		mesh.bottom_radius=0.025
		mesh.height=1.0
		mesh.radial_segments=6
		cable.mesh=mesh
		cable.material_override=material(Color(0.35,0.85,0.95))
		cable.top_level=true
		cable.visible=false
		B.add(combat,cable,"Cable%d"%side)
		var pin := sphere(combat,"Pin%d"%side,0.18,Color(0.8,0.95,1))
		pin.top_level=true
		pin.visible=false
	var flash := sphere(combat,"MuzzleFlash",0.4,Color(1,0.8,0.3))
	flash.top_level=true
	flash.visible=false
	B.add(combat,AudioStreamPlayer3D.new(),"ShotSound")
	if ResourceLoader.exists("res://scenes/auto_blades.tscn"):
		B.add(combat,B.instance("res://scenes/auto_blades.tscn"),"AutoBlades")
	save(combat,"res://scenes/walker_combat.tscn",[],true)
	if failed: quit(1); return
	var w := B.open_scene("res://scenes/walker.tscn")
	w.root.add_to_group("combat_player",true)
	w.root.collision_layer=2
	w.root.collision_mask=5
	B.put(w.root,B.instance("res://scenes/walker_combat.tscn"),"Combat")
	var wrefs: Array = w.refs.duplicate()
	wrefs.append("res://scenes/walker_combat.tscn")
	save(w.root,"res://scenes/walker.tscn",wrefs,true)
	var s := B.open_scene("res://scenes/scout.tscn")
	s.root.collision_layer=4
	s.root.collision_mask=7
	var agent := NavigationAgent3D.new()
	agent.path_desired_distance=1.0
	agent.target_desired_distance=2.0
	B.put(s.root,agent,"NavigationAgent")
	var status := Label3D.new()
	status.position=Vector3(0,3.5,0)
	status.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	status.font_size=40
	status.pixel_size=0.018
	status.text="SCOUT / PATROL"
	status.visible=false
	B.put(s.root,status,"Status")
	for node: Node in s.root.get_children():
		if str(node.name).begins_with("Warning") or str(node.name).begins_with("HitFlash"):
			node.free()
	var warning := sphere(s.root,"Warning",0.35,Color(1,0.12,0.06))
	warning.position=Vector3(0,2.8,0)
	warning.visible=false
	var hit := sphere(s.root,"HitFlash",1.4,Color(1,0.95,0.8))
	hit.position=Vector3(0,1.4,0)
	hit.visible=false
	save(s.root,"res://scenes/scout.tscn",s.refs,true)
	var hud := CanvasLayer.new()
	hud.name="CombatHUD"
	hud.layer=3
	hud.set_script(load("res://scripts/combat_hud.gd"))
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color=Color(0.8,0.03,0.02,0.16)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.visible=false
	B.add(hud,overlay,"DamageFlash")
	label(hud,"Status","HULL 100 / 100 | SCOUTS 0 / 3 | 05:00",Vector2(20,50),22)
	label(hud,"Weapon","CANNON READY | HOOK READY",Vector2(20,82),18)
	var cross := label(hud,"Crosshair","+",Vector2.ZERO,30)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left=-10
	cross.offset_top=-20
	var reticle := label(hud,"GunReticle","○",Vector2(620,340),26)
	reticle.modulate=Color(0.55,1,0.8)
	var controls := Control.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	controls.offset_left=-450
	controls.offset_top=-490
	controls.offset_right=-20
	controls.offset_bottom=-350
	controls.mouse_filter=Control.MOUSE_FILTER_IGNORE
	controls.add_to_group("combat_touch",true)
	B.add(hud,controls,"Controls")
	touch_button(controls,"Fire","fire",Vector2(290,20))
	touch_button(controls,"Hook","hook",Vector2(150,20))
	touch_button(controls,"Aim","aim_toggle",Vector2(10,20))
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	B.add(hud,modal,"Modal")
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left=-330
	panel.offset_right=330
	panel.offset_top=-170
	panel.offset_bottom=170
	B.add(modal,panel,"Panel")
	var margin := MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	B.add(panel,margin,"Margin")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",20)
	B.add(margin,rows,"Rows")
	label(rows,"Title","GREEN RUST / SORTIE",Vector2.ZERO,28)
	var description := label(rows,"Description","Destroy 3 scouts.\nLMB fire / RMB aim / G grapple\nEnter deploy",Vector2.ZERO,19)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size=Vector2(570,135)
	var button := Button.new()
	button.text="DEPLOY"
	button.custom_minimum_size.y=50
	B.add(rows,button,"Action")
	save(hud,"res://scenes/combat_hud.tscn")
	# Bake only fixed colliders, never the grass or actors; persist the mesh.
	var source: Node = B.instance("res://scenes/map_01_green_rust.tscn")
	root.add_child(source)
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type=NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask=1
	nav.agent_radius=1.5
	nav.agent_height=2.5
	nav.agent_max_climb=0.5
	nav.agent_max_slope=40
	nav.cell_size=0.5
	nav.cell_height=0.25
	var data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav,data,source)
	NavigationServer3D.bake_from_source_geometry_data(nav,data)
	print("NAV polygons: ",nav.get_polygon_count())
	if nav.get_polygon_count()==0: failed=true
	ResourceSaver.save(nav,"res://materials/battlefield_navigation.tres")
	nav.take_over_path("res://materials/battlefield_navigation.tres")
	source.free()
	var opened := B.open_scene("res://scenes/battlefield.tscn")
	var level: Node = opened.root
	level.add_to_group("battle_session",true)
	var region := NavigationRegion3D.new()
	region.navigation_mesh=nav
	B.put(level,region,"Navigation")
	B.put(level,Node3D.new(),"Projectiles")
	B.put(level,B.instance("res://scenes/combat_hud.tscn"),"CombatHUD")
	var enemies := Node3D.new()
	B.put(level,enemies,"Enemies")
	for i: int in 3:
		var enemy := B.instance("res://scenes/scout.tscn") as Node3D
		enemy.combat_enabled=true
		var x: float = [-4.0,12.0,-9.0][i]
		var z: float = [-49.0,-22.0,8.0][i]
		var query := PhysicsRayQueryParameters3D.create(Vector3(x,30,z),Vector3(x,-10,z),1)
		# Source was removed; get authored terrain height using its original function.
		var ground := 0.7*sin(x*0.055)*cos(z*0.043)+5*exp(-pow((x+64)/25,2))-exp(-pow((x-7*sin(z*0.025))/10,2))-2.2*exp(-(pow((x-27)/13,2)+pow((z+22)/12,2)))
		enemy.position=Vector3(x,ground+0.2,z)
		enemy.rotation.y=PI
		if i==2:
			enemy.mass=12.0
			enemy.max_health=120.0
		B.add(enemies,enemy,"Scout%d"%i)
	var refs: Array = opened.refs.duplicate()
	refs.append_array(["res://scenes/scout.tscn","res://scenes/combat_hud.tscn"])
	save(level,"res://scenes/battlefield.tscn",refs,true)
	quit(1 if failed else 0)
