extends RefCounted
## The field battle: fixed-step, seeded, independent of rendering. Scenes push commands with
## command() and read state plus drain_events(); they never change units directly.
##
## One step (implementation-plan §5): apply queued commands → respawns → decisions and movement
## for every living unit in id order, which only *roll* their hits → apply every hit of the step
## from the same snapshot → deaths (a fallen leader ends the run before any reward or level-up)
## → rewards → sustain (regen, HOT, potions) for the survivors. Simultaneous blows all land.

const Tuning = preload("res://domain/tuning.gd")
const Unit = preload("res://domain/unit.gd")
const Run = preload("res://domain/run.gd")
const Skills = preload("res://domain/skills.gd")

enum Walk { ARRIVED, MOVING, STUCK }

var tuning: Tuning
var rng := RandomNumberGenerator.new()
var now_ms: float = 0.0
var dt_ms: float
var units: Array[Unit] = []
var obstacles: Array[Dictionary] = []  # {pos: Vector2, radius: float}
var bounds: Rect2
var leader: Unit
var guardian: Unit
var support: Unit

var auto_hunt: bool = false
var auto_potion: bool = true
## Growth, carried items and quests live on the Run; these read through to it.
var run: Run
var level: int:
	get: return run.level
var experience: float:
	get: return run.experience
var gold: int:
	get: return run.gold
var kills: int:
	get: return run.kills
var inventory: Dictionary:
	get: return run.stacks
## The quest the HUD tracks (tuning field.slice_quest_id).
var tracked_quest: String
var ended: bool = false
## Camp: a safe circle {pos, radius}. Monsters never enter it or attack anyone inside.
var camp: Dictionary = {}
var auto_retreat: bool = true
## Sim time when the party's retreat completes; < 0 when none is running.
var retreat_at_ms: float = -1.0
var _was_in_camp: bool = true

var _events: Array[Dictionary] = []
var _next_event_id: int = 1
var _commands: Array[Dictionary] = []
var _pending_hits: Array[Dictionary] = []
var _step_hits: Array[Dictionary] = []
var _next_cast_id: int = 1
var _mastered_casts: Dictionary = {}
var _search_at_ms: float = 0.0
var _by_id: Dictionary = {}
var _field: Dictionary
var _combat: Dictionary


## setup = {seed, bounds: Rect2, obstacles: [{pos, radius}], party_spawn: Vector2,
## monsters: [{id: String, pos: Vector2}], run: Run (optional: a fresh one), camp: {pos, radius} (optional)}.
## Positions are ground cells (x, z).
func _init(tuning_: Tuning, setup: Dictionary) -> void:
	tuning = tuning_
	_field = tuning.section("field")
	_combat = tuning.section("combat")
	dt_ms = float(tuning.step_ms())
	rng.seed = int(setup.get("seed", 1))
	run = setup.get("run") if setup.get("run") != null else Run.new(tuning, "run-1")
	bounds = setup.bounds
	camp = setup.get("camp", {})
	for obstacle: Dictionary in setup.obstacles:
		obstacles.append({"pos": obstacle.pos, "radius": float(obstacle.radius)})
	var names := {"leader": "隊長", "guardian": "盾衛", "support": "援護"}
	var slots: Array = _field.follow_slots_cells
	leader = _add_member("leader", names.leader, setup.party_spawn)
	guardian = _add_member("guardian", names.guardian, setup.party_spawn + Vector2(slots[0][0], slots[0][1]))
	support = _add_member("support", names.support, setup.party_spawn + Vector2(slots[1][0], slots[1][1]))
	for spec: Dictionary in setup.monsters:
		_add_monster(spec.id, spec.pos)
	tracked_quest = _field.slice_quest_id


# --- Public API -------------------------------------------------------------

## {type: move, pos} | {type: attack, target} | {type: steer, vec} | {type: auto, on}
## | {type: auto_potion, on} | {type: skill} | {type: tonic} | {type: emergency} | {type: claim}
func command(cmd: Dictionary) -> void:
	_commands.append(cmd)


func drain_events() -> Array[Dictionary]:
	var out := _events
	_events = []
	return out


func unit(id: int) -> Unit:
	return _by_id.get(id)


func party() -> Array[Unit]:
	return [leader, guardian, support]


func monsters() -> Array[Unit]:
	var out: Array[Unit] = []
	for u: Unit in units:
		if u.team == 1:
			out.append(u)
	return out


func xp_needed() -> int:
	return run.xp_needed()


func quest_ready() -> bool:
	return run.quest_ready(tracked_quest, now_ms)


## The leader's skill in slot `index` (0-based), or "".
func slot_skill(index: int) -> String:
	var slots: Array = run.slots.get("leader", [])
	return String(slots[index]) if index < slots.size() else ""


func skill_ready_in_ms(index: int = 0) -> float:
	var id := slot_skill(index)
	return maxf(0.0, float(leader.cooldowns.get(id, 0.0)) - now_ms) if id != "" else 0.0


func skill_cooldown_ms(u: Unit, id: String) -> float:
	return float(tuning.skills[id].cooldown_ms) * Skills.cooldown_ratio(Skills.mastery_level(run, u.role, id))


func step() -> void:
	if ended:
		return
	for cmd: Dictionary in _commands:
		_apply(cmd)
	_commands.clear()
	now_ms += dt_ms
	for u: Unit in units:
		u.moving = false
		if u.team == 1 and not u.alive and u.respawn_at_ms >= 0.0 and now_ms >= u.respawn_at_ms:
			_respawn(u)
	_resolve_pending_hits()
	for u: Unit in units:
		if not u.alive:
			continue
		match u.role:
			"leader": _think_leader(u)
			"guardian": _think_guardian(u)
			"support": _think_support(u)
			_: _think_monster(u)
	_land_hits()
	if not ended:
		_sustain()
		_check_retreat()
	_separate()


func in_camp(u: Unit) -> bool:
	return not camp.is_empty() and u.pos.distance_to(camp.pos) <= float(camp.radius)


