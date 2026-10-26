extends RefCounted
## One 推王 (boss push) as pure state, stepped with sim seconds. No nodes: scripts/main.gd steps it with game time
## and the view reads its arrays; tests/test_balance.gd plays it headless with bots. Every number is hardcoded on
## purpose (prototype); the balance bands it must hit are asserted in tests/test_balance.gd.
##
## The field is six 區 (zones), 2 columns x 3 rows left of the boss: index = row * 2 + col, col 0 遠 (outer), col 1
## 近 (next to the boss). Heroes have their own HP, stand in one zone, and only melee in a 近 zone reach the boss.

signal event(kind: StringName, value: float)

enum Phase { MUSTER, FIGHT, WON, LOST }
enum Attack { SLAM, SWEEP, ROCKS }

const CLASS_NAMES := ["盾", "劍", "槍", "弓", "法", "補"]
const SHIELD := 0
const SWORD := 1
const SPEAR := 2
const BOW := 3
const MAGE := 4
const HEALER := 5
const ROSTER := [14, 20, 18, 18, 15, 15]
## Heroes per class and rarity (N, R, SR, SSR).
const RARITY_COUNTS := [[7, 4, 2, 1], [10, 5, 3, 2], [9, 5, 3, 1], [9, 5, 3, 1], [8, 4, 2, 1], [8, 4, 2, 1]]
const RARITY_NAMES := ["N", "R", "SR", "SSR"]
const R := 1
const SR := 2
const SSR := 3
## Rarity scales HP, attack and healing; R and up add a passive on the class's main stat (shield HP, healer
## healing, everyone else attack).
const RARITY_MULT := [1.0, 1.15, 1.3, 1.5]
const PASSIVE_MULT := 1.15
const ATK := [1.0, 3.0, 2.6, 2.4, 3.4, 0.0]
const HP := [300.0, 160.0, 150.0, 100.0, 90.0, 110.0]

const ZONES := 6
const ZONE_NAMES := ["遠1", "近1", "遠2", "近2", "遠3", "近3"]
const NEAR := 1
## Default geometry (ground x, z); scripts/main.gd replaces it with the zone tiles' real placement.
const ZONE_X := [-2.2, 0.8]
const ZONE_Z := [-2.7, 0.0, 2.7]
const ZONE_HALF := Vector2(1.4, 1.25)
## Only this many heroes per zone have room to attack; merged zones leave the rest waiting.
const CROWD_CAP := 20
const WALK_SPEED := 3.5

const DURATION := 150.0
const MUSTER_TIME := 6.0
const BOSS_HP := 48000.0
const PHASE2_AT := 0.5
const MORALE_MAX := 100.0
const MORALE_PER_DAMAGE := 0.01
const VOLLEY_SECONDS := 8.0

## 普通攻擊: no warning; hits a few heroes in the target zone, shields first. More crowded, more heroes hit.
const AUTO_EVERY := [1.6, 1.2]
const AUTO_DAMAGE := 110.0
const AUTO_TARGETS := 2
const AUTO_EXTRA_PER := 8
## 預警攻擊: zones are marked TELE_WARN seconds before the hit; whoever is still standing inside takes TELE_DAMAGE.
const TELE_FIRST := 8.0
const TELE_EVERY := [9.0, 6.5]
const TELE_WARN := 2.0
const TELE_DAMAGE := 140.0
const TELE_CYCLE := [[Attack.SLAM, Attack.ROCKS, Attack.SWEEP], [Attack.SWEEP, Attack.SLAM, Attack.ROCKS]]
const ATTACK_NAMES := ["重砸", "橫掃", "落石"]

const HEAL := 20.0
const HEAL_EVERY := 1.5
## 主動技能 cast themselves: damage dealers as soon as they are ready; shields when their zone is about to be hit;
## healers when someone in reach is low (an SSR healer also when a hero in its zone has fallen).
const SKILL_CD := 12.0
const GUARD_TIME := 5.0
const GUARD_MULT := 0.5
const SKILL_BURST := [0.0, 6.0, 5.0, 5.0, 8.0, 0.0]
const SKILL_HEAL := 50.0
const REVIVE_HP := 0.4
const LOW_HP := 0.6
## 光環 (SSR, same zone): shield damage taken, sword melee attack, spear everyone's attack, bow ranged attack,
## mage skill cooldown, healer regen per second.
const AURA_SHIELD := 0.8
const AURA_SWORD := 1.25
const AURA_SPEAR := 1.15
const AURA_BOW := 1.3
const AURA_MAGE := 0.7
const AURA_HEALER := 2.0

