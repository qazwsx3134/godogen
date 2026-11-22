## Authoring tool for a fresh checkout with no saved scenes. Runtime loads the saved scenes.
extends SceneTree

const BETTA_PATH := "res://scenes/betta.tscn"
const TANK_PATH := "res://scenes/tank.tscn"
const Freshwater = preload("res://tools/freshwater_geometry.gd")
const FRESHWATER_ASSETS := "res://assets/freshwater/"
const CARDINAL_PATH := "res://scenes/cardinal.tscn"
const DISCUS_PATH := "res://scenes/discus.tscn"
const CHUB_PATH := "res://scenes/pale_chub.tscn"
const AQUARIUM_PATH := "res://scenes/aquarium.tscn"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("add-freshwater"):
		_add_freshwater_to_saved_tank.call_deferred()
		return
	for path in [BETTA_PATH, TANK_PATH, AQUARIUM_PATH, CARDINAL_PATH, DISCUS_PATH, CHUB_PATH]:
		if FileAccess.file_exists(path):
			push_error("Existing scene at " + path + ". Build in a separate copy to compare.")
			quit(1)
			return
	_build.call_deferred()


func _build() -> void:
	if DirAccess.make_dir_recursive_absolute("res://scenes") != OK:
		quit(1)
		return
	_rng.seed = 723
	if not _make_materials() or not _save(_betta(), BETTA_PATH):
		quit(1)
		return
	if not _save_freshwater_models() or not _save(_tank(), TANK_PATH):
		quit(1)
		return
	quit(0 if _save(_aquarium(), AQUARIUM_PATH) else 1)


func _add_freshwater_to_saved_tank() -> void:
	var tank: Node3D = load(TANK_PATH).instantiate()
	if tank.get_node("Fish").has_node("Cardinal1"):
		push_error("Freshwater fish already in the saved tank.")
		tank.free()
		quit(1)
		return
	if not _save_freshwater_models():
		tank.free()
		quit(1)
		return
	_stock_freshwater(tank)
	quit(0 if _save(tank, TANK_PATH) else 1)


func _make_materials() -> bool:
	for name in ["plain", "silver"]:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/scales.gdshader")
		material.set_shader_parameter("scales", load("res://assets/betta_scales.png"))
		material.set_shader_parameter("silver_mask", load("res://assets/silver_mask.png"))
		material.set_shader_parameter("silver", name == "silver")
		if ResourceSaver.save(material, "res://assets/" + name + "_body.tres") != OK:
			return false
	return true


func _betta() -> Node3D:
	var fish := Node3D.new()
	fish.name = "Betta"
	fish.set_script(load("res://scripts/betta.gd"))
	var rig := _pivot(fish, "Rig", Vector3.ZERO, true)
	_mesh(rig, "Body", load("res://assets/betta_body.res"), load("res://assets/plain_body.tres"), Vector3.ZERO, true)
	var fins := ShaderMaterial.new()
	fins.shader = load("res://shaders/fins.gdshader")
	var body_pick := _pick_area(rig, "BodyPick")
	_pick_box(body_pick, "BodyShape", Vector3(0.86, 0.42, 0.25), Vector3(0.055, 0.0, 0.0))
	var tail := _pivot(rig, "Tail", Vector3(-0.36, 0.0, 0.0), true)
	_mesh(tail, "ShortTail", load("res://assets/tail_short.res"), fins, Vector3.ZERO, true)
	_mesh(tail, "LongTail", load("res://assets/tail_long.res"), fins, Vector3.ZERO, true).hide()
	var tail_pick := _pick_area(tail, "TailPick")
	_pick_box(tail_pick, "ShortTailPick", Vector3(0.46, 0.32, 0.18), Vector3(-0.24, 0.0, 0.0))
	_pick_box(tail_pick, "LongTailPick", Vector3(0.87, 0.48, 0.18), Vector3(-0.45, 0.025, 0.0)).disabled = true
	_mesh(rig, "Dorsal", load("res://assets/dorsal.res"), fins, Vector3.ZERO)
	_mesh(rig, "Anal", load("res://assets/anal.res"), fins, Vector3.ZERO)
	var eye_outline := _material("#bea783")
	var pupil := _material("#100e23")
	var catchlight := _material("#fff4d9")
	for side in [-1.0, 1.0]:
		var near_side: bool = side > 0
		var fin_name := "NearPectoral" if near_side else "FarPectoral"
		var pectoral := _pivot(rig, fin_name, Vector3(0.23, -0.04, side * 0.088), true)
		var filename := "pectoral_near" if near_side else "pectoral_far"
		_mesh(pectoral, "Fin", load("res://assets/" + filename + ".res"), fins, Vector3.ZERO)
		var eye := _pivot(rig, "EyeNear" if near_side else "EyeFar", Vector3(0.32, 0.041, side * 0.078))
		_ball(eye, "Iris", Vector3(0.092, 0.089, 0.054), Vector3.ZERO, eye_outline)
		_ball(eye, "Pupil", Vector3(0.064, 0.067, 0.043), Vector3(0.006, 0.0, side * 0.024), pupil)
		_ball(eye, "Glint", Vector3(0.027, 0.027, 0.022), Vector3(0.016, 0.015, side * 0.041), catchlight)
	_add_betta_mouth(rig)
	return fish


