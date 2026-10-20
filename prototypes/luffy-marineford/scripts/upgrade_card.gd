class_name UpgradeCard
extends Button
## One level-up choice. The look (StyleBox, fonts, sizes) is authored in upgrade_card.tscn; this only fills the text.

@export var new_jutsu_color: Color = Color(0.86, 0.2, 0.22)
@export var upgrade_color: Color = Color(0.85, 0.45, 0.1)
@export var passive_color: Color = Color(0.25, 0.45, 0.75)

@onready var _title: Label = %Title
@onready var _level: Label = %Level
@onready var _desc: Label = %Desc


func show_option(option: Dictionary) -> void:
	var level: int = option.level
	if option.has("jutsu"):
		var def: JutsuDef = option.jutsu
		_title.text = def.title
		_desc.text = def.text_for(level)
		_tag("新忍術" if level == 1 else "忍術 Lv.%d → %d" % [level - 1, level], new_jutsu_color if level == 1 else upgrade_color)
	else:
		var def: PassiveDef = option.passive
		_title.text = def.title
		_desc.text = def.description
		_tag("被動 Lv.%d" % level, passive_color)


func _tag(text: String, color: Color) -> void:
	_level.text = text
	_level.add_theme_color_override(&"font_color", color)