const WEAK_FIRST := 15.0
const WEAK_EVERY := 20.0
const WEAK_OPEN := 3.0
const FOCUS_TIME := 4.0
const FOCUS_MULT := 2.0
const BREAK_PER_WEAK := 0.5
const BREAK_TIME := 5.0
const BREAK_MULT := 1.5

var phase: int = Phase.MUSTER
var muster_t: float = 0.0
## Fight seconds since the muster ended; the push timer.
var t: float = 0.0
var boss_hp: float = BOSS_HP
var phase2: bool = false
var morale: float = 0.0
var damage_dealt: float = 0.0
## Damage per second of the last step, for the HUD.
var dps: float = 0.0
var fallen_total: int = 0

var cls := PackedInt32Array()
var rarity := PackedInt32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var atk := PackedFloat32Array()
var zone := PackedInt32Array()
## The zone a hero was mustered into; 歸位 sends them back there.
var home := PackedInt32Array()
var pos := PackedVector2Array()
var goal := PackedVector2Array()
var skill_cd := PackedFloat32Array()
## Fight time of the last skill cast, for the view's cast pose (-1 = never).
var cast_at := PackedFloat32Array()

var zone_center := PackedVector2Array()
var zone_half := PackedVector2Array()
var guard_t := PackedFloat32Array()

## The telegraphed attack in flight: kind, target zones and seconds until it lands (0 = none).
var tele_t: float = 0.0
var tele_kind: int = Attack.SLAM
var tele_zones := PackedInt32Array()
## The zone the last auto attack hit, for the view.
var auto_zone: int = -1
## Heroes the last telegraphed attack hit (fallen or not).
var tele_hit_count: int = 0
var weak_t: float = 0.0
var focus_t: float = 0.0
var break_t: float = 0.0
var break_gauge: float = 0.0

## 推王戰報 (battle report) bookkeeping, per hero: boss damage dealt, damage taken, HP healed on allies, damage the
## hero's guard spared its zone, allies revived. Every fall is filed by cause (普攻 or the telegraph's name) and zone.
const CAUSE_AUTO := "普攻"
var dealt := PackedFloat32Array()
var taken := PackedFloat32Array()
var healed := PackedFloat32Array()
var spared := PackedFloat32Array()
var saves := PackedInt32Array()
var revived := PackedFloat32Array()  # HP the revives gave back (the target's, not the healer's)
var falls: Array[Dictionary] = []  # {hero, cause, zone, t}
var weak_opened: int = 0
var weak_hits: int = 0
var volleys: int = 0
var guard_by := PackedInt32Array()

var _next_tele: float = TELE_FIRST
var _tele_index: int = 0
var _auto_t: float = 1.0
var _heal_t: float = 0.0
var _next_weak: float = WEAK_FIRST
var _rng := RandomNumberGenerator.new()
## Per-zone aura multipliers, rebuilt every step.
var _aura := []


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	for row: int in 3:
		for col: int in 2:
			zone_center.append(Vector2(ZONE_X[col], ZONE_Z[row]))
			zone_half.append(ZONE_HALF)
	guard_t.resize(ZONES)
	guard_by.resize(ZONES)
	guard_by.fill(-1)
	for c: int in ROSTER.size():
		var k: int = 0
		for r: int in 4:
			for n: int in RARITY_COUNTS[c][r]:
				var mult: float = RARITY_MULT[r] * (PASSIVE_MULT if r >= R else 1.0)
				cls.append(c)
				rarity.append(r)
				max_hp.append(HP[c] * RARITY_MULT[r] * (PASSIVE_MULT if r >= R and c == SHIELD else 1.0))
				atk.append(ATK[c] * (mult if c != SHIELD else RARITY_MULT[r]))
				# Melee to the 近 column, ranged and healers to 遠, dealt round-robin over the three rows.
				var col: int = NEAR if c <= SPEAR else 0
				zone.append(((k + c) % 3) * 2 + col)
				k += 1
	hp = max_hp.duplicate()
	for arr: Variant in [dealt, taken, healed, spared, saves, revived]:
		arr.resize(cls.size())
	home = zone.duplicate()
	skill_cd.resize(cls.size())
	for i: int in cls.size():
		# Staggered so the first casts do not all land on the same frame.
		skill_cd[i] = _rng.randf() * SKILL_CD * 0.5
	cast_at.resize(cls.size())
	cast_at.fill(-1.0)
	pos.resize(cls.size())
	goal.resize(cls.size())
	for z: int in ZONES:
		_reslot(z)
	for i: int in cls.size():
		# Muster: everyone starts off-screen left, inner classes first.
		pos[i] = Vector2(-11.0 - cls[i] * 0.8 - _rng.randf() * 2.5, goal[i].y)
	for z: int in ZONES:
		_aura.append(_aura_of(z))


