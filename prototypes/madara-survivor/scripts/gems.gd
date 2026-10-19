class_name Gems
extends MultiMeshInstance3D
## Experience gems on the ground: one MultiMesh, pulled in by the player's magnet and collected on touch.
## When the field is full a new drop is added to an existing gem instead, which grows a tier (the horde can drop
## thousands; the screen only ever holds max_gems).

@export var max_gems: int = 400
@export var collect_radius: float = 0.7
@export var pull_speed: float = 16.0
## XP thresholds for tiers 1, 2 and 3 (tier 0 below the first).
@export var tier_xp: PackedInt32Array = PackedInt32Array([3, 10, 30])
@export var sizes: PackedFloat32Array = PackedFloat32Array([0.45, 0.55, 0.7, 0.9])
## Atlas frame of the tier-0 chakra sprite (tiers follow it) when the material is sprite_billboard; -1 when the
## material draws the orbs itself (gem.gdshader reads the tier).
@export var frame_base: int = -1

const STRIDE := 16

var count: int = 0

var _pos := PackedVector2Array()
var _xp := PackedInt32Array()
var _pulled := PackedByteArray()
var _buf := PackedFloat32Array()


func _ready() -> void:
	_pos.resize(max_gems)
	_xp.resize(max_gems)
	_pulled.resize(max_gems)
	_buf.resize(max_gems * STRIDE)
	_buf.fill(0.0)
	multimesh.instance_count = max_gems
	multimesh.visible_instance_count = 0


func drop(at: Vector2, xp: int) -> void:
	if count >= max_gems:
		var i: int = randi() % count
		_xp[i] += xp
		_restyle(i)
		return
	_pos[count] = at
	_xp[count] = xp
	_pulled[count] = 0
	_restyle(count)
	count += 1


## Moves pulled gems toward the player, returns the XP collected this frame.
func step(dt: float, player: Vector2, magnet: float) -> int:
	var gained: int = 0
	var magnet2: float = magnet * magnet
	var collect2: float = collect_radius * collect_radius
	var i: int = 0
	while i < count:
		var p: Vector2 = _pos[i]
		var d2: float = p.distance_squared_to(player)
		if d2 <= collect2:
			gained += _xp[i]
			_remove(i)
			continue
		if _pulled[i] == 1 or d2 <= magnet2:
			_pulled[i] = 1
			_pos[i] = p.move_toward(player, pull_speed * dt)
		i += 1
	return gained


## Pulls every gem on the field (a vacuum pickup, or the end of a run).
func pull_all() -> void:
	for i: int in count:
		_pulled[i] = 1


func commit() -> void:
	for i: int in count:
		var b: int = i * STRIDE
		_buf[b + 3] = _pos[i].x
		_buf[b + 11] = _pos[i].y
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = count


func _restyle(i: int) -> void:
	var tier: int = 0
	for t: int in tier_xp.size():
		if _xp[i] >= tier_xp[t]:
			tier = t + 1
	var b: int = i * STRIDE
	var s: float = sizes[tier]
	_buf[b] = s
	_buf[b + 5] = s
	_buf[b + 10] = s
	_buf[b + 12] = float(frame_base + tier if frame_base >= 0 else tier)
	_buf[b + 14] = 1.0


func _remove(i: int) -> void:
	count -= 1
	if i == count:
		return
	_pos[i] = _pos[count]
	_xp[i] = _xp[count]
	_pulled[i] = _pulled[count]
	var a: int = i * STRIDE
	var b: int = count * STRIDE
	for k: int in STRIDE:
		_buf[a + k] = _buf[b + k]
