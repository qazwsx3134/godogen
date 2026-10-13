extends Node2D
## A cigarette-smoke cloud left by a smoker: a faint haze on the ground marks where it hurts, and soft
## puffs above it swell, drift upward and thin out. Puffs are the children of %Puffs, placed in the scene.
@export var lifetime: float = 3.8
@export var radius: float = 42.0
@export var damage: float = 4.0
## How far puffs rise and how much they swell over the cloud's life.
@export var rise: float = 18.0
@export var swell: float = 0.45
var age: float = 0.0
var _rest: Array = []
@onready var puffs: Node2D = %Puffs

func _ready() -> void:
	for puff: Node2D in puffs.get_children():
		_rest.append([puff.position, puff.scale])

func step(delta: float) -> void:
	age += delta
	var t: float = clampf(age / lifetime, 0.0, 1.0)
	modulate.a = minf(minf(1.0, age / 0.25), (lifetime - age) / 0.8)
	var i: int = 0
	for puff: Node2D in puffs.get_children():
		var phase: float = i * 1.7
		puff.position = _rest[i][0] + Vector2(sin(age * 1.3 + phase) * 4.0, -rise * t - sin(age * 2.1 + phase) * 2.0)
		puff.scale = _rest[i][1] * (1.0 + swell * t + sin(age * 2.6 + phase) * 0.05)
		i += 1
	if age >= lifetime:
		queue_free()
