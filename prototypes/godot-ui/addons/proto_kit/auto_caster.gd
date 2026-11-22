extends RefCounted
## Auto-cast spell book for survivor-likes: every learned spell fires on its own cooldown at targets chosen by a rule.
## Pure logic, no nodes: each step the game passes the caster's position and the candidate targets, and turns the
## returned casts into effects, numbers and sounds. `const AutoCaster = preload("res://addons/proto_kit/auto_caster.gd")`
##
##   var book := AutoCaster.new()
##   book.learn({"id": "cleave", "cooldown": 1.5, "range": 3.0, "target": "nearest", "max_targets": 3, "damage": 40})
##   book.rank_up("cleave", {"damage": 0.18})               # a drafted upgrade; Rarity.bonus() builds the dict
##   for cast in book.step(delta, me.position, enemies):   # enemies: [{id, pos, hp, max_hp, tags}]
##       for hit in cast.hits: damage(hit.id, hit.damage)
##
## Spell fields (only id is required):
##   cooldown (s, 1.0)  range (m, 5.0)  damage (per target, 0)  max_targets (1)
##   target: "nearest" | "farthest" | "highest_hp" | "lowest_hp" | "random" | "all" | "self"
##   priority: tags picked before anything else, in order (["boss", "elite"]); inside a tag the target rule decides
##   execute_below + execute_mult: damage multiplier on targets under that HP ratio (they are also preferred)
##   heal_ratio: the caster heals this share of the damage dealt (cast.heal)
##   dot: {"total": damage over the whole effect, "ticks": n, "duration": s}; unique_dot skips afflicted targets
##   stun (s) with stun_boss_factor (0.25): bosses are stunned for that share
##   buff: {"damage": 0.4, "duration": 11} raises all damage while it lasts; trigger_range: fire only with an enemy
##   that close (a buff with no trigger fires on cooldown)
## Upgrades (rank_up, learn's bonus) add up: {"damage": +ratio, "cooldown": -ratio (0.23 = 23 % shorter),
## "targets": +n}. Global modifiers: damage_mult (per-level growth, talents) and cooldown_mult.
##
## Cast (Dictionary): {"spell": id, "hits": [{"id", "damage", "stun"}], "heal": float, "buff": {...} or {},
## "dot": bool (a damage-over-time tick)}. Deterministic with the RNG passed to _init (used only by "random").

var damage_mult: float = 1.0
var cooldown_mult: float = 1.0

var _spells: Dictionary = {}   # id -> spell dict
var _ranks: Dictionary = {}    # id -> int
var _bonus: Dictionary = {}    # id -> {"damage", "cooldown", "targets"}
var _timers: Dictionary = {}   # id -> seconds until ready
var _buffs: Array = []   # {"spell", "damage", "left"}
var _dots: Array = []    # {"spell", "id", "per_tick", "ticks", "every", "next"}
var _order: Array[String] = []
var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Adds a spell at rank 1 (or adds its bonus to a known one). `bonus`: the rarity bonus of the card that taught it.
func learn(spell: Dictionary, bonus: Dictionary = {}) -> void:
	var id: String = spell.id
	if not _spells.has(id):
		_spells[id] = spell
		_ranks[id] = 1
		_bonus[id] = {"damage": 0.0, "cooldown": 0.0, "targets": 0}
		_timers[id] = 0.0
		_order.append(id)
	_add_bonus(id, bonus)


## A drafted upgrade for a known spell: one more rank and its bonus. False for an unknown spell.
func rank_up(id: String, bonus: Dictionary = {}) -> bool:
	if not _spells.has(id):
		return false
	_ranks[id] += 1
	_add_bonus(id, bonus)
	return true


func knows(id: String) -> bool:
	return _spells.has(id)


func rank(id: String) -> int:
	return _ranks.get(id, 0)


func spells() -> Array[String]:
	return _order.duplicate()


## Effective numbers of a spell after bonuses and global modifiers (for tooltips and tests).
func effective(id: String) -> Dictionary:
	var s: Dictionary = _spells[id]
	var b: Dictionary = _bonus[id]
	return {
		"damage": float(s.get("damage", 0.0)) * (1.0 + b.damage) * damage_mult * _buff_mult(),
		"cooldown": maxf(0.05, float(s.get("cooldown", 1.0)) * maxf(0.1, 1.0 - b.cooldown) * cooldown_mult),
		"targets": int(s.get("max_targets", 1)) + int(b.targets),
		"range": float(s.get("range", 5.0)),
	}


