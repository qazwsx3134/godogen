class_name UpgradeCard
extends Button
## One level-up choice. The look (StyleBox, fonts, sizes) is authored in upgrade_card.tscn; this only fills the text.

@onready var _title: Label = %Title
@onready var _level: Label = %Level
@onready var _desc: Label = %Desc


func show_option(option: Dictionary) -> void:
	var def: Resource = option.get("weapon", option.get("passive"))
	_title.text = def.title
	var level: int = option.level
	if level == 1:
		_level.text = "NEW" if option.has("weapon") else "新被動"
	else:
		_level.text = "Lv.%d → %d" % [level - 1, level]
	_desc.text = def.description
