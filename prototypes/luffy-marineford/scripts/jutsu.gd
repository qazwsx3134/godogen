class_name Jutsu
extends Node3D
## Luffy's learned moves and their levels, cast automatically on game time (docs/one-piece-marineford/README.md
## 魯夫的招式). Main keeps this node on the player. What grows is the number of moves, their size and how they
## behave; every level shows on screen.
##   PISTOL   starting move: a straight punch at the nearest enemy, the arm stretching all the way (fist streak);
##            Lv4 pierces three, Lv5 the launched body bowls the row behind it
##   GATLING  a burst of punches into a forward cone, the last one launches
##   WHIP     a 360-degree sweep kick that clears whoever is touching Luffy
##   BAZOOKA  both palms: a whole row is shoved into a wall that bowls the crowd behind it
##   GIGANT   Gear 3: every few seconds a giant fist slams the ground ahead
##   GEAR2    an active button: for a while every move is faster and Luffy steams
##   HAKI     not cast here: learning it gives the ultimate button (ultimate.gd)
## Named targets (story blockers, bosses) are struck by the same moves as the crowd: see `targets`.
## Card texts live in data/jutsu/*.tres; the numbers per level live here, where the casting is.

## A strike landed: `kind` is JutsuDef.Kind; `at` the strike point (a punch's fist), `heavy` a finisher.
signal struck(kind: int, hits: int, crits: int, at: Vector3, heavy: bool)
## Luffy strikes a pose for a cast: &"punch" or &"kick" (the player shows it briefly).
signal posed(pose: StringName)
## Gear 2 started (true) or ended (false); `level` is its level.
signal gear_changed(active: bool, level: int)

@export var horde: Horde
## Unused; kept so the saved main scene's wiring loads unchanged.
@export var enemy_jutsu: EnemyJutsu
@export var fx: Fx
@export var glow: GlowPool
@export var starting: JutsuDef
@export var max_slots: int = 6
@export_range(0.0, 1.0) var crit_chance: float = 0.12
@export var crit_multiplier: float = 2.2
@export var steam_color: Color = Color(1.0, 0.92, 0.9, 0.75)

## Multipliers from passive upgrades (main sets them).
var might: float = 1.0
var area: float = 1.0
var haste: float = 1.0
var crit_bonus: float = 0.0
## The direction of the last strike (x, z); the player turns to face it.
var aim := Vector2.RIGHT
## Named targets the moves also hit: objects with ground() -> Vector2, `radius`, take_strike(amount, push) and
## is_down() -> bool (blocker.gd). Main adds and removes them.
var targets: Array[Node] = []

var owned: Array[JutsuDef] = []
var levels := PackedInt32Array()

var gear_left: float = 0.0
var gear_cooldown: float = 0.0

var _timers := PackedFloat32Array()
var _show: float = 99.0
var _volley_left: int = 0
var _volley_tick: float = 0.0
var _volley_level: int = 1
var _volley_dir := Vector2.RIGHT
var _alternate: bool = false

# Per level (index = level - 1).
const PISTOL_COOLDOWN := [0.6, 0.45, 0.45, 0.42, 0.38]
const PISTOL_REACH := [6.0, 6.0, 8.0, 8.0, 9.0]
const PISTOL_PIERCE := [1, 1, 1, 3, 3]
const PISTOL_PUSH := [16.0, 16.0, 17.0, 18.0, 30.0]
const GATLING_COOLDOWN := [2.4, 2.2, 2.0, 1.8, 1.5]
const GATLING_REACH := [3.4, 3.4, 3.8, 4.4, 4.8]
const GATLING_HALF := [22.0, 32.0, 32.0, 36.0, 40.0]
const GATLING_PUNCHES := [5, 6, 8, 8, 10]
const WHIP_COOLDOWN := [3.0, 2.8, 2.6, 2.2, 2.0]
const WHIP_RADIUS := [2.6, 3.1, 3.1, 3.4, 3.8]
const WHIP_PUSH := [14.0, 14.0, 20.0, 20.0, 26.0]
const BAZOOKA_COOLDOWN := [4.0, 3.7, 3.4, 3.1, 2.8]
const BAZOOKA_WIDTH := [1.2, 1.7, 1.7, 2.2, 3.0]
const BAZOOKA_LENGTH := [5.0, 5.0, 6.5, 6.5, 9.0]
const GIGANT_COOLDOWN := [9.0, 8.0, 7.0, 6.0, 5.0]
const GIGANT_RADIUS := [5.0, 5.8, 5.8, 6.8, 7.6]
const GIGANT_DAMAGE := [70.0, 80.0, 90.0, 100.0, 120.0]
const GEAR_TIME := [6.0, 7.5, 7.5, 9.0, 9.0]
const GEAR_COOLDOWN := [20.0, 20.0, 17.0, 17.0, 14.0]
## Gear 2: moves come this much faster, Luffy moves this much faster (Lv5 more).
const GEAR_HASTE := 1.6
const GEAR_SPEED := [1.2, 1.2, 1.2, 1.2, 1.35]

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


