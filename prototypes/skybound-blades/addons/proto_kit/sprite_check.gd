extends RefCounted
## Checks a sprite3d_sheet against its atlas pixels: cells out of range, empty frames, art touching a cell edge
## (cut in the wrong place or bleeding into the neighbour), and feet that move between the frames of one animation.
## It only reads: frame order, frame sizes and the sheet itself are never changed. Used by sprite_inspector and tests.
##
##   const SpriteCheck = preload("res://addons/proto_kit/sprite_check.gd")
##   var image := SpriteCheck.atlas_image(sheet)                 # decompressed copy of the atlas
##   var info := SpriteCheck.cell_info(sheet, image, 7)          # {rect, empty, bbox, foot_y, foot_x, touches}
##   var issues := SpriteCheck.check_sheet(sheet)                # [{level, anim, dir, frame, cell, text}]
##
## Pixel coordinates are inside the cell: (0, 0) is its top-left, foot_y is the lowest opaque row, the expected foot
## line is cell_px - foot_px (the shader cuts the strip below it).

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")

## Alpha (0..1) above which a pixel counts as art.
const ALPHA_CUT := 0.5
## Feet may differ by this many source pixels between frames of one animation before it is reported.
const FOOT_TOLERANCE_PX := 2

const DIRECTION_NAMES_8 := ["前", "右前", "右", "右後", "後", "左後", "左", "左前"]
const DIRECTION_NAMES_4 := ["前", "右", "後", "左"]
const DIRECTION_NAMES_2 := ["右", "左"]


static func direction_name(sheet: Resource, dir: int) -> String:
	match sheet.logical_count():
		8: return DIRECTION_NAMES_8[dir]
		4: return DIRECTION_NAMES_4[dir]
		2: return DIRECTION_NAMES_2[dir]
	return "單一"


## The atlas as an uncompressed Image, or null when the sheet has no atlas.
static func atlas_image(sheet: Resource) -> Image:
	var tex: Texture2D = sheet.atlas
	if tex == null:
		return null
	var image := tex.get_image()
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	return image


static func cell_count(sheet: Resource) -> int:
	return int(sheet.columns) * int(sheet.rows)


## Cell rectangle in atlas pixels (the atlas may be larger than columns x cell_px: the grid comes from the sheet).
static func cell_rect(sheet: Resource, cell: int, image_size: Vector2i) -> Rect2i:
	var w := image_size.x / maxi(1, int(sheet.columns))
	var h := image_size.y / maxi(1, int(sheet.rows))
	return Rect2i((cell % int(sheet.columns)) * w, (cell / int(sheet.columns)) * h, w, h)


## What is drawn in one cell. touches = sides ("left", "right", "top", "bottom") where art reaches the cell edge.
static func cell_info(sheet: Resource, image: Image, cell: int) -> Dictionary:
	var info := {"cell": cell, "in_range": cell >= 0 and cell < cell_count(sheet), "empty": true,
		"bbox": Rect2i(), "foot_y": -1, "foot_x": -1.0, "touches": PackedStringArray(), "rect": Rect2i()}
	if image == null or not info.in_range:
		return info
	var rect := cell_rect(sheet, cell, image.get_size())
	info.rect = rect
	var region := image.get_region(rect)
	# Native bbox of any visible pixel (alpha > 0): fast, and the right test for edge contact.
	var used := region.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return info
	var min_x := used.position.x
	var min_y := used.position.y
	var max_x := used.end.x - 1
	var max_y := used.end.y - 1
	# Feet: lowest row with solid art (alpha > ALPHA_CUT), scanning up from the bottom of the bbox.
	var foot := -1
	for y in range(max_y, min_y - 1, -1):
		for x in range(min_x, max_x + 1):
			if region.get_pixel(x, y).a > ALPHA_CUT:
				foot = y
				break
		if foot >= 0:
			break
	if foot < 0:
		return info  # only faint pixels: treat as empty
	info.empty = false
	info.bbox = used
	info.foot_y = foot
	# Foot x: centre of the art in its lowest rows (the feet), not of the whole bbox (a sword sticks out).
	var band := maxi(1, used.size.y / 12)
	var sum := 0.0
	var n := 0
	for y in range(maxi(min_y, foot - band + 1), foot + 1):
		for x in range(min_x, max_x + 1):
			if region.get_pixel(x, y).a > ALPHA_CUT:
				sum += x
				n += 1
	info.foot_x = sum / n if n > 0 else -1.0
	var touches := PackedStringArray()
	if min_x == 0: touches.append("left")
	if max_x == rect.size.x - 1: touches.append("right")
	if min_y == 0: touches.append("top")
	if max_y == rect.size.y - 1: touches.append("bottom")
	info.touches = touches
	return info


