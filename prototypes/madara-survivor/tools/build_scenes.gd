extends SceneTree
## One-time authoring tool: writes the slice's materials, meshes, data resources and scenes.
##   godot --headless --path prototypes/madara-survivor --script res://tools/build_scenes.gd
## Existing files are skipped (scenes) or kept (resources), so hand edits survive a rerun; delete a file to rebuild it.
## After the first run the saved .tscn/.tres files are the source: edit them in the editor, not here.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")

const ATLAS := "res://assets/sprites/atlas.png"
const FONT := "res://ui/fonts/NotoSansTC.ttf"
const INK := Color(0.12, 0.08, 0.1)
const CHAKRA := Color(0.4, 0.75, 1.0)
const BLOOD := Color(0.86, 0.2, 0.22)

var _failed: bool = false


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var sprite_node: ShaderMaterial = _material("res://materials/sprite_node.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": false})
	var sprite_instanced: ShaderMaterial = _material("res://materials/sprite_instanced.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": true, "flash_color": Color(1.0, 0.92, 0.85)})
	var sprite_prop: ShaderMaterial = _material("res://materials/sprite_prop.tres", "res://shaders/sprite_billboard.gdshader", {
		"atlas": load(ATLAS), "use_instance_custom": true, "lean": 0.0, "bob": 0.0, "see_through_enabled": true})
	var shadow: ShaderMaterial = _material("res://materials/blob_shadow.tres", "res://shaders/blob_shadow.gdshader", {})
	var ground: ShaderMaterial = _material("res://materials/sand.tres", "res://shaders/ground.gdshader", {})
	var glow: ShaderMaterial = _material("res://materials/fx_glow.tres", "res://shaders/fx_glow.gdshader", {})
	var dust: ShaderMaterial = _material("res://materials/fx_dust.tres", "res://shaders/fx_dust.gdshader", {})
	var orb: ShaderMaterial = _material("res://materials/chakra_orb.tres", "res://shaders/gem.gdshader", {})
	var arc: ShaderMaterial = _material("res://materials/gunbai_arc.tres", "res://shaders/ground_cone.gdshader", {})
	var danger: ShaderMaterial = _material("res://materials/danger_ring.tres", "res://shaders/ground_ring.gdshader", {
		"color": Color(1.0, 0.25, 0.15, 0.9), "thickness": 0.05, "fill_with_progress": true, "fade_with_progress": 0.0})
	var tai_arc: ShaderMaterial = _material("res://materials/taijutsu_arc.tres", "res://shaders/ground_cone.gdshader", {
		"color": Color(1.0, 0.95, 0.85, 0.85), "half_angle": 0.8})

	var actor_mesh: ArrayMesh = _actor_mesh(shadow, sprite_instanced, "res://assets/meshes/actor_mesh.tres")
	var prop_mesh: ArrayMesh = _actor_mesh(shadow, sprite_prop, "res://assets/meshes/prop_mesh.tres")
	var enemies: Array[EnemyDef] = _enemies()
	var passives: Array[PassiveDef] = _passives()
	var jutsu: Array[JutsuDef] = _jutsu()
	var theme: Theme = _theme()

	_save(_damage_number(), "res://scenes/damage_number.tscn")
	_save(_upgrade_card(theme), "res://scenes/upgrade_card.tscn")
	_save(_player(sprite_node, shadow), "res://scenes/player.tscn")
	_save(_hud(theme), "res://scenes/hud.tscn", ["res://scenes/upgrade_card.tscn"])
	var main: Node3D = _main(actor_mesh, prop_mesh, sprite_node, ground, glow, dust, orb, [tai_arc, arc, danger], enemies, passives, jutsu)
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


