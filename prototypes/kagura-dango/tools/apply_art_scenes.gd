extends SceneTree
## Applies scene-owned sprite nodes and texture assignments through Godot's PackedScene serializer.

const SPRITES := "res://assets/sprites"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_create_shopkeeper_scene()
	_update_actor()
	_update_skewer()
	_update_stage()
	_update_title()
	_update_three_eat()
	_update_toss_game()
	quit()


func _update_actor() -> void:
	var root := _open_scene("res://scenes/actor.tscn")
	var label := root.get_node("NameLabel") as Label
	label.unique_name_in_owner = true
	var name_plate := root.get_node_or_null("NamePlate") as Panel
	if name_plate == null:
		name_plate = Panel.new()
		name_plate.name = "NamePlate"
		root.add_child(name_plate)
		root.move_child(name_plate, label.get_index())
		name_plate.owner = root
	name_plate.position = Vector2(-48, 2)
	name_plate.size = Vector2(96, 28)
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_plate.z_index = 1
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.06, 0.12, 0.18, 0.94)
	plate_style.border_color = Color(0.94, 0.72, 0.39, 1.0)
	plate_style.set_border_width_all(2)
	plate_style.set_corner_radius_all(5)
	plate_style.set_content_margin_all(4)
	name_plate.add_theme_stylebox_override("panel", plate_style)
	label.z_index = 2
	label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.12, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	for child_name in ["Body", "Head", "Sweat"]:
		var old := root.get_node_or_null(NodePath(child_name))
		if old:
			root.remove_child(old)
			old.free()
	var sprite := root.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		root.add_child(sprite)
		sprite.owner = root
	sprite.unique_name_in_owner = true
	sprite.texture = load(SPRITES.path_join("gintoki_idle_0.png")) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -96)
	sprite.scale = Vector2(2, 2)
	_save_scene("res://scenes/actor.tscn", root)


func _update_skewer() -> void:
	var root := _open_scene("res://scenes/skewer.tscn")
	var sprite := root.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		root.add_child(sprite)
		sprite.owner = root
	sprite.unique_name_in_owner = true
	sprite.texture = load(SPRITES.path_join("dango_props_0.png")) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2, 2)
	_save_scene("res://scenes/skewer.tscn", root)


func _update_stage() -> void:
	var root := _open_scene("res://scenes/stage.tscn")
	var old_background := root.get_node("Background")
	root.remove_child(old_background)
	old_background.free()
	var background := Sprite2D.new()
	background.name = "Background"
	background.texture = load(SPRITES.path_join("contest_background.png")) as Texture2D
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.position = Vector2(320, 180)
	root.add_child(background)
	root.move_child(background, 0)
	background.owner = root
	root.get_node("Lanterns").visible = false
	root.get_node("BackTable").visible = false
	root.get_node("Table").visible = false
	root.get_node("RivalA").set("character_id", &"rival_man")
	root.get_node("RivalB").set("character_id", &"rival_woman")
	root.get_node("Referee").set("character_id", &"referee")
	_save_scene("res://scenes/stage.tscn", root)


func _update_title() -> void:
	var root := _open_scene("res://scenes/title.tscn")
	root.get_node("Credit").text = "銀魂同人・非商業｜AI 美術・合成音樂"
	var panel := root.get_node_or_null("MenuPanel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "MenuPanel"
		root.add_child(panel)
		root.move_child(panel, root.get_node("Center").get_index())
		panel.owner = root
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -156
	panel.offset_top = -132
	panel.offset_right = 156
	panel.offset_bottom = 132
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.06, 0.12, 0.19, 0.86)
	menu_style.border_color = Color(0.94, 0.72, 0.39, 0.96)
	menu_style.set_border_width_all(2)
	menu_style.set_corner_radius_all(8)
	menu_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", menu_style)
	root.get_node("Center").z_index = 1
	for label_path in ["Center/Column/GameTitle", "Center/Column/Subtitle", "Center/Column/CalibInfo", "Credit"]:
		var label := root.get_node(label_path) as Label
		label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.12, 1.0))
		label.add_theme_constant_override("outline_size", 2)
	var art := root.get_node_or_null("TitleArt") as TextureRect
	if art == null:
		art = TextureRect.new()
		art.name = "TitleArt"
		root.add_child(art)
		root.move_child(art, 1)
		art.owner = root
	art.texture = load(SPRITES.path_join("title_art.png")) as Texture2D
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_scene("res://scenes/title.tscn", root)


