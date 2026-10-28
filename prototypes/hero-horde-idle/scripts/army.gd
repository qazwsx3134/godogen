extends MultiMeshInstance3D
## All 100 heroes in one MultiMesh (two draw calls: shadows and sprites). Reads domain/push_sim.gd every frame:
## positions, walking, HP (hurt heroes redden, hits flash), 陣亡 (lie down, greyed) and skill casts.
## Every hero has the same dark outline (rarity is not drawn in the crowd). `lighting` (stage.gd sprite_light) tints each hero by
## the coloured lights around them. Captains (setup()'s `captains`) are drawn CAPTAIN_SCALE larger. The saved scene
## holds the opening formation as an
## editor preview; step() overwrites it at runtime.

const PushSim = preload("res://domain/push_sim.gd")
const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")
const SHEETS := "res://assets/heroes/heroes.json"
const HERO_MATERIAL := preload("res://materials/heroes.tres")
const CLASS_KEYS := ["shield", "sword", "spear", "bow", "mage", "healer"]
## heroes.json rows: humans are the class keys (every race draws them until the race art is drawn).
## The outline role per rarity: dark for all, so every hero keeps a crisp silhouette and the crowd reads by class tint.
const RARITY_ROLE := [7, 7, 7, 7]
## Class tint hues and strength: shield blue, sword red, spear amber, bow green, mage violet, healer near-white.
const CLASS_HUES := [0.6, 0.01, 0.09, 0.3, 0.76, 0.12]
const CLASS_SAT := [0.32, 0.3, 0.3, 0.3, 0.32, 0.08]
const CAST_POSE := 0.6
const FALL_TIME := 0.4
const HURT_RED := Color(1.0, 0.35, 0.3)
const FALLEN_GREY := Color(0.35, 0.35, 0.4)
const CAPTAIN_SCALE := 1.35

signal fired(from: Vector3, to: Vector3, color: Color)
## A hero just fell, at their feet.
signal fell(at: Vector3)

var target := Vector3.ZERO
## (world point) -> Color multiplier; empty = unlit.
var lighting: Callable
var _sim: PushSim
var _sheets: Array = []
var _size: float = 1.0
var _tick := PackedFloat32Array()
var _shot := PackedFloat32Array()
var _flash := PackedFloat32Array()
var _prev_hp := PackedFloat32Array()
var _fell_age := PackedFloat32Array()
var _volley_t: float = 0.0
var _scale := PackedFloat32Array()


## A per-hero tint over the pale generated outfits: the class hue (so a crowd reads by class), shifted a little per
## hero so no two look the same.
static func tint(i: int, cls: int = 0) -> Color:
	var hue: float = fposmod(CLASS_HUES[cls] + (_hash(i, 3) - 0.5) * 0.08, 1.0)
	return Color.from_hsv(hue, CLASS_SAT[cls], 1.0).lerp(Color.WHITE, _hash(i, 4) * 0.3)


static func role(rarity: int) -> int:
	return RARITY_ROLE[rarity]


static func _hash(i: int, salt: int) -> float:
	return float((i * 7919 + salt * 104729) % 1009) / 1009.0


## captains: hero indexes drawn larger.
func setup(sim: PushSim, boss_target: Vector3, captains := PackedInt32Array()) -> void:
	_sim = sim
	target = boss_target
	if _sheets.is_empty():
		for key: String in CLASS_KEYS:
			_sheets.append(Sprite3DSheet.from_json(SHEETS, key))
		_size = _sheets[0].size_m()
		# The atlas grid comes from heroes.json (18 rows since the 形態 sheets), not from what the material was saved with.
		_sheets[0].apply(HERO_MATERIAL)
	var n: int = sim.cls.size()
	_tick.resize(n)
	_shot.resize(n)
	_flash.resize(n)
	_flash.fill(0.0)
	_prev_hp = sim.hp.duplicate()
	_fell_age.resize(n)
	_fell_age.fill(-1.0)
	for i: int in n:
		_tick[i] = _hash(i, 6) * 60.0
		_shot[i] = _hash(i, 7)
	_volley_t = 0.0
	_scale.resize(n)
	_scale.fill(1.0)
	for i: int in captains:
		if i >= 0 and i < n:
			_scale[i] = CAPTAIN_SCALE
	multimesh.instance_count = n


