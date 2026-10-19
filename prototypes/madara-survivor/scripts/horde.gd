class_name Horde
extends MultiMeshInstance3D
## The ninja army. Enemies are not nodes: their state lives in packed arrays and all of them are drawn by this one
## MultiMesh (two draw calls: shadows and sprites), which is what lets a phone carry hundreds of them.
##
## The signature mechanic lives here: a hard enough hit LAUNCHES an enemy (alive or already dead). A launched body
## flies, tumbles and arcs, and every enemy it passes through takes collision damage and is launched in turn, down to
## `max_chain` links; a body that slams into a rock pillar takes a hit and stops. Kills count the moment hp reaches 0
## (`killed`), but the body stays in the world until its flight ends.
##
## Each frame the owner calls, in order:
##   step(dt, target, target_radius)   move, fly, push apart, touch the player; returns the contact damage
##   ...weapons hurt enemies (damage_cone, damage_circle, nearest, hurt)...
##   flush_dead()                      emits `killed` for new kills, removes bodies that have landed
##   commit()                          uploads the instance buffer
## Instance custom data is (atlas frame, flash 0..1, facing +-1, walk phase), read by sprite_billboard.gdshader;
## a tumble is written as a rotation of the instance basis around Z.

## `burning`: it died on fire (fire release Lv5 makes burning deaths explode).
signal killed(at: Vector3, def: EnemyDef, burning: bool)
signal damaged(at: Vector3, amount: float)
## A flying body hit another enemy (bowling) or a rock. Feedback only.
signal collided(at: Vector3, with_rock: bool)
## A ranged ninja casts its element at `target` (EnemyJutsu spawns the jutsu).
signal cast(element: int, from: Vector3, target: Vector2)

@export var defs: Array[EnemyDef] = []
@export var max_enemies: int = 800
## Rock pillars that block, and that flying bodies slam into. Optional.
@export var obstacles: Decor
## Spatial hash: a window of grid_cells x grid_cells cells of cell_size meters, centered on the target each frame.
@export var cell_size: float = 1.6
@export var grid_cells: int = 64
@export var separation: float = 2.6
@export var knockback_decay: float = 9.0
@export var flash_time: float = 0.12
@export var recycle_distance: float = 46.0
@export var recycle_radius: float = 28.0
@export var steps_per_meter: float = 1.3
@export_group("Launch")
## A hit whose push reaches this speed (m/s) launches the enemy instead of shoving it.
@export var launch_speed: float = 9.0
@export var launch_time: float = 0.55
## How far each link of a chain carries the speed, and how deep a chain can go.
@export var chain_carry: float = 0.72
@export var max_chain: int = 3
## Collision damage = collide_damage * (speed / launch_speed), dealt to each enemy a flying body passes through.
@export var collide_damage: float = 14.0
@export var rock_damage: float = 30.0
@export var gravity: float = 26.0
@export var launch_lift: float = 0.55
## Bowling hits allowed per frame across the horde, so a chain reaction never stalls a phone.
@export var max_collisions_per_frame: int = 160
@export_group("Burn")
## Fire damage per second while an enemy burns.
@export var burn_dps: float = 6.0

const STRIDE := 16

var count: int = 0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _hp := PackedFloat32Array()
var _kind := PackedInt32Array()
var _flash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _facing := PackedFloat32Array()
var _uid := PackedInt32Array()
var _dead := PackedByteArray()
var _deaths := PackedInt32Array()
var _fly := PackedFloat32Array()
var _chain := PackedInt32Array()
var _depth := PackedInt32Array()
var _y := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _spin_v := PackedFloat32Array()
var _burn := PackedFloat32Array()
var _announced := PackedByteArray()
var _cast := PackedFloat32Array()
var _stun := PackedFloat32Array()
var _cap := PackedByteArray()
## Chibaku Tensei: where the core hangs (x, z) and how high; captured enemies are pulled up into it.
var core := Vector3.ZERO
var _k_cast_range := PackedFloat32Array()
var _k_cast_cd := PackedFloat32Array()
var _k_element := PackedInt32Array()
## Where the enemy that touched the target this frame stood (for a dodge direction).
var touch_from := Vector2.ZERO
var _next_uid: int = 1
var _next_chain: int = 1
var _buf := PackedFloat32Array()

