class_name Route
extends Node3D
## The C6 gray-box route on the Marineford plaza. Forward is -Z (screen up); the player starts at the origin.
## One height function serves the terrain mesh (tools/build_route.gd), the walkable bounds and anything that
## stands on the ground, so what you see is what blocks.
##
##   z = 30 ........ back edge
##   z = 0 ......... start
##   plaza  (floor half width `plaza_half`)
##   z = -150 ...... waypoint 1, the quake crack opens
##   bridge (floor half width `bridge_half` over a trench `trench_depth` deep)
##   z = -230 ...... Garp
##   top    (floor half width `top_half`) up to the execution platform's base at `end_z`

## Slack for deciding "on the bridge" from a stored position (float rounding of a clamped coordinate).
const EDGE_EPS := 0.01

@export var back_z: float = 30.0
@export var bridge_from: float = -150.0
@export var bridge_to: float = -230.0
@export var end_z: float = -252.0
@export var plaza_half: float = 18.0
@export var bridge_half: float = 4.5
@export var top_half: float = 22.0
@export var trench_half: float = 26.0
@export var trench_depth: float = 5.0
## Terrace step height and cliff width; pokebonk.com's plateau step is 4.6 m.
@export var step_height: float = 4.6
@export var cliff_width: float = 2.5
## Past the terrace the land drops to the frozen bay, `bay_depth` below the plaza; the siege walls stand on the seam.
@export var bay_at: float = 42.0
@export var bay_depth: float = 3.0
## Closed, the bridge is not walkable (act 4: it rises only after the Haki; until then the crack stops everyone).
@export var bridge_open: bool = true


## Floor half width at `z` (the walkable corridor, bridge included).
func floor_half(z: float) -> float:
	if z >= bridge_from:
		return plaza_half
	if z > bridge_to:
		return bridge_half
	return top_half


## Terrain height (the bridge is a separate mesh standing at 0 over the trench).
func height(x: float, z: float) -> float:
	var ax: float = absf(x)
	var in_crack: bool = z < bridge_from and z > bridge_to
	var inner: float = trench_half if in_crack else (plaza_half if z > bridge_from else top_half)
	var h: float = _ramp(ax, inner, step_height) - _ramp(ax, bay_at, step_height + bay_depth)
	if ax < trench_half + cliff_width:
		# The crack's walls along z, softened over a meter so the mesh has no vertical seam.
		var into: float = minf(bridge_from - z, z - bridge_to)
		var crack: float = clampf(into + 0.5, 0.0, 1.0) * clampf((trench_half - ax) / cliff_width + 1.0, 0.0, 1.0)
		h -= trench_depth * crack
	return h


## Moves a ground circle of radius `r` that went from `from` to `to` (x, z) back into the walkable corridor.
## From the wide floor the circle can enter the crack only through the bridge mouth: the step's segment is tested
## where it crosses the crack's edge (a radius out), so a long step (a dash, a slow frame) or a diagonal one cannot
## cut the corner; blocked, it stops on the edge and slides along it. On the bridge its sides hold. The region is
## decided once from the geometry, never by re-comparing a clamped coordinate against a border.
func clamp_move(from: Vector2, to: Vector2, r: float) -> Vector2:
	to.y = clampf(to.y, end_z + r, back_z - r)
	var near_edge: float = bridge_from + r
	var far_edge: float = bridge_to - r
	var lane: float = _lane(r)
	if from.y < near_edge and from.y > far_edge and absf(from.x) <= lane + EDGE_EPS:
		# On the bridge.
		if to.y < near_edge and to.y > far_edge:
			return Vector2(clampf(to.x, -lane, lane), to.y)
		return _on_floor(to, r, to.y >= near_edge)
	var plaza_side: bool = from.y >= (bridge_from + bridge_to) * 0.5
	var edge: float = near_edge if plaza_side else far_edge
	var crosses: bool = to.y < edge if plaza_side else to.y > edge
	if not crosses:
		return _on_floor(to, r, plaza_side)
	var t: float = clampf((edge - from.y) / (to.y - from.y), 0.0, 1.0) if to.y != from.y else 0.0
	if absf(lerpf(from.x, to.x, t)) <= lane:
		# Through the mouth onto the bridge.
		return Vector2(clampf(to.x, -lane, lane), to.y)
	return _on_floor(Vector2(to.x, edge), r, plaza_side)


## Puts a ground circle placed at `p` (a spawn, a teleport) inside the corridor, at the nearest walkable spot:
## beside the bridge that is the bridge's side or the nearer crack edge (a radius back), whichever is closer.
func clamp_point(p: Vector2, r: float) -> Vector2:
	p.y = clampf(p.y, end_z + r, back_z - r)
	var lane: float = _lane(r)
	if p.y < bridge_from + r and p.y > bridge_to - r:
		if absf(p.x) <= lane:
			return p
		var to_near: float = bridge_from + r - p.y
		var to_far: float = p.y - (bridge_to - r)
		if absf(p.x) - lane <= minf(to_near, to_far):
			return Vector2(signf(p.x) * lane, p.y)
		var plaza_side: bool = to_near < to_far
		return _on_floor(Vector2(p.x, bridge_from + r if plaza_side else bridge_to - r), r, plaza_side)
	return _on_floor(p, r, p.y >= bridge_from)


## Half width a circle's center may use on the bridge; a closed bridge has none (no position is that close).
func _lane(r: float) -> float:
	return bridge_half - r if bridge_open else -1.0e9


## Keeps x on the wide floor of one side (the plaza before the crack, the top after it).
func _on_floor(p: Vector2, r: float, plaza_side: bool) -> Vector2:
	var half: float = (plaza_half if plaza_side else top_half) - r
	return Vector2(clampf(p.x, -half, half), p.y)


func walkable(p: Vector2, margin: float = 0.0) -> bool:
	return p.y <= back_z - margin and p.y >= end_z + margin and absf(p.x) <= floor_half(p.y) - margin


## Progress along the route (meters from the start, forward positive).
func progress(p: Vector2) -> float:
	return -p.y


func _ramp(ax: float, at: float, rise: float) -> float:
	return rise * smoothstep(at, at + cliff_width, ax)
