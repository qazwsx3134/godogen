extends "res://addons/proto_kit/test_kit.gd"
## README acceptance criteria 1 and 2, played by bots on the pure sim (5 seeds):
##   idle     never touches anything                                                       -> loses
##   good     the moment a telegraph shows, moves every squad standing in it to the nearest safe spot, sends
##            everyone home after the hit, aims the ranged squad at the horns then the arm, volleys
##                                                                                        -> wins with 25-45 s left
##   noparts  the same, but never aims at a part                                           -> clearly worse than good
##   human    the same plan as good, but reacts REACTION s after each cue, acts at most once per ACTION_GAP s and
##            dodges the way a person drags: straight away from the red shape until clear (turning aside when the
##            field edge or another shape is in the way), not to the best spot on the field -> still wins
##   late     the same, but only gets to the dodge after the hit landed                    -> loses
## One action = one flag moved, one aim, one tap; the log shows actions per minute (the one-finger budget).
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_balance.gd

const PushSim = preload("res://domain/push_sim.gd")
const DT := 1.0 / 60.0
const SEEDS := [1, 2, 3, 4, 5]
const REACTION := 0.6
const ACTION_GAP := 0.5
## A dodge keeps the squad's block this far clear of the telegraph.
const CLEAR := 0.35
const AIM_ORDER := [PushSim.Part.HORNS, PushSim.Part.ARM, PushSim.Part.LEGS]


func _init() -> void:
	for seed_value: int in SEEDS:
		var idle: Dictionary = _play(seed_value, {"idle": true})
		var good: Dictionary = _play(seed_value, {})
		var noparts: Dictionary = _play(seed_value, {"noparts": true})
		var human: Dictionary = _play(seed_value, {"reaction": REACTION, "gap": ACTION_GAP, "naive": true})
		var late: Dictionary = _play(seed_value, {"reaction": PushSim.TELE_WARN + 0.5, "gap": ACTION_GAP})
		print("seed %d  idle %s\n        good %s\n     noparts %s\n       human %s\n        late %s" % [seed_value,
			_line(idle), _line(good), _line(noparts), _line(human), _line(late)])
		var g: PushSim = good.sim
		var np: PushSim = noparts.sim
		_expect(idle.sim.phase == PushSim.Phase.LOST, "seed %d: idle loses" % seed_value)
		_expect(g.phase == PushSim.Phase.WON and g.time_left() >= 25.0 and g.time_left() <= 45.0,
			"seed %d: good wins with 25-45 s left (got %s)" % [seed_value, _line(good)])
		_expect(np.phase == PushSim.Phase.LOST or g.time_left() - np.time_left() >= 8.0 or np.fallen_total - g.fallen_total >= 10,
			"seed %d: breaking parts clearly helps (good %s vs noparts %s)" % [seed_value, _line(good), _line(noparts)])
		_expect(human.sim.phase == PushSim.Phase.WON and human.sim.time_left() >= 10.0,
			"seed %d: human wins with 10+ s left (got %s)" % [seed_value, _line(human)])
		_expect(late.sim.phase == PushSim.Phase.LOST, "seed %d: late dodging loses" % seed_value)
	_finish("BALANCE TESTS")


func _play(seed_value: int, opts: Dictionary) -> Dictionary:
	var sim := PushSim.new(seed_value)
	var reaction: float = opts.get("reaction", 0.0)
	var gap: float = opts.get("gap", 0.0)
	var tele_seen: float = -1.0
	var next_action: float = 0.0
	var actions: int = 0
	sim.skip_muster()
	while sim.fighting():
		if not opts.get("idle", false) and sim.t >= next_action:
			var acted: bool = false
			if sim.tele_t > 0.0:
				if tele_seen < 0.0:
					tele_seen = sim.t
				if sim.t - tele_seen >= reaction:
					acted = _dodge_naive(sim) if opts.get("naive", false) else _dodge(sim)
			elif tele_seen >= 0.0:
				tele_seen = -1.0
				acted = sim.regroup()
			if not acted:
				acted = _act(sim, opts.get("noparts", false))
			if acted:
				actions += 1
				next_action = sim.t + gap
		sim.step(DT)
	return {"sim": sim, "apm": actions / maxf(sim.t, 1.0) * 60.0}