func retreating() -> bool:
	return retreat_at_ms >= 0.0


# --- Camp and retreat ---------------------------------------------------------

## A whole-party order: completes retreat_ms later (it does not stop incoming blows meanwhile).
func _start_retreat(reason: String) -> void:
	if retreating() or camp.is_empty() or in_camp(leader):
		if reason == "manual":
			_emit({"type": "refused", "what": "retreat", "reason": "already" if retreating() else "in_camp"})
		return
	retreat_at_ms = now_ms + float(tuning.section("simulation").retreat_ms)
	_emit({"type": "retreat_started", "reason": reason, "at": retreat_at_ms})


func _check_retreat() -> void:
	if not retreating() and auto_retreat and not in_camp(leader) \
			and leader.hp_ratio() < float(tuning.section("automation").retreat_threshold):
		_start_retreat("auto")
	if retreating() and now_ms >= retreat_at_ms:
		retreat_at_ms = -1.0
		var slots: Array = _field.follow_slots_cells
		var offsets := [Vector2.ZERO, Vector2(slots[0][0], slots[0][1]) * 0.6, Vector2(slots[1][0], slots[1][1]) * 0.6]
		var members := party()
		for i in members.size():
			var m: Unit = members[i]
			m.pos = camp.pos + offsets[i]
			m.order = Unit.Order.NONE
			m.target_id = -1
			m.steer = Vector2.ZERO
			_reset_stuck(m)
		for mon: Unit in monsters():
			if mon.target_id >= 0 and unit(mon.target_id).team == 0:
				mon.target_id = -1
		auto_hunt = false
		_emit({"type": "retreated"})
	var inside := in_camp(leader)
	if inside and not _was_in_camp:
		_emit({"type": "returned", "trip": run.trip.duplicate(true)})
		run.reset_trip()
	_was_in_camp = inside


# --- Setup ------------------------------------------------------------------

func _add_member(role: String, display_name: String, at: Vector2) -> Unit:
	var u := Unit.new()
	u.id = units.size()
	u.team = 0
	u.role = role
	u.kind_id = role
	u.display_name = display_name
	u.pos = _clamp_to_bounds(at)
	u.spawn = u.pos
	u.range_cells = float(_combat.melee_range_cells)
	u.speed = float(_field.party_move_cells_per_s)
	_apply_member_stats(u)
	u.hp = u.max_hp
	_register(u)
	return u


func _apply_member_stats(u: Unit) -> void:
	var stats: Dictionary = run.member_stats(u.role)
	u.level = run.level
	u.max_hp = stats.max_hp
	u.attack = stats.attack
	u.defense = stats.defense
	u.agility = stats.agility
	u.crit_chance = stats.crit_chance
	u.block_chance = stats.block_chance
	u.attack_ms = stats.attack_ms


func _add_monster(monster_id: String, at: Vector2) -> Unit:
	var def: Dictionary = tuning.monsters[monster_id] if tuning.monsters.has(monster_id) else tuning.bosses[monster_id]
	var u := Unit.new()
	u.id = units.size()
	u.team = 1
	u.role = "monster"
	u.kind_id = monster_id
	u.display_name = String(def.get("name", monster_id))
	u.level = int(def.level)
	u.pos = _clamp_to_bounds(at)
	u.spawn = u.pos
	u.max_hp = float(def.hp)
	u.hp = u.max_hp
	u.attack = float(def.attack)
	u.defense = float(def.defense)
	u.crit_chance = float(_combat.crit_chance)
	u.is_boss = tuning.bosses.has(monster_id)
	u.attack_ms = float(def.get("attack_interval_ms", def.get("normal_interval_ms", 2000)))
	u.range_cells = float(_combat.melee_range_cells)
	u.speed = float(def.get("move_cells_per_s", _field.monster_move_cells_per_s.get(monster_id, 2.4)))
	u.base_exp = float(def.base_exp)
	u.gold = int(def.gold)
	u.facing = Vector2(-1, 1).normalized()
	_register(u)
	return u


func _register(u: Unit) -> void:
	units.append(u)
	_by_id[u.id] = u


# --- Commands ---------------------------------------------------------------

func _apply(cmd: Dictionary) -> void:
	match cmd.type:
		"move":
			_cancel_chain(leader, "moved")
			leader.order = Unit.Order.MOVE
			leader.move_goal = _clamp_to_bounds(cmd.pos)
			leader.target_id = -1
			_reset_stuck(leader)
		"attack":
			var t: Unit = unit(int(cmd.target))
			if t != null and t.team == 1 and t.alive:
				leader.order = Unit.Order.ATTACK
				leader.target_id = t.id
				leader.unreachable.erase(t.id)
				_reset_stuck(leader)
				_emit({"type": "target", "unit": leader.id, "target": t.id})
		"steer":
			var vec: Vector2 = cmd.vec
			leader.steer = vec.normalized() if vec.length() > 0.01 else Vector2.ZERO
			if leader.steer != Vector2.ZERO:
				leader.order = Unit.Order.NONE
				_cancel_chain(leader, "moved")
		"auto":
			auto_hunt = bool(cmd.on)
			if auto_hunt and leader.order == Unit.Order.MOVE:
				leader.order = Unit.Order.NONE
			if not auto_hunt and leader.order != Unit.Order.ATTACK:
				leader.target_id = -1
			_emit({"type": "auto", "on": auto_hunt})
		"auto_potion":
			auto_potion = bool(cmd.on)
		"skill":
			_try_skill(leader, true, slot_skill(int(cmd.get("slot", 0))))
		"tonic":
			_use_tonic(leader, true)
		"emergency":
			_use_emergency(leader, true)
		"claim":
			if not in_camp(leader):
				_emit({"type": "refused", "what": "claim", "reason": "not_in_camp"})
			else:
				_claim_quest(String(cmd.get("quest", tracked_quest)))
		"retreat":
			_start_retreat("manual")


# --- Leader ------------------------------------------------------------------

