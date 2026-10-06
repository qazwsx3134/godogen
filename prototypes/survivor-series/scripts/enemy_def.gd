extends Resource
## Editable combat tuning; visual scenes keep their authored proportions.
@export_enum("smoker", "bike", "car") var kind: String = "smoker"
@export var max_hp: float = 68.0
@export var speed: float = 42.0
@export var radius: float = 18.0
@export var weight: float = 1.0
@export_range(1, 10, 1) var experience: int = 1
@export var hazard_interval: float = 2.6
@export var warning_time: float = 0.85
@export var dash_speed: float = 520.0
@export var dash_time: float = 0.72
