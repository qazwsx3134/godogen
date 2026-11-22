## One-time authoring tool. Stage new bakes outside the project before replacing assets.
extends SceneTree

const Geometry = preload("res://tools/betta_geometry.gd")
const ASSETS := "res://assets/"


func _initialize() -> void:
	if FileAccess.file_exists(ASSETS + "betta_body.res"):
		push_error("Existing betta assets. Bake in a separate project copy to compare revisions.")
		quit(1)
		return
	var meshes := {
		"betta_body": Geometry.body(),
		"tail_short": Geometry.short_tail(),
		"tail_long": Geometry.long_tail(),
		"dorsal": Geometry.dorsal(),
		"anal": Geometry.anal(),
		"pectoral_near": Geometry.pectoral(1.0),
		"pectoral_far": Geometry.pectoral(-1.0),
	}
	for part in meshes:
		if ResourceSaver.save(meshes[part], ASSETS + part + ".res", ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Could not save mesh " + part)
			quit(1)
			return
	var scales := Image.create_empty(64, 32, false, Image.FORMAT_RGB8)
	var mask := Image.create_empty(64, 32, false, Image.FORMAT_RGB8)
	for y in scales.get_height():
		for x in scales.get_width():
			scales.set_pixel(x, y, _scale_pixel(x, y))
			var point := Vector2(x, y)
			var inside := ((point - Vector2(33, 16)) / Vector2(9.0, 8.0)).length() <= 1.0
			var cutout := ((point - Vector2(37, 13)) / Vector2(8.0, 7.0)).length() < 1.0
			mask.set_pixel(x, y, Color.WHITE if inside and not cutout else Color.BLACK)
	var scales_error := scales.save_png(ASSETS + "betta_scales.png")
	var mask_error := mask.save_png(ASSETS + "silver_mask.png")
	quit(0 if scales_error == OK and mask_error == OK else 1)


func _scale_pixel(x: int, y: int) -> Color:
	var color := Color("#293e69")
	if y < 11:
		color = Color("#377b87")
	elif y < 20:
		color = Color("#3e648f")
	elif y > 23:
		color = Color("#886487")
	if x > 49:
		return Color("#38546e") if y < 19 else Color("#a38085")
	var offset := 2 if (y / 3) % 2 == 0 else 0
	var scallop := (x + offset) % 5
	if scallop == 1 and y % 3 == 1:
		color = color.lightened(0.19)
	elif scallop == 4 and y % 3 != 1:
		color = color.darkened(0.16)
	# A short band below each gill draws the eye toward the head.
	if x >= 44 and x <= 46 and y >= 15 and y <= 22:
		color = Color("#ae626d") if x == 45 else Color("#6b465e")
	return color