func _think_leader(u: Unit) -> void:
	if auto_hunt and u.steer == Vector2.ZERO and u.order != Unit.Order.MOVE and _dodge(u):
		_cancel_chain(u, "dodge")
		return
	if not u.chain_next.is_empty() and now_ms >= float(u.chain_next.at):
		_continue_chain(u)
	if u.steer != Vector2.ZERO:
		_displace(u, u.steer * u.speed * dt_ms / 1000.0, u.pos + u.steer * 10.0)
		return
	if u.order == Unit.Order.MOVE:
		match _walk(u, u.move_goal, 0.05):
			Walk.ARRIVED:
				u.order = Unit.Order.NONE
				_emit({"type": "arrived", "unit": u.id})
			Walk.STUCK:
				u.order = Unit.Order.NONE
				_emit({"type": "blocked", "unit": u.id})
		return
	var target: Unit = _valid_target(u)
	if target == null:
		u.target_id = -1
		if u.order == Unit.Order.ATTACK:
			u.order = Unit.Order.NONE
	if auto_hunt and now_ms >= _search_at_ms:
		_search_at_ms = now_ms + float(tuning.section("simulation").search_ms)
		var pick := _auto_pick(u, target)
		if pick != null and pick != target:
			target = pick
			u.target_id = pick.id
			_emit({"type": "target", "unit": u.id, "target": pick.id})
	if target == null:
		return
	if auto_hunt:
		_auto_skill(u)
	_engage(u, target)


func _auto_pick(u: Unit, current: Unit) -> Unit:
	# A monster hitting the leader right now outranks a farther chosen target.
	var attacker: Unit = unit(u.last_attacker)
	if attacker != null and attacker.alive and attacker.team == 1 and now_ms - u.last_hit_ms < 1500.0:
		if current == null or (current.target_id != u.id and
				u.pos.distance_to(attacker.pos) < u.pos.distance_to(current.pos)):
			return attacker
	if current != null:
		return current
	var best: Unit = null
	var best_d := INF
	for m: Unit in units:
		if m.team != 1 or not m.alive or m.returning:
			continue
		if now_ms < float(u.unreachable.get(m.id, -1.0)):
			continue
		var d := u.pos.distance_to(m.pos)
		if d < best_d:
			best_d = d
			best = m
	return best


func _valid_target(u: Unit) -> Unit:
	var t: Unit = unit(u.target_id)
	if t == null or not t.alive or t.team == u.team:
		return null
	return t


# --- Companions ---------------------------------------------------------------

func _think_guardian(u: Unit) -> void:
	if _dodge(u):
		return
	if _too_far_from_leader(u):
		_follow(u)
		return
	# Taunt when a monster locks onto anyone the guardian protects: the leader or the support.
	var threat := _monster_targeting(leader)
	if threat == null and support.alive:
		threat = _monster_targeting(support)
	if threat != null and u.is_ready("taunt", now_ms):
		_taunt(u)
	var target := _companion_target(u)
	if target == null:
		_follow(u)
	else:
		_engage(u, target)


func _think_support(u: Unit) -> void:
	if _dodge(u):
		return
	if _too_far_from_leader(u):
		_follow(u)
		return
	var bandage: Dictionary = tuning.utilities["bandage_ally"]
	if u.is_ready("bandage_ally", now_ms) and run.count("bandage") > 0 and now_ms >= u.busy_until_ms:
		var patient: Unit = null
		for m: Unit in party():
			if m.alive and m.hp_ratio() < float(bandage.trigger_hp_ratio):
				if patient == null or m.hp_ratio() < patient.hp_ratio():
					patient = m
		if patient != null:
			if u.pos.distance_to(patient.pos) <= float(_field.heal_range_cells):
				_bandage(u, patient, bandage)
			else:
				_walk(u, patient.pos, float(_field.heal_range_cells) * 0.8)
			return
	var target := _companion_target(u)
	if target == null:
		_follow(u)
	else:
		_engage(u, target)


func _companion_target(u: Unit) -> Unit:
	# Protect the leader first, then join the leader's fight, then defend the party.
	# Targets this companion just failed to reach are skipped until unreachable_retry_ms passes.
	var engage := float(_field.companion_engage_radius_cells)
	var threat := _monster_targeting(leader)
	if threat != null and _reachable(u, threat):
		return threat
	var leader_target := _valid_target(leader)
	if leader_target != null and leader_target.pos.distance_to(leader.pos) <= engage and _reachable(u, leader_target):
		return leader_target
	var best: Unit = null
	var best_d := INF
	for m: Unit in units:
		if m.team != 1 or not m.alive or m.target_id < 0 or not _reachable(u, m):
			continue
		var d := m.pos.distance_to(leader.pos)
		if d <= engage and d < best_d:
			best_d = d
			best = m
	return best


func _reachable(u: Unit, m: Unit) -> bool:
	return now_ms >= float(u.unreachable.get(m.id, -1.0))


func _monster_targeting(victim: Unit) -> Unit:
	var best: Unit = null
	var best_d := INF
	for m: Unit in units:
		if m.team == 1 and m.alive and m.target_id == victim.id:
			var d := m.pos.distance_to(victim.pos)
			if d < best_d:
				best_d = d
				best = m
	return best


func _too_far_from_leader(u: Unit) -> bool:
	return u.pos.distance_to(leader.pos) > float(_field.companion_leash_cells)


func _follow(u: Unit) -> void:
	var slots: Array = _field.follow_slots_cells
	var slot: Array = slots[0] if u.role == "guardian" else slots[1]
	var goal := _clamp_to_bounds(leader.pos + Vector2(slot[0], slot[1]))
	if u.pos.distance_to(goal) > 0.6:
		_walk(u, goal, 0.3)


func _taunt(u: Unit) -> void:
	var taunt: Dictionary = tuning.utilities["taunt"]
	u.cooldowns["taunt"] = now_ms + float(taunt.cooldown_ms)
	var radius := float(_field.companion_engage_radius_cells)
	var pulled: Array[int] = []
	for m: Unit in units:
		if m.team == 1 and m.alive and m.pos.distance_to(u.pos) <= radius:
			m.taunted_by = u.id
			m.taunt_until_ms = now_ms + float(taunt.duration_ms)
			m.target_id = u.id
			m.returning = false
			pulled.append(m.id)
	u.action_ms = now_ms
	u.action = &"skill"
	_emit({"type": "taunt", "unit": u.id, "pulled": pulled})


