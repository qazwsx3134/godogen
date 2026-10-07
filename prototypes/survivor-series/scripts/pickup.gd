extends Node2D
## A drop on the street: XP gem, coin, food, magnet or chest. Street moves and collects it.
@export_enum("xp", "coin", "food", "magnet", "chest") var kind: String = "xp"
var value: float = 1.0
var attracted: bool = false
var pull: float = 0.0
var age: float = 0.0

func setup(drop_kind: String, amount: float) -> void:
	kind = drop_kind
	value = amount
	refresh()

func refresh() -> void:
	for child: Node in %Looks.get_children():
		child.visible = child.name == _look()

func _look() -> String:
	match kind:
		"xp":
			return "GemBig" if value >= 10.0 else ("GemMid" if value >= 3.0 else "Gem")
		"coin":
			return "Coin"
		"food":
			return "Food"
		"magnet":
			return "Magnet"
	return "Chest"

func add_value(amount: float) -> void:
	value += amount
	refresh()

func _process(delta: float) -> void:
	age += delta
	%Looks.position.y = -6.0 - sin(age * 5.0) * 3.0
