extends SceneTree
## After importing the PNG with --editor --quit:
## godot --headless --path . -s res://tools/vfx/import_strip.gd -- \
##   res://assets/fire.png res://assets/fire.tres 18 15 once SOURCE_URL LICENSE_NOTE
## Horizontal strip only; does not infer or change the source's timing or pivot.
const SheetFrames = preload("res://addons/proto_kit/vfx/sheet_frames.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 7:
		_fail("Expected: sheet.png output.tres frame_count fps once|loop source_url license_note")
		return
	if not args[0].begins_with("res://") or not args[1].begins_with("res://") or args[1].get_extension() != "tres":
		_fail("Input/output must be res:// paths; output must end in .tres")
		return
	if FileAccess.file_exists(args[1]) or FileAccess.file_exists(args[1] + ".source.json"):
		_fail("Output exists; choose a new name to preserve authored resources")
		return
	if not args[2].is_valid_int() or not args[3].is_valid_float() or args[4] not in ["once", "loop"]:
		_fail("Invalid frame count, fps, or playback mode")
		return
	if args[5].strip_edges().is_empty() or args[6].strip_edges().is_empty():
		_fail("Record a source and license note (use unverified when not yet confirmed)")
		return
	var texture := load(args[0]) as Texture2D
	var frames := SheetFrames.build(texture, args[2].to_int(), args[3].to_float(), args[4] == "loop")
	if frames == null:
		_fail("Invalid texture, strip dimensions or timing; run editor import for the PNG first")
		return
	var err := DirAccess.make_dir_recursive_absolute(args[1].get_base_dir())
	if err == OK:
		err = ResourceSaver.save(frames, args[1])
	if err != OK:
		_fail(error_string(err))
		return
	var source := FileAccess.open(args[1] + ".source.json", FileAccess.WRITE)
	if source == null:
		DirAccess.remove_absolute(args[1])
		_fail("Cannot write source record; rolled back new resource")
		return
	source.store_string(JSON.stringify({"source": args[5], "license_note": args[6],
		"sheet": args[0], "sha256": FileAccess.get_sha256(args[0]),
		"frame_count": args[2].to_int(), "fps": args[3].to_float(), "loop": args[4] == "loop"}, "\t") + "\n")
	source.close()
	print("Imported: ", args[1])
	quit()

func _fail(message: String) -> void:
	printerr(message)
	quit(1)
