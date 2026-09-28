extends Node

signal rewards_awarded(kill_count: int, gold_total: int)

@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _game: Node = get_node("/root/Game")

func _ready() -> void:
	_event_bus.connect("enemy_killed", _on_enemy_killed)

func _on_enemy_killed(_enemy_id: String, gold_reward: int) -> void:
	_game.call("add_kill_reward", gold_reward)
	rewards_awarded.emit(int(_game.get("kills")), int(_game.get("gold")))
