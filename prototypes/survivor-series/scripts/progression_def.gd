extends Resource
@export_range(1, 30, 1) var first_level_xp: int = 5
@export_range(0, 10, 1) var level_xp_growth: int = 3
@export var first_choices: Array[StringName] = [&"wave", &"kick", &"sweep"]
@export var upgrades: Array[Resource] = []
