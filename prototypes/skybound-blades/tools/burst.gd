extends SceneTree
## Burst screenshots for checking motion: godot --path . --resolution 1440x900 --script res://tools/burst.gd -- <out_prefix> [count] [gap_s] [warmup_s]
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0]
	var count: int = int(args[1]) if args.size() > 1 else 8
	var gap: float = float(args[2]) if args.size() > 2 else 0.1
	var warmup: float = float(args[3]) if args.size() > 3 else 3.0
	var field: Node = load("res://scenes/field.tscn").instantiate()
	root.add_child(field)
	await process_frame
	field.battle.command({"type": "auto", "on": true})
	await create_timer(warmup).timeout
	for i in count:
		await process_frame
		root.get_texture().get_image().save_png("%s_%02d.png" % [prefix, i])
		await create_timer(gap).timeout
	quit()
