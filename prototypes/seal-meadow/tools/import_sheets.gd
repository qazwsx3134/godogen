extends SceneTree
## Turns every sheets.json that tools/blender/pack_layers.py wrote under res://assets/sprites/ into a sheet resource
## res://resources/sheets/<character>.tres (character = "<name>_<layer>"), which scenes reference.
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/import_sheets.gd
## Rerun after every pack: the .tres only points at the atlas and copies its grid, so it holds no hand edits.

const Sheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")


func _initialize() -> void:
	var count := 0
	for json_path in _find("res://assets/sprites", "sheets.json"):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		for character: String in data.get("characters", {}):
			var sheet: Resource = Sheet.from_json(json_path, character)
			if sheet.atlas == null:
				push_error("%s: atlas not imported yet (run --import first)" % json_path)
				quit(1)
				return
			var out := "res://resources/sheets/%s.tres" % character
			DirAccess.make_dir_recursive_absolute(out.get_base_dir())
			if ResourceSaver.save(sheet, out) != OK:
				push_error("cannot save " + out)
				quit(1)
				return
			print("sheet: ", out)
			count += 1
	print("%d sheets" % count)
	quit(0)


func _find(dir: String, file: String) -> Array[String]:
	var found: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		found.append_array(_find(dir.path_join(sub), file))
	if FileAccess.file_exists(dir.path_join(file)):
		found.append(dir.path_join(file))
	return found
