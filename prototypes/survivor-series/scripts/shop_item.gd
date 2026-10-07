extends Button
## One permanent upgrade in the shop.
@export var definition: Resource

func _ready() -> void:
	if definition != null:
		setup(definition, 0, definition.cost(0), 0)

func setup(entry: Resource, level: int, cost: int, wallet: int) -> void:
	definition = entry
	%Title.text = entry.title
	%Description.text = entry.description
	%Level.text = "Lv.%d / %d" % [level, entry.max_level]
	%Cost.text = "已滿級" if cost < 0 else "%d 金幣" % cost
	disabled = cost < 0 or wallet < cost
