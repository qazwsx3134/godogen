extends Button
signal chosen(id: StringName)
@export var definition: Resource
var id: StringName
@onready var title_label: Label = %Title
@onready var body_label: Label = %Description
@onready var tag_label: Label = %Tag
@onready var stripe: ColorRect = %Stripe

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(id))
	if definition != null:
		setup(definition, 0)

func setup(item: Resource, current_stacks: int) -> void:
	definition = item
	id = item.id
	title_label.text = item.title
	body_label.text = item.description
	tag_label.text = "%s  ·  %d / %d" % [item.category, current_stacks + 1, item.max_stacks]
	stripe.color = item.accent
