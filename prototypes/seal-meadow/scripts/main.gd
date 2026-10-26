extends Node3D
## Wires the field: taps/clicks pick a monster (nearest on screen) or a ground point, the HUD follows
## the player, and level/XP/position/bag are saved on every XP or bag change and when the app goes to the
## background. Dead monsters drop loot (Items.DROPS, rolled on Combat's seeded rng); tapping a pile walks
## the player over and moves it into the bag, all or nothing.
## Touch arrives as emulated mouse events (Godot's default), so one path serves phone and desktop.

const TapPicker3D = preload("res://addons/proto_kit/tap_picker_3d.gd")
const TerrainHeight = preload("res://scripts/terrain_height.gd")
const SaveSlots = preload("res://addons/proto_kit/save_slots.gd")
const Items = preload("res://scripts/items.gd")
const LootDrop = preload("res://scenes/loot_drop.tscn")
const SAVE_VERSION := 4
const MIGRATIONS := {
	1: "_migrate_v1",
	2: "_migrate_v2",
	3: "_migrate_v2",
}

@export var pick_radius_px: float = 70.0
@export var save_path: String = "user://seal_meadow/save.json"
@export var loot_pick_radius_px: float = 60.0
@export var pickup_distance: float = 1.1
@export var talk_distance: float = 2.2
@export var portal_distance: float = 1.2
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

var _holding: bool = false
var _repeat: float = 0.0
var _marker_left: float = 0.0
var _saved_progress: Vector2i
var _loot_goal: Node3D = null
var _npc_goal: Node3D = null
var _portal_goal: Node3D = null
var _travelling: bool = false
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
			player.quests.on_kill(dead.scene_file_path.get_file().get_basename())
			player.stats_changed.emit())
	var migrations := {}
	for v: int in MIGRATIONS:
		migrations[v] = Callable(self, MIGRATIONS[v])
	var saved: Dictionary = SaveSlots.restore(save_path, SAVE_VERSION, migrations)
	if saved.error == "":
		_set_zone(float(saved.data.get("x", 0.0)), float(saved.data.get("z", 0.0)))
		player.load_data(saved.data)
	elif saved.error != "missing":
		push_warning("save not loaded: %s" % saved.error)
	_saved_progress = Vector2i(player.level, player.xp)
	hud.main = self
	pet_follower.player = player
	hud.bind(player)
	click_marker.visible = false
	player.stats_changed.connect(_on_stats_changed)
	combat.hit_landed.connect(_on_hit)
	player.swept.connect(func(hits: int) -> void:
		sfx.play(&"sweep")
		if hits >= 3:
			time_control.hit_stop(0.07))
	player.leveled_up.connect(func(_l: int) -> void: sfx.play(&"level_up", 0.0))
	hud.sweep_denied.connect(func() -> void: sfx.play(&"denied"))
	clock.backgrounded.connect(func(away: bool) -> void: if away: save_game())


## v1 saves had no bag.
func _migrate_v1(data: Dictionary) -> Dictionary:
	data["bag"] = []
	return data


## v2 saves had no gold, equipment or quests, v3 no pet or refine levels; the player's defaults fill them.
func _migrate_v2(data: Dictionary) -> Dictionary:
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
		time_control.hit_stop(0.05)
	elif attacker == player:
		sfx.play(&"hit")


## Fades out, moves the player (and camera) to the portal's arrival point, saves, fades in.
## ponytail: both zones live in one scene far apart, so travel is a teleport; stream zones if maps grow.
func travel(portal: Node3D) -> void:
	_travelling = true
	_portal_goal = null
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


func save_game() -> void:
	var err: Error = SaveSlots.save(save_path, player.save_data(), SAVE_VERSION)
	if err != OK:
		push_warning("save failed: %s" % error_string(err))
	_saved_progress = Vector2i(player.level, player.xp)


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
	elif event.is_action_pressed("skill"):
		hud.try_sweep()
	elif event.is_action_pressed("attack"):
		player.attack_nearest()
	elif event.is_action_pressed("toggle_time"):
		meadow.toggle_time()


func _process(delta: float) -> void:
	for e: Dictionary in player.pet.tick(delta, zone == "town"):
		match e.type:
			"hungry":
				hud.log_line("寵物肚子餓了，想吃%s。" % Items.ALL[e.wants].name, Color("ffb86b"))
			"starved":
				hud.log_line("寵物餓壞了，失去 %d 點經驗。" % e.xp_lost, Color("ff9d8a"))
				save_game()
	player.cam_yaw = rig.yaw
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		m.actor.targeted = m == player.target
	if _holding and player.target == null:  # hold the button to keep walking toward the cursor
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
	if _portal_goal != null and not player.dead and not _travelling \
			and _flat_distance(_portal_goal, player) <= portal_distance:
		travel(_portal_goal)
	if _npc_goal != null and not player.dead and _flat_distance(_npc_goal, player) <= talk_distance:
		player.move_to(player.position)
		player._has_goal = false
		_npc_goal = null
		hud.open_npc()
	_marker_left = maxf(0.0, _marker_left - delta)
	click_marker.visible = _marker_left > 0.0
	click_marker.scale = Vector3.ONE * (0.6 + _marker_left)
	click_marker.rotate_y(delta * 3.0)


func _click(screen: Vector2, allow_monster: bool) -> void:
	var cam: Camera3D = rig.camera
	if _travelling:
		return
	_loot_goal = null
	_npc_goal = null
	_portal_goal = null
	if allow_monster:
		var portal := TapPicker3D.pick_actor(cam, screen, get_tree().get_nodes_in_group("portal"), pick_radius_px)
		if portal != null:
			_portal_goal = portal
			player.move_to(portal.global_position)
			return
		var npc := TapPicker3D.pick_actor(cam, screen, get_tree().get_nodes_in_group("npc"), pick_radius_px,
				func(n: Node3D) -> Vector3: return n.global_position + Vector3.UP * 1.0)
		if npc != null:
			_npc_goal = npc
			player.move_to(npc.global_position)
			return
		var piles := get_tree().get_nodes_in_group("loot").filter(func(l: Node3D) -> bool: return not l.taken)
		var pile := TapPicker3D.pick_actor(cam, screen, piles, loot_pick_radius_px,
				func(l: Node3D) -> Vector3: return l.global_position + Vector3.UP * 0.35)
		if pile != null:
			_loot_goal = pile
			player.move_to(pile.position)
			return
		var alive := get_tree().get_nodes_in_group("monster").filter(func(m: Node3D) -> bool: return m.is_alive())
		var best := TapPicker3D.pick_actor(cam, screen, alive, pick_radius_px,
				func(m: Node3D) -> Vector3: return m.global_position + Vector3.UP * m.actor.head_height * 0.5)
		if best != null:
			player.set_target(best)
			return
	var hit: Variant = TapPicker3D.ground(cam, screen)
	if hit == null:
		return
	player.move_to(hit)
	if allow_monster:
		click_marker.global_position = hit + Vector3.UP * 0.05
		_marker_left = 0.5
