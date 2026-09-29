extends Control
## One character on stage, the root of scenes/characters/<id>.tscn. The root is the standing box a
## slot of scenes/stage.tscn scales to its height (its bottom edge is the feet line); `Art` is laid
## out inside it in the editor, so each character keeps its own size and framing in any slot.
## A character without a scene gets a default Art: the box's height, standing on its bottom edge.

const REFERENCE_SIZE: Vector2 = Vector2(480.0, 1560.0)

var actor_id: String = ""
var tint: Color = Color.GRAY
var expression: String = "neutral"
var _style_id: String = "cinema"
## The catalog picture and, by expression id, the pictures of other faces (catalog `expressions`).
var _base_texture: Texture2D = null
var _expression_art: Dictionary = {}
## The Art offsets for the usual picture (from the character scene), before any face moves them.
var _art_rest: Array[float] = []
@onready var _art: TextureRect = get_node_or_null("Art") as TextureRect
## A board the character holds up (elisabeth.tscn): `Placard` with its `Text` label and `Glow`.
@onready var _placard: Control = get_node_or_null("Placard") as Control
var _placard_pulse: Tween = null

const ART_SHADER: String = """
shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
uniform bool monochrome = false;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (monochrome) {
		float gray = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
		source.rgb = clamp((vec3(gray) - 0.5) * 1.04 + 0.5, 0.0, 1.0);
	}
	COLOR = source * vertex_tint;
}
"""

func setup(id: String, _display_name: String, color: Color, _font: Font) -> void:
	actor_id = id
	tint = color
	name = "Sprite_%s" % id
	size = REFERENCE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_placard("", false)  # the scene's text is only an editor preview


func has_placard() -> bool:
	return _placard != null


## What the board says ("" = blank) and whether it glows (it answers the line on the timed sheet).
func set_placard(text: String, glowing: bool) -> void:
	if _placard == null:
		return
	(_placard.get_node("Text") as Label).text = text
	var glow: CanvasItem = _placard.get_node("Glow") as CanvasItem
	if glowing == glow.visible:
		return
	glow.visible = glowing
	if _placard_pulse != null:
		_placard_pulse.kill()
		_placard_pulse = null
	glow.modulate.a = 1.0
	if glowing and is_inside_tree():
		_placard_pulse = create_tween().set_loops()
		_placard_pulse.tween_property(glow, "modulate:a", 0.35, 0.6)
		_placard_pulse.tween_property(glow, "modulate:a", 1.0, 0.6)


func placard_text() -> String:
	return (_placard.get_node("Text") as Label).text if _placard != null else ""


func placard_glowing() -> bool:
	return _placard != null and (_placard.get_node("Glow") as CanvasItem).visible


## The board's on-screen box: the rotated board's bounding rect in canvas coordinates.
func placard_rect() -> Rect2:
	if _placard == null:
		return Rect2()
	return _placard.get_global_transform() * Rect2(Vector2.ZERO, _placard.size)

## Shows that face's picture when the catalog has one, else the character's usual picture.
func set_expression(value: String) -> void:
	expression = value
	if _art == null or _base_texture == null:
		return
	var texture: Texture2D = _expression_art.get(value, _base_texture)
	_art.texture = texture
	_place_art(texture)


## Faces made by tools/fit_expressions.gd have the usual picture's pixel scale, stand on its bottom
## edge and are centred on it (widened or raised where a pose sticks out), so a face's rect follows
## from its size and the usual picture's rect, which is the Art rect set in the character scene.
func _place_art(texture: Texture2D) -> void:
	if _art_rest.is_empty():
		_art_rest = [_art.offset_left, _art.offset_top, _art.offset_right, _art.offset_bottom]
	var unit: float = (_art_rest[3] - _art_rest[1]) / float(_base_texture.get_height())
	var half_width: float = texture.get_width() * unit * 0.5
	var centre: float = (_art_rest[0] + _art_rest[2]) * 0.5
	_art.offset_left = centre - half_width
	_art.offset_right = centre + half_width
	_art.offset_top = _art_rest[3] - texture.get_height() * unit
	_art.offset_bottom = _art_rest[3]


func set_expression_art(textures: Dictionary) -> void:
	_expression_art = textures
	set_expression(expression)

## The catalog's picture in this character's Art (kept where its scene placed it).
func set_art(texture: Texture2D) -> void:
	if texture == null:
		return
	if _art == null:
		_art = TextureRect.new()
		_art.name = "Art"
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_art)
		var width: float = REFERENCE_SIZE.y * float(texture.get_width()) / float(texture.get_height())
		_art.anchor_left = 0.5
		_art.anchor_right = 0.5
		_art.anchor_top = 1.0
		_art.anchor_bottom = 1.0
		_art.offset_left = -width * 0.5
		_art.offset_right = width * 0.5
		_art.offset_top = -REFERENCE_SIZE.y
		_art.offset_bottom = 0.0
	_base_texture = texture
	_art.texture = _expression_art.get(expression, texture)
	set_ui_style(_style_id)

func set_ui_style(style_id: String) -> void:
	_style_id = style_id
	if _art == null:
		return
	if _art.material == null:
		var shader: Shader = Shader.new()
		shader.code = ART_SHADER
		_art.material = ShaderMaterial.new()
		(_art.material as ShaderMaterial).shader = shader
	(_art.material as ShaderMaterial).set_shader_parameter("monochrome", style_id == "manga")

func art_aspect_ratio() -> float:
	if _art == null or _art.texture == null:
		return REFERENCE_SIZE.x / REFERENCE_SIZE.y
	return float(_art.texture.get_width()) / float(_art.texture.get_height())
