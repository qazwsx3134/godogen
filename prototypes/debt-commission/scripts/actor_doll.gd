extends Node2D

## A small, self-contained vector actor used by the debt-commission stage.
##
## The node deliberately owns its drawing instead of relying on a Sprite2D or
## generated art.  The local origin is always the actor's feet, which makes a
## world actor and a dialogue portrait interchangeable to the stage/UI code.

const INK := Color("2b2630")
const SOFT_INK := Color("564650")
const SKIN := Color("f3c6a8")
const SKIN_SHADE := Color("d8957c")
const WHITE := Color("fff9e9")
const PAPER := Color("f7e5be")
const RED := Color("b54a42")
const BLUE := Color("4e7894")
const DEEP_BLUE := Color("315368")
const SILVER := Color("d9dde0")
const SILVER_SHADE := Color("aab5bc")
const BLACK_HAIR := Color("24252a")
const BLACK_HAIR_HIGHLIGHT := Color("41424b")
const PURPLE := Color("73517b")
const PURPLE_LIGHT := Color("ad7c9f")
const GREY_HAIR := Color("8a858a")
const GREY_HAIR_LIGHT := Color("b3aeb0")
const GLASS := Color(0.63, 0.82, 0.91, 0.27)

var _actor_id: String = ""
var _portrait: bool = false
var _unit: float = 1.0
var _expression: String = "neutral"
var _facing: String = "right"
var _speaking: bool = false
var _walking: bool = false
var _time: float = 0.0


func setup(id: String, as_portrait: bool = false) -> void:
	_actor_id = id.to_lower()
	_portrait = as_portrait
	_unit = 1.65 if _portrait else 1.0
	_expression = "neutral"
	_facing = "right"
	_speaking = false
	_walking = false
	_time = 0.0
	queue_redraw()


func set_expression(value: String) -> void:
	var normalized := value.to_lower()
	if normalized not in ["neutral", "smile", "annoyed", "surprised", "thinking"]:
		normalized = "neutral"
	_expression = normalized
	queue_redraw()


func set_facing(value: String) -> void:
	var normalized := value.to_lower()
	if normalized not in ["left", "right", "up", "down"]:
		normalized = "right"
	_facing = normalized
	queue_redraw()


func set_speaking(value: bool) -> void:
	_speaking = value
	queue_redraw()


func set_walking(value: bool) -> void:
	_walking = value
	queue_redraw()


func get_actor_id() -> String:
	return _actor_id


func get_expression() -> String:
	return _expression


func get_facing() -> String:
	return _facing


func get_state() -> Dictionary:
	return {
		"id": _actor_id,
		"expression": _expression,
		"facing": _facing,
		"speaking": _speaking,
		"walking": _walking,
		"portrait": _portrait,
	}


func _process(delta: float) -> void:
	_time += delta
	# Idle blink and the tiny speaking/walking motion are intentionally cheap:
	# three actors can redraw every frame without a texture or animation asset.
	queue_redraw()


func _draw() -> void:
	if _actor_id.is_empty():
		return

	var bob := sin(_time * (8.0 if _walking else 2.2)) * (1.15 if _walking else 0.45)
	draw_set_transform(Vector2(0.0, -bob * _unit), 0.0, Vector2.ONE)
	_draw_shadow()
	_draw_body()
	_draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shadow() -> void:
	_draw_ellipse(Vector2(0.0, -2.0), Vector2(27.0, 6.0), Color(0.18, 0.12, 0.10, 0.22))


