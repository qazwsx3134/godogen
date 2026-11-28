extends SceneTree

const Quarry = preload("res://quarry.gd")
const RockVolume = preload("res://rock_volume.gd")
const RockSkin = preload("res://rock_skin.gd")
const Debris = preload("res://excavation_debris.gd")
var q: Quarry
var failures := 0
var rubble_batches := 0
var drops_per_hit: Array[int] = []


func _initialize() -> void:
	run.call_deferred()


func expect(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)


func wait_physics() -> void:
	await physics_frame
	await physics_frame


func hit_wall(offset := Vector3.ZERO) -> Dictionary:
	var walk_up := q.mining_waypoint.position
	var from := Vector3(walk_up.x - 4.0, 0.52, walk_up.z) + offset
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.RIGHT * 30.0, 4)
	return q.get_world_3d().direct_space_state.intersect_ray(ray)


func check_single_strike_opening() -> void:
	var from := Vector3(15.1, 1.35, 3.27)
	var space := q.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.RIGHT * 16.0, 4)
	var hit := space.intersect_ray(ray)
	var rock := hit.get("collider") as RockVolume
	expect(rock != null, "高處落鎬測試能打到岩山")
	if rock == null:
		return
	var original: Dictionary[Vector2i, Vector3] = {}
	for y in range(-4, 5):
		for z in range(-4, 5):
			var offset := Vector2i(y, z)
			if offset.length_squared() > 16:
				continue
			ray.from = from + Vector3(0.0, y * 0.09, z * 0.09)
			ray.to = ray.from + Vector3.RIGHT * 16.0
			var sample := space.intersect_ray(ray)
			if sample.get("collider") == rock:
				original[offset] = sample.position
	expect(original.size() > 35, "取樣覆蓋鎬尖周圍的岩面")
	expect(rock.chip(hit.position, hit.normal, 1), "以單次普通揮鎬打出凹口")
	await wait_physics()
	for offset in original:
		ray.from = from + Vector3(0.0, offset.x * 0.09, offset.y * 0.09)
		ray.to = ray.from + Vector3.RIGHT * 16.0
		var sample := space.intersect_ray(ray)
		expect(sample.get("collider") != rock or sample.position.x > original[offset].x + 0.015,
			"單次揮鎬清除挖口中央的舊岩皮碰撞，取樣 %s" % offset)


func check_skin_sliver() -> void:
	var surface := MeshInstance3D.new()
	var triangle := SurfaceTool.new()
	triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
	triangle.add_vertex(Vector3(-1, 0, 0))
	triangle.add_vertex(Vector3(1, 0, 0))
	triangle.add_vertex(Vector3(1, 2, 0))
	surface.mesh = triangle.commit()
	var skin := RockSkin.new(surface)
	var bounds := AABB(Vector3(-2, -1, -1), Vector3(4, 4, 2))
	expect(skin.remove([Plane(Vector3.RIGHT, 0.998)], bounds), "切面與原始岩面相交")
	expect(skin.make_mesh().get_surface_count() == 0, "裁切後極薄的原始岩面殘片被清掉")
	surface.free()


func check_exhausted_shell() -> void:
	var rock := RockVolume.new()
	rock.position = Vector3(11, 0, 12.0)
	rock.cell_origin = Vector3(-0.34, 0, -0.34)
	rock.solid_cells = PackedVector3Array([Vector3.ZERO])
	var skin_view := MeshInstance3D.new()
	skin_view.name = "Surface"
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(2.8, 0.5, 2.8)
	skin_view.mesh = shell_mesh
	skin_view.position.y = 0.25
	rock.add_child(skin_view)
	var collider := CollisionShape3D.new()
	collider.name = "RockShape"
	collider.shape = shell_mesh.create_trimesh_shape()
	rock.add_child(collider)
	q.add_child(rock)
	expect(rock.chip(rock.to_global(Vector3(-1.4, 0.25, 0.0)), Vector3.LEFT, 1), "挖去岩塊最後一格岩材")
	await wait_physics()
	expect(rock.solid.is_empty() and skin_view.mesh.get_surface_count() == 0 and collider.shape == null,
		"岩材挖空時整層舊岩皮和碰撞一併清除")
	rock.queue_free()


func create_support_fixture() -> RockVolume:
	var body := RockVolume.new()
	body.position = Vector3(10, 0, 12)
	body.collision_layer = 4
	body.cell_size = 0.54
	body.cut_material = StandardMaterial3D.new()
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	body.add_child(surface)
	var shape := CollisionShape3D.new()
	shape.name = "RockShape"
	body.add_child(shape)
	var data := PackedVector3Array()
	for x in 3:
		for z in 5:
			for y in 8:
				data.append(Vector3(x,y,z))
	body.solid_cells = data
	q.add_child(body)
	body._refresh_surface()
	body.detached.connect(q.excavation.spawn_section)
	return body


