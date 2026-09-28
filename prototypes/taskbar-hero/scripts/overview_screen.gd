extends Control

@onready var stage_title: Label = %StageTitle
@onready var combat_totals: Label = %CombatTotals
@onready var combat_feedback: Label = %CombatFeedback
@onready var _game_state: Node = get_node("/root/Game")
@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	_game_state.connect("gold_changed", _refresh_totals)
	_game_state.connect("kills_changed", _refresh_totals)
	_game_state.connect("stage_changed", _on_stage_changed)
	_event_bus.connect("damage_dealt", _on_damage_dealt)
	_event_bus.connect("unit_died", _on_unit_died)
	_event_bus.connect("unit_respawned", _on_unit_respawned)
	_refresh_totals(int(_game_state.get("gold")))
	_on_stage_changed(str(_game_state.get("current_stage")))

func _refresh_totals(_value: int = 0) -> void:
	combat_totals.text = "擊倒 %d  ·  金幣 %d" % [int(_game_state.get("kills")), int(_game_state.get("gold"))]

func _on_stage_changed(stage: String) -> void:
	stage_title.text = "第 %s 區  ·  苔原邊境" % stage

func _on_damage_dealt(source_id: String, target_id: String, amount: int, remaining: int, maximum: int) -> void:
	var source_name: String = "騎士" if source_id == "knight" else "史萊姆"
	var target_name: String = "騎士" if target_id == "knight" else "史萊姆"
	combat_feedback.text = "%s 命中 %s  ·  -%d HP  ·  剩餘 %d / %d" % [source_name, target_name, amount, remaining, maximum]

func _on_unit_died(unit_id: String, _faction: String) -> void:
	var unit_name: String = "騎士" if unit_id == "knight" else "史萊姆"
	combat_feedback.text = "%s 倒下，正在準備重返戰場。" % unit_name

func _on_unit_respawned(unit_id: String, _faction: String) -> void:
	var unit_name: String = "騎士" if unit_id == "knight" else "史萊姆"
	combat_feedback.text = "%s 已重返戰場。" % unit_name
