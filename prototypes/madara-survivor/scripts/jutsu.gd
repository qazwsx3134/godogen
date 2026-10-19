class_name Jutsu
extends Node3D
## Madara's learned jutsu and their levels, cast automatically on game time. Main keeps this node on the player.
## The design (docs/naruto/skill-progression.md): Madara is strong from the first second; what grows is the number
## of moves, their size and how they behave. Every level shows on screen.
##   TAIJUTSU  starting move: a three-hit combo at close range; the third kick launches a body into the crowd
##   GUNBAI    a 120-degree war-fan cone with a big knockback
##   SHARINGAN reads an incoming hit: Madara slips aside and leaves an afterimage (charges recharge over time);
##             Lv3 the afterimage bursts and throws the attackers back; Lv5 Mangekyo: longer invulnerability
##   WOOD      Deep Forest Emergence: roots burst up under a crowd and bind it in place; Lv4 casts twice;
##             Lv5 the roots catch fire when Fire Release is learned (wood burns)
##   SUSANOO   an active skill (its own button): a chakra giant rises behind Madara for a while, swings huge
##             strikes on its own and takes most of the damage; each level is a bigger stage and lasts longer
##   CHIBAKU   Chibaku Tensei: not cast here; learning it gives the ultimate button (ultimate.gd)
##   FIREBALL  Great Fireball: grows from a fist-sized ball (Lv1) to one taller than two men (Lv5); Lv3 leaves
##             burning ground, Lv4 throws two, Lv5 makes burning deaths explode
## Card texts live in data/jutsu/*.tres; the numbers per level live here, where the casting is.

## A strike landed: `kind` is JutsuDef.Kind, `heavy` the combo finisher / a fireball blast (feedback scales with it).
signal struck(kind: int, hits: int, crits: int, at: Vector3, heavy: bool)
signal exploded(at: Vector3, radius: float)
## Madara strikes a key pose for a cast: &"punch", &"kick", &"fan" or &"seal" (the player shows it briefly).
signal posed(pose: StringName)
## Susanoo rose (true) or faded (false); `stage` is its level.
signal susanoo_changed(active: bool, stage: int)

@export var horde: Horde
## Enemy jutsu the Gunbai can swat back.
@export var enemy_jutsu: EnemyJutsu
@export var fx: Fx
@export var glow: GlowPool
@export var starting: JutsuDef
@export var max_slots: int = 6
@export_range(0.0, 1.0) var crit_chance: float = 0.12
@export var crit_multiplier: float = 2.2
@export var fire_color: Color = Color(1.0, 0.5, 0.18)
@export var fire_core: Color = Color(1.0, 0.85, 0.4)

## Multipliers from passive upgrades (main sets them).
var might: float = 1.0
var area: float = 1.0
var haste: float = 1.0
var crit_bonus: float = 0.0
## The direction of the last strike (x, z); the player turns to face it.
var aim := Vector2.RIGHT

var owned: Array[JutsuDef] = []
var levels := PackedInt32Array()

var _timers := PackedFloat32Array()
var _combo: int = 0
var _combo_reset: float = 0.0
var _tai_show: float = 99.0
var _fan_show: float = 99.0

var _ball_pos := PackedVector2Array()
var _ball_dir := PackedVector2Array()
var _ball_left := PackedFloat32Array()
var _ball_level := PackedInt32Array()
var _zone_pos := PackedVector2Array()
var _zone_r := PackedFloat32Array()
var _zone_left := PackedFloat32Array()
var _zone_tick := PackedFloat32Array()

# Per level (index = level - 1).
const TAI_COOLDOWN := [0.42, 0.34, 0.34, 0.32, 0.3]
const TAI_RADIUS := [2.3, 2.3, 2.9, 2.9, 3.1]
const TAI_KICK_PUSH := [20.0, 20.0, 22.0, 22.0, 30.0]
const FAN_RADIUS := [4.2, 4.6, 5.0, 5.4, 6.0]
const FAN_DAMAGE := [26.0, 32.0, 38.0, 44.0, 52.0]
const FAN_PUSH := [22.0, 22.0, 24.0, 28.0, 30.0]
const BALL_SIZE := [0.6, 1.1, 1.7, 1.9, 3.0]
const BALL_BLAST := [1.5, 2.2, 3.0, 3.3, 4.6]
const BALL_DAMAGE := [24.0, 30.0, 36.0, 40.0, 56.0]
const BALL_COUNT := [1, 1, 1, 2, 2]
const BALL_COOLDOWN := [1.7, 1.6, 1.5, 1.4, 1.3]
const WOOD_RADIUS := [3.2, 3.8, 4.4, 4.6, 5.4]
const WOOD_BIND := [1.6, 2.0, 2.4, 2.6, 3.0]
const WOOD_COOLDOWN := [6.0, 5.5, 5.0, 5.0, 4.5]
const EYE_RECHARGE := [6.0, 4.5, 4.5, 3.5, 3.0]
const SUS_TIME := [7.0, 8.0, 9.0, 10.0, 12.0]
const SUS_COOLDOWN := [26.0, 24.0, 22.0, 20.0, 18.0]
const SUS_REACH := [6.0, 7.0, 8.0, 9.0, 11.0]
const SUS_DAMAGE := [50.0, 60.0, 75.0, 90.0, 120.0]
## How much damage Susanoo takes for Madara while it stands (fraction blocked).
const SUS_GUARD := 0.7

