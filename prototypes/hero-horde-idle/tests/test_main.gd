extends "res://addons/proto_kit/test_kit.gd"
## The push screen driven like a player: skip the muster, drag a squad's flag, tap a squad to select it (also on the
## heroes' bodies, or its tab at the bottom), tap open ground to send it, skills casting themselves, 全員歸位, aim at a
## boss part (its button and the body around it), a part breaking, a telegraph on the ground, an SSR's 招牌技 callout
## and an SR's name popping up, volley, result, retry; and the scene as the source of layout (a flag moved in the scene
## is where its squad musters). Instantiates scenes/main.tscn and finds nodes by name.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_main.gd

const PushSim = preload("res://domain/push_sim.gd")
const Stages = preload("res://domain/stages.gd")
const Progression = preload("res://domain/progression.gd")
const SAVE_TEST := "user://progress_test_main.json"
## A shield in the front of the 近戰團, picked as the one 隊長.
const CAPTAIN := 3

var main: Node
var sim: PushSim
var cam: Camera3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.progress = _reference_progress()
	main.save_path = SAVE_TEST
	root.add_child(main)
	await _frames(3)
	var hud: Node = main.find_child("Hud", true, false)
	cam = main.find_child("Camera", true, false)
	sim = main.sim
	_expect(main.find_child("Army", true, false).multimesh.instance_count == 100, "all 100 heroes are drawn")
	var sheet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/heroes/heroes.json"))
	var frames: Vector2 = (load("res://materials/heroes.tres") as ShaderMaterial).get_shader_parameter(&"frames")
	_expect(frames == Vector2(sheet.columns, sheet.rows),
		"the heroes' material uses the atlas grid %s (a 6-row grid on the 18-row atlas squashed every hero)" % frames)
	_expect(main.find_child("Flags", true, false).get_child_count() == PushSim.SQUADS, "three squad flags in the scene")
	_expect(sim.phase == PushSim.Phase.MUSTER, "a push opens with the muster")
	_expect(main.pushing == 1 and (hud.find_child("StageLabel", true, false) as Label).text == "第1層" and
		is_equal_approx(sim.boss_max_hp, PushSim.BOSS_HP * Stages.stage(1).hp), "a fresh save pushes 第1層 (its eased boss)")
	var counts := [0, 0, 0, 0]
	for r: int in sim.rarity:
		counts[r] += 1
	_expect(counts[PushSim.SSR] == 7 and counts[0] > counts[PushSim.SSR], "the roster mixes rarities (N..SSR)")
	var by_squad := [0, 0, 0]
	for s: int in sim.squad:
		by_squad[s] += 1
	_expect(by_squad == [52, 33, 15], "盾劍槍 / 弓法 / 補 form the three squads (got %s)" % str(by_squad))

	var army: MultiMeshInstance3D = main.find_child("Army", true, false)
	var plates: Node = main.find_child("CaptainPlates", true, false)
	# (Headless runs keep no MultiMesh transforms, so the size is read from where the head is.)
	var drawn: float = army.head(CAPTAIN).y
	var other: float = army.head(CAPTAIN + 1).y
	_expect(drawn > other * 1.25, "the 隊長 is drawn larger (head at %.2f m vs %.2f m)" % [drawn, other])
	_expect(plates.get_child(0).visible and plates.get_child(0).text.begins_with("隊長") and not plates.get_child(1).visible,
		"one nameplate over the one captain (%s)" % plates.get_child(0).text)
	_expect(plates.get_child(0).position.distance_to(army.head(CAPTAIN)) < 0.01, "the nameplate sits over the captain's head")
	await _press(hud.find_child("SkipMuster", true, false))
	_expect(sim.fighting(), "skip starts the fight")
	var coach: Control = hud.find_child("Coach", true, false)
	_expect(coach.visible and hud.find_child("CoachText", true, false).text.contains("旗子") and main.progress.tips.has("flag"),
		"the first push opens with the flag hint")
	_expect(coach.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the hint never blocks a tap")
	main._on_event(&"skill", float(CAPTAIN))
	var shot_at: float = main._captain_shot_at
	_expect(shot_at > -INF, "a captain casting gets a camera shot")
	await _frames(2)
	main._on_event(&"skill", float(CAPTAIN))
	_expect(main._captain_shot_at == shot_at, "not again within %d s" % int(main.CAPTAIN_SHOT_GAP))

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
	# The squad tabs at the bottom select too, and a tap there never reaches the field.
	var flag_before: Vector2 = sim.flag[PushSim.RANGED]
	await _press(hud.find_child("Squad_2", true, false))
	_expect(main.selected == PushSim.SUPPORT and sim.flag[PushSim.RANGED] == flag_before,
		"the 輔助團 tab selects that squad without moving any flag")
	_expect((hud.find_child("Squad_2", true, false) as Button).button_pressed and
		not (hud.find_child("Squad_1", true, false) as Button).button_pressed, "the selected squad's tab is lit")
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

	# 招牌技: the SSR mage's 隕石術 slides its card in; an SR casting gets its name over its head.
	var mage: int = -1
	var sr: int = -1
	for i: int in sim.cls.size():
		if sim.sig[i] == PushSim.Sig.METEOR:
			mage = i
		if sr < 0 and sim.rarity[i] == PushSim.SR and sim.alive(i):
			sr = i
	sim.pos[mage] = sim.goal[mage]
	sim.sig_cd[mage] = 0.0
	await _until(func() -> bool: return sim.sig_casts[mage] > 0, "the SSR mage casts 隕石術")
	await _frames(12)
	var callout: Control = hud.find_child("SkillCallout", true, false)
	var skill_name: Label = hud.find_child("SkillName", true, false)
	_expect(callout.visible and skill_name.text.contains("隕石術"), "the 招牌技 card shows the move (%s)" % skill_name.text)
	var popups: Node = main.find_child("Popups", true, false)
	main._on_event(&"skill", float(sr))
	var shown: int = 0
	for popup: Node3D in popups.get_children():
		if popup.visible:
			shown += 1
	_expect(shown >= 2, "names rise over the SSR and the SR who cast (%d shown)" % shown)

	sim.morale = PushSim.MORALE_MAX
	await _frames(1)
	var hp: float = sim.boss_hp
	await _press(hud.find_child("Volley", true, false))
	_expect(sim.morale < 1.0 and sim.boss_hp < hp - 1000.0, "volley spends the full bar on a big hit")
	# 士氣 follows how often heroes strike and get hit, not how hard.
	var alive: int = -1
	for i: int in sim.hp.size():
		if sim.hp[i] > sim.max_hp[i] * 0.5:
			alive = i
			break
	sim.morale = 50.0
	sim._hurt(alive, 1.0)
	_expect(is_equal_approx(sim.morale, 50.0 - PushSim.MORALE_PER_HURT), "a hero hit by the boss costs 士氣 (%.1f)" % sim.morale)
	var strong: PushSim = PushSim.new(3, Progression.new(3).roster())
	var weak: PushSim = PushSim.new(3, Progression.new(3).roster())
	for k: int in strong.atk.size():
		strong.atk[k] *= 20.0
	for sim_k: PushSim in [strong, weak]:
		sim_k.skip_muster()
		sim_k.morale = 0.0
		for f: int in 60:
			sim_k.step(1.0 / 60.0)
	_expect(absf(strong.morale - weak.morale) < 0.5, "twenty times the attack fills 士氣 no faster (%.2f vs %.2f)" % [strong.morale, weak.morale])

	sim.t = PushSim.DURATION - 0.01
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "result shows when time runs out")
	_expect(sim.phase == PushSim.Phase.LOST, "time out is a loss")
	var lines: Array = hud.find_child("RewardGrid", true, false).get_children().filter(func(c: Node) -> bool:
		return not c.is_queued_for_deletion())
	_expect(lines.size() >= 1 and lines[0].find_child("RowName", true, false).text == "金幣" and main.progress.gold > 0
		and main.progress.pushes == 1, "the push pays gold into the progress, listed line by line")
	var panel: Control = hud.find_child("Result", true, false).find_child("Panel", true, false)
	_expect(panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= 720
		and panel.get_global_rect().end.y <= 1280, "the result fits a 16:9 screen (%s)" % panel.get_global_rect())
	_expect((hud.find_child("GoGrow", true, false) as Button).theme_type_variation == &"PrimaryButton",
		"after a loss 去點天賦 is the main action")
	_expect(FileAccess.file_exists(SAVE_TEST), "the progress is saved after the push")
	_expect((hud.find_child("GoGrow", true, false) as Button).visible, "the result offers 去點天賦")
	_expect(not horns.visible and not callout.visible, "part buttons and the callout hide on the result")
	await _press(hud.find_child("Retry", true, false))
	_expect(main.sim != sim and main.sim.phase == PushSim.Phase.MUSTER, "retry starts a fresh push with a muster")
	main.sim.skip_muster()
	await _frames(3)
	_expect(not coach.visible, "a hint already seen does not come back")
	_expect(main.sim.home[PushSim.MELEE] == sim.home[PushSim.MELEE], "a retry musters where the scene puts the flags")

	# Win 第1層: a first clear pays its bonus and opens 第2層, which 挑戰下一層 starts with a tougher boss.
	main.sim.skip_muster()
	main.sim.boss_hp = 1.0
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "the win shows the result")
	var next: Button = hud.find_child("NextStage", true, false)
	_expect(main.progress.cleared == 1 and next.visible and next.text.contains("第2層"), "a first clear offers 第2層 (%s)" % next.text)
	_expect((hud.find_child("ResultTitle", true, false) as Label).text == "首次通關！", "the title says it was the first clear")
	await _frames(2)
	var won_panel: Rect2 = hud.find_child("Result", true, false).find_child("Panel", true, false).get_global_rect()
	_expect(won_panel.position.x >= 0 and won_panel.end.x <= 720 and won_panel.position.y >= 0 and won_panel.end.y <= 1280,
		"a first clear's result, with all its drops, fits a 16:9 screen (%s)" % won_panel)
	await _press(next)
	_expect(main.pushing == 2 and main.sim.boss_max_hp > sim.boss_max_hp * 2.0 and
		(hud.find_child("StageLabel", true, false) as Label).text == "第2層", "挑戰下一層 pushes 第2層 with a tougher boss")

	# The scene is the layout: a flag moved in the scene is where that squad musters.
	var edited: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	edited.progress = _reference_progress()
	edited.save_path = SAVE_TEST
	var flag: Node3D = edited.find_child("Flags", true, false).get_child(PushSim.SUPPORT)
	flag.position = Vector3(-0.5, 0.0, 2.6)
	(edited.find_child("MoraleTitle", true, false) as Label).text = "編輯器改的士氣"
	main.queue_free()
	root.add_child(edited)
	await _frames(2)
	_expect(edited.sim.home[PushSim.SUPPORT] == Vector2(-0.5, 2.6), "a flag moved in the scene sets its squad's muster point")
	_expect(edited.sim.home[PushSim.MELEE] == PushSim.HOME[PushSim.MELEE], "the other squads keep theirs")
	_expect((edited.find_child("MoraleTitle", true, false) as Label).text == "編輯器改的士氣", "a HUD text edited in the scene stays")
	DirAccess.remove_absolute(SAVE_TEST)
	_finish("MAIN UI TESTS")


## Heroes near the push's reference strength (劍術 and 耐力 Lv11: about x1.0), so the checks below are not lost to a
## first-day roster.
func _reference_progress() -> RefCounted:
	var p := Progression.new()
	p.talent[0] = 11
	p.talent[1] = 11
	p.captains = PackedInt32Array([CAPTAIN])
	return p


## Screen point over a ground point.
func _screen(p: Vector2) -> Vector2:
	return cam.unproject_position(Vector3(p.x, main.PICK_Y, p.y))
