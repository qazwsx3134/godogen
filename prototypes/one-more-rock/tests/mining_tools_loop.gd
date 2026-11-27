extends SceneTree

const Quarry := preload("res://quarry.gd")
const Rock := preload("res://rock_volume.gd")
var quarry: Quarry
var failures := 0
var cuts := 0
var heavy_drops: Array[int] = []


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func mouse(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	event.position = root.get_visible_rect().get_center()
	root.push_input(event, true)


func aim_at_wall(z: float, distance: float) -> Rock:
	var start := Vector3(15.0, 1.53, z)
	var ray := PhysicsRayQueryParameters3D.create(start, start + Vector3.RIGHT * 26, 4)
	var hit := quarry.get_world_3d().direct_space_state.intersect_ray(ray)
	var rock := hit.get("collider") as Rock
	if rock == null:
		return null
	var at: Vector3 = hit.position
	quarry.player.global_position = Vector3(at.x - distance, 0, z)
	quarry.player.look_at(Vector3(at.x, 0, z))
	quarry.player.eyes.look_at(at)
	await physics_frame
	await physics_frame
	return rock


func run() -> void:
	quarry = load("res://scenes/quarry.tscn").instantiate()
	root.add_child(quarry)
	await physics_frame
	await physics_frame

	var rock := await aim_at_wall(3.2, 1.35)
	if rock == null:
		push_error("未找到礦震測試岩面")
		quit(1)
		return
	rock.chipped.connect(func(_p: Vector3, _n: Vector3, count: int): heavy_drops.append(count))
	var before := rock.solid.size()
	mouse(MOUSE_BUTTON_RIGHT, true)
	mouse(MOUSE_BUTTON_RIGHT, false)
	await create_timer(0.17).timeout
	expect(quarry.player.swinging and rock.solid.size() == before, "礦震先蓄力再撞擊岩面")
	await create_timer(0.34).timeout
	var after := rock.solid.size()
	expect(before - after >= 9 and quarry.power_remaining > 7.4, "右鍵礦震挖掉較大範圍並進入冷卻")
	expect(heavy_drops == [2], "起始礦震只掉兩顆原石")
	mouse(MOUSE_BUTTON_RIGHT, true)
	mouse(MOUSE_BUTTON_RIGHT, false)
	await create_timer(0.25).timeout
	expect(after == rock.solid.size(), "冷卻期間右鍵不會再開採")

	var drill_rock := await aim_at_wall(7.20, 0.83)
	if drill_rock == null:
		push_error("未找到電鑽測試岩面")
		quit(1)
		return
	drill_rock.chipped.connect(func(_p: Vector3, _n: Vector3, _c: int): cuts += 1)
	quarry.player.equip_mining_tool(true)
	var chuck_angle := quarry.player.drill_bit.rotation.z
	mouse(MOUSE_BUTTON_LEFT, true)
	Input.action_press("move_forward")
	await create_timer(0.78).timeout
	Input.action_release("move_forward")
	expect(quarry.player.drilling and not quarry.player.swinging and quarry.player.drill_sound.playing,
		"電鑽長按時保持鑽掘姿勢與馬達聲")
	expect(cuts >= 2 and not is_equal_approx(chuck_angle, quarry.player.drill_bit.rotation.z), "長按持續切出原石且鑽頭旋轉")
	mouse(MOUSE_BUTTON_LEFT, false)
	var before_release := cuts
	await create_timer(0.32).timeout
	expect(not quarry.player.drilling and not quarry.player.drill_sound.playing and cuts == before_release,
		"鬆開後鑽頭、馬達聲與出礦都停止")
	for name in ["MineSound", "RockBreakSound", "OreFoundSound", "CollapseSound", "PickupSound", "CrystalOreSound", "MineralImpactSound"]:
		quarry.get_node(name).stop()
	await create_timer(0.20).timeout
	quarry.queue_free()
	await process_frame
	await process_frame
	print("mining_tools_loop ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