var susanoo_left: float = 0.0
var susanoo_cooldown: float = 0.0
var _sus_swing: float = 0.0
const EYE_CHARGES := [1, 1, 1, 2, 2]

## Sharingan dodges ready now, and the time until the next one recharges.
var eye_charges: int = 0
var _eye_recharge: float = 0.0

@onready var _tai_arc: MeshInstance3D = %TaiArc
@onready var _fan_arc: MeshInstance3D = %FanArc


func _ready() -> void:
	_tai_arc.visible = false
	_fan_arc.visible = false
	if starting:
		learn(starting)


func level_of(def: JutsuDef) -> int:
	var i: int = owned.find(def)
	return levels[i] if i >= 0 else 0


func has_free_slot() -> bool:
	return owned.size() < max_slots


## Learns `def` at level 1, or raises its level by one.
func learn(def: JutsuDef) -> void:
	var i: int = owned.find(def)
	if i >= 0:
		levels[i] = mini(levels[i] + 1, def.max_level)
		return
	owned.append(def)
	levels.append(1)
	_timers.append(0.2)
	if def.kind == JutsuDef.Kind.SHARINGAN:
		eye_charges = 1


func striking() -> bool:
	return _tai_show < 0.2 or _fan_show < 0.28


func step(dt: float) -> void:
	_step_arcs(dt)
	var at := Vector2(global_position.x, global_position.z)
	_combo_reset -= dt
	if _combo_reset <= 0.0:
		_combo = 0
	for s: int in owned.size():
		_timers[s] -= dt
		if _timers[s] > 0.0:
			continue
		var level: int = levels[s]
		match owned[s].kind:
			JutsuDef.Kind.TAIJUTSU:
				_timers[s] = _taijutsu(at, level)
			JutsuDef.Kind.GUNBAI:
				_timers[s] = _gunbai(at, level)
			JutsuDef.Kind.FIREBALL:
				_timers[s] = _fireball(at, level)
			JutsuDef.Kind.SHARINGAN, JutsuDef.Kind.CHIBAKU, JutsuDef.Kind.SUSANOO:
				_timers[s] = 99.0
			JutsuDef.Kind.WOOD:
				_timers[s] = _wood(at, level)
	_step_balls(dt)
	_step_zones(dt)
	_step_eye(dt)
	_step_susanoo(dt, at)


func susanoo_learned() -> bool:
	return level_of_kind(JutsuDef.Kind.SUSANOO) > 0


func susanoo_active() -> bool:
	return susanoo_left > 0.0


## 0..1 how ready the Susanoo button is (1 = can raise it now).
func susanoo_ratio() -> float:
	var level: int = level_of_kind(JutsuDef.Kind.SUSANOO)
	if level == 0:
		return 0.0
	if susanoo_left > 0.0:
		return 1.0
	return 1.0 - susanoo_cooldown / SUS_COOLDOWN[level - 1]


## Raises Susanoo. False when not learned, already up, or cooling down.
func raise_susanoo() -> bool:
	var level: int = level_of_kind(JutsuDef.Kind.SUSANOO)
	if level == 0 or susanoo_left > 0.0 or susanoo_cooldown > 0.0:
		return false
	susanoo_left = SUS_TIME[level - 1]
	_sus_swing = 0.3
	posed.emit(&"seal")
	susanoo_changed.emit(true, level)
	return true


## The fraction of an incoming hit Madara still takes (Susanoo guards most of it).
func damage_taken() -> float:
	return 1.0 - SUS_GUARD if susanoo_left > 0.0 else 1.0


