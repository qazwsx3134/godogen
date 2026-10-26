extends RefCounted
## A companion pet you keep alive and raise (Seal Online style): its hunger drains while you are out in the field,
## it asks for a food it wants, feeding gives XP by the item's worth (more for the wanted food), it climbs levels
## +0..+9 inside a stage, and at +9 with full XP it can try to evolve with materials into a type that sets its stats.
## Starving costs XP and refills the bar; starving with under 2 % XP left, the pet runs away.
## `const PetCare = preload("res://addons/proto_kit/pet_care.gd")`
##
##   var pet := PetCare.new({"egg": "seed", "foods": ["apple", "fish", "bread"]}, rng)
##   for e in pet.tick(delta, in_town): ...       # "hungry" (with e.wants), "starved", "ran_away"
##   pet.feed({"id": "apple", "price": 45})        # -> {"xp", "level_up", "wanted"}
##   pet.feed({"id": "dusk_shield", "price": 5000, "kind": "equipment"})
##   if pet.can_evolve(): pet.evolve(["herb", "feather"], recipes)   # -> {"ok", "type", "rare"}
##   pet.stats()                                   # the type's stats x stage
##
## XP needs (Seal Online's pet table): each stage uses a group whose first level costs base (30, 60, 120 ... doubling
## through group G, then 5000, 5200, 8200); every level after costs 10 % of base more. Spare XP does not roll over.
## Feeding XP from the sell price: < 15 → 1; < 80 → price / 15 + 1; else price / 20 + 2; equipment price / 1500 + 3.

const GROUP_BASE: Array[int] = [30, 60, 120, 240, 480, 960, 1920, 5000, 5200, 8200, 10000, 20400]
## Group index per stage (1..7) for each egg kind.
const EGG_GROUPS := {
	"seed": [0, 1, 2, 3, 7, 8, 9],
	"heaven": [1, 2, 3, 4, 7, 8, 9],
	"piya": [2, 3, 4, 5, 7, 8, 9],
	"bird": [3, 4, 5, 6, 7, 8, 9],
}

var egg: String
var stage: int = 1
var level: int = 0
var xp: int = 0
var hunger: float = 1.0
var type: String = ""
var rare: bool = false
var alive: bool = true
var wants: String = ""

var _drain: float
var _hungry_below: float
var _feed_refill: float
var _play_refill: float
var _wanted_mult: float
var _starve_xp: float
var _max_stage: int
var _foods: Array
var _types: Dictionary
var _asked: bool = false
var _rng: RandomNumberGenerator


## options: egg, foods (what it may ask for), drain (hunger lost per second, 1 / 600), hungry_below (0.66),
## feed_refill (0.35), play_refill (0.08), wanted_mult (XP x for the wanted food, 2.0), starve_xp (share of the level's
## need lost when hunger hits zero, 0.2), max_stage (7), types ({type: {stat: per stage}}).
func _init(options: Dictionary, rng: RandomNumberGenerator) -> void:
	_rng = rng
	egg = options.get("egg", "seed")
	_foods = options.get("foods", [])
	_drain = float(options.get("drain", 1.0 / 600.0))
	_hungry_below = float(options.get("hungry_below", 0.66))
	_feed_refill = float(options.get("feed_refill", 0.35))
	_play_refill = float(options.get("play_refill", 0.08))
	_wanted_mult = float(options.get("wanted_mult", 2.0))
	_starve_xp = float(options.get("starve_xp", 0.2))
	_max_stage = int(options.get("max_stage", 7))
	_types = options.get("types", {})


## XP needed from the current level to the next (at +9: to reach 100 % and be ready to evolve).
func xp_to_next() -> int:
	var groups: Array = EGG_GROUPS.get(egg, EGG_GROUPS.seed)
	var base := GROUP_BASE[groups[clampi(stage - 1, 0, groups.size() - 1)]]
	return base + base * level / 10


func is_hungry() -> bool:
	return hunger < _hungry_below


