extends SceneTree
## Converts the generated magenta-keyed art into compact, nearest-neighbour game sprites.

const SOURCE_DIR := "res://art_src/gen"
const OUTPUT_DIR := "res://assets/sprites"
const CHARACTER_HEIGHT := 96

const STRIPS := [
	{"stem": "gintoki_ref", "frames": 1},
	{"stem": "shinpachi_ref", "frames": 1},
	{"stem": "kagura_ref", "frames": 1},
	{"stem": "gintoki_toss", "frames": 3},
	{"stem": "gintoki_idle", "frames": 2},
	{"stem": "kagura_ready", "frames": 2},
	{"stem": "kagura_chomp", "frames": 2},
	{"stem": "kagura_miss", "frames": 1},
	{"stem": "kagura_full", "frames": 1},
	{"stem": "shinpachi_cheer", "frames": 2},
	{"stem": "shinpachi_shock", "frames": 1},
	{"stem": "dango_props", "frames": 4, "widths": [40, 64, 40, 18], "detect_cells": true},
	{"stem": "kagura_tier2", "frames": 4},
	{"stem": "kagura_tier3", "frames": 4},
	{"stem": "gintoki_eat", "frames": 2},
	{"stem": "shinpachi_eat", "frames": 2},
	{"stem": "gintoki_full", "frames": 1},
	{"stem": "shinpachi_full", "frames": 1},
	{"stem": "referee_ref", "frames": 1},
	{"stem": "referee_call", "frames": 2},
	{"stem": "rival_team", "frames": 4},
	{"stem": "store_owner_serve", "frames": 1},
	{"stem": "dango_flavors", "frames": 2, "widths": [40, 40], "detect_cells": true},
	{"stem": "kagura_rice", "frames": 1},
	{"stem": "rice_bowl", "frames": 1, "target_height": 32, "widths": [32], "fixed_size": true},
	{"stem": "shinpachi_bento", "frames": 3, "detect_cells": true},
	{"stem": "gintoki_kick", "frames": 3, "detect_cells": true},
	{"stem": "gintoki_dart", "frames": 2, "detect_cells": true},
	{"stem": "shinpachi_dart", "frames": 2, "detect_cells": true},
	{"stem": "kagura_eye_hit", "frames": 1},
	{"stem": "life_dango", "frames": 1, "target_height": 32, "widths": [32], "fixed_size": true},
	{"stem": "commentator_pair", "frames": 1},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_absolute)
	for spec in STRIPS:
		var stem: String = spec.stem
		var source_path := SOURCE_DIR.path_join(stem + ".png")
		var source_absolute := ProjectSettings.globalize_path(source_path)
		if not FileAccess.file_exists(source_path):
			push_error("Missing generated art: %s" % source_path)
			quit(1)
			return
		var source := Image.load_from_file(source_absolute)
		if source == null or source.is_empty():
			push_error("Could not load generated art: %s" % source_path)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		_key_magenta(source)
		var widths: Array[int] = []
		for width_value in spec.get("widths", []):
			widths.append(int(width_value))
		var detected_cells := bool(spec.get("detect_cells", false))
		var fixed_size := bool(spec.get("fixed_size", false))
		if not _save_strip(source, stem, int(spec.frames), int(spec.get("target_height", CHARACTER_HEIGHT)), widths, detected_cells, fixed_size):
			quit(1)
			return
	_process_wide("bg_contest", "contest_background.png")
	_process_wide("title_art", "title_art.png")
	_process_wide("bg_torii_park", "bg_torii_park.png")
	_process_wide("scoreboard_panel", "scoreboard_panel.png", Vector2i(400, 120))
	print("Processed %d generated art sheets into %s" % [STRIPS.size() + 4, OUTPUT_DIR])
	quit()