func _step_susanoo(dt: float, at: Vector2) -> void:
	var level: int = level_of_kind(JutsuDef.Kind.SUSANOO)
	if level == 0:
		return
	if susanoo_left <= 0.0:
		susanoo_cooldown = maxf(susanoo_cooldown - dt, 0.0)
		return
	susanoo_left -= dt
	if susanoo_left <= 0.0:
		susanoo_cooldown = SUS_COOLDOWN[level - 1]
		susanoo_changed.emit(false, level)
		return
	_sus_swing -= dt
	if _sus_swing > 0.0:
		return
	_sus_swing = 0.9
	var reach: float = SUS_REACH[level - 1] * area
	var target: int = horde.nearest(at, reach + 1.0)
	if target < 0:
		_sus_swing = 0.2
		return
	aim = (horde.position_of(target) - at).normalized()
	var damage: float = SUS_DAMAGE[level - 1] * might
	var hits: int
	if level >= 5:
		# Perfect Susanoo: the sword sweeps all the way round.
		hits = horde.damage_circle(at, reach, damage, 30.0)
		fx.ring(global_position + Vector3(0, 0.4, 0), reach * 2.0, Color(0.7, 0.45, 1.0), 0.35)
	else:
		hits = horde.damage_cone(at, aim, reach, deg_to_rad(75.0), damage, 30.0)
	_show_arc(_fan_arc, reach, deg_to_rad(75.0) if level < 5 else PI)
	_fan_show = 0.0
	struck.emit(JutsuDef.Kind.SUSANOO, hits, 0, _front(reach * 0.5), true)


## Spends a Sharingan charge to dodge an incoming hit. False when the eye is not learned or not ready.
func try_dodge() -> bool:
	if eye_charges <= 0:
		return false
	eye_charges -= 1
	return true


## How long the invulnerability after a dodge lasts (Mangekyo at Lv5 holds it longer).
func dodge_grace() -> float:
	return 1.0 if level_of_kind(JutsuDef.Kind.SHARINGAN) >= 5 else 0.4


## Lv3+: the afterimage left behind bursts and throws back whoever swung at it.
func afterimage_burst(at: Vector3) -> void:
	if level_of_kind(JutsuDef.Kind.SHARINGAN) < 3:
		return
	horde.damage_circle(Vector2(at.x, at.z), 3.0 * area, 30.0 * might, 20.0)
	fx.ring(at + Vector3(0, 0.3, 0), 6.0 * area, Color(1.0, 0.2, 0.2), 0.3)
	fx.flash(at + Vector3(0, 1.2, 0), 2.6, Color(1.0, 0.3, 0.3))


func _step_eye(dt: float) -> void:
	var level: int = level_of_kind(JutsuDef.Kind.SHARINGAN)
	if level == 0 or eye_charges >= EYE_CHARGES[level - 1]:
		_eye_recharge = 0.0
		return
	_eye_recharge += dt
	if _eye_recharge >= EYE_RECHARGE[level - 1] / haste:
		_eye_recharge = 0.0
		eye_charges += 1


## 0..1 progress of the next Sharingan charge (for the HUD); 1 when full.
func eye_ratio() -> float:
	var level: int = level_of_kind(JutsuDef.Kind.SHARINGAN)
	if level == 0:
		return 0.0
	if eye_charges >= EYE_CHARGES[level - 1]:
		return 1.0
	return _eye_recharge / (EYE_RECHARGE[level - 1] / haste)


## Returns the time until the next try: the combo interval after a strike, a short retry with no one in reach.
func _taijutsu(at: Vector2, level: int) -> float:
	var radius: float = TAI_RADIUS[level - 1] * area
	var target: int = horde.nearest(at, radius + 0.8)
	if target < 0:
		return 0.05
	aim = (horde.position_of(target) - at).normalized()
	var finisher: bool = _combo == 2
	var damage: float = (30.0 if finisher else 22.0) * might
	var crit: bool = randf() < crit_chance + crit_bonus
	if crit:
		damage *= crit_multiplier
	var push: float = TAI_KICK_PUSH[level - 1] if finisher else 11.0
	var cone: float = deg_to_rad(70.0 if finisher else 45.0)
	var hits: int = horde.damage_cone(at, aim, radius, cone, damage, push)
	if finisher and level >= 4:
		hits += horde.damage_circle(at, radius * 1.3, 10.0 * might, 12.0)
		fx.ring(global_position + Vector3(0, 0.3, 0), radius * 2.6, Color(1.0, 0.95, 0.8), 0.3)
	_show_arc(_tai_arc, radius, cone)
	_tai_show = 0.0
	posed.emit(&"kick" if finisher else &"punch")
	_combo = (_combo + 1) % 3
	_combo_reset = 0.9
	struck.emit(JutsuDef.Kind.TAIJUTSU, hits, hits if crit else 0, _front(radius * 0.6), finisher)
	return TAI_COOLDOWN[level - 1] / haste * (1.4 if finisher else 1.0)


