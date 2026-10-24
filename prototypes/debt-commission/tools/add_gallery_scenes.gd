extends SceneTree
## One-off authoring tool for 鑑賞: creates scenes/ui/gallery_panel.tscn with its item scenes
## gallery_picture.tscn and gallery_track.tscn, and adds 鑑賞 (%Gallery) to the 章節選擇 header.
## Layout follows chapter_select.tscn; colours come from the ui_style_role metadata. Skips whatever
## already exists; after it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_gallery_scenes.gd

const PICTURE_PATH: String = "res://scenes/ui/gallery_picture.tscn"
const TRACK_PATH: String = "res://scenes/ui/gallery_track.tscn"
const PANEL_PATH: String = "res://scenes/ui/gallery_panel.tscn"
const SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const PREVIEW_PICTURE: String = "res://assets/image/yorosuya-inside.png"


func _init() -> void:
	if not ResourceLoader.exists(PICTURE_PATH) and not _save(_picture(), PICTURE_PATH, 4):
		return
	if not ResourceLoader.exists(TRACK_PATH) and not _save(_track(), TRACK_PATH, 1):
		return
	if not ResourceLoader.exists(PANEL_PATH) and not _save(_panel(), PANEL_PATH, 25):
		return
	if not _add_gallery_button():
		return
	quit()


## A thumbnail card: the picture above its name; disabled (？？？, no picture) until seen.
func _picture() -> Button:
	var card: Button = Button.new()
	card.name = "GalleryPicture"
	card.custom_minimum_size = Vector2(0, 380)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("ui_style_role", "selector")
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12.0
	column.offset_top = 12.0
	column.offset_right = -12.0
	column.offset_bottom = -12.0
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(card, column)
	var thumb: TextureRect = TextureRect.new()
	thumb.name = "Thumb"
	thumb.unique_name_in_owner = true
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.clip_contents = true
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.texture = load(PREVIEW_PICTURE) as Texture2D
	_own(column, thumb)
	var caption: Label = Label.new()
	caption.name = "Caption"
	caption.unique_name_in_owner = true
	caption.text = "萬事屋・客廳"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 34)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.set_meta("ui_style_role", "body")
	_own(column, caption)
	return card


func _track() -> Button:
	var row: Button = Button.new()
	row.name = "GalleryTrack"
	row.text = "♪ 日常"
	row.custom_minimum_size = Vector2(0, 132.92308)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_theme_font_size_override("font_size", 40)
	row.set_meta("ui_style_role", "selector")
	return row


## Header (鑑賞, ×), tabs (畫廊, 音樂) with the count, a scrolling list holding the picture grid
## and the track column, the full-screen viewer, and the preview player.
func _panel() -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "GalleryPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_script(load("res://scripts/gallery_panel.gd"))
	panel.set_meta("ui_style_role", "log")
	var margins: MarginContainer = MarginContainer.new()
	margins.name = "Margins"
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	_own(panel, margins)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 24)
	_own(margins, layout)
	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size = Vector2(0, 112)
	header.add_theme_constant_override("separation", 16)
	_own(layout, header)
	var heading: Label = Label.new()
	heading.name = "Heading"
	heading.text = "鑑賞"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 52)
	heading.set_meta("ui_style_role", "accent")
	_own(header, heading)
	_own(header, _button("Close", "×", 60, Vector2(132.92308, 132.92308), "standard"))
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 16)
	_own(layout, tabs)
	for pair: Array in [["PicturesTab", "畫廊"], ["MusicTab", "音樂"]]:
		var tab_button: Button = _button(pair[0], pair[1], 42, Vector2(0, 132.92308), "selector")
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_own(tabs, tab_button)
	var progress: Label = Label.new()
	progress.name = "Progress"
	progress.unique_name_in_owner = true
	progress.text = "已看過 1/3"
	progress.add_theme_font_size_override("font_size", 34)
	progress.set_meta("ui_style_role", "muted")
	_own(layout, progress)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_own(layout, scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_own(scroll, list)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Pictures"
	grid.unique_name_in_owner = true
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	_own(list, grid)
	for index: int in range(2):
		var preview: Button = (load(PICTURE_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Button
		preview.name = "Preview%d" % index
		_own(grid, preview)
	var music: VBoxContainer = VBoxContainer.new()
	music.name = "Music"
	music.unique_name_in_owner = true
	music.visible = false
	music.add_theme_constant_override("separation", 12)
	_own(list, music)
	var viewer: ColorRect = ColorRect.new()
	viewer.name = "Viewer"
	viewer.unique_name_in_owner = true
	viewer.color = Color(0.02, 0.025, 0.04, 0.96)
	viewer.visible = false
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_own(panel, viewer)
	var picture: TextureRect = TextureRect.new()
	picture.name = "ViewerPicture"
	picture.unique_name_in_owner = true
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(viewer, picture)
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Player"
	player.unique_name_in_owner = true
	_own(panel, player)
	return panel


func _add_gallery_button() -> bool:
	var select: Node = (load(SELECT_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var header: Node = select.get_node("Margins/Layout/Header")
	if header.has_node("Gallery"):
		print("chapter_select already has Gallery")
		select.free()
		return true
	var before: int = _count(select)
	var button: Button = _button("Gallery", "鑑賞", 38, Vector2(0, 132.92308), "standard")
	header.add_child(button)
	header.move_child(button, header.get_node("Credits").get_index())
	button.owner = select
	return _pack_over(select, SELECT_PATH, before + 1)


func _button(node_name: String, text: String, font_size: int, minimum: Vector2, role: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.text = text
	button.custom_minimum_size = minimum
	button.add_theme_font_size_override("font_size", font_size)
	button.set_meta("ui_style_role", role)
	return button


## false (exit code 1 set) when packing, the node count or saving fails.
func _pack_over(root: Node, path: String, expected: int) -> bool:
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		return _fail("pack " + path)
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	root.free()
	if after != expected:
		return _fail("%s: node count %d, expected %d" % [path, after, expected])
	if ResourceSaver.save(packed, path) != OK:
		return _fail("save " + path)
	print("%s: %d nodes" % [path, after])
	return true


func _save(root: Node, path: String, expected: int) -> bool:
	return _pack_over(root, path, expected)


## `child` under `parent`, owned by the root of what is being built.
func _own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	var root: Node = parent if parent.owner == null else parent.owner
	child.owner = root


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
