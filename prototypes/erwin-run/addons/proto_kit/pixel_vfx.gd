extends Node2D
## Pixel-art hit effects in one node, after PokéSurvivor: everything sits on one art-pixel grid (`pixel` world px
## per art pixel), positions snap to it, angles snap to 22.5°, and fades step 1 → 0.66 → 0.33 instead of sliding.
## Palettes are five tones: outline, dark, mid, light, white.
##
## Two kinds of effect:
## - Shapes, drawn by this node's _draw: square particles (burst, spark, trail) and shape entries (ring, slash,
##   star, pop, caption). Add your own with register(kind, draw) + add_shape(kind, ...).
## - Shader effects: one child node per effect running a canvas shader from `shaders` (explosion, smoke), with
##   `progress` driven 0 → 1 over its life. Add your own by putting a shader in `shaders`; see pixel_vfx.gdshaderinc.
##
## Cosmetic randomness uses its own generator, so spawning effects never moves the game's global randf().
## Put it above the actors (z_index) and call clear() when a run resets.

## World px per art pixel (for a camera zoom z showing art at 2 screen px: 2 / z).
@export var pixel: float = 2.0
@export var max_particles: int = 500
@export var max_shapes: int = 80
@export var max_shader_effects: int = 12
## Caption font, drawn at 11 px so one font pixel is one art pixel; null uses the default theme font.
@export var font: Font
@export var font_size: int = 11
## name: [outline, dark, mid, light, white] as colour strings. Unknown names fall back to `fallback_palette`.
@export var palettes: Dictionary = {
	"hit": ["#2a1a10", "#a4542a", "#ffb35c", "#ffe7a8", "#ffffff"],
	"fire": ["#3a0a08", "#a8201a", "#ff5a2e", "#ffc24a", "#fff3c0"],
	"ice": ["#10243a", "#1f5d86", "#3fb4e0", "#9fe8ff", "#ffffff"],
	"poison": ["#18300c", "#3e7020", "#86c040", "#d2f08a", "#f6ffe0"],
	"gold": ["#3a2408", "#a8701a", "#ffc83e", "#ffe896", "#ffffff"],
	"smoke": ["#1e1a26", "#4a4458", "#7c7590", "#b4aec4", "#e6e2ee"],
	"magic": ["#1c0e36", "#4a2a9a", "#8a5cf0", "#c8b0ff", "#ffffff"],
}
@export var fallback_palette: StringName = &"hit"
## Shader effects by name. Each shader includes pixel_vfx.gdshaderinc.
@export var shaders: Dictionary = {
	"explosion": preload("res://addons/proto_kit/pixel_vfx_explosion.gdshader"),
	"smoke": preload("res://addons/proto_kit/pixel_vfx_smoke.gdshader"),
}
var rng := RandomNumberGenerator.new()
var _parts: Array = []
var _shapes: Array = []
var _kinds: Dictionary = {}
var _tones: Dictionary = {}
var _drawn: bool = false

## A running shader effect: draws one rect that its shader fills; progress goes 0 → 1 over `life` seconds.
class ShaderEffect extends Node2D:
	var size: Vector2
	var life: float = 1.0
	var age: float = 0.0
	## Where the node sits in the rect: (0.5, 0.5) centre, (0.5, 1) bottom middle.
	var pivot := Vector2(0.5, 0.5)

	func _process(delta: float) -> void:
		age += delta
		(material as ShaderMaterial).set_shader_parameter(&"progress", clampf(age / life, 0.0, 1.0))
		if age >= life:
			queue_free()

	func _draw() -> void:
		draw_rect(Rect2(-size * pivot, size), Color.WHITE)

func _init() -> void:
	rng.seed = 7
	for kind: StringName in [&"ring", &"slash", &"star", &"pop", &"text"]:
		_kinds[kind] = Callable(self, "_draw_" + kind)