## Hero i's row of sheets: their class's human sheet (every race, until the 精靈 and 獸人 art is drawn).
func sheet_of(i: int) -> int:
	return _sim.cls[i]


func volley() -> void:
	_volley_t = CAST_POSE


## World position just over a hero's head (captain nameplates).
func head(i: int) -> Vector3:
	return _ground(i) + Vector3(0.0, _size * _scale[i] + 0.15, 0.0)


## World position of a hero's hands, where bolts start.
func hand(i: int) -> Vector3:
	return _ground(i) + Vector3(0.2, _size * 0.45, 0.0)


func step(dt: float) -> void:
	var sim := _sim
	_volley_t = maxf(_volley_t - dt, 0.0)
	var mm := multimesh
	for i: int in sim.cls.size():
		var c: int = sim.cls[i]
		_tick[i] += dt * 60.0
		if sim.hp[i] < _prev_hp[i]:
			_flash[i] = 1.0
		_prev_hp[i] = sim.hp[i]
		_flash[i] = maxf(_flash[i] - dt * 6.0, 0.0)

		var at: Vector3 = _ground(i)
		var spin: float = 0.0
		var anim: StringName = &"attack"
		var color: Color = tint(i, c)
		if not sim.alive(i):
			if _fell_age[i] < 0.0:
				_fell_age[i] = 0.0
				fell.emit(at)
			_fell_age[i] += dt
			var k: float = minf(_fell_age[i] / FALL_TIME, 1.0)
			at += Vector3(-0.5 * k, sin(k * PI) * 0.5, 0.0)
			spin = k * PI * 0.5
			anim = &"down"
			color = color * FALLEN_GREY
		else:
			_fell_age[i] = -1.0
			color = color.lerp(HURT_RED, (1.0 - sim.hp[i] / sim.max_hp[i]) * 0.7)
			if sim.phase == PushSim.Phase.MUSTER or sim.moving(i):
				anim = &"run"
			elif _volley_t > 0.0 or sim.phase == PushSim.Phase.WON \
					or (sim.cast_at[i] >= 0.0 and sim.t - sim.cast_at[i] < CAST_POSE):
				anim = &"volley"
			elif sim.fighting():
				_maybe_shoot(i, c, dt)

		if lighting.is_valid():
			color *= lighting.call(at + Vector3(0.0, _size * 0.5, 0.0))
		var drawn: Vector2i = _sheets[sheet_of(i)].cell(anim, 0, int(_tick[i]))
		var basis := Basis(Vector3.BACK, spin).scaled(Vector3.ONE * _size * _scale[i])
		mm.set_instance_transform(i, Transform3D(basis, at))
		mm.set_instance_custom_data(i, Sprite3DSheet.instance_custom(drawn.x, _flash[i], drawn.y, 0.0))
		mm.set_instance_color(i, Sprite3DSheet.instance_color(color, role(sim.rarity[i])))


func _ground(i: int) -> Vector3:
	var p: Vector2 = _sim.pos[i]
	return Vector3(p.x, 0.0, p.y)


## Bows and mages loose a bolt every so often; purely visual, the sim already counts their damage.
func _maybe_shoot(i: int, c: int, dt: float) -> void:
	if c != PushSim.BOW and c != PushSim.MAGE:
		return
	var every: float = 0.6 if _sim.stagger_t > 0.0 else 1.5
	_shot[i] += dt / every
	if _shot[i] >= 1.0:
		_shot[i] -= 1.0
		var color := Color(1.0, 0.95, 0.6) if c == PushSim.BOW else Color(0.85, 0.55, 1.0)
		fired.emit(hand(i), target, color)