var _k_speed := PackedFloat32Array()
var _k_radius := PackedFloat32Array()
var _k_damage := PackedFloat32Array()
var _k_resist := PackedFloat32Array()
var _k_frame := PackedFloat32Array()
var _k_size := PackedFloat32Array()

var _cell := PackedInt32Array()
var _cnt := PackedInt32Array()
var _start := PackedInt32Array()
var _order := PackedInt32Array()
var _sum := PackedVector2Array()
var _origin := Vector2.ZERO
var _collisions: int = 0


func _ready() -> void:
	# Packed arrays are values: each one is resized in place, not through a loop variable.
	_pos.resize(max_enemies)
	_vel.resize(max_enemies)
	_hp.resize(max_enemies)
	_kind.resize(max_enemies)
	_flash.resize(max_enemies)
	_phase.resize(max_enemies)
	_facing.resize(max_enemies)
	_uid.resize(max_enemies)
	_dead.resize(max_enemies)
	_cell.resize(max_enemies)
	_order.resize(max_enemies)
	_fly.resize(max_enemies)
	_chain.resize(max_enemies)
	_depth.resize(max_enemies)
	_y.resize(max_enemies)
	_vy.resize(max_enemies)
	_spin.resize(max_enemies)
	_spin_v.resize(max_enemies)
	_burn.resize(max_enemies)
	_announced.resize(max_enemies)
	_cast.resize(max_enemies)
	_stun.resize(max_enemies)
	_cap.resize(max_enemies)
	var cells: int = grid_cells * grid_cells
	_cnt.resize(cells)
	_sum.resize(cells)
	_start.resize(cells + 1)
	_buf.resize(max_enemies * STRIDE)
	_buf.fill(0.0)
	for def: EnemyDef in defs:
		_k_speed.append(def.speed)
		_k_radius.append(def.radius)
		_k_damage.append(def.damage)
		_k_resist.append(def.knockback_resist)
		_k_frame.append(float(def.frame))
		_k_size.append(def.size)
		_k_cast_range.append(def.cast_range)
		_k_cast_cd.append(def.cast_cooldown)
		_k_element.append(def.jutsu)
	multimesh.instance_count = max_enemies
	multimesh.visible_instance_count = 0


## Adds an enemy at a ground position (x, z). Returns its index, or -1 when the horde is full.
func spawn(kind: int, at: Vector2, hp_scale: float = 1.0) -> int:
	if count >= max_enemies:
		return -1
	var i: int = count
	count += 1
	_pos[i] = at
	_vel[i] = Vector2.ZERO
	_hp[i] = defs[kind].hp * hp_scale
	_kind[i] = kind
	_flash[i] = 0.0
	_phase[i] = randf() * TAU
	_facing[i] = 1.0
	_uid[i] = _next_uid
	_next_uid += 1
	_dead[i] = 0
	_cell[i] = -1
	_fly[i] = 0.0
	_chain[i] = 0
	_depth[i] = 0
	_y[i] = 0.0
	_vy[i] = 0.0
	_spin[i] = 0.0
	_spin_v[i] = 0.0
	_burn[i] = 0.0
	_announced[i] = 0
	_stun[i] = 0.0
	_cap[i] = 0
	_cast[i] = randf_range(1.0, 2.0) + (_k_cast_cd[kind] if kind < _k_cast_cd.size() else 0.0)
	var b: int = i * STRIDE
	_buf[b + 12] = _k_frame[kind]
	return i


func alive() -> int:
	return count - _bodies()


