extends "res://addons/proto_kit/test_kit.gd"
## The push screen driven like a player: skip the muster, drag a squad's flag, tap a squad to select it (also on the
## heroes' bodies), tap open ground to send it, skills casting themselves, 全員歸位, aim at a boss part (its button and
## the body around it), a part breaking, a telegraph on the ground, volley, result, retry; and the scene
## as the source of layout (a flag moved in the scene is where its squad musters). Instantiates scenes/main.tscn and
## finds nodes by name.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_main.gd

const PushSim = preload("res://domain/push_sim.gd")

var main: Node
var sim: PushSim
var cam: Camera3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	var hud: Node = main.find_child("Hud", true, false)
	cam = main.find_child("Camera", true, false)
	sim = main.sim
	_expect(main.find_child("Army", true, false).multimesh.instance_count == 100, "all 100 heroes are drawn")
	_expect(main.find_child("Flags", true, false).get_child_count() == PushSim.SQUADS, "three squad flags in the scene")
	_expect(sim.phase == PushSim.Phase.MUSTER, "a push opens with the muster")
	var counts := [0, 0, 0, 0]
	for r: int in sim.rarity:
		counts[r] += 1
	_expect(counts[PushSim.SSR] == 7 and counts[0] > counts[PushSim.SSR], "the roster mixes rarities (N..SSR)")
	var by_squad := [0, 0, 0]
	for s: int in sim.squad:
		by_squad[s] += 1
	_expect(by_squad == [52, 33, 15], "盾劍槍 / 弓法 / 補 form the three squads (got %s)" % str(by_squad))

	await _press(hud.find_child("SkipMuster", true, false))
	_expect(sim.fighting(), "skip starts the fight")

	# Drag the melee squad back from the boss.
	var to := Vector2(-1.0, 0.0)
	await _drag(_screen(sim.squad_center(PushSim.MELEE)), _screen(to), 0.05)
	_expect(sim.flag[PushSim.MELEE].distance_to(to) < 0.3 and main.selected == PushSim.MELEE,
		"dragging the 近戰團 plants its flag where the finger let go and selects it (flag %s)" % str(sim.flag[PushSim.MELEE]))
	await _frames(2)
	var walking: int = 0
	for i: int in sim.cls.size():
		if sim.squad[i] == PushSim.MELEE and sim.moving(i):
			walking += 1
	_expect(walking > 40, "the squad walks to its new flag (%d walking)" % walking)

	# Tap on the 遠程團's bodies (not the ground under them) selects it; a tap on open ground sends it there.
	var c: Vector2 = sim.squad_center(PushSim.RANGED)
	await _tap(cam.unproject_position(Vector3(c.x, 0.8, c.y)))
	_expect(main.selected == PushSim.RANGED, "tapping a squad's heroes selects that squad")
	var open := Vector2(-3.3, 3.2)
	await _tap(_screen(open))
	_expect(sim.flag[PushSim.RANGED].distance_to(open) < 0.3 and main.selected == PushSim.RANGED,
		"tapping open ground sends the selected squad there")
	var far := Vector2(-20.0, 0.0)
	sim.move_flag(PushSim.SUPPORT, far)
	_expect(sim.flag[PushSim.SUPPORT] == Vector2(PushSim.FIELD_MIN.x, 0.0), "a flag never leaves the field")

	await _press(hud.find_child("Regroup", true, false))
	var home: bool = true
	for s: int in PushSim.SQUADS:
		if sim.flag[s] != sim.home[s]:
			home = false
	_expect(home, "全員歸位 sends every squad back to where it mustered")

	# Melee in reach cast their skills as soon as they are ready.
	var caster: int = -1
	for i: int in sim.cls.size():
		if sim.cls[i] == PushSim.SWORD and sim.rarity[i] >= PushSim.SR and sim.alive(i):
			caster = i
			break
	for i: int in sim.cls.size():
		sim.pos[i] = sim.goal[i]
	sim.skill_cd[caster] = 0.0
	await _frames(3)
	_expect(sim.in_reach(sim.pos[caster]) and sim.cast_at[caster] >= 0.0 and sim.skill_cd[caster] > 0.0,
		"a ready SR melee skill casts itself in reach of the boss")

	# Aim: the 角 button, then a tap on the boss's arm.
	await _frames(2)
	var horns: Button = hud.find_child("PartHorns", true, false)
	_expect(horns.visible, "part buttons show during the fight")
	await _press(horns)
	await _frames(1)
	_expect(sim.aim == PushSim.Part.HORNS and horns.text.begins_with("◎"), "the 角 button aims the ranged squad at the horns")
	var boss: Node3D = main.find_child("Boss", true, false)
	await _tap(cam.unproject_position(boss.part_point(PushSim.Part.ARM)) + Vector2(0.0, 50.0))
	_expect(sim.aim == PushSim.Part.ARM, "a tap on the boss near the arm aims at the arm")

	# The arm breaks: he goes down, the head opens, the banner says what he lost.
	var banner: Label = hud.find_child("Banner", true, false)
	sim.part_hp[PushSim.Part.ARM] = 1.0
	await _until(func() -> bool: return sim.broken(PushSim.Part.ARM), "the aimed arm breaks")
	_expect(sim.stagger_t > 0.0 and sim.aim == -1, "a broken part knocks him down and the aim is free again")
	_expect(banner.text.contains("持棍手臂") and banner.text.contains("不能橫掃"), "the banner names the part and what he lost (%s)" % banner.text)
	await _frames(2)
	_expect((hud.find_child("PartArm", true, false) as Button).disabled, "a broken part's button greys out")

	# A telegraph after the knockdown: its shape is on the ground and its banner is not covered.
	sim.stagger_t = 0.0
	sim.t = maxf(sim.t, sim._next_tele - PushSim.TELE_WARN - 0.01)
	sim._tele_index = 2  # the 橫掃 turn of the first cycle
	await _until(func() -> bool: return sim.tele_t > 0.0, "a telegraph starts")
	await _frames(2)
	var marker: Node3D = main.find_child("TeleMarkers", true, false).get_child(0)
	_expect(marker.visible, "the telegraph's shape is drawn on the ground")
	_expect(sim.tele_kind == PushSim.Attack.SLAM, "with the arm broken, the 橫掃 turn becomes a 重砸")
	if sim.tele_threatens():
		main._on_event(&"revive", 0.0)
		_expect(banner.text.contains("紅圈"), "an unanswered telegraph is not covered by another banner")

	sim.morale = PushSim.MORALE_MAX
	await _frames(1)
	var hp: float = sim.boss_hp
	await _press(hud.find_child("Volley", true, false))
	_expect(sim.morale < 1.0 and sim.boss_hp < hp - 1000.0, "volley spends the full bar on a big hit")

	sim.t = PushSim.DURATION - 0.01
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "result shows when time runs out")
	_expect(sim.phase == PushSim.Phase.LOST, "time out is a loss")
	_expect(not horns.visible, "part buttons hide on the result")
	await _press(hud.find_child("Retry", true, false))
	_expect(main.sim != sim and main.sim.phase == PushSim.Phase.MUSTER, "retry starts a fresh push with a muster")
	_expect(main.sim.home[PushSim.MELEE] == sim.home[PushSim.MELEE], "a retry musters where the scene puts the flags")

	# The scene is the layout: a flag moved in the scene is where that squad musters.
	var edited: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var flag: Node3D = edited.find_child("Flags", true, false).get_child(PushSim.SUPPORT)
	flag.position = Vector3(-0.5, 0.0, 2.6)
	main.queue_free()
	root.add_child(edited)
	await _frames(2)
	_expect(edited.sim.home[PushSim.SUPPORT] == Vector2(-0.5, 2.6), "a flag moved in the scene sets its squad's muster point")
	_expect(edited.sim.home[PushSim.MELEE] == PushSim.HOME[PushSim.MELEE], "the other squads keep theirs")
	_finish("MAIN UI TESTS")


## Screen point over a ground point.
func _screen(p: Vector2) -> Vector2:
	return cam.unproject_position(Vector3(p.x, main.PICK_Y, p.y))
