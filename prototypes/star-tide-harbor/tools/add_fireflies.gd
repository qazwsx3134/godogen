extends SceneTree
const Builder=preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game:Node=load("res://scenes/harbor.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if game.has_node("World/Fireflies"):
		game.free();quit();return
	var group:=Node2D.new();group.name="Fireflies"
	group.set_script(load("res://scripts/fireflies.gd"))
	game.get_node("World").add_child(group)
	var rng:=RandomNumberGenerator.new();rng.seed=48
	for i in range(38):
		var mote:=Polygon2D.new();mote.name="Light%02d"%i
		mote.polygon=PackedVector2Array([Vector2(-2,-2),Vector2(2,-2),Vector2(2,2),Vector2(-2,2)])
		mote.color=Color("f9dd9b")
		mote.position=Vector2(rng.randf_range(40,2360),rng.randf_range(350,550))
		mote.set_meta("origin",mote.position);group.add_child(mote)
	var result:=Builder.save_scene(game,"res://scenes/harbor.tscn",{"overwrite":true,"expected_refs":["res://scenes/player.tscn","res://scenes/mira.tscn"]})
	quit(0 if result.ok else 1)
