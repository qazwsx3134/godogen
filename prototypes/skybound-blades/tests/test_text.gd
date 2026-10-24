extends "res://addons/proto_kit/test_kit.gd"
## Every character the game can write has a glyph in the shipped font (a web build has no
## system font: a missing glyph is a blank box on the player's screen).

const FontCheck = preload("res://addons/proto_kit/font_check.gd")


func _init() -> void:
	test_text_font_has_every_written_character()
	_finish("TEXT")


func test_text_font_has_every_written_character() -> void:
	var report: Dictionary = FontCheck.missing_report(load("res://assets/fonts/NotoSansTC.ttf"))
	var lines := PackedStringArray()
	for c: String in report:
		lines.append("%s U+%04X (%s)" % [c, c.unicode_at(0), report[c]])
	_expect(report.is_empty(), "font: no missing glyphs\n  " + "\n  ".join(lines))
