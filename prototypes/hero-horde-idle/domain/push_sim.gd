extends RefCounted
## One 推王 (boss push) as pure state, stepped with sim seconds. No nodes: scripts/main.gd steps it with game time
## and the view reads its arrays; tests/test_balance.gd plays it headless with bots. Every number is hardcoded on
## purpose (prototype); the balance bands it must hit are asserted in tests/test_balance.gd.
##
## The field is open ground left of the boss (x grows toward him, z is up/down the screen). The heroes form three
## 團 (squads): 近戰 (盾 劍 槍), 遠程 (弓 法), 輔助 (補). Each squad gathers around its flag; moving a flag walks the
## squad there and it settles into an uneven blob (shields nearest the boss), stragglers trailing behind. Melee only
## reach the boss from his front band; ranged shoot from anywhere; healers reach whoever stands within HEAL_RANGE.
## Telegraphed attacks are shapes on the ground (circles and the band in front of the boss): whoever's feet are
## inside when it lands is hit, so a squad that moves late loses its tail.
##
## The boss has parts with their own HP. Melee hit the legs (or the arm while the club lies on the ground after a
## slam); ranged hit the part the player aims at, at a cost: aimed shots count only PART_BODY_SHARE toward the boss's
## HP. Breaking a part knocks him down for STAGGER_TIME (the telegraph in flight is cancelled, no attacks, everyone's
## damage x STAGGER_MULT), and the part stays broken for the push: legs -> he moves slower; arm -> no 橫掃, smaller 重砸; horns -> no
## 落石. Every broken part is also a wound: all damage to him is WOUND_PER_PART higher per part. A disabled attack's
## turn becomes a 重砸, which can only be shrunk, never removed.

signal event(kind: StringName, value: float)

enum Phase { MUSTER, FIGHT, WON, LOST }
enum Attack { SLAM, SWEEP, ROCKS }
enum Part { LEGS, ARM, HORNS }

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

const SQUADS := 3
const MELEE := 0
const RANGED := 1
const SUPPORT := 2
const SQUAD_NAMES := ["近戰團", "遠程團", "輔助團"]
## Squad of each class.
const CLASS_SQUAD := [MELEE, MELEE, MELEE, RANGED, RANGED, SUPPORT]
## Where each squad musters by default (main.tscn's flags replace it, see set_home), and the blob it settles into:
## an ellipse this many times taller (along z) than deep (along x), every hero getting SPACING^2 of ground, each
## nudged up to JITTER off the spiral so the crowd never lines up.
const HOME := [Vector2(1.35, 0.0), Vector2(-2.3, -1.6), Vector2(-1.2, 2.2)]
const BLOB_ASPECT := [3.0, 1.3, 1.2]
const SPACING := 0.42
const JITTER := 0.09
const GOLDEN_ANGLE := 2.39996323
## The open ground a flag can be put on; the boss's body starts at BOSS_FRONT.
const FIELD_MIN := Vector2(-3.6, -3.4)
const FIELD_MAX := Vector2(2.1, 3.4)
const BOSS_POS := Vector2(3.7, 0.0)
const BOSS_FRONT := 2.4
## Melee whose feet are within this of the boss's front can hit him.
const MELEE_REACH := 2.1
const HEAL_RANGE := 3.4
const WALK_SPEED := 3.5
## Each hero walks at WALK_SPEED times a factor in this range, so a moving squad strings out.
const WALK_SPREAD := Vector2(0.8, 1.15)

const DURATION := 150.0
const MUSTER_TIME := 6.0
const BOSS_HP := 57000.0
const PHASE2_AT := 0.5
const MORALE_MAX := 100.0
const MORALE_PER_DAMAGE := 0.01
const VOLLEY_SECONDS := 8.0