func _key_magenta(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.r >= 0.90 and color.g <= 0.08 and color.b >= 0.90:
				image.set_pixel(x, y, Color.TRANSPARENT)
	for _pass in 4:
		var fringe: Array[Vector2i] = []
		for y in image.get_height():
			for x in image.get_width():
				var color := image.get_pixel(x, y)
				if not _is_magenta_fringe(color) or not _touches_transparency(image, x, y):
					continue
				fringe.append(Vector2i(x, y))
		if fringe.is_empty():
			break
		for point in fringe:
			image.set_pixel(point.x, point.y, Color.TRANSPARENT)


func _is_magenta_fringe(color: Color) -> bool:
	return color.r >= 0.62 and color.g <= 0.4 and color.b >= 0.62 and absf(color.r - color.b) <= 0.28


func _touches_transparency(image: Image, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if nx >= 0 and nx < image.get_width() and ny >= 0 and ny < image.get_height():
				if image.get_pixel(nx, ny).a == 0.0:
					return true
	return false


func _save_strip(image: Image, stem: String, frame_count: int, target_height: int, widths: Array[int], detect_cells: bool, fixed_size: bool) -> bool:
	var bounds: Array[Rect2i] = []
	var max_height := 0
	var max_width := 0
	var detected_regions: Array[Rect2i] = []
	if detect_cells:
		detected_regions = _detected_cell_regions(image, frame_count)
		if detected_regions.size() != frame_count:
			push_error("Expected %d separate cells in %s, found %d" % [frame_count, stem, detected_regions.size()])
			return false
	for index in frame_count:
		var rect: Rect2i
		if detect_cells:
			rect = detected_regions[index]
		else:
			var left := floori(float(image.get_width() * index) / frame_count)
			var right := floori(float(image.get_width() * (index + 1)) / frame_count)
			rect = Rect2i(left, 0, right - left, image.get_height())
		var frame_bounds := _alpha_bounds(image, rect)
		if frame_bounds.size.x <= 0 or frame_bounds.size.y <= 0:
			push_error("No sprite found in %s cell %d" % [stem, index])
			return false
		bounds.append(frame_bounds)
		max_height = maxi(max_height, frame_bounds.size.y)
		max_width = maxi(max_width, frame_bounds.size.x)
	var frame_width := maxi(1, roundi(float(max_width) * target_height / max_height))
	for index in frame_count:
		var frame_bounds := bounds[index]
		var content_width := frame_width
		var content_height := target_height
		if not widths.is_empty():
			content_width = widths[index]
			content_height = target_height if fixed_size else maxi(1, roundi(float(frame_bounds.size.y) * content_width / frame_bounds.size.x))
		var crop := image.get_region(frame_bounds)
		crop.resize(content_width, content_height, Image.INTERPOLATE_NEAREST)
		var canvas := Image.create(content_width, target_height if widths.is_empty() else content_height, false, Image.FORMAT_RGBA8)
		canvas.fill(Color.TRANSPARENT)
		var y_offset := target_height - content_height if widths.is_empty() else 0
		canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(0, y_offset))
		var filename := stem + ("_%d" % index if frame_count > 1 else "") + ".png"
		var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(filename))
		if canvas.save_png(output_path) != OK:
			push_error("Could not save sprite: %s" % output_path)
			return false
	return true


func _detected_cell_regions(image: Image, frame_count: int) -> Array[Rect2i]:
	var runs: Array[Vector2i] = []
	var run_start := -1
	var last_foreground := -1
	var gap_limit := maxi(12, floori(float(image.get_width()) / frame_count * 0.08))
	for x in image.get_width():
		var has_foreground := false
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.0:
				has_foreground = true
				break
		if has_foreground:
			if run_start < 0:
				run_start = x
			last_foreground = x
		elif run_start >= 0 and x - last_foreground > gap_limit:
			runs.append(Vector2i(run_start, last_foreground))
			run_start = -1
	if run_start >= 0:
		runs.append(Vector2i(run_start, last_foreground))
	var lefts: Array[int] = []
	var rights: Array[int] = []
	for index in frame_count:
		lefts.append(image.get_width())
		rights.append(-1)
	for run in runs:
		if run.y - run.x < 8:
			continue
		var center := (run.x + run.y) / 2.0
		var index := clampi(floori(center * frame_count / image.get_width()), 0, frame_count - 1)
		lefts[index] = mini(lefts[index], run.x)
		rights[index] = maxi(rights[index], run.y)
	var regions: Array[Rect2i] = []
	for index in frame_count:
		if rights[index] < lefts[index]:
			return []
		regions.append(Rect2i(lefts[index], 0, rights[index] - lefts[index] + 1, image.get_height()))
	return regions


func _alpha_bounds(image: Image, region: Rect2i) -> Rect2i:
	var min_x := region.position.x + region.size.x
	var min_y := region.position.y + region.size.y
	var max_x := region.position.x - 1
	var max_y := region.position.y - 1
	for y in range(region.position.y, region.position.y + region.size.y):
		for x in range(region.position.x, region.position.x + region.size.x):
			if image.get_pixel(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _process_wide(stem: String, output_name: String, size := Vector2i(640, 360)) -> void:
	var source_path := ProjectSettings.globalize_path(SOURCE_DIR.path_join(stem + ".png"))
	var image := Image.load_from_file(source_path)
	if image == null or image.is_empty():
		push_error("Could not load generated art: %s" % source_path)
		quit(1)
		return
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(output_name))
	if image.save_png(output_path) != OK:
		push_error("Could not save wide art: %s" % output_path)
		quit(1)
