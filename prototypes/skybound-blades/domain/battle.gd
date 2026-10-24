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
var level: int = 1
var experience: float = 0.0
var gold: int = 0
var materials: Dictionary = {}
var kills: int = 0
var inventory: Dictionary = {}
var quest: Dictionary = {}
var ended: bool = false

var _events: Array[Dictionary] = []
var _next_event_id: int = 1
var _commands: Array[Dictionary] = []
var _pending_hits: Array[Dictionary] = []
var _step_hits: Array[Dictionary] = []
var _search_at_ms: float = 0.0
var _by_id: Dictionary = {}
var _field: Dictionary
var _combat: Dictionary


## setup = {seed, bounds: Rect2, obstacles: [{pos, radius}], party_spawn: Vector2,
## monsters: [{id: String, pos: Vector2}]}. Positions are ground cells (x, z).
func _init(tuning_: Tuning, setup: Dictionary) -> void:
	tuning = tuning_
	_field = tuning.section("field")
	_combat = tuning.section("combat")
	dt_ms = float(tuning.step_ms())
	rng.seed = int(setup.get("seed", 1))
	bounds = setup.bounds
	for obstacle: Dictionary in setup.obstacles:
		obstacles.append({"pos": obstacle.pos, "radius": float(obstacle.radius)})
	var names := {"leader": "隊長", "guardian": "盾衛", "support": "援護"}
	var slots: Array = _field.follow_slots_cells
	leader = _add_member("leader", names.leader, setup.party_spawn)
	guardian = _add_member("guardian", names.guardian, setup.party_spawn + Vector2(slots[0][0], slots[0][1]))
	support = _add_member("support", names.support, setup.party_spawn + Vector2(slots[1][0], slots[1][1]))
	for spec: Dictionary in setup.monsters:
		_add_monster(spec.id, spec.pos)
	for entry: Dictionary in tuning.section("hero").initial_issued_items:
		inventory[entry.base_item_id] = int(entry.qty)
	var quest_def: Dictionary = tuning.quests[_field.slice_quest_id]
	quest = {"id": quest_def.id, "target": quest_def.objective.target, "count": int(quest_def.objective.count),
		"progress": 0, "claims": 0, "available_at_ms": 0.0, "reward": quest_def.reward}


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
	return tuning.xp_needed(level)


func quest_ready() -> bool:
	return now_ms >= quest.available_at_ms and quest.progress >= quest.count


func skill_ready_in_ms() -> float:
	return maxf(0.0, float(leader.cooldowns.get("cleave", 0.0)) - now_ms)


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
	_separate()


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
	var stats: Dictionary = tuning.member_stats(u.role, level)
	u.level = level
	u.max_hp = stats.max_hp
	u.attack = stats.attack
	u.defense = stats.defense
	u.agility = stats.agility
	u.crit_chance = stats.crit_chance
	u.block_chance = stats.block_chance
	u.attack_ms = stats.attack_ms


func _add_monster(monster_id: String, at: Vector2) -> Unit:
	var def: Dictionary = tuning.monsters[monster_id]
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
	u.attack_ms = float(def.attack_interval_ms)
	u.range_cells = float(_combat.melee_range_cells)
	u.speed = float(_field.monster_move_cells_per_s.get(monster_id, 2.4))
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
			_try_skill(leader, true)
		"tonic":
			_use_tonic(leader, true)
		"emergency":
			_use_emergency(leader, true)
		"claim":
			_claim_quest()


# --- Leader ------------------------------------------------------------------

func _think_leader(u: Unit) -> void:
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
		_try_skill(u, false)
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
	if _too_far_from_leader(u):
		_follow(u)
		return
	var bandage: Dictionary = tuning.utilities["bandage_ally"]
	if u.is_ready("bandage_ally", now_ms) and int(inventory.get("bandage", 0)) > 0 and now_ms >= u.busy_until_ms:
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
	inventory.bandage = int(inventory.bandage) - 1
	u.cooldowns["bandage_ally"] = now_ms + float(bandage.cooldown_ms)
	u.busy_until_ms = now_ms + 600.0
	u.action_ms = now_ms
	u.action = &"skill"
	u.facing = _face(u.pos, patient.pos, u.facing)
	var amount := _heal(patient, patient.max_hp * float(bandage.heal_max_hp_ratio))
	_emit({"type": "heal", "unit": patient.id, "source": u.id, "amount": amount, "kind": "bandage"})


# --- Monsters -----------------------------------------------------------------

func _think_monster(u: Unit) -> void:
	var leash := float(_field.leash_radius_cells)
	if u.returning:
		if _walk(u, u.spawn, 0.1) != Walk.MOVING:
			u.returning = false
			u.hp = u.max_hp
		return
	if u.taunted_by >= 0 and now_ms >= u.taunt_until_ms:
		u.taunted_by = -1
	var target: Unit = _valid_target(u)
	if u.taunted_by >= 0 and unit(u.taunted_by).alive:
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


func _nearest_member(at: Vector2, radius: float) -> Unit:
	var best: Unit = null
	var best_d := radius
	for m: Unit in party():
		if m.alive:
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