func _gunbai(at: Vector2, level: int) -> float:
	var radius: float = FAN_RADIUS[level - 1] * area
	var target: int = horde.nearest(at, radius + 0.8)
	if target < 0:
		return 0.05
	aim = (horde.position_of(target) - at).normalized()
	var damage: float = FAN_DAMAGE[level - 1] * might
	var crit: bool = randf() < crit_chance + crit_bonus
	if crit:
		damage *= crit_multiplier
	var hits: int = horde.damage_cone(at, aim, radius, deg_to_rad(60.0), damage, FAN_PUSH[level - 1])
	if enemy_jutsu:
		# Uchiha Counter: the fan swats enemy fire and water back at the army.
		enemy_jutsu.reflect_cone(at, aim, radius * 1.15, deg_to_rad(70.0))
	if level >= 5:
		# A gust follows the swing: a wider, weaker push.
		hits += horde.damage_cone(at, aim, radius * 1.5, deg_to_rad(75.0), 8.0 * might, 14.0)
	_show_arc(_fan_arc, radius, deg_to_rad(60.0))
	_fan_show = 0.0
	posed.emit(&"fan")
	struck.emit(JutsuDef.Kind.GUNBAI, hits, hits if crit else 0, _front(radius * 0.55), true)
	return 1.1 / haste


func _wood(at: Vector2, level: int) -> float:
	var target: int = horde.nearest(at, 11.0)
	if target < 0:
		return 0.3
	var casts: int = 2 if level >= 4 else 1
	posed.emit(&"seal")
	for c: int in casts:
		var center: Vector2 = horde.position_of(target) if c == 0 else at + (horde.position_of(target) - at).rotated(PI)
		var radius: float = WOOD_RADIUS[level - 1] * area
		horde.bind_circle(center, radius, WOOD_BIND[level - 1], 12.0 * might)
		var burning: bool = level >= 5 and level_of_kind(JutsuDef.Kind.FIREBALL) > 0
		if burning:
			horde.damage_circle(center, radius, 4.0 * might, 0.0, 3.0)
		_roots(center, radius, burning)
	return WOOD_COOLDOWN[level - 1] / haste


func _roots(center: Vector2, radius: float, burning: bool) -> void:
	var at := Vector3(center.x, 0.1, center.y)
	fx.ring(at, radius * 2.0, Color(0.45, 0.85, 0.35), 0.5)
	fx.dust_burst(at, 8, radius * 1.2, 1.2, Color(0.55, 0.42, 0.28, 0.8))
	# Roots spearing up through the crowd.
	for k: int in 10:
		var o: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
		var p := Vector3(center.x + o.x, 0.4, center.y + o.y)
		fx.spark(p + Vector3(0, 0.5, 0), Color(0.5, 0.8, 0.3), 1.8)
		fx.dust(p, 0.9, Color(0.42, 0.3, 0.18, 0.9), Vector3(0, 3.5, 0), 0.6)
		if burning:
			fx.flame(p, 0.9, fire_color)


func _fireball(at: Vector2, level: int) -> float:
	var target: int = horde.nearest(at, 13.0)
	if target < 0:
		return 0.1
	var dir: Vector2 = (horde.position_of(target) - at).normalized()
	aim = dir
	posed.emit(&"seal")
	var balls: int = BALL_COUNT[level - 1]
	for b: int in balls:
		_ball_pos.append(at + dir * 0.8)
		_ball_dir.append(dir.rotated((b - (balls - 1) * 0.5) * 0.35))
		_ball_left.append(1.1)
		_ball_level.append(level)
	return BALL_COOLDOWN[level - 1] / haste


func _step_balls(dt: float) -> void:
	var i: int = 0
	while i < _ball_pos.size():
		var level: int = _ball_level[i]
		var size: float = BALL_SIZE[level - 1] * area
		var p: Vector2 = _ball_pos[i] + _ball_dir[i] * 13.0 * dt
		_ball_pos[i] = p
		_ball_left[i] -= dt
		var height: float = 0.6 + size * 0.5
		if horde.first_in(p, size * 0.45) >= 0 or _ball_left[i] <= 0.0:
			_explode(p, level)
			_remove_ball(i)
			continue
		var at := Vector3(p.x, height, p.y)
		glow.add(at, size * 1.6, fire_color, GlowPool.DOT)
		glow.add(at, size * 0.9, fire_core, GlowPool.DOT)
		if randf() < 0.5:
			fx.dust(at - Vector3(_ball_dir[i].x, 0.0, _ball_dir[i].y) * size * 0.4, size * 0.8, Color(0.35, 0.25, 0.2, 0.45), Vector3(0, 1.2, 0), 0.35)
		i += 1


