extends SceneTree
## One-time scene authoring. Existing gallery scenes are preserved.
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/"
var good: bool = true

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	for dimension: String in ["2d", "3d"]:
		var page := Control.new()
		page.name = "VfxGallery" + dimension.to_upper()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.set_script(load(BASE + "gallery.gd"))
		page.dimension = dimension
		var panel := PanelContainer.new()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_add(page, panel, "Panel")
		var margin := MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 16)
		_add(panel, margin, "Margin")
		var columns := HBoxContainer.new()
		columns.add_theme_constant_override("separation", 18)
		_add(margin, columns, "Columns")
		var controls := VBoxContainer.new()
		controls.custom_minimum_size.x = 250
		_add(columns, controls, "Controls")
		var title := Label.new()
		title.text = "Godot VFX · " + dimension.to_upper()
		title.add_theme_font_size_override("font_size", 24)
		_add(controls, title, "Title")
		var list := ItemList.new()
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.custom_minimum_size.y = 300
		_add(controls, list, "EffectsList", true)
		var info := Label.new()
		info.text = "Choose an effect"
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.y = 100
		_add(controls, info, "Info", true)
		var button := Button.new()
		button.text = "Replay"
		button.custom_minimum_size.y = 44
		_add(controls, button, "ReplayButton", true)
		var container := SubViewportContainer.new()
		container.stretch = true
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.custom_minimum_size = Vector2(600, 480)
		_add(columns, container, "Stage")
		var view := SubViewport.new()
		view.size = Vector2i(700, 500)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.own_world_3d = dimension == "3d"
		_add(container, view, "Preview", true)
		if dimension == "2d":
			var root2 := Node2D.new()
			_add(view, root2, "Effects", true)
			var sample := B.instance(BASE + "2d/scenario/cinder-explosion.tscn") as Node2D
			sample.position = Vector2(350, 250)
			_add(root2, sample, "EditorSample")
		else:
			var stage := Node3D.new()
			_add(view, stage, "World")
			var camera := Camera3D.new()
			camera.current = true
			camera.position = Vector3(0, 5, 8)
			camera.rotation_degrees.x = -25
			_add(stage, camera, "Camera")
			var floor_node := MeshInstance3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(18, 18)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.05, 0.065, 0.1)
			plane.material = mat
			floor_node.mesh = plane
			floor_node.position.y = -0.02
			_add(stage, floor_node, "Ground")
			var root3 := Node3D.new()
			_add(stage, root3, "Effects", true)
			_add(root3, B.instance(BASE + "3d/scenario/cinder-explosion.tscn"), "EditorSample")
		var timer := Timer.new()
		timer.one_shot = true
		_add(page, timer, "Replay", true)
		var sample_path := BASE + dimension + "/scenario/cinder-explosion.tscn"
		var result := B.save_scene(page, BASE + "gallery_" + dimension + ".tscn", {"expected_refs": [sample_path]})
		good = result.ok and good
	quit(0 if good else 1)

func _add(parent: Node, child: Node, node_name: String, unique: bool = false) -> Node:
	if unique:
		B.unique(child)
	return B.add(parent, child, node_name)
