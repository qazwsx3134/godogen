extends Control
## Sprite animation test page (sprite_inspector.tscn): pick a sheet, an animation and a direction; play it at any
## speed or step frame by frame; check cuts, wrong frames and foot jumps against the grid. Read-only: it never resizes
## a character per frame, never reorders frames, never writes the sheet.
##
##   godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn
##   godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --sheet res://resources/sheets/leader.tres
##   godot --path prototypes/<game> res://addons/proto_kit/sprite_inspector.tscn -- --json res://assets/sprites/sheets.json
##
## Sheets come from every sprite3d_sheet .tres/.res under res:// and every sheets.json (tools/sprite_atlas.py), except
## addons/ and folders with a .gdignore. Keys: Space play/pause, ←/→ frame, ↑/↓ direction, [ ] speed, O onion skin,
## G grid overlays, Z zoom.

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const SpriteCheck = preload("res://addons/proto_kit/sprite_check.gd")
const FrameView = preload("res://addons/proto_kit/sprite_inspector_frame.gd")

const SPEEDS := [0.1, 0.25, 0.5, 1.0, 1.5, 2.0, 4.0]
const ZOOMS := [0.0, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0]  # 0 = one fit factor for the whole cell, same for every frame
const THUMB := Vector2(132, 150)

@onready var _sheet_list: ItemList = %SheetList
@onready var _anim_list: ItemList = %AnimList
@onready var _dir_box: GridContainer = %Directions
@onready var _speed: OptionButton = %Speed
@onready var _zoom: OptionButton = %Zoom
@onready var _view: Control = %FrameView
@onready var _atlas: Control = %AtlasView
@onready var _strip: HBoxContainer = %FrameStrip
@onready var _info: Label = %Info
@onready var _issues: ItemList = %Issues
@onready var _play: Button = %PlayButton
@onready var _onion: CheckBox = %OnionCheck
@onready var _overlays: CheckBox = %OverlayCheck
@onready var _nearest: CheckBox = %NearestCheck

## [{label, sheet}]
var sheets: Array = []
var sheet: Resource
var image: Image
var image_size: Vector2i
var anim: StringName = &""
var dir: int = 0
var frame: int = 0
var playing: bool = true
var _ticks: float = 0.0
var _frames: Array = []
var _infos: Dictionary = {}
var _issue_rows: Array = []


func _ready() -> void:
	var font := pick_font()
	if font != null:
		theme = Theme.new()
		theme.default_font = font
	_sheet_list.item_selected.connect(func(i: int) -> void: select_sheet(i))
	_anim_list.item_selected.connect(func(i: int) -> void: select_anim(StringName(_anim_list.get_item_text(i).get_slice(" ", 0))))
	_issues.item_selected.connect(_on_issue)
	_play.pressed.connect(func() -> void: set_playing(not playing))
	%PrevButton.pressed.connect(func() -> void: step_frame(-1))
	%NextButton.pressed.connect(func() -> void: step_frame(1))
	for s: float in SPEEDS:
		_speed.add_item("%sx" % s)
	_speed.select(SPEEDS.find(1.0))
	for z: float in ZOOMS:
		_zoom.add_item("整格等比" if z == 0.0 else "%sx" % z)
	_zoom.select(0)
	_zoom.item_selected.connect(func(_i: int) -> void: _refresh_views())
	_onion.toggled.connect(func(_on: bool) -> void: _refresh_views())
	_overlays.toggled.connect(func(_on: bool) -> void: _refresh_views())
	_nearest.toggled.connect(func(on: bool) -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if on else CanvasItem.TEXTURE_FILTER_LINEAR)
	_atlas.cell_clicked.connect(_on_atlas_cell)
	_view.resized.connect(_refresh_views)
	sheets = discover()
	_apply_cli()
	for entry: Dictionary in sheets:
		_sheet_list.add_item(entry.label)
	if not sheets.is_empty():
		_sheet_list.select(0)
		select_sheet(0)
	else:
		_info.text = "找不到任何 sprite3d sheet（.tres／.res）或 sheets.json。用 -- --sheet <路徑> 指定。"


# --- Sources ----------------------------------------------------------------------

## A font with CJK glyphs: the project's custom GUI font, else the first .ttf/.otf in the project, else a system font.
func pick_font() -> Font:
	var custom := String(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	if custom != "" and ResourceLoader.exists(custom):
		return load(custom)
	var found := _find_font("res://")
	if found != "":
		return load(found)
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["PingFang TC", "Noto Sans CJK TC", "Microsoft JhengHei", "Noto Sans TC", "sans-serif"])
	return system


