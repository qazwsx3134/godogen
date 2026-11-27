extends RefCounted

const DevPanel = preload("res://addons/godot_dev_panel/dev_panel.gd")
const Player = preload("res://player.gd")
const Workbench = preload("res://workbench.gd")
const Excavation = preload("res://excavation.gd")


static func mount(quarry: Node) -> void:
	if not DevPanel.available():
		return
	var scene := load("res://addons/godot_dev_panel/dev_panel.tscn") as PackedScene
	var panel := scene.instantiate() as DevPanel
	quarry.add_child(panel)
	var player := quarry.get_node("%Player") as Player
	var bench := quarry.get_node("%Workbench") as Workbench
	var excavation := quarry.get_node("%Excavation") as Excavation
	panel.opened.connect(Callable(quarry, "_clear_touch"))
	panel.opened.connect(bench.cancel_held_strike)

	panel.bind_number("Hero", "步行速度", player, &"speed", 1, 12, 0.1)
	panel.bind_number("Hero", "跑步速度", player, &"run_speed", 1, 20, 0.1)
	panel.bind_number("Hero", "跳躍速度", player, &"jump_speed", 1, 12, 0.1)
	panel.bind_number("Camera", "視野角度", player.eyes, &"fov", 45, 105, 1)
	panel.bind_number("Camera", "桌機靈敏度", player, &"mouse_sensitivity", 0.0005, 0.012, 0.0001)
	panel.bind_number("Camera", "觸控靈敏度", player, &"touch_sensitivity", 0.0005, 0.015, 0.0001)
	panel.bind_number("Camera", "命中鏡頭震幅", player, &"camera_kick_scale", 0, 2, 0.05)

	panel.bind_number("Terrain", "連挖間隔（秒）", quarry, &"mine_interval", 0.25, 1, 0.005)
	panel.bind_number("Terrain", "抬鎬（秒）", player, &"swing_raise_time", 0.03, 0.25, 0.005)
	panel.bind_number("Terrain", "揮擊（秒）", player, &"swing_strike_time", 0.035, 0.25, 0.005)
	panel.bind_number("Terrain", "卡鎬（秒）", player, &"swing_contact_time", 0, 0.15, 0.005)
	panel.bind_number("Terrain", "收回（秒）", player, &"swing_recover_time", 0.06, 0.35, 0.005)
	panel.bind_number("Terrain", "揮鎬弧寬", player, &"swing_width", 0.10, 0.60, 0.01)
	panel.bind_number("Terrain", "鎬的距離（公尺）", player, &"mining_reach", 0.5, 3, 0.05)
	panel.bind_number("Terrain", "十字鎬等級", player, &"mining_power", 1, 2, 1)
	panel.bind_number("Terrain", "碎岩剛體預算", excavation, &"body_budget", 8, 200, 1)
	panel.bind_toggle("Terrain", "採礦石屑與粉塵", quarry, &"mining_particles")
	panel.bind_toggle("Terrain", "手機命中震動", quarry, &"mining_haptics")
	panel.add_readout("Debug View", "地上原石", func(): return excavation.loose.size())
	panel.add_readout("Debug View", "坍落中的岩塊", func(): return excavation.falling.size())

	panel.bind_number("Rewards", "收取半徑（公尺）", quarry, &"pickup_radius", 0.5, 3, 0.05)
	panel.bind_number("Rewards", "卸貨半徑（公尺）", quarry, &"unload_radius", 0.5, 3, 0.05)
	panel.bind_number("Rewards", "工作台連敲間隔（秒）", bench, &"min_hit_interval", 0.015, 0.5, 0.005)
	panel.bind_number("Rewards", "碎石微光機率", bench, &"rubble_glow_chance", 0, 1, 0.01)
	panel.bind_number("Rewards", "敲出亮面機率", bench, &"lucky_chance", 0, 1, 0.01)
	panel.add_action("Rewards", "加 100 測試金幣", Callable(bench, "_change_wallet").bind(100))
	for count in [30, 100]:
		panel.add_action("Stress Tests", "在前方放 %d 顆原石" % count,
			_spawn_rocks.bind(player, excavation, count))

	var mine_sound := quarry.get_node("%MineSound") as AudioStreamPlayer
	var pickup_sound := quarry.get_node("%PickupSound") as AudioStreamPlayer
	var unload_sound := quarry.get_node("%UnloadSound") as AudioStreamPlayer
	var cash_sound := bench.get_node("%CashSound") as AudioStreamPlayer
	var fracture_sound := quarry.get_node("%RockBreakSound") as AudioStreamPlayer
	var ore_sound := quarry.get_node("%OreFoundSound") as AudioStreamPlayer
	var crystal_sound := quarry.get_node("%CrystalOreSound") as AudioStreamPlayer
	var mineral_impact := quarry.get_node("%MineralImpactSound") as AudioStreamPlayer
	var hammer_sound := bench.get_node("%Tap") as AudioStreamPlayer
	for entry in [["揮鎬", player.swing_sound], ["鎬頭命中", mine_sound], ["岩石碎裂", fracture_sound],
			["挖出原石", ore_sound], ["露頭礦片命中", mineral_impact], ["水晶共鳴", crystal_sound], ["工坊槌擊", hammer_sound],
			["砂礫腳步", player.footstep_sound], ["拾取", pickup_sound], ["卸貨", unload_sound], ["入帳", cash_sound]]:
		var sound: AudioStreamPlayer = entry[1]
		panel.bind_number("Audio", "%s音量（dB）" % entry[0], sound, &"volume_db", -60, 6, 0.5)
		panel.add_action("Sound Test", "播放%s音效" % entry[0], panel.preview_sound.bind(sound))


static func _spawn_rocks(player: Player, excavation: Excavation, count: int) -> void:
	var origin := player.global_position - player.global_basis.z * 2.0 + Vector3.UP * 0.45
	for index in floori(count / 5.0):
		var offset := Vector3(index % 5 - 2, 0, floori(index / 5.0)) * 0.33
		excavation.spawn_ore(origin + offset, Vector3.UP, 5)
