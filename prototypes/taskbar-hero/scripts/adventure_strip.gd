extends PanelContainer

@onready var stage_label: Label = %StripStage
@onready var totals_label: Label = %StripTotals
@onready var combat_status: Label = %StripCombatStatus
@onready var knight_health: ProgressBar = %StripKnightHealth
@onready var slime_health: ProgressBar = %StripSlimeHealth
@onready var knight_health_text: Label = %StripKnightHealthText
@onready var slime_health_text: Label = %StripSlimeHealthText
@onready var _game_state: Node = get_node("/root/Game")
@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	_game_state.connect("gold_changed", _refresh_totals)
	_game_state.connect("kills_changed", _refresh_totals)
	_game_state.connect("stage_changed", _on_stage_changed)
	_event_bus.connect("unit_health_changed", _on_unit_health_changed)
	_event_bus.connect("damage_dealt", _on_damage_dealt)
	_event_bus.connect("unit_died", _on_unit_died)
	_event_bus.connect("unit_respawned", _on_unit_respawned)
	_refresh_totals()
	_on_stage_changed(str(_game_state.get("current_stage")))
	_sync_current_health()

func _refresh_totals(_value: int = 0) -> void:
	totals_label.text = "擊倒 %d  ·  金幣 %d" % [int(_game_state.get("kills")), int(_game_state.get("gold"))]

func _on_stage_changed(stage: String) -> void:
	stage_label.text = "遠征紀錄  ·  第 %s 區" % stage

func _sync_current_health() -> void:
	for candidate: Node in get_tree().get_nodes_in_group("combat_units"):
		var unit: CombatUnit = candidate as CombatUnit
		if unit == null or unit.unit_data == null:
			continue
		_on_unit_health_changed(unit.unit_data.unit_id, unit.faction, unit.current_health, unit.unit_data.max_health)

func _on_unit_health_changed(unit_id: String, faction: String, current: int, maximum: int) -> void:
	if unit_id == "knight" or faction == "hero":
		knight_health.max_value = maximum
		knight_health.value = current
		knight_health_text.text = "騎士  %d / %d" % [current, maximum]
	elif unit_id == "slime" or faction == "enemy":
		slime_health.max_value = maximum
		slime_health.value = current
		slime_health_text.text = "史萊姆  %d / %d" % [current, maximum]

func _on_damage_dealt(source_id: String, target_id: String, amount: int, remaining: int, maximum: int) -> void:
	var source_name: String = "騎士" if source_id == "knight" else "史萊姆"
	var target_name: String = "騎士" if target_id == "knight" else "史萊姆"
	combat_status.text = "%s 命中 %s  ·  -%d HP  ·  %d / %d" % [source_name, target_name, amount, remaining, maximum]

func _on_unit_died(unit_id: String, _faction: String) -> void:
	var unit_name: String = "騎士" if unit_id == "knight" else "史萊姆"
	combat_status.text = "%s 倒下  ·  短暫休整後重返戰場" % unit_name

func _on_unit_respawned(unit_id: String, _faction: String) -> void:
	var unit_name: String = "騎士" if unit_id == "knight" else "史萊姆"
	combat_status.text = "%s 已重返戰場" % unit_name
