extends SceneTree
## Creates scenes/characters/<id>.tscn for every catalog character that has a picture (`path`) and
## no scene yet. Existing scenes are never touched, so framing adjusted in the editor stays:
##   godot --headless --path . --script res://tools/make_character_scenes.gd
## The root is the standing box (placeholder_sprite.gd REFERENCE_SIZE; its bottom edge is the feet
## line) that a stage slot scales; Art starts as tall as the box, standing on its bottom edge.

const Sprite = preload("res://scripts/placeholder_sprite.gd")
const CATALOG_PATH: String = "res://data/asset_catalog.json"
const SCENE_PATH: String = "res://scenes/characters/%s.tscn"


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var characters: Dictionary = catalog["characters"]
	var made: Array[String] = []
	var failed: bool = false
	for id: String in characters.keys():
		var info: Dictionary = characters[id]
		var art_path: String = String(info.get("path", ""))
		if art_path.is_empty() or FileAccess.file_exists(SCENE_PATH % id):
			continue
		var texture: Texture2D = load(art_path) as Texture2D
		if texture == null:
			printerr("CHARACTER SCENES: cannot load %s for %s" % [art_path, id])
			failed = true
			continue
		if _save(_build(id, String(info.get("name", id)), texture)) == OK:
			made.append(id)
		else:
			failed = true
	print("CHARACTER SCENES: made %s" % [made])
	quit(1 if failed else 0)


func _build(id: String, display_name: String, texture: Texture2D) -> Control:
	var root: Control = Control.new()
	root.name = id
	root.size = Sprite.REFERENCE_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.editor_description = "%s 的站姿框。框的底邊是腳底線，站位（scenes/stage.tscn）會把整個框縮放到站位的高度。拖曳、縮放 Art 決定%s在任何站位的大小與位置；框本身不用動。圖以 asset_catalog.json 為準，這裡的圖是預覽。" % [display_name, display_name]
	var box: ReferenceRect = ReferenceRect.new()
	box.name = "Box"
	box.border_color = Color(1.0, 0.65, 0.2)
	box.border_width = 4.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("_edit_lock_", true)
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art: TextureRect = TextureRect.new()
	art.name = "Art"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	var height: float = Sprite.REFERENCE_SIZE.y
	var width: float = height * float(texture.get_width()) / float(texture.get_height())
	art.anchor_left = 0.5
	art.anchor_right = 0.5
	art.anchor_top = 1.0
	art.anchor_bottom = 1.0
	art.offset_left = -width * 0.5
	art.offset_right = width * 0.5
	art.offset_top = -height
	art.offset_bottom = 0.0
	box.owner = root
	art.owner = root
	root.set_script(Sprite)
	return root


func _save(root: Control) -> Error:
	var scene: PackedScene = PackedScene.new()
	var error: Error = scene.pack(root)
	if error == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/characters"))
		error = ResourceSaver.save(scene, SCENE_PATH % String(root.name))
	root.free()
	return error
