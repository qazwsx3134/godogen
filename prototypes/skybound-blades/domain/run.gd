extends RefCounted
## One generation's expedition (Run): level, EXP, carried gold and items, gear, quests and the
## receipts that make every reward pay once. The Battle fights; the Run owns what the fight earns.
## Everything here is lost when the leader falls; the Profile (warehouse, memorial) is not.

const Tuning = preload("res://domain/tuning.gd")

var tuning: Tuning
var id: String
var generation: int = 1
var level: int = 1
var experience: float = 0.0
var gold: int = 0
var kills: int = 0
## item id -> quantity carried (materials, potions, bandages, rations).
var stacks: Dictionary = {}
## item id -> how many of stacks[item] are run-issued supplies (no sale, no warehouse).
var issued: Dictionary = {}
## instance id -> {id, template, quality, bonus: {stat: value}, issued: bool}
var gear: Dictionary = {}
## role -> {slot: instance id}
var equipped: Dictionary = {}
## quest id -> {progress, claims, available_at_ms}
var quests: Dictionary = {}
## kill ids already paid (idempotency: a replayed kill never pays twice).
var receipts: Dictionary = {}
## Since leaving camp: {kills, exp, gold, items: {id: qty}, gear: [ids], used: {id: qty}}
var trip: Dictionary = {}
var _next_seq: int = 1


func _init(tuning_: Tuning, run_id: String, generation_: int = 1) -> void:
	tuning = tuning_
	id = run_id
	generation = generation_
	for entry: Dictionary in tuning.section("hero").initial_issued_items:
		add_item(entry.base_item_id, int(entry.qty), true)
	for role: String in tuning.section("party").initial_equipment:
		equipped[role] = {}
		for template_id: String in tuning.section("party").initial_equipment[role]:
			var inst := make_gear(template_id, "plain", true)
			equipped[role][tuning.equipment[template_id].slot] = inst.id
	for q: Dictionary in tuning.data.quest_definitions:
		if int(q.floor) == 1:
			quests[q.id] = {"progress": 0, "claims": 0, "available_at_ms": 0.0}
	reset_trip()


# --- Growth ---------------------------------------------------------------------

func xp_needed() -> int:
	return tuning.xp_needed(level)


## Adds EXP; returns how many levels were gained.
func gain_exp(amount: float) -> int:
	var gained := 0
	experience += amount
	trip.exp = float(trip.exp) + amount
	while experience >= xp_needed() and level < int(tuning.section("simulation").max_level):
		experience -= xp_needed()
		level += 1
		gained += 1
	return gained


## Pays a kill once. Returns {} when this kill id was already paid.
func record_kill(kill_id: String, monster_id: String, monster_level: int, rng: RandomNumberGenerator,
		now_ms: float = 0.0) -> Dictionary:
	if receipts.has(kill_id):
		return {}
	receipts[kill_id] = true
	var def: Dictionary = tuning.monsters[monster_id] if tuning.monsters.has(monster_id) else tuning.bosses[monster_id]
	var loot: Dictionary = tuning.section("loot")
	var gained := float(def.base_exp) * tuning.xp_penalty(level, monster_level)
	var result := {"exp": gained, "gold": int(def.gold), "material": "", "gear": ""}
	kills += 1
	trip.kills = int(trip.kills) + 1
	add_gold(int(def.gold))
	if rng.randf() < float(loot.material_chance):
		result.material = tuning.data.zones[0].material_id
		add_item(result.material, 1)
	if rng.randf() < float(loot.gear_chance):
		var inst := roll_gear(rng)
		result.gear = inst.id
		trip.gear.append(inst.id)
	for qid: String in quests:
		var q: Dictionary = tuning.quests[qid]
		if q.objective.type in ["monster_kill", "boss_kill"] and q.objective.target == monster_id:
			var state: Dictionary = quests[qid]
			if state.progress < int(q.objective.count) and _quest_open(qid, now_ms):
				state.progress += 1
	result.levels = gain_exp(gained)
	return result


func next_kill_id() -> String:
	var kid := "%s:%d" % [id, _next_seq]
	_next_seq += 1
	return kid


# --- Items ----------------------------------------------------------------------

func count(item_id: String) -> int:
	return int(stacks.get(item_id, 0))


## Free (non-issued) quantity: what may be sold or stored.
func free_count(item_id: String) -> int:
	return count(item_id) - int(issued.get(item_id, 0))


func add_item(item_id: String, qty: int, is_issued: bool = false) -> void:
	stacks[item_id] = count(item_id) + qty
	if is_issued:
		issued[item_id] = int(issued.get(item_id, 0)) + qty
	elif tuning.items.has(item_id) and tuning.items[item_id].kind == "material":
		trip.items[item_id] = int(trip.items.get(item_id, 0)) + qty


## Uses issued stock first. False (and no change) when there is not enough.
func consume(item_id: String, qty: int = 1) -> bool:
	if count(item_id) < qty:
		return false
	stacks[item_id] = count(item_id) - qty
	issued[item_id] = maxi(0, int(issued.get(item_id, 0)) - qty)
	trip.used[item_id] = int(trip.used.get(item_id, 0)) + qty
	return true


## Removes free stock only (sale, deposit, quest hand-in). False when not enough.
func take_free(item_id: String, qty: int) -> bool:
	if qty <= 0 or free_count(item_id) < qty:
		return false
	stacks[item_id] = count(item_id) - qty
	return true


func add_gold(amount: int) -> void:
	gold += amount
	trip.gold = int(trip.gold) + amount


