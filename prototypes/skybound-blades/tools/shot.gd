extends SceneTree
## Screenshot tool (needs a window):
##   godot --path . --resolution 1440x900 --script res://tools/shot.gd -- <out.png> [seconds] [auto|camp|boss]
## Uses its own save file (erased first), so shots never touch the player's save.
const SaveService = preload("res://domain/save_service.gd")

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/shot.png"
	var seconds: float = float(args[1]) if args.size() > 1 else 4.0
	var mode: String = args[2] if args.size() > 2 else ""
	SaveService.new("user://shot_save.json").erase()
	var field: Node = load("res://scenes/field.tscn").instantiate()
	field.save_path = "user://shot_save.json"
	root.add_child(field)
	await process_frame
	match mode:
		"auto":
			field.battle.command({"type": "auto", "on": true})
		"camp":
			field.battle.run.record_kill(field.battle.run.next_kill_id(), "meadow_slime", 1, field.battle.rng)
			var r: RefCounted = field.battle.run
			r.make_gear("novice_sword", "rare")
			r.make_gear("hard_leather", "fine")
			r.add_item("green_core", 4)
			field.open_camp("裝備")
		"skills":
			var r: RefCounted = field.battle.run
			r.level = 9
			r.learned.leader = {"cleave": {"level": 3, "exp": 40.0}, "rising": {"level": 2, "exp": 10.0}, "whirl": {"level": 2, "exp": 0.0}}
			r.seals = 2
			load("res://domain/skills.gd").link(field.tuning, r, "leader", "rising")
			field.open_camp("技能")
		"boss":
			var b: RefCounted = field.battle
			for m: RefCounted in b.party():
				m.pos = Vector2(8.0, -4.0) + Vector2(m.id * 0.8, 0.5)
				m.max_hp = 5000.0
				m.hp = 5000.0
			b.command({"type": "auto", "on": true})
	await create_timer(seconds).timeout
	await process_frame
	root.get_texture().get_image().save_png(out)
	print("shot: ", out)
	SaveService.new("user://shot_save.json").erase()
	quit()
