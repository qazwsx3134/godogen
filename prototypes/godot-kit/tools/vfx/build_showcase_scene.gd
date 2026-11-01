extends SceneTree
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/"
func _initialize() -> void:
	_build.call_deferred()
func _build() -> void:
	var tabs := TabContainer.new()
	tabs.name = "GodotVfxShowcase"
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var refs: Array[String] = []
	for dimension: String in ["2d", "3d"]:
		var path := BASE + "gallery_" + dimension + ".tscn"
		refs.append(path)
		var gallery := B.instance(path)
		B.add(tabs, gallery, dimension.to_upper())
	var result := B.save_scene(tabs, BASE + "showcase.tscn", {"expected_refs": refs})
	quit(0 if result.ok else 1)
