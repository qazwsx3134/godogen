extends "res://addons/proto_kit/test_kit.gd"
const Layout = preload("res://scripts/investigation_layout.gd")

func _init() -> void:
	var viewport := Vector2(1920, 1080)
	var full := Rect2(Vector2.ZERO, viewport)
	var wide := Layout.coverage(full, Vector2(3840, 1080), viewport)
	_expect(wide.picture == Rect2(-960, 0, 3840, 1080) and wide.horizontal == Vector2(-960, 960), "wide artwork exposes both horizontal edges")
	_expect(wide.vertical == Vector2.ZERO, "wide artwork cannot slide vertically")
	var tall := Layout.coverage(full, Vector2(1920, 2160), viewport)
	_expect(tall.picture == Rect2(0, -540, 1920, 2160) and tall.vertical == Vector2(-540, 540), "tall artwork exposes both vertical edges")
	_expect(tall.horizontal == Vector2.ZERO, "tall artwork cannot slide horizontally")
	var placeholder := Layout.coverage(full, Vector2.ZERO, viewport)
	_expect(placeholder.picture == full and placeholder.horizontal == Vector2.ZERO and placeholder.vertical == Vector2.ZERO, "placeholder keeps its frame without extra pan")
	var offsets: Array[float] = [-100, -50, 100, 50]
	var frame := Layout.anchored_rect(Vector4(0.5, 0.5, 0.5, 0.5), offsets, Rect2(10, 20, 1000, 600))
	_expect(frame == Rect2(410, 270, 200, 100), "anchor conversion includes nonzero parent origin")
	for pan: float in [-960.0, 0.0, 960.0]:
		var result := Layout.panned_offsets(wide.picture, Vector2(pan, 0), Vector4(0, 0, 1, 1), viewport)
		var restored: Array[float] = [result.x, result.y, result.z, result.w]
		var shown := Layout.anchored_rect(Vector4(0, 0, 1, 1), restored, full)
		_expect(shown.encloses(full), "pan edge never exposes a gap at %s" % pan)
		_expect(shown.size == Vector2(3840, 1080), "pan preserves artwork size at %s" % pan)
	_finish("INVESTIGATION LAYOUT TESTS")