func _update_three_eat() -> void:
	var root := _open_scene("res://scenes/three_eat.tscn")
	for child_name in ["HatchWindow", "Hatch"]:
		var old := root.get_node_or_null(NodePath(child_name))
		if old:
			root.remove_child(old)
			old.free()
	root.get_node("Gintoki").set("character_id", &"gintoki")
	root.get_node("Shinpachi").set("character_id", &"shinpachi")
	root.get_node("Kagura").set("character_id", &"kagura")
	root.get_node("HUD").set("hint_text", "桌上出餐：紅豆→左（銀時）　醬油→中（新八）　三色→右（神樂）；落點拍點選那一側")
	var shopkeeper := root.get_node_or_null("Shopkeeper")
	if shopkeeper == null:
		shopkeeper = (load("res://scenes/shopkeeper.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		shopkeeper.name = "Shopkeeper"
		shopkeeper.unique_name_in_owner = true
		root.add_child(shopkeeper)
		root.move_child(shopkeeper, root.get_node("Gintoki").get_index())
		shopkeeper.owner = root
	shopkeeper.position = Vector2(390, 290)
	shopkeeper.scale = Vector2(0.6, 0.6)
	shopkeeper.visible = true
	_add_marker(root, "ServeOrigin", Vector2(430, 228))
	_add_marker(root, "PlateLeft", Vector2(110, 264))
	_add_marker(root, "PlateMiddle", Vector2(300, 264))
	_add_marker(root, "PlateRight", Vector2(525, 264))
	var old_notice := root.get_node_or_null("ServeNotice")
	if old_notice:
		root.remove_child(old_notice)
		old_notice.free()
	_save_scene("res://scenes/three_eat.tscn", root)


func _create_shopkeeper_scene() -> void:
	var path := "res://scenes/shopkeeper.tscn"
	if ResourceLoader.exists(path):
		return
	var root := Node2D.new()
	root.name = "Shopkeeper"
	root.set_script(load("res://scripts/shopkeeper.gd"))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.unique_name_in_owner = true
	sprite.texture = load(SPRITES.path_join("store_owner_serve.png")) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -96)
	sprite.scale = Vector2(2, 2)
	root.add_child(sprite)
	sprite.owner = root
	_save_scene(path, root)


func _update_toss_game() -> void:
	var root := _open_scene("res://scenes/toss_game.tscn")
	root.get_node("Gintoki").set("character_id", &"gintoki")
	root.get_node("Shinpachi").set("character_id", &"shinpachi")
	root.get_node("Kagura").set("character_id", &"kagura")
	_save_scene("res://scenes/toss_game.tscn", root)


func _add_marker(root: Node, marker_name: String, at: Vector2) -> void:
	var marker := root.get_node_or_null(marker_name) as Marker2D
	if marker == null:
		marker = Marker2D.new()
		marker.name = marker_name
		root.add_child(marker)
		marker.owner = root
	marker.unique_name_in_owner = true
	marker.position = at


func _open_scene(path: String) -> Node:
	var packed := load(path) as PackedScene
	assert(packed != null, "Could not load scene: " + path)
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	assert(root != null, "Could not instantiate scene: " + path)
	return root


func _save_scene(path: String, root: Node) -> void:
	var before_count := _node_count(root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	assert(pack_result == OK, "PackedScene.pack failed for %s: %s" % [path, error_string(pack_result)])
	var saved_count := packed.get_state().get_node_count()
	assert(saved_count > 0, "Packed scene has no nodes: " + path)
	var save_result := ResourceSaver.save(packed, path)
	assert(save_result == OK, "ResourceSaver.save failed for %s: %s" % [path, error_string(save_result)])
	var verification := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	assert(_node_count(verification) >= before_count, "Scene lost nodes while saving %s (%d → %d)" % [path, before_count, _node_count(verification)])
	print("Saved %s: %d live nodes, %d packed nodes, %d after reload" % [path, before_count, saved_count, _node_count(verification)])
	verification.free()
	root.free()


func _node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _node_count(child)
	return total