## Moves a zone's rectangle (the view's tiles are the source of truth) and re-places its heroes.
func set_zone(z: int, center: Vector2, half: Vector2) -> void:
	zone_center[z] = center
	zone_half[z] = half
	_reslot(z)


## The zone whose rectangle is nearest to p, if within `slack` metres (0 = strictly inside). -1 if none.
func zone_near(p: Vector2, slack: float) -> int:
	var best: int = -1
	var best_d: float = slack
	for z: int in ZONES:
		var d: Vector2 = ((p - zone_center[z]).abs() - zone_half[z]).max(Vector2.ZERO)
		if d.length() <= best_d:
			best_d = d.length()
			best = z
	return best


func zone_at(p: Vector2) -> int:
	for z: int in ZONES:
		var d: Vector2 = (p - zone_center[z]).abs()
		if d.x <= zone_half[z].x and d.y <= zone_half[z].y:
			return z
	return -1


func alive(i: int) -> bool:
	return hp[i] > 0.0


func moving(i: int) -> bool:
	return pos[i].distance_squared_to(goal[i]) > 0.0025


func living_in(z: int) -> int:
	var n: int = 0
	for i: int in cls.size():
		if zone[i] == z and hp[i] > 0.0:
			n += 1
	return n


func living() -> int:
	var n: int = 0
	for i: int in cls.size():
		if hp[i] > 0.0:
			n += 1
	return n


## True while a telegraphed attack is up and someone still stands in a marked zone.
func tele_threatens() -> bool:
	if tele_t <= 0.0:
		return false
	for i: int in cls.size():
		if hp[i] > 0.0 and zone_at(pos[i]) in tele_zones:
			return true
	return false


func time_left() -> float:
	return maxf(DURATION - t, 0.0)


func hp_ratio() -> float:
	return boss_hp / BOSS_HP


func fighting() -> bool:
	return phase == Phase.FIGHT


## advance(): frames feed the sim in fixed STEP ticks, so the frame rate never changes the fight. A frame longer
## than MAX_FRAME (a hitch, a backgrounded browser tab) only advances MAX_FRAME: the push pauses, it does not skip ahead.
const STEP := 1.0 / 60.0
const MAX_FRAME := 0.25
var ticks: int = 0
var _pending: float = 0.0


func advance(frame_dt: float) -> void:
	_pending += minf(frame_dt, MAX_FRAME)
	while _pending >= STEP:
		_pending -= STEP
		ticks += 1
		step(STEP)


func step(dt: float) -> void:
	if phase == Phase.MUSTER:
		muster_t += dt
		_walk(dt)
		if muster_t >= MUSTER_TIME:
			_start_fight()
	elif phase == Phase.FIGHT:
		_fight(dt)


func skip_muster() -> void:
	if phase == Phase.MUSTER:
		muster_t = MUSTER_TIME
		_start_fight()


## 移區: everyone alive in zone a walks to zone b and merges with it.
func move_zone(a: int, b: int) -> bool:
	if not fighting() or a == b or a < 0 or b < 0 or living_in(a) == 0:
		return false
	for i: int in cls.size():
		if zone[i] == a and hp[i] > 0.0:
			zone[i] = b
	_reslot(b)
	event.emit(&"move", float(b))
	return true