func _explode(p: Vector2, level: int) -> void:
	var blast: float = BALL_BLAST[level - 1] * area
	var ignite: float = 3.0 if level >= 3 else 0.0
	var hits: int = horde.damage_circle(p, blast, BALL_DAMAGE[level - 1] * might, 14.0, ignite)
	var at := Vector3(p.x, 0.6, p.y)
	fx.flash(at + Vector3(0, 0.6, 0), blast * 1.6, fire_core)
	fx.ring(at, blast * 2.2, fire_color, 0.35)
	fx.dust_burst(at, 6, blast * 1.4, blast * 0.7, Color(0.3, 0.22, 0.18, 0.6))
	if level >= 3:
		_zone_pos.append(p)
		_zone_r.append(blast * 0.85)
		_zone_left.append(2.5 if level < 4 else 3.5)
		_zone_tick.append(0.0)
	exploded.emit(at, blast)
	struck.emit(JutsuDef.Kind.FIREBALL, hits, 0, at, true)


## Lv5: an enemy that dies burning bursts into a small fire blast (main calls this from the kill signal).
func burning_death(at: Vector3) -> void:
	if level_of_kind(JutsuDef.Kind.FIREBALL) < 5:
		return
	var p := Vector2(at.x, at.z)
	horde.damage_circle(p, 1.8 * area, 14.0 * might, 10.0, 2.0)
	fx.flash(at + Vector3(0, 0.8, 0), 2.4, fire_core)
	fx.ring(at + Vector3(0, 0.3, 0), 3.6, fire_color, 0.25)


func level_of_kind(kind: int) -> int:
	for s: int in owned.size():
		if owned[s].kind == kind:
			return levels[s]
	return 0


func _step_zones(dt: float) -> void:
	var i: int = 0
	while i < _zone_pos.size():
		_zone_left[i] -= dt
		if _zone_left[i] <= 0.0:
			_remove_zone(i)
			continue
		_zone_tick[i] -= dt
		var p: Vector2 = _zone_pos[i]
		var r: float = _zone_r[i]
		if _zone_tick[i] <= 0.0:
			_zone_tick[i] = 0.4
			horde.damage_circle(p, r, 6.0 * might, 0.0, 2.0)
		# Flames licking up across the zone.
		for k: int in 3:
			var o: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * r
			fx.flame(Vector3(p.x + o.x, 0.3, p.y + o.y), randf_range(0.5, 1.0), fire_color)
		i += 1


func _front(distance: float) -> Vector3:
	return global_position + Vector3(aim.x, 0.0, aim.y) * distance


func _show_arc(arc: MeshInstance3D, radius: float, half_angle: float) -> void:
	arc.visible = true
	arc.scale = Vector3.ONE * radius * 2.0
	arc.rotation.y = atan2(-aim.x, -aim.y)
	var material := arc.material_override as ShaderMaterial
	material.set_shader_parameter(&"half_angle", half_angle)
	material.set_shader_parameter(&"progress", 0.0)


func _step_arcs(dt: float) -> void:
	_tai_show += dt
	_fan_show += dt
	_arc_progress(_tai_arc, _tai_show, 0.2)
	_arc_progress(_fan_arc, _fan_show, 0.28)


func _arc_progress(arc: MeshInstance3D, shown: float, length: float) -> void:
	if shown >= length:
		arc.visible = false
		return
	(arc.material_override as ShaderMaterial).set_shader_parameter(&"progress", clampf(shown / length, 0.0, 1.0))


func _remove_ball(i: int) -> void:
	var last: int = _ball_pos.size() - 1
	_ball_pos[i] = _ball_pos[last]
	_ball_dir[i] = _ball_dir[last]
	_ball_left[i] = _ball_left[last]
	_ball_level[i] = _ball_level[last]
	_ball_pos.resize(last)
	_ball_dir.resize(last)
	_ball_left.resize(last)
	_ball_level.resize(last)


func _remove_zone(i: int) -> void:
	var last: int = _zone_pos.size() - 1
	_zone_pos[i] = _zone_pos[last]
	_zone_r[i] = _zone_r[last]
	_zone_left[i] = _zone_left[last]
	_zone_tick[i] = _zone_tick[last]
	_zone_pos.resize(last)
	_zone_r.resize(last)
	_zone_left.resize(last)
	_zone_tick.resize(last)
