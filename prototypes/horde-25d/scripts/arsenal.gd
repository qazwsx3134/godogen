class_name Arsenal
extends Node3D
## The player's weapons and passives: owns their levels, fires them on game time, and rolls the level-up cards.
## Weapon kinds:
##   BOLT   projectiles at the nearest enemy (drawn in the GlowPool)
##   AURA   damages everything inside a ring around the player every `cooldown` seconds (%Aura shows the ring)
##   ORBIT  orbs circling the player that hit what they pass through
##   NOVA   a ring that bursts out from the player and knocks the crowd back (%Nova shows the wave)
## Main keeps it on the player's position each frame, so the aura and nova rings follow.

@export var horde: Horde
@export var glow: GlowPool
@export var fx: Fx
@export var weapon_pool: Array[WeaponDef] = []
@export var passive_pool: Array[PassiveDef] = []
@export var starting_weapon: WeaponDef
@export var max_weapons: int = 4
@export var max_passives: int = 4
## Bolts aim at enemies within this range.
@export var bolt_range: float = 16.0
@export var bolt_life: float = 1.4
@export var nova_show_time: float = 0.35
@export var base_magnet: float = 2.6

var weapons: Array[WeaponDef] = []
var weapon_levels: PackedInt32Array = PackedInt32Array()
var passives: Array[PassiveDef] = []
var passive_levels: PackedInt32Array = PackedInt32Array()

var _timers := PackedFloat32Array()
var _orbit_angle: float = 0.0
var _nova_age: float = 99.0

var _bolt_pos := PackedVector2Array()
var _bolt_dir := PackedVector2Array()
var _bolt_age := PackedFloat32Array()
var _bolt_pierce := PackedInt32Array()
var _bolt_last := PackedInt32Array()
var _bolt_weapon := PackedInt32Array()

@onready var _aura: MeshInstance3D = %Aura
@onready var _nova: MeshInstance3D = %Nova


func _ready() -> void:
	_aura.visible = false
	_nova.visible = false
	if starting_weapon:
		add_weapon(starting_weapon)


func add_weapon(def: WeaponDef) -> void:
	var i: int = weapons.find(def)
	if i >= 0:
		weapon_levels[i] = mini(weapon_levels[i] + 1, def.max_level)
		return
	weapons.append(def)
	weapon_levels.append(1)
	_timers.append(0.2)


func add_passive(def: PassiveDef) -> void:
	var i: int = passives.find(def)
	if i >= 0:
		passive_levels[i] = mini(passive_levels[i] + 1, def.max_level)
		return
	passives.append(def)
	passive_levels.append(1)


func stat(which: PassiveDef.Stat) -> float:
	var total: float = 0.0
	for i: int in passives.size():
		if passives[i].stat == which:
			total += passives[i].per_level * passive_levels[i]
	return total


func might() -> float:
	return 1.0 + stat(PassiveDef.Stat.MIGHT)


func area_scale() -> float:
	return 1.0 + stat(PassiveDef.Stat.AREA)


func cooldown_scale() -> float:
	return maxf(0.4, 1.0 - stat(PassiveDef.Stat.HASTE))


func speed_scale() -> float:
	return 1.0 + stat(PassiveDef.Stat.SPEED)


func magnet() -> float:
	return base_magnet * (1.0 + stat(PassiveDef.Stat.MAGNET))


## Up to `n` level-up choices: {"weapon": WeaponDef} or {"passive": PassiveDef}, plus "level" (the level it becomes).
func roll_options(rng: RandomNumberGenerator, n: int = 3) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for def: WeaponDef in weapon_pool:
		var i: int = weapons.find(def)
		if i >= 0 and weapon_levels[i] < def.max_level:
			pool.append({"weapon": def, "level": weapon_levels[i] + 1})
		elif i < 0 and weapons.size() < max_weapons:
			pool.append({"weapon": def, "level": 1})
	for def: PassiveDef in passive_pool:
		var i: int = passives.find(def)
		if i >= 0 and passive_levels[i] < def.max_level:
			pool.append({"passive": def, "level": passive_levels[i] + 1})
		elif i < 0 and passives.size() < max_passives:
			pool.append({"passive": def, "level": 1})
	var picked: Array[Dictionary] = []
	while picked.size() < n and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


func apply_option(option: Dictionary) -> void:
	if option.has("weapon"):
		add_weapon(option.weapon)
	elif option.has("passive"):
		add_passive(option.passive)