## Hunger only drains in the field (towns pause the pet: no hunger, no growth, no death).
func tick(delta: float, in_town: bool = false) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not alive or in_town:
		return events
	hunger = maxf(0.0, hunger - _drain * delta)
	if is_hungry() and not _asked:
		_asked = true
		if not _foods.is_empty():
			wants = String(_foods[_rng.randi_range(0, _foods.size() - 1)])
		events.append({"type": "hungry", "wants": wants})
	if hunger <= 0.0:
		# Empty bar: XP is lost and the bar refills; with under 2 % XP left there is nothing to lose and it runs away.
		if xp < xp_to_next() * 0.02:
			alive = false
			events.append({"type": "ran_away"})
			return events
		var loss := int(ceil(xp_to_next() * _starve_xp))
		xp = maxi(0, xp - loss)
		hunger = 1.0
		_asked = false
		events.append({"type": "starved", "xp_lost": loss})
	return events


static func food_xp(item: Dictionary) -> int:
	var price := int(item.get("price", 0))
	if item.get("kind", "item") == "equipment":
		return price / 1500 + 3
	if price < 15:
		return 1
	if price < 80:
		return price / 15 + 1
	return price / 20 + 2


func feed(item: Dictionary) -> Dictionary:
	if not alive:
		return {"xp": 0, "level_up": false, "wanted": false}
	var wanted: bool = wants != "" and item.get("id", "") == wants
	var gain := food_xp(item) * (_wanted_mult if wanted else 1.0)
	hunger = minf(1.0, hunger + _feed_refill)
	if not is_hungry():
		_asked = false
		wants = ""
	var level_up := _gain(int(gain))
	return {"xp": int(gain), "level_up": level_up, "wanted": wanted}


## Playing keeps hunger up a little and gives no XP.
func play() -> void:
	hunger = minf(1.0, hunger + _play_refill)


## Unequipping and equipping again loses the XP of the current level (the level stays).
func reequip() -> void:
	xp = 0


func can_evolve() -> bool:
	return alive and level >= 9 and xp >= xp_to_next() and stage < _max_stage


## recipes: [{"materials": [...], "chance": 0.8, "types": {type: weight}, "rare": 0.05}]. The first recipe whose
## materials are all given is used; with none, a poor fallback (chance 0.2, the type stays). On failure the pet keeps
## its stage and must fill its XP again.
func evolve(materials: Array, recipes: Array) -> Dictionary:
	if not can_evolve():
		return {"ok": false, "type": type, "rare": rare}
	var recipe := {"chance": 0.2, "types": {type: 1.0} if type != "" else {"plain": 1.0}, "rare": 0.0}
	for r: Dictionary in recipes:
		if r.materials.all(func(m) -> bool: return m in materials):
			recipe = r
			break
	if _rng.randf() >= float(recipe.chance):
		xp = 0
		return {"ok": false, "type": type, "rare": rare}
	stage += 1
	level = 0
	xp = 3  # Seal Online gives 3 XP on every level up and evolution
	type = _weighted(recipe.types)
	rare = _rng.randf() < float(recipe.get("rare", 0.0))
	return {"ok": true, "type": type, "rare": rare}


## The type's per-stage stats x stage (x1.5 when rare).
func stats() -> Dictionary:
	var out := {}
	var per: Dictionary = _types.get(type, {})
	for stat in per:
		out[stat] = float(per[stat]) * stage * (1.5 if rare else 1.0)
	return out


func to_dict() -> Dictionary:
	return {"egg": egg, "stage": stage, "level": level, "xp": xp, "hunger": hunger, "type": type, "rare": rare,
		"alive": alive, "wants": wants}


func from_dict(data: Dictionary) -> void:
	egg = data.get("egg", egg)
	stage = int(data.get("stage", 1))
	level = int(data.get("level", 0))
	xp = int(data.get("xp", 0))
	hunger = float(data.get("hunger", 1.0))
	type = data.get("type", "")
	rare = bool(data.get("rare", false))
	alive = bool(data.get("alive", true))
	wants = data.get("wants", "")
	_asked = wants != ""


func _gain(amount: int) -> bool:
	var leveled := false
	xp += amount
	while level < 9 and xp >= xp_to_next():
		xp = 3  # spare XP does not roll over; a level up grants 3
		level += 1
		leveled = true
	if level >= 9:
		xp = mini(xp, xp_to_next())
	return leveled


func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := _rng.randf() * total
	for k in weights:
		pick -= float(weights[k])
		if pick < 0.0:
			return String(k)
	return String(weights.keys()[-1])
