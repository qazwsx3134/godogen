extends SceneTree
## One-time authoring tool: writes the graybox's materials, meshes, data resources and scenes.
##   godot --headless --path prototypes/horde-25d --script res://tools/build_scenes.gd
## Existing files are skipped (scenes) or kept (resources), so hand edits survive a rerun; delete a file to rebuild it.
## After the first run the saved .tscn/.tres files are the source: edit them in the editor, not here.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")

const ATLAS := "res://assets/sprites/atlas.png"
const FONT := "res://ui/fonts/NotoSansTC.ttf"

var _failed: bool = false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var sprite_node: ShaderMaterial = _material("res://materials/sprite_node.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": false})
	var sprite_instanced: ShaderMaterial = _material("res://materials/sprite_instanced.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": true})
	var sprite_prop: ShaderMaterial = _material("res://materials/sprite_prop.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": true, "lean": 0.0, "bob": 0.0, "see_through_enabled": true})
	var shadow: ShaderMaterial = _material("res://materials/blob_shadow.tres", "res://shaders/blob_shadow.gdshader", {})
	var ground: ShaderMaterial = _material("res://materials/ground.tres", "res://shaders/ground.gdshader", {})
	var glow: ShaderMaterial = _material("res://materials/fx_glow.tres", "res://shaders/fx_glow.gdshader", {})
	var gem: ShaderMaterial = _material("res://materials/gem.tres", "res://shaders/gem.gdshader", {})
	var aura: ShaderMaterial = _material("res://materials/aura_ring.tres", "res://shaders/ground_ring.gdshader", {
		"color": Color(0.35, 0.85, 1.0, 0.55), "fill": 0.1})
	var nova: ShaderMaterial = _material("res://materials/nova_ring.tres", "res://shaders/ground_ring.gdshader", {
		"color": Color(1.0, 0.6, 0.25, 0.9), "thickness": 0.14, "fill": 0.0, "fade_with_progress": 1.0})

	var actor_mesh: ArrayMesh = _actor_mesh(shadow, sprite_instanced, "res://assets/meshes/actor_mesh.tres")
	var prop_mesh: ArrayMesh = _actor_mesh(shadow, sprite_prop, "res://assets/meshes/prop_mesh.tres")
	var enemies: Array[EnemyDef] = _enemies()
	var weapons: Array[WeaponDef] = _weapons()
	var passives: Array[PassiveDef] = _passives()
	var theme: Theme = _theme()

	_save(_damage_number(), "res://scenes/damage_number.tscn")
	_save(_upgrade_card(theme), "res://scenes/upgrade_card.tscn")
	_save(_player(sprite_node, shadow), "res://scenes/player.tscn")
	_save(_hud(theme), "res://scenes/hud.tscn", ["res://scenes/upgrade_card.tscn"])
	var main: Node3D = _main(actor_mesh, prop_mesh, sprite_node, ground, glow, gem, aura, nova, enemies, weapons, passives)
	_save(main, "res://scenes/main.tscn", ["res://scenes/player.tscn", "res://scenes/hud.tscn"])
	quit(1 if _failed else 0)


func _save(root: Node, path: String, refs: Array = []) -> void:
	var result: Dictionary = SceneBuilder.save_scene(root, path, {"expected_refs": refs})
	if not result.ok:
		_failed = true
	elif not result.skipped:
		_strip_nulls(path)


