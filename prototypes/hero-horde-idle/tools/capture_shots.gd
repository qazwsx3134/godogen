extends SceneTree
## Screenshots of the push at fixed moments (muster, fight, a 重砸 circle, the squad walking out of it, the slam
## landing, a 落石 pair over the back squads, aiming at the horns, the horns breaking, the SSR mage's 隕石術, volley,
## phase 2 hurt, result), then the 養成 roster and two hero pages (an SSR with its 招牌技, an N with its next rarity step),
## for reviewing layout at phone sizes. Needs a display; keep the default Mobile renderer (gl_compatibility has no depth
## of field, so the stage looks different):
##   godot --path prototypes/hero-horde-idle --resolution 390x844 --script res://tools/capture_shots.gd -- <out dir>
## On Linux without a screen, prefix xvfb-run -a.
## Writes <out dir>/<W>x<H>_<n>_<moment>.png.

const PushSim = preload("res://domain/push_sim.gd")
const Progression = preload("res://domain/progression.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")

var _out: String
var _main: Node


func _initialize() -> void:
	_out = Screenshot.out_dir()
	_run.call_deferred()


func _run() -> void:
	seed(7)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Heroes near the push's reference strength, saved aside so the player's progress is never touched.
	var progress := Progression.new()
	progress.class_level.fill(12)
	progress.captains = PackedInt32Array([3, 60])  # a shield up front and an archer at the back
	_main.progress = progress
	_main.save_path = "user://progress_shots.json"
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

	for i: int in sim.cls.size():
		if sim.sig[i] == PushSim.Sig.METEOR:
			sim.sig_cd[i] = 0.0
	await _shot("6c_meteor", 20)
	await _frames(120)

	sim.morale = PushSim.MORALE_MAX
	sim.volley()
	await _shot("7_volley", 9)

	for i: int in sim.cls.size():
		if i % 3 == 0:
			sim.hp[i] = 0.0
		else:
			sim.hp[i] = sim.max_hp[i] * 0.4
	sim.boss_hp = sim.boss_max_hp * 0.45
	await _shot("8_phase2_hurt", 30)

	sim.t = PushSim.DURATION - 0.01
	await _shot("9_result", 8)

	# The growth screen after a few rounds: some gold and shards, a levelled march squad.
	_main.queue_free()
	var grown := Progression.new()
	for k: int in 3:
		grown.march_hour()
		grown.gold += 2000
		grown.auto_spend()
	grown.shards = 3
	var growth: Control = (load("res://scenes/growth.tscn") as PackedScene).instantiate()
	growth.progress = grown
	growth.save_path = "user://progress_shots.json"
	root.add_child(growth)
	await _frames(3)
	growth.select_class(1)
	await _shot("10_growth", 4)
	# The hero page: the SSR sword (its 招牌技), then an N (the next rarity step).
	growth.select_hero(growth.find_child("Cards", true, false).get_child(0).hero)
	await _shot("11_hero_ssr", 3)
	growth.select_hero(growth.find_child("Cards", true, false).get_child(12).hero)
	await _shot("12_hero_n", 3)
	quit(0)


func _shot(moment: String, frames: int) -> void:
	await _frames(frames)
	Screenshot.save(root, _out, moment)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