## Moves the first squad with someone in the telegraph to the nearest spot where its whole block stands clear.
## False when every squad is already clear (or already walking somewhere clear).
func _dodge(sim: PushSim) -> bool:
	for s: int in PushSim.SQUADS:
		if sim.squad_living(s) == 0:
			continue
		var half: Vector2 = sim.block_half(s) + Vector2(CLEAR, CLEAR)
		if _clear(sim, sim.flag[s], half):
			continue
		var best := Vector2.INF
		var best_d: float = INF
		var p := Vector2(PushSim.FIELD_MIN.x, PushSim.FIELD_MIN.y)
		while p.x <= PushSim.FIELD_MAX.x:
			p.y = PushSim.FIELD_MIN.y
			while p.y <= PushSim.FIELD_MAX.y:
				var d: float = p.distance_to(sim.flag[s])
				if d < best_d and _clear(sim, p, half):
					best_d = d
					best = p
				p.y += 0.25
			p.x += 0.25
		if best != Vector2.INF:
			return sim.move_flag(s, best)
	return false


## A person's dodge: drag the first squad standing in red straight away from the shape that holds it (the band:
## straight back), as far as it takes to be clear; if the edge of the field or another shape is in the way, the same
## drag turned further and further aside (30 degrees at a time, both ways, up to straight back the other way).
func _dodge_naive(sim: PushSim) -> bool:
	for s: int in PushSim.SQUADS:
		if sim.squad_living(s) == 0:
			continue
		var from: Vector2 = sim.flag[s]
		var half: Vector2 = sim.block_half(s) + Vector2(CLEAR, CLEAR)
		if _clear(sim, from, half):
			continue
		var away := Vector2.LEFT
		for shape: Dictionary in sim.tele_shapes:
			if shape.kind == &"circle" and not _clear_of(shape, from, half):
				away = (from - shape.c).normalized() if from != shape.c else Vector2.LEFT
				break
		for turn: float in [0.0, 0.52, -0.52, 1.05, -1.05, 1.57, -1.57, 2.09, -2.09, 2.62, -2.62, PI]:
			var dir: Vector2 = away.rotated(turn)
			var dist: float = 0.5
			while dist <= 7.0:
				var to: Vector2 = (from + dir * dist).clamp(PushSim.FIELD_MIN, PushSim.FIELD_MAX)
				if _clear(sim, to, half):
					return sim.move_flag(s, to)
				dist += 0.25
	return false


## Whether a block of half-size `half` centred on p stays out of every telegraph shape.
func _clear(sim: PushSim, p: Vector2, half: Vector2) -> bool:
	for shape: Dictionary in sim.tele_shapes:
		if not _clear_of(shape, p, half):
			return false
	return true


func _clear_of(shape: Dictionary, p: Vector2, half: Vector2) -> bool:
	if shape.kind == &"band":
		return p.x + half.x < shape.x
	var nearest: Vector2 = shape.c.clamp(p - half, p + half)
	return nearest.distance_to(shape.c) > shape.r


func _act(sim: PushSim, noparts: bool) -> bool:
	if sim.morale >= PushSim.MORALE_MAX:
		return sim.volley()
	if not noparts and sim.aim < 0:
		for p: int in AIM_ORDER:
			if not sim.broken(p):
				return sim.aim_at(p)
	return false


func _line(r: Dictionary) -> String:
	var sim: PushSim = r.sim
	var parts := ""
	for p: int in PushSim.PART_NAMES.size():
		parts += PushSim.PART_NAMES[p][0] if sim.broken(p) else "-"
	return "%s %3.0f%% %5.1fs fell %2d parts %s apm %4.1f" % ["WON " if sim.phase == PushSim.Phase.WON else "LOST",
		sim.hp_ratio() * 100.0, sim.time_left(), sim.fallen_total, parts, r.apm]
