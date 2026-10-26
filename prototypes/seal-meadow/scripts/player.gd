extends Node3D
## The player's warrior: click-to-move or WASD, auto-attacks a locked target, levels up from monster XP.
## Sweep (範圍揮砍, D07): hits every monster within sweep_radius; costs AP, has a cooldown, and moving
## during the windup cancels it without spending anything. Hits go through Combat.
## Stands on TerrainHeight; trees, rocks and the pond push it out (Meadow.blockers()).

signal stats_changed
signal message(text: String, color: Color)
signal leveled_up(new_level: int)
## The sweep resolved (after its windup), hitting `hits` monsters.
signal swept(hits: int)

const TerrainHeight = preload("res://scripts/terrain_height.gd")
const Fx = preload("res://scripts/fx.gd")
const Inventory = preload("res://scripts/inventory.gd")
const Items = preload("res://scripts/items.gd")
const Quests = preload("res://scripts/quests.gd")
const Tutorial = preload("res://scripts/tutorial.gd")
const PetCare = preload("res://addons/proto_kit/pet_care.gd")
const PetRules = preload("res://scripts/pet_rules.gd")
const Refine = preload("res://scripts/refine.gd")

@export var player_name: String = "你"
@export var move_speed: float = 5.0
@export var base_hp: int = 120
@export var base_attack: int = 12
@export var attack_range: float = 1.8
@export var attack_interval: float = 0.8
@export var bounds_radius: float = 60.0
## Centre (x, z) of the walkable area of the current zone; Main sets it when travelling.
var bounds_center := Vector2.ZERO
@export var respawn_seconds: float = 3.0
## XP needed to leave level L: round(xp_base * L ^ xp_exponent).
@export var xp_base: float = 100.0
@export var xp_exponent: float = 1.8
@export_group("Sweep")
@export var max_ap: int = 100
@export var sweep_cost: int = 30
@export var sweep_cooldown: float = 5.0
@export var sweep_radius: float = 2.5
@export var sweep_multiplier: float = 1.3
@export var sweep_windup: float = 0.25
@export var ap_regen_idle: float = 5.0
@export var ap_regen_combat: float = 2.0

@onready var actor: Node3D = $Actor

var level: int = 1
var max_hp: int = 120
var hp: float = 120.0
var attack_power: int = 12
var xp: int = 0
var target: Node3D = null
var dead: bool = false
## Camera yaw (radians), so WASD moves relative to the screen.
var cam_yaw: float = 0.0
## Vector3(x, z, radius) circles the player cannot enter.
var blockers: Array[Vector3] = []
var combat: Node
var ap: float = 100.0
## Seconds until the sweep is ready again.
var sweep_left: float = 0.0
var casting: bool = false
var bag := Inventory.new(12)
var gold: int = 0
var quests := Quests.new()
var tutorial := Tutorial.new()
## Item id -> refine level (+0 .. +6), see refine.gd.
var refine := {}
var pet_rng := RandomNumberGenerator.new()
var pet := PetCare.new(PetRules.OPTIONS, pet_rng)
## slot -> item id ("" = empty). Equipment adds its atk/hp in _recalc().
var equipped := {"weapon": "", "body": ""}

var _goal: Vector3
var _has_goal: bool = false
var _cooldown: float = 0.0
var _since_hit: float = 99.0
var _spawn: Vector3
var _cast_id: int = 0
var _target_spawn: int = -1


func _ready() -> void:
	pet_rng.randomize()
	add_to_group("player")
	_spawn = position
	_recalc()
	hp = max_hp
	actor.display_name = player_name
	_snap()


func xp_to_next() -> int:
	return xp_for_level(level)


func xp_for_level(l: int) -> int:
	return roundi(xp_base * pow(l, xp_exponent))


func _recalc() -> void:
	max_hp = base_hp + (level - 1) * 18
	attack_power = base_attack + (level - 1) * 4
	for slot: String in equipped:
		var id: String = equipped[slot]
		if id != "":
			var plus := Refine.bonus(slot, refine.get(id, 0))
			max_hp += int(Items.ALL[id].get("hp", 0)) + int(plus.get("hp", 0))
			attack_power += int(Items.ALL[id].get("atk", 0)) + int(plus.get("atk", 0))
	var pet_bonus := pet.stats()
	max_hp += int(pet_bonus.get("hp", 0))
	attack_power += int(pet_bonus.get("atk", 0))
	hp = minf(hp, max_hp)
	_dress()


func refresh_stats() -> void:
	_recalc()
	stats_changed.emit()


## Feeds one of `id` from the bag. Returns "" or why not: none, not_food.
func feed_pet(id: String, result: Dictionary = {}) -> String:
	if not Items.ALL.get(id, {}).has("pet"):
		return "not_food"
	if not bag.remove(id, 1):
		return "none"
	result.merge(pet.feed({"id": id, "price": Items.ALL[id].pet}), true)
	refresh_stats()
	return ""