func make_gear(template_id: String, quality: String, is_issued: bool = false) -> Dictionary:
	var template: Dictionary = tuning.equipment[template_id]
	var gen: Dictionary = tuning.section("equipment_generation")
	var ratio := float(gen.quality_positive_stat_ratios[quality]) * float(gen.tier_stat_ratios[0])
	var bonus := {}
	for stat: String in template.bonus:
		var v := float(template.bonus[stat])
		if v > 0.0:
			v *= ratio
		# Chances stay fractional; flat stats round to whole numbers.
		bonus[stat] = v if stat.ends_with("_chance") else roundf(v)
	var inst := {"id": "%s:g%d" % [id, _next_seq], "template": template_id, "quality": quality,
		"bonus": bonus, "issued": is_issued}
	_next_seq += 1
	gear[inst.id] = inst
	return inst


func roll_gear(rng: RandomNumberGenerator) -> Dictionary:
	var templates: Array = tuning.equipment.keys()
	templates.sort()
	var template_id: String = templates[rng.randi_range(0, templates.size() - 1)]
	var weights: Dictionary = tuning.section("loot").gear_quality_weights
	var total := 0.0
	for q: String in weights:
		total += float(weights[q])
	var pick := rng.randf() * total
	var quality := "plain"
	for q: String in ["plain", "fine", "rare"]:
		pick -= float(weights.get(q, 0.0))
		if pick < 0.0:
			quality = q
			break
	return make_gear(template_id, quality)


func equipped_ids(role: String) -> Array:
	return (equipped.get(role, {}) as Dictionary).values()


func holder_of(instance_id: String) -> String:
	for role: String in equipped:
		if instance_id in (equipped[role] as Dictionary).values():
			return role
	return ""


## Equips an instance on a role (moving it off whoever wore it). Returns the replaced id or "".
func equip(role: String, instance_id: String) -> String:
	if not gear.has(instance_id):
		return ""
	var slot: String = tuning.equipment[gear[instance_id].template].slot
	var previous_holder := holder_of(instance_id)
	if previous_holder != "":
		(equipped[previous_holder] as Dictionary).erase(slot)
	var replaced: String = (equipped[role] as Dictionary).get(slot, "")
	equipped[role][slot] = instance_id
	return replaced


func unequip(role: String, slot: String) -> void:
	(equipped.get(role, {}) as Dictionary).erase(slot)


## Gear in the bag (not worn by anyone).
func bag_gear() -> Array:
	var out: Array = []
	for gid: String in gear:
		if holder_of(gid) == "":
			out.append(gear[gid])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return out


## Final stats of a role with what it wears now.
func member_stats(role: String) -> Dictionary:
	var worn: Array = []
	for gid: String in equipped_ids(role):
		worn.append(gear[gid])
	return tuning.member_stats(role, level, worn)


# --- Quests ---------------------------------------------------------------------

func _quest_open(qid: String, now_ms: float) -> bool:
	var q: Dictionary = tuning.quests[qid]
	var state: Dictionary = quests[qid]
	if not bool(q.repeatable) and int(state.claims) > 0:
		return false
	return now_ms >= float(state.available_at_ms)


func quest_progress(qid: String) -> int:
	var q: Dictionary = tuning.quests[qid]
	if q.objective.type == "item_count":
		return mini(free_count(q.objective.target), int(q.objective.count))
	return int(quests[qid].progress)


func quest_ready(qid: String, now_ms: float) -> bool:
	if not quests.has(qid) or not _quest_open(qid, now_ms):
		return false
	return quest_progress(qid) >= int(tuning.quests[qid].objective.count)


## Claims a quest: re-checks, takes hand-ins and pays in one step. {} when not claimable.
func claim(qid: String, now_ms: float) -> Dictionary:
	if not quests.has(qid) or not quest_ready(qid, now_ms):
		return {}
	var q: Dictionary = tuning.quests[qid]
	if bool(q.consume_on_claim) and not take_free(q.objective.target, int(q.objective.count)):
		return {}
	var state: Dictionary = quests[qid]
	state.progress = 0
	state.claims = int(state.claims) + 1
	if bool(q.repeatable):
		state.available_at_ms = now_ms + float(tuning.section("quests").repeat_cooldown_ms)
	var reward: Dictionary = q.reward
	add_gold(int(reward.get("gold", 0)))
	var levels := gain_exp(float(reward.get("exp", 0)))
	return {"quest": qid, "exp": int(reward.get("exp", 0)), "gold": int(reward.get("gold", 0)), "levels": levels}


# --- Trips ----------------------------------------------------------------------

func reset_trip() -> void:
	trip = {"kills": 0, "exp": 0.0, "gold": 0, "items": {}, "gear": [], "used": {}}


# --- Save -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"id": id, "generation": generation, "level": level, "experience": experience, "gold": gold,
		"kills": kills, "stacks": stacks, "issued": issued, "gear": gear, "equipped": equipped, "quests": quests,
		"receipts": receipts.keys(), "trip": trip, "next_seq": _next_seq}


static func from_dict(tuning_: Tuning, d: Dictionary) -> RefCounted:
	var r: RefCounted = load("res://domain/run.gd").new(tuning_, String(d.id), int(d.generation))
	r.level = int(d.level)
	r.experience = float(d.experience)
	r.gold = int(d.gold)
	r.kills = int(d.kills)
	r.stacks = _ints(d.stacks)
	r.issued = _ints(d.issued)
	r.gear = d.gear
	r.equipped = d.equipped
	r.quests = {}
	for qid: String in d.quests:
		var q: Dictionary = d.quests[qid]
		r.quests[qid] = {"progress": int(q.progress), "claims": int(q.claims), "available_at_ms": float(q.available_at_ms)}
	r.receipts = {}
	for kid: String in d.receipts:
		r.receipts[kid] = true
	r.trip = d.get("trip", r.trip)
	r._next_seq = int(d.next_seq)
	return r


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out
