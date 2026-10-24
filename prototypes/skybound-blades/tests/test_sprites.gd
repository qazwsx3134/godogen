extends "res://addons/proto_kit/test_kit.gd"
## Every character sheet passes the sprite check (addons/proto_kit/sprite_check.gd): cells inside the atlas, no empty
## frame, no art on a cell edge, feet on the foot line and steady across frames. Look at a failure with
##   godot --path . res://addons/proto_kit/sprite_inspector.tscn -- --sheet <sheet>

const SpriteCheck = preload("res://addons/proto_kit/sprite_check.gd")
const SHEETS := ["leader", "guardian", "support", "meadow_slime", "briar_boar", "ruin_hound"]


func _init() -> void:
	for id: String in SHEETS:
		test_sprites_sheet_is_clean(id)
	_finish("SPRITES")


func test_sprites_sheet_is_clean(id: String) -> void:
	var issues := SpriteCheck.check_sheet(load("res://resources/sheets/%s.tres" % id))
	var lines := PackedStringArray()
	for i: Dictionary in issues:
		lines.append("%s %s dir %d frame %d: %s" % [i.level, i.anim, i.dir, i.frame, i.text])
	_expect(issues.is_empty(), "sprites: %s has no issues\\n  %s" % [id, "\\n  ".join(lines)])
