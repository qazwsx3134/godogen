extends "res://addons/proto_kit/test_kit.gd"
## Measures the core-loop target (design/core-loop.md): pulling 3+ and sweeping should level clearly faster
## than tapping one monster at a time. Taps go through Main._click, the same path as a finger.
##   godot --headless --path . --fixed-fps 60 -s tests/bot_m1.gd -- [seconds=180] [seed=7] [knob=value ...]
##   godot --headless --path . --fixed-fps 60 -s tests/bot_m1.gd -- clear [pack=5] [knob=value ...]   # one pack
## Knobs try a tuning without editing scenes: `sweep_cost=20` sets a Player export, `slime.max_hp=60` sets it on
## every monster whose scene is slime.tscn.

const SAVE := "user://bot_m1/save.json"

var main: Node3D
var player: Node3D
var cam: Camera3D
var knobs: PackedStringArray = []
## Bot policy: sweep once this many provoked monsters stand inside the sweep radius (knob `min_sweep=2`).
var min_sweep: int = 3


func _init() -> void:
	_run.call_deferred()


func _total_xp() -> int:
	var total: int = player.xp
	for l in range(1, player.level):
		total += player.xp_for_level(l)
	return total


func _alive_monsters() -> Array:
	return root.get_tree().get_nodes_in_group("monster").filter(func(m: Node3D) -> bool: return m.is_alive())


func _nearest(list: Array) -> Node3D:
	var best: Node3D = null
	for m: Node3D in list:
		if best == null or m.position.distance_to(player.position) < best.position.distance_to(player.position):
			best = m
	return best


func _tap_monster(m: Node3D) -> void:
	main._click(cam.unproject_position(m.global_position + Vector3.UP * m.actor.head_height * 0.5), true)


