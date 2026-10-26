extends RefCounted
## In-run chests bought with gold: every opening costs more than the last, and each one gives a random reward from a
## weighted pool. Gold never piles up uselessly, and the rising price caps how much it buys in one run.
## `const ChestShop = preload("res://addons/proto_kit/chest_shop.gd")`
##
##   var chests := ChestShop.new([{"id": "potion", "weight": 5}, {"id": "tome", "weight": 1, "max": 2}], rng,
##       {"base": 20, "growth": 1.5})
##   hud.chest_label = str(chests.price())       # "20", then 30, 45, 68...
##   var r := chests.open(gold)                   # {"ok", "spent", "gold" (what is left), "reward" (pool entry)}
##   if r.ok: gold = r.gold; give(r.reward.id)
##   chests.reset()                               # a new run: price back to base, per-run limits cleared
##
## Price of the n-th opening (n from 0): round(base x growth^n + step x n), capped at max_price when that is > 0.
## Pool entry: {id, weight (1), max (openings per run that may give it; 0 = no limit)}. A failed open (not enough gold,
## or nothing left to give) changes nothing.

var opened: int = 0

var _pool: Array[Dictionary] = []
var _given: Dictionary = {}   # id -> times this run
var _base: float
var _growth: float
var _step: float
var _max_price: int
var _rng: RandomNumberGenerator


func _init(pool: Array[Dictionary], rng: RandomNumberGenerator, options: Dictionary = {}) -> void:
	_pool = pool
	_rng = rng
	_base = float(options.get("base", 20.0))
	_growth = float(options.get("growth", 1.5))
	_step = float(options.get("step", 0.0))
	_max_price = int(options.get("max_price", 0))


## What the next chest costs (or the n-th, counted from 0).
func price(n: int = -1) -> int:
	var k := opened if n < 0 else n
	var p := roundi(_base * pow(_growth, k) + _step * k)
	return mini(p, _max_price) if _max_price > 0 else p


func can_open(gold: int) -> bool:
	return gold >= price() and not _available().is_empty()


func open(gold: int) -> Dictionary:
	var cost := price()
	var pool := _available()
	if gold < cost or pool.is_empty():
		return {"ok": false, "spent": 0, "gold": gold, "reward": {}}
	var total := 0.0
	for entry: Dictionary in pool:
		total += float(entry.get("weight", 1.0))
	var pick := _rng.randf() * total
	var reward: Dictionary = pool[-1]
	for entry: Dictionary in pool:
		pick -= float(entry.get("weight", 1.0))
		if pick < 0.0:
			reward = entry
			break
	_given[reward.id] = _given.get(reward.id, 0) + 1
	opened += 1
	return {"ok": true, "spent": cost, "gold": gold - cost, "reward": reward}


func reset() -> void:
	opened = 0
	_given.clear()


func to_dict() -> Dictionary:
	# The RNG state is a 64-bit int: as a JSON number it would lose bits, so it is saved as text.
	return {"opened": opened, "given": _given.duplicate(), "rng_state": str(_rng.state)}


func from_dict(data: Dictionary) -> void:
	opened = int(data.get("opened", 0))
	_given.clear()
	var given: Dictionary = data.get("given", {})
	for id in given:
		_given[id] = int(given[id])
	if data.has("rng_state"):
		_rng.state = String(data.rng_state).to_int()


func _available() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _pool:
		var cap := int(e.get("max", 0))
		if float(e.get("weight", 1.0)) > 0.0 and (cap <= 0 or _given.get(e.id, 0) < cap):
			out.append(e)
	return out
