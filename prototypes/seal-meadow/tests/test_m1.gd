extends "res://addons/proto_kit/test_kit.gd"
## M1 combat checks on the real main scene: one resolve path, seeded replay, sweep skill rules.
## godot --headless --path . -s tests/test_m1.gd

const SAVE := "user://test_m1/save.json"

var main: Node3D
var player: Node3D
var combat: Node
var hits: Array = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")
	combat = main.get_node("%Combat")
	combat.hit_landed.connect(func(a: Node3D, v: Node3D, amount: int, crit: bool) -> void: hits.append([a, v, amount, crit]))
	_test_seed()
	await _test_kill_xp_once()
	await _test_sweep()
	await _test_sweep_cancel()
	await _test_swing_once()
	_test_pack_aggro()
	main.queue_free()
	_finish("SEAL MEADOW M1 TESTS")


func _monsters() -> Array:
	return get_nodes_in_group_alive()


func get_nodes_in_group_alive() -> Array:
	return root.get_tree().get_nodes_in_group("monster").filter(func(m: Node3D) -> bool: return m.is_alive())


## Puts n live monsters around the player at `dist` metres and calms them so they do not bite mid-test.
func _gather(n: int, dist: float) -> Array:
	var picked := _monsters().slice(0, n)
	for i in picked.size():
		var a := TAU * i / picked.size()
		picked[i].position = player.position + Vector3(cos(a), 0, sin(a)) * dist
		picked[i].hp = picked[i].max_hp
		picked[i].set_process(false)
	return picked


func _release(ms: Array) -> void:
	for m: Node3D in ms:
		m.set_process(true)


func _test_seed() -> void:
	var rolls := func(seed_value: int) -> Array:
		var c: Node = load("res://scripts/combat.gd").new()
		c.rng_seed = seed_value
		root.add_child(c)
		var out := []
		for i in 20:
			var crit: bool = c.rng.randf() < c.crit_chance
			out.append([crit, c.rng.randi_range(-2, 3)])
		c.free()
		return out
	_expect(rolls.call(42) == rolls.call(42), "same seed replays the same rolls")
	_expect(rolls.call(42) != rolls.call(43), "a different seed rolls differently")


func _test_kill_xp_once() -> void:
	var m: Node3D = _gather(1, 1.0)[0]
	m.hp = 1
	var xp_before: int = player.xp + player.level * 1000
	combat.attack(player, m, 50)
	combat.attack(player, m, 50)  # stale second swing on a dead monster
	var gained: int = player.xp + player.level * 1000 - xp_before
	_expect(not m.is_alive(), "monster died")
	_expect(gained > 0 and hits.filter(func(h: Array) -> bool: return h[1] == m).size() == 1, "kill pays XP once, dead target takes no hit")
	_release([m])


func _test_sweep() -> void:
	var ms := _gather(3, 1.5)
	var others := _monsters().filter(func(m: Node3D) -> bool: return m not in ms)
	var far: Node3D = others[0] if others.size() > 0 else null
	if far:
		far.position = player.position + Vector3(6, 0, 0)
		far.set_process(false)
	player.ap = player.max_ap
	player.sweep_left = 0.0
	hits.clear()
	_expect(player.use_sweep() == "", "sweep starts")
	_expect(player.use_sweep() == "casting", "second tap during windup is refused")
	await _until(func() -> bool: return not player.casting, "windup ends", 2.0)
	var struck := hits.filter(func(h: Array) -> bool: return h[0] == player).map(func(h: Array) -> Node3D: return h[1])
	_expect(ms.all(func(m: Node3D) -> bool: return m in struck), "sweep hits every monster in radius")
	_expect(far == null or far not in struck, "sweep misses monsters outside radius")
	_expect(struck.size() == ms.size(), "each monster hit once")
	_expect(player.ap <= player.max_ap - player.sweep_cost + 1.0, "AP spent")
	_expect(player.use_sweep() == "cooldown", "cooldown refuses")
	player.sweep_left = 0.0
	player.ap = player.sweep_cost - 1
	_expect(player.use_sweep() == "ap", "low AP refuses")
	_release(ms + ([far] if far else []))


func _test_sweep_cancel() -> void:
	var ms := _gather(2, 1.5)
	player.ap = player.max_ap
	player.sweep_left = 0.0
	hits.clear()
	player.use_sweep()
	player.move_to(player.position + Vector3(3, 0, 0))
	await _frames(30)
	_expect(hits.filter(func(h: Array) -> bool: return h[0] == player).is_empty(), "moving during windup cancels the sweep")
	_expect(player.ap >= player.max_ap - 0.01 and player.sweep_left == 0.0, "cancelled sweep costs nothing")
	_release(ms)


func _test_swing_once() -> void:
	var m: Node3D = _gather(1, 1.0)[0]
	m.max_hp = 100000
	m.hp = m.max_hp
	player.set_target(m)
	hits.clear()
	var seconds := 4.0
	await create_timer(seconds).timeout
	player.target = null
	var swings := hits.filter(func(h: Array) -> bool: return h[0] == player).size()
	var expected := int(seconds / player.attack_interval)
	_expect(absi(swings - expected) <= 1, "auto-attack lands once per interval (%d vs %d)" % [swings, expected])
	_release([m])


func _test_pack_aggro() -> void:
	var slimes := root.get_tree().get_nodes_in_group("monster").filter(func(m: Node3D) -> bool:
		return m.is_alive() and m.scene_file_path.ends_with("slime.tscn"))
	var a: Node3D = slimes[0]
	var near: Node3D = slimes[1]
	var far: Node3D = slimes[2]
	for m: Node3D in [a, near, far]:
		m._provoked = false
		m._returning = false
		m.set_process(false)
	near.position = a.position + Vector3(3, 0, 0)
	far.position = a.position + Vector3(20, 0, 0)
	combat.attack(player, a, 1)
	_expect(near._provoked and not far._provoked, "hitting one slime wakes its pack, not distant ones")
	_release([a, near, far])
