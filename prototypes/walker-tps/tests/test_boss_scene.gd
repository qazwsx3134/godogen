extends "res://addons/proto_kit/test_kit.gd"

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := (load("res://scenes/boss.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	await _frames(2)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_expect(anim != null, "Boss scene contains the imported AnimationPlayer")
	if anim == null:
		model.queue_free()
		_finish("BOSS_SCENE")
		return
	_expect(anim.current_animation == &"idle" and anim.is_playing(), "Boss starts idle")
	model.set_flying(true)
	_expect(anim.current_animation == &"fly", "flight can be selected")
	_expect(model.fire(), "first shot starts")
	_expect(anim.current_animation == &"fire", "fire animation starts")
	_expect(not model.fire(), "a second shot cannot restart a shot already playing")
	model.set_flying(false)
	_expect(anim.current_animation == &"fire", "locomotion change waits until shot finishes")
	await _frames(85)
	_expect(anim.current_animation == &"idle" and anim.is_playing(), "shot returns to queued idle")
	model.set_flying(true)
	model.fire()
	await _frames(85)
	_expect(anim.current_animation == &"fly" and anim.is_playing(), "shot returns to flying")
	model.queue_free()
	await _frames(4)

	change_scene_to_file("res://scenes/boss_battlefield.tscn")
	await _frames(5)
	var scene := current_scene
	_expect(scene != null and scene.has_node("Boss"), "Boss is saved in the playable scene")
	if scene == null or not scene.has_node("Battlefield"):
		_finish("BOSS_SCENE")
		return
	var session: Node = scene.get_node("Battlefield")
	var battlefield_boss: Node = scene.get_node("Boss")
	var player := battlefield_boss.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_expect(session.get_node("Enemies").get_child_count() == 3 and session.total == 3,
		"the existing scout objective still counts three scouts")
	_expect(battlefield_boss.get_children().size() == 1, "Boss does not add a gameplay collider")
	var armor: Node = scene.get_node("Armor")
	_expect(armor.get_child_count() == 10, "four melee, four tanks and two Phido are saved in the map")
	var animated_units := 0
	var static_units := 0
	for unit: Node in armor.get_children():
		_expect(not unit.shadows_enabled, unit.name + " starts with the measured shadow-saving setting")
		var unit_anim := unit.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var meshes := unit.find_children("*", "MeshInstance3D", true, false)
		_expect(meshes.size() == 1, unit.name + " uses one mesh")
		if unit_anim != null:
			animated_units += 1
			_expect(unit_anim.current_animation == &"idle" and unit_anim.is_playing(), unit.name + " plays idle")
		else:
			static_units += 1
		if not meshes.is_empty():
			unit.set_shadows_enabled(false)
			_expect((meshes[0] as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				unit.name + " can disable its shadow")
			unit.set_shadows_enabled(true)
			unit.set_shadows_enabled(false)
	_expect(animated_units == 8 and static_units == 2, "eight animated units and two static Phido")
	var stress: Node3D = scene.get_node("StressUnits")
	scene.set_armors_shadows(false)
	scene.set_armor_count(40)
	_expect(stress.get_child_count() == 30, "40 mode has 30 extra units")
	if stress.get_child_count() > 0:
		_expect(not stress.get_child(0).shadows_enabled, "new stress units respect disabled shadows")
	scene.set_armor_count(80)
	_expect(stress.get_child_count() == 70, "80 mode has 70 extra units")
	scene.set_armors_shadows(true)
	if stress.get_child_count() > 0:
		_expect(stress.get_child(0).shadows_enabled, "shadow toggle reaches stress units")
	scene.set_armor_count(10)
	_expect(stress.get_child_count() == 0, "returning to 10 removes extras")
	var label: Label = scene.get_node("BossPreviewControls/Panel/Column/LoadButtons/LoadCount")
	_expect(label.text == "LOAD 10", "load control displays the selected count")
	var fly_button: Button = scene.get_node("BossPreviewControls/Panel/Column/Buttons/BossFly")
	var fire_button: Button = scene.get_node("BossPreviewControls/Panel/Column/Buttons/BossFire")
	fly_button.pressed.emit()
	_expect(player.current_animation == &"fly", "scene button selects fly")
	fire_button.pressed.emit()
	_expect(player.current_animation == &"fire", "scene button starts fire")
	await _frames(85)
	_expect(player.current_animation == &"fly", "scene fire returns to fly")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_1
	root.push_input(key, true)
	await _frames(2)
	_expect(player.current_animation == &"idle", "1 key selects idle")
	session.start_match()
	_expect(session.match_state == "playing", "the existing match starts")
	for i: int in 3:
		session._enemy_destroyed(null)
	_expect(session.match_state == "victory", "the existing match victory still works")
	session.retry()
	await _frames(8)
	_expect(current_scene != null and current_scene.has_node("Boss"), "retry retains the Boss scene")
	if current_scene != null:
		var new_session: Node = current_scene.get_node("Battlefield")
		_expect(new_session.match_state == "briefing" and new_session.kills == 0, "retry restores the match")
		for sound: Node in current_scene.find_children("*", "AudioStreamPlayer3D", true, false):
			sound.stop()
		new_session.get_node("Radio").stop()
		current_scene.queue_free()
		current_scene = null
	await _frames(8)
	OS.delay_msec(50)
	await _frames(4)
	_finish("BOSS_SCENE")