func _keep(resource: Resource, path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		push_error("cannot save %s: %s" % [path, error_string(error)])
		_failed = true
		return resource
	print("saved: ", path)
	_strip_nulls(path)
	return load(path)


## A headless save writes every shader uniform it did not set as `= null`, which hides the shader's default.
func _strip_nulls(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var kept: PackedStringArray = []
	for line: String in text.split("\n"):
		if not (line.begins_with("shader_parameter/") and line.ends_with(" = null")):
			kept.append(line)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(kept))


func _material(path: String, shader: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return _keep(m, path)


## Shadow plane (surface 0) and feet-pivoted sprite quad (surface 1): the horde's and decor's shared mesh.
func _actor_mesh(shadow: Material, sprite: Material, path: String) -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	mesh.surface_set_material(0, shadow)
	mesh.surface_set_material(1, sprite)
	return _keep(mesh, path)


func _enemies() -> Array[EnemyDef]:
	var list: Array[EnemyDef] = []
	for row: Array in [
		# id, frame, hp, speed, size, radius, damage, xp, resist, tint, appears_at, weight, elite
		# Sizes: one source pixel is 0.074 m, so a 32 px sprite is 2.37 m. Placeholders vary the scale instead.
		[&"slime", 1, 10.0, 2.8, 2.0, 0.6, 6.0, 1, 0.0, Color(0.55, 0.85, 0.5), 0.0, 1.0, false],
		[&"bat", 2, 6.0, 4.4, 1.8, 0.5, 4.0, 1, 0.0, Color(0.9, 0.4, 0.45), 40.0, 0.7, false],
		[&"brute", 3, 45.0, 2.0, 3.0, 0.9, 12.0, 4, 0.6, Color(0.7, 0.5, 0.9), 100.0, 0.3, false],
		[&"elite", 4, 400.0, 2.4, 4.4, 1.3, 20.0, 40, 0.9, Color(1.0, 0.8, 0.3), 0.0, 0.0, true],
	]:
		var def := EnemyDef.new()
		def.id = row[0]
		def.frame = row[1]
		def.hp = row[2]
		def.speed = row[3]
		def.size = row[4]
		def.radius = row[5]
		def.damage = row[6]
		def.xp = row[7]
		def.knockback_resist = row[8]
		def.tint = row[9]
		def.appears_at = row[10]
		def.weight = row[11]
		def.elite = row[12]
		list.append(_keep(def, "res://data/enemies/%s.tres" % def.id))
	return list


func _weapons() -> Array[WeaponDef]:
	var list: Array[WeaponDef] = []
	for row: Array in [
		# id, title, description, kind, damage, cooldown, amount, area, speed, pierce, knockback, color
		[&"spark_bolt", "星火彈", "朝最近的敵人發射火花彈。", WeaponDef.Kind.BOLT, 9.0, 0.7, 1, 1.0, 15.0, 1, 3.0, Color(1.0, 0.8, 0.3)],
		[&"guard_aura", "守護光環", "持續傷害身邊一圈的敵人。", WeaponDef.Kind.AURA, 4.0, 0.4, 1, 2.6, 0.0, 1, 0.8, Color(0.35, 0.85, 1.0)],
		[&"moon_orbs", "月光球", "光球繞著你轉，撞到就傷害。", WeaponDef.Kind.ORBIT, 8.0, 0.25, 2, 1.2, 3.2, 1, 4.0, Color(0.75, 0.6, 1.0)],
		[&"shock_nova", "震波", "從腳下炸開一圈震波，把敵人推遠。", WeaponDef.Kind.NOVA, 14.0, 2.6, 1, 5.0, 0.0, 1, 14.0, Color(1.0, 0.6, 0.25)],
	]:
		var def := WeaponDef.new()
		def.id = row[0]
		def.title = row[1]
		def.description = row[2]
		def.kind = row[3]
		def.damage = row[4]
		def.cooldown = row[5]
		def.amount = row[6]
		def.area = row[7]
		def.speed = row[8]
		def.pierce = row[9]
		def.knockback = row[10]
		def.color = row[11]
		list.append(_keep(def, "res://data/weapons/%s.tres" % def.id))
	return list


func _passives() -> Array[PassiveDef]:
	var list: Array[PassiveDef] = []
	for row: Array in [
		[&"might", "力量", "所有傷害 +12%。", PassiveDef.Stat.MIGHT, 0.12],
		[&"haste", "迅捷", "冷卻時間 -8%。", PassiveDef.Stat.HASTE, 0.08],
		[&"area", "擴張", "範圍與彈體 +12%。", PassiveDef.Stat.AREA, 0.12],
		[&"swift", "輕快", "移動速度 +8%。", PassiveDef.Stat.SPEED, 0.08],
		[&"magnet", "磁力", "經驗吸取範圍 +30%。", PassiveDef.Stat.MAGNET, 0.3],
		[&"vitality", "體魄", "最大生命 +20。", PassiveDef.Stat.MAX_HP, 20.0],
		[&"regen", "再生", "每秒回復 0.5 生命。", PassiveDef.Stat.REGEN, 0.5],
	]:
		var def := PassiveDef.new()
		def.id = row[0]
		def.title = row[1]
		def.description = row[2]
		def.stat = row[3]
		def.per_level = row[4]
		list.append(_keep(def, "res://data/passives/%s.tres" % def.id))
	return list


func _theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = load(FONT)
	theme.default_font_size = 22
	theme.set_color(&"font_color", &"Label", Color.WHITE)
	theme.set_color(&"font_outline_color", &"Label", Color(0.1, 0.08, 0.16))
	theme.set_constant(&"outline_size", &"Label", 6)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.08, 0.16, 0.75)
	bar_bg.set_corner_radius_all(6)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.4, 0.8, 1.0)
	bar_fill.set_corner_radius_all(6)
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(1.0, 0.8, 0.2)
	button.set_corner_radius_all(14)
	button.content_margin_left = 28
	button.content_margin_right = 28
	button.content_margin_top = 12
	button.content_margin_bottom = 12
	theme.set_stylebox(&"normal", &"Button", button)
	var hover: StyleBoxFlat = button.duplicate()
	hover.bg_color = Color(1.0, 0.88, 0.4)
	theme.set_stylebox(&"hover", &"Button", hover)
	theme.set_stylebox(&"pressed", &"Button", hover)
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	theme.set_color(&"font_color", &"Button", Color(0.1, 0.08, 0.16))
	theme.set_color(&"font_hover_color", &"Button", Color(0.1, 0.08, 0.16))
	theme.set_color(&"font_pressed_color", &"Button", Color(0.1, 0.08, 0.16))
	return _keep(theme, "res://ui/theme.tres")


