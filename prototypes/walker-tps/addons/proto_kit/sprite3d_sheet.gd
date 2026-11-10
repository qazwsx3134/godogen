extends Resource
## One character's sprite sheet for sprite3d.gdshader: which atlas cell to draw for an animation, a camera-relative
## direction and a time. Spec: skill sprite-actors-3d.
## `const Sprite3DSheet = preload("res://addons/proto_kit/sprite3d_sheet.gd")`
##
##   var sheet := Sprite3DSheet.from_json("res://assets/sprites/sheets.json", "luffy")   # tools/sprite_atlas.py output
##   sheet.apply(material)                                     # atlas, grid and foot strip into a sprite3d material
##   var angle := Sprite3DSheet.view_angle(facing, camera.global_basis)
##   dir = sheet.direction(angle, dir)                         # keep `dir` per actor: it carries the hysteresis
##   var drawn := sheet.cell(&"walk", dir, ticks)              # Vector2i(cell, facing): facing -1 = mirrored row
##   multimesh.set_instance_custom_data(i, Sprite3DSheet.instance_custom(drawn.x, flash, drawn.y, phase))
##   multimesh.set_instance_color(i, Sprite3DSheet.instance_color(Color.WHITE, Sprite3DSheet.ROLE_ELITE))
##
## Directions are counted from the camera, not the world: 0 faces the camera, then clockwise as seen from above
## (8 directions: 1 front-right, 2 right, 3 back-right, 4 back, 5 back-left, 6 left, 7 front-left; 4 directions:
## front, right, back, left). With `mirror` only the camera-right half is drawn (8: rows front, front-right, right,
## back-right, back; 4: front, right, back) and the left half is those rows flipped. One direction with `mirror`
## means one row drawn facing right, flipped when the actor faces screen left.
##
## An animation is a block of cells: `cell` is its first cell, its frames run left to right and its stored direction
## rows top to bottom (cell + row * columns + frame). `d` is how many ticks (1/60 s of game time) each frame stays.

const ROLE_NONE := 0
const ROLE_PLAYER := 1
const ROLE_ELITE := 2
const ROLE_BOSS := 3
const ROLE_ALLY := 4

@export var atlas: Texture2D
## Atlas grid.
@export var columns: int = 1
@export var rows: int = 1
@export var cell_px: int = 96
## Transparent strip under the feet in every cell (px), cut off by the shader so the feet touch the ground.
@export var foot_px: int = 4
## World size of one source pixel; the same for every character of a game (pokebonk.com 0.074).
@export var meters_per_px: float = 0.025
@export_enum("1:1", "4:4", "8:8") var directions: int = 8
@export var mirror: bool = true
## name -> {"cell": int, "n": int, "d": Array (ticks per frame), "loop": bool}
@export var anims: Dictionary = {}
## Degrees past a border before the direction changes, so an actor facing along a border does not flicker.
@export var hysteresis: float = 6.0


## Camera-relative angle (degrees, 0..360) of a world-space facing: 0 = toward the camera, 90 = screen right.
## Cameras without roll. Looking straight down, the camera's forward has no ground direction, so screen up stands in.
static func view_angle(facing: Vector3, camera_basis: Basis) -> float:
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(camera_basis.y.x, 0.0, camera_basis.y.z)
	forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)  # forward turned 90 degrees clockwise seen from above
	var d := Vector3(facing.x, 0.0, facing.z)
	if d.length_squared() < 0.000001:
		return 0.0
	d = d.normalized()
	return fposmod(rad_to_deg(atan2(d.dot(right), -d.dot(forward))), 360.0)


## Directions an actor can show: `directions`, or 2 (right, flipped left) for one row with `mirror`.
func logical_count() -> int:
	return 2 if directions == 1 and mirror else directions


## Direction index for a camera-relative angle. Pass the actor's previous index to keep it until the angle is
## `hysteresis` degrees past the border; -1 for a fresh pick.
func direction(angle: float, previous: int = -1) -> int:
	var count := logical_count()
	if count <= 1:
		return 0
	var sector := 360.0 / count
	var offset := 90.0 if count == 2 else 0.0
	if previous >= 0 and previous < count:
		var diff := wrapf(angle - (previous * sector + offset), -180.0, 180.0)
		if absf(diff) <= sector * 0.5 + hysteresis:
			return previous
	return posmod(roundi((angle - offset) / sector), count)