## Damage multiplier from active buffs (they stack additively).
func buff_mult() -> float:
	return _buff_mult()


## Advances cooldowns, buffs and damage-over-time by `delta` seconds and returns what fired.
func step(delta: float, origin: Variant, targets: Array) -> Array[Dictionary]:
	var casts: Array[Dictionary] = []
	for buff in _buffs:
		buff.left -= delta
	_buffs = _buffs.filter(func(b: Dictionary) -> bool: return b.left > 0.0)
	_tick_dots(delta, targets, casts)
	for id: String in _order:
		_timers[id] = maxf(0.0, _timers[id] - delta)
		if _timers[id] > 0.0:
			continue
		var cast := _cast(id, origin, targets)
		if cast.is_empty():
			continue  # nothing in range: stays ready and fires the moment something comes close
		_timers[id] = effective(id).cooldown
		casts.append(cast)
	return casts


## Forget timers, buffs and dots (a new run); spells and ranks stay unless `forget_spells`.
func reset(forget_spells: bool = false) -> void:
	_buffs.clear()
	_dots.clear()
	for id: String in _timers:
		_timers[id] = 0.0
	if forget_spells:
		_spells.clear()
		_ranks.clear()
		_bonus.clear()
		_timers.clear()
		_order.clear()


func to_dict() -> Dictionary:
	return {"spells": _order.map(func(id: String) -> Dictionary: return _spells[id]), "ranks": _ranks.duplicate(),
		"bonus": _bonus.duplicate(true), "damage_mult": damage_mult, "cooldown_mult": cooldown_mult}


func from_dict(data: Dictionary) -> void:
	reset(true)
	for spell: Dictionary in data.get("spells", []):
		learn(spell)
		_ranks[spell.id] = int(data.ranks.get(spell.id, 1))
		var b: Dictionary = data.bonus.get(spell.id, {})
		_bonus[spell.id] = {"damage": float(b.get("damage", 0.0)), "cooldown": float(b.get("cooldown", 0.0)),
			"targets": int(b.get("targets", 0))}
	damage_mult = float(data.get("damage_mult", 1.0))
	cooldown_mult = float(data.get("cooldown_mult", 1.0))


func _add_bonus(id: String, bonus: Dictionary) -> void:
	var b: Dictionary = _bonus[id]
	b.damage += float(bonus.get("damage", 0.0))
	b.cooldown += float(bonus.get("cooldown", 0.0))
	b.targets += int(bonus.get("targets", 0))


func _buff_mult() -> float:
	var m := 1.0
	for buff in _buffs:
		m += buff.damage
	return m


func _cast(id: String, origin: Variant, targets: Array) -> Dictionary:
	var s: Dictionary = _spells[id]
	var e := effective(id)
	var cast := {"spell": id, "hits": [], "heal": 0.0, "buff": {}, "dot": false}
	if s.has("buff"):
		var trigger: float = s.get("trigger_range", 0.0)
		if trigger > 0.0 and _in_range(origin, targets, trigger).is_empty():
			return {}
		_buffs.append({"spell": id, "damage": float(s.buff.get("damage", 0.0)), "left": float(s.buff.get("duration", 1.0))})
		cast.buff = s.buff
		if not s.has("damage") and not s.has("dot"):
			return cast
	if s.get("target", "nearest") == "self":
		return cast if not cast.buff.is_empty() else {}
	var chosen := _choose(s, origin, _in_range(origin, targets, e.range), e.targets)
	if chosen.is_empty():
		return {} if cast.buff.is_empty() else cast
	var dealt := 0.0
	for t: Dictionary in chosen:
		var amount: float = e.damage
		if s.has("execute_below") and _ratio(t) < float(s.execute_below):
			amount *= float(s.get("execute_mult", 2.0))
		var stun := 0.0
		if s.has("stun"):
			stun = float(s.stun) * (float(s.get("stun_boss_factor", 0.25)) if "boss" in t.get("tags", []) else 1.0)
		if amount > 0.0:
			cast.hits.append({"id": t.id, "damage": amount, "stun": stun})
			dealt += amount
		elif stun > 0.0 or s.has("dot"):  # a pure dot or stun still reports whom it landed on
			cast.hits.append({"id": t.id, "damage": 0.0, "stun": stun})
		if s.has("dot"):
			var ticks := maxi(1, int(s.dot.get("ticks", 1)))
			var total: float = float(s.dot.get("total", 0.0)) * (1.0 + _bonus[id].damage) * damage_mult * _buff_mult()
			var every: float = float(s.dot.get("duration", 1.0)) / ticks
			_dots.append({"spell": id, "id": t.id, "per_tick": total / ticks, "ticks": ticks, "every": every, "next": every})
	cast.heal = dealt * float(s.get("heal_ratio", 0.0))
	return cast if not cast.hits.is_empty() or not cast.buff.is_empty() else {}