## 全員歸位: every living hero walks back to the zone it mustered into.
func regroup() -> bool:
	if not fighting():
		return false
	var changed := {}
	for i: int in cls.size():
		if hp[i] > 0.0 and zone[i] != home[i]:
			changed[zone[i]] = true
			changed[home[i]] = true
			zone[i] = home[i]
	if changed.is_empty():
		return false
	for z: int in changed:
		_reslot(z)
	event.emit(&"regroup", float(changed.size()))
	return true


## Casts every ready 主動技能 whose moment has come (see SKILL_CD). Called each fight step.
func _auto_skills() -> void:
	var burst: float = 0.0
	for i: int in cls.size():
		if hp[i] <= 0.0 or rarity[i] < SR or skill_cd[i] > 0.0 or moving(i):
			continue
		var z: int = zone[i]
		match cls[i]:
			SHIELD:
				var threatened: bool = (tele_t > 0.0 and tele_t < 1.0 and z in tele_zones) or z == auto_zone
				if not threatened:
					continue
				guard_t[z] = GUARD_TIME
				guard_by[z] = i
			HEALER:
				var fallen_here: bool = rarity[i] == SSR and _fallen_in(z) >= 0
				if _lowest_near(z) >= LOW_HP and not fallen_here:
					continue
				_heal_around(z, SKILL_HEAL * RARITY_MULT[rarity[i]], i)
				if fallen_here:
					_revive(z, i)
			_:
				var d: float = atk[i] * SKILL_BURST[cls[i]] * _aura[z].all
				dealt[i] += d
				burst += d
		skill_cd[i] = SKILL_CD * _aura[z].cd
		cast_at[i] = t
		event.emit(&"skill", float(i))
	if burst > 0.0:
		_deal(burst, true)


func tap_weak_point() -> bool:
	if not fighting() or weak_t <= 0.0:
		return false
	weak_t = 0.0
	weak_hits += 1
	focus_t = FOCUS_TIME
	break_gauge += BREAK_PER_WEAK
	event.emit(&"weak_hit", break_gauge)
	if break_gauge >= 1.0:
		break_gauge = 0.0
		break_t = BREAK_TIME
		event.emit(&"break", BREAK_TIME)
	return true


func volley() -> bool:
	if not fighting() or morale < MORALE_MAX:
		return false
	morale = 0.0
	volleys += 1
	var amount: float = 0.0
	for i: int in cls.size():
		if hp[i] > 0.0:
			amount += atk[i]
			dealt[i] += atk[i] * VOLLEY_SECONDS
	amount *= VOLLEY_SECONDS
	event.emit(&"volley", amount)
	_deal(amount, false)
	return true


func _start_fight() -> void:
	for i: int in cls.size():
		pos[i] = goal[i]
	phase = Phase.FIGHT
	event.emit(&"fight", 0.0)