func _add_betta_mouth(rig: Node3D) -> void:
	var aperture := _ball(rig, "Mouth", Vector3(0.084, 0.067, 0.083),
		Vector3(0.458, -0.026, 0), _material("#192332"))
	aperture.hide()
	var jaw := _pivot(rig, "LowerJaw", Vector3(0.381, -0.034, 0))
	_ball(jaw, "Lip", Vector3(0.126, 0.047, 0.079),
		Vector3(0.056, -0.007, 0), _material("#66818e"))
	jaw.hide()


func _save_freshwater_models() -> bool:
	if not _save_freshwater_materials():
		return false
	return (
		_save(_freshwater_model("Cardinal", Freshwater.cardinal(), "cardinal", "#dec5a4"), CARDINAL_PATH)
		and _save(_freshwater_model("Discus", Freshwater.discus(), "discus_blue", "#ff8b51"), DISCUS_PATH)
		and _save(_freshwater_model("PaleChub", Freshwater.pale_chub(), "pale_chub_male", "#d6ba88"), CHUB_PATH)
	)


func _save_freshwater_materials() -> bool:
	if DirAccess.make_dir_recursive_absolute(FRESHWATER_ASSETS) != OK:
		return false
	var colors := [
		["cardinal", 0, "#738f9f", "#4cf6ff", "#fb3045", "#4d7b83", "#8cb5ba", "#badbd3"],
		["discus_blue", 1, "#425bad", "#72c3f1", "#6986d3", "#2f386d", "#415f9f", "#80d0df"],
		["discus_red", 1, "#ad4b2f", "#ffc277", "#e77a3b", "#6f3139", "#bf573c", "#f2a761"],
		["discus_turquoise", 1, "#387a83", "#7ff6d9", "#697650", "#2f465d", "#488e8d", "#82d0b0"],
		["pale_chub_male", 2, "#7d9e92", "#2d9b91", "#de8069", "#4d5769", "#9b6e69", "#e99c81"],
		["pale_chub_female", 3, "#9bafa8", "#536d79", "#e0cfab", "#4f676c", "#9da99a", "#d9c8a1"],
	]
	for palette: Array in colors:
		var body := ShaderMaterial.new()
		body.shader = load("res://shaders/freshwater_scales.gdshader")
		body.set_shader_parameter("pattern", palette[1])
		body.set_shader_parameter("base_color", Color(palette[2]))
		body.set_shader_parameter("stripe_color", Color(palette[3]))
		body.set_shader_parameter("accent_color", Color(palette[4]))
		var fins := ShaderMaterial.new()
		fins.shader = load("res://shaders/fins.gdshader")
		fins.set_shader_parameter("root_color", Color(palette[5]))
		fins.set_shader_parameter("main_color", Color(palette[6]))
		fins.set_shader_parameter("edge_color", Color(palette[7]))
		var path: String = FRESHWATER_ASSETS + palette[0]
		if ResourceSaver.save(body, path + "_body.tres") != OK:
			return false
		if ResourceSaver.save(fins, path + "_fins.tres") != OK:
			return false
	return true