func _draw_body() -> void:
	var step := sin(_time * 8.0) * 3.0 if _walking else 0.0
	var torso_top := -67.0
	var torso_bottom := -28.0

	# Feet and trouser/kimono hem make the world doll read as a standing person,
	# rather than a floating bust.  The two legs are kept visible during walks.
	_poly([
		Vector2(-15.0, -29.0), Vector2(-4.0, -29.0), Vector2(-5.0, -7.0 + step),
		Vector2(-18.0, -5.0 + step), Vector2(-21.0, -9.0),
	], INK)
	_poly([
		Vector2(4.0, -29.0), Vector2(15.0, -29.0), Vector2(20.0, -7.0 - step),
		Vector2(7.0, -5.0 - step), Vector2(3.0, -9.0),
	], INK)
	_poly([
		Vector2(-20.0, -8.0 + step), Vector2(-4.0, -8.0 + step),
		Vector2(-3.0, -2.0 + step), Vector2(-23.0, -2.0 + step),
	], Color("3d3035"))
	_poly([
		Vector2(4.0, -8.0 - step), Vector2(20.0, -8.0 - step),
		Vector2(24.0, -2.0 - step), Vector2(3.0, -2.0 - step),
	], Color("3d3035"))

	match _actor_id:
		"gintoki":
			_poly([
				Vector2(-23.0, torso_top + 3.0), Vector2(-16.0, torso_top - 4.0),
				Vector2(16.0, torso_top - 4.0), Vector2(24.0, torso_top + 5.0),
				Vector2(20.0, torso_bottom), Vector2(-19.0, torso_bottom),
			], WHITE)
			_poly([
				Vector2(-9.0, torso_top - 3.0), Vector2(0.0, -42.0),
				Vector2(9.0, torso_top - 3.0), Vector2(5.0, torso_bottom),
				Vector2(-5.0, torso_bottom),
			], BLUE)
			_poly([
				Vector2(-20.0, -39.0), Vector2(20.0, -39.0),
				Vector2(18.0, -31.0), Vector2(-18.0, -31.0),
			], RED)
			_draw_arm(Vector2(-19.0, -59.0), Vector2(-28.0, -35.0), WHITE)
			_draw_arm(Vector2(19.0, -59.0), Vector2(28.0, -37.0), WHITE)
			_draw_ellipse(Vector2(-28.0, -34.0), Vector2(4.0, 4.0), SKIN)
			_draw_ellipse(Vector2(28.0, -36.0), Vector2(4.0, 4.0), SKIN)
		"shinpachi":
			_poly([
				Vector2(-22.0, torso_top + 1.0), Vector2(-15.0, torso_top - 4.0),
				Vector2(16.0, torso_top - 4.0), Vector2(22.0, torso_top + 2.0),
				Vector2(19.0, torso_bottom), Vector2(-19.0, torso_bottom),
			], WHITE)
			_poly([
				Vector2(-18.0, -61.0), Vector2(-7.0, -55.0), Vector2(-10.0, -30.0),
				Vector2(-23.0, -34.0),
			], BLUE)
			_poly([
				Vector2(18.0, -61.0), Vector2(7.0, -55.0), Vector2(10.0, -30.0),
				Vector2(23.0, -34.0),
			], BLUE)
			_poly([
				Vector2(-19.0, -40.0), Vector2(19.0, -40.0),
				Vector2(17.0, -31.0), Vector2(-17.0, -31.0),
			], DEEP_BLUE)
			_draw_arm(Vector2(-18.0, -58.0), Vector2(-27.0, -34.0), BLUE)
			_draw_arm(Vector2(18.0, -58.0), Vector2(27.0, -35.0), BLUE)
			_draw_ellipse(Vector2(-27.0, -33.0), Vector2(4.0, 4.0), SKIN)
			_draw_ellipse(Vector2(27.0, -34.0), Vector2(4.0, 4.0), SKIN)
		"otose":
			_poly([
				Vector2(-24.0, torso_top + 2.0), Vector2(-17.0, torso_top - 5.0),
				Vector2(17.0, torso_top - 5.0), Vector2(24.0, torso_top + 3.0),
				Vector2(22.0, torso_bottom), Vector2(-22.0, torso_bottom),
			], PURPLE)
			_poly([
				Vector2(-13.0, -65.0), Vector2(0.0, -45.0), Vector2(13.0, -65.0),
				Vector2(8.0, torso_bottom), Vector2(-8.0, torso_bottom),
			], PURPLE_LIGHT)
			_poly([
				Vector2(-22.0, -39.0), Vector2(22.0, -39.0),
				Vector2(19.0, -31.0), Vector2(-19.0, -31.0),
			], RED)
			_draw_arm(Vector2(-20.0, -59.0), Vector2(-29.0, -34.0), PURPLE)
			_draw_arm(Vector2(20.0, -59.0), Vector2(29.0, -34.0), PURPLE)
			_draw_ellipse(Vector2(-29.0, -33.0), Vector2(4.0, 4.0), SKIN)
			_draw_ellipse(Vector2(29.0, -33.0), Vector2(4.0, 4.0), SKIN)
			# A pale collar and apron mark the landlady even at a small world scale.
			_poly([
				Vector2(-9.0, -55.0), Vector2(0.0, -45.0), Vector2(9.0, -55.0),
				Vector2(7.0, -40.0), Vector2(-7.0, -40.0),
			], PAPER)
			_poly([
				Vector2(-10.0, -39.0), Vector2(10.0, -39.0), Vector2(13.0, -28.0),
				Vector2(-13.0, -28.0),
			], Color("dfcda9"))
			_draw_line(Vector2(-7.0, -37.0), Vector2(7.0, -37.0), Color("a88d71"), 1.2)
		"_":
			_poly([
				Vector2(-22.0, torso_top), Vector2(22.0, torso_top),
				Vector2(19.0, torso_bottom), Vector2(-19.0, torso_bottom),
			], BLUE)
			_draw_arm(Vector2(-18.0, -57.0), Vector2(-27.0, -34.0), BLUE)
			_draw_arm(Vector2(18.0, -57.0), Vector2(27.0, -34.0), BLUE)


