extends RefCounted
## Horizontal PNG strip -> shared SpriteFrames for 2D and 3D.
## var frames = SheetFrames.build(texture, 18, 15.0, false)
## Invalid dimensions/timing return null without writing files.

static func build(texture: Texture2D, count: int, fps: float, looped: bool = false) -> SpriteFrames:
	if texture == null or count < 1 or count > 4096 or not is_finite(fps) or fps <= 0.0:
		return null
	if texture.get_width() < count or texture.get_height() < 1 or texture.get_width() % count != 0:
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", fps)
	frames.set_animation_loop(&"default", looped)
	var width: int = texture.get_width() / count
	for index: int in count:
		var tile := AtlasTexture.new()
		tile.atlas = texture
		tile.region = Rect2(index * width, 0, width, texture.get_height())
		frames.add_frame(&"default", tile)
	return frames
