class_name StreetShopItem
extends Resource
## A permanent upgrade bought with coins between runs. Adds per_level × level to `stat`.
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var stat: StringName
@export var per_level: float = 0.05
@export_range(1, 10, 1) var max_level: int = 5
@export var base_cost: int = 100
@export var cost_growth: float = 1.5

func cost(current_level: int) -> int:
	return int(round(base_cost * pow(cost_growth, current_level)))
