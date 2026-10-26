extends "res://addons/proto_kit/test_kit.gd"
const FontCheck = preload("res://addons/proto_kit/font_check.gd")


func _init() -> void:
	var font: Font = load("res://assets/fonts/NotoSansTC.otf")
	var missing: String = FontCheck.missing_characters(font)
	_expect(missing.is_empty(), "packaged font covers game text: " + missing)
	_finish("DREAMLING FONT")
