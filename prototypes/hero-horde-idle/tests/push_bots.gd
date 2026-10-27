extends RefCounted
## The push bots, shared by tests/test_balance.gd (one push at the reference roster) and tests/test_progression.gd
## (pushes between growth rounds). play(seed, opts) plays one push headless and returns {sim, apm}:
##   {}                    good: the moment a telegraph shows, moves every squad standing in it to the nearest safe
##                         spot on the field, sends everyone home after the hit, aims the ranged squad at the horns,
##                         the arm, then the legs, volleys when the morale is full
##   "idle": true          never touches anything
##   "noparts": true       the same as good, but never aims at a part
##   "reaction", "gap"     reacts that many seconds after each cue, acts at most once per gap
##   "naive": true         dodges the way a person drags: straight away from the red shape until clear (turning aside
##                         when the field edge or another shape is in the way), not to the best spot on the field
##   "roster": {...}       progression.gd roster() for PushSim.new()
##   "stage": {...}        stages.gd stage(n) for PushSim.new() (the boss of that 關卡)
## One action = one flag moved, one aim, one tap; apm is actions per minute (the one-finger budget).

const PushSim = preload("res://domain/push_sim.gd")
const DT := 1.0 / 60.0
const REACTION := 0.6
const ACTION_GAP := 0.5
## A dodge keeps the squad's block this far clear of the telegraph.
const CLEAR := 0.35
const AIM_ORDER := [PushSim.Part.HORNS, PushSim.Part.ARM, PushSim.Part.LEGS]
## The bots by name.
const GOOD := {}
const IDLE := {"idle": true}
const NOPARTS := {"noparts": true}
const HUMAN := {"reaction": REACTION, "gap": ACTION_GAP, "naive": true}
const LATE := {"reaction": PushSim.TELE_WARN + 0.5, "gap": ACTION_GAP}


static func play(seed_value: int, opts: Dictionary) -> Dictionary:
	var sim := PushSim.new(seed_value, opts.get("roster", {}), opts.get("stage", {}))
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
					acted = dodge_naive(sim) if opts.get("naive", false) else dodge(sim)
			elif tele_seen >= 0.0:
				tele_seen = -1.0
				acted = sim.regroup()
			if not acted:
				acted = act(sim, opts.get("noparts", false))
			if acted:
				actions += 1
				next_action = sim.t + gap
		sim.step(DT)
	return {"sim": sim, "apm": actions / maxf(sim.t, 1.0) * 60.0}


## Moves the first squad with someone in the telegraph to the nearest spot where its whole block stands clear.
## False when every squad is already clear (or already walking somewhere clear).
static func dodge(sim: PushSim) -> bool:
	for s: int in PushSim.SQUADS:
		if sim.squad_living(s) == 0:
			continue
		var half: Vector2 = sim.block_half(s) + Vector2(CLEAR, CLEAR)
		if clear(sim, sim.flag[s], half):
			continue
		var best := Vector2.INF
		var best_d: float = INF
		var p := Vector2(PushSim.FIELD_MIN.x, PushSim.FIELD_MIN.y)
		while p.x <= PushSim.FIELD_MAX.x:
			p.y = PushSim.FIELD_MIN.y
			while p.y <= PushSim.FIELD_MAX.y:
				var d: float = p.distance_to(sim.flag[s])
				if d < best_d and clear(sim, p, half):
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
static func dodge_naive(sim: PushSim) -> bool:
	for s: int in PushSim.SQUADS:
		if sim.squad_living(s) == 0:
			continue
		var from: Vector2 = sim.flag[s]
		var half: Vector2 = sim.block_half(s) + Vector2(CLEAR, CLEAR)
		if clear(sim, from, half):
			continue
		var away := Vector2.LEFT
		for shape: Dictionary in sim.tele_shapes:
			if shape.kind == &"circle" and not clear_of(shape, from, half):
				away = (from - shape.c).normalized() if from != shape.c else Vector2.LEFT
				break
		for turn: float in [0.0, 0.52, -0.52, 1.05, -1.05, 1.57, -1.57, 2.09, -2.09, 2.62, -2.62, PI]:
			var dir: Vector2 = away.rotated(turn)
			var dist: float = 0.5
			while dist <= 7.0:
				var to: Vector2 = (from + dir * dist).clamp(PushSim.FIELD_MIN, PushSim.FIELD_MAX)
				if clear(sim, to, half):
					return sim.move_flag(s, to)
				dist += 0.25
	return false


## Whether a block of half-size `half` centred on p stays out of every telegraph shape.
static func clear(sim: PushSim, p: Vector2, half: Vector2) -> bool:
	for shape: Dictionary in sim.tele_shapes:
		if not clear_of(shape, p, half):
			return false
	return true


static func clear_of(shape: Dictionary, p: Vector2, half: Vector2) -> bool:
	if shape.kind == &"band":
		return p.x + half.x < shape.x
	var nearest: Vector2 = shape.c.clamp(p - half, p + half)
	return nearest.distance_to(shape.c) > shape.r


static func act(sim: PushSim, noparts: bool) -> bool:
	if sim.morale >= PushSim.MORALE_MAX:
		return sim.volley()
	if not noparts and sim.aim < 0:
		for p: int in AIM_ORDER:
			if not sim.broken(p):
				return sim.aim_at(p)
	return false


static func line(r: Dictionary) -> String:
	var sim: PushSim = r.sim
	var parts := ""
	for p: int in PushSim.PART_NAMES.size():
		parts += PushSim.PART_NAMES[p][0] if sim.broken(p) else "-"
	return "%s %3.0f%% %5.1fs fell %2d parts %s apm %4.1f" % ["WON " if sim.phase == PushSim.Phase.WON else "LOST",
		sim.hp_ratio() * 100.0, sim.time_left(), sim.fallen_total, parts, r.apm]