func _freshwater_model(model_name: String, model: Dictionary, palette: String, iris: String) -> Node3D:
	var fish := Node3D.new()
	fish.name = model_name
	fish.set_script(load("res://scripts/freshwater_fish.gd"))
	var rig := _pivot(fish, "Rig", Vector3.ZERO, true)
	var tail := _pivot(rig, "Tail", Vector3(model.tail_x, 0, 0), true)
	_mesh(rig, "Body", model.body, null, Vector3.ZERO, true)
	_mesh(tail, "Caudal", model.caudal, null, Vector3.ZERO, true)
	_mesh(rig, "Dorsal", model.dorsal, null, Vector3.ZERO, true)
	_mesh(rig, "Anal", model.anal, null, Vector3.ZERO, true)
	var body_pick := _pick_area(rig, "BodyPick")
	_pick_box(body_pick, "BodyShape", model.body_pick_size, model.body_pick_offset)
	var tail_pick := _pick_area(tail, "TailPick")
	_pick_box(tail_pick, "TailShape", model.tail_pick_size, model.tail_pick_offset)
	var iris_material := _material(iris)
	var pupil := _material("#121829")
	var glint := _material("#ffefca")
	for side: float in [-1.0, 1.0]:
		var near_side := side > 0
		var pectoral: Vector3 = model.pectoral
		pectoral.z *= side
		var fin := _pivot(rig, "NearPectoral" if near_side else "FarPectoral", pectoral, true)
		var fin_filename := "pectoral_near" if near_side else "pectoral_far"
		var fin_mesh := _mesh(fin, "NearFinMesh" if near_side else "FarFinMesh",
			load("res://assets/" + fin_filename + ".res"), null, Vector3.ZERO, true)
		fin_mesh.scale = Vector3.ONE * float(model.pectoral_scale)
		var eye_position: Vector3 = model.eye
		eye_position.z *= side
		var eye := _pivot(rig, "EyeNear" if near_side else "EyeFar", eye_position)
		var radius: float = model.eye_size
		_ball(eye, "Iris", Vector3(1.0, 1.0, 0.51) * radius, Vector3.ZERO, iris_material)
		_ball(eye, "Pupil", Vector3(0.74, 0.74, 0.48) * radius, Vector3(0.007, 0, side * radius * 0.24), pupil)
		_ball(eye, "Glint", Vector3.ONE * radius * 0.27, Vector3(0.017, 0.016, side * radius * 0.44), glint)
	_apply_palette(fish, palette)
	return fish


func _apply_palette(fish: Node3D, palette: String) -> void:
	var path := FRESHWATER_ASSETS + palette
	var body: Material = load(path + "_body.tres")
	var fins: Material = load(path + "_fins.tres")
	fish.set("body_material", body)
	fish.set("fin_material", fins)
	fish.get_node("Rig/Body").material_override = body
	for part in ["Tail/Caudal", "Dorsal", "Anal", "NearPectoral/NearFinMesh", "FarPectoral/FarFinMesh"]:
		fish.get_node("Rig/" + part).material_override = fins


func _stock_freshwater(tank: Node3D) -> void:
	# Cardinal tetras share one route and keep a staggered formation.
	var school := {
		"fish_name": "紅蓮燈",
		"appearance": "藍色亮帶 · 紅色下腹",
		"swim_span": Vector3(2.6, 0.27, 1.4),
		"swim_period": 12.0,
		"phase": 0.55,
		"tail_speed": 12.0,
		"tail_swing": 0.4,
		"marker_drop": 0.2,
	}
	for index in 3:
		var home := Vector3(-1.22 + index * 0.78, 2.04 + (0.29 if index == 1 else 0.0), -0.9)
		_add_specimen(tank, CARDINAL_PATH, "Cardinal%d" % (index + 1), home, school)

	var discus := {
		"swim_span": Vector3(1.48, 0.35, 1.1),
		"swim_period": 18.0,
		"tail_speed": 5.3,
		"tail_swing": 0.25,
		"marker_drop": 0.56,
		"start_facing_left": true,
	}
	var discus_variants := [
		["BlueDiscus", "藍七彩神仙", "藍底 · 淺藍波紋", "discus_blue", Vector3(-3.7, 0.41, -1.6), 0.07],
		["RedDiscus", "紅七彩神仙", "橘紅底 · 金色波紋", "discus_red", Vector3(0.16, -0.81, 1.6), 0.26],
		["TurquoiseDiscus", "綠松石七彩神仙", "青綠底 · 綠松石波紋", "discus_turquoise", Vector3(3.65, 1.52, -2.0), -0.19],
	]
	for entry: Array in discus_variants:
		var properties := discus.merged({"fish_name": entry[1], "appearance": entry[2], "phase": entry[5]})
		var specimen := _add_specimen(tank, DISCUS_PATH, entry[0], entry[4], properties)
		_apply_palette(specimen, entry[3])

	var male := _add_specimen(tank, CHUB_PATH, "PaleChubMale", Vector3(-3.91, -0.69, 1.45), {
		"fish_name": "オイカワ（雄）",
		"appearance": "藍綠斑 · 橘紅下腹",
		"swim_span": Vector3(1.25, 0.41, 1.35),
		"swim_period": 10.2,
		"phase": 0.01,
		"tail_speed": 9.8,
		"tail_swing": 0.37,
		"marker_drop": 0.31,
	})
	var female := _add_specimen(tank, CHUB_PATH, "PaleChubFemale", Vector3(3.18, -1.0, 1.2), {
		"fish_name": "オイカワ（雌）",
		"appearance": "銀灰魚身 · 深色側線",
		"swim_span": Vector3(1.95, 0.3, 2.0),
		"swim_period": 11.7,
		"phase": 0.09,
		"tail_speed": 9.4,
		"tail_swing": 0.35,
		"marker_drop": 0.31,
		"start_facing_left": true,
	})
	_apply_palette(male, "pale_chub_male")
	_apply_palette(female, "pale_chub_female")


