extends RefCounted
## 行軍 (the march) as pure state, stepped in fixed TICK steps: the same seed and the same dt total give the same
## fight at any frame rate. The march squad (3-5 heroes from progression.gd march_units()) stands in a line on the
## left, the shield in front; WAVE_SIZE monsters walk in from the right and fight them, WAVES waves make a 段, then the
## squad marches on for TRAVEL_TIME (the view scrolls) and the next 段 begins. A kill is an event (progression.gd
## march_kill pays it out); the squad falling is `lost` (the caller steps back a stage and starts a new march).
##
## Heroes keep their push classes and numbers (PushSim.base_stats x growth, x SCALE so the popups read as whole
## numbers): melee reach only the front monster, ranged and healers reach the whole lane. SR and up cast their 主動技能
## on SKILL_CD: damage dealers a burst, shields a guard for the squad, healers a heal on everyone. The forms' passives
## (domain/heroes.gd) and the squad's bonds come in through the units. A stage's monsters scale like its boss
## (Stages.stage(n) hp / dmg). measure() plays a march headless to price an offline stretch.

const PushSim = preload("res://domain/push_sim.gd")
const Heroes = preload("res://domain/heroes.gd")
const Stages = preload("res://domain/stages.gd")

const TICK := 0.05
const SCALE := 10.0
## Where each class stands (x, the lane grows to the right) and how far it reaches.
const CLASS_X := [0.0, -0.5, -0.9, -2.2, -2.6, -3.1]
const CLASS_REACH := [1.4, 1.7, 2.3, 9.0, 9.0, 9.0]
## A hero hits once per HIT_EVERY[class] seconds for atk x HIT_EVERY (the push's atk is damage per second).
const HIT_EVERY := [1.2, 0.9, 1.0, 1.1, 1.4, 1.5]
const HEAL := 20.0
const HEAL_EVERY := 1.5
const SKILL_CD := 12.0
const SKILL_BURST := [0.0, 6.0, 5.0, 5.0, 8.0, 0.0]
const GUARD_TIME := 5.0
const GUARD_MULT := 0.5
const SKILL_HEAL := 50.0

const WAVE_SIZE := 3
const WAVES := 3
const SPAWN_X := 7.5
const ENEMY_GAP := 0.8
const ENEMY_SPEED := 2.4
## Monsters stop this far in front of the front hero, and hit every ENEMY_HIT_EVERY seconds.
const ENEMY_CONTACT := 0.9
const ENEMY_HIT_EVERY := 1.3
## A stage-1 monster at x1 (Stages.stage hp / dmg scale it): HP, and damage per second.
const ENEMY_HP := 70.0
const ENEMY_DPS := 28.0
## The 段's last wave has a big one with ELITE_MULT HP and damage.
const ELITE_MULT := 3.0
const WAVE_GAP := 0.8
const TRAVEL_TIME := 1.6

## units: [{hero, cls, rarity, form, hp, atk, heal, lifesteal, regen, heal_taken, guard}] (progression.gd march_units()).
var stage: int = 1
var t: float = 0.0
var kills: int = 0
var waves_cleared: int = 0
var lost: bool = false
## Seconds left of the march between 段 (> 0: walking, the view scrolls).
var travel_t: float = 0.0
var hero := PackedInt32Array()
var cls := PackedInt32Array()
var form := PackedInt32Array()
var rarity := PackedInt32Array()
var hx := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var atk := PackedFloat32Array()
var heal_power := PackedFloat32Array()
var lifesteal := PackedFloat32Array()
var regen := PackedFloat32Array()
var heal_taken := PackedFloat32Array()
var hit_cd := PackedFloat32Array()
var skill_cd := PackedFloat32Array()
## Fight time of each hero's last hit and skill (the view's attack and cast poses).
var hit_at := PackedFloat32Array()
var cast_at := PackedFloat32Array()
var guard: float = 0.0
var guard_t: float = 0.0
var cd_mult: float = 1.0
## Monsters of the wave on the field: x, HP, max HP, damage per second, whether elite, hit cooldown, last hit time.
var ex := PackedFloat32Array()
var ehp := PackedFloat32Array()
var emax := PackedFloat32Array()
var edps := PackedFloat32Array()
var elite := PackedByteArray()
var ehit_cd := PackedFloat32Array()
var ehit_at := PackedFloat32Array()
## What happened since the view last took them: {kind: &"hit"|&"enemy_hit"|&"heal"|&"kill"|&"skill"|&"wave"|
## &"travel"|&"lost", ...}; the view drains it with take_events().
var events: Array = []

var _rng := RandomNumberGenerator.new()
var _left: float = 0.0
var _wave: int = 0
var _wave_in: float = 0.5
var _heal_in: float = 0.0
var _enemy_hp: float = ENEMY_HP
var _enemy_dps: float = ENEMY_DPS


