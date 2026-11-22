extends SceneTree
## timeout 120 godot --headless --path . -s tests/test_hole.gd </dev/null

func _init() -> void:
	var m: Node3D = load("res://scenes/main.tscn").instantiate()
	m.follow_mouse = false
	root.add_child(m)
	for p in m.get_node("Props").get_children():
		p.free()
	var hole := m.get_node("%Hole") as HoleBody
	var props := m.get_node("Props")
	var small := _spawn(props, "prop_box", Vector3(0, 0.3, 0))      # 洞正上方，小
	var crate := _spawn(props, "prop_crate", Vector3(6, 0.7, 0))    # 比洞大
	var far := _spawn(props, "prop_ball", Vector3(-8, 0.4, -8))     # 遠處
	await _frames(90)
	if not _ok(not is_instance_valid(small) and hole.eaten == 1, "small prop above hole is eaten"): return
	if not _ok(far.global_position.y > 0.1 and far.collision_mask == hole.normal_flags, "far prop rests on floor"): return
	# 洞移到木箱底下：木箱比洞大，應卡在洞緣，不掉下去
	await _frames(20)  # 等變大動畫跑完再縮回原尺寸，下面只測「比洞大」
	hole.size = 1.0
	hole.target = Vector3(6, 0, 0)
	await _frames(120)
	if not _ok(is_instance_valid(crate) and crate.global_position.y > 0.2, "crate larger than hole stays on the lip"): return
	if not _ok(crate.collision_mask == hole.hole_flags, "crate over hole uses hole flags"): return
	# 移走洞：木箱回到一般地板 flags，仍在地面上
	hole.target = Vector3(-4, 0, 6)
	await _frames(120)
	if not _ok(crate.collision_mask == hole.normal_flags and crate.global_position.y > 0.2
			and Vector2(crate.global_position.x - 6, crate.global_position.z).length() < 1.0, "crate back on floor, not dragged by the moving hole"): return
	# 洞移到小球底下：會吃掉
	var ball := _spawn(props, "prop_ball", Vector3(-8, 0.4, 6))
	await _frames(30)
	hole.target = Vector3(-8, 0, 6)
	await _frames(150)
	if not _ok(not is_instance_valid(ball) and hole.eaten == 2, "moving hole eats resting ball"): return
	if not _ok(absf(hole.size - (1.0 + hole.grow_per_eat)) < 0.01, "hole grows per eat"): return
	# 長大到直徑超過木箱：木箱會掉進去
	hole.size = 1.8  # 木箱對角線 5.1m，洞直徑要大於它
	crate.free()  # ponytail: 移動中的大洞會把木箱推走（見 README），這裡只測「大洞吞得下」
	crate = _spawn(props, "prop_crate", Vector3(hole.global_position.x, 0.7, hole.global_position.z))
	await _frames(240)
	if not _ok(not is_instance_valid(crate) and hole.eaten == 3, "grown hole eats the crate"): return
	# 掉到一半洞就滑開：仍要被全域刪除區刪掉並計分
	hole.size = 1.0
	var faller := _spawn(props, "prop_ball", hole.global_position + Vector3(0, -1.5, 0))
	faller.collision_mask = hole.hole_flags
	await _frames(2)
	hole.global_position += Vector3(10, 0, 0)  # 瞬移：物體留在地底，洞底刪除區已不在下方
	hole.target = hole.global_position
	await _frames(150)
	if not _ok(not is_instance_valid(faller) and hole.eaten == 4, "body left under the floor is killed by Abyss"): return
	print("ALL PASS")
	quit()


func _spawn(parent: Node, kind: String, pos: Vector3) -> RigidBody3D:
	var p: RigidBody3D = load("res://scenes/%s.tscn" % kind).instantiate()
	p.position = pos
	parent.add_child(p)
	return p


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("FAIL " + msg)
		quit(1)
	return cond
