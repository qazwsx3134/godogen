extends Node
## The one place where hits land: damage roll, crit, death XP. Player swings, the sweep skill and monster
## bites all call attack(); nothing else lowers HP. A non-zero rng_seed replays the same rolls (AC-S02-02).

signal hit_landed(attacker: Node3D, victim: Node3D, amount: int, crit: bool)

@export var rng_seed: int = 0
@export var crit_chance: float = 0.12

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()


## Returns the damage dealt, 0 when the victim is gone or already down (a stale swing lands nowhere).
func attack(attacker: Node3D, victim: Node3D, power: int, multiplier: float = 1.0, can_crit: bool = true) -> int:
	if not is_instance_valid(victim) or not victim.is_alive():
		return 0
	var crit: bool = can_crit and rng.randf() < crit_chance
	var amount: int = maxi(1, roundi((power + rng.randi_range(-2, 3)) * multiplier))
	if crit:
		amount *= 2
	victim.take_damage(amount, attacker, crit)
	hit_landed.emit(attacker, victim, amount, crit)
	if not victim.is_alive() and victim.is_in_group("monster") and is_instance_valid(attacker) \
			and attacker.has_method("gain_xp"):
		attacker.gain_xp(victim.xp_reward, victim.display_name)
	return amount
