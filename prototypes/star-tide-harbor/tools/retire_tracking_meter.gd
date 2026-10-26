extends SceneTree
## Applied 2026-10-25. Removes obsolete tracking UI only; preserves authored surroundings.
const B=preload("res://addons/proto_kit/scene_builder.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var game:Node=B.instance("res://scenes/harbor.tscn")
	var old:Node=game.get_node_or_null("HUD/Screen/FishingPanel")
	if old==null:game.free();quit();return
	old.get_parent().remove_child(old);old.free()
	game.get_node("%FishButton").text="釣魚  [ 空白鍵 ]"
	game.get_node("%AutoButton").text="輔助釣魚  [ Tab ]"
	var result:=B.save_scene(game,"res://scenes/harbor.tscn",{"overwrite":true,"expected_refs":["res://scenes/player.tscn","res://scenes/mira.tscn","res://scenes/fishing.tscn"]})
	quit(0 if result.ok else 1)