## Shadow plane (surface 0) and feet-pivoted sprite quad (surface 1): one MultiMesh draws both.
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
		# id, frame, hp, speed, size, radius, damage, xp, resist, tint, appears_at, weight, cost, elite,
		# jutsu (0 none, 1 fire, 2 water, 3 earth), cast_range, cast_cooldown
		[&"genin", 1, 20.0, 3.2, 2.0, 0.5, 6.0, 1, 0.0, Color(0.6, 0.75, 0.5), 0.0, 1.0, 1.0, false, 0, 0.0, 0.0],
		[&"masked", 2, 14.0, 4.6, 2.0, 0.5, 5.0, 1, 0.0, Color(0.6, 0.62, 0.68), 90.0, 0.6, 1.0, false, 0, 0.0, 0.0],
		[&"heavy", 3, 70.0, 2.4, 2.4, 0.7, 10.0, 3, 0.5, Color(0.7, 0.58, 0.42), 180.0, 0.3, 3.0, false, 0, 0.0, 0.0],
		[&"elite", 4, 900.0, 2.8, 2.8, 0.85, 18.0, 30, 0.85, Color(0.95, 0.92, 0.85), 0.0, 0.0, 10.0, true, 0, 0.0, 0.0],
		[&"caster_fire", 8, 24.0, 3.0, 2.0, 0.5, 5.0, 2, 0.0, Color(0.9, 0.4, 0.3), 120.0, 0.22, 2.0, false, 1, 11.0, 3.2],
		[&"caster_water", 9, 24.0, 3.0, 2.0, 0.5, 5.0, 2, 0.0, Color(0.4, 0.6, 0.95), 150.0, 0.22, 2.0, false, 2, 12.0, 2.4],
		[&"caster_earth", 10, 30.0, 2.6, 2.0, 0.5, 5.0, 2, 0.0, Color(0.75, 0.55, 0.35), 210.0, 0.2, 2.0, false, 3, 13.0, 4.0],
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
		def.cost = row[12]
		def.elite = row[13]
		def.jutsu = row[14]
		def.cast_range = row[15]
		def.cast_cooldown = row[16]
		list.append(_keep(def, "res://data/enemies/%s.tres" % def.id))
	return list


func _jutsu() -> Array[JutsuDef]:
	var list: Array[JutsuDef] = []
	for row: Array in [
		[&"taijutsu", "體術", JutsuDef.Kind.TAIJUTSU, "近身三連擊，第三下踢飛敵人撞進人群。",
			["連擊更快。", "出手範圍變大。", "第三下踢擊震出一圈衝擊波。", "第三下把人踢得更遠、更狠。"]],
		[&"gunbai", "團扇", JutsuDef.Kind.GUNBAI, "揮出 120° 扇形重擊，把前方一整排掃飛；敵人的火遁、水遁會被扇回去。",
			["團扇變大，傷害提高。", "團扇再變大。", "掃飛的力道更強。", "揮扇後捲起一陣暴風，再推一次。"]],
		[&"fireball", "火遁・豪火球", JutsuDef.Kind.FIREBALL, "朝敵人吐出拳頭大的火球，命中爆炸。",
			["火球長到一個人大，爆炸更大。", "火球比人還大，爆炸處留下燃燒的地面。", "一次吐兩顆，火地燒得更久。", "火球有兩人高；燒著的敵人死掉時會爆炸，把火傳出去。"]],
		[&"wood", "木遁・樹界降誕", JutsuDef.Kind.WOOD, "樹根從敵群腳下竄出，把一整圈敵人綁在原地。",
			["樹海更大，綁得更久。", "樹海再擴大。", "一次長出兩片樹海（前後各一）。", "學過火遁時，樹根會著火，把綁住的人一起燒。"]],
		[&"susanoo", "須佐能乎", JutsuDef.Kind.SUSANOO, "按「須佐」召出查克拉巨人：7 秒內自動揮出巨大斬擊，替你擋下七成傷害。",
			["第二階段：巨人更大，撐 8 秒。", "半身：斬擊更遠更重，撐 9 秒。", "鎧甲：再大一圈，冷卻更短。", "完全體：斬擊橫掃一整圈，撐 12 秒。"]],
		[&"chibaku", "輪迴眼・地爆天星", JutsuDef.Kind.CHIBAKU, "支配滿了就能發動：把整片戰場的敵人吸上天，壓成一顆星。",
			[]],
		[&"sharingan", "寫輪眼", JutsuDef.Kind.SHARINGAN, "看穿攻擊：快被打中時留下殘影閃開（6 秒一次）。",
			["看穿得更快（4.5 秒一次）。", "殘影會爆開，把攻擊你的人震飛。", "可以連續閃兩次，3.5 秒補一次。", "萬花筒：閃開後無敵 1 秒，3 秒補一次。"]],
	]:
		var def := JutsuDef.new()
		def.id = row[0]
		def.title = row[1]
		def.kind = row[2]
		def.summary = row[3]
		def.level_texts = PackedStringArray(row[4])
		if def.kind == JutsuDef.Kind.SUSANOO:
			def.min_player_level = 5
		if def.kind == JutsuDef.Kind.CHIBAKU:
			def.max_level = 1
			def.min_player_level = 8
		list.append(_keep(def, "res://data/jutsu/%s.tres" % def.id))
	return list


