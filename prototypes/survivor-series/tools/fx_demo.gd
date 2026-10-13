extends SceneTree
## Puts every PixelFx effect next to the hero once (punch and heavy slash, kick ring, firecracker and fart blasts
## with captions, gold burst, sparks, a white hit flash, a smoker's cloud) and saves two frames, for tuning effects by eye.
## Renders, so run it on a virtual display, never on the user's desktop:
##   env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x1280x24" \
##     godot --path . --fixed-fps 60 --resolution 540x960 -s res://tools/fx_demo.gd -- /tmp/fx   (-> /tmp/fx-a.png, -b.png)
const META_PATH = "user://fx_demo_meta.json"
var game: Node
var frame: int = 0
var out: String

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = META_PATH
	root.add_child(game)

func _process(_delta: float) -> bool:
	frame += 1
	var street: Node = game.street
	match frame:
		5:
			game.start_run()
			street.spawn_left = 1000.0
			street.surge_left = 1000.0
		8:
			street.clear()
			var at: Vector2 = street.player.position
			var enemy: Node2D = street.spawn_enemy(0, at + Vector2(-120, 60))
			street.fx.slash(at + Vector2(0, -20), 0.0, 90.0, 1.7, &"hit")
			street.fx.slash(at + Vector2(0, -170), PI, 90.0, 1.7, &"heavy", true)
			street.fx.ring(at + Vector2(0, 170), 30.0, 110.0, &"kick", 0.32, 2)
			street.blast(at + Vector2(150, 120), 90.0, 0.0, 0.0, &"blast", "砰！")
			street.blast(at + Vector2(-150, -170), 90.0, 0.0, 0.0, &"fart", "噗～")
			street.fx.burst(at + Vector2(150, -160), &"gold", 14, 70.0)
			street.fx.spark(at + Vector2(-60, 220), Vector2.RIGHT, &"slipper", 6)
			enemy.hit(1.0, Vector2.LEFT, 0.0)
			street._smoke(at + Vector2(-20, 300))
		11:
			root.get_texture().get_image().save_png(out + "-a.png")
		16:
			root.get_texture().get_image().save_png(out + "-b.png")
		40:
			root.get_texture().get_image().save_png(out + "-c.png")
		44:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
			return true
	return false
