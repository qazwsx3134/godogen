extends "res://addons/proto_kit/test_kit.gd"

const PAGES := ["overview", "train", "backpack", "monster", "equipment", "adventure", "store"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	load("res://tests/test_bootstrap.gd").add_services(root)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	var found_pages: Array[String] = []
	var node_count := main.find_children("*", "", true, false).size()
	_expect(node_count > 150, "main already contains authored presentation before ready")
	for child: Node in main.find_children("*", "", true, false):
		if child.scene_file_path.begins_with("res://scenes/pages/"):
			found_pages.append(child.scene_file_path.get_file().get_basename())
	for page: String in PAGES:
		_expect(found_pages.has(page), "main references editable page: " + page)
		var packed := load("res://scenes/pages/%s.tscn" % page) as PackedScene
		_expect(packed != null and packed.get_state().get_node_count() > 8, "page has populated serialized nodes: " + page)
	var arena := main.find_child("CombatArena", true, false)
	_expect(arena != null, "live arena is authored in main")
	if arena != null:
		var actors := 0
		for child: Node in arena.get_children():
			if child is CombatUnit:
				actors += 1
				_expect(child.scene_file_path == "res://scenes/combat/party_unit.tscn", "all combat actors remain editable reusable scenes")
		_expect(actors == 8,"eight authored actors exist before runtime")
		for actor: String in ["KnightUnit", "SlimeUnit"]:
			var unit := arena.get_node_or_null(actor)
			_expect(unit != null and not unit.scene_file_path.is_empty(), "actor remains a reusable scene: " + actor)
			if unit != null:
				_expect(unit.get_node("Visuals/KnightVisual").visible == (actor == "KnightUnit"), "authored knight preview: " + actor)
				_expect(unit.get_node("Visuals/SlimeVisual").visible == (actor == "SlimeUnit"), "authored slime preview: " + actor)
	for rect: Node in main.find_children("*", "TextureRect", true, false):
		var texture: Texture2D = rect.texture
		if texture is AtlasTexture:
			_expect(texture.region.get_area() < 941.0 * 1672.0 * 0.70, "art region is not an entire screenshot: " + str(rect.name))
	main.free()
	print("AUTHORED NODES: ", node_count)
	_finish("SCENE NODE PERSISTENCE")