func _bandage(u: Unit, patient: Unit, bandage: Dictionary) -> void:
	run.consume("bandage")
	u.cooldowns["bandage_ally"] = now_ms + float(bandage.cooldown_ms)
	u.busy_until_ms = now_ms + 600.0
	u.action_ms = now_ms
	u.action = &"skill"
	u.facing = _face(u.pos, patient.pos, u.facing)
	var amount := _heal(patient, patient.max_hp * float(bandage.heal_max_hp_ratio))
	run.note_heal(u.role, amount)
	_emit({"type": "heal", "unit": patient.id, "source": u.id, "amount": amount, "kind": "bandage"})


# --- Monsters -----------------------------------------------------------------

func _think_monster(u: Unit) -> void:
	if u.is_boss:
		_think_boss(u)
		return
	var leash := float(_field.leash_radius_cells)
	var current: Unit = _valid_target(u)
	if current != null and in_camp(current):
		u.target_id = -1
		u.taunted_by = -1
	if u.returning:
		if _walk(u, u.spawn, 0.1) != Walk.MOVING:
			u.returning = false
			u.hp = u.max_hp
		return
	if u.taunted_by >= 0 and now_ms >= u.taunt_until_ms:
		u.taunted_by = -1
	var target: Unit = _valid_target(u)
	if u.taunted_by >= 0 and unit(u.taunted_by).alive and not in_camp(unit(u.taunted_by)):
		target = unit(u.taunted_by)
	if target == null:
		target = _nearest_member(u.pos, float(_field.aggro_radius_cells))
	if target != null and u.spawn.distance_to(u.pos) > leash:
		target = null
		u.returning = true
		u.taunted_by = -1
		_emit({"type": "leash", "unit": u.id})
	u.target_id = target.id if target != null else -1
	if target != null:
		_engage(u, target)
	elif u.pos.distance_to(u.spawn) > 0.3:
		_walk(u, u.spawn, 0.1)


## Floor guardian: chases within its own aggro/leash, and spends its moves on telegraphed areas
## (tuning bosses[].moves): the circle is fixed when the warning starts, so stepping out dodges.
func _think_boss(u: Unit) -> void:
	var def: Dictionary = tuning.bosses[u.kind_id]
	var leash := float(def.get("leash_radius_cells", 12.0))
	if u.returning:
		if _walk(u, u.spawn, 0.1) != Walk.MOVING:
			u.returning = false
			u.hp = u.max_hp
		return
	var target: Unit = _valid_target(u)
	if target != null and in_camp(target):
		target = null
	if target == null:
		target = _nearest_member(u.pos, float(def.get("aggro_radius_cells", 6.0)))
	if target != null and u.spawn.distance_to(u.pos) > leash:
		target = null
		u.returning = true
		_emit({"type": "leash", "unit": u.id})
	u.target_id = target.id if target != null else -1
	if target == null:
		if u.pos.distance_to(u.spawn) > 0.3:
			_walk(u, u.spawn, 0.1)
		return
	if now_ms >= u.busy_until_ms and u.pos.distance_to(target.pos) <= 5.0:
		for move: Dictionary in def.moves:
			if u.is_ready(move.id, now_ms):
				_telegraph(u, move, target)
				return
	_engage(u, target)


func _telegraph(u: Unit, move: Dictionary, target: Unit) -> void:
	var warning := float(move.warning_ms)
	var center: Vector2 = u.pos if move.targets == "all" else target.pos
	u.cooldowns[move.id] = now_ms + float(move.cooldown_ms)
	u.busy_until_ms = now_ms + warning + 500.0
	u.next_attack_ms = maxf(u.next_attack_ms, u.busy_until_ms)
	u.facing = _face(u.pos, target.pos, u.facing)
	u.action_ms = now_ms
	u.action = &"skill"
	var radius := float(move.radius_cells)
	var threatened: Array[int] = []
	for m: Unit in party():
		if m.alive and not in_camp(m) and m.pos.distance_to(center) <= radius:
			threatened.append(m.id)
	_emit({"type": "telegraph", "unit": u.id, "move": move.id, "name": String(move.get("name", move.id)),
		"center": center, "radius": radius, "warning_ms": warning})
	var covered: bool = move.targets == "all" and _cover(warning)
	_pending_hits.append({"at": now_ms + warning, "src": u.id, "area": true, "center": center, "radius": radius,
		"power": float(move.power), "move": move.id, "warned_at": now_ms, "threatened": threatened,
		"covered": covered, "dodging": []})


## Guardian's cover (tuning party.utilities.cover): allies near the guardian take
## damage_taken_ratio of a charged blow that lands inside the window.
func _cover(warning_ms: float) -> bool:
	var cover: Dictionary = tuning.utilities["cover"]
	if not guardian.alive or not guardian.is_ready("cover", now_ms):
		return false
	guardian.cooldowns["cover"] = now_ms + float(cover.cooldown_ms)
	guardian.action_ms = now_ms
	guardian.action = &"skill"
	var covered: Array[int] = []
	for m: Unit in party():
		if m.alive and m.pos.distance_to(guardian.pos) <= 3.5:
			m.cover_until_ms = now_ms + warning_ms + float(cover.duration_ms) * 0.5
			m.cover_ratio = float(cover.damage_taken_ratio)
			covered.append(m.id)
	_emit({"type": "cover", "unit": guardian.id, "covered": covered})
	return true


