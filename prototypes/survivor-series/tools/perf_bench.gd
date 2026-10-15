extends SceneTree
## Worst-case frame cost: full enemy cap, six maxed evolved/fused weapons, night-market roadblocks.
## Run rendered and offscreen: xvfb-run -a godot --path . --fixed-fps 60 -s res://tools/perf_bench.gd
## Prints avg / p95 / max of wall time per frame, draw calls and node count, plus nodes per Street child.
## Wall time, not Performance.TIME_*: those monitors jump around (a 4 s physics max on a 6 ms average run).
# ponytail: xvfb renders with software GL, so its wall time overstates GPU cost; --headless gives game logic alone.
# Draw calls and node counts carry over to phones; real frame time needs the web build on a device.

const FRAMES := 900
const WARMUP := 120

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.get_node("Services/Meta").save_path = "user://perf_bench_meta.json"
	root.add_child(game)
	await process_frame
	game.menu.get_node("%Start").pressed.emit()
	var street = game.street
	street.player.max_hp = 1e9
	street.player.hp = 1e9
	var loadout: Array = []
	for slot: String in ["evolution", "fusion", "weapon"]:
		for path: String in DirAccess.get_files_at("res://data/items"):
			var item: Resource = load("res://data/items/" + path.trim_suffix(".remap"))
			if item.slot == slot and loadout.size() < 6 and item.projectile != null:
				loadout.append(item)
	street.build.weapons.clear()
	for item: Resource in loadout:
		street.build.weapons.append(item.id)
		street.build.levels[item.id] = item.max_level
	print("loadout: ", loadout.map(func(i: Resource) -> StringName: return i.id))
	var draws: Array = []
	var nodes: Array = []
	var wall_ms: Array = []
	var last := Time.get_ticks_usec()
	for frame: int in FRAMES + WARMUP:
		game.state = game.State.RUNNING
		street.player.hp = 1e9
		street.build.pending_choices = 0
		for i: int in mini(4, street.max_enemies - street.enemies.get_child_count()):
			street.spawn_enemy(street.rng.randi_range(0, street.enemy_scenes.size() - 1), street.spawn_point())
		await process_frame
		var now := Time.get_ticks_usec()
		var spent := (now - last) / 1000.0
		last = now
		if frame < WARMUP:
			continue
		wall_ms.append(spent)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var census: Dictionary = {}
	for child: Node in street.get_children():
		census[child.name] = _count(child)
	print(census)
	print("enemies=%d projectiles=%d" % [street.living_count(), street.projectiles.get_child_count()])
	for row: Array in [["wall ms", wall_ms], ["draw calls", draws], ["nodes", nodes]]:
		var v: Array = row[1].duplicate()
		v.sort()
		var avg: float = v.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / v.size()
		print("%-10s avg %.2f  p95 %.2f  max %.2f" % [row[0], avg, v[int(v.size() * 0.95)], v[-1]])
	quit()

func _count(node: Node) -> int:
	var n := 1
	for child: Node in node.get_children():
		n += _count(child)
	return n