## 普通攻擊: no warning; the hero nearest the boss and whoever stands within AUTO_SPLASH of them, shields first.
## More crowded, more heroes hit.
const AUTO_EVERY := [1.6, 1.2]
const AUTO_DAMAGE := 150.0
const AUTO_TARGETS := 2
const AUTO_EXTRA_PER := 8
const AUTO_SPLASH := 1.3
## 預警攻擊: shapes are marked TELE_WARN seconds before the hit; whoever still stands inside takes TELE_DAMAGE.
const TELE_FIRST := 8.0
const TELE_EVERY := [9.0, 6.5]
const TELE_WARN := 2.0
const TELE_DAMAGE := 140.0
const TELE_CYCLE := [[Attack.SLAM, Attack.ROCKS, Attack.SWEEP], [Attack.SWEEP, Attack.SLAM, Attack.ROCKS]]
const ATTACK_NAMES := ["重砸", "橫掃", "落石"]
## 重砸: a circle on the biggest squad. 橫掃: the band SWEEP_REACH deep in front of the boss. 落石: a circle on the
## 遠程 and on the 輔助 squad.
const SLAM_RADIUS := 2.0
const SLAM_RADIUS_NO_ARM := 1.3
const SWEEP_REACH := 2.5
const ROCK_RADIUS := 1.5
## Death causes for the push report: 普通攻擊, then the telegraphed attacks in Attack order.
const CAUSE_AUTO := 0
const CAUSE_SLAM := 1
const CAUSE_NAMES := ["普通攻擊", "重砸", "橫掃", "落石"]

const PART_NAMES := ["腿", "持棍手臂", "角"]
const PART_HP := [12000.0, 6000.0, 5000.0]
## Aimed ranged damage counts this much toward the boss's HP (the rest only wears the part down).
const PART_BODY_SHARE := 0.8
const STAGGER_TIME := 4.0
const STAGGER_MULT := 1.5
const WOUND_PER_PART := 0.12
## After a 重砸 lands the club lies on the ground this long; melee hit the arm instead of the legs.
const ARM_DOWN := 2.0
## Broken legs: attacks come this much slower, warnings this much longer.
const LEGS_SLOW := 1.3
const LEGS_WARN := 0.4

const HEAL := 20.0
const HEAL_EVERY := 1.5
## 主動技能 cast themselves: damage dealers as soon as they are ready; shields when their squad is about to be hit;
## healers when someone in reach is low (an SSR healer also when a hero in reach has fallen).
const SKILL_CD := 12.0
const GUARD_TIME := 5.0
const GUARD_MULT := 0.5
const SKILL_BURST := [0.0, 6.0, 5.0, 5.0, 8.0, 0.0]
const SKILL_HEAL := 50.0
const REVIVE_HP := 0.4
const LOW_HP := 0.6
## 光環 (SSR, own squad): shield damage taken, sword melee attack, spear everyone's attack, bow ranged attack, mage
## skill cooldown; the healer's regen per second reaches everyone within HEAL_RANGE of it.
const AURA_SHIELD := 0.8
const AURA_SWORD := 1.25
const AURA_SPEAR := 1.15
const AURA_BOW := 1.3
const AURA_MAGE := 0.7
const AURA_HEALER := 2.0

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
var squad := PackedInt32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var atk := PackedFloat32Array()
var pos := PackedVector2Array()
var goal := PackedVector2Array()
var speed := PackedFloat32Array()
var skill_cd := PackedFloat32Array()
## Fight time of the last skill cast, for the view's cast pose (-1 = never).
var cast_at := PackedFloat32Array()

## Each squad's flag (where it gathers), where it mustered (全員歸位 goes back there) and guard time left.
var flag := PackedVector2Array()
var home := PackedVector2Array()
var guard_t := PackedFloat32Array()

## The telegraphed attack in flight: kind, shapes and seconds until it lands (0 = none). A shape is
## {"kind": &"circle", "c": Vector2, "r": float} or {"kind": &"band", "x": float} (everything with x >= x).
var tele_t: float = 0.0
var tele_kind: int = Attack.SLAM
var tele_shapes: Array = []
## The hero the last auto attack aimed at (-1 = none), for the view.
var auto_target: int = -1
## Heroes the last telegraphed attack hit (fallen or not).
var tele_hit_count: int = 0

var part_hp := PackedFloat32Array()
## The part the ranged squad shoots at (-1 = the body).
var aim: int = -1
var arm_down_t: float = 0.0
## Seconds left of the knockdown after a part broke.
var stagger_t: float = 0.0

var _next_tele: float = TELE_FIRST
var _tele_index: int = 0
var _auto_t: float = 1.0
var _heal_t: float = 0.0
var _rng := RandomNumberGenerator.new()
## Per-squad aura multipliers and per-hero regen, rebuilt every step.
var _aura := []
var _regen := PackedFloat32Array()

