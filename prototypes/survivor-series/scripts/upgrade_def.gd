class_name StreetUpgradeDefinition
extends Resource
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var category: String = "強化"
@export var accent: Color = Color("72e0c0")
@export_range(1, 8, 1) var max_stacks: int = 1
@export var prerequisite: StringName
@export var value: float = 0.0