## The animation actually played for a name: itself, else "walk", else the first one; {} when there are none.
## cell() and an actor's finished() both go through this, so they agree on what is on screen.
func resolve(anim: StringName) -> Dictionary:
	var a := _anim(String(anim))
	if a.is_empty():
		a = _anim("walk")
	if a.is_empty() and not anims.is_empty():
		a = anims.values()[0]
	return a


## The cell to draw and the facing to give the shader: Vector2i(cell, 1), or Vector2i(cell, -1) for a mirrored row.
## A missing animation plays resolve()'s fallback; with no animations at all, cell 0.
func cell(anim: StringName, dir: int, tick: int) -> Vector2i:
	var a := resolve(anim)
	var row := dir
	var flip := false
	if logical_count() == 2 and directions == 1:
		row = 0
		flip = dir == 1
	elif mirror and dir > directions / 2.0:
		row = directions - dir
		flip = true
	if a.is_empty():
		return Vector2i(0, -1 if flip else 1)
	return Vector2i(int(a.get("cell", 0)) + row * columns + frame_index(a, tick), -1 if flip else 1)


## Frame of an animation after `tick` ticks: looping, or held on the last frame.
static func frame_index(a: Dictionary, tick: int) -> int:
	var d: Array = a.get("d", [])
	var n := int(a.get("n", d.size()))
	if d.is_empty():
		if n <= 0:
			return 0
		return posmod(tick, n) if a.get("loop", true) else mini(tick, n - 1)
	var total := 0
	for t: int in d:
		total += maxi(t, 1)
	var t := posmod(tick, total) if a.get("loop", true) else mini(tick, total - 1)
	for i in d.size():
		t -= maxi(int(d[i]), 1)
		if t < 0:
			return i
	return d.size() - 1


## An animation by name, whether the dictionary was written with String or StringName keys.
func _anim(anim_name: String) -> Dictionary:
	if anims.has(anim_name):
		return anims[anim_name]
	return anims.get(StringName(anim_name), {})


## Ticks an animation takes once through (for one-shots: attack, hurt). Without `d`, one tick per frame, as
## frame_index() plays it.
static func length_ticks(a: Dictionary) -> int:
	var d: Array = a.get("d", [])
	if d.is_empty():
		return maxi(int(a.get("n", 0)), 0)
	var total := 0
	for t: int in d:
		total += maxi(t, 1)
	return total


## Shader foot strip as a fraction of the cell, and the quad's world size (scale a sprite node by it).
func foot_gutter() -> float:
	return float(foot_px) / float(cell_px)


func size_m() -> float:
	return cell_px * meters_per_px


## Puts the atlas, grid and foot strip into a sprite3d, xray or ghost material.
func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter(&"atlas", atlas)
	material.set_shader_parameter(&"frames", Vector2(columns, rows))
	material.set_shader_parameter(&"foot_gutter", foot_gutter())


## INSTANCE_CUSTOM for a MultiMesh instance (use_instance_custom): facing is the sign from cell().
static func instance_custom(cell_index: int, flash: float, facing: int, phase: float, dissolve: float = 0.0) -> Color:
	return Color(cell_index, flash, (1.0 if facing >= 0 else -1.0) * (1.0 + clampf(dissolve, 0.0, 1.0)), phase)


## Instance colour (use_instance_color): rgb tints the sprite, alpha carries the outline role (ROLE_*), so the
## default white instance colour means no outline.
static func instance_color(tint: Color, role: int) -> Color:
	return Color(tint.r, tint.g, tint.b, 1.0 - clampi(role, 0, 7) / 8.0)


## Reads one character from a tools/sprite_atlas.py sheets file (JSON). The atlas path in it is relative to the file.
static func from_json(path: String, character: String) -> Resource:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not (data as Dictionary).get("characters", {}).has(character):
		push_error("sprite3d_sheet: no character '%s' in %s" % [character, path])
		return null
	var sheet: Resource = load("res://addons/proto_kit/sprite3d_sheet.gd").new()
	var c: Dictionary = data.characters[character]
	var atlas_path: String = path.get_base_dir().path_join(String(data.get("atlas", "atlas.png")))
	if ResourceLoader.exists(atlas_path):
		sheet.atlas = load(atlas_path)
	sheet.columns = int(data.columns)
	sheet.rows = int(data.rows)
	sheet.cell_px = int(data.cell_px)
	sheet.foot_px = int(data.get("foot_px", 4))
	sheet.meters_per_px = float(data.get("meters_per_px", 0.025))
	sheet.directions = int(c.get("directions", 1))
	sheet.mirror = bool(c.get("mirror", true))
	sheet.anims = c.get("anims", {})
	return sheet