func level_of_kind(kind: int) -> int:
	for i: int in owned.size():
		if owned[i].kind == kind:
			return levels[i]
	return 0


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


func striking() -> bool:
	return _show < 0.22 or _volley_left > 0


func step(dt: float) -> void:
	_step_arcs(dt)
	_step_gear(dt)
	var at := Vector2(global_position.x, global_position.z)
	var speed: float = haste * (GEAR_HASTE if gear_left > 0.0 else 1.0)
	for s: int in owned.size():
		_timers[s] -= dt
		if _timers[s] > 0.0:
			continue
		var level: int = levels[s]
		match owned[s].kind:
			JutsuDef.Kind.PISTOL:
				_timers[s] = _pistol(at, level, speed)
			JutsuDef.Kind.GATLING:
				_timers[s] = _gatling(at, level, speed)
			JutsuDef.Kind.WHIP:
				_timers[s] = _whip(at, level, speed)
			JutsuDef.Kind.BAZOOKA:
				_timers[s] = _bazooka(at, level, speed)
			JutsuDef.Kind.GIGANT:
				_timers[s] = _gigant(at, level, speed)
			_:
				_timers[s] = 99.0
	_step_volley(dt, at)


## The direction to the nearest enemy or named target within `reach`, or ZERO when there is none.
func _aim_at(at: Vector2, reach: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = reach
	var j: int = horde.nearest(at, reach)
	if j >= 0:
		best = horde.position_of(j)
		best_d = at.distance_to(best)
	for t: Node in targets:
		if t.is_down():
			continue
		var p: Vector2 = t.ground()
		var d: float = at.distance_to(p) - t.radius
		if d < best_d:
			best_d = d
			best = p
	return (best - at).normalized() if best != Vector2.INF and best != at else Vector2.ZERO


## Named targets inside a strip / a circle take the strike too. Returns how many.
func _strike_named_line(start: Vector2, dir: Vector2, length: float, half_width: float, amount: float, push: float) -> int:
	var n: int = 0
	for t: Node in targets:
		if t.is_down():
			continue
		var rel: Vector2 = t.ground() - start
		var along: float = rel.dot(dir)
		if along >= -t.radius and along <= length + t.radius and absf(rel.cross(dir)) <= half_width + t.radius:
			t.take_strike(amount, dir * push)
			n += 1
	return n


func _strike_named_circle(center: Vector2, radius: float, amount: float, push: float) -> int:
	var n: int = 0
	for t: Node in targets:
		if not t.is_down() and t.ground().distance_to(center) <= radius + t.radius:
			var away: Vector2 = t.ground() - center
			t.take_strike(amount, (away.normalized() if away.length() > 0.01 else aim) * push)
			n += 1
	return n


## Returns the time until the next try: the interval after a punch, a short retry with no one in reach.
func _pistol(at: Vector2, level: int, speed: float) -> float:
	var reach: float = PISTOL_REACH[level - 1] * area
	var dir: Vector2 = _aim_at(at, reach + 0.8)
	if dir == Vector2.ZERO:
		return 0.05
	aim = dir
	var damage: float = 28.0 * might
	var crit: bool = randf() < crit_chance + crit_bonus
	if crit:
		damage *= crit_multiplier
	var hits: int = horde.damage_line(at, aim, reach, 0.55, damage, PISTOL_PUSH[level - 1], PISTOL_PIERCE[level - 1])
	var tip: Vector2 = horde.last_hit if hits > 0 else at + aim * reach
	var named: int = _strike_named_line(at, aim, reach, 0.55, damage, PISTOL_PUSH[level - 1])
	if hits == 0 and named > 0:
		tip = at + aim * minf(reach, _nearest_named_along(at, aim, reach))
	_show = 0.0
	_alternate = not _alternate
	posed.emit(&"punch")
	struck.emit(JutsuDef.Kind.PISTOL, hits + named, (hits + named) if crit else 0, Vector3(tip.x, 0.0, tip.y), level >= 5)
	return PISTOL_COOLDOWN[level - 1] / speed


func _nearest_named_along(at: Vector2, dir: Vector2, reach: float) -> float:
	var best: float = reach
	for t: Node in targets:
		if not t.is_down():
			best = minf(best, maxf((t.ground() - at).dot(dir) - t.radius * 0.5, 0.5))
	return best


func _gatling(at: Vector2, level: int, speed: float) -> float:
	var reach: float = GATLING_REACH[level - 1] * area
	var dir: Vector2 = _aim_at(at, reach + 0.8)
	if dir == Vector2.ZERO:
		return 0.1
	aim = dir
	_volley_dir = dir
	_volley_left = GATLING_PUNCHES[level - 1]
	_volley_level = level
	_volley_tick = 0.0
	return GATLING_COOLDOWN[level - 1] / speed


## The Gatling's punches land one by one, 0.06 s apart; the last launches.
func _step_volley(dt: float, at: Vector2) -> void:
	if _volley_left <= 0:
		return
	_volley_tick -= dt
	if _volley_tick > 0.0:
		return
	_volley_tick = 0.06
	_volley_left -= 1
	var level: int = _volley_level
	var reach: float = GATLING_REACH[level - 1] * area
	var half: float = deg_to_rad(GATLING_HALF[level - 1])
	var last: bool = _volley_left == 0
	var dir: Vector2 = _volley_dir.rotated(randf_range(-half, half))
	aim = _volley_dir
	var push: float = 24.0 if last else 3.0
	var hits: int = horde.damage_cone(at, dir, reach, deg_to_rad(14.0) if not last else half, 9.0 * might, push)
	hits += _strike_named_circle(at + dir * reach * 0.6, reach * 0.5, 9.0 * might, push)
	if last:
		_show_arc(_fan_arc, reach, half)
	_show = 0.0
	posed.emit(&"punch")
	struck.emit(JutsuDef.Kind.GATLING, hits, 0, _front_at(at, dir, reach), last)


func _whip(at: Vector2, level: int, speed: float) -> float:
	var radius: float = WHIP_RADIUS[level - 1] * area
	if horde.nearest(at, radius + 0.6) < 0 and _aim_at(at, radius + 0.6) == Vector2.ZERO:
		return 0.15
	var hits: int = horde.damage_circle(at, radius, 18.0 * might, WHIP_PUSH[level - 1])
	hits += _strike_named_circle(at, radius, 18.0 * might, WHIP_PUSH[level - 1])
	_show_arc(_tai_arc, radius, PI)
	fx.ring(global_position + Vector3(0, 0.3, 0), radius * 2.0, Color(1.0, 0.95, 0.85), 0.25)
	_show = 0.0
	posed.emit(&"kick")
	struck.emit(JutsuDef.Kind.WHIP, hits, 0, global_position, level >= 3)
	return WHIP_COOLDOWN[level - 1] / speed


func _bazooka(at: Vector2, level: int, speed: float) -> float:
	var length: float = BAZOOKA_LENGTH[level - 1] * area
	var dir: Vector2 = _aim_at(at, length)
	if dir == Vector2.ZERO:
		return 0.2
	aim = dir
	var width: float = BAZOOKA_WIDTH[level - 1] * area
	var hits: int = horde.damage_line(at, aim, length, width, 30.0 * might, 30.0, 99)
	hits += _strike_named_line(at, aim, length, width, 30.0 * might, 30.0)
	_show_arc(_fan_arc, length, atan2(width, length))
	fx.flash(_front(1.2) + Vector3(0, 1.0, 0), 2.4, Color(1.0, 0.9, 0.7))
	_show = 0.0
	posed.emit(&"punch")
	struck.emit(JutsuDef.Kind.BAZOOKA, hits, 0, _front(length * 0.5), true)
	return BAZOOKA_COOLDOWN[level - 1] / speed


func _gigant(at: Vector2, level: int, speed: float) -> float:
	var dir: Vector2 = _aim_at(at, 14.0)
	if dir == Vector2.ZERO:
		return 0.5
	aim = dir
	var j: int = horde.nearest(at, 14.0)
	var center: Vector2 = horde.position_of(j) if j >= 0 else at + dir * 6.0
	var radius: float = GIGANT_RADIUS[level - 1] * area
	var hits: int = horde.damage_circle(center, radius, GIGANT_DAMAGE[level - 1] * might, 24.0)
	hits += _strike_named_circle(center, radius, GIGANT_DAMAGE[level - 1] * might, 24.0)
	var p := Vector3(center.x, 0.2, center.y)
	fx.ring(p, radius * 2.2, Color(1.0, 0.85, 0.7), 0.4)
	fx.flash(p + Vector3(0, 1.5, 0), radius * 0.8, Color(1.0, 0.9, 0.75))
	fx.dust_burst(p, 10, radius, 2.0, Color(0.85, 0.75, 0.6, 0.85))
	_show = 0.0
	posed.emit(&"punch")
	struck.emit(JutsuDef.Kind.GIGANT, hits, 0, p, true)
	return GIGANT_COOLDOWN[level - 1] / speed


func gear_learned() -> bool:
	return level_of_kind(JutsuDef.Kind.GEAR2) > 0


func gear_active() -> bool:
	return gear_left > 0.0


## 0..1 how ready the Gear 2 button is (1 = can start now or running).
func gear_ratio() -> float:
	var level: int = level_of_kind(JutsuDef.Kind.GEAR2)
	if level == 0:
		return 0.0
	if gear_left > 0.0:
		return 1.0
	return 1.0 - gear_cooldown / GEAR_COOLDOWN[level - 1]


## Luffy's move speed factor right now (Gear 2 makes him faster).
func speed_factor() -> float:
	var level: int = level_of_kind(JutsuDef.Kind.GEAR2)
	return GEAR_SPEED[level - 1] if gear_left > 0.0 and level > 0 else 1.0


## Starts Gear 2. False when not learned, already running, or cooling down.
func raise_gear() -> bool:
	var level: int = level_of_kind(JutsuDef.Kind.GEAR2)
	if level == 0 or gear_left > 0.0 or gear_cooldown > 0.0:
		return false
	gear_left = GEAR_TIME[level - 1]
	gear_changed.emit(true, level)
	return true


func _step_gear(dt: float) -> void:
	var level: int = level_of_kind(JutsuDef.Kind.GEAR2)
	if level == 0:
		return
	if gear_left <= 0.0:
		gear_cooldown = maxf(gear_cooldown - dt, 0.0)
		return
	gear_left -= dt
	if randf() < 0.5:
		fx.dust(global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.6, 1.6), randf_range(-0.3, 0.3)), 0.7,
			steam_color, Vector3(0.0, 2.2, 0.0), 0.5)
	if gear_left <= 0.0:
		gear_cooldown = GEAR_COOLDOWN[level - 1]
		gear_changed.emit(false, level)


func _front(distance: float) -> Vector3:
	return global_position + Vector3(aim.x, 0.0, aim.y) * distance


func _front_at(at: Vector2, dir: Vector2, distance: float) -> Vector3:
	return Vector3(at.x + dir.x * distance, 0.0, at.y + dir.y * distance)


func _show_arc(arc: MeshInstance3D, radius: float, half_angle: float) -> void:
	arc.visible = true
	arc.scale = Vector3.ONE * radius * 2.0
	arc.rotation.y = atan2(-aim.x, -aim.y)
	var material := arc.material_override as ShaderMaterial
	material.set_shader_parameter(&"half_angle", half_angle)
	material.set_shader_parameter(&"progress", 0.0)


func _step_arcs(dt: float) -> void:
	_show += dt
	_arc_progress(_tai_arc, _show, 0.22)
	_arc_progress(_fan_arc, _show, 0.28)


func _arc_progress(arc: MeshInstance3D, shown: float, length: float) -> void:
	if shown >= length:
		arc.visible = false
		return
	(arc.material_override as ShaderMaterial).set_shader_parameter(&"progress", clampf(shown / length, 0.0, 1.0))
