extends Label

@onready var _game_state: Node = get_node("/root/Game")
@onready var _save_manager: Node = get_node("/root/SaveManager")

func _ready() -> void:
	_game_state.connect("combat_pause_changed", _on_pause_changed)
	_save_manager.connect("save_completed", _on_save_completed)
	var warning: String = str(_save_manager.get("last_load_message"))
	if not warning.is_empty():
		text = warning
	elif bool(_game_state.get("combat_paused")):
		text = "戰鬥已暫停"
	else:
		text = "自動戰鬥進行中  ·  Stage 1-1 持續挑戰"

func _on_pause_changed(paused: bool) -> void:
	if not str(_save_manager.get("last_load_message")).is_empty():
		return
	text = "戰鬥已暫停" if paused else "自動戰鬥進行中  ·  Stage 1-1 持續挑戰"

func _on_save_completed(success: bool, message: String) -> void:
	text = message if not success or str(_save_manager.get("last_load_message")).is_empty() else str(_save_manager.get("last_load_message"))
