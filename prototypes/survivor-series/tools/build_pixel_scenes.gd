extends SceneTree
## Pixel pass (docs/pixel-ui-plan.md P1): every sprite that shows original art from assets/art/ gets a pixel version
## sized so one art pixel covers PIXEL screen px through the camera's ZOOM, and its scale/offset change so it keeps
## its world size. Gameplay sizes do not change. Run in three steps:
##   godot --headless --path . -s tools/build_pixel_scenes.gd -- --plan     writes art_src/pixel-style/jobs.json
##   uv run --no-project --with pillow --with numpy python tools/pixelize.py writes assets/pixel/**
##   godot --headless --path . --import && godot --headless --path . -s tools/build_pixel_scenes.gd
## The last step edits the saved scenes once; after that the scenes are the source. It refuses to run twice.
## A redrawn pixel sprite (P2) simply replaces its file in assets/pixel/ under the same name.

const PIXEL := 2.0
const ZOOM := 0.72
const JOBS := "res://art_src/pixel-style/jobs.json"
## Soft light overlays stay smooth, like PokéSurvivor's glows and shadows.
const SMOOTH := ["lantern_glow.png", "wet_reflection.png", "pavement.png"]
const UI_ICON := 24
const GROUND_TILES := 8
var jobs: Dictionary = {}
var plan: bool = false

func _init() -> void:
	plan = "--plan" in OS.get_cmdline_user_args()
	var scenes: Array[String] = []
	for folder: String in ["res://scenes/", "res://scenes/props/"]:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".tscn"):
				scenes.append(folder + file)
	if not plan and FileAccess.file_exists("res://assets/pixel/.applied"):
		push_error("pixel pass already applied; edit the scenes directly")
		quit(1)
		return
	for path: String in scenes:
		_scene(path)
	_icons()
	_ground()
	if plan:
		var file := FileAccess.open(JOBS, FileAccess.WRITE)
		file.store_string(JSON.stringify(jobs.values(), "\t"))
		print("planned %d pixel images -> %s" % [jobs.size(), JOBS])
	else:
		FileAccess.open("res://assets/pixel/.applied", FileAccess.WRITE).store_string(Time.get_datetime_string_from_system())
	quit()

## The pixel file for `source` shrunk by `factor` (pixel px per source px).
func _job(source: Texture2D, factor: float, kind: String = "sprite") -> Dictionary:
	var path: String = source.resource_path
	var height: int = maxi(1, roundi(source.get_height() * factor))
	var width: int = maxi(1, roundi(source.get_width() * factor))
	var out: String = path.replace("res://assets/art/", "res://assets/pixel/").get_basename() + "_%d.png" % height
	var job := {"src": ProjectSettings.globalize_path(path), "out": ProjectSettings.globalize_path(out), "res": out, "width": width, "height": height, "kind": kind}
	jobs[out] = job
	return job

func _art(texture: Texture2D) -> bool:
	return texture != null and texture.resource_path.begins_with("res://assets/art/") and texture.resource_path.ends_with(".png") and texture.resource_path.get_file() not in SMOOTH

func _scene(path: String) -> void:
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var before: int = _count(root)
	var changed: bool = false
	for sprite: Sprite2D in _own_sprites(root, root):
		if not _art(sprite.texture):
			continue
		var reach: float = 1.0
		var node: Node = sprite
		while node != root:
			reach *= absf((node as Node2D).scale.x) if node is Node2D else 1.0
			node = node.get_parent()
		var factor: float = reach * ZOOM / PIXEL
		var job: Dictionary = _job(sprite.texture, factor)
		var textures: Array = []
		if sprite.name == "Art" and "direction_textures" in root and not root.direction_textures.is_empty():
			for each: Texture2D in root.direction_textures:
				textures.append(_job(each, factor))
		if plan:
			continue
		var ratio: float = float(job.height) / sprite.texture.get_height()
		sprite.texture = load(job.res)
		sprite.scale /= ratio
		sprite.offset = sprite.offset * ratio - (Vector2.ZERO if sprite.centered else Vector2.ONE)
		if not textures.is_empty():
			var swapped: Array[Texture2D] = []
			for each: Dictionary in textures:
				swapped.append(load(each.res))
			root.direction_textures = swapped
		changed = true
	if changed:
		_save(root, path, before)
	else:
		root.free()

## Sprites that belong to this scene, not to instanced sub-scenes.
func _own_sprites(node: Node, root: Node) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for child: Node in node.get_children():
		if child.owner != root:
			continue
		if child is Sprite2D:
			found.append(child)
		if child.scene_file_path.is_empty():
			found.append_array(_own_sprites(child, root))
	return found

## Card and slot icons: 24 px pixel versions, drawn at 2× in the UI.
func _icons() -> void:
	for file: String in DirAccess.get_files_at("res://data/items/"):
		if not file.ends_with(".tres"):
			continue
		var item: Resource = load("res://data/items/" + file)
		if not "icon" in item or not _art(item.icon):
			continue
		var job: Dictionary = _job(item.icon, float(UI_ICON) / item.icon.get_height(), "icon")
		if not plan:
			item.icon = load(job.res)
			assert(ResourceSaver.save(item) == OK)

## Pavement: a seamless tile pixelized with wrap-around, repeated GROUND_TILES times across the ground sprite.
func _ground() -> void:
	var path := "res://scenes/street.tscn"
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var before: int = _count(root)
	var ground: Sprite2D = root.get_node("Map/Ground")
	var job: Dictionary = _job(ground.texture, ZOOM / PIXEL, "tile")
	if plan:
		root.free()
		return
	var ratio: float = float(job.height) / ground.texture.get_height()
	ground.texture = load(job.res)
	ground.scale = Vector2.ONE / ratio
	ground.region_rect = Rect2(Vector2.ZERO, Vector2(job.width, job.height) * GROUND_TILES)
	_save(root, path, before)

func _save(root: Node, path: String, before: int) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(root) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	root.free()
	var check: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var after: int = _count(check)
	check.free()
	assert(after == before, "%s: %d nodes before, %d after" % [path, before, after])
	print("pixel: ", path)

func _count(node: Node) -> int:
	var total: int = 1
	for child: Node in node.get_children():
		total += _count(child)
	return total