## Push report counters (push_report.gd reads them). Bookkeeping only: nothing in the fight reads them back.
var stat_dealt := PackedFloat32Array()
var stat_taken := PackedFloat32Array()
var stat_healed := PackedFloat32Array()
## Saves: an SSR healer's revive, or a shield's guard that took the edge off a hit on its squad.
var stat_saves := PackedInt32Array()
## What felled a hero: CAUSE_* (-1 = standing), their squad and when.
var death_cause := PackedInt32Array()
var death_squad := PackedInt32Array()
var death_t := PackedFloat32Array()
## The attack now hurting heroes (CAUSE_AUTO, or CAUSE_SLAM + Attack); _hurt() books deaths to it.
var _cause: int = CAUSE_AUTO


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	for c: int in ROSTER.size():
		for r: int in 4:
			for n: int in RARITY_COUNTS[c][r]:
				var mult: float = RARITY_MULT[r] * (PASSIVE_MULT if r >= R else 1.0)
				cls.append(c)
				rarity.append(r)
				squad.append(CLASS_SQUAD[c])
				max_hp.append(HP[c] * RARITY_MULT[r] * (PASSIVE_MULT if r >= R and c == SHIELD else 1.0))
				atk.append(ATK[c] * (mult if c != SHIELD else RARITY_MULT[r]))
	var n: int = cls.size()
	hp = max_hp.duplicate()
	skill_cd.resize(n)
	speed.resize(n)
	for i: int in n:
		# Staggered so the first casts do not all land on the same frame.
		skill_cd[i] = _rng.randf() * SKILL_CD * 0.5
		speed[i] = WALK_SPEED * _rng.randf_range(WALK_SPREAD.x, WALK_SPREAD.y)
	cast_at.resize(n)
	cast_at.fill(-1.0)
	stat_dealt.resize(n)
	stat_taken.resize(n)
	stat_healed.resize(n)
	stat_saves.resize(n)
	death_cause.resize(n)
	death_squad.resize(n)
	death_t.resize(n)
	death_cause.fill(-1)
	death_squad.fill(-1)
	_regen.resize(n)
	pos.resize(n)
	goal.resize(n)
	guard_t.resize(SQUADS)
	for s: int in SQUADS:
		flag.append(HOME[s])
		home.append(HOME[s])
		_form(s)
		_aura.append(_aura_of(s))
	part_hp = PackedFloat32Array(PART_HP)
	for i: int in n:
		# Muster: everyone starts off-screen left, inner classes first.
		pos[i] = Vector2(-11.0 - cls[i] * 0.8 - _rng.randf() * 2.5, goal[i].y)


func alive(i: int) -> bool:
	return hp[i] > 0.0


func moving(i: int) -> bool:
	return pos[i].distance_squared_to(goal[i]) > 0.0025


func squad_living(s: int) -> int:
	var n: int = 0
	for i: int in cls.size():
		if squad[i] == s and hp[i] > 0.0:
			n += 1
	return n


## Mean position of a squad's living heroes (its flag when nobody is left).
func squad_center(s: int) -> Vector2:
	var sum := Vector2.ZERO
	var n: int = 0
	for i: int in cls.size():
		if squad[i] == s and hp[i] > 0.0:
			sum += pos[i]
			n += 1
	return sum / n if n > 0 else flag[s]


func living() -> int:
	var n: int = 0
	for i: int in cls.size():
		if hp[i] > 0.0:
			n += 1
	return n


func broken(p: int) -> bool:
	return part_hp[p] <= 0.0


## Damage multiplier from broken parts.
func wound() -> float:
	var n: int = 0
	for p: int in part_hp.size():
		if part_hp[p] <= 0.0:
			n += 1
	return 1.0 + WOUND_PER_PART * n


## Whether ground point p lies inside the telegraph now up.
func in_tele(p: Vector2) -> bool:
	if tele_t <= 0.0:
		return false
	for shape: Dictionary in tele_shapes:
		if _inside(shape, p):
			return true
	return false


## Where a telegraph shape sits on the ground: a circle's centre, the band's middle (in front of the boss).
static func shape_center(shape: Dictionary) -> Vector2:
	if shape.kind == &"band":
		return Vector2((shape.x + BOSS_FRONT) * 0.5, 0.0)
	return shape.c