func _fight(dt: float) -> void:
	t += dt
	focus_t = maxf(focus_t - dt, 0.0)
	break_t = maxf(break_t - dt, 0.0)
	for z: int in ZONES:
		guard_t[z] = maxf(guard_t[z] - dt, 0.0)
		_aura[z] = _aura_of(z)
	for i: int in cls.size():
		skill_cd[i] = maxf(skill_cd[i] - dt, 0.0)
	_walk(dt)
	if not phase2 and hp_ratio() <= PHASE2_AT:
		phase2 = true
		event.emit(&"phase2", 0.0)
	var p: int = 1 if phase2 else 0

	_auto_t -= dt
	if _auto_t <= 0.0:
		_auto_t += AUTO_EVERY[p]
		_auto_attack()

	if tele_t > 0.0:
		tele_t -= dt
		if tele_t <= 0.0:
			tele_t = 0.0
			_land()
	elif t >= _next_tele - TELE_WARN:
		_telegraph(TELE_CYCLE[p][_tele_index % 3], maxf(_next_tele - t, dt))
		_tele_index += 1
		_next_tele += TELE_EVERY[p]

	if weak_t > 0.0:
		weak_t = maxf(weak_t - dt, 0.0)
		if weak_t == 0.0:
			event.emit(&"weak_close", 0.0)
	elif t >= _next_weak:
		weak_t = WEAK_OPEN
		weak_opened += 1
		_next_weak += WEAK_EVERY
		event.emit(&"weak_open", WEAK_OPEN)

	_heal_t -= dt
	if _heal_t <= 0.0:
		_heal_t += HEAL_EVERY
		_healers()
	for i: int in cls.size():
		if hp[i] > 0.0 and hp[i] < max_hp[i]:
			hp[i] = minf(hp[i] + _aura[zone[i]].regen * dt, max_hp[i])

	_auto_skills()
	var amount: float = 0.0
	var room := PackedInt32Array()
	room.resize(ZONES)
	for i: int in cls.size():
		var z: int = zone[i]
		if hp[i] <= 0.0 or moving(i):
			continue
		var melee: bool = cls[i] <= SPEAR
		if melee and z % 2 != NEAR:
			continue
		if cls[i] == HEALER or room[z] >= CROWD_CAP:
			continue
		room[z] += 1
		var a: Dictionary = _aura[z]
		var d: float = atk[i] * a.all
		if melee:
			d *= a.melee
		else:
			d *= a.ranged
			if focus_t > 0.0:
				d *= FOCUS_MULT
		amount += d
		# ponytail: credited before _deal clamps at 0 HP, so the killing step may over-credit by one step's damage.
		dealt[i] += d * dt * (BREAK_MULT if break_t > 0.0 else 1.0)
	if break_t > 0.0:
		amount *= BREAK_MULT
	dps = amount
	_deal(amount * dt, true)
	if phase == Phase.FIGHT and (t >= DURATION or living() == 0):
		phase = Phase.LOST
		event.emit(&"lost", hp_ratio())


func _walk(dt: float) -> void:
	var step_m: float = WALK_SPEED * dt
	for i: int in cls.size():
		if hp[i] > 0.0:
			pos[i] = pos[i].move_toward(goal[i], step_m)


## Places a zone's living heroes on a grid inside it: shields nearest the boss, healers furthest.
func _reslot(z: int) -> void:
	var members: Array[int] = []
	for i: int in cls.size():
		if zone[i] == z and hp[i] > 0.0:
			members.append(i)
	if members.is_empty():
		return
	members.sort_custom(func(a: int, b: int) -> bool: return cls[a] < cls[b] or (cls[a] == cls[b] and a < b))
	var n: int = members.size()
	var w: float = zone_half[z].x * 2.0 * 0.86
	var h: float = zone_half[z].y * 2.0 * 0.86
	var cols: int = maxi(ceili(sqrt(n * w / h)), 1)
	var rows: int = ceili(float(n) / cols)
	for k: int in n:
		var c: int = k / rows
		var r: int = k % rows
		var x: float = zone_center[z].x + w * 0.5 - (c + 0.5) / cols * w
		var y: float = zone_center[z].y - h * 0.5 + (r + 0.5) / rows * h
		goal[members[k]] = Vector2(x, y)


func _aura_of(z: int) -> Dictionary:
	var a := {"taken": 1.0, "melee": 1.0, "all": 1.0, "ranged": 1.0, "cd": 1.0, "regen": 0.0}
	for i: int in cls.size():
		if zone[i] != z or hp[i] <= 0.0 or rarity[i] != SSR:
			continue
		match cls[i]:
			SHIELD: a.taken = AURA_SHIELD
			SWORD: a.melee = AURA_SWORD
			SPEAR: a.all = AURA_SPEAR
			BOW: a.ranged = AURA_BOW
			MAGE: a.cd = AURA_MAGE
			HEALER: a.regen = AURA_HEALER
	return a


func _auto_attack() -> void:
	var target: int = -1
	var best: int = -1
	for z: int in ZONES:
		var n: int = living_in(z)
		if n == 0:
			continue
		# The most crowded 近 zone, then any zone.
		var score: int = n + (100 if z % 2 == NEAR else 0)
		if score > best:
			best = score
			target = z
	auto_zone = target
	if target < 0:
		return
	var victims: Array[int] = []
	for i: int in cls.size():
		if zone[i] == target and hp[i] > 0.0:
			victims.append(i)
	victims.sort_custom(func(a: int, b: int) -> bool:
		if (cls[a] == SHIELD) != (cls[b] == SHIELD):
			return cls[a] == SHIELD
		return hp[a] > hp[b])
	var hits: int = mini(AUTO_TARGETS + victims.size() / AUTO_EXTRA_PER, victims.size())
	var fell: int = 0
	for k: int in hits:
		fell += _hurt(victims[k], AUTO_DAMAGE, CAUSE_AUTO)
	event.emit(&"auto", float(target))
	if fell > 0:
		event.emit(&"fallen", float(fell))