func step(dt: float, target: Vector2, target_radius: float) -> float:
	_rebuild_grid(target)
	_collisions = 0
	var touch: float = 0.0
	var g: int = grid_cells
	var reach2: float = cell_size * cell_size
	var decay: float = exp(-knockback_decay * dt)
	var fade: float = dt / flash_time
	for i: int in count:
		_flash[i] = maxf(_flash[i] - fade, 0.0)
		if _burn[i] > 0.0:
			_burn[i] -= dt
			if _dead[i] == 0:
				_hp[i] -= burn_dps * dt
				if _hp[i] <= 0.0:
					_dead[i] = 1
					_deaths.append(i)
		if _cap[i] == 1:
			_step_captured(i, dt)
			continue
		if _fly[i] > 0.0:
			_step_flight(i, dt)
			continue
		if _dead[i] == 1:
			continue
		var p: Vector2 = _pos[i]
		var k: int = _kind[i]
		var to: Vector2 = target - p
		var dist: float = to.length()
		if dist > recycle_distance:
			_pos[i] = target + to / dist * recycle_radius
			_vel[i] = Vector2.ZERO
			continue
		var dir: Vector2 = to / dist if dist > 0.001 else Vector2.ZERO
		var move: Vector2 = dir * _k_speed[k]
		if _stun[i] > 0.0:
			# Bound by Wood Release: rooted in place, can still be hit and launched.
			_stun[i] -= dt
			move = Vector2.ZERO
		var cast_range: float = _k_cast_range[k]
		if cast_range > 0.0:
			# Casters keep their distance: hold at about 70% of their range, back off when rushed.
			if dist < cast_range * 0.6:
				move = -dir * _k_speed[k] * 0.6
			elif dist < cast_range * 0.8:
				move = Vector2.ZERO
			_cast[i] -= dt
			if _cast[i] <= 0.0 and dist < cast_range:
				_cast[i] = _k_cast_cd[k] * randf_range(0.8, 1.25)
				cast.emit(_k_element[k], Vector3(p.x, _k_size[k] * 0.6, p.y), target)
		var c: int = _cell[i]
		if c >= 0:
			var cx: int = c % g
			var cy: int = c / g
			var push := Vector2.ZERO
			for yy: int in range(maxi(cy - 1, 0), mini(cy + 2, g)):
				var row: int = yy * g
				for xx: int in range(maxi(cx - 1, 0), mini(cx + 2, g)):
					var n: int = row + xx
					var others: int = _cnt[n]
					if others == 0:
						continue
					var away: Vector2 = p - _sum[n] / others
					var d2: float = away.length_squared()
					if d2 < reach2 and d2 > 0.0001:
						push += away * (others / sqrt(d2))
			move += push.limit_length(4.0) * separation
		var reach: float = _k_radius[k] + target_radius
		if dist < reach:
			p -= dir * (reach - dist)
			if _k_damage[k] > touch:
				touch = _k_damage[k]
				touch_from = p
		var v: Vector2 = _vel[i] * decay
		_vel[i] = v
		var step_v: Vector2 = (move + v) * dt
		p += step_v
		if obstacles:
			p = obstacles.push_out(p, _k_radius[k])
		_pos[i] = p
		if absf(dir.x) > 0.2:
			_facing[i] = 1.0 if dir.x > 0.0 else -1.0
		_phase[i] += step_v.length() * steps_per_meter * TAU
	return touch


## Damages every living enemy inside the cone (apex `center`, facing `dir`, `half_angle` radians each side).
## Knockback pushes away from the apex. Returns the number of enemies hit.
func damage_cone(center: Vector2, dir: Vector2, radius: float, half_angle: float, amount: float, knockback: float) -> int:
	var hits: int = 0
	var cos_limit: float = cos(half_angle)
	for j: int in _query(center, radius + 1.0):
		var away: Vector2 = _pos[j] - center
		var d: float = away.length()
		var r: float = radius + _k_radius[_kind[j]]
		if d > r:
			continue
		# Bodies right at the apex count whatever their angle.
		if d > 0.6 and away.dot(dir) / d < cos_limit:
			continue
		var push: Vector2 = (away / d if d > 0.001 else dir).lerp(dir, 0.35).normalized()
		hurt(j, amount, push * knockback)
		hits += 1
	return hits


## Damages every living enemy whose body overlaps the circle. Returns the hit count.
func damage_circle(center: Vector2, radius: float, amount: float, knockback: float, ignite: float = 0.0) -> int:
	var hits: int = 0
	for j: int in _query(center, radius + 1.0):
		var away: Vector2 = _pos[j] - center
		var r: float = radius + _k_radius[_kind[j]]
		if away.length_squared() <= r * r:
			if ignite > 0.0:
				_burn[j] = maxf(_burn[j], ignite)
			hurt(j, amount, away.normalized() * knockback)
			hits += 1
	return hits


## The first living, grounded enemy whose body overlaps the circle, or -1 (a projectile's contact test).
func first_in(center: Vector2, radius: float) -> int:
	for j: int in _query(center, radius + 1.0):
		var r: float = radius + _k_radius[_kind[j]]
		if _pos[j].distance_squared_to(center) <= r * r:
			return j
	return -1


