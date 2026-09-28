extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	for page: String in ["train", "backpack", "monster", "equipment", "adventure", "store"]:
		var source: Node = (load("res://scenes/pages/%s.tscn" % page) as PackedScene).instantiate()
		var label: Label
		for node: Node in source.find_children("*", "Label", true, false):
			if node.owner == source:
				label = node as Label
				break
		_expect(label != null, "page has editable native static text: " + page)
		if label == null:
			source.free()
			continue
		var label_path := source.get_path_to(label)
		label.text = "EDITOR SENTINEL"
		label.add_theme_constant_override("outline_size", 3)
		label.offset_left += 7.0
		var authored_offset := label.offset_left
		var packed := PackedScene.new()
		_expect(packed.pack(source) == OK, "pack edited page: " + page)
		var saved := "user://editor_%s.tscn" % page
		_expect(ResourceSaver.save(packed, saved) == OK, "save edited page: " + page)
		source.free()
		var restored: Node = (load(saved) as PackedScene).instantiate()
		root.add_child(restored)
		await _frames(3)
		var restored_label := restored.get_node(label_path) as Label
		_expect(restored_label.text == "EDITOR SENTINEL", "static text survives ready: " + page)
		_expect(restored_label.get_theme_constant("outline_size") == 3, "style edit survives ready: " + page)
		if not restored_label.get_parent() is Container:
			_expect(is_equal_approx(restored_label.offset_left, authored_offset), "layout edit survives ready: " + page)
		restored.queue_free()
		await _frames(2)
	_finish("EDITOR CONTRACT")
