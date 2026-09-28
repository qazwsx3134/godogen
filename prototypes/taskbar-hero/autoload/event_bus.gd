extends Node

signal enemy_killed(enemy_id: String, gold_reward: int)
signal unit_died(unit_id: String, faction: String)
signal unit_respawned(unit_id: String, faction: String)
signal unit_health_changed(unit_id: String, faction: String, current: int, maximum: int)
signal damage_dealt(source_id: String, target_id: String, amount: int, remaining: int, maximum: int)