## Wood Release: roots every living enemy in the circle for `seconds` and deals `amount`. Returns the count.
func bind_circle(center: Vector2, radius: float, seconds: float, amount: float) -> int:
	var n: int = 0
	for j: int in _query(center, radius + 1.0):
		if _pos[j].distance_to(center) <= radius + _k_radius[_kind[j]]:
			_stun[j] = maxf(_stun[j], seconds)
			hurt(j, amount, Vector2.ZERO)
			n += 1
	return n


func is_bound(i: int) -> bool:
	return _stun[i] > 0.0


## Chibaku Tensei, first half: every living enemy within `radius` of `center` is lifted toward `core`.
func capture(center: Vector2, radius: float, core_at: Vector3) -> int:
	core = core_at
	var n: int = 0
	var r2: float = radius * radius
	for i: int in count:
		if _dead[i] == 0 and _cap[i] == 0 and _pos[i].distance_squared_to(center) <= r2:
			_cap[i] = 1
			_fly[i] = 0.0
			_spin_v[i] = randf_range(-6.0, 6.0)
			n += 1
	return n


func captured() -> int:
	var n: int = 0
	for i: int in count:
		if _cap[i] == 1:
			n += 1
	return n


## Chibaku Tensei, second half: crushes everything in the core (`amount` each) and lets the bodies rain down
## outward. Returns how many were crushed.
func crush(amount: float) -> int:
	var n: int = 0
	for i: int in count:
		if _cap[i] == 0:
			continue
		_cap[i] = 0
		n += 1
		_hp[i] -= amount
		_flash[i] = 1.0
		if _hp[i] <= 0.0 and _dead[i] == 0:
			_dead[i] = 1
			_deaths.append(i)
		var out: Vector2 = Vector2.from_angle(randf() * TAU) * randf_range(6.0, 16.0)
		_vel[i] = out
		_vy[i] = randf_range(2.0, 8.0)
		_fly[i] = 1.6
		_chain[i] = _new_chain()
		_depth[i] = max_chain
	return n


func _step_captured(i: int, dt: float) -> void:
	var p: Vector2 = _pos[i]
	var target := Vector2(core.x, core.z)
	# Spiral in: pulled toward the core, swung around it, lifted toward its height.
	var to: Vector2 = target - p
	var swirl: Vector2 = to.orthogonal().normalized() * minf(to.length(), 6.0) * 1.4
	_pos[i] = p + (to * 2.2 + swirl) * dt
	_y[i] = lerpf(_y[i], core.y - 1.0, 1.0 - exp(-2.4 * dt))
	_spin[i] += _spin_v[i] * dt


func is_burning(i: int) -> bool:
	return _burn[i] > 0.0


## Ground positions of up to `limit` burning enemies (for flame effects).
func burning_positions(limit: int) -> PackedVector3Array:
	var found := PackedVector3Array()
	for i: int in count:
		if _burn[i] > 0.0 and _dead[i] == 0:
			found.append(Vector3(_pos[i].x, _k_size[_kind[i]] * 0.5, _pos[i].y))
			if found.size() >= limit:
				break
	return found


## Index of the closest living enemy within max_distance, or -1.
func nearest(center: Vector2, max_distance: float) -> int:
	var best: int = -1
	var best_d2: float = max_distance * max_distance
	for j: int in _query(center, max_distance):
		var d2: float = _pos[j].distance_squared_to(center)
		if d2 < best_d2:
			best_d2 = d2
			best = j
	return best


## A hit. A push of launch_speed or more launches the body; a lethal hit with any push launches it too, so the
## kill flies into the crowd. `chain` / `depth` carry a bowling chain along (internal); leave them at the defaults.
func hurt(i: int, amount: float, push: Vector2, chain: int = 0, depth: int = 0) -> void:
	if _dead[i] == 1:
		return
	_hp[i] -= amount
	_flash[i] = 1.0
	var p: Vector2 = _pos[i]
	damaged.emit(Vector3(p.x, _k_size[_kind[i]] * 0.6, p.y), amount)
	var v: Vector2 = push * (1.0 - _k_resist[_kind[i]])
	var lethal: bool = _hp[i] <= 0.0
	if lethal:
		_dead[i] = 1
		_deaths.append(i)
	if v.length() >= launch_speed or (lethal and v.length() > 1.0):
		if lethal and v.length() < launch_speed:
			v = v.normalized() * launch_speed
		_launch(i, v, chain if chain > 0 else _new_chain(), depth)
	else:
		_vel[i] += v