func _find_font(dir_path: String) -> String:
	var d := DirAccess.open(dir_path)
	if d == null or FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return ""
	for file: String in d.get_files():
		if file.get_extension().to_lower() in ["ttf", "otf"]:
			return dir_path.path_join(file)
	for sub: String in d.get_directories():
		if sub.begins_with(".") or (dir_path == "res://" and sub in ["addons", "build"]):
			continue
		var hit := _find_font(dir_path.path_join(sub))
		if hit != "":
			return hit
	return ""


func discover() -> Array:
	var found: Array = []
	_scan("res://", found)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.label < b.label)
	return found


func _scan(dir_path: String, found: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null or FileAccess.file_exists(dir_path.path_join(".gdignore")):
		return
	for sub: String in d.get_directories():
		if sub.begins_with(".") or (dir_path == "res://" and sub in ["addons", "build"]):
			continue
		_scan(dir_path.path_join(sub), found)
	for file: String in d.get_files():
		var path := dir_path.path_join(file)
		if file.ends_with(".tres") and FileAccess.get_file_as_string(path).contains("sprite3d_sheet.gd"):
			found.append({"label": path.trim_prefix("res://"), "sheet": load(path)})
		elif file == "sheets.json":
			_add_json(path, found)


func _add_json(path: String, found: Array) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return
	for character: String in (data as Dictionary).get("characters", {}):
		var s: Resource = Sheet.from_json(path, character)
		if s != null:
			found.append({"label": "%s · %s" % [path.trim_prefix("res://"), character], "sheet": s})


## `-- --sheet <res path>` or `-- --json <res path>` puts those first.
func _apply_cli() -> void:
	var args := OS.get_cmdline_user_args()
	var extra: Array = []
	for i in args.size() - 1:
		if args[i] == "--sheet" and ResourceLoader.exists(args[i + 1]):
			extra.append({"label": args[i + 1].trim_prefix("res://"), "sheet": load(args[i + 1])})
		elif args[i] == "--json":
			_add_json(args[i + 1], extra)
	if not extra.is_empty():
		sheets = extra + sheets


# --- Selection --------------------------------------------------------------------

func select_sheet(index: int) -> void:
	if index < _sheet_list.item_count:  # `sheets` set from code has no list rows
		_sheet_list.select(index)
	sheet = sheets[index].sheet
	image = SpriteCheck.atlas_image(sheet)
	image_size = image.get_size() if image != null else Vector2i.ZERO
	_infos.clear()
	_anim_list.clear()
	for anim_name: Variant in sheet.anims:
		var a: Dictionary = sheet.anims[anim_name]
		_anim_list.add_item("%s  (%d 格%s)" % [anim_name, int(a.get("n", 1)), "" if a.get("loop", true) else "，單次"])
	_build_directions()
	_run_checks()
	_atlas.sheet = sheet
	_atlas.image_size = image_size
	if _anim_list.item_count > 0:
		_anim_list.select(0)
		select_anim(StringName(_anim_list.get_item_text(0).get_slice(" ", 0)))


func _build_directions() -> void:
	for child: Node in _dir_box.get_children():
		_dir_box.remove_child(child)
		child.queue_free()
	var count: int = sheet.logical_count()
	_dir_box.columns = mini(count, 4)
	var group := ButtonGroup.new()
	for d in count:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(64, 40)
		b.text = SpriteCheck.direction_name(sheet, d)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: select_direction(d))
		_dir_box.add_child(b)
	dir = clampi(dir, 0, count - 1)
	(_dir_box.get_child(dir) as Button).button_pressed = true


func select_anim(anim_name: StringName) -> void:
	anim = anim_name
	for i in _anim_list.item_count:
		if _anim_list.get_item_text(i).get_slice(" ", 0) == String(anim_name):
			_anim_list.select(i)
	frame = 0
	_ticks = 0.0
	_load_frames()


func select_direction(d: int) -> void:
	dir = d
	if d < _dir_box.get_child_count():
		(_dir_box.get_child(d) as Button).button_pressed = true
	_load_frames()


func _load_frames() -> void:
	_frames = SpriteCheck.frames(sheet, anim, dir)
	frame = clampi(frame, 0, maxi(0, _frames.size() - 1))
	for f: Dictionary in _frames:
		if not _infos.has(f.cell):
			_infos[f.cell] = SpriteCheck.cell_info(sheet, image, f.cell)
	_build_strip()
	_refresh_views()


