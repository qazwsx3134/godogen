extends "res://addons/proto_kit/test_kit.gd"
## The shipped (subset) font has a glyph for every character the game writes: the web build has no system font.

const FontCheck = preload("res://addons/proto_kit/font_check.gd")


func _init() -> void:
	var missing: String = FontCheck.missing_characters(load("res://assets/fonts/NotoSansTC.otf"))
	_expect(missing.is_empty(), "font covers every character (missing: %s; rerun subset_font.py)" % missing)
	_finish("FONT")
