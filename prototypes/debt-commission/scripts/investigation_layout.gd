extends RefCounted
## Runtime picture coverage and pan limits; does not mutate scenes or save state.

static func anchored_rect(anchors: Vector4, offsets: Array[float], parent: Rect2) -> Rect2:
	var start := parent.position + parent.size * Vector2(anchors.x, anchors.y) + Vector2(offsets[0], offsets[1])
	var end := parent.position + parent.size * Vector2(anchors.z, anchors.w) + Vector2(offsets[2], offsets[3])
	return Rect2(start, end - start)


## Zero art size means the frame itself (placeholder or no texture).
static func coverage(frame: Rect2, art: Vector2, viewport: Vector2) -> Dictionary:
	var picture := frame
	if art.x > 0.0 and art.y > 0.0:
		var drawn := art * maxf(frame.size.x / art.x, frame.size.y / art.y)
		picture = Rect2(frame.position + (frame.size - drawn) * 0.5, drawn)
	return {"picture": picture,
		"horizontal": Vector2(minf(0.0, viewport.x - picture.end.x), maxf(0.0, -picture.position.x)),
		"vertical": Vector2(minf(0.0, viewport.y - picture.end.y), maxf(0.0, -picture.position.y))}


static func panned_offsets(picture: Rect2, pan: Vector2, anchors: Vector4, viewport: Vector2) -> Vector4:
	var start := picture.position + pan - viewport * Vector2(anchors.x, anchors.y)
	var end := picture.end + pan - viewport * Vector2(anchors.z, anchors.w)
	return Vector4(start.x, start.y, end.x, end.y)