## AI step-out (tuning automation.dodge_*): dodge_react_ms after a boss warning starts, a member still inside the
## circle walks away from the boss until it is dodge_margin_cells clear. The guardian holds for a sweep it covers.
## True while dodging; the member does nothing else that step.
func _dodge(u: Unit) -> bool:
	var auto: Dictionary = tuning.section("automation")
	if not bool(auto.get("dodge_enabled", false)) or in_camp(u) or not (auto.dodge_roles as Array).has(u.role):
		return false
	for hit: Dictionary in _pending_hits:
		if not hit.get("area", false) or now_ms < float(hit.warned_at) + float(auto.dodge_react_ms):
			continue
		if u == guardian and hit.covered:
			continue
		var clear := float(hit.radius) + float(auto.dodge_margin_cells)
		var p: Vector2 = u.pos - hit.center
		if p.length() >= clear:
			continue
		# Away from the boss: a targeted blow is centred on the victim, so "away from the centre" is undefined there.
		var away: Vector2 = u.pos - unit(hit.src).pos
		away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(u.id)
		for d: Vector2 in [away, away.rotated(PI / 2.0), away.rotated(-PI / 2.0), -away]:
			var pd := p.dot(d)
			var goal := _clamp_to_bounds(u.pos + d * (-pd + sqrt(pd * pd - p.length_squared() + clear * clear) + 0.1))
			if goal.distance_to(hit.center) < clear:
				continue  # a wall or the field edge is in the way; try another side
			if not (hit.dodging as Array).has(u.id):
				hit.dodging.append(u.id)
				_emit({"type": "dodge", "unit": u.id, "move": hit.move})
			_walk(u, goal, 0.05)
			return true
	return false


func _nearest_member(at: Vector2, radius: float) -> Unit:
	var best: Unit = null
	var best_d := radius
	for m: Unit in party():
		if m.alive and not in_camp(m):
			var d := at.distance_to(m.pos)
			if d <= best_d:
				best_d = d
				best = m
	return best


func _respawn(u: Unit) -> void:
	u.alive = true
	u.hp = u.max_hp
	u.pos = u.spawn
	u.target_id = -1
	u.taunted_by = -1
	u.returning = false
	u.respawn_at_ms = -1.0
	u.next_attack_ms = now_ms + u.attack_ms
	_emit({"type": "respawn", "unit": u.id})


# --- Combat -------------------------------------------------------------------

func _engage(u: Unit, t: Unit) -> void:
	var d := u.pos.distance_to(t.pos)
	if d > u.range_cells:
		if now_ms < u.busy_until_ms:
			return
		if _walk(u, t.pos, u.range_cells * 0.9) == Walk.STUCK and u.team == 0:
			u.unreachable[t.id] = now_ms + float(_field.unreachable_retry_ms)
			u.target_id = -1
			if u.order == Unit.Order.ATTACK:
				u.order = Unit.Order.NONE
			_emit({"type": "blocked", "unit": u.id, "target": t.id})
		return
	u.facing = _face(u.pos, t.pos, u.facing)
	_reset_stuck(u)
	if now_ms < u.busy_until_ms or now_ms < u.next_attack_ms:
		return
	# Continuous swinging keeps the fractional remainder; a fresh engagement starts now.
	u.next_attack_ms = (u.next_attack_ms if u.next_attack_ms > now_ms - dt_ms else now_ms) + u.attack_ms
	u.action_ms = now_ms
	u.action = &"attack"
	_emit({"type": "swing", "unit": u.id, "target": t.id})
	_roll_hit(u, t, 1.0, "attack")


## Casts `id` on the current target (manual: else the nearest monster in reach). A cast of the chain head starts the
## member's chain; follow-ups are cast by _continue_chain when the previous blow lands.
func _try_skill(u: Unit, manual: bool, id: String) -> bool:
	if id == "" or not u.alive or now_ms < u.busy_until_ms or not u.chain_next.is_empty():
		return false
	if not u.is_ready(id, now_ms):
		if manual:
			_emit({"type": "refused", "what": "skill", "reason": "cooldown"})
		return false
	var skill: Dictionary = tuning.skills[id]
	# A locked target out of reach is not swapped for a nearer one: the player chose it.
	var t: Unit = _valid_target(u)
	if t != null and t.pos.distance_to(u.pos) > float(skill.range_cells):
		if manual:
			_emit({"type": "refused", "what": "skill", "reason": "too_far"})
		return false
	if t == null:
		t = _nearest_monster(u.pos, float(skill.range_cells)) if manual else null
	if t == null:
		if manual:
			_emit({"type": "refused", "what": "skill", "reason": "no_target"})
		return false
	var chain := Skills.chain(run, u.role)
	_cast(u, id, t, 0, chain if not chain.is_empty() and chain[0] == id else [id])
	return true


## Auto hunt: the first ready skill in slot order.
func _auto_skill(u: Unit) -> void:
	var slots: Array = run.slots.get(u.role, [])
	for id: String in slots:
		if id != "" and _try_skill(u, false, id):
			return


func _cast(u: Unit, id: String, t: Unit, step: int, chain: Array) -> void:
	var skill: Dictionary = tuning.skills[id]
	var cfg := Skills.links(tuning)
	var mastery := Skills.mastery_level(run, u.role, id)
	var cast_ms := float(skill.cast_ms) * (float(cfg.follow_cast_ratio) if step > 0 else 1.0)
	var power := float(skill.power) * Skills.power_ratio(tuning, mastery) \
		* (1.0 + float(cfg.follow_damage_bonus_per_step) * step)
	u.target_id = t.id
	u.cooldowns[id] = now_ms + skill_cooldown_ms(u, id)
	u.busy_until_ms = now_ms + cast_ms + float(skill.recovery_ms)
	u.next_attack_ms = maxf(u.next_attack_ms, u.busy_until_ms)
	u.facing = _face(u.pos, t.pos, u.facing)
	u.action_ms = now_ms
	u.action = &"skill"
	var effect: Dictionary = skill.get("effect", {})
	if effect.get("family", "") == "guard":
		var current := u.cover_ratio if u.cover_until_ms >= now_ms else 1.0
		u.cover_until_ms = now_ms + cast_ms + float(effect.duration_ms)
		u.cover_ratio = minf(current, float(effect.damage_taken_ratio))
	var cast_id := _next_cast_id
	_next_cast_id += 1
	var hits := int(skill.get("hits", 1))
	for h in hits:
		_pending_hits.append({"at": now_ms + cast_ms + h * 150.0, "src": u.id, "dst": t.id, "power": power,
			"range": float(skill.range_cells) + 0.6, "skill": id, "cast": cast_id, "step": step, "chain": chain,
			"last": h == hits - 1})
	_emit({"type": "cast", "unit": u.id, "target": t.id, "skill": id, "step": step, "chain_len": chain.size(), "cast_ms": cast_ms})


