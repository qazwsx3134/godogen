extends "res://addons/proto_kit/test_kit.gd"
const B = preload("res://addons/proto_kit/scene_builder.gd")
const BASE := "res://addons/proto_kit/vfx/"
func _initialize() -> void:
	_patch.call_deferred()
func _patch() -> void:
	for dimension: String in ["2d", "3d"]:
		var path := BASE + "gallery_" + dimension + ".tscn"
		var opened := B.open_scene(path)
		var page: Node = opened.root
		var controls: Node = page.get_node("Panel/Margin/Columns/Controls")
		controls.get_node("EffectsList").custom_minimum_size.y = 180.0
		var choice := OptionButton.new()
		choice.add_item("All sources")
		choice.add_item("Scenario sprites")
		choice.add_item("00GameDevs native")
		choice.selected = 2 if dimension == "3d" else 0
		choice.custom_minimum_size.y = 36
		B.put(controls, B.unique(choice), "SourceChoice", 1)
		controls.get_node("EffectsList").custom_minimum_size.y = 145.0
		var actions := HBoxContainer.new()
		B.put(controls, actions, "Actions")
		for name: String in ["Stop", "Hit"]:
			var button := Button.new()
			button.text = name
			button.custom_minimum_size.y = 44
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			B.add(actions, B.unique(button), name + "Button")
		var label := Label.new()
		label.text = "Speed 1.00x"
		B.put(controls, B.unique(label), "SpeedLabel")
		var speed := HSlider.new()
		speed.min_value = 0.25
		speed.max_value = 2.0
		speed.step = 0.25
		speed.value = 1.0
		speed.custom_minimum_size.y = 32
		B.put(controls, B.unique(speed), "SpeedControl")
		var result := B.save_scene(page, path, {"overwrite": true, "expected_refs": opened.refs})
		_expect(result.ok, path)
	var main_path := BASE + "showcase.tscn"
	var main := B.open_scene(main_path)
	main.root.current_tab = 1
	var result := B.save_scene(main.root, main_path, {"overwrite": true, "expected_refs": main.refs})
	_expect(result.ok, "default 3D tab")
	_finish("GALLERY CONTROLS")