func position_of(i: int) -> Vector2:
	return _pos[i]


func is_alive(i: int) -> bool:
	return i >= 0 and i < count and _dead[i] == 0


func is_flying(i: int) -> bool:
	return _fly[i] > 0.0


## Sum of 1/d pushes away from living enemies within `radius`: which way is safest. Used by the QA autopilot.
func threat(center: Vector2, radius: float) -> Vector2:
	var away := Vector2.ZERO
	var r2: float = radius * radius
	for i: int in count:
		if _dead[i] == 1:
			continue
		var d: Vector2 = center - _pos[i]
		var d2: float = d.length_squared()
		if d2 < r2 and d2 > 0.0001:
			away += d / d2
	return away


## Emits `killed` for this frame's kills; removes dead bodies that are no longer flying. A kill caused by a
## `killed` handler (a burning death exploding) is announced next frame, and its body stays until then.
func flush_dead() -> void:
	var batch: PackedInt32Array = _deaths
	_deaths = PackedInt32Array()
	for i: int in batch:
		_announced[i] = 1
		var p: Vector2 = _pos[i]
		killed.emit(Vector3(p.x, 0.0, p.y), defs[_kind[i]], _burn[i] > 0.0)
	var i: int = count - 1
	while i >= 0:
		if _dead[i] == 1 and _announced[i] == 1 and _fly[i] <= 0.0:
			_remove(i)
			# The body swapped into i may be on the pending list under its old index.
			var moved: int = _deaths.find(count)
			if moved >= 0:
				_deaths[moved] = i
		i -= 1


func clear() -> void:
	count = 0
	_deaths.clear()
	multimesh.visible_instance_count = 0


func commit() -> void:
	for i: int in count:
		var b: int = i * STRIDE
		var p: Vector2 = _pos[i]
		var s: float = _k_size[_kind[i]]
		var a: float = _spin[i]
		var cs: float = s * cos(a)
		var sn: float = s * sin(a)
		_buf[b] = cs
		_buf[b + 1] = -sn
		_buf[b + 3] = p.x
		_buf[b + 4] = sn
		_buf[b + 5] = cs
		_buf[b + 7] = _y[i]
		_buf[b + 10] = s
		_buf[b + 11] = p.y
		_buf[b + 13] = _flash[i]
		_buf[b + 14] = _facing[i]
		_buf[b + 15] = _phase[i]
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = count


func _new_chain() -> int:
	_next_chain += 1
	return _next_chain


func _launch(i: int, velocity: Vector2, chain: int, depth: int) -> void:
	_vel[i] = velocity
	_fly[i] = launch_time
	_chain[i] = chain
	_depth[i] = depth
	_vy[i] = velocity.length() * launch_lift
	_spin_v[i] = (1.0 if velocity.x >= 0.0 else -1.0) * -randf_range(9.0, 15.0)


