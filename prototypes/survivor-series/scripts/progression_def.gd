extends Resource
## Level curve and card catalogue for one run.
@export_range(1, 30, 1) var first_level_xp: int = 5
@export_range(0, 30, 1) var level_xp_growth: int = 6
## Extra growth per level after `late_level`, so late levels slow down.
@export_range(0, 30, 1) var late_xp_growth: int = 4
@export var late_level: int = 20
@export var start_weapon: StringName = &"punch"
@export var weapon_slots: int = 6
@export var passive_slots: int = 6
@export var items: Array[Resource] = []
## Offered when every weapon and passive is maxed.
@export var fillers: Array[Resource] = []
