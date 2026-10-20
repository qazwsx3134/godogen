extends SceneTree
## Screenshots of the push at fixed moments (muster, fight, telegraph, zone moved, selected zone with its arrows, volley, result),
## for reviewing layout at phone sizes. Needs a display; on Linux run it off-screen:
##   xvfb-run -a godot --path prototypes/hero-horde-idle --rendering-method gl_compatibility --resolution 780x1688 \
##     --script res://tools/capture_shots.gd -- <out dir>
## Writes <out dir>/<W>x<H>_<n>_<moment>.png.

const PushSim = preload("res://domain/push_sim.gd")

var _out: String
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	seed(7)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _frames(2)
	var sim: PushSim = _main.sim
	await _shot("1_muster", 50)

	sim.skip_muster()
	await _shot("2_fight", 40)

	sim.t = PushSim.TELE_FIRST - PushSim.TELE_WARN - 0.01
	await _shot("3_telegraph", 30)

	var target: int = sim.tele_zones[0]
	sim.move_zone(target, target - 1 if target % 2 == PushSim.NEAR else target + 1)
	await _shot("4_moved", 20)

	await _frames(60)
	_main.selected = 1
	await _shot("5_selected_arrows", 10)

	sim.morale = PushSim.MORALE_MAX
	sim.volley()
	await _shot("6_volley", 9)

	for i: int in sim.cls.size():
		if i % 3 == 0:
			sim.hp[i] = 0.0
		else:
			sim.hp[i] = sim.max_hp[i] * 0.4
	sim.boss_hp = PushSim.BOSS_HP * 0.45
	await _shot("7_phase2_hurt", 30)

	sim.t = PushSim.DURATION - 0.01
	await _shot("8_result", 8)
	quit(0)


func _shot(moment: String, frames: int) -> void:
	await _frames(frames)
	var image: Image = root.get_texture().get_image()
	var path := "%s/%dx%d_%s.png" % [_out, image.get_width(), image.get_height(), moment]
	image.save_png(path)
	print("shot: ", path)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
