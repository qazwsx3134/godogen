extends Node3D
## One pile of loot on the ground. Tapping it walks the player over; Main moves it into the bag.
## `taken` flips once, so two pickups of the same pile can never both succeed.

const Items = preload("res://scripts/items.gd")

@export var lifetime: float = 60.0

var item_id: String = ""
var count: int = 0
var taken: bool = false

@onready var gem: MeshInstance3D = %Gem
@onready var name_label: Label3D = %NameLabel

var _age: float = 0.0


func setup(id: String, amount: int) -> void:
	item_id = id
	count = amount


func _ready() -> void:
	add_to_group("loot")
	var def: Dictionary = Items.ALL.get(item_id, {"name": item_id, "color": Color.WHITE})
	name_label.text = def.name if count == 1 else "%s ×%d" % [def.name, count]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem.material_override = mat


func _process(delta: float) -> void:
	_age += delta
	gem.position.y = 0.35 + sin(_age * 3.0) * 0.08
	gem.rotate_y(delta * 2.0)
	if _age > lifetime and not taken:
		taken = true
		queue_free()