## True while a telegraphed attack is up and someone still stands in it.
func tele_threatens() -> bool:
	if tele_t <= 0.0:
		return false
	for i: int in cls.size():
		if hp[i] > 0.0 and in_tele(pos[i]):
			return true
	return false


## Living heroes of squad s standing in the telegraph now up.
func squad_threatened(s: int) -> int:
	var n: int = 0
	for i: int in cls.size():
		if squad[i] == s and hp[i] > 0.0 and in_tele(pos[i]):
			n += 1
	return n


## Whether a hero standing at p reaches the boss in melee.
func in_reach(p: Vector2) -> bool:
	return p.x >= BOSS_FRONT - MELEE_REACH


func time_left() -> float:
	return maxf(DURATION - t, 0.0)


func hp_ratio() -> float:
	return boss_hp / BOSS_HP


func fighting() -> bool:
	return phase == Phase.FIGHT


## Radii of squad s's blob on the ground (x deep, z wide) for its living heroes.
func block_half(s: int) -> Vector2:
	var n: int = maxi(squad_living(s), 1)
	var a: float = sqrt(n * SPACING * SPACING / (PI * BLOB_ASPECT[s]))
	return Vector2(a, a * BLOB_ASPECT[s])


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


## Moves squad s's muster point (the view's flags are the source of truth); call before the fight starts.
func set_home(s: int, p: Vector2) -> void:
	home[s] = p.clamp(FIELD_MIN, FIELD_MAX)
	flag[s] = home[s]
	_form(s)


## Plants squad s's flag at p (kept on the open field); its heroes walk there and pack into a block.
func move_flag(s: int, p: Vector2) -> bool:
	if not fighting() or s < 0 or s >= SQUADS or squad_living(s) == 0:
		return false
	flag[s] = p.clamp(FIELD_MIN, FIELD_MAX)
	_form(s)
	event.emit(&"move", float(s))
	return true


## 全員歸位: every squad walks back to where it mustered.
func regroup() -> bool:
	if not fighting():
		return false
	var changed: int = 0
	for s: int in SQUADS:
		if flag[s] != home[s] and squad_living(s) > 0:
			flag[s] = home[s]
			_form(s)
			changed += 1
	if changed == 0:
		return false
	event.emit(&"regroup", float(changed))
	return true


## The ranged squad shoots at part p (-1 = the body). False if the part is already broken.
func aim_at(p: int) -> bool:
	if not fighting() or (p >= 0 and broken(p)) or p == aim:
		return false
	aim = p
	event.emit(&"aim", float(p))
	return true


