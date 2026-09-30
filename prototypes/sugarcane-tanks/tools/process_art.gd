extends SceneTree
## Turns the images generated from art_src/PROMPTS.md into game-ready PNGs in assets/.
##   godot --headless --path . --script res://tools/process_art.gd                 # every source present
##   godot --headless --path . --script res://tools/process_art.gd -- --self-test
## Sources without alpha are keyed against their corner colour (the prompts ask for flat #FF00FF),
## kits are cut on their grid, each piece is trimmed and resized to its in-game size here,
## so nothing is shrunk at runtime. Backgrounds are cover-fitted to the 1080x1920 world.

const SRC := "res://art_src/"
const OUT := "res://assets/"
const BG_SIZE := Vector2i(1080, 1920)
const BACKGROUNDS := ["bg_temple", "bg_square", "bg_memorial", "bg_hall"]
## Kit source → [columns, rows, output names in reading order ("" = unused cell)].
const KITS := {
	"items": [4, 3, ["sugarcane_shot", "bullet", "pea", "corn", "carrot", "exp_gem", "heart", "pistol", "coin", "", "", ""]],
	"obstacles": [2, 2, ["crate", "sandbags", "hedgehog", "stone_block"]],
	"portraits": [2, 2, ["portrait_hero", "portrait_chiang", "portrait_boss_tank", ""]],
	"abilities": [4, 4, ["icon_front", "icon_multishot", "icon_diagonal", "icon_side",
		"icon_rear", "icon_pierce", "icon_ricochet", "icon_wall_bounce",
		"icon_fire", "icon_freeze", "icon_attack_boost", "icon_attack_speed",
		"icon_crit", "icon_hp_boost", "icon_heal", ""]],
}
## Longest side in game pixels (the world is 1080 wide; concept art is 720 wide, so concept px x1.5).
const SIZES := {
	"hero": 120, "rat": 110, "tank": 210, "chef": 140, "boss_tank": 320, "chiang": 300,
	"sugarcane_shot": 80, "bullet": 50, "pea": 30, "corn": 40, "carrot": 46, "exp_gem": 40, "heart": 44, "pistol": 72, "coin": 36,
	"crate": 110, "sandbags": 250, "hedgehog": 110, "stone_block": 110,
	"portrait_hero": 150, "portrait_chiang": 150, "portrait_boss_tank": 150,
}
const ICON_SIZE := 96
## Colour distance to the key below LOW is fully transparent, above HIGH fully opaque.
const KEY_LOW := 0.15
const KEY_HIGH := 0.45
const EXTENSIONS := ["png", "webp", "jpg", "jpeg"]

func _init() -> void:
	if "--self-test" in OS.get_cmdline_user_args():
		_self_test()
		quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var missing: Array[String] = []
	var sources: Array = BACKGROUNDS + KITS.keys() + ["hero", "rat", "tank", "chef", "boss_tank", "chiang"]
	for source: String in sources:
		var path: String = _find_source(source)
		if path == "":
			missing.append(source)
			continue
		var image: Image = Image.load_from_file(path)
		if source in BACKGROUNDS:
			_save(_cover(image, BG_SIZE), source)
			continue
		var kit: Array = KITS.get(source, [1, 1, [source]])
		_slice(_cutout(image), kit[0], kit[1], kit[2])
	if not missing.is_empty():
		print("not generated yet: ", ", ".join(missing))
	print("done. Re-import with: godot --headless --path . --editor --quit")
	quit()

func _find_source(source: String) -> String:
	for ext: String in EXTENSIONS:
		var path: String = ProjectSettings.globalize_path(SRC + source + "." + ext)
		if FileAccess.file_exists(path):
			return path
	return ""

func _slice(cut: Image, columns: int, rows: int, names: Array) -> void:
	var cell := Vector2i(cut.get_width() / columns, cut.get_height() / rows)
	for i: int in names.size():
		var out_name: String = names[i]
		if out_name == "":
			continue
		var piece: Image = cut.get_region(Rect2i(Vector2i(i % columns, i / columns) * cell, cell))
		var used: Rect2i = _main_rect(piece)
		if used.size == Vector2i.ZERO:
			push_error("%s: cell %d is empty" % [out_name, i])
			continue
		_save(_fit(piece.get_region(used), SIZES.get(out_name, ICON_SIZE)), out_name)

