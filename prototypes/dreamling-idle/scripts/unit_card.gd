extends PanelContainer
signal inspected(id: String)
signal deployment_requested(id: String)
@export var definition_id: String = "moss"
@onready var portrait: TextureRect = %Portrait
@onready var title: Label = %CardName
@onready var subtitle: Label = %CardRole
@onready var stats_label: Label = %CardStats
@onready var xp: ProgressBar = %CardXP
@onready var deploy: Button = %Deploy


func _ready() -> void:
	%Inspect.pressed.connect(func() -> void: inspected.emit(definition_id))
	deploy.pressed.connect(func() -> void: deployment_requested.emit(definition_id))


func refresh(game: RefCounted, selected: String) -> void:
	var definition: Dictionary = game.catalog.units[definition_id]
	var owned: bool = game.state.roster.has(definition_id)
	var active: bool = definition_id in game.state.deployed
	var progress: Dictionary = game.state.roster.get(definition_id, {"level": 1, "xp": 0})
	title.text = "%s  Lv.%d" % [definition.name, progress.level] if owned else str(definition.name)
	subtitle.text = "%s · %s" % [definition.race_name, definition.job_name]
	portrait.modulate = Color(definition.color) if owned else Color(0.35, 0.38, 0.45)
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/%s.png" % definition.art)
	atlas.region = Rect2(0, 80, 512, 432)
	portrait.texture = atlas
	if owned:
		var values: Dictionary = game.stats(definition_id)
		stats_label.text = "攻 %d  ·  血 %d" % [roundi(values.attack), roundi(values.hp)]
		xp.max_value = game.xp_needed(int(progress.level))
		xp.value = progress.xp
	else:
		stats_label.text = "通關 %d 關後可招募" % int(definition.unlock)
		xp.value = 0
	deploy.text = "撤下" if active else ("上陣" if owned else "未同行")
	deploy.disabled = not owned
	theme_type_variation = &"SelectedCard" if selected == definition_id else &"Card"
	%Inspect.text = "已選中" if selected == definition_id else "查看"
	tooltip_text = definition.description