func _passives() -> Array[PassiveDef]:
	var list: Array[PassiveDef] = []
	for row: Array in [
		[&"might", "查克拉之力", "所有忍術傷害 +15%。", PassiveDef.Stat.MIGHT, 0.15],
		[&"area", "查克拉擴張", "所有忍術範圍與火球 +10%。", PassiveDef.Stat.AREA, 0.1],
		[&"haste", "結印速度", "所有忍術冷卻 -10%。", PassiveDef.Stat.HASTE, 0.1],
		[&"crit", "看破", "暴擊率 +6%。", PassiveDef.Stat.CRIT, 0.06],
		[&"swift", "瞬步", "移動速度 +8%。", PassiveDef.Stat.SPEED, 0.08],
		[&"magnet", "查克拉感知", "查克拉吸取範圍 +35%。", PassiveDef.Stat.MAGNET, 0.35],
		[&"vitality", "柱間細胞", "最大生命 +25。", PassiveDef.Stat.MAX_HP, 25.0],
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
	theme.set_color(&"font_outline_color", &"Label", INK)
	theme.set_constant(&"outline_size", &"Label", 7)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.06, 0.08, 0.7)
	bar_bg.set_corner_radius_all(4)
	bar_bg.set_border_width_all(2)
	bar_bg.border_color = INK
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = CHAKRA
	bar_fill.set_corner_radius_all(4)
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	var button := StyleBoxFlat.new()
	button.bg_color = BLOOD
	button.set_corner_radius_all(10)
	button.content_margin_left = 30
	button.content_margin_right = 30
	button.content_margin_top = 12
	button.content_margin_bottom = 12
	theme.set_stylebox(&"normal", &"Button", button)
	var hover: StyleBoxFlat = button.duplicate()
	hover.bg_color = BLOOD.lightened(0.15)
	theme.set_stylebox(&"hover", &"Button", hover)
	theme.set_stylebox(&"pressed", &"Button", hover)
	theme.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		theme.set_color(state, &"Button", Color.WHITE)
	return _keep(theme, "res://ui/theme.tres")


func _damage_number() -> Label3D:
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.text = "52"
	label.font = load(FONT)
	label.font_size = 64
	label.outline_size = 18
	label.outline_modulate = INK
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	return label