## The previous chain blow landed: cast the next skill if every condition still holds, else say why it broke.
func _continue_chain(u: Unit) -> void:
	var c: Dictionary = u.chain_next
	u.chain_next = {}
	var t: Unit = unit(int(c.target))
	if t == null or not t.alive:
		return
	var id: String = c.id
	var skill: Dictionary = tuning.skills[id]
	var reason := ""
	if not u.is_ready(id, now_ms):
		reason = "cooldown"
	elif t.pos.distance_to(u.pos) > float(skill.range_cells) + 0.3:
		reason = "too_far"
	elif not t.has_tag(skill.get("needs"), now_ms):
		reason = "tag_gone"
	if reason != "":
		_emit({"type": "chain_break", "unit": u.id, "skill": id, "step": int(c.step), "reason": reason})
		return
	_cast(u, id, t, int(c.step), c.chain)


func _cancel_chain(u: Unit, reason: String) -> void:
	if u.chain_next.is_empty():
		return
	_emit({"type": "chain_break", "unit": u.id, "skill": u.chain_next.id, "step": int(u.chain_next.step), "reason": reason})
	u.chain_next = {}


func _nearest_monster(at: Vector2, radius: float) -> Unit:
	var best: Unit = null
	var best_d := radius
	for m: Unit in units:
		if m.team == 1 and m.alive:
			var d := at.distance_to(m.pos)
			if d <= best_d:
				best_d = d
				best = m
	return best


func _resolve_pending_hits() -> void:
	var due: Array[Dictionary] = []
	var later: Array[Dictionary] = []
	for hit: Dictionary in _pending_hits:
		(due if hit.at <= now_ms else later).append(hit)
	_pending_hits = later
	for hit: Dictionary in due:
		var src: Unit = unit(hit.src)
		if hit.get("area", false):
			# Boss move: whoever stands in the warned circle when it lands.
			if not src.alive:
				continue
			for m: Unit in party():
				var inside: bool = m.alive and not in_camp(m) and m.pos.distance_to(hit.center) <= float(hit.radius)
				if inside:
					_roll_hit(src, m, float(hit.power), "boss")
				if m.alive and (hit.threatened as Array).has(m.id) and not (m == guardian and hit.covered):
					run.note_warning(not inside)
			_emit({"type": "boss_impact", "unit": src.id, "move": hit.move, "center": hit.center, "radius": hit.radius})
			continue
		var dst: Unit = unit(hit.dst)
		if not src.alive or not dst.alive or src.pos.distance_to(dst.pos) > hit.range:
			_emit({"type": "whiff", "unit": src.id})
			if hit.get("last", false) and int(hit.step) + 1 < (hit.chain as Array).size() and src.alive:
				_emit({"type": "chain_break", "unit": src.id, "skill": hit.chain[int(hit.step) + 1],
					"step": int(hit.step) + 1, "reason": "whiff"})
			continue
		var meta := {"skill": hit.skill, "cast": hit.cast, "step": hit.step, "chain": hit.chain, "primary": hit.last}
		_roll_hit(src, dst, hit.power, "skill", meta)
		var area := float(tuning.skills[hit.skill].get("area_cells", 0.0))
		if area > 0.0 and hit.last:
			for m: Unit in units:
				if m != dst and m.team != src.team and m.alive and m.pos.distance_to(src.pos) <= area:
					_roll_hit(src, m, hit.power, "skill", {"skill": hit.skill, "cast": hit.cast, "step": hit.step,
						"chain": [], "primary": false})


## Rolls one blow now (the RNG order stays the unit-id order) and queues its damage for _land_hits.
func _roll_hit(src: Unit, dst: Unit, power: float, kind: String, meta: Dictionary = {}) -> void:
	var hit_chance := clampf(float(_combat.base_hit) - float(_combat.base_evade), float(_combat.min_hit),
		float(_combat.max_hit))
	if rng.randf() >= hit_chance:
		_emit({"type": "miss", "unit": dst.id, "source": src.id, "kind": kind})
		if meta.get("primary", false) and int(meta.step) + 1 < (meta.chain as Array).size():
			_emit({"type": "chain_break", "unit": src.id, "skill": meta.chain[int(meta.step) + 1],
				"step": int(meta.step) + 1, "reason": "miss"})
		return
	var variance: Array = _combat.damage_variance
	var raw := src.attack * power * rng.randf_range(float(variance[0]), float(variance[1]))
	var amount := maxf(1.0, roundf(raw - dst.defense_now(now_ms) * float(_combat.defense_factor)))
	var crit := rng.randf() < src.crit_chance
	if crit:
		amount = roundf(amount * float(_combat.crit_multiplier))
	var block := dst.block_chance > 0.0 and rng.randf() < dst.block_chance
	if block:
		amount = maxf(1.0, roundf(amount * float(_combat.shield_block_damage_ratio)))
	_step_hits.append({"src": src.id, "dst": dst.id, "amount": amount, "crit": crit, "block": block, "kind": kind,
		"meta": meta})