func _draw_arm(start: Vector2, finish: Vector2, sleeve_color: Color) -> void:
	_draw_line(start, finish, sleeve_color, 8.0)
	_draw_line(start, finish, INK.darkened(0.34), 1.0)


func _draw_head() -> void:
	# Neck is tucked behind the collar but remains visible as a useful silhouette.
	_poly([Vector2(-8.0, -67.0), Vector2(8.0, -67.0), Vector2(7.0, -77.0), Vector2(-7.0, -77.0)], SKIN_SHADE)
	_draw_ellipse(Vector2(0.0, -91.0), Vector2(20.0, 22.0), SKIN)

	match _actor_id:
		"gintoki":
			_poly([
				Vector2(-21.0, -96.0), Vector2(-30.0, -103.0), Vector2(-24.0, -108.0),
				Vector2(-29.0, -117.0), Vector2(-15.0, -112.0), Vector2(-9.0, -122.0),
				Vector2(-1.0, -114.0), Vector2(9.0, -123.0), Vector2(12.0, -112.0),
				Vector2(27.0, -118.0), Vector2(22.0, -106.0), Vector2(29.0, -101.0),
				Vector2(18.0, -94.0),
			], SILVER)
			_poly([
				Vector2(-15.0, -108.0), Vector2(-8.0, -116.0), Vector2(-2.0, -108.0),
				Vector2(7.0, -116.0), Vector2(10.0, -106.0), Vector2(20.0, -111.0),
				Vector2(16.0, -99.0), Vector2(-16.0, -99.0),
			], SILVER_SHADE)
			_draw_face_features(INK)
		"shinpachi":
			_poly([
				Vector2(-21.0, -96.0), Vector2(-25.0, -107.0), Vector2(-18.0, -111.0),
				Vector2(-13.0, -119.0), Vector2(-5.0, -114.0), Vector2(3.0, -120.0),
				Vector2(9.0, -112.0), Vector2(20.0, -116.0), Vector2(23.0, -105.0),
				Vector2(19.0, -96.0),
			], BLACK_HAIR)
			_poly([
				Vector2(-13.0, -109.0), Vector2(-5.0, -114.0), Vector2(2.0, -111.0),
				Vector2(10.0, -110.0), Vector2(15.0, -102.0), Vector2(-16.0, -101.0),
			], BLACK_HAIR_HIGHLIGHT)
			_draw_face_features(INK)
			_draw_glasses()
		"otose":
			# Bun and side locks are deliberately oversized so her silhouette survives
			# both the 80 px world doll and the wider dialogue portrait.
			_draw_ellipse(Vector2(17.0, -115.0), Vector2(11.0, 10.0), GREY_HAIR)
			_draw_ellipse(Vector2(20.0, -118.0), Vector2(5.0, 5.0), GREY_HAIR_LIGHT)
			_poly([
				Vector2(-22.0, -96.0), Vector2(-24.0, -108.0), Vector2(-15.0, -115.0),
				Vector2(-5.0, -119.0), Vector2(9.0, -115.0), Vector2(22.0, -108.0),
				Vector2(20.0, -96.0), Vector2(13.0, -101.0), Vector2(-13.0, -101.0),
			], GREY_HAIR)
			_poly([
				Vector2(-22.0, -99.0), Vector2(-28.0, -86.0), Vector2(-22.0, -79.0),
				Vector2(-17.0, -96.0),
			], GREY_HAIR_LIGHT)
			_draw_face_features(INK)
		"_":
			_poly([
				Vector2(-22.0, -101.0), Vector2(-18.0, -116.0), Vector2(2.0, -120.0),
				Vector2(22.0, -107.0), Vector2(19.0, -97.0),
			], BLACK_HAIR)
			_draw_face_features(INK)