func _step_flight(i: int, dt: float) -> void:
	var p: Vector2 = _pos[i]
	var v: Vector2 = _vel[i]
	p += v * dt
	_vel[i] = v * exp(-1.6 * dt)
	_vy[i] -= gravity * dt
	_y[i] = maxf(_y[i] + _vy[i] * dt, 0.0)
	_spin[i] += _spin_v[i] * dt
	_fly[i] -= dt
	var speed: float = v.length()
	var k: int = _kind[i]
	var r: float = _k_radius[k]
	# Bowling: every enemy this body passes through, once per chain.
	if _collisions < max_collisions_per_frame and speed > launch_speed * 0.4:
		for j: int in _query(p, r + 1.0):
			if j == i or _fly[j] > 0.0 or _chain[j] == _chain[i]:
				continue
			var rj: float = r + _k_radius[_kind[j]]
			var away: Vector2 = _pos[j] - p
			if away.length_squared() > rj * rj:
				continue
			_collisions += 1
			_chain[j] = _chain[i]
			var out: Vector2 = (away.normalized() + v / speed).normalized()
			var carry: float = speed * chain_carry if _depth[i] < max_chain else launch_speed * 0.5
			var pj: Vector2 = _pos[j]
			collided.emit(Vector3(pj.x, 0.8, pj.y), false)
			hurt(j, collide_damage * speed / launch_speed, out * carry, _chain[i], _depth[i] + 1)
			_vel[i] *= 0.82
			if _collisions >= max_collisions_per_frame:
				break
	# Rock pillars stop a flying body cold.
	if obstacles:
		var pushed: Vector2 = obstacles.push_out(p, r)
		if pushed != p:
			p = pushed
			collided.emit(Vector3(p.x, 1.0, p.y), true)
			if _dead[i] == 0:
				_hp[i] -= rock_damage
				_flash[i] = 1.0
				if _hp[i] <= 0.0:
					_dead[i] = 1
					_deaths.append(i)
			_vel[i] = Vector2.ZERO
			_fly[i] = minf(_fly[i], 0.12)
	_pos[i] = p
	if _fly[i] <= 0.0:
		_fly[i] = 0.0
		_y[i] = 0.0
		_vy[i] = 0.0
		_spin[i] = 0.0
		_vel[i] = Vector2.ZERO


## Living, grounded enemies in the grid cells overlapping the square of half-size `reach` around `center`.
func _query(center: Vector2, reach: float) -> PackedInt32Array:
	var found := PackedInt32Array()
	var inv: float = 1.0 / cell_size
	var g: int = grid_cells
	var x0: int = maxi(int((center.x - reach - _origin.x) * inv), 0)
	var x1: int = mini(int((center.x + reach - _origin.x) * inv), g - 1)
	var y0: int = maxi(int((center.y - reach - _origin.y) * inv), 0)
	var y1: int = mini(int((center.y + reach - _origin.y) * inv), g - 1)
	for yy: int in range(y0, y1 + 1):
		for xx: int in range(x0, x1 + 1):
			var n: int = yy * g + xx
			for o: int in range(_start[n], _start[n + 1]):
				var j: int = _order[o]
				if j < count and _dead[j] == 0 and _cap[j] == 0:
					found.append(j)
	return found


func _bodies() -> int:
	var n: int = 0
	for i: int in count:
		if _dead[i] == 1:
			n += 1
	return n


func _remove(i: int) -> void:
	var last: int = count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_hp[i] = _hp[last]
		_kind[i] = _kind[last]
		_flash[i] = _flash[last]
		_phase[i] = _phase[last]
		_facing[i] = _facing[last]
		_uid[i] = _uid[last]
		_dead[i] = _dead[last]
		_fly[i] = _fly[last]
		_chain[i] = _chain[last]
		_depth[i] = _depth[last]
		_y[i] = _y[last]
		_vy[i] = _vy[last]
		_spin[i] = _spin[last]
		_spin_v[i] = _spin_v[last]
		_burn[i] = _burn[last]
		_announced[i] = _announced[last]
		_cast[i] = _cast[last]
		_stun[i] = _stun[last]
		_cap[i] = _cap[last]
		_cell[i] = -1
		var a: int = i * STRIDE
		var b: int = last * STRIDE
		_buf[a + 12] = _buf[b + 12]
	count = last


## Counting sort of grounded enemies into cells: _start[n].._start[n + 1] indexes _order for cell n.
func _rebuild_grid(center: Vector2) -> void:
	var g: int = grid_cells
	var half: float = g * cell_size * 0.5
	_origin = center - Vector2(half, half)
	_cnt.fill(0)
	_sum.fill(Vector2.ZERO)
	var inv: float = 1.0 / cell_size
	for i: int in count:
		var p: Vector2 = _pos[i]
		var gx: int = int((p.x - _origin.x) * inv)
		var gy: int = int((p.y - _origin.y) * inv)
		if _dead[i] == 1 or gx < 0 or gy < 0 or gx >= g or gy >= g:
			_cell[i] = -1
			continue
		var c: int = gy * g + gx
		_cell[i] = c
		_cnt[c] += 1
		_sum[c] += p
	var total: int = 0
	for c: int in g * g:
		total += _cnt[c]
		_start[c] = total
	_start[g * g] = total
	for i: int in count:
		var c: int = _cell[i]
		if c >= 0:
			_start[c] -= 1
			_order[_start[c]] = i