func _build_strip() -> void:
	for child: Node in _strip.get_children():
		_strip.remove_child(child)  # out of the list now: refresh indexes the new thumbnails only
		child.queue_free()
	for f: Dictionary in _frames:
		var thumb: Control = FrameView.new()
		thumb.custom_minimum_size = THUMB
		thumb.mouse_filter = Control.MOUSE_FILTER_STOP
		var index: int = f.frame
		thumb.clicked.connect(func() -> void:
			set_playing(false)
			show_frame(index))
		_strip.add_child(thumb)


# --- Playback ---------------------------------------------------------------------

func set_playing(on: bool) -> void:
	playing = on
	_play.text = "暫停" if on else "播放"


func step_frame(delta: int) -> void:
	set_playing(false)
	if _frames.is_empty():
		return
	show_frame(posmod(frame + delta, _frames.size()))


func show_frame(index: int) -> void:
	frame = index
	_ticks = 0.0
	_refresh_views()


func _process(delta: float) -> void:
	if not playing or _frames.size() < 2:
		return
	_ticks += delta * 60.0 * float(SPEEDS[_speed.selected])
	var hold := float(_frames[frame].ticks)
	if _ticks >= hold:
		_ticks -= hold
		frame = (frame + 1) % _frames.size()
		_refresh_views()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_SPACE: set_playing(not playing)
		KEY_LEFT: step_frame(-1)
		KEY_RIGHT: step_frame(1)
		KEY_UP: select_direction(posmod(dir - 1, sheet.logical_count()))
		KEY_DOWN: select_direction(posmod(dir + 1, sheet.logical_count()))
		KEY_BRACKETLEFT: _speed.select(maxi(0, _speed.selected - 1))
		KEY_BRACKETRIGHT: _speed.select(mini(SPEEDS.size() - 1, _speed.selected + 1))
		KEY_O: _onion.button_pressed = not _onion.button_pressed
		KEY_G: _overlays.button_pressed = not _overlays.button_pressed
		KEY_Z:
			_zoom.select((_zoom.selected + 1) % ZOOMS.size())
			_refresh_views()


# --- Drawing ----------------------------------------------------------------------

## One zoom for every frame: the chosen factor, or the factor that fits the whole cell in the view.
func current_zoom() -> float:
	var z: float = ZOOMS[_zoom.selected]
	if z > 0.0 or image_size == Vector2i.ZERO:
		return z
	var cell := Vector2(image_size.x / int(sheet.columns), image_size.y / int(sheet.rows))
	return maxf(0.05, minf(_view.size.x / cell.x, _view.size.y / cell.y) * 0.95)


func _refresh_views() -> void:
	if sheet == null:
		return
	var overlays := _overlays.button_pressed
	var first_foot := -1
	if not _frames.is_empty():
		first_foot = int(_infos.get(_frames[0].cell, {}).get("foot_y", -1))
	var f: Dictionary = _frames[frame] if not _frames.is_empty() else {}
	_configure(_view, f, current_zoom(), overlays, first_foot)
	if _onion.button_pressed and _frames.size() > 1:
		var prev: Dictionary = _frames[posmod(frame - 1, _frames.size())]
		_view.onion_cell = prev.cell
		_view.onion_flip = prev.flip
	else:
		_view.onion_cell = -1
	_view.queue_redraw()
	var cell_px := Vector2(image_size.x / maxi(1, int(sheet.columns)), image_size.y / maxi(1, int(sheet.rows)))
	var thumb_zoom := minf((THUMB.x - 8) / maxf(1.0, cell_px.x), (THUMB.y - 24) / maxf(1.0, cell_px.y))
	for i in _strip.get_child_count():
		var thumb: Control = _strip.get_child(i)
		if i < _frames.size():
			_configure(thumb, _frames[i], thumb_zoom, overlays, first_foot)
			thumb.selected = i == frame
			thumb.caption = "#%d 格%d %dt" % [i, _frames[i].cell, _frames[i].ticks]
			thumb.show_pixel_grid = false
			thumb.queue_redraw()
	_atlas.anim_cells = _frames.map(func(x: Dictionary) -> int: return x.cell)
	_atlas.current_cell = f.get("cell", -1)
	_atlas.queue_redraw()
	_info.text = _info_text(f, first_foot)