func _telegraph(kind: int, warn: float) -> void:
	tele_kind = kind
	tele_zones = PackedInt32Array()
	match kind:
		Attack.SLAM:
			var best: int = -1
			var target: int = 1
			for z: int in ZONES:
				var n: int = living_in(z)
				if n > best:
					best = n
					target = z
			tele_zones.append(target)
		Attack.SWEEP:
			tele_zones = PackedInt32Array([1, 3, 5])
		Attack.ROCKS:
			var far := [0, 2, 4]
			far.remove_at(_rng.randi_range(0, 2))
			tele_zones = PackedInt32Array(far)
	tele_t = warn
	event.emit(&"tele_warn", warn)


func _land() -> void:
	var fell: int = 0
	tele_hit_count = 0
	for i: int in cls.size():
		if hp[i] > 0.0 and zone_at(pos[i]) in tele_zones:
			tele_hit_count += 1
			fell += _hurt(i, TELE_DAMAGE, ATTACK_NAMES[tele_kind])
	event.emit(&"tele_hit", float(fell))
	tele_zones = PackedInt32Array()


## Damages a hero after zone guard and shield aura. Returns 1 if they fell.
func _hurt(i: int, amount: float, cause: String) -> int:
	var z: int = zone[i]
	var d: float = amount * _aura[z].taken
	if guard_t[z] > 0.0:
		if guard_by[z] >= 0:
			spared[guard_by[z]] += d * (1.0 - GUARD_MULT)
		d *= GUARD_MULT
	taken[i] += minf(d, hp[i])
	hp[i] = maxf(hp[i] - d, 0.0)
	if hp[i] == 0.0:
		fallen_total += 1
		falls.append({"hero": i, "cause": cause, "zone": z, "t": t})
		return 1
	return 0


func _healers() -> void:
	for i: int in cls.size():
		if cls[i] != HEALER or hp[i] <= 0.0:
			continue
		var amount: float = HEAL * RARITY_MULT[rarity[i]] * (PASSIVE_MULT if rarity[i] >= R else 1.0)
		var target: int = -1
		var worst: float = 1.0
		for j: int in cls.size():
			if hp[j] > 0.0 and hp[j] < max_hp[j] and _near(zone[i], zone[j]) and hp[j] / max_hp[j] < worst:
				worst = hp[j] / max_hp[j]
				target = j
		if target >= 0:
			healed[i] += minf(amount, max_hp[target] - hp[target])
			hp[target] = minf(hp[target] + amount, max_hp[target])


## ponytail: the SSR healer aura's regen is not credited to anyone; credit it once auras show in the report.
func _heal_around(z: int, amount: float, healer: int) -> void:
	for j: int in cls.size():
		if hp[j] > 0.0 and _near(z, zone[j]):
			healed[healer] += minf(amount, max_hp[j] - hp[j])
			hp[j] = minf(hp[j] + amount, max_hp[j])


func _revive(z: int, healer: int) -> bool:
	var j: int = _fallen_in(z)
	if j < 0:
		return false
	hp[j] = max_hp[j] * REVIVE_HP
	saves[healer] += 1
	revived[healer] += hp[j]
	fallen_total -= 1
	_reslot(z)
	event.emit(&"revive", float(z))
	return true


func _fallen_in(z: int) -> int:
	for j: int in cls.size():
		if hp[j] <= 0.0 and zone[j] == z:
			return j
	return -1


## Lowest HP ratio among the living in a zone and its neighbours.
func _lowest_near(z: int) -> float:
	var low: float = 1.0
	for j: int in cls.size():
		if hp[j] > 0.0 and _near(z, zone[j]):
			low = minf(low, hp[j] / max_hp[j])
	return low


## Same zone or orthogonally next to it.
func _near(a: int, b: int) -> bool:
	return absi(a / 2 - b / 2) + absi(a % 2 - b % 2) <= 1


