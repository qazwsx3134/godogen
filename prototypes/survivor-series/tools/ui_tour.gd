extends SceneTree
## Saves one screenshot per screen (menu, fight with elite/warning/off-screen chest, level-up, pause, results, shop)
## for layout checks at phone sizes. It renders, so run it on a virtual display, never on the user's desktop:
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x1280x24" \
##     godot --path . --fixed-fps 60 --resolution 390x844 -s res://tools/ui_tour.gd -- --out=/tmp/tour-390
const META_PATH = "user://ui_tour_meta.json"
var game: Node
var frame: int = 0
var out: String = "user://ui_tour"
var shots: Dictionary = {}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		10: _shot("1-menu")
		12:
			game.auto_play = true
			game.start_run()
		200:
			var street: Node = game.street
			street.spawn_enemy(0, street.player.position + Vector2(160, -260), 2.0, true)
			street.drop("chest", street.player.position + Vector2(-900, 1400), 1.0)
			var bike: Node2D = street.spawn_enemy(1, street.player.position + Vector2(-150, 120))
			bike.hazard_left = 0.0
		240: _shot("2-fight")
		250:
			game.auto_play = false
			game.street.build.pending_choices = 1
			game.show_upgrades()
		262: _shot("3-levelup")
		264:
			game.choose_upgrade(game.current_offers[0].id)
			game.pause_run()
		276: _shot("4-pause")
		278:
			game.resume_run()
			game.finish_run(true)
		290: _shot("5-results")
		292:
			game.show_menu()
			game.open_shop()
		304: _shot("6-shop")
		306:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
			print("ui tour: ", out)
			return true
	return false

func _shot(label: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(out.path_join(label + ".png"))
