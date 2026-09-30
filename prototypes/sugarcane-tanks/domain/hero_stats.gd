extends RefCounted
## The hero's numbers for one run: base stats, picked ability stacks, level and EXP.
## Pure logic so tests can check the Archero-style stacking rules without a scene tree.

const BASE_ATTACK: float = 50.0
const BASE_ATTACK_INTERVAL: float = 0.8
const BASE_MAX_HP: int = 600
const BASE_CRIT_CHANCE: float = 0.05
const CRIT_MULTIPLIER: float = 2.0
const FRONT_SPACING: float = 30.0

## Per-stack penalties: more projectiles, less damage each.
const FRONT_DAMAGE_FACTOR: float = 0.75
const MULTISHOT_DAMAGE_FACTOR: float = 0.85
const PIERCE_DAMAGE_FACTOR: float = 0.67
const RICOCHET_DAMAGE_FACTOR: float = 0.7

var stacks: Dictionary = {}   # StringName -> int
var level: int = 1
var experience: int = 0
var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP

func count(id: StringName) -> int:
	return int(stacks.get(id, 0))

## Applies one pick. Instant effects (heal, HP boost) change hp right away.
func add_ability(id: StringName) -> void:
	stacks[id] = count(id) + 1
	match id:
		&"hp_boost":
			var gain: int = int(round(BASE_MAX_HP * 0.2))
			max_hp += gain
			hp += gain
		&"heal":
			heal(int(round(max_hp * 0.4)))

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)

## Returns the damage actually taken.
func take_damage(amount: int) -> int:
	var taken: int = mini(hp, amount)
	hp -= taken
	return taken

func attack() -> float:
	return BASE_ATTACK * (1.0 + 0.2 * count(&"attack_boost"))

func attack_interval() -> float:
	return BASE_ATTACK_INTERVAL / (1.0 + 0.2 * count(&"attack_speed"))

func crit_chance() -> float:
	return BASE_CRIT_CHANCE + 0.1 * count(&"crit")

## Damage of one projectile before crit, after the stacking penalties.
func projectile_damage() -> float:
	var damage: float = attack()
	damage *= pow(FRONT_DAMAGE_FACTOR, count(&"front"))
	damage *= pow(MULTISHOT_DAMAGE_FACTOR, count(&"multishot"))
	return damage

## Volleys per attack: the first plus one per multishot stack, fired back to back.
func volleys() -> int:
	return 1 + count(&"multishot")

## Every projectile of one volley, relative to the aim direction:
## `angle` in radians, `offset` sideways in pixels.
func volley_pattern() -> Array[Dictionary]:
	var shots: Array[Dictionary] = []
	var front: int = 1 + count(&"front")
	for i: int in front:
		shots.append({"angle": 0.0, "offset": (i - (front - 1) * 0.5) * FRONT_SPACING})
	if count(&"diagonal") > 0:
		shots.append({"angle": deg_to_rad(45.0), "offset": 0.0})
		shots.append({"angle": deg_to_rad(-45.0), "offset": 0.0})
	if count(&"side") > 0:
		shots.append({"angle": deg_to_rad(90.0), "offset": 0.0})
		shots.append({"angle": deg_to_rad(-90.0), "offset": 0.0})
	if count(&"rear") > 0:
		shots.append({"angle": PI, "offset": 0.0})
	return shots

func pierces() -> bool:
	return count(&"pierce") > 0

func ricochets() -> int:
	return 3 * count(&"ricochet")

func wall_bounces() -> int:
	return 2 * count(&"wall_bounce")

func burns() -> bool:
	return count(&"fire") > 0

func freezes() -> bool:
	return count(&"freeze") > 0

static func exp_to_next(at_level: int) -> int:
	return 6 + at_level * 4

## Adds EXP and returns how many levels were gained.
func gain_exp(amount: int) -> int:
	experience += amount
	var gained: int = 0
	while experience >= exp_to_next(level):
		experience -= exp_to_next(level)
		level += 1
		gained += 1
	return gained

## Three distinct cards the hero can still take. `defs` are AbilityDef resources.
func draw_choices(defs: Array, rng: RandomNumberGenerator, amount: int = 3) -> Array:
	var pool: Array = []
	for def: Resource in defs:
		if count(def.id) >= def.max_stacks:
			continue
		if def.needs_missing_hp and hp >= max_hp:
			continue
		pool.append(def)
	var picks: Array = []
	while picks.size() < amount and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		picks.append(pool[index])
		pool.remove_at(index)
	return picks
