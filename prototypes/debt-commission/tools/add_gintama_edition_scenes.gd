extends SceneTree
## Applied once to the existing edition scenes; refuses to duplicate the selector or rewrite
## generated Gintama scenes. The saved scenes remain the editable source.

const STYLES = preload("res://scripts/ui_styles.gd")

const STYLE_IDS: Array[String] = ["cinema", "ledger", "manga"]
const ORNAMENT_SCRIPT: Script = preload("res://scripts/ui_ornament.gd")
const WAVE_TEXTURE: Texture2D = preload("res://assets/ui/gintama_seigaiha.svg")
const SAKURA_TEXTURE: Texture2D = preload("res://assets/ui/gintama_sakura_corner.svg")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for kind: String in ["title_screen", "menu_panel", "dialogue_box", "choice_item", "choice_sheet"]:
		if ResourceLoader.exists("res://scenes/ui/%s_gintama.tscn" % kind):
			push_error("Migration already applied: edit the saved scenes directly.")
			quit(1)
			return
	for style_id: String in STYLE_IDS:
		for kind: String in ["title_screen", "menu_panel"]:
			var path: String = "res://scenes/ui/%s_%s.tscn" % [kind, style_id]
			var root: Node = _instantiate(path)
			if root == null:
				quit(1)
				return
			if not _ensure_style_grid(root, path):
				root.free()
				quit(1)
				return
			if not _save_scene(root, path):
				quit(1)
				return

	if not _make_variant("res://scenes/ui/title_screen_manga.tscn", "res://scenes/ui/title_screen_gintama.tscn", "gintama"):
		quit(1)
		return
	if not _make_variant("res://scenes/ui/menu_panel_manga.tscn", "res://scenes/ui/menu_panel_gintama.tscn", "gintama"):
		quit(1)
		return
	if not _make_variant("res://scenes/ui/dialogue_box_manga.tscn", "res://scenes/ui/dialogue_box_gintama.tscn", "gintama", true):
		quit(1)
		return
	if not _make_variant("res://scenes/ui/choice_item_ledger.tscn", "res://scenes/ui/choice_item_gintama.tscn", "gintama"):
		quit(1)
		return
	if not _make_variant("res://scenes/ui/choice_sheet_ledger.tscn", "res://scenes/ui/choice_sheet_gintama.tscn", "gintama"):
		quit(1)
		return
	print("GINTAMA SCENES SAVED with PackedScene.pack")
	quit(0)


func _ensure_style_grid(root: Node, path: String) -> bool:
	var existing: Button = root.find_child("Style_gintama", true, false) as Button
	if existing != null:
		if existing.get_parent() is GridContainer and (existing.get_parent() as GridContainer).columns == 2:
			return true
		push_error("Refusing to replace a partial or hand-edited style picker: %s" % path)
		return false
	var cinema: Button = root.find_child("Style_cinema", true, false) as Button
	var ledger: Button = root.find_child("Style_ledger", true, false) as Button
	var manga: Button = root.find_child("Style_manga", true, false) as Button
	if cinema == null or ledger == null or manga == null or cinema.get_parent() != ledger.get_parent() or ledger.get_parent() != manga.get_parent():
		push_error("Could not find the three existing edition buttons in %s" % path)
		return false
	var old_row: Control = cinema.get_parent() as Control
	if not old_row is HBoxContainer:
		push_error("Expected the original horizontal selector in %s" % path)
		return false
	var parent: Node = old_row.get_parent()
	var index: int = old_row.get_index()
	var grid: GridContainer = GridContainer.new()
	grid.name = old_row.name
	grid.columns = 2
	grid.size_flags_horizontal = old_row.size_flags_horizontal
	grid.size_flags_vertical = old_row.size_flags_vertical
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	parent.remove_child(old_row)
	parent.add_child(grid)
	grid.owner = root
	parent.move_child(grid, index)
	for button: Button in [cinema, ledger, manga]:
		button.owner = null
		old_row.remove_child(button)
		grid.add_child(button)
		button.owner = root
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)
	var gintama: Button = manga.duplicate() as Button
	gintama.name = "Style_gintama"
	gintama.unique_name_in_owner = true
	gintama.text = "D 銀魂和紙"
	gintama.tooltip_text = "銀魂和紙"
	gintama.button_group = manga.button_group
	gintama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gintama.custom_minimum_size.y = maxf(gintama.custom_minimum_size.y, 48.0)
	grid.add_child(gintama)
	gintama.owner = root
	old_row.free()
	return true


func _make_variant(source_path: String, target_path: String, style_id: String, add_corner_art: bool = false) -> bool:
	if ResourceLoader.exists(target_path):
		push_error("Refusing to overwrite existing scene %s" % target_path)
		return false
	var root: Node = _instantiate(source_path)
	if root == null:
		return false
	_set_style_id(root, style_id)
	_set_ornament_styles(root, style_id)
	_bake_palette(root)
	if add_corner_art and not _add_dialogue_corners(root):
		root.free()
		return false
	if target_path.contains("choice_sheet"):
		root.set("item_scene", load("res://scenes/ui/choice_item_gintama.tscn"))
	return _save_scene(root, target_path)