func step(dt: float) -> void:
	var at: Vector2 = Vector2(global_position.x, global_position.z)
	_aura.visible = false
	for w: int in weapons.size():
		var def: WeaponDef = weapons[w]
		var level: int = weapon_levels[w]
		var damage: float = def.damage_at(level) * might()
		var area: float = def.area_at(level) * area_scale()
		_timers[w] -= dt
		match def.kind:
			WeaponDef.Kind.BOLT:
				if _timers[w] <= 0.0:
					_timers[w] = _fire_bolts(w, at, def.amount_at(level), def.cooldown_at(level) * cooldown_scale())
			WeaponDef.Kind.AURA:
				_aura.visible = true
				_aura.scale = Vector3(area * 2.0, 1.0, area * 2.0)
				if _timers[w] <= 0.0:
					_timers[w] = def.cooldown_at(level) * cooldown_scale()
					horde.damage_circle(at, area, damage, def.knockback)
			WeaponDef.Kind.ORBIT:
				_orbit_angle += def.speed * dt
				var orbs: int = def.amount_at(level)
				var hit_now: bool = _timers[w] <= 0.0
				if hit_now:
					_timers[w] = def.cooldown_at(level) * cooldown_scale()
				for o: int in orbs:
					var angle: float = _orbit_angle + TAU * o / orbs
					var p: Vector2 = at + Vector2(cos(angle), sin(angle)) * area * 2.2
					glow.add(Vector3(p.x, 0.8, p.y), 0.9, def.color, GlowPool.DOT)
					if hit_now:
						horde.damage_circle(p, 0.6, damage, def.knockback)
			WeaponDef.Kind.NOVA:
				if _timers[w] <= 0.0:
					_timers[w] = def.cooldown_at(level) * cooldown_scale()
					horde.damage_circle(at, area, damage, def.knockback)
					_nova_age = 0.0
					_nova.scale = Vector3.ONE * 0.01
					_nova.set_meta(&"radius", area)
	_step_nova(dt)
	_step_bolts(dt)


func bolts_alive() -> int:
	return _bolt_pos.size()


## Returns the time until this weapon may try again: its cooldown after a shot, a short retry with no target.
func _fire_bolts(w: int, at: Vector2, amount: int, cooldown: float) -> float:
	var target: int = horde.nearest(at, bolt_range)
	if target < 0:
		return 0.15
	var aim: Vector2 = (horde.position_of(target) - at).normalized()
	var spread: float = 0.16
	for b: int in amount:
		var angle: float = (b - (amount - 1) * 0.5) * spread
		_bolt_pos.append(at)
		_bolt_dir.append(aim.rotated(angle))
		_bolt_age.append(0.0)
		_bolt_pierce.append(weapons[w].pierce)
		_bolt_last.append(0)
		_bolt_weapon.append(w)
	return cooldown


func _step_bolts(dt: float) -> void:
	var i: int = 0
	while i < _bolt_pos.size():
		var def: WeaponDef = weapons[_bolt_weapon[i]]
		var level: int = weapon_levels[_bolt_weapon[i]]
		var p: Vector2 = _bolt_pos[i] + _bolt_dir[i] * def.speed * dt
		_bolt_pos[i] = p
		_bolt_age[i] += dt
		var size: float = def.area_at(level) * area_scale()
		var hit: int = horde.hit_first(p, size * 0.35, _bolt_last[i])
		if hit >= 0:
			_bolt_last[i] = horde.uid_of(hit)
			horde.hurt(hit, def.damage_at(level) * might(), _bolt_dir[i] * def.knockback)
			_bolt_pierce[i] -= 1
		if _bolt_pierce[i] <= 0 or _bolt_age[i] >= bolt_life:
			_remove_bolt(i)
			continue
		glow.add(Vector3(p.x, 0.7, p.y), size * 0.8, def.color, GlowPool.DOT)
		i += 1


func _remove_bolt(i: int) -> void:
	var last: int = _bolt_pos.size() - 1
	_bolt_pos[i] = _bolt_pos[last]
	_bolt_dir[i] = _bolt_dir[last]
	_bolt_age[i] = _bolt_age[last]
	_bolt_pierce[i] = _bolt_pierce[last]
	_bolt_last[i] = _bolt_last[last]
	_bolt_weapon[i] = _bolt_weapon[last]
	_bolt_pos.resize(last)
	_bolt_dir.resize(last)
	_bolt_age.resize(last)
	_bolt_pierce.resize(last)
	_bolt_last.resize(last)
	_bolt_weapon.resize(last)


func _step_nova(dt: float) -> void:
	_nova_age += dt
	if _nova_age >= nova_show_time:
		_nova.visible = false
		return
	var t: float = _nova_age / nova_show_time
	var radius: float = _nova.get_meta(&"radius", 4.0)
	var d: float = radius * 2.0 * (1.0 - (1.0 - t) * (1.0 - t))
	_nova.visible = true
	_nova.scale = Vector3(d, 1.0, d)
	(_nova.material_override as ShaderMaterial).set_shader_parameter(&"progress", t)