func _configure(v: Control, f: Dictionary, zoom: float, overlays: bool, first_foot: int) -> void:
	v.sheet = sheet
	v.image_size = image_size
	v.cell = f.get("cell", -1)
	v.flip = f.get("flip", false)
	v.zoom = zoom
	v.info = _infos.get(v.cell, {})
	v.reference_foot_y = first_foot
	v.show_bbox = overlays
	v.show_foot_line = overlays
	v.show_center = overlays
	v.show_pixel_grid = overlays
	v.show_cell_border = true


func _info_text(f: Dictionary, first_foot: int) -> String:
	if f.is_empty():
		return "這個動畫沒有格子。"
	var a: Dictionary = sheet.resolve(anim)
	var lines := PackedStringArray()
	lines.append("%s · 方向 %s（%s）· 第 %d / %d 格 · 停 %d tick（%.0f ms）%s" % [anim,
		SpriteCheck.direction_name(sheet, dir), "鏡像" if f.flip else "原圖", f.frame + 1, _frames.size(), f.ticks,
		f.ticks * 1000.0 / 60.0, "" if a.get("loop", true) else " · 單次（遊戲中停在最後一格）"])
	var info: Dictionary = _infos.get(f.cell, {})
	var cs := Vector2i(image_size.x / maxi(1, int(sheet.columns)), image_size.y / maxi(1, int(sheet.rows)))
	var line2 := "圖集格號 %d（第 %d 列第 %d 欄）· 格子 %dx%d px · 倍率 %.2f（所有幀相同）" % [f.cell,
		f.cell / int(sheet.columns), f.cell % int(sheet.columns), cs.x, cs.y, current_zoom()]
	lines.append(line2)
	if info.get("empty", true):
		lines.append("這一格是空的或超出圖集。")
	else:
		var foot_line := int(sheet.cell_px) - int(sheet.foot_px) - 1
		lines.append("外框 %s · 腳底 y=%d（腳底線 %d，差 %+d）· 腳 x=%.1f · 與第 1 格腳底差 %+d px%s" % [info.bbox,
			info.foot_y, foot_line, int(info.foot_y) - foot_line, info.foot_x, int(info.foot_y) - first_foot,
			"" if (info.touches as PackedStringArray).is_empty() else " · 碰到邊緣：" + ", ".join(info.touches)])
	return "\n".join(lines)


# --- Checks -----------------------------------------------------------------------

func _run_checks() -> void:
	_issues.clear()
	_issue_rows = SpriteCheck.check_sheet(sheet)
	var marks := {}
	for issue: Dictionary in _issue_rows:
		var where := "%s %s 第%d格" % [issue.anim, SpriteCheck.direction_name(sheet, maxi(0, int(issue.dir))), int(issue.frame) + 1] \
			if int(issue.frame) >= 0 else ("%s %s" % [issue.anim, SpriteCheck.direction_name(sheet, maxi(0, int(issue.dir)))] if issue.anim != "" else "圖集")
		var idx := _issues.add_item("%s  %s：%s" % ["✖" if issue.level == "error" else "▲", where, issue.text])
		_issues.set_item_custom_fg_color(idx, Color(1, 0.45, 0.4) if issue.level == "error" else Color(1, 0.8, 0.35))
		if int(issue.cell) >= 0:
			marks[int(issue.cell)] = "error" if issue.level == "error" or marks.get(int(issue.cell), "") == "error" else "warn"
	if _issue_rows.is_empty():
		var idx := _issues.add_item("✔ 沒有發現問題：格號都在圖集內、沒有空白格、沒有碰邊、腳底對齊。")
		_issues.set_item_custom_fg_color(idx, Color(0.55, 0.95, 0.55))
	_atlas.marks = marks


func _on_issue(index: int) -> void:
	if index >= _issue_rows.size():
		return
	var issue: Dictionary = _issue_rows[index]
	if issue.anim == "":
		return
	for i in _anim_list.item_count:
		if _anim_list.get_item_text(i).get_slice(" ", 0) == issue.anim:
			_anim_list.select(i)
			select_anim(StringName(issue.anim))
	select_direction(maxi(0, int(issue.dir)))
	set_playing(false)
	if int(issue.frame) >= 0:
		show_frame(int(issue.frame))


func _on_atlas_cell(cell: int) -> void:
	for i in _frames.size():
		if _frames[i].cell == cell:
			set_playing(false)
			show_frame(i)
			return
	_info.text = "格號 %d 不在目前的動畫／方向裡。" % cell