func _add_specimen(tank: Node3D, path: String, node_name: String,
		home: Vector3, properties: Dictionary) -> Node3D:
	var specimen: Node3D = load(path).instantiate()
	specimen.name = node_name
	specimen.position = home
	for property in properties:
		specimen.set(property, properties[property])
	tank.get_node("Fish").add_child(specimen)
	tank.set_editable_instance(specimen, true)
	specimen.get_node("Rig").rotation.y = PI if specimen.get("start_facing_left") else 0.0
	return specimen


func _tank() -> Node3D:
	var tank := Node3D.new()
	tank.name = "Tank"
	var camera := Camera3D.new()
	camera.name = "ViewingCamera"
	camera.position = Vector3(0, 2.4, 14)
	camera.rotation_degrees.x = -9.0
	camera.fov = 29.0
	camera.current = true
	tank.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#101e25")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#7eaeaa")
	environment.environment.ambient_light_energy = 0.61
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = Color("#1a5357")
	environment.environment.fog_density = 0.013
	tank.add_child(environment)
	var key := DirectionalLight3D.new()
	key.name = "TankLamp"
	key.rotation_degrees = Vector3(-49.0, -25.0, 0.0)
	key.light_color = Color("#e1f7d9")
	key.light_energy = 0.92
	tank.add_child(key)

	var water := QuadMesh.new()
	water.size = Vector2(80.0, 48.0)
	var water_material := ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	_mesh(tank, "WaterBackdrop", water, water_material, Vector3(0, -0.18, -6.0))

	_layout(tank)
	var fish := _pivot(tank, "Fish", Vector3.ZERO, true)
	var names := ["Plain", "LongTail", "Silver", "Moon"]
	var homes := [Vector3(-2.0, 1.3, -1.4), Vector3(1.7, 0.76, 1.1),
		Vector3(-1.35, -0.65, 1.8), Vector3(1.04, -0.43, -1.1)]
	var phases := [0.25, -0.25, -0.18, 0.18]
	var spans := [Vector3(2.6, 0.42, 2.2), Vector3(2.9, 0.52, 2.4),
		Vector3(3.6, 0.69, 1.7), Vector3(3.9, 0.54, 2.4)]
	for i in names.size():
		var specimen: Node3D = load(BETTA_PATH).instantiate()
		specimen.name = names[i]
		specimen.set("long_tail", i % 2 == 1)
		specimen.set("silver", i >= 2)
		specimen.set("phase", phases[i])
		specimen.set("swim_span", spans[i])
		specimen.set("swim_period", 12.0 + float(i))
		specimen.set("start_facing_left", i % 2 == 1)
		specimen.position = homes[i]
		fish.add_child(specimen)
		specimen.get_node("Rig").rotation.y = PI if i % 2 == 1 else 0.0
		specimen.get_node("Rig/Tail/ShortTail").visible = i % 2 == 0
		specimen.get_node("Rig/Tail/LongTail").visible = i % 2 == 1
		if i >= 2:
			specimen.get_node("Rig/Body").material_override = load("res://assets/silver_body.tres")
		tank.set_editable_instance(specimen, true)
	_stock_freshwater(tank)
	return tank