func _deal(amount: float, earns_morale: bool) -> void:
	boss_hp = maxf(boss_hp - amount, 0.0)
	damage_dealt += amount
	if earns_morale:
		morale = minf(morale + amount * MORALE_PER_DAMAGE, MORALE_MAX)
	if boss_hp == 0.0 and phase == Phase.FIGHT:
		phase = Phase.WON
		event.emit(&"won", time_left())


# --- 推王戰報 -------------------------------------------------------------------

## "SSR 劍#2": rarity, class and number within that class and rarity (heroes have no names yet).
func hero_name(i: int) -> String:
	var n: int = 1
	for j: int in i:
		if cls[j] == cls[i] and rarity[j] == rarity[i]:
			n += 1
	return "%s %s#%d" % [RARITY_NAMES[rarity[i]], CLASS_NAMES[cls[i]], n]


## MVP score in HP-sized units: boss damage + HP healed + damage spared by guard + the HP each revive gave back.
func contribution(i: int) -> float:
	return dealt[i] + healed[i] + spared[i] + revived[i]


## {mvp, top: {metric: [[hero, value], ...] best 3 with a value > 0}, causes: {cause: falls}, zone_falls: [per zone],
## tele_falls / auto_falls: falls to telegraphs vs 普攻, advice: what to change next push, most falls first}.
## Cumulative over the push, not per second. A wipe ends in 普攻 falls once the army is thin, so read the two totals
## before the per-cause lines.
func report() -> Dictionary:
	var metrics := {"dealt": dealt, "taken": taken, "healed": healed, "spared": spared, "saves": saves}
	var top := {}
	for m: String in metrics:
		var arr: Variant = metrics[m]
		var order: Array = range(cls.size()).filter(func(i: int) -> bool: return arr[i] > 0)
		order.sort_custom(func(a: int, b: int) -> bool: return arr[a] > arr[b] or (arr[a] == arr[b] and a < b))
		top[m] = order.slice(0, 3).map(func(i: int) -> Array: return [i, arr[i]])
	var mvp: int = 0
	for i: int in cls.size():
		if contribution(i) > contribution(mvp):
			mvp = i
	var causes := {}
	var zone_falls := PackedInt32Array()
	zone_falls.resize(ZONES)
	var auto_zone_falls := PackedInt32Array()
	auto_zone_falls.resize(ZONES)
	for f: Dictionary in falls:
		causes[f.cause] = int(causes.get(f.cause, 0)) + 1
		zone_falls[f.zone] += 1
		if f.cause == CAUSE_AUTO:
			auto_zone_falls[f.zone] += 1
	var advice: Array = []  # [falls, line]
	var tips := {"重砸": "它打人最多的一區，別把人全合在一起，預警時把那區移開",
		"橫掃": "它打整條近欄，預警時把近欄往 ◀ 移，落下後再歸位",
		"落石": "它打兩個遠欄區，預警時把那兩區往 ▶ 移"}
	for cause: String in causes:
		var n: int = causes[cause]
		if n < 3:
			continue
		if cause == CAUSE_AUTO:
			var z: int = Array(auto_zone_falls).find(Array(auto_zone_falls).max())
			advice.append([n, "普攻在%s打倒 %d 人：它集中打近欄人最多的區，那區要有盾，人越擠一次打到越多人" % [ZONE_NAMES[z], n]])
		else:
			advice.append([n, "%s打倒 %d 人：%s" % [cause, n, tips[cause]]])
	var tele_falls: int = falls.size() - int(causes.get(CAUSE_AUTO, 0))
	advice.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var lines := PackedStringArray(advice.map(func(a: Array) -> String: return a[1]))
	if phase == Phase.LOST and living() > 0:
		lines.append("時間到，王還剩 %d%%：弱點點中 %d／%d 次、大招 %d 次——點弱點破防，士氣滿就放大招" % [
			ceili(hp_ratio() * 100.0), weak_hits, weak_opened, volleys])
	return {"mvp": mvp, "top": top, "causes": causes, "zone_falls": zone_falls, "tele_falls": tele_falls,
		"auto_falls": int(causes.get(CAUSE_AUTO, 0)), "advice": lines}
