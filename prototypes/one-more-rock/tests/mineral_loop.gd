extends SceneTree

const Quarry = preload("res://quarry.gd")
const RockVolume = preload("res://rock_volume.gd")
const EmbeddedMineral = preload("res://embedded_mineral.gd")
const Debris = preload("res://excavation_debris.gd")

var quarry: Quarry
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)


func wait_physics() -> void:
	await physics_frame
	await physics_frame


func strike_wall(z := 3.27) -> void:
	var from := Vector3(15.1, 1.35, z)
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.RIGHT * 20.0, 4)
	var hit := quarry.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.get("collider") is RockVolume:
		expect(false, "採礦路線能找到岩壁")
		return
	quarry.player.global_position = hit.position + Vector3(-1.35, -hit.position.y, 0.0)
	quarry.player.eyes.look_at(hit.position)
	await wait_physics()
	expect(quarry._pickaxe_aim().get("collider") is RockVolume, "從第一人稱準星瞄準岩面")
	quarry._swing()
	await quarry.player.swing.finished


func run() -> void:
	quarry = load("res://scenes/quarry.tscn").instantiate()
	root.add_child(quarry)
	quarry.excavation.rng.seed = 717
	await wait_physics()
	await strike_wall()
	await strike_wall()
	expect(quarry.exposed_minerals.is_empty(), "普通外岩尚未露出礦片")
	await strike_wall()
	expect(quarry.exposed_minerals.size() == 1, "開口裡露出一處可採礦片")
	if not quarry.exposed_minerals.is_empty():
		var mineral: EmbeddedMineral = quarry.exposed_minerals.values().front()
		var rock := mineral.get_parent() as RockVolume
		expect(rock.solid.has(mineral.anchor_cell) and mineral.calcite.visible, "礦片貼在挖口內的實體岩材上")
		quarry.player.eyes.look_at(mineral.global_position + mineral.global_basis.z * 0.11)
		expect(quarry._pickaxe_aim().get("collider") == mineral, "從同一採掘位置可以瞄準已露出的礦片")
		quarry.get_node("%MineSound").stop()
		quarry.get_node("%RockBreakSound").stop()
		quarry._swing()
		await create_timer(0.30).timeout
		expect(is_instance_valid(mineral) and mineral.hits_left == 1, "第一擊只敲鬆露出的礦片")
		expect(quarry.get_node("%MineralImpactSound").playing and quarry.get_node("%CrystalOreSound").playing
			and not quarry.get_node("%MineSound").playing and not quarry.get_node("%RockBreakSound").playing,
			"直接命中礦片播放撞擊與水晶聲")
		await quarry.player.swing.finished
		quarry._swing()
		await create_timer(0.29).timeout
		expect(quarry.exposed_minerals.is_empty() and not is_instance_valid(mineral), "第二擊採下礦片並清除其碰撞")
		var finds := quarry.excavation.loose.filter(func(piece: Debris): return piece.mineral == 2)
		expect(finds.size() == 1 and finds.front().rare, "只掉一顆可手動拾取的方解石原石")
		if not finds.is_empty():
			var piece: Debris = finds.front()
			expect(piece.has_node("Crystals/Calcite") and not piece.get_node("ShapeMesh").visible,
				"採下的剛體顯示實際方解石晶簇")
			piece.grounded = true
			piece.age = 0.25
			piece.linear_velocity = Vector3.ZERO
			# Move clear of ordinary drops so this unload exercises just the crystal.
			quarry.player.global_position = Vector3(12.0, 0.0, 3.0)
			await create_timer(quarry.pickup_flight_time + 0.1).timeout
			quarry.inventory.pack.clear()
			expect(quarry._collect_piece(piece, 0), "原石可以經一般拾取路徑收走")
			await create_timer(quarry.pickup_flight_time + 0.1).timeout
			expect(quarry.inventory.unload(false) == 1, "採出的原石經卸貨進料斗")
			quarry.bench.hit_power = 1
			expect(quarry._take_stored() == -1 and quarry.bench.waiting_hardness == 2, "方解石需要二階工坊槌")
			quarry.bench.hit_power = 2
			quarry.bench.at_station = true
			quarry.bench._next_stone()
			expect(quarry.bench.loot_index == 2 and quarry.bench.source_hardness == 2,
				"工作台首件保留採出的方解石")
	quarry.cuts_to_mineral = 1
	await strike_wall(7.20)
	expect(quarry.exposed_minerals.size() == 1, "下一處開口能露出紫水晶")
	if not quarry.exposed_minerals.is_empty():
		var crystal: EmbeddedMineral = quarry.exposed_minerals.values().front()
		expect(crystal.amethyst.visible and crystal.mineral == 3, "紫水晶使用各自的模型和對應礦石標記")
	for name in ["MineSound", "RockBreakSound", "OreFoundSound", "CollapseSound", "PickupSound", "CrystalOreSound", "MineralImpactSound"]:
		quarry.get_node(name).stop()
	await create_timer(0.20).timeout
	quarry.queue_free()
	await process_frame
	print("mineral_loop ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