## Tries the pet's evolution with the recipe's materials from the bag (used up either way).
## Returns "" or why not: not_ready, materials. On "", result has ok and type.
func evolve_pet(result: Dictionary = {}) -> String:
	if not pet.can_evolve():
		return "not_ready"
	var mats: Array = PetRules.RECIPES[0].materials
	var trial = bag.duplicate_bag()
	for m: String in mats:
		if not trial.remove(m, 1):
			return "materials"
	bag.slots = trial.slots
	result.merge(pet.evolve(mats, PetRules.RECIPES), true)
	refresh_stats()
	return ""


## Shows what is worn on the paper doll.
func _dress() -> void:
	if not is_node_ready():
		return
	for slot: String in equipped:
		var id: String = equipped[slot]
		var path: String = Items.ALL[id].get("sheet", "") if id != "" else Items.EMPTY_SHEET[slot]
		actor.set_layer(Items.LAYER[slot], load(path) if path != "" else null)


## Wears an item from the bag; the one it replaces goes back into the bag. All or nothing.
## Returns "" or why not: none, not_equipment, bag_full.
func equip(id: String) -> String:
	if bag.count(id) < 1:
		return "none"
	var slot: String = Items.ALL[id].get("slot", "")
	if slot == "":
		return "not_equipment"
	var trial = bag.duplicate_bag()
	trial.remove(id, 1)
	if equipped[slot] != "" and not trial.add(equipped[slot], 1):
		return "bag_full"
	bag.slots = trial.slots
	equipped[slot] = id
	_recalc()
	stats_changed.emit()
	return ""


func unequip(slot: String) -> String:
	if equipped.get(slot, "") == "":
		return "none"
	if not bag.add(equipped[slot], 1):
		return "bag_full"
	equipped[slot] = ""
	_recalc()
	stats_changed.emit()
	return ""


## Uses one consumable (heal). Returns "" or why not: none, not_usable, dead, full_hp.
func use_item(id: String) -> String:
	if dead:
		return "dead"
	if not Items.ALL.get(id, {}).has("heal"):
		return "not_usable"
	if hp >= max_hp:
		return "full_hp"
	if not bag.remove(id, 1):
		return "none"
	hp = minf(max_hp, hp + max_hp * Items.ALL[id].heal)
	actor.hp_ratio = hp / max_hp
	stats_changed.emit()
	return ""


func _process(delta: float) -> void:
	if dead:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	sweep_left = maxf(0.0, sweep_left - delta)
	_since_hit += delta
	var in_combat: bool = _since_hit < 5.0 or is_instance_valid(target)
	ap = minf(max_ap, ap + (ap_regen_combat if in_combat else ap_regen_idle) * delta)
	if _since_hit > 5.0 and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.04 * delta)
		actor.hp_ratio = hp / max_hp
		stats_changed.emit()

	var dir := Vector3.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length() > 0.1:
		cancel_cast()
		_has_goal = false
		target = null
		dir = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, cam_yaw).normalized()
	elif casting:
		pass
	elif is_instance_valid(target) and target.is_alive():
		var to := target.position - position
		to.y = 0.0
		if to.length() > attack_range:
			dir = to.normalized()
		else:
			actor.face(to)
			_try_attack()
	elif _has_goal:
		var to := _goal - position
		to.y = 0.0
		if to.length() < 0.25:
			_has_goal = false
		else:
			dir = to.normalized()
	if target != null and not (is_instance_valid(target) and target.is_alive() and target.spawn_id == _target_spawn):
		target = null

	if dir != Vector3.ZERO:
		position += dir * move_speed * delta
		_push_out()
		actor.face(dir)
	_snap()
	actor.moving = dir != Vector3.ZERO


func save_data() -> Dictionary:
	return {"level": level, "xp": xp, "x": position.x, "z": position.z, "bag": bag.to_data(),
		"gold": gold, "equipped": equipped.duplicate(), "quests": quests.to_data(), "tutorial": tutorial.step,
		"refine": refine.duplicate(), "pet": pet.to_dict()}


func load_data(data: Dictionary) -> void:
	level = maxi(1, int(data.get("level", 1)))
	xp = maxi(0, int(data.get("xp", 0)))
	position.x = float(data.get("x", position.x))
	position.z = float(data.get("z", position.z))
	bag.load_data(data.get("bag", []))
	gold = maxi(0, int(data.get("gold", 0)))
	quests.load_data(data.get("quests", {}))
	tutorial.step = clampi(int(data.get("tutorial", 0)), 0, Tutorial.STEPS.size())
	refine.clear()
	var saved_refine: Dictionary = data.get("refine", {})
	for id: String in saved_refine:
		if Items.ALL.has(id):
			refine[id] = clampi(int(saved_refine[id]), 0, Refine.max_level())
	if data.get("pet") is Dictionary:
		pet.from_dict(data.pet)
	var worn: Dictionary = data.get("equipped", {})
	for slot: String in equipped:
		var id: String = worn.get(slot, "")
		equipped[slot] = id if Items.ALL.has(id) and Items.ALL[id].get("slot", "") == slot else ""
	_push_out()
	_snap()
	_recalc()
	hp = max_hp
	actor.hp_ratio = 1.0
	stats_changed.emit()


