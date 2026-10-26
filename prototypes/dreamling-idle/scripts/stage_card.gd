extends PanelContainer
signal travel_requested(index: int)
@export var stage_index: int = 0


func _ready() -> void:
	%Travel.pressed.connect(func() -> void: travel_requested.emit(stage_index))


func refresh(game: RefCounted) -> void:
	var definition: Dictionary = game.catalog.stages[stage_index]
	var unlocked: bool = stage_index <= int(game.state.best_stage) + 1
	var current: bool = stage_index == int(game.state.stage)
	%StageNumber.text = "01 — %02d" % (stage_index + 1)
	%StageName.text = definition.name
	%StageDescription.text = definition.subtitle
	%StageReward.text = "擊殺 %d 金／%d EXP  ·  %s" % [definition.gold, definition.xp, "首領出沒" if definition.boss else "三波遭遇"]
	%Travel.text = "正在探索" if current else ("回來刷寶" if stage_index in game.state.cleared else ("前往挑戰" if unlocked else "前關通過後解鎖"))
	%Travel.disabled = not unlocked or current
	theme_type_variation = &"SelectedCard" if current else &"Card"
	modulate.a = 1.0 if unlocked else 0.55
