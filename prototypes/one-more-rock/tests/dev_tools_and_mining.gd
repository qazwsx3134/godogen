extends SceneTree

const Quarry = preload("res://quarry.gd")
const RockVolume = preload("res://rock_volume.gd")
const DevPanel = preload("res://addons/godot_dev_panel/dev_panel.gd")

var failures := 0
var contact_error := INF
var impact_count := 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func press_f1() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F1
	event.pressed = true
	root.push_input(event)


func run() -> void:
	var quarry := (load("res://scenes/quarry.tscn") as PackedScene).instantiate() as Quarry
	root.add_child(quarry)
	quarry.excavation.rng.seed = 717
	await physics_frame
	var panel := quarry.get_node_or_null("DevPanel") as DevPanel
	expect(DevPanel.available() and panel != null, "編輯器的遊戲場景有開發面板")
	if panel:
		quarry.mouse_swing = true
		press_f1()
		expect(paused and panel.is_open() and not quarry.mouse_swing, "F1 暫停並清除按住採礦")
		var terrain: VBoxContainer
		for section in panel.sections.get_children():
			var title: Button = section.get_node("%SectionTitle")
			if title.text.ends_with("Terrain"):
				terrain = section.get_node("%Fields")
				expect(not terrain.visible, "Terrain 初始收合")
				title.button_pressed = true
				expect(terrain.visible, "分類可展開")
				break
		expect(terrain != null, "採礦控制項已註冊")
		if terrain:
			var interval: SpinBox = terrain.get_child(0).get_node("%Number")
			expect(is_equal_approx(interval.value, 0.56), "欄位取得連挖預設值")
			interval.value = 0.5
			expect(is_equal_approx(quarry.mine_interval, 0.5), "修改欄位會套用到遊戲")
		press_f1()
		expect(not paused and not panel.is_open(), "第二次 F1 恢復遊戲")

	var player := quarry.player
	var waypoint := quarry.mining_waypoint.position
	var probe := Vector3(waypoint.x - 4.0, 0.82, waypoint.z)
	var ray := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.RIGHT * 16.0, 4)
	var face := quarry.get_world_3d().direct_space_state.intersect_ray(ray)
	var rock := face.get("collider") as RockVolume
	expect(rock != null, "從礦場入口找到可採岩壁")
	if rock == null:
		quit(1)
		return
	var target: Vector3 = face.position
	player.global_position = Vector3(target.x - 1.50, 0, target.z)
	player.velocity = Vector3.ZERO
	rock.chipped.connect(func(point: Vector3, _normal: Vector3, _count: int):
		impact_count += 1
		contact_error = player.pickaxe_tip.global_position.distance_to(point)
	)
	await physics_frame
	await physics_frame
	player.eyes.look_at(target)
	expect(quarry._pickaxe_aim().get("collider") == rock, "起始瞄得到入口岩壁")
	quarry._swing()
	await create_timer(0.11).timeout
	player.eyes.look_at(player.eyes.global_position + Vector3(-1, 2, 0))
	await create_timer(0.42).timeout
	expect(impact_count == 0 and not quarry.get_node("%RockBreakSound").playing
		and not quarry.get_node("%OreFoundSound").playing, "揮空不播放碎裂或出礦聲")
	var swing_side := player.swing_side
	quarry._swing()
	await create_timer(0.11).timeout
	player.eyes.look_at(target)
	await create_timer(0.175).timeout
	expect(impact_count == 1, "揮擊途中掃進可挖岩石，會在落鎬時命中")
	expect(contact_error < 0.015, "發生切削當下鎬尖與碰撞點吻合")
	expect(player.swing_side == -swing_side, "兩次揮鎬交替換邊")
	var mine_sound: AudioStreamPlayer = quarry.get_node("%MineSound")
	expect(mine_sound.playing and quarry.get_node("%RockBreakSound").playing, "實際挖岩播放命中與碎裂聲")
	await create_timer(0.12).timeout
	expect(quarry.get_node("%OreFoundSound").playing, "成功挖出原石後播放出礦聲")
	expect(not quarry.get_node("%MineralImpactSound").playing and not quarry.get_node("%CrystalOreSound").playing,
		"敲普通岩壁時保留露頭礦片的專屬聲音")
	if mine_sound.playing:
		await mine_sound.finished
	for path in ["%CollapseSound", "%PickupSound", "%RockBreakSound"]:
		quarry.get_node(path).stop()
	await create_timer(0.20).timeout
	quarry.queue_free()
	await process_frame
	print("dev_tools_and_mining ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