## Used rect without slivers of the neighbouring cell: generated grids are never exactly even,
## so a thin strip touching the cell edge and separated from the subject by a gap is dropped.
func _main_rect(piece: Image) -> Rect2i:
	var used: Rect2i = piece.get_used_rect()
	if used.size == Vector2i.ZERO:
		return used
	var rows: Array[bool] = []
	var cols: Array[bool] = []
	rows.resize(piece.get_height())
	cols.resize(piece.get_width())
	for y: int in piece.get_height():
		for x: int in piece.get_width():
			if piece.get_pixel(x, y).a > 0.0:
				rows[y] = true
				cols[x] = true
	var y_span: Vector2i = _drop_edge_slivers(rows)
	var x_span: Vector2i = _drop_edge_slivers(cols)
	var main: Rect2i = Rect2i(x_span.x, y_span.x, x_span.y - x_span.x, y_span.y - y_span.x)
	return _refit(piece, main)

## Recomputes the used rect inside `area` so dropped slivers don't widen the other axis.
func _refit(piece: Image, area: Rect2i) -> Rect2i:
	var inner: Rect2i = piece.get_region(area).get_used_rect()
	return Rect2i(area.position + inner.position, inner.size)

## Occupied [start, end) along one axis, minus runs that touch an edge and are under 6% of it.
func _drop_edge_slivers(occupied: Array[bool]) -> Vector2i:
	var runs: Array[Vector2i] = []
	var start: int = -1
	for i: int in occupied.size() + 1:
		var on: bool = i < occupied.size() and occupied[i]
		if on and start < 0:
			start = i
		elif not on and start >= 0:
			runs.append(Vector2i(start, i))
			start = -1
	var limit: float = occupied.size() * 0.06
	if runs.size() > 1 and runs[0].x == 0 and runs[0].y - runs[0].x < limit:
		runs.pop_front()
	if runs.size() > 1 and runs[-1].y == occupied.size() and runs[-1].y - runs[-1].x < limit:
		runs.pop_back()
	return Vector2i(runs[0].x, runs[-1].y)

## Returns a premultiplied RGBA8 copy: background keyed out (or the source's own alpha kept),
## edge pixels un-mixed from the key colour so no magenta fringe survives the resize.
func _cutout(source: Image) -> Image:
	var image: Image = source.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var keyed: bool = source.detect_alpha() == Image.ALPHA_NONE
	var key: Color = _corner_colour(image)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var a: float = c.a
			if keyed:
				var d: float = Vector3(c.r - key.r, c.g - key.g, c.b - key.b).length()
				a = clampf((d - KEY_LOW) / (KEY_HIGH - KEY_LOW), 0.0, 1.0)
				# premultiplied foreground = observed - (1 - a) * key
				c = Color(maxf(c.r - (1.0 - a) * key.r, 0.0), maxf(c.g - (1.0 - a) * key.g, 0.0), maxf(c.b - (1.0 - a) * key.b, 0.0))
				# despill: outlines blended with magenta turn purple; pull red and blue back to green's level
				var spill: float = minf(c.r, c.b) - c.g
				if spill > 0.0:
					c = Color(c.r - spill, c.g, c.b - spill)
			else:
				c = Color(c.r * a, c.g * a, c.b * a)
			if a < 0.04:
				a = 0.0
				c = Color.BLACK
			image.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return image

func _corner_colour(image: Image) -> Color:
	var w: int = image.get_width() - 1
	var h: int = image.get_height() - 1
	var sum := Color(0, 0, 0, 0)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
		sum += image.get_pixelv(p)
	return sum / 4.0