func _init(seed_value: int, units: Array, stage_n: int, cooldown_mult: float = 1.0) -> void:
	_rng.seed = seed_value
	stage = stage_n
	cd_mult = cooldown_mult
	var s: Dictionary = Stages.stage(stage_n)
	_enemy_hp = ENEMY_HP * s.hp
	_enemy_dps = ENEMY_DPS * s.dmg
	for u: Dictionary in units:
		hero.append(u.hero)
		cls.append(u.cls)
		form.append(u.form)
		rarity.append(u.rarity)
		hx.append(CLASS_X[u.cls])
		max_hp.append(u.hp * SCALE)
		hp.append(u.hp * SCALE)
		atk.append(u.atk * SCALE)
		heal_power.append(u.heal * SCALE)
		lifesteal.append(u.lifesteal)
		regen.append(u.regen)
		heal_taken.append(u.heal_taken)
		hit_cd.append(_rng.randf() * HIT_EVERY[u.cls])
		skill_cd.append(SKILL_CD * cd_mult * (0.4 + 0.4 * _rng.randf()))
		hit_at.append(-1.0)
		cast_at.append(-1.0)
		guard = u.get("guard", 0.0)
	# Two heroes of one class stand a little apart.
	for i: int in hx.size():
		for j: int in i:
			if cls[j] == cls[i]:
				hx[i] -= 0.35


## Advances the march by dt seconds in fixed TICK steps (the remainder waits for the next call).
func step(dt: float) -> void:
	_left += dt
	# A hair of slack so float sums of 1/fps never drop the last tick.
	while _left >= TICK - 1e-9 and not lost:
		_left -= TICK
		_tick(TICK)


func take_events() -> Array:
	var out: Array = events
	events = []
	return out


func alive(i: int) -> bool:
	return hp[i] > 0.0


func living() -> int:
	var n: int = 0
	for i: int in hp.size():
		if hp[i] > 0.0:
			n += 1
	return n


func walking() -> bool:
	return travel_t > 0.0


func _tick(dt: float) -> void:
	t += dt
	guard_t = maxf(guard_t - dt, 0.0)
	for i: int in hp.size():
		if hp[i] > 0.0 and hp[i] < max_hp[i] and regen[i] > 0.0:
			hp[i] = minf(hp[i] + max_hp[i] * regen[i] * dt, max_hp[i])
	if travel_t > 0.0:
		travel_t -= dt
		if travel_t <= 0.0:
			travel_t = 0.0
			_wave_in = 0.3
		return
	if ex.is_empty():
		_wave_in -= dt
		if _wave_in <= 0.0:
			_spawn()
		return
	_enemies(dt)
	_heroes(dt)
	_healers(dt)
	_skills(dt)
	if living() == 0:
		lost = true
		events.append({"kind": &"lost"})


func _spawn() -> void:
	var big: bool = _wave == WAVES - 1
	for k: int in WAVE_SIZE:
		var is_elite: bool = big and k == WAVE_SIZE - 1
		var mult: float = ELITE_MULT if is_elite else 1.0
		ex.append(SPAWN_X + k * ENEMY_GAP)
		var h: float = _enemy_hp * mult * _rng.randf_range(0.9, 1.1)
		ehp.append(h)
		emax.append(h)
		edps.append(_enemy_dps * mult)
		elite.append(1 if is_elite else 0)
		ehit_cd.append(_rng.randf() * ENEMY_HIT_EVERY)
		ehit_at.append(-1.0)
	events.append({"kind": &"wave", "wave": _wave})


func _front_hero() -> int:
	var best: int = -1
	for i: int in hp.size():
		if hp[i] > 0.0 and (best < 0 or hx[i] > hx[best]):
			best = i
	return best


## The living monster nearest the squad (-1 when none).
func _front_enemy() -> int:
	var best: int = -1
	for k: int in ex.size():
		if ehp[k] > 0.0 and (best < 0 or ex[k] < ex[best]):
			best = k
	return best


func _enemies(dt: float) -> void:
	var front: int = _front_hero()
	if front < 0:
		return
	var stop: float = hx[front] + ENEMY_CONTACT
	for k: int in ex.size():
		if ehp[k] <= 0.0:
			continue
		# Each monster queues behind the one ahead.
		var limit: float = stop
		for j: int in k:
			if ehp[j] > 0.0:
				limit = maxf(limit, ex[j] + ENEMY_GAP * 0.7)
		ex[k] = maxf(ex[k] - ENEMY_SPEED * dt, limit)
		if ex[k] > stop + 0.05:
			continue
		ehit_cd[k] -= dt
		if ehit_cd[k] <= 0.0:
			ehit_cd[k] += ENEMY_HIT_EVERY
			ehit_at[k] = t
			var d: float = edps[k] * ENEMY_HIT_EVERY * (1.0 - guard) * (GUARD_MULT if guard_t > 0.0 else 1.0)
			d *= _rng.randf_range(0.85, 1.15)
			hp[front] = maxf(hp[front] - d, 0.0)
			events.append({"kind": &"enemy_hit", "enemy": k, "hero": front, "amount": d})
			if hp[front] <= 0.0:
				front = _front_hero()
				if front < 0:
					return
				stop = hx[front] + ENEMY_CONTACT


