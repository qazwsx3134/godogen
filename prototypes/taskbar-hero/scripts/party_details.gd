extends Control

@onready var hero_name: Label = %HeroName
@onready var role_label: Label = %RoleLabel
@onready var health_stat: Label = %HealthStat
@onready var attack_stat: Label = %AttackStat
@onready var defense_stat: Label = %DefenseStat
@onready var speed_stat: Label = %SpeedStat
@onready var attack_speed_stat: Label = %AttackSpeedStat
@onready var party_status: Label = %PartyStatus
@onready var _game_state: Node = get_node("/root/Game")
@onready var _data_registry: Node = get_node("/root/DataRegistry")

func _ready() -> void:
	_game_state.connect("gold_changed", _refresh_status)
	_game_state.connect("kills_changed", _refresh_status)
	_game_state.connect("combat_pause_changed", _on_pause_changed)
	_refresh_hero()
	_refresh_status()

func _refresh_hero() -> void:
	var hero: UnitData = _data_registry.call("playable_hero") as UnitData
	hero_name.text = hero.display_name
	role_label.text = hero.role_description
	health_stat.text = "生命　%d" % hero.max_health
	attack_stat.text = "攻擊　%d" % hero.attack
	defense_stat.text = "防禦　%d" % hero.defense
	speed_stat.text = "移動　%d" % roundi(hero.move_speed)
	attack_speed_stat.text = "攻擊速度　%.2f / 秒" % hero.attack_speed

func _refresh_status(_value: int = 0) -> void:
	party_status.text = "目前擊倒 %d 隻敵人，持有 %d 金幣。" % [int(_game_state.get("kills")), int(_game_state.get("gold"))]

func _on_pause_changed(paused: bool) -> void:
	if paused:
		party_status.text = "戰鬥暫停中  ·  騎士留守原地。"
	else:
		_refresh_status()
