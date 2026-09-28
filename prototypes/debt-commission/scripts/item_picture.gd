@tool
extends TextureRect
## An item's (or character's) picture (scenes/ui/item_picture.tscn). Until the asset catalog gives
## it a `path`, it draws a placeholder card with the first character of its name, so the art can
## be dropped in later without touching any screen.

const TINTS: Array[Color] = [Color("#c9a24a"), Color("#a94432"), Color("#4f7fcf"), Color("#6b9a5b"),
	Color("#9a6bb0"), Color("#c47a3a")]

## The name the placeholder shows (its first character) and picks its colour from.
@export var label: String = "瓶":
	set(value):
		label = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


## picture null shows the placeholder.
func show_item(display_name: String, picture: Texture2D) -> void:
	label = display_name
	texture = picture


func _draw() -> void:
	if texture != null:
		return
	var side: float = minf(size.x, size.y)
	var rect: Rect2 = Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(TINTS[absi(label.hash()) % TINTS.size()], 0.9)
	box.border_color = Color(1.0, 1.0, 1.0, 0.75)
	box.set_border_width_all(maxi(1, roundi(side * 0.035)))
	box.set_corner_radius_all(roundi(side * 0.16))
	draw_style_box(box, rect)
	var font: Font = get_theme_default_font()
	var initial: String = label.left(1) if not label.is_empty() else "?"
	var font_size: int = maxi(8, roundi(side * 0.52))
	var width: float = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(rect.get_center().x - width * 0.5, baseline), initial, HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size, Color.WHITE)