## Every blow of the step lands on the same snapshot; then deaths, then rewards. If the leader
## falls this step the run ends and this step's kills pay nothing (no level-up rescue).
func _land_hits() -> void:
	var fallen: Array[Unit] = []
	var killers: Dictionary = {}
	for h: Dictionary in _step_hits:
		var src: Unit = unit(h.src)
		var dst: Unit = unit(h.dst)
		if not dst.alive:
			continue
		var amount: float = h.amount
		if dst.cover_until_ms >= now_ms:
			amount = maxf(1.0, roundf(amount * dst.cover_ratio))
			h.amount = amount
		# Trip stats count effective damage: after cover and block, without overkill.
		run.note_damage("%s:%s" % [src.role, h.get("meta", {}).get("skill", "attack")] if src.team == 0 else "",
			dst.role if dst.team == 0 else "", minf(amount, dst.hp))
		dst.hp = maxf(0.0, dst.hp - amount)
		dst.last_attacker = src.id
		dst.last_hit_ms = now_ms
		if dst == leader and auto_hunt:
			_search_at_ms = minf(_search_at_ms, now_ms + dt_ms)  # react on the next step
		if dst.team == 1 and dst.target_id < 0 and not dst.returning:
			dst.target_id = src.id
		_emit({"type": "hit", "unit": dst.id, "source": src.id, "amount": int(h.amount), "crit": h.crit,
			"block": h.block, "kind": h.kind, "step": int(h.get("meta", {}).get("step", 0))})
		if not (h.get("meta", {}) as Dictionary).is_empty():
			_skill_landed(src, dst, h.meta)
		if dst.hp <= 0.0 and not killers.has(dst.id):
			killers[dst.id] = src
			fallen.append(dst)
	_step_hits.clear()
	for u: Unit in fallen:
		_down(u, killers[u.id])
	if ended:
		return
	for u: Unit in fallen:
		if u.team == 1:
			_reward(u)


## A skill blow landed: leave its mark, apply its effect, pay mastery once per cast, queue the chain's next step.
func _skill_landed(src: Unit, dst: Unit, meta: Dictionary) -> void:
	var skill: Dictionary = tuning.skills[meta.skill]
	if dst.hp > 0.0:
		var leaves: Variant = skill.get("leaves")
		if leaves != null:
			dst.tags[leaves] = now_ms + float(Skills.links(tuning).tag_window_ms)
		var effect: Dictionary = skill.get("effect", {})
		if effect.get("family", "") == "armor_break":
			dst.def_until_ms = now_ms + float(effect.duration_ms)
			dst.def_ratio = float(effect.defense_ratio)
	if src.team == 0 and not _mastered_casts.has(meta.cast):
		_mastered_casts[meta.cast] = true
		var rose := Skills.add_mastery(tuning, run, src.role, meta.skill)
		if rose > 0:
			_emit({"type": "mastery_up", "unit": src.id, "skill": meta.skill, "level": rose})
	var chain: Array = meta.chain
	var next_step := int(meta.step) + 1
	if meta.primary and next_step < chain.size() and dst.hp > 0.0 and src.alive:
		src.chain_next = {"id": chain[next_step], "step": next_step, "target": dst.id, "chain": chain,
			"at": maxf(now_ms, src.busy_until_ms)}


func _down(u: Unit, killer: Unit) -> void:
	u.alive = false
	u.hp = 0.0
	u.target_id = -1
	u.order = Unit.Order.NONE
	u.hot_left_ms = 0.0
	_emit({"type": "down", "unit": u.id, "source": killer.id})
	for other: Unit in units:
		if other.target_id == u.id:
			other.target_id = -1
	_pending_hits.assign(_pending_hits.filter(func(hit: Dictionary) -> bool: return hit.src != u.id))
	if u.team == 1:
		var def: Dictionary = tuning.bosses.get(u.kind_id, {})
		u.respawn_at_ms = now_ms + float(def.get("respawn_ms", _field.respawn_ms))
		_pending_hits.assign(_pending_hits.filter(func(hit: Dictionary) -> bool: return hit.src != u.id))
	elif u == leader:
		ended = true
		_emit({"type": "run_ended", "level": level, "kills": kills})


func _reward(m: Unit) -> void:
	var paid := run.record_kill(run.next_kill_id(), m.kind_id, m.level, rng, now_ms)
	if paid.is_empty():
		return
	_emit({"type": "reward", "unit": m.id, "exp": paid.exp, "gold": int(paid.gold), "material": paid.material,
		"gear": paid.gear, "seals": int(paid.get("seals", 0))})
	_on_levels(int(paid.levels))


## Test and quest hook: EXP from outside a kill.
func _gain_exp(amount: float) -> void:
	_on_levels(run.gain_exp(amount))


func _on_levels(gained: int) -> void:
	if gained <= 0:
		return
	for m: Unit in party():
		_apply_member_stats(m)
		if m.alive:
			m.hp = m.max_hp
	_emit({"type": "level_up", "level": run.level})


## Recomputes a member's stats after a gear change, keeping the HP ratio.
func refresh_member(role: String) -> void:
	for m: Unit in party():
		if m.role == role:
			var ratio := m.hp_ratio()
			_apply_member_stats(m)
			if m.alive:
				m.hp = m.max_hp * ratio


func _claim_quest(qid: String) -> void:
	var paid := run.claim(qid, now_ms)
	if paid.is_empty():
		_emit({"type": "refused", "what": "claim", "reason": "not_ready"})
		return
	_emit({"type": "quest_claimed", "quest": qid, "exp": int(paid.exp), "gold": int(paid.gold)})
	_on_levels(int(paid.levels))


# --- Sustain ------------------------------------------------------------------

func _sustain() -> void:
	var regen := float(_field.natural_regen_max_hp_ratio_per_s) * dt_ms / 1000.0
	for m: Unit in party():
		if not m.alive:
			continue
		m.hp = minf(m.max_hp, m.hp + m.max_hp * regen)
		if m.hot_left_ms > 0.0:
			var slice := minf(dt_ms, m.hot_left_ms)
			m.hp = minf(m.max_hp, m.hp + m.hot_rate * slice)
			m.hot_left_ms -= slice
	if not auto_potion:
		return
	# The neediest member drinks first, so two members never split the last bottle.
	var order: Array = party().filter(func(m: Unit) -> bool: return m.alive)
	order.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.hp_ratio() < b.hp_ratio() if a.hp_ratio() != b.hp_ratio() else a.id < b.id)
	var threshold := float(tuning.section("automation").potion_threshold)
	var emergency_line := threshold * float(_field.emergency_auto_threshold_ratio)
	for m: Unit in order:
		if m.hp_ratio() >= threshold:
			continue
		if m.hot_left_ms <= 0.0 and run.count("tonic_small") > 0:
			_use_tonic(m, false)
		elif m.hp_ratio() < emergency_line:
			_use_emergency(m, false)