## Resizes a premultiplied piece so its longest side is `size`, then un-premultiplies.
func _fit(piece: Image, size: int) -> Image:
	var scale: float = float(size) / maxf(piece.get_width(), piece.get_height())
	piece.resize(maxi(1, roundi(piece.get_width() * scale)), maxi(1, roundi(piece.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	for y: int in piece.get_height():
		for x: int in piece.get_width():
			var c: Color = piece.get_pixel(x, y)
			if c.a > 0.0:
				piece.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), c.a))
	return piece

func _cover(image: Image, size: Vector2i) -> Image:
	var scale: float = maxf(float(size.x) / image.get_width(), float(size.y) / image.get_height())
	image.resize(ceili(image.get_width() * scale), ceili(image.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	return image.get_region(Rect2i((Vector2i(image.get_width(), image.get_height()) - size) / 2, size))

func _save(image: Image, out_name: String) -> void:
	var error: Error = image.save_png(ProjectSettings.globalize_path(OUT + out_name + ".png"))
	print("%s %s %dx%d" % ["wrote" if error == OK else "FAILED", out_name, image.get_width(), image.get_height()])

func _self_test() -> void:
	var magenta := Color(1, 0, 1)
	var pink := Color(0.9, 0.6, 0.65)  # like the rat's ears, the colour closest to the key
	var sheet: Image = Image.create(200, 100, false, Image.FORMAT_RGB8)
	sheet.fill(magenta)
	sheet.fill_rect(Rect2i(20, 30, 60, 40), pink)
	sheet.fill_rect(Rect2i(130, 10, 20, 80), Color(0.1, 0.1, 0.1))
	sheet.set_pixel(80, 50, magenta.lerp(pink, 0.35))  # half-covered edge pixel
	sheet.set_pixel(129, 50, Color(0.5, 0, 0.5))  # dark outline blended with the key
	var cut: Image = _cutout(sheet)
	var ok: bool = true
	ok = _expect(cut.get_pixel(0, 0).a == 0.0, "background corner is transparent") and ok
	var left: Image = cut.get_region(Rect2i(0, 0, 100, 100))
	ok = _expect(left.get_used_rect() == Rect2i(20, 30, 61, 40), "pink subject survives keying and trims tight") and ok
	var edge: float = cut.get_pixel(80, 50).a
	ok = _expect(edge > 0.1 and edge < 0.9, "edge pixel is partially transparent (%.2f)" % edge) and ok
	var outline: Color = cut.get_pixel(129, 50)
	ok = _expect(outline.a == 1.0 and outline.r < 0.05 and outline.b < 0.05, "purple fringe on a dark outline turns black") and ok
	var fitted: Image = _fit(left.get_region(Rect2i(20, 30, 60, 40)), 30)
	ok = _expect(fitted.get_size() == Vector2i(30, 20), "fit keeps aspect with the longest side at the target") and ok
	var centre: Color = fitted.get_pixel(15, 10)
	ok = _expect(centre.a > 0.99 and absf(centre.g - pink.g) < 0.05 and absf(centre.b - pink.b) < 0.1, "colour survives premultiply and despill") and ok
	var cell: Image = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	cell.fill_rect(Rect2i(20, 10, 60, 60), Color.WHITE)
	cell.fill_rect(Rect2i(15, 97, 70, 3), Color.WHITE)  # top edge of the tile below, cut into this cell
	ok = _expect(_main_rect(cell) == Rect2i(20, 10, 60, 60), "a sliver of the next cell is dropped") and ok
	cell.fill_rect(Rect2i(40, 80, 10, 10), Color.WHITE)  # a detached sparkle inside the cell stays
	ok = _expect(_main_rect(cell) == Rect2i(20, 10, 60, 80), "detached parts away from the edge are kept") and ok
	var bg: Image = Image.create(720, 1280, false, Image.FORMAT_RGB8)
	ok = _expect(_cover(bg, BG_SIZE).get_size() == BG_SIZE, "backgrounds cover-fit to the world size") and ok
	print("process_art self-test ", "PASSED" if ok else "FAILED")

func _expect(condition: bool, label: String) -> bool:
	if not condition:
		print("FAIL ", label)
	return condition
