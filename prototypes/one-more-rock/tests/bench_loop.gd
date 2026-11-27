extends SceneTree

var bench
var failures := 0
var awards: Array[String] = []
var point: Vector2

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)

func press(pos: Vector2, touch: bool) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

# Game-time wait that ignores Engine.time_scale, so the rare hit stop cannot stall the test.
func wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func wait_for_perfect_beat() -> void:
	var beat: float = bench.last_strike_at + 0.40
	while bench.clock < beat:
		await process_frame

# Taps the stone five times at a fast cadence and checks every tap counts.
func open_stone(touch: bool) -> void:
	var fixed: int = bench.loot_index
	for i in 5:
		press(point, touch)
		press(point, touch)
		expect(bench.hits == i + 1, "同一幀連點只算一擊（第 %d 擊）" % (i + 1))
		await wait(0.12)
		expect(bench.loot_index == fixed, "殼內物品須固定")
	await wait(0.08)  # the last swing holds on impact before the reveal

func run() -> void:
	bench = load("res://scenes/workbench.tscn").instantiate()
	root.add_child(bench)
	bench.lucky_chance = 0.0
	bench.specimen_opened.connect(func(item: String): awards.append(item))
	await physics_frame
	await physics_frame
	var camera: Camera3D = bench.get_node("%Camera")
	point = camera.unproject_position(bench.get_node("%Stone").global_position)
	press(Vector2(50, 50), true)
	expect(bench.hits == 0, "敲到背景不應傷害原石")

	expect(bench.estimate_label.text.ends_with("×1.00"), "原石上台品相倍率 ×1.00")
	press(point, false)
	bench.animation.pause()
	bench.animation.custom_step(0.050)
	expect(bench.impact_index == 1 and bench.strike_face.global_position.distance_to(bench.last_impact) < 0.12, "槌面確實落在原石命中點並噴出石屑")
	expect(not bench.price.text.contains("幣") and bench.coins == 0, "敲擊時只浮出倍率，不透露金額")
	bench.animation.play()
	await wait_for_perfect_beat()
	# Strikes inside the closing-ring window are perfect and raise the multiplier.
	for index in 4:
		press(point, false)
		press(point, false)
		expect(bench.hits == index + 2, "同幀快速連點只算一擊")
		if index < 3:
			await wait_for_perfect_beat()
		else:
			await wait(0.14)
	expect(awards == ["石英"] and bench.coins == 0 and bench.revealing, "首顆石英揭露一次，需點一下收走")
	expect(bench.flawless and is_equal_approx(bench.quality, 1.65 * 1.25) and bench.payout == 17, "普通一擊及四下完美會加分，完美無瑕另有加成")
	expect(bench.price.text == "8 × 2.06 = 17 幣" and bench.achievements.has("完美無瑕"), "揭曉時才顯示基價 × 倍率")
	expect(bench.get_node("%MineralName").text == "石英" and bench.get_node("%MineralIcon").texture != null, "右上角圖鑑初次通知顯示名稱與圖片")
	expect(bench.get_node("%AchievementToast").visible and bench.achievements.has("第一次開石"), "第一次開石解鎖成就")
	await wait(1.7)
	expect(bench.revealing and bench.get_node("%Finds").get_child(0).visible and not bench.stone.visible, "無輸入時顯示礦物，等待下一次點擊")
	var crystal := bench.get_node("%Finds").get_child(0) as Node3D
	var origin := crystal.position
	press(point, false)
	press(point, false)
	await wait(0.15)
	expect(bench.clearing and crystal.position.distance_to(origin) > 0.3 and bench.coins == 0, "點擊後先移走水晶，多點幾下不增加結算")
	await wait(0.21)
	expect(bench.coins == 17 and bench.displayed_coins < 17 and bench.get_node("%CashSound").playing, "入托盤後發錢，音效和數字開始滾動")
	await wait(0.52)
	expect(bench.stone.visible and bench.hits == 0 and bench.displayed_coins == 17 and bench.quality == 1.0, "補入下一顆，倍率重設，金錢顯示到帳")

	bench.loot_index = 0
	await open_stone(true)
	expect(bench.coins == 17 and bench.revealing and bench.get_node("%Finds").get_child(3).visible, "觸控敲出碎石也在台上等待收走")
	expect(is_equal_approx(bench.quality, 1.25) and bench.payout == 3, "快速連敲仍逐擊加分，碎石也有正收益")
	expect(bench.discoveries.has("碎石") and bench.get_node("%MineralName").text == "碎石", "第一次碎石有圖鑑")
	press(point, true)
	await wait(0.5)
	expect(bench.coins == 20 and bench.stone.visible, "點收走碎石並補下一顆")

	bench.loot_index = 3
	await open_stone(false)
	expect(bench.revealing and bench.coins == 20 and bench.get_node("%MineralName").text == "紫水晶", "紫水晶有圖鑑通知並保留至下一次點擊")
	press(point, false)
	await wait(0.5)
	bench.loot_index = 3
	bench.get_node("%CollectionToast").hide()
	await open_stone(false)
	expect(bench.discoveries.size() == 3 and not bench.get_node("%CollectionToast").visible, "重複紫水晶不再顯示首次收錄")
	expect(awards.size() == 4 and bench.coins == 95, "每顆只揭露與付費一次，最後一顆仍待收走")
	bench.finishing_level = 1
	bench.lucky_chance = 1.0
	press(point, false)
	await wait(0.56)
	expect(is_equal_approx(bench.quality, 1.10), "修面工具給下一顆原石提高起始品相")
	press(point, false)
	await wait(0.10)
	expect(is_equal_approx(bench.quality, 1.29) and bench.price.text.contains("亮面"), "亮面給額外倍率，已購入的修面也提高每擊加成")
	await wait(0.45)

	print("bench_loop ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