func _use_tonic(m: Unit, manual: bool) -> void:
	if not m.alive or run.count("tonic_small") <= 0 or m.hot_left_ms > 0.0 or m.hp >= m.max_hp:
		if manual:
			var reason := "none" if run.count("tonic_small") <= 0 else ("hot" if m.hot_left_ms > 0.0 else "full")
			_emit({"type": "refused", "what": "tonic", "reason": reason})
		return
	var item: Dictionary = tuning.items["tonic_small"]
	run.consume("tonic_small")
	m.hot_left_ms = float(item.duration_ms)
	m.hot_rate = float(item.heal_flat) / float(item.duration_ms)
	_emit({"type": "potion", "unit": m.id, "item": "tonic_small", "auto": not manual})


func _use_emergency(m: Unit, manual: bool) -> void:
	var item: Dictionary = tuning.items["emergency_kit"]
	if not m.alive or run.count("emergency_kit") <= 0 or not m.is_ready("emergency_kit", now_ms) \
			or m.hp >= m.max_hp:
		if manual:
			var reason := "none" if run.count("emergency_kit") <= 0 else ("full" if m.hp >= m.max_hp else "cooldown")
			_emit({"type": "refused", "what": "emergency", "reason": reason})
		return
	run.consume("emergency_kit")
	m.cooldowns["emergency_kit"] = now_ms + float(item.cooldown_ms)
	var amount := _heal(m, m.max_hp * float(item.heal_max_hp_ratio))
	_emit({"type": "heal", "unit": m.id, "source": m.id, "amount": amount, "kind": "emergency"})


func _heal(m: Unit, amount: float) -> int:
	var before := m.hp
	m.hp = minf(m.max_hp, m.hp + amount)
	return int(roundf(m.hp - before))


# --- Movement -----------------------------------------------------------------

func _walk(u: Unit, goal: Vector2, stop: float) -> Walk:
	var to := goal - u.pos
	var dist := to.length()
	if dist <= stop + 0.01:
		_reset_stuck(u)
		return Walk.ARRIVED
	var travel := minf(u.speed * dt_ms / 1000.0, dist - stop)
	_displace(u, to / dist * travel, goal)
	# Stuck: no real progress toward the goal for stuck_ms.
	var left := u.pos.distance_to(goal)
	if left < u.stuck_best - float(_field.stuck_progress_cells):
		u.stuck_best = left
		u.stuck_ms = 0.0
	else:
		u.stuck_ms += dt_ms
		if u.stuck_ms >= float(_field.stuck_ms):
			_reset_stuck(u)
			return Walk.STUCK
	return Walk.MOVING


## Same-team bodies push apart so a party never stacks into one sprite. Uses _displace, so
## obstacles and bounds still hold.
func _separate() -> void:
	var gap := float(_field.unit_radius_cells) * 3.2
	for i in units.size():
		var a := units[i]
		if not a.alive:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if not b.alive or b.team != a.team:
				continue
			var offset := b.pos - a.pos
			var d := offset.length()
			if d >= gap:
				continue
			var dir := offset / d if d > 0.001 else Vector2.RIGHT.rotated(float(a.id + b.id))
			var push := dir * (gap - d) * 0.5
			var keep := [a.moving, a.facing, b.moving, b.facing]  # a nudge is not a walk
			_displace(a, -push, a.pos - push)
			_displace(b, push, b.pos + push)
			a.moving = keep[0]
			a.facing = keep[1]
			b.moving = keep[2]
			b.facing = keep[3]


func _reset_stuck(u: Unit) -> void:
	u.stuck_ms = 0.0
	u.stuck_best = INF


## Moves by v, sliding along circular obstacles. A head-on approach turns toward the side the
## goal lies on (right-hand side when the goal is dead behind), so nobody pins on a contact point.
func _displace(u: Unit, v: Vector2, goal: Vector2) -> void:
	var length := v.length()
	if length < 0.0001:
		return
	var body := float(_field.unit_radius_cells)
	var next := u.pos + v
	var solid: Array = obstacles
	if u.team == 1 and not camp.is_empty():
		solid = solid + [camp]
	for o: Dictionary in solid:
		var r: float = o.radius + body
		if next.distance_to(o.pos) >= r:
			continue
		var normal: Vector2 = u.pos - o.pos
		normal = normal.normalized() if normal.length() > 0.001 else Vector2.RIGHT
		var inward := v.dot(normal)
		if inward < 0.0:
			var tangent := v - normal * inward
			if tangent.length() < length * 0.2:
				var side := normal.orthogonal()
				var s := signf(side.dot(goal - o.pos))
				tangent = side * (s if s != 0.0 else 1.0)
			next = u.pos + tangent.normalized() * length
		var away: Vector2 = next - o.pos
		if away.length() < r:
			next = o.pos + (away.normalized() if away.length() > 0.001 else normal) * r
	next = _clamp_to_bounds(next)
	if next.distance_to(u.pos) > 0.0001:
		u.facing = (next - u.pos).normalized()
		u.moving = true
	u.pos = next


func _clamp_to_bounds(p: Vector2) -> Vector2:
	var pad := float(_field.unit_radius_cells)
	return Vector2(clampf(p.x, bounds.position.x + pad, bounds.end.x - pad),
		clampf(p.y, bounds.position.y + pad, bounds.end.y - pad))


func _face(from: Vector2, to: Vector2, fallback: Vector2) -> Vector2:
	return (to - from).normalized() if from.distance_to(to) > 0.01 else fallback


func _emit(event: Dictionary) -> void:
	event.id = _next_event_id
	event.t = now_ms
	_next_event_id += 1
	_events.append(event)