func clear() -> void:
	for child: Node in get_children():
		if child is ShaderEffect:
			child.queue_free()
	_parts.clear()
	_shapes.clear()
	queue_redraw()

## Live particles, shapes and shader effects.
func count() -> int:
	return _parts.size() + _shapes.size() + get_children().filter(func(c: Node) -> bool: return c is ShaderEffect and not c.is_queued_for_deletion()).size()

## The five colours of `palette`.
func tones(palette: StringName) -> Array:
	if not _tones.has(palette):
		var source: Array = palettes.get(palette, palettes.get(fallback_palette, ["#000", "#444", "#888", "#ccc", "#fff"]))
		_tones[palette] = source.map(func(c: Variant) -> Color: return Color(c) if c is String else c)
	return _tones[palette]

# --- particles ---------------------------------------------------------------------------------------------

## Square particles flying out in every direction; `speed` in art px per second.
func burst(at: Vector2, palette: StringName, amount: int = 8, speed: float = 55.0) -> void:
	var pal: Array = tones(palette)
	for i: int in amount:
		var velocity := Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.35, 1.0) * speed * pixel
		particle(at, velocity, pal[rng.randi_range(2, 4)], rng.randf_range(0.22, 0.5), 2 if rng.randf() < 0.55 else 1)

## A few quick sparks thrown along `direction`, for ordinary hits.
func spark(at: Vector2, direction: Vector2, palette: StringName, amount: int = 4) -> void:
	var pal: Array = tones(palette)
	var base: float = direction.angle() if direction != Vector2.ZERO else -PI / 2.0
	for i: int in amount:
		var velocity := Vector2.RIGHT.rotated(base + rng.randf_range(-0.9, 0.9)) * rng.randf_range(30.0, 85.0) * pixel
		particle(at, velocity, pal[rng.randi_range(3, 4)], rng.randf_range(0.14, 0.32), 1)

## Call every frame along a flying shot: "ember" rises, "drip" falls, anything else scatters.
func trail(at: Vector2, palette: StringName, kind: StringName) -> void:
	if rng.randf() > 0.5:
		return
	var pal: Array = tones(palette)
	var jitter := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * pixel
	match kind:
		&"ember":
			particle(at + jitter, Vector2(0, -14) * pixel, pal[rng.randi_range(2, 3)], 0.35, 1)
		&"drip":
			particle(at + jitter, Vector2(0, 4) * pixel, pal[3], 0.35, 1, 94.0 * pixel)
		_:
			particle(at + jitter * 2.0, Vector2(rng.randf_range(-22, 22), rng.randf_range(-22, 22)) * pixel, pal[rng.randi_range(3, 4)], 0.16, 1)

## One square particle (`cells` art pixels wide) with drag and optional gravity (world px/s²).
func particle(at: Vector2, velocity: Vector2, color: Color, life: float, cells: int = 1, gravity: float = 0.0) -> void:
	if _parts.size() >= max_particles:
		return
	_parts.append({"at": at, "v": velocity, "color": color, "life": life, "t": 0.0, "size": cells, "g": gravity})

# --- shapes --------------------------------------------------------------------------------------------------

## An expanding ring of grid squares, squashed to lie on the ground; `thick` 2 adds an inner row.
func ring(at: Vector2, from_radius: float, to_radius: float, palette: StringName, life: float = 0.3, thick: int = 1) -> void:
	add_shape(&"ring", at, palette, life, {"r0": from_radius, "r1": to_radius, "thick": thick})

## A swing: an arc around `at` facing `angle`, thick in the middle and thin at the ends, with an impact star.
func slash(at: Vector2, angle: float, radius: float, arc: float, palette: StringName, heavy: bool = false) -> void:
	add_shape(&"slash", at, palette, 0.22, {"angle": angle, "radius": radius, "arc": arc, "heavy": heavy})
	star(at + Vector2.RIGHT.rotated(angle) * radius * 0.7, palette, heavy)