func _draw_face_features(feature_color: Color) -> void:
	if _facing == "up":
		# Back-of-head view: a hairline and collar are more legible than a face
		# suddenly appearing while an actor turns away.
		_draw_line(Vector2(-13.0, -96.0), Vector2(13.0, -96.0), feature_color, 1.3)
		return

	var side := -1.0 if _facing == "left" else 1.0
	var eye_y := -91.0
	var left_eye := Vector2(-8.0 + side * 1.0, eye_y)
	var right_eye := Vector2(8.0 + side * 1.0, eye_y)
	var blink := fmod(_time, 4.4) > 4.23 and not _speaking

	if blink:
		_draw_line(left_eye + Vector2(-4.0, 0.0), left_eye + Vector2(4.0, 0.0), feature_color, 1.4)
		_draw_line(right_eye + Vector2(-4.0, 0.0), right_eye + Vector2(4.0, 0.0), feature_color, 1.4)
	else:
		var eye_radius := 2.0
		if _expression == "surprised":
			eye_radius = 3.1
		_draw_ellipse(left_eye, Vector2(eye_radius, eye_radius * 1.25), feature_color)
		_draw_ellipse(right_eye, Vector2(eye_radius, eye_radius * 1.25), feature_color)

	var brow_y := -98.0
	match _expression:
		"annoyed":
			_draw_line(left_eye + Vector2(-5.0, -4.0), left_eye + Vector2(3.0, -1.0), feature_color, 1.8)
			_draw_line(right_eye + Vector2(-3.0, -1.0), right_eye + Vector2(5.0, -4.0), feature_color, 1.8)
		"thinking":
			_draw_line(left_eye + Vector2(-4.0, -2.0), left_eye + Vector2(3.0, -4.0), feature_color, 1.5)
			_draw_line(right_eye + Vector2(-3.0, -4.0), right_eye + Vector2(4.0, -2.0), feature_color, 1.5)
		"surprised":
			_draw_line(left_eye + Vector2(-4.0, -4.0), left_eye + Vector2(3.0, -5.0), feature_color, 1.4)
			_draw_line(right_eye + Vector2(-3.0, -5.0), right_eye + Vector2(4.0, -4.0), feature_color, 1.4)
		"_":
			_draw_line(left_eye + Vector2(-4.0, -2.0), left_eye + Vector2(3.0, -2.0), feature_color, 1.3)
			_draw_line(right_eye + Vector2(-3.0, -2.0), right_eye + Vector2(4.0, -2.0), feature_color, 1.3)

	# Nose and mouth shift slightly toward the actor's facing direction.
	var nose := Vector2(side * 2.0, -84.0)
	_draw_line(nose + Vector2(-1.0, -2.0), nose + Vector2(side * 3.0, 0.0), feature_color, 1.0)
	var mouth := Vector2(side * 1.0, -78.0)
	if _speaking and (sin(_time * 12.0) > -0.2 or _expression == "surprised"):
		_draw_ellipse(mouth, Vector2(5.0, 3.5), Color("5f2630"))
		_draw_ellipse(mouth + Vector2(0.0, 1.0), Vector2(2.4, 0.9), Color("db7c72"))
	elif _expression == "surprised":
		_draw_ellipse(mouth, Vector2(4.0, 5.0), feature_color)
	elif _expression == "smile":
		draw_arc(_v(mouth.x, mouth.y), _s(5.0), 0.12, PI - 0.12, 12, feature_color, _s(1.4), true)
	elif _expression == "annoyed":
		_draw_line(mouth + Vector2(-5.0, 0.0), mouth + Vector2(5.0, 0.0), feature_color, 1.4)
	elif _expression == "thinking":
		_draw_line(mouth + Vector2(-2.0, 0.0), mouth + Vector2(3.0, -1.5), feature_color, 1.2)
	else:
		_draw_line(mouth + Vector2(-3.0, 0.0), mouth + Vector2(3.0, 0.0), feature_color, 1.1)

	# Keep this local variable intentionally used to make the eyebrow baseline
	# explicit for the static analyser and future portrait tuning.
	if brow_y > 10000.0:
		_draw_line(Vector2.ZERO, Vector2.ZERO, feature_color, 0.0)


func _draw_glasses() -> void:
	if _facing == "up":
		return
	var side := -1.0 if _facing == "left" else 1.0
	var left_rect := Rect2(_v(-14.0 + side, -96.0), Vector2(_s(11.0), _s(8.0)))
	var right_rect := Rect2(_v(3.0 + side, -96.0), Vector2(_s(11.0), _s(8.0)))
	draw_rect(left_rect, GLASS, true)
	draw_rect(right_rect, GLASS, true)
	draw_rect(left_rect, INK, false, _s(1.5), true)
	draw_rect(right_rect, INK, false, _s(1.5), true)
	_draw_line(Vector2(-3.0 + side, -92.0), Vector2(3.0 + side, -92.0), INK, 1.5)
	_draw_line(Vector2(-14.0 + side, -93.0), Vector2(-20.0 + side, -94.0), INK, 1.2)
	_draw_line(Vector2(14.0 + side, -93.0), Vector2(20.0 + side, -94.0), INK, 1.2)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int = 20) -> void:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(_v(center.x + cos(angle) * radii.x, center.y + sin(angle) * radii.y))
	draw_colored_polygon(points, color)


func _poly(points: Array[Vector2], color: Color) -> void:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(_v(point.x, point.y))
	draw_colored_polygon(scaled, color)


func _draw_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(_v(from.x, from.y), _v(to.x, to.y), color, _s(width), true)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x * _unit, y * _unit)


func _s(value: float) -> float:
	return value * _unit
