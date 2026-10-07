extends Resource
## Editable combat tuning; visual scenes keep their authored proportions.
@export_enum("smoker", "bike", "car", "fatty") var kind: String = "smoker"
@export var max_hp: float = 68.0
@export var speed: float = 42.0
@export var radius: float = 18.0
@export var weight: float = 1.0
@export_range(1, 10, 1) var experience: int = 1
@export var contact_damage: float = 6.0
@export var hazard_interval: float = 2.6
@export var warning_time: float = 0.85
@export var dash_speed: float = 520.0
@export var dash_time: float = 0.72
## Vehicles turn their art to the movement heading; people only flip left/right.
@export var turns: bool = false
@export_group("Stink")
## Hero moves at (1 - aura_slow) speed inside the aura.
@export var aura_radius: float = 0.0
@export var aura_slow: float = 0.0
## Fart on lethal launch: damages and launches nearby enemies.
@export var burst_radius: float = 0.0
@export var burst_damage: float = 0.0