## Frames of one animation in one stored direction row, in the sheet's own order: [{frame, cell, ticks, flip}].
static func frames(sheet: Resource, anim: StringName, dir: int) -> Array:
	var a: Dictionary = sheet.resolve(anim)
	var out: Array = []
	if a.is_empty():
		return out
	var d: Array = a.get("d", [])
	var n := int(a.get("n", d.size()))
	var tick := 0
	for i in n:
		var drawn: Vector2i = sheet.cell(anim, dir, tick)
		out.append({"frame": i, "cell": drawn.x, "flip": drawn.y < 0, "ticks": int(d[i]) if i < d.size() else 1})
		tick += maxi(1, int(d[i]) if i < d.size() else 1)
	return out


## Every problem in the sheet. level: "error" (wrong cell or empty frame) or "warn" (edge contact, foot drift).
static func check_sheet(sheet: Resource) -> Array:
	var issues: Array = []
	var image := atlas_image(sheet)
	if image == null:
		issues.append({"level": "error", "anim": "", "dir": -1, "frame": -1, "cell": -1, "text": "沒有圖集（atlas）"})
		return issues
	var expected_cell := Vector2i(image.get_width() / maxi(1, int(sheet.columns)), image.get_height() / maxi(1, int(sheet.rows)))
	if expected_cell.x != int(sheet.cell_px) or expected_cell.y != int(sheet.cell_px):
		issues.append({"level": "error", "anim": "", "dir": -1, "frame": -1, "cell": -1,
			"text": "格子大小不符：圖集 %dx%d ÷ %dx%d 格 = %dx%d px，sheet 寫 cell_px %d" % [image.get_width(),
				image.get_height(), int(sheet.columns), int(sheet.rows), expected_cell.x, expected_cell.y, int(sheet.cell_px)]})
	var foot_line := int(sheet.cell_px) - int(sheet.foot_px) - 1
	var cache := {}
	var rows_seen := {}
	for anim_name: Variant in sheet.anims:
		var anim := StringName(str(anim_name))
		for dir in sheet.logical_count():
			var list := frames(sheet, anim, dir)
			# Mirrored directions draw the same cells: check each stored row once.
			var key := "%s|%s" % [anim, list.map(func(f: Dictionary) -> int: return f.cell)]
			if rows_seen.has(key):
				continue
			rows_seen[key] = true
			var feet: Array = []
			for f: Dictionary in list:
				if not cache.has(f.cell):
					cache[f.cell] = cell_info(sheet, image, f.cell)
				var info: Dictionary = cache[f.cell]
				var where := {"anim": String(anim), "dir": dir, "frame": f.frame, "cell": f.cell}
				if not info.in_range:
					issues.append(_issue("error", where, "格號 %d 超出圖集（共 %d 格）" % [f.cell, cell_count(sheet)]))
					continue
				if info.empty:
					issues.append(_issue("error", where, "空白格（格號 %d 沒有任何圖）" % f.cell))
					continue
				if not (info.touches as PackedStringArray).is_empty():
					issues.append(_issue("warn", where, "圖碰到格子邊緣（%s）：可能切錯格或吃到隔壁格" % ", ".join(info.touches)))
				feet.append({"frame": f.frame, "cell": f.cell, "foot_y": info.foot_y, "foot_x": info.foot_x})
			if feet.size() >= 2:
				var ys: Array = feet.map(func(f: Dictionary) -> int: return f.foot_y)
				var spread: int = ys.max() - ys.min()
				if spread > FOOT_TOLERANCE_PX:
					issues.append(_issue("warn", {"anim": String(anim), "dir": dir, "frame": -1, "cell": -1},
						"腳底跳動 %d px（各格最低點 %s）" % [spread, ys]))
			for f: Dictionary in feet:
				if absi(int(f.foot_y) - foot_line) > FOOT_TOLERANCE_PX:
					issues.append(_issue("warn", {"anim": String(anim), "dir": dir, "frame": f.frame, "cell": f.cell},
						"腳底不在腳底線上：最低點 y=%d，腳底線 y=%d（差 %+d px）" % [f.foot_y, foot_line, int(f.foot_y) - foot_line]))
	return issues


static func _issue(level: String, where: Dictionary, text: String) -> Dictionary:
	var out := where.duplicate()
	out.level = level
	out.text = text
	return out
