extends SceneTree
## One-off authoring tool: creates scenes/ui/episode_card.tscn, the 章節選擇 card of a chapter in the
## manner of an episode map (a picture card under a 「第 N 章」 plaque, dots linking it to the card
## above, brush corners on the current one, who wrote and drew it under the card), and puts two of them in place of the 本篇 previews in
## chapter_select.tscn. Skips whatever already exists; after it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/add_episode_cards.gd

const CARD_PATH: String = "res://scenes/ui/episode_card.tscn"
const SELECT_PATH: String = "res://scenes/ui/chapter_select.tscn"
const PREVIEW_PICTURE: String = "res://assets/image/kitchen.png"
const INK: Color = Color("#fffdf5")


func _init() -> void:
	if not ResourceLoader.exists(CARD_PATH) and not _pack_over(_card(), CARD_PATH, 14):
		return
	if not _swap_previews():
		return
	quit()


func _card() -> MarginContainer:
	var root: MarginContainer = MarginContainer.new()
	root.name = "EpisodeCard"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("margin_bottom", 30)  # room for the brush corners below the card
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 0)
	_own(root, column)
	var dots: Label = _label("Dots", "⋮", 56, "muted")
	dots.custom_minimum_size = Vector2(0, 64)
	dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_own(column, dots)
	var frame: Control = Control.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(0, 340)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(column, frame)
	var card: Button = Button.new()
	card.name = "Card"
	card.unique_name_in_owner = true
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.offset_top = 44.0
	card.set_meta("ui_style_role", "selector")
	_own(frame, card)
	var thumb: TextureRect = TextureRect.new()
	thumb.name = "Thumb"
	thumb.unique_name_in_owner = true
	_inset(thumb, 10.0)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.clip_contents = true
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.texture = load(PREVIEW_PICTURE) as Texture2D
	_own(card, thumb)
	var shade: ColorRect = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.03, 0.06, 0.1, 0.74)
	shade.anchor_top = 1.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.offset_left = 10.0
	shade.offset_top = -132.0
	shade.offset_right = -10.0
	shade.offset_bottom = -10.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(card, shade)
	var title: Label = _label("Title", "萬事屋冰箱草莓牛奶失竊事件", 36, "")
	title.unique_name_in_owner = true
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.anchor_top = 1.0
	title.anchor_right = 1.0
	title.anchor_bottom = 1.0
	title.offset_left = 30.0
	title.offset_top = -128.0
	title.offset_right = -30.0
	title.offset_bottom = -70.0
	_own(card, title)
	var badge: Label = _label("Badge", "最佳評價 S・結局 1/2", 30, "")
	badge.unique_name_in_owner = true
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 30.0
	badge.offset_top = -72.0
	badge.offset_right = -30.0
	badge.offset_bottom = -16.0
	_own(card, badge)
	var lock: Label = _label("Lock", "完成前一章後開放", 38, "")
	lock.unique_name_in_owner = true
	lock.visible = false
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.1, 0.9))
	lock.add_theme_constant_override("outline_size", 10)
	_own(card, lock)
	var plaque: PanelContainer = PanelContainer.new()
	plaque.name = "Plaque"
	plaque.unique_name_in_owner = true
	plaque.anchor_left = 0.5
	plaque.anchor_right = 0.5
	plaque.offset_left = -150.0
	plaque.offset_right = 150.0
	plaque.offset_bottom = 84.0
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own(frame, plaque)
	var number: Label = _label("Number", "第 1 章", 40, "")
	number.unique_name_in_owner = true
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_own(plaque, number)
	var corners: Control = Control.new()
	corners.name = "Corners"
	corners.unique_name_in_owner = true
	corners.set_script(load("res://scripts/brush_corners.gd"))
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.offset_top = 44.0
	corners.visible = false
	_own(frame, corners)
	var credit: Label = _label("Credit", "劇本 作者名字｜繪 畫師名字", 28, "muted")
	credit.unique_name_in_owner = true
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_own(column, credit)
	return root


## The 本篇 list's two chapter_row previews become episode cards (the second as the current one).
func _swap_previews() -> bool:
	var select: Node = (load(SELECT_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var chapters: Node = select.find_child("Chapters", true, false)
	if chapters.get_child_count() > 0 and chapters.get_child(0).scene_file_path == CARD_PATH:
		print("chapter_select already shows episode cards")
		select.free()
		return true
	var before: int = _count(select)
	var removed: int = 0
	for preview: Node in chapters.get_children():
		removed += _count(preview)
		chapters.remove_child(preview)
		preview.free()
	chapters.add_theme_constant_override("separation", 0)
	for index: int in range(2):
		var card: Control = (load(CARD_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Control
		card.name = "Preview%d" % index
		chapters.add_child(card)
		card.owner = select
		if index == 0:
			card.get_node("Column/Dots").visible = false
		else:
			card.get_node("Column/Frame/Corners").visible = true
			card.get_node("Column/Frame/Plaque/Number").text = "第 2 章"
	return _pack_over(select, SELECT_PATH, before - removed + 28)


func _label(node_name: String, text: String, font_size: int, role: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if role.is_empty():
		label.add_theme_color_override("font_color", INK)
	else:
		label.set_meta("ui_style_role", role)
	return label


func _inset(control: Control, margin: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = margin
	control.offset_top = margin
	control.offset_right = -margin
	control.offset_bottom = -margin


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


func _own(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent if parent.owner == null else parent.owner


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
