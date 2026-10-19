class_name PassiveDef
extends Resource
## A stat boost picked on level-up. Each level adds `per_level` to its stat (a fraction for multipliers).

enum Stat { MIGHT, HASTE, AREA, SPEED, MAGNET, MAX_HP, REGEN }

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var stat: Stat = Stat.MIGHT
@export var per_level: float = 0.1
@export var max_level: int = 5