func move_to(point: Vector3) -> void:
	if dead:
		return
	cancel_cast()
	_goal = point
	_has_goal = true
	target = null


func is_alive() -> bool:
	return not dead


## Starts the sweep. Returns "" when it started, else why not: dead, casting, cooldown, ap.
func use_sweep() -> String:
	var reason := ""
	if dead:
		reason = "dead"
	elif casting:
		reason = "casting"
	elif sweep_left > 0.0:
		reason = "cooldown"
	elif ap < sweep_cost:
		reason = "ap"
	if reason != "":
		return reason
	_cast_id += 1
	casting = true
	_has_goal = false
	actor.attack()
	_finish_sweep(_cast_id)
	return ""


func cancel_cast() -> void:
	casting = false


func _finish_sweep(id: int) -> void:
	await get_tree().create_timer(sweep_windup, false).timeout
	if not casting or id != _cast_id or dead:
		return
	casting = false
	ap -= sweep_cost
	sweep_left = sweep_cooldown
	var hits := 0
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		if m.is_alive() and Vector2(m.position.x - position.x, m.position.z - position.z).length() <= sweep_radius:
			if combat.attack(self, m, attack_power, sweep_multiplier) > 0:
				hits += 1
	Fx.ring(get_parent(), position, sweep_radius, Color(0.62, 0.85, 1.0, 0.8))
	swept.emit(hits)
	message.emit("範圍揮砍命中 %d 隻。" % hits if hits > 0 else "範圍揮砍沒有打到怪。", Color("9fd8ff"))
	stats_changed.emit()


func set_target(monster: Node3D) -> void:
	if dead or not monster.is_alive():
		return
	target = monster
	_target_spawn = monster.spawn_id
	_has_goal = false


func attack_nearest(max_distance: float = 9.0) -> void:
	var best: Node3D = null
	var best_d := max_distance
	for m: Node3D in get_tree().get_nodes_in_group("monster"):
		var d := m.position.distance_to(position)
		if m.is_alive() and d < best_d:
			best = m
			best_d = d
	if best != null:
		set_target(best)


func _try_attack() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = attack_interval
	actor.attack()
	var victim := target
	await get_tree().create_timer(0.18, false).timeout
	if dead or not is_instance_valid(victim) or not victim.is_alive():
		return
	combat.attack(self, victim, attack_power)


func take_damage(amount: int, _from: Node3D = null, _crit: bool = false) -> void:
	if dead:
		return
	hp -= amount
	_since_hit = 0.0
	actor.hurt()
	actor.hp_ratio = clampf(hp / max_hp, 0.0, 1.0)
	Fx.popup(get_parent(), position + Vector3.UP * 1.9, str(amount), Color("ff6b6b"))
	if hp <= 0.0:
		hp = 0.0
		_die()
	stats_changed.emit()


func gain_xp(amount: int, from_name: String) -> void:
	xp += amount
	message.emit("打倒了 %s，獲得 %d 點經驗值。" % [from_name, amount], Color("e6edf7"))
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_recalc()
		hp = max_hp
		message.emit("等級提升！現在是 Lv %d（生命 %d、攻擊 %d）" % [level, max_hp, attack_power], Color("ffd75e"))
		Fx.popup(get_parent(), position + Vector3.UP * 2.3, "LEVEL UP!", Color("ffd75e"), 64)
		leveled_up.emit(level)
	actor.hp_ratio = hp / max_hp
	stats_changed.emit()


func _die() -> void:
	dead = true
	casting = false
	target = null
	_has_goal = false
	actor.moving = false
	actor.set_dead(true)
	message.emit("你倒下了……%d 秒後在路牌旁復活。" % int(respawn_seconds), Color("ff8a8a"))
	await get_tree().create_timer(respawn_seconds, false).timeout
	position = _spawn
	_snap()
	hp = max_hp
	actor.hp_ratio = 1.0
	actor.set_dead(false)
	dead = false
	stats_changed.emit()


func _push_out() -> void:
	var p := Vector2(position.x, position.z)
	for b in blockers:
		var c := Vector2(b.x, b.y)
		var d := p.distance_to(c)
		if d < b.z:
			p = c + (p - c).normalized() * b.z if d > 0.001 else c + Vector2(b.z, 0.0)
	p = bounds_center + (p - bounds_center).limit_length(bounds_radius)
	position.x = p.x
	position.z = p.y


func _snap() -> void:
	position.y = TerrainHeight.height(position.x, position.z)
