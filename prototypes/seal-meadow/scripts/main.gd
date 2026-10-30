extends Node3D
## Wires the field: taps/clicks pick a monster (nearest on screen) or a ground point, the HUD follows
## the player, and level/XP/position/bag are saved on every XP or bag change and when the app goes to the
## background. Dead monsters drop loot (Items.DROPS, rolled on Combat's seeded rng); tapping a pile walks
## the player over and moves it into the bag, all or nothing.
## Touch arrives as emulated mouse events (Godot's default), so one path serves phone and desktop.

const TapPicker3D = preload("res://addons/proto_kit/tap_picker_3d.gd")
const TerrainHeight = preload("res://scripts/terrain_height.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const AtomicFile = preload("res://addons/proto_kit/atomic_file.gd")
const Inventory = preload("res://scripts/inventory.gd")
const SaveValidation = preload("res://scripts/save_validation.gd")
const Items = preload("res://scripts/items.gd")
const LootDrop = preload("res://scenes/loot_drop.tscn")
const Fishing = preload("res://scripts/fishing.gd")
const SAVE_VERSION := 6
const DEFAULT_SETTINGS := {"sound": true, "large_text": false, "reduced_motion": false}
const MIGRATIONS := {
	1: "_migrate_v1",
	2: "_migrate_v2",
	3: "_migrate_v2",
	4: "_migrate_v4",
	5: "_migrate_v5",
}

@export var pick_radius_px: float = 70.0
@export var save_path: String = "user://seal_meadow/save.json"
@export var loot_pick_radius_px: float = 84.0
@export var pickup_distance: float = 1.8
@export var talk_distance: float = 2.2
@export var portal_distance: float = 1.2
@export var fishing_distance: float = 2.0
@export var meadow_radius: float = 60.0

@onready var player: Node3D = %Player
@onready var rig: Node3D = %CameraRig
@onready var hud: CanvasLayer = %HUD
@onready var meadow: Node3D = %Meadow
@onready var town: Node3D = %Town
@onready var pet_follower: Node3D = %Pet
@onready var click_marker: MeshInstance3D = %ClickMarker
@onready var clock: Node = %GameClock
@onready var combat: Node = %Combat
@onready var sfx: Node = %Sfx
@onready var time_control: Node = %TimeControl
@onready var fishing_spot: Node3D = %FishingSpot

var _holding: bool = false
var _hold_to_walk: bool = false
var _repeat: float = 0.0
var _marker_left: float = 0.0
var _saved_progress: Vector2i
var _loot_goal: Node3D = null
var _npc_goal: Node3D = null
var _portal_goal: Node3D = null:
	set(value):
		if is_instance_valid(_portal_goal):
			_portal_goal.highlighted = false
		_portal_goal = value
		if is_instance_valid(_portal_goal):
			_portal_goal.highlighted = true
var _fishing_goal: Node3D = null
var _travelling: bool = false
var save_blocked_reason: String = ""
var _recovered_backup: PackedByteArray = []
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var fishing := Fishing.new()
var _fishing_origin: Vector3 = Vector3.ZERO
## "meadow" or "town", from where the player stands.
var zone: String = "meadow"


func _ready() -> void:
	var blockers: Array[Vector3] = meadow.blockers()
	blockers.append_array(town.blockers())
	player.blockers = blockers
	player.combat = combat
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		m.blockers = blockers
		m.combat = combat
		m.died.connect(_drop_loot)
		m.died.connect(func(dead: Node3D) -> void:
			sfx.play(&"monster_die")
			var kind: String = dead.scene_file_path.get_file().get_basename()
			player.quests.on_kill(kind)
			player.collection.record_kill(kind)
			player.stats_changed.emit())
	var migrations := {}
	for v: int in MIGRATIONS:
		migrations[v] = Callable(self, MIGRATIONS[v])
	var saved: Dictionary = SaveSlots.restore(save_path, SAVE_VERSION, migrations)
	if saved.error == "" and not SaveValidation.valid(saved.data):
		var backup: Dictionary = SaveSlots.restore(save_path + ".bak", SAVE_VERSION, migrations) if saved.source == "main" else {"error": "corrupt"}
		if backup.error == "" and backup.source == "main" and SaveValidation.valid(backup.data):
			saved = {"error": "", "data": backup.data, "source": "backup"}
		else:
			saved = {"error": backup.error if backup.error in ["newer", "migration"] else "corrupt"}
	if saved.error == "":
		if saved.source == "backup":
			_recovered_backup = AtomicFile.read_bytes(save_path + ".bak")
		_set_zone(float(saved.data.get("x", 0.0)), float(saved.data.get("z", 0.0)))
		player.load_data(saved.data)
		for key: String in settings:
			settings[key] = saved.data.get("settings", {}).get(key, settings[key])
	elif saved.error != "missing":
		save_blocked_reason = saved.error
		push_warning("save not loaded: %s" % saved.error)
	_saved_progress = Vector2i(player.level, player.xp)
	hud.main = self
	pet_follower.player = player
	hud.bind(player)
	_apply_settings()
	if not save_blocked_reason.is_empty():
		hud.log_line("存檔無法讀取，已停止寫入以保護資料。", Color("ff9d8a"))
	elif not _recovered_backup.is_empty():
		hud.log_line("已從備份讀取存檔。", Color("ffd75e"))
	click_marker.visible = false
	player.stats_changed.connect(_on_stats_changed)
	player.damaged.connect(func(_attacker: Node3D) -> void: cancel_fishing("受到攻擊，釣魚已中斷。"))
	player.mounted_changed.connect(func(riding: bool) -> void:
		if riding:
			cancel_fishing("乘坐時已停止釣魚。"))
	combat.hit_landed.connect(_on_hit)
	player.swept.connect(func(hits: int) -> void:
		sfx.play(&"sweep")
		if hits >= 3 and not settings.reduced_motion:
			time_control.hit_stop(0.07))
	player.leveled_up.connect(func(_l: int) -> void: sfx.play(&"level_up", 0.0))
	hud.sweep_denied.connect(func() -> void: sfx.play(&"denied"))
	clock.backgrounded.connect(_on_backgrounded)


## v1 saves had no bag.
func _migrate_v1(data: Dictionary) -> Dictionary:
	data["bag"] = []
	return data


## v2 saves had no gold, equipment or quests, v3 no pet or refine levels; the player's defaults fill them.
func _migrate_v2(data: Dictionary) -> Dictionary:
	return data


## v5 had no persisted wardrobe choices; preserve all other fields.
func _migrate_v5(data: Dictionary) -> Dictionary:
	if not data.has("appearance"):
		data["appearance"] = {"outfit": "", "aura": ""}
	return data


## v4 attached refinement to an item type. Give every existing copy its own identity and preserve that bonus.
func _migrate_v4(data: Dictionary) -> Dictionary:
	if (data.has("refine") and not data.refine is Dictionary) \
			or (data.has("bag") and not data.bag is Array) \
			or (data.has("equipped") and not data.equipped is Dictionary):
		data["_invalid_schema"] = true
		return data
	var legacy: Dictionary = data.get("refine", {}) if data.get("refine", {}) is Dictionary else {}
	for value: Variant in legacy.values():
		if not (value is int or value is float) or not is_finite(float(value)):
			data["_invalid_schema"] = true
			return data
	var bag: Array = data.get("bag", []) if data.get("bag", []) is Array else []
	var migrated_bag: Array = []
	for entry: Variant in bag:
		if entry is Dictionary and entry.get("id", "") is String:
			var id: String = entry.get("id", "")
			if Items.ALL.has(id) and Items.ALL[id].has("slot"):
				var count: Variant = entry.get("count", 0)
				if not (count is int or count is float) or float(count) != 1.0:
					data["_invalid_schema"] = true
					return data
				migrated_bag.append(Inventory.equipment_record(id, int(legacy.get(id, 0))))
			else:
				migrated_bag.append(entry)
		else:
			migrated_bag.append(entry)
	data["bag"] = migrated_bag
	var worn: Dictionary = data.get("equipped", {}) if data.get("equipped", {}) is Dictionary else {}
	var migrated_worn := {"weapon": {}, "body": {}}
	for slot: String in migrated_worn:
		if not worn.get(slot, "") is String:
			data["_invalid_schema"] = true
			return data
		var id: String = str(worn.get(slot, ""))
		if Items.ALL.has(id) and Items.ALL[id].get("slot", "") == slot:
			migrated_worn[slot] = Inventory.equipment_record(id, int(legacy.get(id, 0)))
	data["equipped"] = migrated_worn
	data.erase("refine")
	return data


func _drop_loot(monster: Node3D) -> void:
	var drops := Items.roll(monster.drop_table, combat.rng)
	for i in drops.size():
		var pile: Node3D = LootDrop.instantiate()
		pile.setup(drops[i].id, drops[i].count)
		var a := TAU * i / maxf(1.0, drops.size()) + 0.6
		var spot: Vector3 = monster.position + Vector3(cos(a), 0.0, sin(a)) * (0.5 if drops.size() > 1 else 0.0)
		add_child(pile)
		pile.position = spot


## Moves one pile into the bag. Returns false when it is already taken or the bag cannot hold all of it.
func pickup(pile: Node3D) -> bool:
	if not is_instance_valid(pile) or pile.taken:
		return false
	var name_text: String = Items.ALL[pile.item_id].name
	if not player.bag.add(pile.item_id, pile.count):
		player.message.emit("背包已滿，撿不起 %s。" % name_text, Color("ff9d8a"))
		sfx.play(&"bag_full")
		return false
	pile.taken = true
	pile.queue_free()
	player.message.emit("撿到 %s ×%d。" % [name_text, pile.count], Color("b8f28a"))
	sfx.play(&"pickup")
	save_game()
	player.stats_changed.emit()
	return true


func _on_hit(attacker: Node3D, victim: Node3D, _amount: int, crit: bool) -> void:
	if victim == player:
		sfx.play(&"player_hurt")
	elif crit:
		sfx.play(&"crit")
		if not settings.reduced_motion:
			time_control.hit_stop(0.05)
	elif attacker == player:
		sfx.play(&"hit")


## Fades out, moves the player (and camera) to the portal's arrival point, saves, fades in.
## ponytail: both zones live in one scene far apart, so travel is a teleport; stream zones if maps grow.
func travel(portal: Node3D) -> void:
	player.set_mounted(false)
	_travelling = true
	_portal_goal = null
	_fishing_goal = null
	cancel_fishing()
	player.target = null
	player.cancel_cast()
	player.move_to(player.position)
	await hud.fade(true)
	var to: Vector3 = portal.arrival
	_set_zone(to.x, to.z)
	player.position = to
	player._has_goal = false
	player._snap()
	rig.global_position = player.global_position + Vector3.UP
	hud.log_line("來到了%s。" % ("蓬蓬村" if zone == "town" else "蓬蓬草原"), Color("9fd8ff"))
	save_game()
	await hud.fade(false)
	_travelling = false


func _set_zone(x: float, z: float) -> void:
	zone = "town" if TerrainHeight.in_town(x, z) else "meadow"
	player.bounds_center = TerrainHeight.TOWN_CENTER if zone == "town" else Vector2.ZERO
	player.bounds_radius = TerrainHeight.TOWN_HALF if zone == "town" else meadow_radius


func _flat_distance(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func save_game() -> Error:
	if not save_blocked_reason.is_empty():
		return ERR_FILE_CANT_WRITE
	if not _recovered_backup.is_empty():
		# Restore the validated backup first; SaveSlots must not back up a malformed primary over it.
		var recovery_error: Error = AtomicFile.write_bytes(save_path, _recovered_backup)
		if recovery_error != OK:
			push_warning("save recovery failed: %s" % error_string(recovery_error))
			return recovery_error
		_recovered_backup = []
	var snapshot: Dictionary = player.save_data()
	snapshot["settings"] = settings.duplicate()
	var err: Error = SaveSlots.save(save_path, snapshot, SAVE_VERSION)
	if err != OK:
		push_warning("save failed: %s" % error_string(err))
	else:
		_saved_progress = Vector2i(player.level, player.xp)
	return err


func update_setting(key: String, value: bool) -> void:
	if not settings.has(key) or settings[key] == value:
		return
	settings[key] = value
	_apply_settings()
	save_game()


func _apply_settings() -> void:
	sfx.set_enabled(settings.sound)
	hud.set_large_text(settings.large_text)


func _on_backgrounded(away: bool) -> void:
	if away:
		player.set_mounted(false)
		_holding = false
		_hold_to_walk = false
		player.pointer_moving = false
		player.cancel_cast()
		player.cancel_pending_attack()
		cancel_fishing("切到背景，釣魚已中斷。")
		save_game()


func start_fishing() -> void:
	var panel = hud.fishing_window
	if zone != "meadow" or _flat_distance(player, fishing_spot) > fishing_distance:
		panel.status.text = "請先靠近草原釣點。"
		return
	var reason: String = fishing.start(clock.now, player)
	if reason == "":
		_fishing_origin = player.global_position
	panel.status.text = "釣餌不足，可向村長購買。" if reason == "bait" else ("目前無法釣魚。" if reason != "" else "")
	panel.update_state(fishing.active, fishing.remaining(clock.now), player.bag.count(Fishing.BAIT))


func cancel_fishing(message: String = "") -> void:
	if fishing.cancel() and is_instance_valid(hud) and hud.fishing_window.visible:
		hud.fishing_window.status.text = message if not message.is_empty() else "已停止釣魚。"
		hud.fishing_window.update_state(false, 0.0, player.bag.count(Fishing.BAIT))


func _on_stats_changed() -> void:
	if Vector2i(player.level, player.xp) != _saved_progress:
		save_game()


## Shop, equipment and quest actions from the HUD go through here, so each change is saved and sounded once.
func town_action(result: String) -> void:
	if result == "":
		sfx.play(&"pickup")
		save_game()
		player.stats_changed.emit()
	else:
		sfx.play(&"denied")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed
		if event.pressed:
			_click(event.position, true)
			player.pointer_moving = _hold_to_walk
	elif event.is_action_pressed("skill"):
		hud.try_sweep()
	elif event.is_action_pressed("attack"):
		player.attack_nearest()
	elif event.is_action_pressed("toggle_time"):
		meadow.toggle_time()
	elif event.is_action_pressed("ui_cancel"):
		hud.close_top_window()


## A release may land on a HUD control and never reach _unhandled_input.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_holding = false
		_hold_to_walk = false
		player.pointer_moving = false


func _process(delta: float) -> void:
	var pet_xp_before: int = player.pet.xp
	for e: Dictionary in player.pet.tick(delta, zone == "town"):
		match e.type:
			"hungry":
				hud.log_line("寵物肚子餓了，想吃%s。" % Items.ALL[e.wants].name, Color("ffb86b"))
			"starved":
				hud.log_line("寵物餓壞了，失去 %d 點經驗。" % (pet_xp_before - player.pet.xp), Color("ff9d8a"))
				save_game()
	player.cam_yaw = rig.yaw
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		m.actor.targeted = m == player.target
	if player.dead or Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1:
		_loot_goal = null
		_npc_goal = null
		_portal_goal = null
		_fishing_goal = null
		cancel_fishing("移動時已停止釣魚。")
	if _holding and _hold_to_walk and player.target == null:  # only a ground press starts hold-to-walk
		_repeat -= delta
		if _repeat <= 0.0:
			_repeat = 0.12
			_click(get_viewport().get_mouse_position(), false)
	if _loot_goal != null:
		if not is_instance_valid(_loot_goal) or _loot_goal.taken or player.dead:
			_loot_goal = null
		elif Vector2(_loot_goal.position.x - player.position.x, _loot_goal.position.z - player.position.z).length() <= pickup_distance:
			pickup(_loot_goal)
			_loot_goal = null
	if _portal_goal != null:
		if not is_instance_valid(_portal_goal):
			_portal_goal = null
		elif player.casting or is_instance_valid(player.target) or not player._has_goal:
			# A skill or a new attack interrupts the walk; the old portal must not stay selected or travel later.
			_portal_goal = null
		elif not player.dead and not _travelling and _flat_distance(_portal_goal, player) <= portal_distance:
			travel(_portal_goal)
	if _npc_goal != null and not player.dead and _flat_distance(_npc_goal, player) <= talk_distance:
		player.move_to(player.position)
		player._has_goal = false
		_npc_goal = null
		hud.open_npc()
	if _fishing_goal != null:
		if not is_instance_valid(_fishing_goal) or player.dead:
			_fishing_goal = null
		elif _flat_distance(_fishing_goal, player) <= fishing_distance:
			player.move_to(player.position)
			player._has_goal = false
			_fishing_goal = null
			hud.open_fishing()
	if fishing.active:
		if Vector2(player.global_position.x - _fishing_origin.x, player.global_position.z - _fishing_origin.z).length() > 0.05 \
				or is_instance_valid(player.target) or player.casting:
			cancel_fishing("行動時已停止釣魚。")
	if fishing.active:
		var catch: Dictionary = fishing.poll(clock.now, player, combat.rng)
		if not catch.is_empty():
			if catch.error == "":
				save_game()
				player.stats_changed.emit()
				hud.fishing_window.status.text = "釣到了%s！" % Items.ALL[catch.item].name
			else:
				hud.fishing_window.status.text = "背包已滿，釣餌沒有消耗。" if catch.error == "bag_full" else "釣魚已中斷，釣餌沒有消耗。"
	if hud.fishing_window.visible:
		hud.fishing_window.update_state(fishing.active, fishing.remaining(clock.now), player.bag.count(Fishing.BAIT))
	_marker_left = maxf(0.0, _marker_left - delta)
	click_marker.visible = _marker_left > 0.0
	click_marker.scale = Vector3.ONE * (0.6 + _marker_left)
	click_marker.rotate_y(delta * 3.0)


func _click(screen: Vector2, allow_monster: bool) -> void:
	var cam: Camera3D = rig.camera
	if _travelling:
		return
	if allow_monster:
		_hold_to_walk = false
	_loot_goal = null
	_npc_goal = null
	_portal_goal = null
	_fishing_goal = null
	if allow_monster:
		var picked := _pick_interaction(cam, screen)
		var node: Node3D = picked.get("node")
		if node != null:
			match picked.kind:
				"loot":
					_loot_goal = node
					player.move_to(node.global_position)
				"portal":
					_portal_goal = node
					player.move_to(node.global_position)
				"npc":
					_npc_goal = node
					player.move_to(node.global_position)
				"monster":
					player.set_target(node)
				"fishing_spot":
					_fishing_goal = node
					player.move_to(node.global_position)
			return
	var hit: Variant = TapPicker3D.ground(cam, screen)
	if hit == null:
		return
	player.move_to(hit)
	if allow_monster:
		_hold_to_walk = true
		click_marker.global_position = hit + Vector3.UP * 0.05
		_marker_left = 0.5


## Compare all nearby screen targets, including the labels, so a portal cannot swallow a closer item or monster.
func _pick_interaction(cam: Camera3D, screen: Vector2) -> Dictionary:
	var best := {}
	var best_distance := INF
	for spec: Dictionary in [
		{"kind": "loot", "radius": loot_pick_radius_px, "heights": [0.35, 0.85]},
		{"kind": "portal", "radius": pick_radius_px, "heights": [0.0, 1.4]},
		{"kind": "npc", "radius": pick_radius_px, "heights": [1.0]},
		{"kind": "fishing_spot", "radius": pick_radius_px, "heights": [0.4, 1.4]},
		{"kind": "monster", "radius": pick_radius_px, "heights": []},
	]:
		for node: Node3D in get_tree().get_nodes_in_group(spec.kind):
			if spec.kind == "loot" and node.taken:
				continue
			if spec.kind == "monster" and not node.is_alive():
				continue
			var heights: Array = [node.actor.head_height * 0.5] if spec.kind == "monster" else spec.heights
			for h: float in heights:
				var point := node.global_position + Vector3.UP * h
				if cam.is_position_behind(point):
					continue
				var distance := cam.unproject_position(point).distance_to(screen)
				if distance <= spec.radius and distance < best_distance:
					best_distance = distance
					best = {"kind": spec.kind, "node": node}
	return best