func volley() -> bool:
	if not fighting() or morale < MORALE_MAX:
		return false
	morale = 0.0
	var amount: float = 0.0
	for i: int in cls.size():
		if hp[i] > 0.0:
			amount += atk[i]
			stat_dealt[i] += atk[i] * VOLLEY_SECONDS * wound()
	amount *= VOLLEY_SECONDS * wound()
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
	arm_down_t = maxf(arm_down_t - dt, 0.0)
	for s: int in SQUADS:
		guard_t[s] = maxf(guard_t[s] - dt, 0.0)
		_aura[s] = _aura_of(s)
	_regen_of()
	for i: int in cls.size():
		skill_cd[i] = maxf(skill_cd[i] - dt, 0.0)
	_walk(dt)
	if not phase2 and hp_ratio() <= PHASE2_AT:
		phase2 = true
		event.emit(&"phase2", 0.0)
	var p: int = 1 if phase2 else 0
	var slow: float = LEGS_SLOW if broken(Part.LEGS) else 1.0

	if stagger_t > 0.0:
		# Knocked down: his attack clocks stand still.
		stagger_t = maxf(stagger_t - dt, 0.0)
		_next_tele += dt
	else:
		_auto_t -= dt
		if _auto_t <= 0.0:
			_auto_t += AUTO_EVERY[p] * slow
			_auto_attack()

	if stagger_t > 0.0:
		pass
	elif tele_t > 0.0:
		tele_t -= dt
		if tele_t <= 0.0:
			tele_t = 0.0
			_land()
	else:
		var warn: float = TELE_WARN + (LEGS_WARN if broken(Part.LEGS) else 0.0)
		if t >= _next_tele - warn:
			_telegraph(TELE_CYCLE[p][_tele_index % 3], maxf(_next_tele - t, dt))
			_tele_index += 1
			_next_tele += TELE_EVERY[p] * slow

	_heal_t -= dt
	if _heal_t <= 0.0:
		_heal_t += HEAL_EVERY
		_healers()
	for i: int in cls.size():
		if hp[i] > 0.0 and hp[i] < max_hp[i] and _regen[i] > 0.0:
			hp[i] = minf(hp[i] + _regen[i] * dt, max_hp[i])

	_auto_skills()
	var melee_sum: float = 0.0
	var ranged_sum: float = 0.0
	var mult: float = (STAGGER_MULT if stagger_t > 0.0 else 1.0) * wound()
	var aimed: bool = aim >= 0
	for i: int in cls.size():
		if hp[i] <= 0.0 or moving(i) or cls[i] == HEALER:
			continue
		var a: Dictionary = _aura[squad[i]]
		var d: float = atk[i] * a.all * mult
		if cls[i] <= SPEAR:
			if not in_reach(pos[i]):
				continue
			d *= a.melee
			melee_sum += d
			stat_dealt[i] += d * dt
		else:
			d *= a.ranged
			ranged_sum += d
			stat_dealt[i] += d * dt * (PART_BODY_SHARE if aimed else 1.0)
	# Melee wear down the legs (the arm while the club is down); aimed ranged shots wear down their part.
	var melee_part: int = Part.ARM if arm_down_t > 0.0 and not broken(Part.ARM) else Part.LEGS
	_wear(melee_part, melee_sum * dt)
	if aimed:
		_wear(aim, ranged_sum * dt)
		ranged_sum *= PART_BODY_SHARE
	dps = melee_sum + ranged_sum
	_deal(dps * dt, true)
	if phase == Phase.FIGHT and (t >= DURATION or living() == 0):
		phase = Phase.LOST
		event.emit(&"lost", hp_ratio())


func _wear(p: int, amount: float) -> void:
	if amount <= 0.0 or broken(p):
		return
	part_hp[p] = maxf(part_hp[p] - amount, 0.0)
	if part_hp[p] > 0.0:
		return
	if aim == p:
		aim = -1
	stagger_t = STAGGER_TIME
	if tele_t > 0.0:
		tele_t = 0.0
		tele_shapes = []
		event.emit(&"tele_cancel", 0.0)
	event.emit(&"part_break", float(p))


func _walk(dt: float) -> void:
	for i: int in cls.size():
		if hp[i] > 0.0:
			pos[i] = pos[i].move_toward(goal[i], speed[i] * dt)


## Settles squad s's living heroes into a blob around its flag: a sunflower spiral squashed into the squad's ellipse,
## each spot nudged by a fixed per-hero amount; the spots nearest the boss go to the shields, then by class.
func _form(s: int) -> void:
	var members: Array[int] = []
	for i: int in cls.size():
		if squad[i] == s and hp[i] > 0.0:
			members.append(i)
	if members.is_empty():
		return
	members.sort_custom(func(a: int, b: int) -> bool: return cls[a] < cls[b] or (cls[a] == cls[b] and a < b))
	var n: int = members.size()
	var radii: Vector2 = block_half(s)
	var spots: Array[Vector2] = []
	for k: int in n:
		var r: float = sqrt((k + 0.5) / n)
		var angle: float = k * GOLDEN_ANGLE
		spots.append(Vector2(cos(angle), sin(angle)) * r * radii)
	spots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x > b.x)
	for k: int in n:
		var i: int = members[k]
		var nudge := Vector2(_hash(i, 1) - 0.5, _hash(i, 2) - 0.5) * 2.0 * JITTER
		goal[i] = flag[s] + spots[k] + nudge


## A fixed number in 0..1 per hero and salt, so a squad's shape never depends on the random stream.
static func _hash(i: int, salt: int) -> float:
	return float((i * 7919 + salt * 104729) % 1009) / 1009.0


func _aura_of(s: int) -> Dictionary:
	var a := {"taken": 1.0, "melee": 1.0, "all": 1.0, "ranged": 1.0, "cd": 1.0}
	for i: int in cls.size():
		if squad[i] != s or hp[i] <= 0.0 or rarity[i] != SSR:
			continue
		match cls[i]:
			SHIELD: a.taken = AURA_SHIELD
			SWORD: a.melee = AURA_SWORD
			SPEAR: a.all = AURA_SPEAR
			BOW: a.ranged = AURA_BOW
			MAGE: a.cd = AURA_MAGE
	return a


