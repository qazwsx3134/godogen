extends Control
## Placeholder standing sprite: silhouette + character name + expression text.
## A catalog texture can replace the silhouette without changing the scene.

const EXPRESSION_NAMES: Dictionary = {
	"neutral": "平常",
	"smile": "得意",
	"annoyed": "不耐",
	"surprised": "驚訝",
	"thinking": "思考",
}

var actor_id: String = ""
var tint: Color = Color.GRAY
var expression: String = "neutral"

var _name_label: Label = null
var _expression_label: Label = null
var _art: TextureRect = null


func setup(id: String, display_name: String, color: Color, font: Font) -> void:
	actor_id = id
	tint = color
	name = "Sprite_%s" % id
	size = Vector2(460.0, 1040.0)
	pivot_offset = Vector2(size.x * 0.5, size.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = _make_label(font, display_name, 56, Vector2(0.0, size.y * 0.47))
	_expression_label = _make_label(font, "", 38, Vector2(0.0, size.y * 0.47 + 76.0))
	set_expression(expression)


func set_expression(value: String) -> void:
	expression = value
	if _expression_label != null:
		_expression_label.text = "（%s）" % str(EXPRESSION_NAMES.get(value, value))


func set_art(texture: Texture2D) -> void:
	if texture == null:
		return
	_art = TextureRect.new()
	_art.name = "Art"
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name_label.visible = false
	_expression_label.visible = false
	queue_redraw()


func _draw() -> void:
	if _art != null:
		return
	var w: float = size.x
	var h: float = 1040.0  # 頭肩比例固定；身體一路畫到 size.y，讓下緣藏在對話框之後
	var body: Color = tint.darkened(0.62)
	var rim: Color = tint.lightened(0.15)
	var head_center: Vector2 = Vector2(w * 0.5, h * 0.19)
	var head_radius: float = w * 0.2
	var torso: PackedVector2Array = PackedVector2Array([
		Vector2(w * 0.40, h * 0.30), Vector2(w * 0.60, h * 0.30), Vector2(w * 0.93, h * 0.42),
		Vector2(w * 0.99, size.y), Vector2(w * 0.01, size.y), Vector2(w * 0.07, h * 0.42),
	])
	draw_colored_polygon(torso, body)
	var outline: PackedVector2Array = torso.duplicate()
	outline.append(torso[0])
	draw_polyline(outline, rim, 6.0, true)
	draw_circle(head_center, head_radius + 6.0, rim)
	draw_circle(head_center, head_radius, body)


func _make_label(font: Font, value: String, font_size: int, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.position = at
	label.size = Vector2(size.x, font_size * 1.4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint.lightened(0.35))
	add_child(label)
	return label