func _choose(s: Dictionary, origin: Variant, pool: Array, count: int) -> Array:
	if s.get("unique_dot", false):
		var afflicted := {}
		for d in _dots:
			if d.spell == s.id:
				afflicted[d.id] = true
		pool = pool.filter(func(t: Dictionary) -> bool: return not afflicted.has(t.id))
	if pool.is_empty():
		return []
	var rule: String = s.get("target", "nearest")
	if rule == "all":
		return pool
	var ordered := pool.duplicate()
	match rule:
		"farthest":
			ordered.sort_custom(func(a, b) -> bool: return _dist(origin, a.pos) > _dist(origin, b.pos))
		"highest_hp":
			ordered.sort_custom(func(a, b) -> bool: return float(a.hp) > float(b.hp))
		"lowest_hp":
			ordered.sort_custom(func(a, b) -> bool: return float(a.hp) < float(b.hp))
		"random":
			for i in range(ordered.size() - 1, 0, -1):
				var j := _rng.randi_range(0, i)
				var tmp = ordered[i]
				ordered[i] = ordered[j]
				ordered[j] = tmp
		_:
			ordered.sort_custom(func(a, b) -> bool: return _dist(origin, a.pos) < _dist(origin, b.pos))
	# Priority tags first, then (for execute spells) targets under the threshold, keeping the rule's order inside.
	var keys: Array[int] = []
	var tags: Array = s.get("priority", [])
	for index in ordered.size():
		var t: Dictionary = ordered[index]
		var tag_rank := tags.size()
		for k in tags.size():
			if tags[k] in t.get("tags", []):
				tag_rank = k
				break
		var low := 0 if s.has("execute_below") and _ratio(t) < float(s.execute_below) else 1
		keys.append(tag_rank * 2_000_000 + low * 1_000_000 + index)  # index < 1e6 keeps the rule's order
	keys.sort()
	var out: Array = []
	for k in keys.slice(0, count):
		out.append(ordered[k % 1_000_000])
	return out


func _tick_dots(delta: float, targets: Array, casts: Array[Dictionary]) -> void:
	var alive := {}
	for t: Dictionary in targets:
		alive[t.id] = true
	var by_spell := {}
	for d in _dots:
		if not alive.has(d.id):
			d.ticks = 0
			continue
		d.next -= delta
		while d.next <= 0.0 and d.ticks > 0:
			d.ticks -= 1
			d.next += d.every
			if not by_spell.has(d.spell):
				by_spell[d.spell] = {"spell": d.spell, "hits": [], "heal": 0.0, "buff": {}, "dot": true}
			by_spell[d.spell].hits.append({"id": d.id, "damage": d.per_tick, "stun": 0.0})
	_dots = _dots.filter(func(d: Dictionary) -> bool: return d.ticks > 0)
	for cast in by_spell.values():
		casts.append(cast)


func _in_range(origin: Variant, targets: Array, radius: float) -> Array:
	return targets.filter(func(t: Dictionary) -> bool: return float(t.get("hp", 1.0)) > 0.0 and _dist(origin, t.pos) <= radius)


static func _ratio(t: Dictionary) -> float:
	return float(t.hp) / maxf(1.0, float(t.get("max_hp", t.hp)))


static func _dist(a: Variant, b: Variant) -> float:
	if a is Vector3 and b is Vector3:
		return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))  # ground distance, like the game's yards
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))