func _heroes(dt: float) -> void:
	for i: int in hp.size():
		if hp[i] <= 0.0 or cls[i] == PushSim.HEALER:
			continue
		hit_cd[i] -= dt
		if hit_cd[i] > 0.0:
			continue
		var target: int = _front_enemy()
		if target < 0 or ex[target] - hx[i] > CLASS_REACH[cls[i]]:
			hit_cd[i] = 0.0
			continue
		hit_cd[i] += HIT_EVERY[cls[i]]
		hit_at[i] = t
		var crit: bool = _rng.randf() < 0.1
		_strike(i, target, atk[i] * HIT_EVERY[cls[i]] * _rng.randf_range(0.9, 1.1) * (1.8 if crit else 1.0), crit)


func _strike(i: int, target: int, amount: float, crit: bool) -> void:
	var dealt: float = minf(amount, ehp[target])
	ehp[target] -= amount
	events.append({"kind": &"hit", "hero": i, "enemy": target, "amount": amount, "crit": crit})
	if lifesteal[i] > 0.0 and hp[i] > 0.0:
		hp[i] = minf(hp[i] + dealt * lifesteal[i], max_hp[i])
	if ehp[target] <= 0.0:
		ehp[target] = 0.0
		kills += 1
		events.append({"kind": &"kill", "enemy": target, "elite": elite[target] == 1, "stage": stage})
		if _front_enemy() < 0:
			_wave_done()


func _wave_done() -> void:
	ex.clear()
	ehp.clear()
	emax.clear()
	edps.clear()
	elite.clear()
	ehit_cd.clear()
	ehit_at.clear()
	waves_cleared += 1
	_wave += 1
	if _wave >= WAVES:
		_wave = 0
		travel_t = TRAVEL_TIME
		events.append({"kind": &"travel"})
	else:
		_wave_in = WAVE_GAP


func _healers(dt: float) -> void:
	_heal_in -= dt
	if _heal_in > 0.0:
		return
	_heal_in += HEAL_EVERY
	for i: int in hp.size():
		if hp[i] <= 0.0 or cls[i] != PushSim.HEALER:
			continue
		var target: int = -1
		for j: int in hp.size():
			if hp[j] > 0.0 and hp[j] < max_hp[j] and (target < 0 or hp[j] / max_hp[j] < hp[target] / max_hp[target]):
				target = j
		if target >= 0:
			_heal(i, target, heal_power[i])


func _heal(from: int, to: int, amount: float) -> void:
	var a: float = minf(amount * heal_taken[to], max_hp[to] - hp[to])
	if a <= 0.0:
		return
	hp[to] += a
	events.append({"kind": &"heal", "hero": from, "target": to, "amount": a})


func _skills(dt: float) -> void:
	for i: int in hp.size():
		if hp[i] <= 0.0 or rarity[i] < PushSim.SR:
			continue
		skill_cd[i] -= dt
		if skill_cd[i] > 0.0:
			continue
		match cls[i]:
			PushSim.SHIELD:
				guard_t = GUARD_TIME
			PushSim.HEALER:
				for j: int in hp.size():
					if hp[j] > 0.0:
						_heal(i, j, heal_power[i] * SKILL_HEAL / HEAL)
			_:
				var target: int = _front_enemy()
				if target < 0 or ex[target] - hx[i] > CLASS_REACH[cls[i]]:
					skill_cd[i] = 0.0
					continue
				_strike(i, target, atk[i] * SKILL_BURST[cls[i]], true)
		skill_cd[i] = SKILL_CD * cd_mult
		cast_at[i] = t
		events.append({"kind": &"skill", "hero": i})


## Measures raw kills and reward units (elite x3) per second. A fallen squad reports lost.
static func measure(units: Array, stage_n: int, seconds: float, cooldown_mult: float = 1.0) -> Dictionary:
	var sim := new(4242, units, stage_n, cooldown_mult)
	var reward_units := 0
	var steps: int = roundi(seconds / TICK)
	for k: int in steps:
		sim._tick(TICK)
		for event: Dictionary in sim.take_events():
			if event.kind == &"kill":
				reward_units += 3 if event.elite else 1
		if sim.lost:
			break
	return {"kills_per_sec": sim.kills / maxf(sim.t, TICK),
		"reward_units_per_sec": reward_units / maxf(sim.t, TICK), "reward_units": reward_units,
		"lost": sim.lost, "kills": sim.kills}