func _layout(tank: Node3D) -> void:
	var backdrop := _pivot(tank, "Hardscape", Vector3.ZERO)
	var sand := _material("#827570", false)
	var bed_surface := PlaneMesh.new()
	bed_surface.size = Vector2(100.0, 45.0)
	var sand_material := ShaderMaterial.new()
	sand_material.shader = load("res://shaders/substrate.gdshader")
	_mesh(backdrop, "Substrate", bed_surface, sand_material, Vector3(0, -2.28, -7.0))
	var slate := _material("#415359", false)
	var light_slate := _material("#516268", false)
	var dark_slate := _material("#374550", false)
	var rocks := [Vector3(-3.2, -1.94, -0.7), Vector3(-3.97, -1.89, -1.2),
		Vector3(3.0, -1.92, -0.6), Vector3(4.05, -1.75, -1.5),
		Vector3(-0.52, -2.0, -0.3), Vector3(0.09, -1.97, -0.83)]
	for i in rocks.size():
		var rock := _ball(backdrop, "Slate" + str(i), Vector3(1.6, 0.84, 1.1), rocks[i],
			light_slate if i % 2 == 0 else slate)
		rock.rotation = Vector3(0.19 * i, 0.52 * i, -0.30 + i * 0.11)
		_occlude(rock)
	for i in 77:
		var stone_size := _rng.randf_range(0.08, 0.24)
		var gravel := _ball(backdrop, "Pebble" + str(i), Vector3(stone_size, stone_size * 0.55, stone_size),
			Vector3(_rng.randf_range(-7.4, 7.4), -2.26, _rng.randf_range(-4.7, 6.3)),
			[slate, light_slate, dark_slate, sand][i % 4])
		gravel.rotation.y = _rng.randf_range(0.0, TAU)

	var wood := _material("#734e43", false)
	var log_piece := _ball(backdrop, "Driftwood", Vector3(3.2, 0.44, 0.65), Vector3(-1.4, -1.85, -0.6), wood)
	log_piece.rotation.z = 0.26
	var branch := _ball(backdrop, "DriftwoodBranch", Vector3(1.6, 0.19, 0.36), Vector3(-1.76, -1.61, -0.72), wood)
	branch.rotation.z = 0.69
	_occlude(log_piece)
	_occlude(branch)
	var near_stone := _ball(backdrop, "ForegroundSlate", Vector3(2.3, 1.17, 1.2),
		Vector3(4.85, -2.29, 4.55), dark_slate)
	near_stone.rotation = Vector3(0.34, -0.42, -0.38)
	_occlude(near_stone)

	var plants := _pivot(tank, "Plants", Vector3.ZERO)
	var heights := [2.4, 1.6, 2.6, 2.94, 1.7, 1.5, 1.2, 2.7, 2.3, 2.5]
	var bed := [Vector3(-5.04, -2.18, 0.0), Vector3(-4.27, -2.16, 0.7),
		Vector3(-3.14, -2.18, -1.8), Vector3(4.85, -2.17, 0.2),
		Vector3(4.07, -2.22, -0.15), Vector3(5.15, -2.16, 1.45),
		Vector3(1.5, -2.25, -2.4), Vector3(-5.4, -2.27, 4.55),
		Vector3(5.42, -2.27, 4.1), Vector3(-1.9, -2.27, -4.5)]
	var leaves := [_material("#508e73", false, true), _material("#36776a", false, true),
		_material("#69977b", false, true)]
	for i in bed.size():
		var patch := _pivot(plants, "WaterGrass" + str(i), bed[i])
		for j in 7:
			var length_y: float = heights[i] * _rng.randf_range(0.55, 1.0)
			var width_x := _rng.randf_range(0.10, 0.23)
			var sweep := _rng.randf_range(-0.66, 0.73)
			var leaf := _mesh(patch, "Leaf" + str(j), _leaf(length_y, width_x, sweep),
				leaves[j % 3], Vector3(_rng.randf_range(-0.27, 0.27), 0, _rng.randf_range(-0.23, 0.23)))
			leaf.rotation.y = _rng.randf_range(-0.70, 0.70)
			_occlude(leaf)

	var particles := _pivot(tank, "SuspendedParticles", Vector3.ZERO)
	var speck := _material("#558c88")
	var glint := _material("#8cbf95")
	for i in 99:
		var width := _rng.randf_range(0.018, 0.048)
		_box(particles, "Speck" + str(i), Vector3(width, width, width),
			Vector3(_rng.randf_range(-8.8, 8.8), _rng.randf_range(-1.9, 5.0),
			_rng.randf_range(-5.8, 3.8)), glint if i % 7 == 0 else speck)