func _damage_number() -> Label3D:
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.text = "12"
	label.font = load(FONT)
	label.font_size = 56
	label.outline_size = 16
	label.outline_modulate = Color(0.1, 0.08, 0.16)
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return label


func _upgrade_card(theme: Theme) -> Button:
	var card := Button.new()
	card.name = "UpgradeCard"
	card.set_script(load("res://scripts/upgrade_card.gd"))
	card.theme = theme
	card.custom_minimum_size = Vector2(300, 180)
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.98, 0.97, 0.94)
	face.set_corner_radius_all(18)
	face.border_width_bottom = 6
	face.border_color = Color(0.75, 0.7, 0.62)
	card.add_theme_stylebox_override(&"normal", face)
	var hover: StyleBoxFlat = face.duplicate()
	hover.bg_color = Color(1.0, 0.95, 0.75)
	hover.border_color = Color(1.0, 0.7, 0.2)
	card.add_theme_stylebox_override(&"hover", hover)
	card.add_theme_stylebox_override(&"pressed", hover)
	card.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	SceneBuilder.add(card, margin, "Margin")
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	SceneBuilder.add(margin, box, "Box")
	var dark := Color(0.12, 0.1, 0.2)
	for spec: Array in [["Level", "NEW", 18, Color(0.9, 0.45, 0.1)], ["Title", "星火彈", 30, dark], ["Desc", "朝最近的敵人發射火花彈。", 19, Color(0.3, 0.28, 0.36)]]:
		var label := Label.new()
		label.text = spec[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override(&"font_size", spec[2])
		label.add_theme_color_override(&"font_color", spec[3])
		label.add_theme_constant_override(&"outline_size", 0)
		if spec[0] == "Desc":
			label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		SceneBuilder.add(box, SceneBuilder.unique(label), spec[0])
	return card


func _player(sprite: ShaderMaterial, shadow: ShaderMaterial) -> Node3D:
	var player := Node3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var shadow_node := MeshInstance3D.new()
	shadow_node.mesh = plane
	shadow_node.material_override = shadow
	shadow_node.scale = Vector3(2.0, 1.0, 2.0)
	SceneBuilder.add(player, shadow_node, "Shadow")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var body := MeshInstance3D.new()
	body.mesh = quad
	var material: ShaderMaterial = sprite.duplicate()
	material.set_shader_parameter(&"frame", 0.0)
	material.set_shader_parameter(&"outline", Color.WHITE)
	body.material_override = material
	body.scale = Vector3.ONE * 2.37
	SceneBuilder.add(player, SceneBuilder.unique(body), "Body")
	var xray := MeshInstance3D.new()
	xray.mesh = quad
	var xray_material := ShaderMaterial.new()
	xray_material.shader = load("res://shaders/sprite_xray.gdshader")
	xray_material.set_shader_parameter(&"atlas", load(ATLAS))
	xray_material.render_priority = 1
	xray.material_override = xray_material
	xray.scale = body.scale
	SceneBuilder.add(player, SceneBuilder.unique(xray), "Xray")
	return player


func _hud(theme: Theme) -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.name = "Hud"
	hud.set_script(load("res://scripts/hud.gd"))
	hud.set("card_scene", load("res://scenes/upgrade_card.tscn"))
	var root := Control.new()
	root.theme = theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(hud, root, "Root")

	var stick := Control.new()
	stick.set_script(load("res://addons/proto_kit/floating_stick.gd"))
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(stick), "Stick")
	var base := Panel.new()
	base.size = Vector2(200, 200)
	base.position = Vector2(140, 420)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override(&"panel", _round(Color(1, 1, 1, 0.16), 100, Color(1, 1, 1, 0.5)))
	SceneBuilder.add(stick, SceneBuilder.unique(base), "Base")
	var knob := Panel.new()
	knob.size = Vector2(84, 84)
	knob.position = Vector2(58, 58)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override(&"panel", _round(Color(1, 1, 1, 0.75), 42, Color(0.1, 0.08, 0.16, 0.6)))
	SceneBuilder.add(base, SceneBuilder.unique(knob), "Knob")

	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top"]:
		top.add_theme_constant_override("margin_" + side, 16)
	SceneBuilder.add(root, top, "Top")
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(top, column, "Column")
	var xp_bar := ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 14)
	xp_bar.show_percentage = false
	xp_bar.value = 35
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(column, SceneBuilder.unique(xp_bar), "XpBar")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 14)
	SceneBuilder.add(column, row, "Row")
	SceneBuilder.add(row, SceneBuilder.unique(_label("Lv.1", 26)), "LevelLabel")
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(220, 18)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.show_percentage = false
	hp_bar.value = 80
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(1.0, 0.35, 0.4)
	hp_fill.set_corner_radius_all(6)
	hp_bar.add_theme_stylebox_override(&"fill", hp_fill)
	SceneBuilder.add(row, SceneBuilder.unique(hp_bar), "HpBar")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(row, spacer, "Spacer")
	SceneBuilder.add(row, SceneBuilder.unique(_label("0:00", 30)), "TimeLabel")
	var spacer2: Control = spacer.duplicate()
	SceneBuilder.add(row, spacer2, "Spacer2")
	SceneBuilder.add(row, SceneBuilder.unique(_label("擊倒 0", 24)), "KillsLabel")

	var perf: Label = _label("60 fps", 15)
	perf.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	perf.position = Vector2(12, -34)
	perf.grow_vertical = Control.GROW_DIRECTION_BEGIN
	SceneBuilder.add(root, SceneBuilder.unique(perf), "Perf")

	var level_up := Control.new()
	level_up.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(level_up), "LevelUp")
	SceneBuilder.add(level_up, _dim(), "Dim")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	SceneBuilder.add(level_up, margin, "Margin")
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override(&"separation", 20)
	SceneBuilder.add(margin, stack, "Stack")
	var title: Label = _label("升級！選一張卡", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SceneBuilder.add(stack, title, "Title")
	var cards := HFlowContainer.new()
	cards.alignment = FlowContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override(&"h_separation", 18)
	cards.add_theme_constant_override(&"v_separation", 14)
	SceneBuilder.add(stack, SceneBuilder.unique(cards), "Cards")
	for i: int in 3:
		SceneBuilder.add(cards, SceneBuilder.instance("res://scenes/upgrade_card.tscn"), "Sample%d" % (i + 1))

	var result := Control.new()
	result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(result), "Result")
	SceneBuilder.add(result, _dim(), "Dim")
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(result, center, "Center")
	var panel := PanelContainer.new()
	var face: StyleBoxFlat = _round(Color(0.98, 0.97, 0.94), 22, Color(0.75, 0.7, 0.62))
	face.content_margin_left = 48
	face.content_margin_right = 48
	face.content_margin_top = 32
	face.content_margin_bottom = 32
	panel.add_theme_stylebox_override(&"panel", face)
	SceneBuilder.add(center, panel, "Panel")
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(&"separation", 18)
	SceneBuilder.add(panel, body, "Body")
	var result_title: Label = _label("倒下了", 46)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_color_override(&"font_color", Color(0.12, 0.1, 0.2))
	result_title.add_theme_constant_override(&"outline_size", 0)
	SceneBuilder.add(body, SceneBuilder.unique(result_title), "ResultTitle")
	var stats: Label = _label("存活 0:00 · 擊倒 0 · Lv.1", 24)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override(&"font_color", Color(0.3, 0.28, 0.36))
	stats.add_theme_constant_override(&"outline_size", 0)
	SceneBuilder.add(body, SceneBuilder.unique(stats), "ResultStats")
	var restart := Button.new()
	restart.text = "再來一局"
	restart.add_theme_font_size_override(&"font_size", 28)
	SceneBuilder.add(body, SceneBuilder.unique(restart), "Restart")
	return hud


