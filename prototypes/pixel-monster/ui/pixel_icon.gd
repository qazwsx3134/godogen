extends Control

var kind: String = "scale"
const INK: Color = Color("52664f")

func _ready() -> void:
	custom_minimum_size = Vector2(28, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(((size - Vector2(24, 24)) / 2.0).floor())
	var rows: Array = []
	match kind:
		"scale": rows = ["..######..", ".#......#.", ".#.####.#.", ".#..##..#.", ".#......#.", ".########."]
		"food": rows = ["...####...", "..######..", ".########.", "..######..", "...####.#.", "......##.."]
		"train": rows = [".#......#.", "###....###", "##########", "##########", "###....###", ".#......#."]
		"battle": rows = [".##....##.", "..##..##..", "...####...", "...####...", "..##..##..", ".##....##."]
		"clean": rows = ["......##..", ".....##...", "....##....", "..####....", ".######...", "########.."]
		"lights": rows = ["...####...", "..#....#..", "..#....#..", "...#..#...", "...####...", "....##...."]
		"heal": rows = ["....##....", "....##....", "..######..", "..######..", "....##....", "....##...."]
		"steps": rows = ["..##...##.", ".###..###.", ".###..###.", "..##..##..", "..##..##..", "...#..#..."]
	for y in rows.size():
		for x in str(rows[y]).length():
			if rows[y][x] == "#":
				draw_rect(Rect2(x * 2 + 2, y * 2 + 6, 2, 2), INK)
	draw_set_transform(Vector2.ZERO)
