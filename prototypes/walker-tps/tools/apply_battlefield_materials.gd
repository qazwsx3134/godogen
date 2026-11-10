extends SceneTree
## Explicit material authoring pass. Preserves saved geometry and scene instances.
const B = preload("res://addons/proto_kit/scene_builder.gd")
var mats: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func make_material(label: String, cell: Vector2, moss: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/spatial_env_weathered.gdshader")
	m.set_shader_parameter("atlas_cell",cell)
	m.set_shader_parameter("moss_amount",moss)
	textures(m)
	ResourceSaver.save(m,"res://materials/"+label+".tres")
	m.take_over_path("res://materials/"+label+".tres")
	return m
func textures(m: ShaderMaterial) -> void:
	for channel: String in ["color","normal","orm"]:
		var suffix := "albedo" if channel == "color" else channel
		m.set_shader_parameter("atlas_"+channel,load("res://assets/environment/battlefield_"+suffix+".png"))
func surfaces(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child: Node in node.get_children(): surfaces(child,material)
func save_opened(opened: Dictionary, path: String) -> bool:
	return B.save_scene(opened.root,path,{"overwrite":true,"expected_refs":opened.refs}).ok
func _run() -> void:
	mats.concrete=make_material("weathered_concrete",Vector2(3,0),0.5)
	mats.rust=make_material("rusted_armor",Vector2(0,1),0.35)
	mats.metal=make_material("burnt_steel",Vector2(3,1),0.12)
	var wall := B.open_scene("res://scenes/ruined_wall.tscn")
	surfaces(wall.root,mats.concrete)
	if not save_opened(wall,"res://scenes/ruined_wall.tscn"): quit(1); return
	var wreck := B.open_scene("res://scenes/armored_wreck.tscn")
	for child: Node in wreck.root.get_children():
		if child.name == "HullOvergrowth": continue
		surfaces(child,mats.metal if str(child.name).begins_with("Track") else mats.rust)
	if not save_opened(wreck,"res://scenes/armored_wreck.tscn"): quit(1); return
	var opened := B.open_scene("res://scenes/map_01_green_rust.tscn")
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/spatial_env_ground.gdshader")
	textures(ground)
	ResourceSaver.save(ground,"res://materials/battlefield_ground.tres")
	ground.take_over_path("res://materials/battlefield_ground.tres")
	opened.root.get_node("Terrain/GroundSurface").material_override=ground
	surfaces(opened.root.get_node("BrokenViaduct"),mats.concrete)
	surfaces(opened.root.get_node("Factory"),mats.rust)
	opened.root.get_node("Factory/Chimney/Surface").material_override=mats.concrete
	quit(0 if save_opened(opened,"res://scenes/map_01_green_rust.tscn") else 1)