func _main(actor_mesh: ArrayMesh, prop_mesh: ArrayMesh, sprite_node: ShaderMaterial, ground_mat: Material, glow_mat: Material, gem_mat: Material,
		aura_mat: Material, nova_mat: Material, enemies: Array[EnemyDef], weapons: Array[WeaponDef], passives: Array[PassiveDef]) -> Node3D:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	var huge := AABB(Vector3(-2000, -10, -2000), Vector3(4000, 40, 4000))

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.75, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.62, 0.8, 0.95)
	env.fog_density = 1.0
	env.fog_depth_begin = 40.0
	env.fog_depth_end = 110.0
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	SceneBuilder.add(main, world_env, "WorldEnvironment")

	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = ground_mat
	SceneBuilder.add(main, SceneBuilder.unique(ground), "Ground")

	var decor := MultiMeshInstance3D.new()
	decor.set_script(load("res://scripts/decor.gd"))
	decor.multimesh = _multimesh(prop_mesh, false, true)
	decor.custom_aabb = huge
	SceneBuilder.add(main, SceneBuilder.unique(decor), "Decor")

	var player: Node3D = SceneBuilder.instance("res://scenes/player.tscn")
	SceneBuilder.add(main, SceneBuilder.unique(player), "Player")

	var horde := MultiMeshInstance3D.new()
	horde.set_script(load("res://scripts/horde.gd"))
	horde.multimesh = _multimesh(actor_mesh, false, true)
	horde.custom_aabb = huge
	horde.set("defs", enemies)
	SceneBuilder.add(main, SceneBuilder.unique(horde), "Horde")

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var gems := MultiMeshInstance3D.new()
	gems.set_script(load("res://scripts/gems.gd"))
	gems.multimesh = _multimesh(quad, false, true)
	gems.material_override = gem_mat
	gems.custom_aabb = huge
	SceneBuilder.add(main, SceneBuilder.unique(gems), "Gems")

	var glow := MultiMeshInstance3D.new()
	glow.set_script(load("res://scripts/glow_pool.gd"))
	glow.multimesh = _multimesh(quad, true, true)
	glow.material_override = glow_mat
	glow.custom_aabb = huge
	SceneBuilder.add(main, SceneBuilder.unique(glow), "Glow")

	var fx := Node.new()
	fx.set_script(load("res://scripts/fx.gd"))
	fx.set("glow", glow)
	SceneBuilder.add(main, SceneBuilder.unique(fx), "Fx")

	var arsenal := Node3D.new()
	arsenal.set_script(load("res://scripts/arsenal.gd"))
	arsenal.set("horde", horde)
	arsenal.set("glow", glow)
	arsenal.set("fx", fx)
	arsenal.set("weapon_pool", weapons)
	arsenal.set("passive_pool", passives)
	arsenal.set("starting_weapon", weapons[0])
	SceneBuilder.add(main, SceneBuilder.unique(arsenal), "Arsenal")
	var ring := PlaneMesh.new()
	ring.size = Vector2.ONE
	for spec: Array in [["Aura", aura_mat, 5.2], ["Nova", nova_mat, 10.0]]:
		var node := MeshInstance3D.new()
		node.mesh = ring
		node.material_override = spec[1]
		node.position = Vector3(0, 0.05, 0)
		node.scale = Vector3(spec[2], 1.0, spec[2])
		SceneBuilder.add(arsenal, SceneBuilder.unique(node), spec[0])

	var numbers := Node3D.new()
	numbers.set_script(load("res://scripts/damage_numbers.gd"))
	numbers.set("number_scene", load("res://scenes/damage_number.tscn"))
	SceneBuilder.add(main, SceneBuilder.unique(numbers), "Numbers")

	# Editor-only look references for the horde (the horde itself is drawn at runtime); main.gd hides them.
	var previews := Node3D.new()
	SceneBuilder.add(main, SceneBuilder.unique(previews), "Previews")
	var feet := QuadMesh.new()
	feet.size = Vector2.ONE
	feet.center_offset = Vector3(0.0, 0.5, 0.0)
	for k: int in enemies.size():
		var def: EnemyDef = enemies[k]
		var node := MeshInstance3D.new()
		node.mesh = feet
		var material: ShaderMaterial = sprite_node.duplicate()
		material.set_shader_parameter(&"frame", float(def.frame))
		node.material_override = material
		node.scale = Vector3.ONE * def.size
		node.position = Vector3(-4.5 + 3.0 * k, 0.0, -3.0)
		SceneBuilder.add(previews, node, String(def.id).capitalize())

	var rig := Node3D.new()
	rig.set_script(load("res://scripts/camera_rig.gd"))
	rig.set("target", player)
	SceneBuilder.add(main, SceneBuilder.unique(rig), "CameraRig")
	var camera := Camera3D.new()
	# The reference camera: perspective FOV 70, pitch 0.45 rad (about 26 degrees), 9 m from the player.
	var pitch: float = 0.45
	var distance: float = 9.0
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.position.y += 1.0
	camera.fov = 70.0
	camera.far = 300.0
	SceneBuilder.add(rig, SceneBuilder.unique(camera), "Camera")

	var hud: Node = SceneBuilder.instance("res://scenes/hud.tscn")
	SceneBuilder.add(main, SceneBuilder.unique(hud), "Hud")
	return main


func _multimesh(mesh: Mesh, colors: bool, custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	return mm


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	return label


func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


func _round(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(3)
	box.border_color = border
	return box
