extends SceneTree
## Domain simulation of arena reward/restart rules. No rendering or player saves.
const Progression = preload("res://domain/progression.gd")
const MarchSim = preload("res://domain/march_sim.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var rows: Array = []
	var matrix := "--matrix" in OS.get_cmdline_user_args()
	var seeds: Array = [7, 73, 4242] if matrix else [73]
	var stages: Array = [1, 2, 3, 8] if matrix else [1]
	for seed_value: int in seeds:
		for stage_n: int in stages:
			for level: int in [1, 20]:
				for seconds: int in [300, 3600]:
					var row := _compare(seed_value, stage_n, level, seconds)
					rows.append(row)
					print("seed%d stage%d Lv%d %ds: online=%d offline=%d difference=%.2f%% losses=%d" % [seed_value, stage_n, level, seconds, row.online_gold, row.offline_gold, row.gold_difference_percent, row.online_losses])
	var output := "/tmp/hero-march-rewards.json"
	if not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0] != "--matrix":
		output = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write report: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify({"rows": rows, "scope": "Domain model of MarchArena kill/travel/restart rules at 20 Hz; scenario seed resets per restart; stages recorded per row; no player upgrades or saves"}, "\t"))
	file.close()
	print("report: " + output)
	quit()


func _compare(seed_value: int, stage_n: int, level: int, seconds: int) -> Dictionary:
	var original := Progression.new(seed_value)
	for hero: int in original.march:
		original.hero_level[hero] = level
	original.march_stage = stage_n
	original.cleared = stage_n - 1
	var online := Progression.from_dict(original.to_dict().duplicate(true))
	var offline := Progression.from_dict(original.to_dict().duplicate(true))
	seed(seed_value)
	var sim := MarchSim.new(seed_value, online.march_units(), online.march_stage, online.cooldown_mult())
	var losses := 0
	var recover := 0.0
	var pending := false
	for tick: int in seconds * 20:
		if recover > 0.0:
			recover -= MarchSim.TICK
			if recover <= 0.0:
				sim = MarchSim.new(seed_value, online.march_units(), online.march_stage, online.cooldown_mult())
			continue
		sim.step(MarchSim.TICK)
		for event: Dictionary in sim.take_events():
			if event.kind == &"kill":
				online.march_kill(event.stage, event.elite)
				pending = true
			elif event.kind == &"travel" and pending:
				sim = MarchSim.new(seed_value, online.march_units(), online.march_stage, online.cooldown_mult())
				sim.travel_t = MarchSim.TRAVEL_TIME
				pending = false
			elif event.kind == &"lost":
				losses += 1
				online.march_lost()
				recover = 2.0
	var got: Dictionary = offline._march_for(seconds)
	var online_gold: int = online.gold - original.gold
	var row := {"seed": seed_value, "starting_stage": stage_n, "starting_level": level, "seconds": seconds,
		"online_final_stage": online.march_stage, "offline_final_stage": offline.march_stage, "online_losses": losses,
		"online_gold": online_gold, "offline_gold": got.gold,
		"gold_difference_percent": 100.0 * (got.gold - online_gold) / maxf(1.0, online_gold),
		"online_kills": online.march_kills - original.march_kills, "offline_kills": got.kills,
		"online_levels": Array(online.hero_level), "offline_levels": Array(offline.hero_level),
		"online_exp": Array(online.hero_exp), "offline_exp": Array(offline.hero_exp),
		"online_shards": online.shards - original.shards, "offline_shards": got.shards,
		"online_stones": online.stones - original.stones, "offline_stones": got.stones,
		"online_items": online.bag.size() - original.bag.size(), "offline_items": got.items.size(),
		"online_potions": Array(online.potions), "offline_potions": Array(offline.potions)}
	return row
