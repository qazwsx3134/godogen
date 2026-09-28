extends Resource
class_name UnitData

@export var unit_id: String = "unit"
@export var display_name: String = "單位"
@export var role_description: String = ""
@export_enum("hero", "enemy") var faction: String = "hero"
@export_range(1, 9999, 1) var max_health: int = 50
@export_range(0, 9999, 1) var attack: int = 10
@export_range(0, 999, 1) var defense: int = 0
@export_range(0.0, 600.0, 1.0) var move_speed: float = 60.0
@export_range(0.1, 10.0, 0.05) var attack_speed: float = 1.0
@export_range(1.0, 200.0, 1.0) var attack_range: float = 54.0
@export_range(0, 99999, 1) var gold_reward: int = 0
@export_range(0.1, 30.0, 0.1) var respawn_delay: float = 2.0