func _aquarium() -> Control:
	var aquarium := Control.new()
	aquarium.name = "Aquarium"
	aquarium.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aquarium.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aquarium.set_script(load("res://scripts/aquarium.gd"))

	var view := SubViewport.new()
	view.name = "TankView"
	view.unique_name_in_owner = true
	view.size = Vector2i(640, 360)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	aquarium.add_child(view)
	var tank: Node3D = load(TANK_PATH).instantiate()
	view.add_child(tank)

	var picture := TextureRect.new()
	picture.name = "WaterPicture"
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport_texture := ViewportTexture.new()
	viewport_texture.viewport_path = NodePath("TankView")
	picture.texture = viewport_texture
	aquarium.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var ui := Control.new()
	ui.name = "Controls"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aquarium.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = _theme()

	var zoom := HBoxContainer.new()
	zoom.name = "ZoomControls"
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.add_theme_constant_override("separation", 4)
	ui.add_child(zoom)
	zoom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom.offset_left = 12
	zoom.offset_top = -37
	zoom.offset_right = 128
	zoom.offset_bottom = -12
	_button(zoom, "ZoomOut", "−", "縮小魚缸", 29)
	_button(zoom, "ZoomReset", "100%", "回到預設視野", 50)
	_button(zoom, "ZoomIn", "+", "放大魚缸", 29)

	var marker := ColorRect.new()
	marker.name = "SelectionMarker"
	marker.unique_name_in_owner = true
	marker.color = Color("#fae3ae")
	marker.size = Vector2(13, 2)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.hide()
	ui.add_child(marker)

	var storage := MenuButton.new()
	storage.name = "StoredFish"
	storage.unique_name_in_owner = true
	storage.text = "收起的魚"
	ui.add_child(storage)
	storage.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	storage.offset_left = -115
	storage.offset_right = -12
	storage.offset_top = 12
	storage.offset_bottom = 38
	storage.hide()

	var panel := PanelContainer.new()
	panel.name = "FishPanel"
	panel.unique_name_in_owner = true
	panel.mouse_force_pass_scroll_events = false
	var panel_style := _panel(Color("#152f35"), Color("#82aa9e"))
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -187
	panel.offset_right = -12
	panel.offset_top = -82
	panel.offset_bottom = 82
	panel.hide()

	var details := VBoxContainer.new()
	details.name = "Details"
	details.add_theme_constant_override("separation", 4)
	panel.add_child(details)
	var header := HBoxContainer.new()
	header.name = "Header"
	details.add_child(header)
	var title := _label(header, "FishName", "月影鬥魚", 17, Color("#fae3ae"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "CloseFish", "×", "關閉魚隻資訊", 23)
	_label(details, "Status", "成魚 · 游動中", 10, Color("#adcec1"))
	_label(details, "Traits", "長尾 · 月牙銀紋", 10, Color("#adcec1"))
	var separator := HSeparator.new()
	separator.name = "Separator"
	details.add_child(separator)

	var breed := _button(details, "BreedFish", "繁殖", "育種系統開放後可選擇另一尾魚", 0)
	breed.custom_minimum_size.y = 23
	breed.disabled = true
	var sell := _button(details, "SellFish", "出售", "交易系統開放後可出售", 0)
	sell.custom_minimum_size.y = 23
	sell.disabled = true
	var store := _button(details, "StoreFish", "收起", "從目前魚缸暫時收起", 0)
	store.custom_minimum_size.y = 23
	return aquarium


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/NotoSansTC.ttf")
	theme.default_font_size = 11
	theme.set_stylebox("panel", "PopupMenu", _panel(Color("#152f35"), Color("#82aa9e")))
	theme.set_stylebox("hover", "PopupMenu", _panel(Color("#354f50"), Color("#75988b")))
	theme.set_color("font_color", "PopupMenu", Color("#d4e3d1"))
	theme.set_color("font_color", "Button", Color("#d4e3d1"))
	theme.set_color("font_pressed_color", "Button", Color("#ffe2b4"))
	theme.set_stylebox("normal", "Button", _panel(Color("#25383c"), Color("#476064")))
	theme.set_stylebox("hover", "Button", _panel(Color("#354f50"), Color("#75988b")))
	theme.set_color("font_disabled_color", "Button", Color("#9ab0aa"))
	theme.set_stylebox("disabled", "Button", _panel(Color("#23343a"), Color("#394e50")))
	theme.set_stylebox("pressed", "Button", _panel(Color("#425c55"), Color("#b39a72")))
	var focus := _panel(Color.TRANSPARENT, Color("#f4d496"))
	theme.set_stylebox("focus", "Button", focus)
	return theme


func _panel(background: Color, border: Color) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = background
	panel.border_color = border
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(2)
	return panel


func _button(parent: Node, node_name: String, title: String, hint: String, width: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.tooltip_text = hint
	button.custom_minimum_size.x = width
	button.unique_name_in_owner = true
	parent.add_child(button)
	return button


func _label(parent: Node, node_name: String, title: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = title
	label.unique_name_in_owner = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _pick_area(parent: Node3D, node_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.unique_name_in_owner = true
	area.monitoring = false
	area.monitorable = false
	area.collision_mask = 0
	parent.add_child(area)
	return area


func _pick_box(parent: Area3D, node_name: String, size: Vector3, offset: Vector3) -> CollisionShape3D:
	var hitbox := CollisionShape3D.new()
	hitbox.name = node_name
	hitbox.unique_name_in_owner = true
	var shape := BoxShape3D.new()
	shape.size = size
	hitbox.shape = shape
	hitbox.position = offset
	parent.add_child(hitbox)
	return hitbox


func _occlude(mesh: MeshInstance3D) -> void:
	var obstruction := StaticBody3D.new()
	obstruction.name = "PickOccluder"
	obstruction.collision_layer = 2
	obstruction.collision_mask = 0
	mesh.add_child(obstruction)
	var shape := mesh.mesh.create_trimesh_shape()
	shape.backface_collision = true
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	obstruction.add_child(hitbox)


func _leaf(height: float, width: float, sweep: float) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 7:
		for corner in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1),
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
			var t := float(segment + corner.y) / 7.0
			var edge := float(corner.x) - 0.5
			mesh.add_vertex(Vector3(
				sweep * t * t + edge * width * (0.1 + sin(t * PI) * 0.9),
				t * height, sin(t * PI) * 0.12
			))
	mesh.generate_normals()
	return mesh.commit()


func _save(node: Node, path: String) -> bool:
	_own(node, node)
	var count := _count(node)
	var packed := PackedScene.new()
	var status := packed.pack(node)
	if status == OK:
		status = ResourceSaver.save(packed, path)
	node.free()
	if status != OK:
		push_error("Could not save %s, error %s" % [path, status])
		return false
	var saved: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if saved == null:
		return false
	var restored := saved.instantiate()
	if restored == null:
		return false
	var restored_count := _count(restored)
	restored.free()
	print("%s: %d authored nodes, %d reloaded nodes" % [path, count, restored_count])
	return restored_count == count


func _own(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			_own(child, scene_root)


func _count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count(child)
	return count


func _material(color: String, unshaded := true, two_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 1.0
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _pivot(parent: Node3D, node_name: String, position: Vector3, unique := false) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = position
	node.unique_name_in_owner = unique
	parent.add_child(node)
	return node


func _mesh(parent: Node3D, node_name: String, shape: Mesh, material: Material,
		position: Vector3, unique := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position
	node.mesh = shape
	node.material_override = material
	node.unique_name_in_owner = unique
	parent.add_child(node)
	return node


func _box(parent: Node3D, node_name: String, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, node_name, shape, material, position)


func _ball(parent: Node3D, node_name: String, size: Vector3, position: Vector3,
		material: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 9
	shape.rings = 5
	var node := _mesh(parent, node_name, shape, material, position)
	node.scale = size
	return node