func _upgrade_card(theme: Theme) -> Button:
	var card := Button.new()
	card.name = "UpgradeCard"
	card.set_script(load("res://scripts/upgrade_card.gd"))
	card.theme = theme
	card.custom_minimum_size = Vector2(300, 170)
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.96, 0.93, 0.86)
	face.set_corner_radius_all(12)
	face.set_border_width_all(3)
	face.border_width_bottom = 7
	face.border_color = INK
	card.add_theme_stylebox_override(&"normal", face)
	var hover: StyleBoxFlat = face.duplicate()
	hover.bg_color = Color(1.0, 0.9, 0.82)
	hover.border_color = BLOOD
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
	for spec: Array in [["Level", "NEW", 18, BLOOD], ["Title", "團扇之力", 30, INK], ["Desc", "團扇傷害 +20%。", 19, Color(0.32, 0.26, 0.28)]]:
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
	player.set("use_poses", true)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var shadow_node := MeshInstance3D.new()
	shadow_node.mesh = plane
	shadow_node.material_override = shadow
	shadow_node.scale = Vector3.ONE * 2.3
	SceneBuilder.add(player, shadow_node, "Shadow")
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.center_offset = Vector3(0.0, 0.5, 0.0)
	var body := MeshInstance3D.new()
	body.mesh = quad
	var material: ShaderMaterial = sprite.duplicate()
	material.set_shader_parameter(&"frame", 0.0)
	body.material_override = material
	# The pose cells share one scale (build_atlas.py groups), which leaves Madara at ~70% of the cell height.
	body.scale = Vector3.ONE * 3.6
	SceneBuilder.add(player, SceneBuilder.unique(body), "Body")
	var xray := MeshInstance3D.new()
	xray.mesh = quad
	var xray_material := ShaderMaterial.new()
	xray_material.shader = load("res://shaders/sprite_xray.gdshader")
	xray_material.set_shader_parameter(&"atlas", load(ATLAS))
	xray_material.set_shader_parameter(&"color", Color(1.0, 0.35, 0.3, 0.6))
	xray_material.render_priority = 1
	xray.material_override = xray_material
	xray.scale = body.scale
	SceneBuilder.add(player, SceneBuilder.unique(xray), "Xray")
	# Susanoo: the chakra giant behind Madara (placeholder: his own sprite, violet and huge).
	var susanoo := MeshInstance3D.new()
	susanoo.mesh = quad
	var sus_material := ShaderMaterial.new()
	sus_material.shader = load("res://shaders/susanoo.gdshader")
	sus_material.set_shader_parameter(&"atlas", load(ATLAS))
	susanoo.material_override = sus_material
	susanoo.scale = Vector3.ONE * 6.0
	SceneBuilder.add(player, SceneBuilder.unique(susanoo), "Susanoo")
	# Sharingan afterimages: top-level, so they stay where Madara stood while he slips away.
	var ghosts := Node3D.new()
	SceneBuilder.add(player, SceneBuilder.unique(ghosts), "Ghosts")
	for g: int in 3:
		var ghost := MeshInstance3D.new()
		ghost.mesh = quad
		ghost.top_level = true
		ghost.scale = body.scale
		var ghost_material := ShaderMaterial.new()
		ghost_material.shader = load("res://shaders/sprite_ghost.gdshader")
		ghost_material.set_shader_parameter(&"atlas", load(ATLAS))
		ghost.material_override = ghost_material
		SceneBuilder.add(ghosts, ghost, "Ghost%d" % (g + 1))
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
	stick.set_script(load("res://scripts/touch_stick.gd"))
	stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(stick), "Stick")
	var base := Panel.new()
	base.size = Vector2(190, 190)
	base.position = Vector2(110, 320)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override(&"panel", _round(Color(1, 1, 1, 0.14), 95, Color(1, 1, 1, 0.45)))
	SceneBuilder.add(stick, SceneBuilder.unique(base), "Base")
	var knob := Panel.new()
	knob.size = Vector2(80, 80)
	knob.position = Vector2(55, 55)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.add_theme_stylebox_override(&"panel", _round(Color(1, 1, 1, 0.7), 40, Color(INK, 0.6)))
	SceneBuilder.add(base, SceneBuilder.unique(knob), "Knob")

	var dash := Control.new()
	dash.set_script(load("res://scripts/touch_button.gd"))
	dash.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dash.offset_left = -170
	dash.offset_top = -170
	dash.offset_right = -36
	dash.offset_bottom = -36
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(dash), "DashButton")
	var face := Panel.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.pivot_offset = Vector2(67, 67)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override(&"panel", _round(Color(BLOOD, 0.8), 67, Color(1, 1, 1, 0.75)))
	SceneBuilder.add(dash, SceneBuilder.unique(face), "Face")
	var dash_label: Label = _label("瞬身", 30)
	dash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(face, dash_label, "Label")

	var ult := Control.new()
	ult.set_script(load("res://scripts/touch_button.gd"))
	ult.set("action", &"ultimate")
	ult.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ult.offset_left = -150
	ult.offset_top = -300
	ult.offset_right = -46
	ult.offset_bottom = -196
	ult.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(ult), "UltButton")
	var ult_face := Panel.new()
	ult_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ult_face.pivot_offset = Vector2(52, 52)
	ult_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ult_face.add_theme_stylebox_override(&"panel", _round(Color(0.35, 0.15, 0.55, 0.85), 52, Color(0.85, 0.7, 1.0, 0.9)))
	SceneBuilder.add(ult, SceneBuilder.unique(ult_face), "Face")
	var ult_label: Label = _label("地爆\n天星", 22)
	ult_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ult_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(ult_face, ult_label, "Label")

	var sus := Control.new()
	sus.set_script(load("res://scripts/touch_button.gd"))
	sus.set("action", &"susanoo")
	sus.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sus.offset_left = -300
	sus.offset_top = -140
	sus.offset_right = -196
	sus.offset_bottom = -36
	sus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(root, SceneBuilder.unique(sus), "SusButton")
	var sus_face := Panel.new()
	sus_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sus_face.pivot_offset = Vector2(52, 52)
	sus_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus_face.add_theme_stylebox_override(&"panel", _round(Color(0.45, 0.2, 0.7, 0.85), 52, Color(0.85, 0.7, 1.0, 0.9)))
	SceneBuilder.add(sus, SceneBuilder.unique(sus_face), "Face")
	var sus_label: Label = _label("須佐", 26)
	sus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SceneBuilder.add(sus_face, sus_label, "Label")

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
	xp_bar.custom_minimum_size = Vector2(0, 12)
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
	hp_fill.bg_color = BLOOD
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override(&"fill", hp_fill)
	SceneBuilder.add(row, SceneBuilder.unique(hp_bar), "HpBar")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	SceneBuilder.add(row, spacer, "Spacer")
	SceneBuilder.add(row, SceneBuilder.unique(_label("0:00", 30)), "TimeLabel")
	var spacer2: Control = spacer.duplicate()
	SceneBuilder.add(row, spacer2, "Spacer2")
	var kill_box := VBoxContainer.new()
	kill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_box.add_theme_constant_override(&"separation", -6)
	SceneBuilder.add(row, kill_box, "KillBox")
	var kills: Label = _label("0", 40)
	kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	SceneBuilder.add(kill_box, SceneBuilder.unique(kills), "KillsLabel")
	var kills_caption: Label = _label("KILLS", 16)
	kills_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kills_caption.add_theme_color_override(&"font_color", Color(1.0, 0.8, 0.75))
	SceneBuilder.add(kill_box, kills_caption, "Caption")
	var dom_row := HBoxContainer.new()
	dom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dom_row.add_theme_constant_override(&"separation", 10)
	SceneBuilder.add(column, dom_row, "DominanceRow")
	var dom_label: Label = _label("支配", 18)
	dom_label.add_theme_color_override(&"font_color", Color(0.85, 0.7, 1.0))
	SceneBuilder.add(dom_row, SceneBuilder.unique(dom_label), "DominanceLabel")
	var dom_bar := ProgressBar.new()
	dom_bar.custom_minimum_size = Vector2(260, 12)
	dom_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dom_bar.show_percentage = false
	dom_bar.value = 40
	dom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dom_fill := StyleBoxFlat.new()
	dom_fill.bg_color = Color(0.62, 0.35, 0.95)
	dom_fill.set_corner_radius_all(4)
	dom_bar.add_theme_stylebox_override(&"fill", dom_fill)
	SceneBuilder.add(dom_row, SceneBuilder.unique(dom_bar), "DominanceBar")

	var combo := VBoxContainer.new()
	combo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combo.offset_left = -260
	combo.offset_right = 260
	combo.offset_top = 92
	combo.offset_bottom = 190
	combo.alignment = BoxContainer.ALIGNMENT_BEGIN
	combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo.add_theme_constant_override(&"separation", -4)
	SceneBuilder.add(root, SceneBuilder.unique(combo), "Combo")
	var combo_count: Label = _label("47 KILLS", 52)
	combo_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_count.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.8))
	combo_count.add_theme_color_override(&"font_outline_color", Color(0.45, 0.05, 0.08))
	combo_count.add_theme_constant_override(&"outline_size", 12)
	SceneBuilder.add(combo, SceneBuilder.unique(combo_count), "ComboCount")
	var combo_title: Label = _label("SHINOBI HUNTER", 26)
	combo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_title.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
	SceneBuilder.add(combo, SceneBuilder.unique(combo_title), "ComboTitle")

	var darken := ColorRect.new()
	darken.color = Color(0.06, 0.02, 0.12, 0.55)
	darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(darken), "Darken")
	root.move_child(darken, 0)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.98, 1.0, 1.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SceneBuilder.add(root, SceneBuilder.unique(flash), "Flash")

	var perf: Label = _label("60 fps", 14)
	perf.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	perf.position = Vector2(12, -30)
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
	var title: Label = _label("查克拉解放 — 選一張", 40)
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
	var face_box: StyleBoxFlat = _round(Color(0.96, 0.93, 0.86), 14, INK)
	face_box.content_margin_left = 48
	face_box.content_margin_right = 48
	face_box.content_margin_top = 32
	face_box.content_margin_bottom = 32
	panel.add_theme_stylebox_override(&"panel", face_box)
	SceneBuilder.add(center, panel, "Panel")
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override(&"separation", 18)
	SceneBuilder.add(panel, body, "Body")
	var result_title: Label = _label("戰場已被支配", 46)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_color_override(&"font_color", INK)
	result_title.add_theme_constant_override(&"outline_size", 0)
	SceneBuilder.add(body, SceneBuilder.unique(result_title), "ResultTitle")
	var stats: Label = _label("10:00 · 擊倒 0 · 最大連殺 0 · Lv.1", 24)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override(&"font_color", Color(0.32, 0.26, 0.28))
	stats.add_theme_constant_override(&"outline_size", 0)
	SceneBuilder.add(body, SceneBuilder.unique(stats), "ResultStats")
	var restart := Button.new()
	restart.text = "再戰"
	restart.add_theme_font_size_override(&"font_size", 28)
	SceneBuilder.add(body, SceneBuilder.unique(restart), "Restart")
	return hud