func _add_dialogue_corners(root: Node) -> bool:
	var frame: Control = root.find_child("Frame", true, false) as Control
	if frame == null or frame.get_script() != ORNAMENT_SCRIPT:
		push_error("The dialogue scene has no editable ornament Frame")
		return false
	_add_name_plate(root)
	var gap: Control = root.find_child("FooterGap", true, false) as Control
	gap.custom_minimum_size.y = 78.0
	var waves: TextureRect = _corner_texture("Seigaiha", WAVE_TEXTURE, false)
	var sakura: TextureRect = _corner_texture("Sakura", SAKURA_TEXTURE, true)
	frame.add_child(waves)
	frame.add_child(sakura)
	waves.owner = root
	sakura.owner = root
	return true


func _corner_texture(node_name: String, texture: Texture2D, right_corner: bool) -> TextureRect:
	var result: TextureRect = TextureRect.new()
	result.name = node_name
	result.texture = texture
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	result.anchor_top = 1.0
	result.anchor_bottom = 1.0
	if right_corner:
		result.anchor_left = 1.0
		result.anchor_right = 1.0
		result.offset_left = -196.0
		result.offset_top = -108.0
		result.offset_right = -8.0
		result.offset_bottom = -4.0
	else:
		result.anchor_left = 0.0
		result.anchor_right = 0.0
		result.offset_left = 8.0
		result.offset_top = -96.0
		result.offset_right = 238.0
		result.offset_bottom = -4.0
	return result


func _set_style_id(root: Node, style_id: String) -> void:
	for node: Node in _walk(root):
		for property: Dictionary in node.get_property_list():
			if str(property.get("name", "")) == "style_id":
				node.set("style_id", style_id)
				break


func _set_ornament_styles(root: Node, style_id: String) -> void:
	for node: Node in _walk(root):
		if node.get_script() == ORNAMENT_SCRIPT:
			node.set("style_id", style_id)


func _walk(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]
	for child: Node in root.get_children():
		nodes.append_array(_walk(child))
	return nodes


func _instantiate(path: String) -> Node:
	var packed: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if packed == null:
		push_error("Could not load scene %s" % path)
		return null
	return packed.instantiate()


func _save_scene(root: Node, path: String) -> bool:
	var expected_nodes: int = _count_nodes(root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(root)
	if pack_error != OK:
		push_error("PackedScene.pack failed for %s: %s" % [path, error_string(pack_error)])
		root.free()
		return false
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("ResourceSaver.save failed for %s: %s" % [path, error_string(save_error)])
		root.free()
		return false
	var reloaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if reloaded == null:
		push_error("Saved scene could not be reloaded: %s" % path)
		root.free()
		return false
	var check: Node = reloaded.instantiate()
	var actual_nodes: int = _count_nodes(check)
	check.free()
	root.free()
	if actual_nodes != expected_nodes:
		push_error("Node count changed while packing %s: %d -> %d" % [path, expected_nodes, actual_nodes])
		return false
	print("SAVED %s (%d nodes)" % [path, actual_nodes])
	return true


func _count_nodes(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count_nodes(child)
	return total


func _bake_palette(root: Node) -> void:
	for node: Node in _walk(root):
		if node is Label:
			var label: Label = node as Label
			label.add_theme_color_override("font_color", Color("#203047"))
			label.add_theme_color_override("font_outline_color", Color("#f4eddf"))
			label.add_theme_constant_override("outline_size", 0)
		elif node is Button:
			var button: Button = node as Button
			var old: StyleBox = button.get_theme_stylebox("normal")
			var margins: Vector4 = Vector4(old.content_margin_left, old.content_margin_top, old.content_margin_right, old.content_margin_bottom)
			var role: String = "primary" if node.name in ["Begin", "BokeTsukkomi", "Super"] else "standard"
			STYLES.apply_button(button, "gintama", role)
			button.remove_meta("ui_style_role")
			button.remove_meta("ui_style_active")
			for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
				var box: StyleBoxFlat = button.get_theme_stylebox(state) as StyleBoxFlat
				box.content_margin_left = margins.x
				box.content_margin_top = margins.y
				box.content_margin_right = margins.z
				box.content_margin_bottom = margins.w
				box.set_border_width_all(5 if state == "focus" else 2)
			button.add_theme_color_override("font_hover_pressed_color", button.get_theme_color("font_pressed_color"))
		elif node is ColorRect and node.name != "Dim":
			(node as ColorRect).color = Color(0.25, 0.4, 0.52, 0.25)
	var advance: Button = root.find_child("Advance", true, false) as Button
	if advance != null:
		advance.text = "▾"
		for child: Node in advance.get_children():
			if child.get_script() == ORNAMENT_SCRIPT:
				child.free()


func _add_name_plate(root: Node) -> void:
	var row: HBoxContainer = root.find_child("SpeakerRow", true, false) as HBoxContainer
	var plate: PanelContainer = PanelContainer.new()
	plate.name = "NamePlate"
	row.add_child(plate)
	row.move_child(plate, 0)
	plate.owner = root
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = STYLES.panel_style("gintama", "name", 2.0)
	style.border_color = Color("#9eb8c9")
	plate.add_theme_stylebox_override("panel", style)
	var content: HBoxContainer = HBoxContainer.new()
	content.name = "NameContents"
	content.add_theme_constant_override("separation", 14)
	plate.add_child(content)
	content.owner = root
	for child_name: String in ["SpeakerMark", "SpeakerName"]:
		var label: Label = row.get_node(child_name) as Label
		label.owner = null
		label.reparent(content)
		label.owner = root
		label.unique_name_in_owner = true
		label.add_theme_color_override("font_color", Color("#f8f3e9"))
		if child_name == "SpeakerMark":
			label.text = "❀"
			label.custom_minimum_size.x = 40