## The SSR healer's regen reaches everyone within HEAL_RANGE of it.
func _regen_of() -> void:
	_regen.fill(0.0)
	for h: int in cls.size():
		if cls[h] != HEALER or rarity[h] != SSR or hp[h] <= 0.0:
			continue
		for j: int in cls.size():
			if hp[j] > 0.0 and pos[j].distance_to(pos[h]) <= HEAL_RANGE:
				_regen[j] = AURA_HEALER


## Casts every ready 主動技能 whose moment has come (see SKILL_CD). Called each fight step.
func _auto_skills() -> void:
	var burst: float = 0.0
	for i: int in cls.size():
		if hp[i] <= 0.0 or rarity[i] < SR or skill_cd[i] > 0.0 or moving(i):
			continue
		var s: int = squad[i]
		match cls[i]:
			SHIELD:
				var aimed_here: bool = auto_target >= 0 and squad[auto_target] == s
				if not ((tele_t > 0.0 and tele_t < 1.0 and squad_threatened(s) > 0) or aimed_here):
					continue
				guard_t[s] = GUARD_TIME
				stat_saves[i] += 1
			HEALER:
				var fallen: int = _fallen_near(pos[i]) if rarity[i] == SSR else -1
				if _lowest_near(pos[i]) >= LOW_HP and fallen < 0:
					continue
				stat_healed[i] += _heal_around(pos[i], SKILL_HEAL * RARITY_MULT[rarity[i]])
				if fallen >= 0:
					_revive(fallen)
					stat_saves[i] += 1
			_:
				if cls[i] <= SPEAR and not in_reach(pos[i]):
					continue
				var b: float = atk[i] * SKILL_BURST[cls[i]] * _aura[s].all * wound()
				stat_dealt[i] += b
				burst += b
		skill_cd[i] = SKILL_CD * _aura[s].cd
		cast_at[i] = t
		event.emit(&"skill", float(i))
	if burst > 0.0:
		_deal(burst, true)


## The hero nearest the boss, and whoever stands within AUTO_SPLASH of them: shields first, then the healthiest.
func _auto_attack() -> void:
	var target: int = -1
	for i: int in cls.size():
		if hp[i] > 0.0 and (target < 0 or pos[i].x > pos[target].x):
			target = i
	auto_target = target
	if target < 0:
		return
	var victims: Array[int] = []
	for i: int in cls.size():
		if hp[i] > 0.0 and pos[i].distance_to(pos[target]) <= AUTO_SPLASH:
			victims.append(i)
	victims.sort_custom(func(a: int, b: int) -> bool:
		if (cls[a] == SHIELD) != (cls[b] == SHIELD):
			return cls[a] == SHIELD
		return hp[a] > hp[b])
	var hits: int = mini(AUTO_TARGETS + victims.size() / AUTO_EXTRA_PER, victims.size())
	var fell: int = 0
	_cause = CAUSE_AUTO
	for k: int in hits:
		fell += _hurt(victims[k], AUTO_DAMAGE)
	event.emit(&"auto", float(target))
	if fell > 0:
		event.emit(&"fallen", float(fell))


func _telegraph(kind: int, warn: float) -> void:
	# A broken part's attack becomes a 重砸.
	if (kind == Attack.SWEEP and broken(Part.ARM)) or (kind == Attack.ROCKS and broken(Part.HORNS)):
		kind = Attack.SLAM
	tele_kind = kind
	tele_shapes = []
	match kind:
		Attack.SLAM:
			var best: int = MELEE
			for s: int in SQUADS:
				if squad_living(s) > squad_living(best):
					best = s
			var r: float = SLAM_RADIUS_NO_ARM if broken(Part.ARM) else SLAM_RADIUS
			tele_shapes.append({"kind": &"circle", "c": squad_center(best), "r": r})
		Attack.SWEEP:
			tele_shapes.append({"kind": &"band", "x": BOSS_FRONT - SWEEP_REACH})
		Attack.ROCKS:
			for s: int in [RANGED, SUPPORT]:
				if squad_living(s) > 0:
					tele_shapes.append({"kind": &"circle", "c": squad_center(s), "r": ROCK_RADIUS})
	tele_t = warn
	event.emit(&"tele_warn", warn)


