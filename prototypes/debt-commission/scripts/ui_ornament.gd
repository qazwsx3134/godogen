@tool
extends Control
## Frames and action shapes of the four UI editions (A cinema, B ledger, C manga, D gintama). Place it
## as the first child of a panel (or with show_behind_parent under a button); it draws in the
## editor too, so scenes show their real frame. `unit` is one CSS pixel of the HTML reference
## in local pixels: 1080 / 390 at the design width.

@export_enum("cinema", "ledger", "manga", "gintama") var style_id: String = "cinema":
	set(value):
		style_id = value
		queue_redraw()
@export_enum("dialogue", "choices", "menu", "title", "advance", "slash") var kind: String = "dialogue":
	set(value):
		kind = value
		queue_redraw()
@export var unit: float = 1080.0 / 390.0:
	set(value):
		unit = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configure(style: String, purpose: String, scale_unit: float) -> void:
	style_id = style
	kind = purpose
	unit = scale_unit


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	var u: float = unit
	if kind == "slash":  # the yellow cut at the right end of a manga choice row
		draw_colored_polygon(PackedVector2Array([Vector2(size.x * .47, 0), Vector2(size.x, 0), size, Vector2(0, size.y)]), Color("#ffdc41"))
		return
	if kind == "advance":
		if style_id == "cinema":
			draw_line(Vector2(0, 0), Vector2(0, size.y), Color(0.80, 0.88, 0.85, 0.32), u)
		elif style_id == "ledger":
			var radius: float = minf(size.x, size.y) * .5 - u
			draw_circle(size * .5 + Vector2(0, 2 * u), radius, Color("#762d22"))
			draw_circle(size * .5, radius, Color("#9f3b2b"))
			draw_circle(size * .5, radius - u, Color("#a94432"))
			draw_arc(size * .5, radius - 2.5 * u, 0, TAU, 96, Color("#f4dfbd"), 2 * u)
		elif style_id == "gintama":
			var radius: float = minf(size.x, size.y) * .5 - 2 * u
			draw_circle(size * .5, radius, Color("#203e5e"))
			draw_arc(size * .5, radius - 2 * u, 0, TAU, 96, Color("#d7e4eb"), u)
		else:
			var points: PackedVector2Array = PackedVector2Array([Vector2(size.x * .2, 0), Vector2(size.x, 0), size, Vector2(0, size.y)])
			draw_colored_polygon(points, Color("#e74e36"))
			points.append(points[0])
			draw_polyline(points, Color("#252724"), 2 * u, true)
		return
	if style_id == "cinema":
		if kind == "dialogue":
			for i: int in range(64):
				var fraction: float = float(i) / 63.0
				var alpha: float = lerpf(.62, .96, minf(fraction / .18, 1.0))
				draw_rect(Rect2(0, size.y * i / 64.0, size.x, size.y / 64.0 + 1), Color(.03, .07, .1, alpha))
		elif kind == "choices":
			for i: int in range(64):
				var fraction: float = float(i) / 63.0
				draw_rect(Rect2(0, size.y * i / 64.0, size.x, size.y / 64.0 + 1),
					Color(8, 17, 26, 224).lerp(Color(7, 14, 22, 250), fraction) / 255.0)
		elif kind == "menu":
			draw_rect(r, Color8(8, 16, 25, 240))
			draw_line(Vector2(0, size.y), size, Color8(182, 219, 217, 115), u)
		# title: text sits on the screen's own wash; the panel is only its top rule
		var top_rule: Color = {"menu": Color8(182, 219, 217, 191), "title": Color8(190, 218, 213, 148)}.get(kind, Color(.65, .80, .81, .72))
		draw_line(Vector2.ZERO, Vector2(size.x, 0), top_rule, u)
	elif style_id == "ledger":
		var shadow_offset: Vector2 = Vector2(5, 5) * u if kind in ["menu", "title"] else Vector2(0, 3 * u)
		var shadow: Color = {"menu": Color8(42, 31, 21, 89), "title": Color8(34, 26, 19, 82)}.get(kind, Color(.16, .12, .08, .18))
		draw_rect(Rect2(shadow_offset, size), shadow)
		draw_rect(r, Color("#f2e8d2"))
		for y: int in range(0, int(size.y), maxi(1, int(5 * u))):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(.39, .31, .19, .025), u)
		draw_rect(r, Color({"menu": "#ad9670", "title": "#c9b58c"}.get(kind, "#b9a681")), false, u)
		draw_rect(r.grow(-5 * u), Color(.55, .41, .24, .58), false, u)
		if kind in ["dialogue", "choices", "menu"]:
			draw_rect(Rect2(0, 12 * u, 3 * u, size.y - 24 * u), Color("#a94432"))
	elif style_id == "gintama":
		var paper: StyleBoxFlat = StyleBoxFlat.new()
		paper.bg_color = Color("#f4eddf")
		paper.border_color = Color("#203e5e")
		paper.set_border_width_all(roundi(2 * u))
		paper.set_corner_radius_all(roundi(10 * u))
		paper.shadow_color = Color(0.08, 0.16, 0.23, 0.2)
		paper.shadow_size = roundi(2 * u)
		draw_style_box(paper, r)
		var inner: StyleBoxFlat = StyleBoxFlat.new()
		inner.draw_center = false
		inner.border_color = Color(0.53, 0.68, 0.78, 0.36)
		inner.set_border_width_all(maxi(1, roundi(u)))
		inner.set_corner_radius_all(roundi(7 * u))
		draw_style_box(inner, r.grow(-5 * u))
	else:
		var shadow: Color = {"menu": Color("#e6be32"), "title": Color("#e3bd35"), "choices": Color(.06, .063, .06, .42)}.get(kind, Color(.07, .07, .07, .3))
		var offset: float = {"menu": 6.0, "title": 6.0, "choices": 5.0}.get(kind, 4.0)
		draw_rect(Rect2(Vector2(offset, offset) * u, size), shadow)
		draw_rect(r, {"menu": Color("#f4f2e8"), "dialogue": Color(.965, .96, .93, .96)}.get(kind, Color("#f5f3e9")))
		draw_rect(r, Color("#242522") if kind != "menu" else Color("#20211f"), false, 2 * u if kind == "dialogue" else 3 * u)
		if kind == "dialogue":
			var notch: PackedVector2Array = PackedVector2Array([Vector2(27 * u, u), Vector2(34.5 * u, -6.5 * u), Vector2(42 * u, u)])
			draw_colored_polygon(notch, Color("#f6f5ed"))
			draw_polyline(notch, Color("#242522"), 2 * u, true)
