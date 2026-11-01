extends "res://addons/proto_kit/test_kit.gd"
## Applied authoring step only. Runtime reset restores zero-time state; tested against JS snapshots.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/3d/00gamedevs/"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var source := OS.get_cmdline_user_args()[0]
	for file: String in DirAccess.get_files_at(source):
		if not file.ends_with(".json") or file == "stats.json":
			continue
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join(file)))
		var path: String = BASE + data.id + ".tscn"
		var opened := B.open_scene(path)
		var effect: Node = opened.root
		effect.auto_step = false
		root.add_child(effect)
		var fallback: float = 0.45 if data.preset.burst else maxf(0.45, float(data.lifecycle.start) + 0.1)
		var preview: float = minf(float(data.preset.get("previewTime", fallback)), float(data.preset.duration) * 0.8)
		effect.step(preview)
		effect.motion.stop(true)
		root.remove_child(effect)
		effect.auto_step = true
		effect.set_meta("editor_preview_time", preview)
		var result := B.save_scene(effect, path, {"overwrite": true, "expected_refs": opened.refs})
		_expect(result.ok, path)
	_finish("NATIVE EDITOR PREVIEWS")
