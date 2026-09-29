extends SceneTree
## Turns generated expression pictures into game-ready faces:
##   godot --headless --path . --script res://tools/fit_expressions.gd
## art_src/expressions/fit.json lists, per character, its usual picture (`base`) and which source
## picture (in art_src/expressions/, drawn on white with the prompt in
## docs/story-telling-game/EXPRESSIONS.md) is which expression id. For each source:
## - the white reachable from the border becomes transparent (edge pixels fade with their lightness);
## - the figure is scaled to the usual picture's pixels: `scale` when given, else the usual figure's
##   height over the median figure height of that character's sources. A face may be written as
##   {"file": …, "rescale": 0.66} when its source draws the character at another size (a seated pose
##   drawn larger): its figure is scaled by that much more and left out of the median;
## - it stands on the usual figure's feet line, centred on the same body line (the middle of the
##   lower 60 % of the figure, or `anchor_x` for the usual picture when given);
## - the canvas is the usual picture's, widened evenly and raised when a pose sticks out, so the game
##   places any face from its size alone (placeholder_sprite.gd).
## Writes assets/image/expressions/<character>_<expression>.png (ids sharing a source share the file
## of the first) and prints each character's catalog `expressions` entry.

const CONFIG_PATH: String = "res://art_src/expressions/fit.json"
const SOURCE_DIR: String = "res://art_src/expressions/"
const OUTPUT_DIR: String = "res://assets/image/expressions/"
## A pixel whose darkest channel is at least this is paper white.
const WHITE: int = 235


func _init() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for character_id: String in config.keys():
		var spec: Dictionary = config[character_id]
		var base: Image = _load(String(spec["base"]))
		var base_box: Rect2i = _figure(base)
		var base_anchor: float = float(spec.get("anchor_x", _anchor(base, base_box)))
		var sources: Dictionary = {}  # file -> [cut image, figure box, anchor x]
		var rescales: Dictionary = {}  # file -> extra scale of a source drawn at another size
		for expression: String in (spec["faces"] as Dictionary).keys():
			var file: String = _face_file(spec["faces"][expression])
			if spec["faces"][expression] is Dictionary and not rescales.has(file):
				rescales[file] = float((spec["faces"][expression] as Dictionary).get("rescale", 1.0))
			if not sources.has(file):
				var cut: Image = _cut_white(_load(SOURCE_DIR + file))
				var box: Rect2i = _figure(cut)
				sources[file] = [cut, box, _anchor(cut, box)]
		var heights: Array = []
		for file: String in sources.keys():
			if not rescales.has(file):
				heights.append((sources[file][1] as Rect2i).size.y)
		heights.sort()
		var scale: float = float(spec.get("scale", float(base_box.size.y) / float(heights[heights.size() / 2])))
		var written: Dictionary = {}  # file -> output path
		var entry: Dictionary = {}
		for expression: String in (spec["faces"] as Dictionary).keys():
			var file: String = _face_file(spec["faces"][expression])
			if not written.has(file):
				var path: String = OUTPUT_DIR + "%s_%s.png" % [character_id, expression]
				var face_scale: float = scale * float(rescales.get(file, 1.0))
				var fitted: Image = _fit(sources[file], face_scale, base, base_box, base_anchor)
				fitted.save_png(ProjectSettings.globalize_path(path))
				written[file] = path
				print("FACE %s %s <- %s %s scale %.3f" % [character_id, expression, file, fitted.get_size(), face_scale])
			entry[expression] = written[file]
		print("CATALOG \"%s\" expressions: %s" % [character_id, JSON.stringify(entry)])
	quit(0)


## A face is a source file name, or {"file": name, "rescale": n}.
func _face_file(face: Variant) -> String:
	return String((face as Dictionary)["file"]) if face is Dictionary else String(face)


func _load(path: String) -> Image:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	image.convert(Image.FORMAT_RGBA8)
	return image


## Paper white reachable from the border becomes transparent; pixels on its edge keep an alpha
## that fades with their lightness, so no white fringe stays around the lines.
func _cut_white(image: Image) -> Image:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var data: PackedByteArray = image.get_data()
	var paper: PackedByteArray = PackedByteArray()
	paper.resize(w * h)
	var queue: PackedInt32Array = PackedInt32Array()
	for x: int in w:
		queue.append(x)
		queue.append((h - 1) * w + x)
	for y: int in h:
		queue.append(y * w)
		queue.append(y * w + w - 1)
	var head: int = 0
	while head < queue.size():
		var p: int = queue[head]
		head += 1
		if paper[p] != 0 or mini(data[p * 4], mini(data[p * 4 + 1], data[p * 4 + 2])) < WHITE:
			continue
		paper[p] = 1
		var x: int = p % w
		if x > 0:
			queue.append(p - 1)
		if x < w - 1:
			queue.append(p + 1)
		if p >= w:
			queue.append(p - w)
		if p < w * (h - 1):
			queue.append(p + w)
	for p: int in w * h:
		if paper[p] == 1:
			data[p * 4 + 3] = 0
			continue
		var x: int = p % w
		var edge: bool = (x > 0 and paper[p - 1] == 1) or (x < w - 1 and paper[p + 1] == 1) \
			or (p >= w and paper[p - w] == 1) or (p < w * (h - 1) and paper[p + w] == 1)
		if edge:
			var darkest: int = mini(data[p * 4], mini(data[p * 4 + 1], data[p * 4 + 2]))
			data[p * 4 + 3] = clampi(int((WHITE + 10 - darkest) * 255.0 / 90.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


## The box around every visible pixel.
func _figure(image: Image) -> Rect2i:
	var used: Rect2i = image.get_used_rect()
	return used if used.has_area() else Rect2i(Vector2i.ZERO, image.get_size())


## The body line: the mean x of the visible pixels in the lower 60 % of the figure.
func _anchor(image: Image, box: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(box.position.y + int(box.size.y * 0.4), box.end.y, 4):
		for x: int in range(box.position.x, box.end.x, 4):
			if image.get_pixel(x, y).a > 0.5:
				total += x
				count += 1
	return total / maxi(count, 1) if count > 0 else box.get_center().x


func _fit(source: Array, scale: float, base: Image, base_box: Rect2i, base_anchor: float) -> Image:
	var cut: Image = source[0]
	var box: Rect2i = source[1]
	var figure: Image = cut.get_region(box)
	figure.resize(maxi(1, roundi(box.size.x * scale)), maxi(1, roundi(box.size.y * scale)), Image.INTERPOLATE_LANCZOS)
	var left: float = base_anchor - (float(source[2]) - box.position.x) * scale
	var top: float = base_box.end.y - figure.get_height()
	var pad_x: int = ceili(maxf(0.0, maxf(-left, left + figure.get_width() - base.get_width())))
	var pad_top: int = ceili(maxf(0.0, -top))
	var canvas: Image = Image.create(base.get_width() + pad_x * 2, base.get_height() + pad_top, false, Image.FORMAT_RGBA8)
	canvas.blit_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), Vector2i(roundi(left) + pad_x, roundi(top) + pad_top))
	return canvas
