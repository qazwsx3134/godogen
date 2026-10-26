extends "res://addons/proto_kit/test_kit.gd"
## M1 rewards: bag transactions, drop tables, ground piles, one-time pickup, respawn ids, save migration.
## godot --headless --path . -s tests/test_m1_loot.gd

const Inventory = preload("res://scripts/inventory.gd")
const Items = preload("res://scripts/items.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const SAVE := "user://test_m1_loot/save.json"

var main: Node3D
var player: Node3D
var sounds: Array[StringName] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_inventory()
	_expect(Items.broken_refs().is_empty(), "every drop table points at a defined item")
	for f in [SAVE, SAVE + ".bak"]:
		DirAccess.remove_absolute(f)
	SaveSlots.save(SAVE, {"level": 3, "xp": 5, "x": 0.0, "z": 0.0}, 1)  # a save from before the bag existed
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await _frames(3)
	player = main.get_node("%Player")
	main.get_node("%Sfx").played.connect(func(s: StringName) -> void: sounds.append(s))
	_expect(player.level == 3 and player.bag.slots.is_empty(), "v1 save migrates: level kept, empty bag")
	await _test_drops_and_pickup()
	await _test_respawn_drops_target()
	main.queue_free()
	_finish("SEAL MEADOW M1 LOOT TESTS")


func _test_inventory() -> void:
	var bag := Inventory.new(2)
	_expect(bag.add("jelly_gel", 25), "25 gel fits in two stacks of 20")
	_expect(bag.slots.size() == 2 and bag.count("jelly_gel") == 25, "stacks split at the limit")
	_expect(not bag.add("apple", 1), "no free slot for a new item")
	_expect(not bag.add("jelly_gel", 16), "16 more gel does not fit (15 free)")
	_expect(bag.count("jelly_gel") == 25, "a failed add changes nothing")
	_expect(bag.add("jelly_gel", 15) and bag.count("jelly_gel") == 40, "exactly filling works")
	_expect(not bag.remove("jelly_gel", 41) and bag.count("jelly_gel") == 40, "over-remove refused, nothing taken")
	_expect(bag.remove("jelly_gel", 30) and bag.count("jelly_gel") == 10 and bag.slots.size() == 1, "remove frees an emptied slot")
	_expect(not bag.add("no_such_item", 1), "unknown id refused")
	bag.load_data([{"id": "apple", "count": 99}, {"id": "gone", "count": 1}])
	_expect(bag.slots == [{"id": "apple", "count": 10}], "load clamps to stack and drops unknown ids")


func _piles() -> Array:
	return root.get_tree().get_nodes_in_group("loot").filter(func(l: Node3D) -> bool: return not l.taken)


func _test_drops_and_pickup() -> void:
	var m: Node3D = root.get_tree().get_nodes_in_group("monster")[0]
	for i in 30:
		if not _piles().is_empty():
			break
		main._drop_loot(m)
	await _frames(1)
	var pile: Node3D = _piles()[0] if not _piles().is_empty() else null
	_expect(pile != null, "a kill drops a pile")
	if pile == null:
		return
	# full bag: the pile stays on the ground, untouched
	var cap: int = player.bag.capacity
	player.bag.capacity = 0
	_expect(not main.pickup(pile) and not pile.taken and is_instance_valid(pile), "full bag leaves the pile")
	_expect(&"bag_full" in sounds, "full bag plays its sound")
	player.bag.capacity = cap
	var id: String = pile.item_id
	var n: int = pile.count
	var before: int = player.bag.count(id)
	_expect(main.pickup(pile), "pickup succeeds")
	_expect(not main.pickup(pile), "the same pile cannot be picked twice")
	_expect(sounds.count(&"pickup") == 1, "one pickup, one pickup sound")
	_expect(player.bag.count(id) == before + n, "bag got exactly the pile")
	_expect(int(SaveSlots.restore(SAVE, main.SAVE_VERSION).data.bag.size()) > 0, "pickup is saved")
	# tap a pile: the player walks over and picks it up
	for p: Node3D in _piles():
		p.taken = true
		p.queue_free()
	main._drop_loot(m)
	for i in 30:
		if not _piles().is_empty():
			break
		main._drop_loot(m)
	await _frames(1)
	pile = _piles()[0]
	pile.position = player.position + Vector3(2.5, 0, 0)
	var cam: Camera3D = main.get_node("%CameraRig").camera
	main._click(cam.unproject_position(pile.global_position + Vector3.UP * 0.35), true)
	var ref: WeakRef = weakref(pile)
	var gone := func() -> bool: return ref.get_ref() == null or ref.get_ref().taken
	await _until(gone, "walked over and picked up", 5.0)
	_expect(gone.call(), "tap on a pile picks it up")


func _test_respawn_drops_target() -> void:
	var m: Node3D = root.get_tree().get_nodes_in_group("monster").filter(func(x: Node3D) -> bool: return x.is_alive())[0]
	m.respawn_seconds = 0.2
	m.position = player.position + Vector3(1, 0, 0)
	player.set_target(m)
	var old_spawn: int = m.spawn_id
	m.take_damage(m.hp, null)
	await _until(func() -> bool: return m.is_alive(), "monster respawned", 3.0)
	_expect(&"monster_die" in sounds, "death plays a sound")
	_expect(m.spawn_id == old_spawn + 1, "respawn gets a new spawn id")
	await _frames(2)
	_expect(player.target == null, "lock on the old life does not carry over")
