extends SceneTree
## Applied once. Saved scenes are editable sources; existing scenes are preserved.
## Requires import_examples.py, then Godot --editor --quit for staged PNGs.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/"
var good: bool = true
var effects: Dictionary = {}
var details: Dictionary = {}

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE + "assets/scenario/index.json"))
	for entry: Dictionary in entries:
		var id: String = entry.id
		var frames := load(BASE + "assets/scenario/%s/%s.tres" % [id, id]) as SpriteFrames
		var size := Vector2(entry.size[0], entry.size[1])
		var pivot := Vector2(entry.pivot[0], entry.pivot[1])
		var scene2 := B.instance(BASE + "2d/sheet_effect.tscn") as AnimatedSprite2D
		scene2.name = id.to_pascal_case()
		scene2.sprite_frames = frames
		scene2.animation = entry.animation
		scene2.offset = (Vector2.ONE * 0.5 - pivot) * size
		scene2.frame = mini(2, entry.frames - 1)
		scene2.set_meta("vfx_source", "scenario")
		scene2.set_meta("vfx_id", id)
		scene2.set_meta("placement", entry.place)
		scene2.set_meta("depth_hint", entry.depth)
		scene2.scene_file_path = ""
		_save(scene2, entry.scene_2d)
		var scene3 := B.instance(BASE + "3d/sheet_effect.tscn") as AnimatedSprite3D
		scene3.name = id.to_pascal_case()
		scene3.sprite_frames = frames
		scene3.animation = entry.animation
		# Sprite3D offset +Y points up; Sprite2D offset +Y points down.
		scene3.offset = Vector2(0.5 - pivot.x, pivot.y - 0.5) * size
		scene3.pixel_size = 0.025
		scene3.frame = mini(2, entry.frames - 1)
		scene3.set_meta("vfx_source", "scenario")
		scene3.set_meta("vfx_id", id)
		scene3.set_meta("placement", entry.place)
		scene3.set_meta("depth_hint", entry.depth)
		scene3.scene_file_path = ""
		_save(scene3, entry.scene_3d)
		effects[id] = {"2d": entry.scene_2d, "3d": entry.scene_3d}
		details[id] = {"name": entry.name, "source": "Scenario", "loop": entry.loop, "duration": float(entry.frames) / entry.fps}
	for shape: String in ["circle", "sector"]:
		var id := "spell-indicator-" + shape
		var effect := Node3D.new()
		effect.name = id.to_pascal_case()
		effect.set_script(load(BASE + "3d/00gamedevs/spell_indicator.gd"))
		effect.angle_degrees = 360.0 if shape == "circle" else 90.0
		var surface := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2.04, 2.04)
		surface.mesh = plane
		surface.position.y = 0.01
		var material := ShaderMaterial.new()
		material.resource_local_to_scene = true
		material.shader = load(BASE + "3d/00gamedevs/spatial_spell_indicator.gdshader")
		material.set_shader_parameter("uHalfAngle", PI if shape == "circle" else PI * 0.25)
		material.set_shader_parameter("uProgress", 0.5)
		material.set_shader_parameter("uOpacity", 1.0)
		material.set_shader_parameter("uDetail", 1.0)
		surface.material_override = material
		B.add(effect, B.unique(surface), "Surface")
		effect.set_meta("vfx_source", "00gamedevs")
		effect.set_meta("vfx_id", id)
		var path := BASE + "3d/00gamedevs/" + id + ".tscn"
		_save(effect, path)
		effects[id] = {"3d": path}
		details[id] = {"name": "Circle telegraph" if shape == "circle" else "Sector telegraph", "source": "00GameDevs", "loop": false, "duration": 2.15}
	_write_library()
	quit(0 if good else 1)

func _write_library() -> void:
	var path := BASE + "library.gd"
	if FileAccess.file_exists(path):
		print("skip existing library.gd; update it manually when adding scenes")
		return
	var text := "extends RefCounted\n## Saved scene catalog. Preloads keep dependencies in selected-scene exports.\nconst EFFECTS := {\n"
	for id: String in effects:
		text += "\t\"%s\": {" % id
		for dimension: String in effects[id]:
			text += "\"%s\": preload(\"%s\"), " % [dimension, effects[id][dimension]]
		text += "},\n"
	text += "}\nconst DETAILS := " + JSON.stringify(details, "\t") + "\n\n"
	text += "static func get_scene(id: String, dimension: String = \"2d\") -> PackedScene:\n\treturn EFFECTS.get(id, {}).get(dimension) as PackedScene\n\n"
	text += "static func ids(dimension: String = \"2d\") -> PackedStringArray:\n\tvar result := PackedStringArray()\n\tfor id: String in EFFECTS:\n\t\tif EFFECTS[id].has(dimension):\n\t\t\tresult.append(id)\n\treturn result\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _save(node: Node, path: String, refs: Array = []) -> void:
	var result := B.save_scene(node, path, {"expected_refs": refs})
	good = result.ok and good