## An eight-ray impact star; its second frame is wider and turned.
func star(at: Vector2, palette: StringName, big: bool = false) -> void:
	add_shape(&"star", at, palette, 0.28 if big else 0.2, {"size": 8.0 if big else 5.0})

## A solid flash that shrinks fast: white core, light and mid rings. `radius` in world px.
func pop(at: Vector2, palette: StringName, radius: float, life: float = 0.14) -> void:
	add_shape(&"pop", at, palette, life, {"radius": radius})

## A pixel-font word that pops and rises ("BAM!").
func caption(at: Vector2, text: String, palette: StringName, life: float = 0.6) -> void:
	add_shape(&"text", at, palette, life, {"text": text})

## A shape of a registered kind: drawn every frame by its draw callable until `life` runs out.
func add_shape(kind: StringName, at: Vector2, palette: StringName, life: float, extra: Dictionary = {}) -> void:
	if _shapes.size() >= max_shapes or not _kinds.has(kind):
		return
	var entry := {"kind": kind, "at": at, "pal": tones(palette), "life": life, "t": 0.0}
	entry.merge(extra)
	_shapes.append(entry)

## New shape kind: `draw` is called as draw.call(entry, left) inside this node's _draw, where `left` runs 1 → 0;
## use cell(), snap() and fade() to stay on the grid. entry holds at, pal, life, t and add_shape's extra keys.
func register(kind: StringName, draw: Callable) -> void:
	_kinds[kind] = draw

# --- shader effects ------------------------------------------------------------------------------------------

## Plays shader effect `name` (a key of `shaders`) in a `size` rect at `at` for `life` seconds, coloured from
## `palette`. `pivot` places the node in the rect; `params` sets extra shader uniforms. Returns the node, or null
## when the cap is reached or the name is unknown.
func effect(name: StringName, at: Vector2, size: Vector2, life: float, palette: StringName, params: Dictionary = {}, pivot := Vector2(0.5, 0.5)) -> Node2D:
	var shader: Shader = shaders.get(name)
	if shader == null or count_effects() >= max_shader_effects:
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	var pal: Array = tones(palette)
	for i: int in 5:
		material.set_shader_parameter(StringName("tone_%d" % i), pal[i])
	material.set_shader_parameter(&"rect_size", size)
	material.set_shader_parameter(&"pixel", pixel)
	material.set_shader_parameter(&"seed", rng.randf() * 100.0)
	material.set_shader_parameter(&"progress", 0.0)
	for key: StringName in params:
		material.set_shader_parameter(key, params[key])
	var node := ShaderEffect.new()
	node.material = material
	node.size = size
	node.life = life
	node.pivot = pivot
	node.show_behind_parent = true
	add_child(node)
	# Snap so the shader's cells line up with the particles' grid.
	node.global_position = snap(at)
	return node

func count_effects() -> int:
	return get_children().filter(func(c: Node) -> bool: return c is ShaderEffect and not c.is_queued_for_deletion()).size()

# --- update and draw -----------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var drag: float = pow(0.9, 60.0 * delta)
	for i: int in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p.t += delta
		if p.t >= p.life:
			_parts.remove_at(i)
			continue
		p.v.y += p.g * delta
		p.at += p.v * delta
		p.v *= drag
	for i: int in range(_shapes.size() - 1, -1, -1):
		_shapes[i].t += delta
		if _shapes[i].t >= _shapes[i].life:
			_shapes.remove_at(i)
	if not _parts.is_empty() or not _shapes.is_empty() or _drawn:
		queue_redraw()

## `at` moved onto the art-pixel grid.
func snap(at: Vector2) -> Vector2:
	return (at / pixel).round() * pixel

## Stepped fade for `left` (1 → 0): 1, 0.66 or 0.33.
static func fade(left: float) -> float:
	return 1.0 if left > 0.66 else (0.66 if left > 0.33 else 0.33)