func _play(strategy: String, seconds: float, seed_value: int) -> Dictionary:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	main.get_node("%Combat").rng_seed = seed_value
	seed(seed_value)
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")
	_apply_knobs()
	cam = main.get_node("%CameraRig").camera
	var nodes_start := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var mem_start := Performance.get_monitor(Performance.MEMORY_STATIC)
	var nodes_peak := nodes_start
	var deaths := 0
	var sweeps := 0
	var sweep_sizes: Array[int] = []
	var was_dead := false
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0
		nodes_peak = maxf(nodes_peak, Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if player.dead:
			if not was_dead:
				deaths += 1
			was_dead = true
			continue
		was_dead = false
		var alive := _alive_monsters().filter(func(m: Node3D) -> bool: return m.aggressive == false)
		if strategy == "single":
			if player.target == null and not alive.is_empty():
				_tap_monster(_nearest(alive))
		else:
			var close := alive.filter(func(m: Node3D) -> bool: return m._provoked and m.position.distance_to(player.position) <= player.sweep_radius)
			if close.size() >= min_sweep and player.sweep_left <= 0.0 and player.ap >= player.sweep_cost and not player.casting:
				if player.use_sweep() == "":
					sweeps += 1
					sweep_sizes.append(close.size())
				continue
			var provoked := alive.filter(func(m: Node3D) -> bool: return m._provoked)
			var calm := alive.filter(func(m: Node3D) -> bool: return not m._provoked)
			if provoked.size() < min_sweep and not calm.is_empty() and (player.target == null or player.target._provoked) \
					and (provoked.is_empty() or _nearest(calm).position.distance_to(player.position) < 9.0):
				_tap_monster(_nearest(calm))  # tag the next one; it chases us
			elif player.target == null and not provoked.is_empty():
				_tap_monster(_nearest(provoked))
	var bag_value := 0
	for s: Dictionary in player.bag.slots:
		bag_value += int(preload("res://scripts/items.gd").ALL[s.id].get("sell", 0)) * s.count
	var result := {"strategy": strategy, "xp": _total_xp(), "level": player.level, "deaths": deaths, "sweeps": sweeps,
		"sweep_sizes": sweep_sizes, "bag_value": bag_value, "bag_slots": player.bag.slots.size(),
		"nodes": "%d -> %d (peak %d)" % [nodes_start, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes_peak],
		"static_mb": "%.1f -> %.1f" % [mem_start / 1048576.0, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]}
	main.queue_free()
	await _frames(2)
	return result


## One pack of `size` slimes already around the player; seconds to kill them all and the lowest HP reached.
func _apply_knobs() -> void:
	for k in knobs:
		var kv := k.split("=")
		if kv[0] == "min_sweep":
			min_sweep = int(kv[1])
			continue
		var path := kv[0].split(".")
		if path.size() == 1:
			player.set(path[0], float(kv[1]))
		else:
			for m: Node3D in root.get_tree().get_nodes_in_group("monster"):
				if m.scene_file_path.get_file().get_basename() == path[0]:
					m.set(path[1], int(float(kv[1])) if typeof(m.get(path[1])) == TYPE_INT else float(kv[1]))
					if path[1] == "max_hp":
						m.hp = m.max_hp


func _clear(strategy: String, size: int, seed_value: int) -> Dictionary:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	main.get_node("%Combat").rng_seed = seed_value
	seed(seed_value)
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")
	cam = main.get_node("%CameraRig").camera
	_apply_knobs()
	var pack := root.get_tree().get_nodes_in_group("monster").filter(func(m: Node3D) -> bool:
		return m.scene_file_path.ends_with("slime.tscn")).slice(0, size)
	for m: Node3D in root.get_tree().get_nodes_in_group("monster"):
		if m not in pack:
			m.position += Vector3(500, 0, 0)  # out of the way
	for i in pack.size():
		var a := TAU * i / pack.size()
		pack[i].position = player.position + Vector3(cos(a), 0, sin(a)) * 2.0
		pack[i].respawn_seconds = 9999.0
		pack[i]._provoked = true
	var low: float = player.hp / player.max_hp
	var t := 0.0
	while pack.any(func(m: Node3D) -> bool: return m.is_alive()) and t < 120.0 and not player.dead:
		await process_frame
		t += 1.0 / 60.0
		low = minf(low, player.hp / player.max_hp)
		var alive := pack.filter(func(m: Node3D) -> bool: return m.is_alive())
		var close := alive.filter(func(m: Node3D) -> bool: return m.position.distance_to(player.position) <= player.sweep_radius)
		if strategy == "sweep" and close.size() >= min_sweep and player.sweep_left <= 0.0 \
				and player.ap >= player.sweep_cost and not player.casting:
			player.use_sweep()
		elif player.target == null and not alive.is_empty() and not player.casting:
			player.set_target(_nearest(alive))
	var result := {"strategy": strategy, "seconds": snappedf(t, 0.1), "lowest_hp": "%d%%" % int(low * 100.0), "died": player.dead}
	main.queue_free()
	await _frames(2)
	return result


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 180.0
	var seed_value := int(args[1]) if args.size() > 1 else 7
	knobs = args.slice(2)
	if args.size() > 0 and args[0] == "clear":
		knobs = args.slice(2)
		for k in knobs:
			if k.begins_with("min_sweep="):
				min_sweep = int(k.split("=")[1])
		var size := int(args[1]) if args.size() > 1 else 5
		var s := await _clear("single", size, 7)
		var w := await _clear("sweep", size, 7)
		print("CLEAR ", s)
		print("CLEAR ", w)
		print("CLEAR sweep speedup = %.2f (target >= 1.40)" % (s.seconds / maxf(0.1, w.seconds)))
		_finish("SEAL MEADOW M1 BOT")
		return
	var a := await _play("single", seconds, seed_value)
	var b := await _play("pull_sweep", seconds, seed_value)
	print("BOT ", a)
	print("BOT ", b)
	var ratio := float(b.xp) / maxf(1.0, a.xp)
	print("BOT pull_sweep / single XP = %.2f (target >= 1.40)" % ratio)
	_expect(a.xp > 0 and b.xp > 0, "both strategies earn XP without a keyboard")
	_finish("SEAL MEADOW M1 BOT")
