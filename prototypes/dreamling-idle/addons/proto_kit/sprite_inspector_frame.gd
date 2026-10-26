extends Control
## One cell of a sprite3d_sheet drawn as the shader would pick it (same cell, same mirror), at one uniform zoom for
## every frame, so size and foot changes between frames stay visible. Overlays for checking cuts and feet.
## Used by sprite_inspector for the big view and for the frame strip thumbnails.

signal clicked

var sheet: Resource
var image_size: Vector2i
var cell: int = -1
var flip: bool = false
## Source pixels -> screen pixels. Never chosen per frame: the inspector sets one value for all frames.
var zoom: float = 1.0
var onion_cell: int = -1
var onion_flip: bool = false
var info: Dictionary = {}
## Foot of the animation's first frame (cell pixels), drawn as a reference line; -1 = none.
var reference_foot_y: int = -1
var show_cell_border: bool = true
var show_pixel_grid: bool = true
var show_foot_line: bool = true
var show_bbox: bool = true
var show_center: bool = true
var selected: bool = false
var caption: String = ""

const CHECK_A := Color(0.22, 0.24, 0.27)
const CHECK_B := Color(0.28, 0.3, 0.34)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()


## Top-left of the cell on screen: centred in the control.
func cell_origin() -> Vector2:
	var cell_size := _cell_size() * zoom
	return ((size - cell_size) * 0.5).floor()


func _cell_size() -> Vector2:
	if sheet == null or image_size == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(image_size.x / maxi(1, int(sheet.columns)), image_size.y / maxi(1, int(sheet.rows)))


func _draw() -> void:
	var cs := _cell_size()
	if cs == Vector2.ZERO:
		return
	var origin := cell_origin()
	var box := Rect2(origin, cs * zoom)
	# Checkerboard behind the cell, in 8 source-pixel squares.
	var step := maxf(4.0, 8.0 * zoom)
	var y := 0.0
	while y < box.size.y:
		var x := 0.0
		while x < box.size.x:
			var c := CHECK_A if (int(x / step) + int(y / step)) % 2 == 0 else CHECK_B
			draw_rect(Rect2(box.position + Vector2(x, y), Vector2(minf(step, box.size.x - x), minf(step, box.size.y - y))), c)
			x += step
		y += step
	if onion_cell >= 0:
		_draw_cell(onion_cell, onion_flip, box, Color(0.6, 0.85, 1.0, 0.35))
	if cell >= 0 and cell < int(sheet.columns) * int(sheet.rows):
		_draw_cell(cell, flip, box, Color.WHITE)
	elif cell >= 0:
		draw_line(box.position, box.end, Color.RED, 2.0)
		draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), Color.RED, 2.0)
	if show_pixel_grid and zoom >= 6.0:
		var grid := Color(1, 1, 1, 0.08)
		for i in range(1, int(cs.x)):
			draw_line(origin + Vector2(i * zoom, 0), origin + Vector2(i * zoom, box.size.y), grid)
		for i in range(1, int(cs.y)):
			draw_line(origin + Vector2(0, i * zoom), origin + Vector2(box.size.x, i * zoom), grid)
	if show_center:
		var cx := origin.x + cs.x * 0.5 * zoom
		draw_dashed_line(Vector2(cx, box.position.y), Vector2(cx, box.end.y), Color(1, 1, 1, 0.25), 1.0, 6.0)
	if show_foot_line:
		var fy := origin.y + (cs.y - float(sheet.foot_px)) * zoom
		draw_line(Vector2(box.position.x, fy), Vector2(box.end.x, fy), Color(1.0, 0.3, 0.3, 0.9), 1.5)
		if reference_foot_y >= 0:
			var ry := origin.y + (reference_foot_y + 1) * zoom
			draw_dashed_line(Vector2(box.position.x, ry), Vector2(box.end.x, ry), Color(0.3, 0.9, 1.0, 0.8), 1.0, 5.0)
	if show_bbox and not info.is_empty() and not info.get("empty", true):
		var bb: Rect2i = info.bbox
		var bx := bb.position.x
		if flip:
			bx = int(cs.x) - bb.end.x
		draw_rect(Rect2(origin + Vector2(bx, bb.position.y) * zoom, Vector2(bb.size) * zoom), Color(1.0, 0.85, 0.2, 0.8), false, 1.0)
		var fx: float = info.foot_x
		if flip:
			fx = cs.x - 1.0 - fx
		var foot := origin + Vector2(fx + 0.5, int(info.foot_y) + 1) * zoom
		draw_line(foot + Vector2(-6, 0), foot + Vector2(6, 0), Color(1.0, 0.85, 0.2), 2.0)
		draw_line(foot + Vector2(0, -6), foot + Vector2(0, 2), Color(1.0, 0.85, 0.2), 2.0)
	if show_cell_border:
		draw_rect(box, Color(0.9, 0.9, 1.0, 0.7) if not selected else Color(1.0, 0.75, 0.2), false, 2.0 if selected else 1.0)
	if caption != "":
		draw_string(get_theme_default_font(), Vector2(4, size.y - 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(1, 0.9, 0.6) if selected else Color(0.85, 0.85, 0.9))


func _draw_cell(index: int, mirrored: bool, box: Rect2, tint: Color) -> void:
	var cs := _cell_size()
	var src := Rect2(Vector2((index % int(sheet.columns)) * cs.x, (index / int(sheet.columns)) * cs.y), cs)
	if mirrored:
		draw_set_transform(Vector2(box.position.x + box.size.x, box.position.y), 0.0, Vector2(-1, 1))
		draw_texture_rect_region(sheet.atlas, Rect2(Vector2.ZERO, box.size), src, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(sheet.atlas, box, src, tint)
