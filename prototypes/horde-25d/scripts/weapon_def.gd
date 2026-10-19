class_name WeaponDef
extends Resource
## An auto-firing weapon. Level 1 uses the base numbers; each level after that adds the *_per_level growth.

enum Kind { BOLT, AURA, ORBIT, NOVA }

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var kind: Kind = Kind.BOLT
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var amount: int = 1
## BOLT: projectile size; AURA / NOVA: radius in meters; ORBIT: orbit radius.
@export var area: float = 1.0
## BOLT: meters per second; ORBIT: radians per second.
@export var speed: float = 14.0
## BOLT: enemies one projectile can hit.
@export var pierce: int = 1
@export var knockback: float = 5.0
@export var color: Color = Color(0.5, 0.85, 1.0)
@export var max_level: int = 5
@export var damage_per_level: float = 0.3
@export var area_per_level: float = 0.1
@export var cooldown_per_level: float = 0.06
## Every this many levels adds one more projectile / orb.
@export var levels_per_amount: int = 2


func damage_at(level: int) -> float:
	return damage * (1.0 + damage_per_level * (level - 1))


func area_at(level: int) -> float:
	return area * (1.0 + area_per_level * (level - 1))


func cooldown_at(level: int) -> float:
	return cooldown * maxf(0.3, 1.0 - cooldown_per_level * (level - 1))


func amount_at(level: int) -> int:
	return amount + (level - 1) / maxi(levels_per_amount, 1)
