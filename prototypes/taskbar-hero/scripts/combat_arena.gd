extends Node2D

@export var arena_frame_size: Vector2 = Vector2(360, 108)
@onready var knight: CombatUnit = %KnightUnit
@onready var slime: CombatUnit = %SlimeUnit
@onready var battle_camera: Camera2D = %BattleCamera

func _ready() -> void:
	var token: int = get_instance_id()
	for unit: CombatUnit in live_units():
		unit.arena_token = token
	if get_viewport() is SubViewport:
		get_viewport().size_changed.connect(_fit_camera)
		_fit_camera()
	else:
		battle_camera.enabled = false

func _fit_camera() -> void:
	# Fit the authored world as a whole; actor coordinates and combat ranges stay intact.
	var available: Vector2 = get_viewport_rect().size
	var ratio: float = minf(available.x / maxf(arena_frame_size.x, 1.0), available.y / maxf(arena_frame_size.y, 1.0))
	battle_camera.zoom = Vector2.ONE * maxf(ratio, 0.01)

func live_units() -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	if is_instance_valid(knight):
		result.append(knight)
	if is_instance_valid(slime):
		result.append(slime)
	return result
