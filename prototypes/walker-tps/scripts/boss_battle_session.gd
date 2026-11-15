extends "res://scripts/battlefield.gd"
## Keep the Boss composition when the normal battlefield's Retry button is used.

func retry() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/boss_battlefield.tscn")
