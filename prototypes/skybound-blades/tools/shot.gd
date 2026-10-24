extends SceneTree
## Screenshot tool (needs a window): godot --path . --resolution 1440x900 --script res://tools/shot.gd -- <out.png> [seconds] [auto]
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shot.png"
	var seconds: float = float(args[1]) if args.size() > 1 else 4.0
	var field: Node = load("res://scenes/field.tscn").instantiate()
	root.add_child(field)
	await process_frame
	if args.size() > 2 and args[2] == "auto":
		field.battle.command({"type": "auto", "on": true})
	await create_timer(seconds).timeout
	await process_frame
	root.get_texture().get_image().save_png(out)
	print("shot: ", out)
	quit()