func _main(actor_mesh: ArrayMesh, prop_mesh: ArrayMesh, sprite_node: ShaderMaterial, ground_mat: Material, glow_mat: Material,
		dust_mat: Material, orb_mat: Material, arcs: Array, enemies: Array[EnemyDef], passives: Array[PassiveDef],
		jutsu_defs: Array[JutsuDef]) -> Node3D:
	var main := Node3D.new()
	main.name = "Main"
	main.set_script(load("res://scripts/main.gd"))
	var huge := AABB(Vector3(-2000, -10, -2000), Vector3(4000, 60, 4000))

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.95, 0.8, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.95, 0.8, 0.62)
	env.fog_density = 1.0
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 70.0
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	SceneBuilder.add(main, world_env, "WorldEnvironment")

	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
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
	horde.set("obstacles", decor)
	SceneBuilder.add(main, SceneBuilder.unique(horde), "Horde")

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var gems := MultiMeshInstance3D.new()
	gems.set_script(load("res://scripts/gems.gd"))
	gems.multimesh = _multimesh(quad, false, true)
	gems.material_override = orb_mat
	gems.custom_aabb = huge
	SceneBuilder.add(main, SceneBuilder.unique(gems), "Gems")

	var pools: Array[MultiMeshInstance3D] = []
	for spec: Array in [["Dust", dust_mat], ["Glow", glow_mat]]:
		var pool := MultiMeshInstance3D.new()
		pool.set_script(load("res://scripts/glow_pool.gd"))
		pool.multimesh = _multimesh(quad, true, true)
		pool.material_override = spec[1]
		pool.custom_aabb = huge
		SceneBuilder.add(main, SceneBuilder.unique(pool), spec[0])
		pools.append(pool)

	var fx := Node.new()
	fx.set_script(load("res://scripts/fx.gd"))
	fx.set("dust_pool", pools[0])
	fx.set("glow", pools[1])
	SceneBuilder.add(main, SceneBuilder.unique(fx), "Fx")

	var jutsu := Node3D.new()
	jutsu.set_script(load("res://scripts/jutsu.gd"))
	jutsu.set("horde", horde)
	jutsu.set("fx", fx)
	jutsu.set("glow", pools[1])
	jutsu.set("starting", jutsu_defs[0])

	var enemy_jutsu := Node3D.new()
	enemy_jutsu.set_script(load("res://scripts/enemy_jutsu.gd"))
	enemy_jutsu.set("horde", horde)
	enemy_jutsu.set("fx", fx)
	enemy_jutsu.set("glow", pools[1])
	SceneBuilder.add(main, SceneBuilder.unique(enemy_jutsu), "EnemyJutsu")
	var warnings := Node3D.new()
	SceneBuilder.add(enemy_jutsu, SceneBuilder.unique(warnings), "Warnings")
	var warn_plane := PlaneMesh.new()
	warn_plane.size = Vector2.ONE
	for w: int in 8:
		var ring := MeshInstance3D.new()
		ring.mesh = warn_plane
		ring.material_override = arcs[2].duplicate()
		ring.top_level = true
		ring.scale = Vector3(4.0, 1.0, 4.0)
		SceneBuilder.add(warnings, ring, "Warning%d" % (w + 1))
	jutsu.set("enemy_jutsu", enemy_jutsu)

	var ultimate := Node3D.new()
	ultimate.set_script(load("res://scripts/ultimate.gd"))
	ultimate.set("horde", horde)
	ultimate.set("fx", fx)
	SceneBuilder.add(main, SceneBuilder.unique(ultimate), "Ultimate")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var core := MeshInstance3D.new()
	core.mesh = sphere
	var core_material := ShaderMaterial.new()
	core_material.shader = load("res://shaders/core.gdshader")
	core.material_override = core_material
	core.top_level = true
	core.position = Vector3(0, 9, -2)
	SceneBuilder.add(ultimate, SceneBuilder.unique(core), "Core")
	SceneBuilder.add(main, SceneBuilder.unique(jutsu), "Jutsu")
	var flat := PlaneMesh.new()
	flat.size = Vector2.ONE
	for spec: Array in [["TaiArc", arcs[0], 4.6], ["FanArc", arcs[1], 8.8]]:
		var arc := MeshInstance3D.new()
		arc.mesh = flat
		arc.material_override = spec[1]
		arc.position = Vector3(0, 0.06, 0)
		arc.scale = Vector3.ONE * spec[2]
		SceneBuilder.add(jutsu, SceneBuilder.unique(arc), spec[0])

	var upgrades := Node.new()
	upgrades.set_script(load("res://scripts/upgrades.gd"))
	upgrades.set("jutsu", jutsu)
	upgrades.set("jutsu_pool", jutsu_defs.slice(1))
	upgrades.set("pool", passives)
	SceneBuilder.add(main, SceneBuilder.unique(upgrades), "Upgrades")

	var sfx := Node.new()
	sfx.set_script(load("res://scripts/sfx.gd"))
	SceneBuilder.add(main, SceneBuilder.unique(sfx), "Sfx")

	var numbers := Node3D.new()
	numbers.set_script(load("res://scripts/damage_numbers.gd"))
	numbers.set("number_scene", load("res://scenes/damage_number.tscn"))
	SceneBuilder.add(main, SceneBuilder.unique(numbers), "Numbers")

	# Editor-only look references for the army (the horde itself is drawn at runtime); main.gd hides them.
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
		node.position = Vector3(-4.5 + 3.0 * k, 0.0, -3.5)
		SceneBuilder.add(previews, node, String(def.id).capitalize())

	var rig := Node3D.new()
	rig.set_script(load("res://scripts/camera_rig.gd"))
	rig.set("target", player)
	ultimate.set("rig", rig)
	SceneBuilder.add(main, SceneBuilder.unique(rig), "CameraRig")
	var camera := Camera3D.new()
	# Steeper than the pixel reference (26 degrees): the Gunbai cone and danger zones must read on the ground.
	var pitch: float = deg_to_rad(42.0)
	var distance: float = 13.0
	camera.position = Vector3(0.0, sin(pitch) * distance + 1.0, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.fov = 50.0
	camera.far = 200.0
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
	dim.color = Color(0.08, 0.03, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


func _round(color: Color, radius: int, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(3)
	box.border_color = border
	return box