func run() -> void:
	check_skin_sliver()
	q = load("res://scenes/quarry.tscn").instantiate()
	root.add_child(q)
	await wait_physics()
	await check_exhausted_shell()
	var hit := hit_wall()
	var mountain := hit.get("collider") as RockVolume
	expect(mountain != null, "岩山正常入口的射線能打中原始岩體")
	if mountain:
		var previous := mountain.solid.size()
		var collider_before := mountain.collider.shape
		mountain.prepare()
		var intact := mountain.skin.original.back() as Dictionary
		var previous_point: Vector3 = hit.position
		mountain.chipped.connect(func(_point: Vector3, _normal: Vector3, count: int): drops_per_hit.append(count))
		var original_cells := mountain.solid.keys()
		var sample_offsets: Array[Vector3] = [Vector3.UP * 0.12, Vector3.DOWN * 0.12,
			Vector3.BACK * 0.12, Vector3.FORWARD * 0.12]
		var original_depths: Array[float] = []
		for offset in sample_offsets:
			var sample := hit_wall(offset)
			original_depths.append(sample.get("position", Vector3.INF).x)
		for index in 2:
			var shot := hit_wall()
			var target := shot.get("collider") as RockVolume
			if target:
				target.chip(shot.position, shot.normal, 1)
				await wait_physics()
		var drilled := hit_wall()
		expect(mountain.solid.size() < previous and mountain.collider.shape != collider_before and not mountain.chunk_shapes.is_empty(), "除掉山體材料並改用分塊碰撞")
		expect(drilled.is_empty() or drilled.position.x > previous_point.x + 0.15, "同一條射線真的進到凹洞更深處")
		for index in sample_offsets.size():
			var sample := hit_wall(sample_offsets[index])
			expect(sample.is_empty() or sample.position.x > original_depths[index] + 0.12,
				"挖口鄰近射線不會卡在原來的薄面")
		expect(mountain.surface.visible and mountain.skin.skin.has(intact), "遠離挖口的原始岩面仍留在網格上")
		var shell_cuts := mountain.cut_cells.keys().filter(func(cell: Vector3i): return cell not in original_cells)
		expect(shell_cuts.size() > 1, "挖口周圍多個空心格裡的原始外殼都會被裁切")
		expect(drops_per_hit == [1, 1], "普通敲擊只掉一顆原石")

	var test_rock := create_support_fixture()
	await wait_physics()
	var stability_sample := Vector3i(1, 7, 2)
	expect(test_rock.solid.has(stability_sample), "基座完整時保留上方岩層")
	test_rock.chip(test_rock.to_global(Vector3(0.015, 1.7, 0.25)), Vector3.LEFT, 1)
	expect(test_rock.solid.has(stability_sample), "先挖外側小凹口時，上層仍有足夠支撐")
	q.excavation.ore_landed.connect(func(_point: Vector3, count: int):
		expect(count <= 2, "單塊坍落最多掉兩顆原石")
		if count > 0:
			rubble_batches += 1
	)
	# Remove the lower layer progressively across the face of the supported volume.
	for z in [0.32, 0.82, 1.35, 1.88, 2.34]:
		for x in [0.03, 0.55, 1.12, 1.44]:
			test_rock.chip(test_rock.to_global(Vector3(x, 0.18, z)), Vector3.LEFT, 1)
			if not q.excavation.unstable.is_empty() and not test_rock.solid.has(stability_sample):
				break
		if not q.excavation.unstable.is_empty() and not test_rock.solid.has(stability_sample):
			break
	expect(not test_rock.solid.has(stability_sample), "底層去除足夠後上方失去支撐")
	expect(not q.excavation.unstable.is_empty() and q.excavation.falling.is_empty(), "失去支撐後先出現鬆動")
	await create_timer(0.20).timeout
	expect(q.excavation.falling.is_empty(), "預警期間岩塊還沒進入物理掉落")
	await create_timer(0.33).timeout
	expect(not q.excavation.falling.is_empty(), "鬆動後岩塊才成為獨立剛體")
	if not q.excavation.falling.is_empty():
		var body := q.excavation.falling.back() as Debris
		var from := body.global_position.y
		await create_timer(0.18).timeout
		expect(not is_instance_valid(body) or body.global_position.y < from, "岩塊真的受重力往下落")
	await create_timer(2.2).timeout
	expect(rubble_batches > 0, "落地碎裂後產生可拾取的碎岩")
	expect(q.excavation.loose.any(func(piece: Debris): return piece.usable()), "碎岩接觸地面並進入可拾取狀態")
	q.queue_free()
	await wait_physics()
	q = load("res://scenes/quarry.tscn").instantiate()
	root.add_child(q)
	await wait_physics()
	await check_single_strike_opening()
	await create_timer(0.70).timeout
	q.queue_free()
	await wait_physics()
	print("excavation_loop ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
