extends SceneTree
## Screenshots of the push at fixed moments (muster, fight, a 重砸 circle, the squad walking out of it, the slam
## landing, a 落石 pair over the back squads, aiming at the horns, the horns breaking, volley, phase 2 hurt, result),
## for reviewing layout at phone sizes. Needs a display; keep the default Mobile renderer (gl_compatibility has no depth
## of field, so the stage looks different):
##   godot --path prototypes/hero-horde-idle --resolution 390x844 --script res://tools/capture_shots.gd -- <out dir>
## On Linux without a screen, prefix xvfb-run -a.
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

	sim.move_flag(PushSim.MELEE, Vector2(-1.8, 0.0))
	await _shot("4_moved", 20)

	while sim.tele_t > 0.0:
		await process_frame
	await _shot("4b_slam", 6)

	sim.regroup()
	await _frames(90)
	sim._tele_index = 1  # the 落石 turn of the first cycle
	sim.t = sim._next_tele - PushSim.TELE_WARN - 0.01
	await _shot("5_rocks", 50)
	# Step the back squads out of the rocks, the way a player would.
	sim.move_flag(PushSim.RANGED, Vector2(0.6, -2.0))
	sim.move_flag(PushSim.SUPPORT, Vector2(1.4, 3.1))
	while sim.tele_t > 0.0:
		await process_frame
	sim.regroup()
	await _frames(60)

	sim.aim_at(PushSim.Part.HORNS)
	_main.selected = PushSim.RANGED
	await _shot("6_aim_horns", 30)
	sim.part_hp[PushSim.Part.HORNS] = 1.0
	await _shot("6b_horns_break", 12)
	await _frames(240)

	sim.morale = PushSim.MORALE_MAX
	sim.volley()
	await _shot("7_volley", 9)

	for i: int in sim.cls.size():
		if i % 3 == 0:
			sim.hp[i] = 0.0
		else:
			sim.hp[i] = sim.max_hp[i] * 0.4
	sim.boss_hp = PushSim.BOSS_HP * 0.45
	await _shot("8_phase2_hurt", 30)

	sim.t = PushSim.DURATION - 0.01
	await _shot("9_result", 8)
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