func _land() -> void:
	var fell: int = 0
	tele_hit_count = 0
	_cause = CAUSE_SLAM + tele_kind
	for i: int in cls.size():
		if hp[i] > 0.0 and _in_shapes(pos[i]):
			tele_hit_count += 1
			fell += _hurt(i, TELE_DAMAGE)
	if tele_kind == Attack.SLAM:
		arm_down_t = ARM_DOWN
	event.emit(&"tele_hit", float(fell))
	tele_shapes = []


func _in_shapes(p: Vector2) -> bool:
	for shape: Dictionary in tele_shapes:
		if _inside(shape, p):
			return true
	return false


func _inside(shape: Dictionary, p: Vector2) -> bool:
	if shape.kind == &"band":
		return p.x >= shape.x
	return p.distance_to(shape.c) <= shape.r


## Damages a hero after squad guard and shield aura. Returns 1 if they fell.
func _hurt(i: int, amount: float) -> int:
	var s: int = squad[i]
	var d: float = amount * _aura[s].taken * (GUARD_MULT if guard_t[s] > 0.0 else 1.0)
	stat_taken[i] += minf(d, hp[i])
	hp[i] = maxf(hp[i] - d, 0.0)
	if hp[i] == 0.0:
		fallen_total += 1
		death_cause[i] = _cause
		death_squad[i] = s
		death_t[i] = t
		return 1
	return 0


## Each healer mends the most hurt hero (by HP ratio) within HEAL_RANGE.
func _healers() -> void:
	for i: int in cls.size():
		if cls[i] != HEALER or hp[i] <= 0.0:
			continue
		var amount: float = HEAL * RARITY_MULT[rarity[i]] * (PASSIVE_MULT if rarity[i] >= R else 1.0)
		var target: int = -1
		var worst: float = 1.0
		for j: int in cls.size():
			if hp[j] > 0.0 and hp[j] < max_hp[j] and hp[j] / max_hp[j] < worst \
					and pos[j].distance_squared_to(pos[i]) <= HEAL_RANGE * HEAL_RANGE:
				worst = hp[j] / max_hp[j]
				target = j
		if target >= 0:
			stat_healed[i] += minf(amount, max_hp[target] - hp[target])
			hp[target] = minf(hp[target] + amount, max_hp[target])


## Heals everyone within HEAL_RANGE of p; returns how much HP it actually restored.
func _heal_around(p: Vector2, amount: float) -> float:
	var total: float = 0.0
	for j: int in cls.size():
		if hp[j] > 0.0 and pos[j].distance_squared_to(p) <= HEAL_RANGE * HEAL_RANGE:
			total += minf(amount, max_hp[j] - hp[j])
			hp[j] = minf(hp[j] + amount, max_hp[j])
	return total


func _revive(j: int) -> void:
	hp[j] = max_hp[j] * REVIVE_HP
	death_cause[j] = -1
	fallen_total -= 1
	_form(squad[j])
	event.emit(&"revive", float(j))


## A fallen hero lying within HEAL_RANGE of p (-1 if none).
func _fallen_near(p: Vector2) -> int:
	for j: int in cls.size():
		if hp[j] <= 0.0 and pos[j].distance_squared_to(p) <= HEAL_RANGE * HEAL_RANGE:
			return j
	return -1


## Lowest HP ratio among the living within HEAL_RANGE of p.
func _lowest_near(p: Vector2) -> float:
	var low: float = 1.0
	for j: int in cls.size():
		if hp[j] > 0.0 and pos[j].distance_squared_to(p) <= HEAL_RANGE * HEAL_RANGE:
			low = minf(low, hp[j] / max_hp[j])
	return low


func _deal(amount: float, earns_morale: bool) -> void:
	boss_hp = maxf(boss_hp - amount, 0.0)
	damage_dealt += amount
	if earns_morale:
		morale = minf(morale + amount * MORALE_PER_DAMAGE, MORALE_MAX)
	if boss_hp == 0.0 and phase == Phase.FIGHT:
		phase = Phase.WON
		event.emit(&"won", time_left())