func _try_skill(u: Unit, manual: bool) -> bool:
	var skill: Dictionary = tuning.skills["cleave"]
	if not u.alive or now_ms < u.busy_until_ms or not u.is_ready("cleave", now_ms):
		return false
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
	u.target_id = t.id
	u.cooldowns["cleave"] = now_ms + float(skill.cooldown_ms)
	u.busy_until_ms = now_ms + float(skill.cast_ms) + float(skill.recovery_ms)
	u.next_attack_ms = maxf(u.next_attack_ms, u.busy_until_ms)
	u.facing = _face(u.pos, t.pos, u.facing)
	u.action_ms = now_ms
	u.action = &"skill"
	_pending_hits.append({"at": now_ms + float(skill.cast_ms), "src": u.id, "dst": t.id,
		"power": float(skill.power), "range": float(skill.range_cells) + 0.6})
	_emit({"type": "cast", "unit": u.id, "target": t.id, "skill": "cleave"})
	return true


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
		var dst: Unit = unit(hit.dst)
		if not src.alive or not dst.alive or src.pos.distance_to(dst.pos) > hit.range:
			_emit({"type": "whiff", "unit": src.id})
			continue
		_roll_hit(src, dst, hit.power, "skill")


## Rolls one blow now (the RNG order stays the unit-id order) and queues its damage for _land_hits.
func _roll_hit(src: Unit, dst: Unit, power: float, kind: String) -> void:
	var hit_chance := clampf(float(_combat.base_hit) - float(_combat.base_evade), float(_combat.min_hit),
		float(_combat.max_hit))
	if rng.randf() >= hit_chance:
		_emit({"type": "miss", "unit": dst.id, "source": src.id, "kind": kind})
		return
	var variance: Array = _combat.damage_variance
	var raw := src.attack * power * rng.randf_range(float(variance[0]), float(variance[1]))
	var amount := maxf(1.0, roundf(raw - dst.defense * float(_combat.defense_factor)))
	var crit := rng.randf() < src.crit_chance
	if crit:
		amount = roundf(amount * float(_combat.crit_multiplier))
	var block := dst.block_chance > 0.0 and rng.randf() < dst.block_chance
	if block:
		amount = maxf(1.0, roundf(amount * float(_combat.shield_block_damage_ratio)))
	_step_hits.append({"src": src.id, "dst": dst.id, "amount": amount, "crit": crit, "block": block, "kind": kind})


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
		dst.hp = maxf(0.0, dst.hp - h.amount)
		dst.last_attacker = src.id
		dst.last_hit_ms = now_ms
		if dst == leader and auto_hunt:
			_search_at_ms = minf(_search_at_ms, now_ms + dt_ms)  # react on the next step
		if dst.team == 1 and dst.target_id < 0 and not dst.returning:
			dst.target_id = src.id
		_emit({"type": "hit", "unit": dst.id, "source": src.id, "amount": int(h.amount), "crit": h.crit,
			"block": h.block, "kind": h.kind})
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
		u.respawn_at_ms = now_ms + float(_field.respawn_ms)
	elif u == leader:
		ended = true
		_emit({"type": "run_ended", "level": level, "kills": kills})


func _reward(m: Unit) -> void:
	var gained := m.base_exp * tuning.xp_penalty(level, m.level)
	kills += 1
	gold += m.gold
	var material := ""
	if rng.randf() < float(tuning.section("loot").material_chance):
		material = tuning.data.zones[0].material_id
		materials[material] = int(materials.get(material, 0)) + 1
	if m.kind_id == quest.target and now_ms >= quest.available_at_ms and quest.progress < quest.count:
		quest.progress += 1
	_emit({"type": "reward", "unit": m.id, "exp": gained, "gold": m.gold, "material": material})
	_gain_exp(gained)


func _gain_exp(amount: float) -> void:
	experience += amount
	while experience >= xp_needed() and level < int(tuning.section("simulation").max_level):
		experience -= xp_needed()
		level += 1
		for m: Unit in party():
			_apply_member_stats(m)
			if m.alive:
				m.hp = m.max_hp
		_emit({"type": "level_up", "level": level})


func _claim_quest() -> void:
	if not quest_ready():
		_emit({"type": "refused", "what": "claim", "reason": "not_ready"})
		return
	var reward: Dictionary = quest.reward
	quest.progress = 0
	quest.claims += 1
	quest.available_at_ms = now_ms + float(tuning.section("quests").repeat_cooldown_ms)
	gold += int(reward.gold)
	_emit({"type": "quest_claimed", "exp": int(reward.exp), "gold": int(reward.gold)})
	_gain_exp(float(reward.exp))


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
		if m.hot_left_ms <= 0.0 and int(inventory.get("tonic_small", 0)) > 0:
			_use_tonic(m, false)
		elif m.hp_ratio() < emergency_line:
			_use_emergency(m, false)


func _use_tonic(m: Unit, manual: bool) -> void:
	if not m.alive or int(inventory.get("tonic_small", 0)) <= 0 or m.hot_left_ms > 0.0 or m.hp >= m.max_hp:
		if manual:
			var reason := "none" if int(inventory.get("tonic_small", 0)) <= 0 else ("hot" if m.hot_left_ms > 0.0 else "full")
			_emit({"type": "refused", "what": "tonic", "reason": reason})
		return
	var item: Dictionary = tuning.items["tonic_small"]
	inventory.tonic_small = int(inventory.tonic_small) - 1
	m.hot_left_ms = float(item.duration_ms)
	m.hot_rate = float(item.heal_flat) / float(item.duration_ms)
	_emit({"type": "potion", "unit": m.id, "item": "tonic_small", "auto": not manual})


func _use_emergency(m: Unit, manual: bool) -> void:
	var item: Dictionary = tuning.items["emergency_kit"]
	if not m.alive or int(inventory.get("emergency_kit", 0)) <= 0 or not m.is_ready("emergency_kit", now_ms) \
			or m.hp >= m.max_hp:
		if manual:
			var reason := "none" if int(inventory.get("emergency_kit", 0)) <= 0 else ("full" if m.hp >= m.max_hp else "cooldown")
			_emit({"type": "refused", "what": "emergency", "reason": reason})
		return
	inventory.emergency_kit = int(inventory.emergency_kit) - 1
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
	for o: Dictionary in obstacles:
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
