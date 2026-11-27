extends SceneTree

const Quarry = preload("res://quarry.gd")
const RockVolume = preload("res://rock_volume.gd")
const Debris = preload("res://excavation_debris.gd")
var quarry: Quarry
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)


func frames() -> void:
	await physics_frame
	await physics_frame


func until(ready: Callable, timeout := 4.8) -> bool:
	for step in ceili(timeout / 0.05):
		if ready.call():
			return true
		await create_timer(0.05).timeout
	return ready.call()


func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	root.push_input(event, true)


func left_click() -> void:
	click_at(root.get_visible_rect().get_center())


func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func touch(index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	root.push_input(event, true)


func action_touch(down: bool) -> void:
	touch(3, quarry.action_button.get_global_rect().get_center(), down)


func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	root.push_input(event, true)


func aim(position: Vector3, target: Vector3) -> void:
	quarry.player.position = position
	quarry.player.look_at(Vector3(target.x, position.y, target.z))
	quarry.player.eyes.look_at(target)
	await frames()


func walk_into_shack() -> void:
	var doorway := quarry.workshop_exit.global_position
	await aim(doorway, quarry.workshop_entry.global_position)
	Input.action_press("move_forward")
	await create_timer(0.45).timeout
	Input.action_release("move_forward")


func open_bench_stone() -> void:
	var point := quarry.bench.camera.unproject_position(quarry.bench.stone.global_position)
	var strikes := ceili(float(quarry.bench.durability - quarry.bench.hits) / quarry.bench.hit_power)
	for i in strikes:
		touch(1, point, true)
		touch(1, point, false)
		await create_timer(0.42).timeout


func collect_product() -> void:
	var point := root.get_visible_rect().get_center()
	touch(1, point, true)
	touch(1, point, false)
	await create_timer(0.55).timeout


func run() -> void:
	quarry = load("res://scenes/quarry.tscn").instantiate()
	root.add_child(quarry)
	quarry.excavation.rng.seed = 717
	quarry.bench.lucky_chance = 0.0
	await frames()
	expect(quarry.player.eyes.current and quarry.bench.source_id == -1, "從第一人稱野外開始，工作台沒有樣品")
	for asset in ["MinersShack", "MineHeadframe", "TrailLantern", "FreightCrates"]:
		var model := quarry.get_node("PolyforkProps/" + asset)
		expect(model.scene_file_path.ends_with(".glb"), "採石場使用原始 GLB 場景實例")
		var visual := model.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D
		var material := visual.mesh.surface_get_material(0) as StandardMaterial3D
		expect(material.vertex_color_use_as_albedo, "%s 匯入後會顯示模型的頂點色" % asset)
	expect(quarry.cart.get_node("CartBody/OreBarrow").scene_file_path.ends_with("ore_barrow.glb")
		and quarry.cart_socket.get_parent() == quarry.cart_body, "GLB 推車與石頭落點隨車斗旋轉")
	expect(quarry.route.text.begins_with("↑　岩山採石場"), "出門指引朝向岩山並標示距離")
	var start := quarry.player.position
	Input.action_press("move_forward")
	await create_timer(0.42).timeout
	Input.action_release("move_forward")
	expect(quarry.player.position.distance_to(start) > 0.85, "WASD 移動")
	expect(quarry.player.footstep_sound.playing, "實際走過砂礫時會播放腳步")

	expect(quarry.get_node_or_null("WallVeins") == null and get_nodes_in_group("quarry_rock").size() == 36 and quarry.get_node_or_null("TrailStone") == null, "岩山本體可採，入口步道沒有預置岩石")
	var walking_pace: float = quarry.player.velocity.length()
	Input.action_press("move_forward")
	Input.action_press("run")
	await create_timer(0.19).timeout
	expect(quarry.player.velocity.length() > maxf(walking_pace + 2.0, 6.8), "Shift 加速跑步")
	key(KEY_SPACE, true)
	key(KEY_SPACE, false)
	await create_timer(0.20).timeout
	expect(not quarry.player.is_on_floor() and quarry.player.position.y > 0.45, "空白鍵讓玩家跳起")
	expect(quarry.player.step_distance == 0.0, "空中移動不累計腳步距離")
	Input.action_release("move_forward")
	Input.action_release("run")
	await create_timer(0.62).timeout

	await aim(Vector3(2, 0, 3.55), Vector3(3.4, 4.2, 3.55))
	left_click()
	expect(quarry.player.swinging, "桌機左鍵可朝空中揮鎬")
	await create_timer(0.12).timeout
	expect(quarry.player.swing_sound.playing, "揮空也會播放十字鎬風切聲")
	await create_timer(0.41).timeout
	expect(quarry.excavation.loose.is_empty(), "空揮不生礦石")
	var waypoint := quarry.mining_waypoint.position
	var probe := Vector3(waypoint.x - 4.0, 0.82, waypoint.z)
	var ray := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.RIGHT * 16.0, 4)
	var face := quarry.get_world_3d().direct_space_state.intersect_ray(ray)
	var path_rock := face.get("collider") as RockVolume
	expect(path_rock != null and quarry.player.position.distance_to(face.position) < 20.0, "新入口前方可以在短距離找到可採岩壁")
	if path_rock == null:
		quit(1)
		return
	var path_spot: Vector3 = face.position
	await aim(Vector3(path_spot.x - 1.55, 0, path_spot.z), path_spot)
	var count_before := path_rock.solid.size()
	expect(quarry._aimed_target() == path_rock, "入口岩壁會被採掘射線命中")
	left_click()
	await create_timer(0.27).timeout
	expect(path_rock.solid.size() < count_before and not quarry.excavation.loose.is_empty(), "左鍵挖岩壁，岩體實際減少且飛出碎岩")
	var ore_mesh := (quarry.excavation.loose[0].get_node("ShapeMesh") as MeshInstance3D).mesh
	var flying_ore: Node3D
	for index in 110:
		for item in quarry.get_children():
			if item.scene_file_path == "res://scenes/pickup_ore.tscn":
				flying_ore = item
				break
		if is_instance_valid(flying_ore):
			break
		await physics_frame
	expect(is_instance_valid(flying_ore), "碎岩落地後才執行拾取上浮")
	if is_instance_valid(flying_ore):
		expect(flying_ore.get_node("Ore").mesh == ore_mesh, "地上碎岩和飛行中的原石共用模型")
		var start_height := flying_ore.global_position.y
		await create_timer(0.15).timeout
		expect(flying_ore.global_position.y > start_height + 0.5 and quarry.inventory.pack.is_empty(), "先向上飄，落下前還沒計入背包")
	await create_timer(0.84).timeout
	expect(not quarry.inventory.pack.is_empty(), "碎岩落地，經拾取弧線裝入背包")
	expect(quarry.route.text.contains("工坊卸貨"), "有原石時箭頭引導回工坊")

	var fixture := Vector3(13, 0.32, 3.5)
	await aim(fixture + Vector3(-2.6, -0.32, 0), fixture)
	quarry.excavation.spawn_ore(fixture, Vector3.UP, 1)
	var rare := quarry.excavation.loose.back() as Debris
	rare.rare = true
	rare.collision_layer |= 2
	expect(rare.get_node("ShapeMesh").mesh == ore_mesh, "稀有碎岩沿用普通原石的外殼")
	await create_timer(0.91).timeout
	var drop := rare.global_position
	await aim(Vector3(drop.x - 1.1, 0, drop.z), drop)
	var center := root.get_visible_rect().get_center()
	var look_start := center + Vector2(120, -60)
	touch(6, look_start, true)
	touch(6, look_start, false)
	await frames()
	expect(rare.usable() and quarry.inventory.rare_ids.is_empty(), "稀有碎岩保留手動拾取")
	action_touch(true)
	action_touch(false)
	expect(quarry.inventory.reserved_pack == 1 and quarry.inventory.rare_ids.is_empty(), "稀有碎岩也先沿弧線拾取")
	await create_timer(0.68).timeout
	expect(quarry.inventory.rare_ids.size() == 1, "手動拾取後保留稀有標記")
	var rare_id := quarry.inventory.pack.back() as int
	var run_point := quarry.run_button.get_global_rect().get_center()
	touch(1, run_point, true)
	touch(1, run_point, false)
	expect(quarry.player.touch_running, "手機跑步鍵切換速度")
	var jump_point := quarry.jump_button.get_global_rect().get_center()
	touch(2, jump_point, true)
	touch(2, jump_point, false)
	await create_timer(0.16).timeout
	expect(not quarry.player.is_on_floor() and quarry.player.position.y > 0.4, "手機跳躍鍵")
	await create_timer(0.58).timeout
	var stick := Vector2(center.x * 0.55, center.y * 1.55)
	var turn := center + Vector2(150, -40)
	var yaw := quarry.player.rotation.y
	touch(4, stick, true)
	touch(7, turn, true)
	drag(4, stick + Vector2(0, -65), Vector2(0, -65))
	drag(7, turn + Vector2(32, 0), Vector2(32, 0))
	expect(quarry.player.touch_move.length() > 0.9 and not is_equal_approx(yaw, quarry.player.rotation.y), "兩指可同時移動、轉向")
	touch(7, turn, false)
	expect(quarry.player.touch_move.length() > 0.9, "右指放開，左指仍移動")
	quarry.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(quarry.player.touch_move == Vector2.ZERO, "失焦清除長按與搖桿")

	await aim(quarry.cart.position + Vector3(0, 0, 1.7), quarry.cart.position + Vector3.UP * 0.6)
	expect(quarry.action_button.text == "接上推車", "準星對著推車顯示接車")
	action_touch(true)
	action_touch(false)
	expect(quarry.pushing, "用同一情境鍵接上推車")

	# Park away from a target, then pick it up with the desktop equivalent.
	await aim(Vector3(7.0, 0, 7.0), Vector3(8.0, 2.8, 7.0))
	expect(quarry.action_button.text == "停放推車", "推車時沒有近距互動目標就顯示停車")
	action_touch(true)
	action_touch(false)
	expect(not quarry.pushing, "用同一情境鍵停放推車")
	await aim(quarry.cart.position + Vector3(0, 0, 1.7), quarry.cart.position + Vector3.UP * 0.6)
	key(KEY_E, true)
	key(KEY_E, false)
	expect(quarry.pushing, "桌機 E 也使用同一互動")

	# Spawn an actual load of five rigid fragments for the partial unload fixture.
	var cart_collect := Vector3(17, 0.25, 4)
	await aim(cart_collect + Vector3(-1.3, -0.25, 0), cart_collect)
	quarry.excavation.spawn_ore(cart_collect, Vector3.UP, 5)
	for piece in quarry.excavation.loose:
		piece.rare = false
	for index in 110:
		if quarry.inventory.reserved_cart > 0:
			break
		await physics_frame
	expect(quarry.inventory.reserved_cart > 0 and quarry.inventory.cart.is_empty(), "推車原石飛行中會先保留位置")
	await create_timer(1.05).timeout
	expect(quarry.inventory.cart.size() == 5, "五顆物理碎岩落地後裝進推車")
	# Populate an almost-full hopper for the partial unload case.
	for i in 28:
		quarry.inventory.storage.append(100 + i)
	# Free the backpack first so this case isolates cart overflow.
	quarry.inventory.pack.clear()
	quarry._update_inventory()
	var unload := quarry.unload_box.position
	await aim(unload + Vector3(0, 0, 1.7), unload + Vector3.UP * 0.48)
	await create_timer(0.12).timeout
	expect(quarry.inventory.storage.size() == 30 and quarry.inventory.cart.size() == 3, "走進卸貨區自動卸貨並保留剩三顆")
	expect(quarry.load_groups.get_child(0).visible and not quarry.load_groups.get_child(1).visible, "車上餘量反映在模型上")
	expect(quarry.stock_pile.near.size() == 30 and quarry.stock_pile.near.back().freeze, "卸貨時仍看得到飛行中的石頭")
	expect(quarry.get_node("%UnloadSound").playing and quarry.get_node("%Prompt").text.contains("2"), "卸貨有聲音與入庫數量提示")
	await create_timer(0.5).timeout
	expect(quarry.inventory.storage.size() == 30 and quarry.inventory.cart.size() == 3, "留在滿倉卸貨區不再扣車上石頭")
	expect(quarry.stock_pile.near.size() == 30 and not quarry.stock_pile.near.back().freeze and quarry.stock_pile.near.back().collision_layer == 16, "入庫後以真正的剛體碰撞堆積")

	var stand := quarry.workshop_exit.global_position
	await aim(stand, quarry.workshop_entry.global_position)
	expect(not quarry.at_bench, "小屋門外保留第一人稱採石畫面")
	await walk_into_shack()
	expect(quarry.at_bench and quarry.bench.source_id == 100 and quarry.inventory.storage.size() == 29, "進台領倉庫第一顆")
	expect(quarry.stock_pile.near.size() == 29, "領取一顆後箱內少一顆")
	await open_bench_stone()
	expect(quarry.bench.opened == 1 and quarry.bench.coins == 0 and quarry.shelf.collected == 0, "完成第一人稱採運→開石流程，留下礦物等收取")
	expect(quarry.bench.revealing and not quarry.bench.stone.visible, "首顆留在揭露畫面")
	await create_timer(0.19).timeout
	expect(quarry.bench.revealing and quarry.bench.source_id == -1, "首顆展示後才領取下一顆")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	expect(not quarry.at_bench and quarry.player.eyes.current and quarry.player.position.distance_to(stand) < 0.06, "離台回到小屋門外")
	await create_timer(1.8).timeout
	expect(quarry.inventory.storage.size() == 29 and quarry.bench.revealing, "離台後不預領下一顆，也保留待收礦物")
	quarry.inventory.storage.clear()
	await walk_into_shack()
	expect(quarry.at_bench and quarry.bench.revealing, "回台可收走原本發現的礦物")
	await collect_product()
	expect(quarry.bench.coins == 17 and not quarry.bench.stone.visible, "收走後入帳，缺料時顯示空工位")
	expect(quarry.shelf.collected == 1 and quarry.shelf.displays.get_node("Bay0/Sample").visible, "首次石英收料後出現在圖鑑架")
	expect(quarry.shelf.tally.text.ends_with("1／4"), "圖鑑架顯示已收錄數量")

	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	quarry.inventory.storage.append(rare_id)
	await walk_into_shack()
	expect(quarry.at_bench and not quarry.bench.stone.visible and quarry.bench.waiting_hardness == 3
		and quarry.inventory.storage.has(rare_id), "初始槌無法加工稀有原石，保留庫存")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	# Opening the station does not make a purchase. Choose a route and reject duplicate purchases.
	await aim(quarry.upgrade.position + Vector3(0, -0.52, 1.6), quarry.upgrade.position)
	key(KEY_E, true)
	key(KEY_E, false)
	expect(quarry.workshop.visible and not quarry.player.walking and quarry.bench.coins == 17, "互動開啟選單並暫停角色輸入")
	quarry.workshop.purchase_requested.emit(&"bag")
	expect(quarry.inventory.pack_capacity == 5 and quarry.bench.coins == 17, "金幣不足時維持原容量")
	quarry.bench.credit_coins(175)
	quarry.workshop.purchase_requested.emit(&"diamond_hammer")
	expect(quarry.bench.hit_power == 1 and quarry.bench.coins == 192, "進階槌子需要前置升級")
	await process_frame
	var diamond: Button = quarry.workshop.cards[&"diamond_hammer"].get_node("%Select")
	click_at(diamond.get_global_rect().get_center())
	expect(quarry.workshop.selected == &"diamond_hammer" and quarry.workshop.apply_button.disabled,
		"天賦樹鎖住的節點可選看內容，不能購買")
	var transport: Button = quarry.workshop.route_buttons.get_node("Transport")
	click_at(transport.get_global_rect().get_center())
	await process_frame
	var bag_button: Button = quarry.workshop.cards[&"bag"].get_node("%Select")
	click_at(bag_button.get_global_rect().get_center())
	expect(quarry.workshop.selected == &"bag" and quarry.bench.coins == 192, "點選天賦時只切換查閱內容")
	click_at(quarry.workshop.apply_button.get_global_rect().get_center())
	expect(quarry.inventory.pack_capacity == 10 and quarry.bench.coins == 167, "選擇搬運天賦並確認解鎖")
	quarry.workshop.purchase_requested.emit(&"bag")
	expect(quarry.bench.coins == 167, "同一升級只扣款一次")
	quarry.workshop.purchase_requested.emit(&"steel_hammer")
	expect(quarry.bench.hit_power == 2 and quarry.inventory.storage_capacity == 30, "鍛鋼槌與料斗可分別購買")
	quarry.workshop.purchase_requested.emit(&"diamond_hammer")
	expect(quarry.bench.hit_power == 3 and quarry.bench.coins == 72, "進階槌有獨立購買成本")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)

	quarry.inventory.storage.append_array([900, 901])
	await walk_into_shack()
	expect(quarry.bench.loot_index == 3 and quarry.bench.durability == 9, "鑽尖槌可開稀有硬度 3 原石")
	await open_bench_stone()
	expect(quarry.bench.revealing and quarry.inventory.storage.size() == 2 and quarry.bench.coins == 72, "後續稀有石也留在台上直到點擊")
	var rare_payout := quarry.bench.payout
	var rare_shell := quarry.bench.shell.mesh
	await collect_product()
	expect(quarry.bench.source_id == 900 and quarry.bench.hits == 0 and quarry.bench.stone.visible and quarry.bench.coins == 72 + rare_payout, "收走紫水晶後入帳，進下一顆")
	expect(quarry.bench.shell.mesh != rare_shell, "連續補料使用不同原石輪廓")
	quarry.bench.loot_index = 2
	await open_bench_stone()
	expect(quarry.bench.revealing and quarry.inventory.storage.size() == 1, "後續普通石也等待確認")
	await collect_product()
	expect(quarry.bench.source_id == 901, "收走一般礦物後補下一顆")
	quarry.bench.loot_index = 0
	await open_bench_stone()
	expect(quarry.bench.get_node("%StockClear").visible and quarry.bench.achievements.has("清完整批"), "清完整批出現收尾與成就")
	await collect_product()
	expect(quarry.bench.source_id == -1 and not quarry.bench.stone.visible and quarry.inventory.storage.is_empty(), "末顆收走後顯示缺料")
	expect(quarry.shelf.collected == 4 and quarry.shelf.tally.text.ends_with("4／4"), "收齊四種後展示架填滿")
	var coins_before := quarry.bench.coins
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	await aim(quarry.upgrade.position + Vector3(0, -0.52, 1.6), quarry.upgrade.position)
	key(KEY_E, true)
	key(KEY_E, false)
	quarry.workshop.purchase_requested.emit(&"bin")
	expect(quarry.bench.hit_power == 3 and quarry.inventory.storage_capacity == 60 and quarry.bench.coins == coins_before - 32, "搬運路線可獨立擴充料斗")
	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	quarry.inventory.storage.assign([904, 903])
	await walk_into_shack()
	expect(quarry.bench.durability == 7 and quarry.bench.source_hardness == 2 and quarry.bench.shell.mesh == quarry.bench.raw_shells.back(), "緻密原石有獨立輪廓、硬度與耐久")
	var aim_point := quarry.bench.camera.unproject_position(quarry.bench.stone.global_position)
	var outside := Vector2(32, root.get_visible_rect().size.y * 0.35)
	touch(1, outside, true)
	await create_timer(0.30).timeout
	expect(quarry.bench.hits == 0, "按住空處不敲")
	drag(1, aim_point, aim_point - outside)
	await create_timer(0.05).timeout
	expect(quarry.bench.hits == 3, "掃入可敲區後鑽尖槌每擊傷害為三")
	var opened_before := quarry.bench.opened
	var balance_before := quarry.bench.coins
	expect(await until(func(): return quarry.bench.revealing), "長按敲開當前原石")
	await create_timer(0.26).timeout
	expect(quarry.bench.opened == opened_before + 1 and quarry.bench.revealing and quarry.bench.coins == balance_before,
		"長按仍保留一段礦物揭曉時間")
	expect(await until(func(): return quarry.bench.source_id == 903), "持續按住會收走礦物並上下一顆")
	touch(1, aim_point, false)
	expect(quarry.bench.coins > balance_before and quarry.inventory.storage.is_empty(), "長按收料只入帳一次")
	await create_timer(0.29).timeout
	await open_bench_stone()
	await collect_product()
	expect(quarry.shelf.collected == 4, "再次發現不增加擺位或收藏數")
	var pile := quarry.stock_pile
	pile.set_count(300)
	expect(pile.body_budget == 60 and pile.near.size() == 60 and pile.middle_count == 64 and pile.bulk.visible, "爆量庫存分成近層、中層與石堆")
	expect(pile.near[0].get_node("Shell").mesh == ore_mesh and pile.middle.multimesh.mesh == ore_mesh
		and pile.bulk.get_child(0).mesh == ore_mesh and quarry.load_groups.get_child(0).get_child(0).mesh == ore_mesh,
		"裝車與料斗各層沿用原石外觀")
	var amethyst: Mesh = quarry.bench.get_node("Finds/Amethyst/AmethystCluster").mesh
	expect(quarry.bench.get_node("IconViewport/IconModels/Amethyst/AmethystCluster").mesh == amethyst
		and quarry.shelf.displays.get_node("Bay2/Sample/AmethystCluster").mesh == amethyst,
		"紫水晶揭露、發現縮圖和圖鑑櫃共用晶簇")
	var escaped := pile.near[0]
	escaped.position.y = -1.0
	await frames()
	expect(escaped.position.y >= 0.0 and pile.visible_stock == 300 and quarry.inventory.storage.is_empty(), "飛出容器回收，表現與帳本獨立")
	pile.set_count(0)
	expect(pile.near.is_empty() and pile.middle_count == 0 and not pile.bulk.visible, "清空後三層都清掉")

	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	quarry.bench.coins = 250
	await aim(quarry.upgrade.position + Vector3(0, -0.52, 1.6), quarry.upgrade.position)
	key(KEY_E, true)
	key(KEY_E, false)
	quarry.workshop.purchase_requested.emit(&"steel_pick")
	expect(quarry.player.mining_power == 2 and quarry.bench.coins == 215, "工坊升級鋼製十字鎬")
	quarry.workshop.purchase_requested.emit(&"drill")
	expect(quarry.player.using_drill and quarry.player.mining_power == 1 and quarry._swing_interval() < 0.30,
		"電鑽可換裝，有更快但更窄的採掘方式")
	quarry.workshop.tool_requested.emit(false)
	expect(not quarry.player.using_drill and quarry.player.mining_power == 2, "可切換回鋼製十字鎬")
	quarry.workshop.purchase_requested.emit(&"robot")
	var automation := quarry.automation
	expect(automation.collector.visible and not automation.crusher_enabled, "拾運和破石各有自己的解鎖")
	for piece: Debris in quarry.excavation.loose.duplicate():
		quarry.excavation.retire(piece)
	quarry.inventory.storage.assign([909, 916])
	quarry.inventory.rare_ids[916] = true
	quarry.inventory.storage_capacity = 2
	quarry.excavation.spawn_ore(Vector3(16, 0.30, 0.8), Vector3.UP, 1)
	var ordinary: Debris = quarry.excavation.loose.back()
	ordinary.rare = false
	quarry.excavation.spawn_ore(Vector3(17, 0.30, 0.8), Vector3.UP, 1)
	var ground_rare: Debris = quarry.excavation.loose.back()
	ground_rare.rare = true
	await create_timer(0.85).timeout
	expect(not automation.collector_busy and quarry.excavation.loose.has(ordinary), "滿倉時地上的原石保留")
	quarry.inventory.storage_capacity = 3
	expect(await until(func(): return quarry.inventory.reserved_storage == 1), "拾運機器人抵達原石並保留一格入庫空間")
	quarry.inventory.pack.append(917)
	expect(quarry.inventory.unload(false) == 0, "玩家卸貨不能占用運送中的一格")
	expect(await until(func(): return quarry.inventory.storage.size() == 3), "機器人運回料斗後才更新庫存")
	quarry.inventory.pack.erase(917)
	expect(quarry.excavation.loose.has(ground_rare) and quarry.stock_pile.near.size() == 3, "稀有原石留在地上，料斗增加實際石塊")
	quarry.workshop.automation_toggled.emit(&"robot")
	expect(not automation.collector_enabled, "可單獨暫停拾運")
	quarry.inventory.storage.assign([909, 915, 916])
	quarry.bench.credit_coins(500)
	quarry.workshop.purchase_requested.emit(&"crusher_diamond")
	expect(automation.crusher_level == 0, "高階破石機需要前置")
	var before_robot := quarry.bench.coins - 50
	quarry.workshop.purchase_requested.emit(&"crusher")
	expect(await until(func(): return quarry.bench.coins > before_robot), "硬度 1 原石自動加工並入帳")
	expect(quarry.inventory.storage == [909, 916], "初階保留緻密與稀有原石")
	quarry.workshop.purchase_requested.emit(&"crusher_steel")
	before_robot = quarry.bench.coins
	expect(await until(func(): return quarry.bench.coins > before_robot), "鍛鋼破石機加工硬度 2")
	expect(quarry.inventory.storage == [916], "鍛鋼破石機保留稀有原石")
	quarry.workshop.purchase_requested.emit(&"crusher_diamond")
	before_robot = quarry.bench.coins
	expect(await until(func(): return quarry.bench.coins > before_robot, 5.5), "鑽尖破石機加工硬度 3")
	expect(quarry.bench.coins == before_robot + 60 and quarry.inventory.storage.is_empty() and not quarry.inventory.rare_ids.has(916),
		"稀有加工依紫水晶基價結算一次")
	before_robot = quarry.bench.coins
	quarry.workshop.automation_toggled.emit(&"robot")
	quarry.excavation.spawn_ore(Vector3(15, 0.30, 1.2), Vector3.UP, 1)
	quarry.excavation.loose.back().rare = false
	expect(await until(func(): return quarry.bench.coins > before_robot, 7.0), "兩台機器把散落的原石一路送進料斗、破石、入帳")
	expect(quarry.inventory.storage.is_empty() and quarry.inventory.reserved_storage == 0, "自動流程完成後庫存與保留位正確扣清")
	quarry.workshop.automation_toggled.emit(&"crusher")
	expect(not automation.crusher_enabled and automation.collector_enabled, "可單獨暫停破石")
	quarry.bench.credit_coins(400)
	quarry.workshop.purchase_requested.emit(&"ore_yield_2")
	expect(quarry.bonus_ore == 0, "出礦進階需要前置")
	for id in [&"ore_yield", &"ore_yield_2", &"pickup_reach", &"fast_pickup", &"running_boots", &"spring_boots", &"cart_rack"]:
		quarry.workshop.purchase_requested.emit(id)
	expect(quarry.bonus_ore == 2 and quarry.pickup_radius == 3.0 and quarry.pickup_flight_time == 0.36,
		"出礦及拾取路線的數值確實套用")
	expect(quarry.player.run_speed == 8.6 and quarry.player.jump_speed == 6.45 and quarry.inventory.cart_capacity == 30,
		"體能及車斗升級會影響角色和實際容量")
	var loose_before := quarry.excavation.loose.size()
	quarry._rock_chipped(Vector3(11.0, 0.52, 5.2), Vector3.UP, 1)
	expect(quarry.excavation.loose.size() == loose_before + 3, "出礦升級增加實際掉落的原石")

	key(KEY_ESCAPE, true)
	key(KEY_ESCAPE, false)
	expect(get_nodes_in_group("quarry_rock").size() == 36, "岩山的 36 個岩體都有可挖的碰撞")
	await create_timer(0.50).timeout # Let the final purchase cue finish before shutting down the mixer.
	for sound: AudioStreamPlayer in quarry.find_children("*", "AudioStreamPlayer", true, false):
		sound.stop()
	for sound: AudioStreamPlayer3D in quarry.find_children("*", "AudioStreamPlayer3D", true, false):
		sound.stop()
	await create_timer(0.20).timeout
	quarry.queue_free()
	await process_frame
	await process_frame
	print("quarry_loop ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
