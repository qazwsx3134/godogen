extends SceneTree
## Repairs only unbound textures after initial import; preserves all authored layout.
const B=preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var bindings:Dictionary={"furniture":{"Glow":"prop_glow.svg","Art":"prop_lamp.svg"},"cabin":{"CabinArt":"cabin.svg","Preview":"prop_plant.svg"},"depth_layers":{"MidShore/DistantForest":"midshore.svg","ForegroundLayer/NearPlants/ForegroundPlants":"foreground.svg"}}
	for scene:String in bindings:
		var path:="res://scenes/%s.tscn"%scene
		var node:Node=B.instance(path)
		for child:String in bindings[scene]:
			if node.get_node(child).texture==null:node.get_node(child).texture=load("res://assets/"+bindings[scene][child])
		if not B.save_scene(node,path,{"overwrite":true}).ok:quit(1);return
	quit()
