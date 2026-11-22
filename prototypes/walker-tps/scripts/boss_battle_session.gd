extends "res://scripts/battlefield.gd"
## Include the Boss in the objective and retain this composition on Retry.

func _ready() -> void:
	super()
	objective_name = "TARGETS"
	var boss: Node = get_parent().get_node("Boss")
	total += 1
	boss.destroyed.connect(_enemy_destroyed)

func start_match() -> void:
	super()
	if match_state == "playing": get_parent().get_node("Boss").active = true

func finish(result: String) -> void:
	super(result)
	get_parent().get_node("Boss").active = false
