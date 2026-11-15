extends SceneTree
## One-time authoring tool. Saved scenes are the source; existing scenes are
## skipped unless --overwrite is explicitly passed, never rebuilt during normal
## project import, execution or tests.

const SceneBuilder = preload("res://addons/proto_kit/scene_builder.gd")
const MODEL := "res://assets/boss/boss_animated.glb"
const BOSS := "res://scenes/boss.tscn"
const BASE := "res://scenes/battlefield.tscn"
const VARIANT := "res://scenes/boss_battlefield.tscn"
const MAP := "res://scenes/map_01_green_rust.tscn"
const ARMOR := {
	"Melee": ["res://assets/armor/melee.glb", "res://scenes/melee_display.tscn"],
	"Tank": ["res://assets/armor/tank.glb", "res://scenes/tank_display.tscn"],
	"Phido": ["res://assets/armor/phido.glb", "res://scenes/phido_display.tscn"],
}


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	var boss := Node3D.new()
	boss.name = "Boss"
	boss.set_script(load("res://scripts/boss.gd"))
	SceneBuilder.add(boss, SceneBuilder.unique(SceneBuilder.instance(MODEL)), "Model")
	var result: Dictionary = SceneBuilder.save_scene(boss, BOSS, {"expected_refs": [MODEL]})
	if not result.ok:
		quit(1)
		return

	for kind: String in ARMOR:
		var armor := Node3D.new()
		armor.name = kind
		armor.set_script(load("res://scripts/armor_display.gd"))
		SceneBuilder.add(armor, SceneBuilder.unique(SceneBuilder.instance(ARMOR[kind][0])), "Model")
		result = SceneBuilder.save_scene(armor, ARMOR[kind][1], {"expected_refs": [ARMOR[kind][0]]})
		if not result.ok:
			quit(1)
			return

	if FileAccess.file_exists(VARIANT) and "--overwrite" not in OS.get_cmdline_user_args():
		print("skip (exists): ", VARIANT)
		quit(0)
		return
	var scene := Node3D.new()
	scene.name = "BossBattlefield"
	scene.set_script(load("res://scripts/boss_battlefield.gd"))
	var battlefield: Node3D = SceneBuilder.instance(BASE) as Node3D
	battlefield.set_script(load("res://scripts/boss_battle_session.gd"))
	SceneBuilder.add(scene, battlefield, "Battlefield")
	var boss_instance: Node3D = SceneBuilder.instance(BOSS) as Node3D
	boss_instance.position = Vector3(0.0, 12.0, -20.0)
	boss_instance.rotation.y = deg_to_rad(150.0)
	SceneBuilder.add(scene, SceneBuilder.unique(boss_instance), "Boss")

	# Sample real map collision heights once while authoring; saved nodes are then
	# directly movable in the editor, without a runtime placement generator.
	var terrain: Node3D = SceneBuilder.instance(MAP) as Node3D
	root.add_child(terrain)
	await physics_frame
	await physics_frame
	var armor_group := Node3D.new()
	SceneBuilder.add(scene, armor_group, "Armor")
	var placements: Array[Array] = [
		["Melee", Vector2(-14, -65)], ["Tank", Vector2(14, -65)],
		["Tank", Vector2(-14, -51)], ["Melee", Vector2(14, -51)],
		["Melee", Vector2(-14, -37)], ["Tank", Vector2(14, -37)],
		["Tank", Vector2(-14, -23)], ["Melee", Vector2(14, -23)],
		["Phido", Vector2(-5, -70)], ["Phido", Vector2(5, -70)],
	]
	for i: int in placements.size():
		var kind: String = placements[i][0]
		var point: Vector2 = placements[i][1]
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, 100.0, point.y), Vector3(point.x, -100.0, point.y), 1)
		var hit: Dictionary = terrain.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			push_error("No map surface at " + str(point))
			quit(1)
			return
		var unit: Node3D = SceneBuilder.instance(ARMOR[kind][1]) as Node3D
		unit.position = hit.position + Vector3.UP * 0.05
		unit.rotation.y = PI + deg_to_rad(float((i % 3) - 1) * 8.0)
		unit.set("animation_phase", fmod(float(i) * 0.23, 1.8))
		unit.set("shadows_enabled", false)
		SceneBuilder.add(armor_group, unit, "%s%02d" % [kind, i])
	terrain.queue_free()
	SceneBuilder.add(scene, Node3D.new(), "StressUnits")

	var canvas := CanvasLayer.new()
	canvas.layer = 4
	SceneBuilder.add(scene, canvas, "BossPreviewControls")
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -405.0
	panel.offset_top = 12.0
	panel.offset_right = -16.0
	panel.offset_bottom = 105.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	SceneBuilder.add(canvas, panel, "Panel")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	SceneBuilder.add(panel, column, "Column")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	SceneBuilder.add(column, row, "Buttons")
	var label := Label.new()
	label.text = "BOSS "
	label.add_theme_font_size_override("font_size", 15)
	SceneBuilder.add(row, label, "Title")
	for item: Array in [["BossIdle", "1 IDLE"], ["BossFly", "2 FLY"], ["BossFire", "3 FIRE"]]:
		var button := Button.new()
		button.text = item[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		SceneBuilder.add(row, SceneBuilder.unique(button), item[0])

	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 5)
	SceneBuilder.add(column, load_row, "LoadButtons")
	var count_label := Label.new()
	count_label.text = "LOAD 10"
	count_label.add_theme_font_size_override("font_size", 15)
	SceneBuilder.add(load_row, SceneBuilder.unique(count_label), "LoadCount")
	for item: Array in [["Load10", "4:10"], ["Load40", "5:40"], ["Load80", "6:80"]]:
		var button := Button.new()
		button.text = item[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		SceneBuilder.add(load_row, SceneBuilder.unique(button), item[0])
	var shadows := CheckButton.new()
	shadows.text = "7 SHADOW"
	shadows.button_pressed = false
	shadows.focus_mode = Control.FOCUS_NONE
	SceneBuilder.add(load_row, SceneBuilder.unique(shadows), "ArmorShadows")

	result = SceneBuilder.save_scene(scene, VARIANT, {"overwrite": true, "expected_refs": [BASE, BOSS, ARMOR["Melee"][1], ARMOR["Tank"][1], ARMOR["Phido"][1]]})
	if not result.ok:
		quit(1)
		return
	print("BOSS_SCENES_CREATED")
	quit(0)
