extends HBoxContainer
## One line of a 推王戰報 board: rank, hero name, value. Layout, font sizes and colours are in report_row.tscn.

@onready var _rank: Label = %Rank
@onready var _name: Label = %HeroName
@onready var _value: Label = %Value


func show_row(rank: int, hero_name: String, value: String) -> void:
	_rank.text = "%d" % rank
	_name.text = hero_name
	_value.text = value
	visible = true
