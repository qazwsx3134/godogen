extends Control
## The whole atlas with its cell grid (as the sheet's columns x rows divide it), cell numbers, the cells the current
## animation uses and the cell on screen now. Click a cell to report it (cell_clicked).

signal cell_clicked(cell: int)

var sheet: Resource
var image_size: Vector2i
var anim_cells: Array = []
var current_cell: int = -1
## cell -> "error" or "warn": cells with problems get a coloured fill.
var marks: Dictionary = {}


func _scale() -> float:
	if image_size == Vector2i.ZERO:
		return 1.0
	return minf(size.x / image_size.x, size.y / image_size.y)


func _origin() -> Vector2:
	return ((size - Vector2(image_size) * _scale()) * 0.5).floor()


func _gui_input(event: InputEvent) -> void:
	if sheet == null or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = (event.position - _origin()) / _scale()
	if p.x < 0 or p.y < 0 or p.x >= image_size.x or p.y >= image_size.y:
		return
	var cw := image_size.x / int(sheet.columns)
	var ch := image_size.y / int(sheet.rows)
	cell_clicked.emit(int(p.y) / ch * int(sheet.columns) + int(p.x) / cw)


func _draw() -> void:
	if sheet == null or sheet.atlas == null or image_size == Vector2i.ZERO:
		return
	var s := _scale()
	var o := _origin()
	var full := Rect2(o, Vector2(image_size) * s)
	draw_rect(full, Color(0.18, 0.2, 0.23))
	draw_texture_rect(sheet.atlas, full, false)
	var cols := int(sheet.columns)
	var rows := int(sheet.rows)
	var cw := image_size.x / float(cols) * s
	var ch := image_size.y / float(rows) * s
	var font := get_theme_default_font()
	for cell in cols * rows:
		var r := Rect2(o + Vector2((cell % cols) * cw, (cell / cols) * ch), Vector2(cw, ch))
		if marks.has(cell):
			draw_rect(r, Color(1, 0.2, 0.2, 0.18) if marks[cell] == "error" else Color(1, 0.75, 0.2, 0.15))
		if cell in anim_cells:
			draw_rect(r.grow(-2), Color(0.3, 0.9, 1.0, 0.8), false, 2.0)
		if cell == current_cell:
			draw_rect(r.grow(-1), Color(1.0, 0.75, 0.2), false, 3.0)
		draw_string(font, r.position + Vector2(4, 14), str(cell), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	var grid := Color(1, 1, 1, 0.35)
	for c in range(cols + 1):
		draw_line(o + Vector2(c * cw, 0), o + Vector2(c * cw, full.size.y), grid)
	for r in range(rows + 1):
		draw_line(o + Vector2(0, r * ch), o + Vector2(full.size.x, r * ch), grid)
