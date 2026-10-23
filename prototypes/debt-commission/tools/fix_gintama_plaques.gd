extends SceneTree
## One-off authoring tool: keeps the cloud plaques from being stretched.
## - Title: the story label is one line on the plaque art drawn at the button's height
##   (gintama_heading_plaque_tall.png), so the cloud keeps its proportions.
## - Reading box: the speaker plaque is a NinePatchRect whose cloud (left) and voice end (right)
##   never stretch; only the navy middle grows when a long name widens the plaque, and the name
##   fills the space between them.
## After it runs the scenes are the source files.
##   godot --headless --path . --script res://tools/fix_gintama_plaques.gd

const TITLE: String = "res://scenes/ui/title_screen_gintama.tscn"
const BOX: String = "res://scenes/ui/dialogue_box_gintama.tscn"
const TALL: String = "res://assets/ui/gintama_heading_plaque_tall.png"


func _init() -> void:
	if not _title() or not _box():
		return
	quit()


func _title() -> bool:
	var root: Node = (load(TITLE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var button: Button = root.find_child("StorySwitch", true, false) as Button
	var box: StyleBoxTexture = (button.get_theme_stylebox("normal") as StyleBoxTexture).duplicate() as StyleBoxTexture
	box.texture = load(TALL) as Texture2D
	box.texture_margin_left = 104.0
	box.texture_margin_right = 65.0
	box.texture_margin_top = 32.0
	box.texture_margin_bottom = 32.0
	box.content_margin_left = 120.0
	box.content_margin_right = 80.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.custom_minimum_size = Vector2(0, 132.92308)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.clip_text = true
	button.text = "第一章　章節選擇 ›"
	return _save(root, TITLE)


func _box() -> bool:
	var root: Node = (load(BOX) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var old: TextureRect = root.find_child("CloudPlaque", true, false) as TextureRect
	if old == null:
		print("dialogue box plaque is already a NinePatchRect")
		root.free()
		return true
	var plate: Control = old.get_parent() as Control
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = old.texture
	patch.patch_margin_left = 64
	patch.patch_margin_right = 72
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: int = old.get_index()
	plate.remove_child(old)  # first, so the new node can take its name
	old.free()
	patch.name = "CloudPlaque"
	plate.add_child(patch)
	plate.move_child(patch, index)
	patch.owner = root
	patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label: Label = root.find_child("SpeakerName", true, false) as Label
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 71.0
	label.offset_top = 5.0
	label.offset_right = -79.0
	label.offset_bottom = -10.0
	return _save(root, BOX)


func _save(root: Node, path: String) -> bool:
	var before: int = _count(root)
	var packed: PackedScene = PackedScene.new()
	if packed.pack(root) != OK:
		return _fail("pack " + path)
	var check: Node = packed.instantiate()
	var after: int = _count(check)
	check.free()
	root.free()
	if after != before:
		return _fail("%s: node count %d -> %d" % [path, before, after])
	if ResourceSaver.save(packed, path) != OK:
		return _fail("save " + path)
	print("%s: %d nodes" % [path, after])
	return true


func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
