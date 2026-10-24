extends "res://addons/proto_kit/test_kit.gd"
## The push screen driven like a player: skip the muster, drag a zone onto another (also from a hero's body into a
## gap between zones), tap to select, ◀ ▶ arrows, skills casting themselves, regroup, weak point, volley, result, retry. Instantiates scenes/main.tscn and finds nodes by name.
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_main.gd

const PushSim = preload("res://domain/push_sim.gd")

var main: Node
var sim: PushSim


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(3)
	var hud: Node = main.find_child("Hud", true, false)
	sim = main.sim
	_expect(main.find_child("Army", true, false).multimesh.instance_count == 100, "all 100 heroes are drawn")
	_expect(main.find_child("Zones", true, false).get_child_count() == PushSim.ZONES, "six zone tiles in the scene")
	_expect(sim.phase == PushSim.Phase.MUSTER, "a push opens with the muster")
	var counts := [0, 0, 0, 0]
	for r: int in sim.rarity:
		counts[r] += 1
	_expect(counts[PushSim.SSR] == 7 and counts[0] > counts[PushSim.SSR], "the roster mixes rarities (N..SSR)")

	await _press(hud.find_child("SkipMuster", true, false))
	_expect(sim.fighting(), "skip starts the fight")

	var moving: int = sim.living_in(3)
	await _drag(_screen(3), _screen(2), 0.05)
	_expect(sim.living_in(3) == 0 and sim.living_in(2) >= moving, "dragging 近2 onto 遠2 moves all its heroes")
	_expect(main.selected == 2, "the drag target becomes the selected zone")
	await _tap(_screen(1))
	_expect(main.selected == 1, "tapping a zone selects it")

	await _frames(2)
	var left: Button = hud.find_child("ArrowLeft", true, false)
	var right: Button = hud.find_child("ArrowRight", true, false)
	_expect(left.visible and not right.visible, "a selected 近 zone shows only ◀")
	moving = sim.living_in(1)
	await _press(left)
	_expect(sim.living_in(1) == 0 and sim.living_in(0) >= moving and main.selected == 0, "◀ moves the zone to 遠 and keeps it selected")
	await _frames(2)
	_expect(right.visible and not left.visible, "a selected 遠 zone shows only ▶")
	await _press(right)
	_expect(sim.living_in(1) >= moving and main.selected == 1, "▶ moves it back to 近")

	# Grabbing the heroes' bodies (not the ground under them) and letting go in the gap between columns still moves.
	var cam: Camera3D = main.find_child("Camera", true, false)
	var c5: Vector2 = sim.zone_center[5]
	# Just past 遠3's right edge, in the gap, nearer 遠3 than 近3 (measured where picking measures, at mid-body).
	var gap_x: float = sim.zone_center[4].x + sim.zone_half[4].x + 0.04
	moving = sim.living_in(5)
	await _drag(cam.unproject_position(Vector3(c5.x, 0.8, c5.y)), cam.unproject_position(Vector3(gap_x, main.PICK_Y, c5.y)), 0.05)
	_expect(sim.living_in(5) == 0 and sim.living_in(4) >= moving, "a drag from hero bodies into the column gap reaches 遠3")

	# Heroes walking between zones hold their skills; a standing SR sword casts as soon as it is ready.
	var caster: int = -1
	for i: int in sim.cls.size():
		if sim.cls[i] == PushSim.SWORD and sim.rarity[i] >= PushSim.SR and sim.alive(i):
			caster = i
			break
	sim.pos[caster] = sim.goal[caster]
	sim.skill_cd[caster] = 0.0
	await _frames(3)
	_expect(sim.cast_at[caster] >= 0.0 and sim.skill_cd[caster] > 0.0, "a ready SR skill casts itself")

	await _press(hud.find_child("Regroup", true, false))
	var home: bool = true
	for i: int in sim.cls.size():
		if sim.alive(i) and sim.zone[i] != sim.home[i]:
			home = false
	_expect(home and sim.living_in(3) > 0, "全員歸位 sends everyone back to their own zone")

	var banner: Label = hud.find_child("Banner", true, false)
	sim.t = PushSim.TELE_FIRST - PushSim.TELE_WARN - 0.01
	await _until(func() -> bool: return sim.tele_t > 0.0, "a telegraph starts")
	main._on_event(&"weak_open", 3.0)
	_expect(banner.text.contains("紅區"), "an unanswered telegraph is not covered by another banner")

	sim.weak_t = 3.0
	await _frames(2)
	var weak: Button = hud.find_child("WeakPoint", true, false)
	_expect(weak.visible, "weak point button shows while the weak point is open")
	await _tap(weak.get_global_rect().get_center())
	_expect(sim.focus_t > 0.0, "tapping the weak point makes the ranged focus")

	sim.morale = PushSim.MORALE_MAX
	await _frames(1)
	var hp: float = sim.boss_hp
	await _press(hud.find_child("Volley", true, false))
	_expect(sim.morale < 1.0 and sim.boss_hp < hp - 1000.0, "volley spends the full bar on a big hit")

	sim.t = PushSim.DURATION - 0.01
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "result shows when time runs out")
	_expect(sim.phase == PushSim.Phase.LOST, "time out is a loss")
	var report: Label = hud.find_child("Report", true, false)
	_expect(report.is_visible_in_tree() and report.text.begins_with("MVP：") and report.text.contains("時間到"),
		"result shows the 推王戰報 with an MVP and the time-out advice")
	await _press(hud.find_child("Retry", true, false))
	_expect(main.sim != sim and main.sim.phase == PushSim.Phase.MUSTER, "retry starts a fresh push with a muster")

	# The tiles are the zones: resizing one in the editor resizes only that zone.
	var tile: Node3D = main.find_child("Zones", true, false).get_child(0)
	var before: PackedVector2Array = main.sim.zone_half.duplicate()
	tile.scale.x = 1.3
	main.new_push()
	var z: int = tile.zone_index
	_expect(is_equal_approx(main.sim.zone_half[z].x, before[z].x * 1.3), "a resized tile resizes its zone")
	var others_same: bool = true
	for k: int in PushSim.ZONES:
		if k != z and main.sim.zone_half[k] != before[k]:
			others_same = false
	_expect(others_same, "the other zones keep their size")
	tile.scale.x = 1.0
	_finish("MAIN UI TESTS")


## Screen point over a zone's centre.
func _screen(z: int) -> Vector2:
	var c: Vector2 = sim.zone_center[z]
	return main.find_child("Camera", true, false).unproject_position(Vector3(c.x, 0.0, c.y))