## One square of `cells` art pixels at `at` (snapped). Only valid inside a draw callable.
func cell(at: Vector2, color: Color, cells: int = 1) -> void:
	draw_rect(Rect2(snap(at), Vector2.ONE * pixel * cells), color)

func _draw() -> void:
	_drawn = not _parts.is_empty() or not _shapes.is_empty()
	for s: Dictionary in _shapes:
		_kinds[s.kind].call(s, 1.0 - s.t / s.life)
	for p: Dictionary in _parts:
		cell(p.at, Color(p.color, fade(1.0 - p.t / p.life)), p.size)

func _draw_ring(s: Dictionary, left: float) -> void:
	var radius: float = lerpf(s.r0, s.r1, 1.0 - left)
	var steps: int = maxi(10, ceili(TAU * radius / (pixel * 1.5)))
	var alpha: float = fade(left)
	for i: int in steps:
		var a: float = TAU * i / steps
		var at := Vector2(cos(a) * radius, sin(a) * radius * 0.75)
		cell(s.at + at, Color(s.pal[3], alpha), s.thick)
		if s.thick > 1:
			cell(s.at + at * 0.94, Color(s.pal[2], alpha))

func _draw_slash(s: Dictionary, left: float) -> void:
	var half: float = minf(s.arc, TAU) * 0.5
	var radius: float = s.radius * (0.72 + 0.28 * (1.0 - left))
	var cells: int = maxi(8, ceili(radius * half * 2.0 / pixel))
	var depth_max: int = 6 if s.heavy else 4
	var alpha: float = fade(left)
	var angle: float = snappedf(s.angle, PI / 8.0)
	for i: int in cells + 1:
		var u: float = float(i) / cells
		var a: float = angle - half + u * half * 2.0
		var depth: int = roundi(depth_max * sin(PI * u) * left)
		for d: int in range(-1, depth + 1):
			var tone: int = 0 if d < 0 else (4 if d == depth else (3 if d > depth / 2 else 2))
			cell(s.at + Vector2.RIGHT.rotated(a) * (radius - d * pixel), Color(s.pal[tone], alpha))

func _draw_star(s: Dictionary, left: float) -> void:
	var second: bool = left < 0.5
	var alpha: float = fade(left)
	for ray: int in 8:
		var a: float = ray * PI / 4.0 + (PI / 8.0 if second else 0.0)
		var length: float = s.size * (1.0 if ray % 2 == 0 else 0.6) * (1.0 if second else 0.75)
		var steps: int = ceili(length)
		for k: int in steps + 1:
			var tone: int = 4 if k <= 1 else (3 if k < steps else 2)
			cell(s.at + Vector2.RIGHT.rotated(a) * k * pixel, Color(s.pal[tone], alpha))

func _draw_pop(s: Dictionary, left: float) -> void:
	var cells: int = maxi(1, roundi(s.radius * left / pixel))
	var origin: Vector2 = snap(s.at)
	for y: int in range(-cells, cells + 1):
		for x: int in range(-cells, cells + 1):
			var d: float = Vector2(x, y * 1.25).length() / cells
			if d > 1.0:
				continue
			var tone: int = 4 if d < 0.45 else (3 if d < 0.75 else 2)
			draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2.ONE * pixel), s.pal[tone])

func _draw_text(s: Dictionary, left: float) -> void:
	var face: Font = font if font != null else ThemeDB.fallback_font
	var rise: float = (1.0 - left) * 14.0 * pixel
	var scale: float = pixel * (1.4 if s.t < 0.08 else 1.0)
	var width: float = face.get_string_size(s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * scale
	draw_set_transform(snap(s.at - Vector2(width * 0.5, rise)), 0.0, Vector2.ONE * scale)
	draw_string_outline(face, Vector2.ZERO, s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(s.pal[0], fade(left)))
	draw_string(face, Vector2.ZERO, s.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(s.pal[3], fade(left)))
	draw_set_transform(Vector2.ZERO)
