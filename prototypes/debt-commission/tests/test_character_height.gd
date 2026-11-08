extends "res://addons/proto_kit/test_kit.gd"

const RUNNER = preload("res://scripts/story_runner.gd")
const BUILDER = preload("res://tools/story_build/story_builder.gd")
const CATALOG: String = "res://stories/katsura_dog_ears/catalog.json"

func _init() -> void:
	create_timer(25.0).timeout.connect(func() -> void: quit(2))
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var catalog: Dictionary = RUNNER.read_catalog(CATALOG)["catalog"]
	var validator: RefCounted = RUNNER.new()
	for bad: Variant in [-1, 0, "175", false]:
		var broken: Dictionary = catalog.duplicate(true)
		broken.characters.katsura.height_cm = bad
		_expect(not str(validator._validate_asset_catalog(broken)).is_empty(), "invalid height rejected: %s" % bad)
	for bad: Array in [[0.5,0.2], [0,2], ["0",1], [0]]:
		var broken: Dictionary = catalog.duplicate(true)
		broken.characters.katsura.height_bounds = bad
		_expect(not str(validator._validate_asset_catalog(broken)).is_empty(), "invalid body bounds rejected: %s" % [bad])
	var built: Dictionary = BUILDER.build_text("~ start\n身高比例測試。\ndo end(\"完成\")\n", "res://tests/fixtures/story_src/__height_test.dialogue")
	FileAccess.open("user://height_test.json", FileAccess.WRITE).store_string(BUILDER.to_json(built["story"]))
	var game: Control = (load("res://main.tscn") as PackedScene).instantiate()
	game.story_path = "user://height_test.json"
	game.story_catalog_override = CATALOG
	game.save_path = "user://height_test.save"
	game.settings_path = "user://height_test_settings.cfg"
	game.progress_path = "user://height_test_progress.cfg"
	game.tutorials_enabled = false
	root.add_child(game)
	await _frames(3)
	_expect(game._story_ready, "height fixture loads pack catalog")
	game._on_begin_pressed()
	await _until(func() -> bool: return game._screen_mode == "story", "height reading shell")
	var heights: Dictionary = {}
	var soles: Dictionary = {}
	var index: int = 0
	for actor: String in ["gintoki", "katsura", "kagura"]:
		var info: Dictionary = catalog.characters[actor]
		game._apply_character({"id":actor, "enter":true, "position":["left","center","right"][index], "transition":"instant"})
		index += 1
		var sprite: Control = game._sprites[actor]
		var art: TextureRect = sprite.get_node("Art")
		var bounds: Array = info.height_bounds
		var crown: Vector2 = art.get_global_transform() * Vector2(0, art.size.y * float(bounds[0]))
		var sole: Vector2 = art.get_global_transform() * Vector2(0, art.size.y * float(bounds[1]))
		heights[actor] = sole.y - crown.y
		soles[actor] = sole.y
		var unit: float = art.size.y / art.texture.get_height()
		if not info.get("expressions", {}).is_empty():
			sprite.set_expression(str(info.expressions.keys()[0]))
			_expect(is_equal_approx(art.size.y / art.texture.get_height(), unit), actor + " expression keeps the same pixel scale")
			var base: Texture2D = load(info.path)
			var expression_sole: Vector2 = art.get_global_transform() * Vector2(0, art.size.y - base.get_height() * (1.0 - float(bounds[1])) * unit)
			_expect(absf(expression_sole.y - sole.y) < 0.1, actor + " expression keeps the feet line")
	_expect(absf(heights.katsura / heights.gintoki - 175.0 / 177.0) < 0.001, "Katsura:Gintoki follows 175:177")
	_expect(absf(heights.kagura / heights.gintoki - 155.0 / 177.0) < 0.001, "Kagura:Gintoki follows 155:177, excluding umbrella")
	_expect(absf(soles.kagura - soles.gintoki) < 0.1 and absf(soles.katsura - soles.gintoki) < 0.1, "all three feet share the stage baseline")
	var kagura: Control = game._sprites.kagura
	kagura.set_expression("neutral")
	kagura.configure_height(170.0, catalog.characters.kagura.height_bounds)
	var art: TextureRect = kagura.get_node("Art")
	var changed_height: float = art.size.y * (float(catalog.characters.kagura.height_bounds[1]) - float(catalog.characters.kagura.height_bounds[0])) * kagura.scale.y
	_expect(absf(changed_height / heights.gintoki - 170.0 / 177.0) < 0.001, "changing only the height setting immediately changes the displayed body ratio")
	game._cancel_generation()
	await _frames(2)
	game.queue_free()
	await _frames(2)
	_finish("CHARACTER HEIGHT")
