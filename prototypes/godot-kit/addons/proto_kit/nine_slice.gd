extends RefCounted
## 9-slice frames from PNGs into a Theme: `const NineSlice = preload("res://addons/proto_kit/nine_slice.gd")`.
## A frame image keeps its corners and edges `slice` px wide and stretches the middle, so one small PNG frames a
## button or a dialog of any size (pixel art stays crisp with the project's nearest texture filter).
##
##   var theme: Theme = load("res://ui/theme.tres")
##   NineSlice.button_states(theme, &"Button", "res://ui/frame/button%s.png", 14, Vector4(20, 8, 20, 8))
##   theme.set_type_variation(&"Dialog", &"PanelContainer")
##   theme.set_stylebox(&"panel", &"Dialog", NineSlice.box(load("res://ui/frame/dialog.png"), 24, Vector4(34, 26, 34, 30)))
##   ResourceSaver.save(theme, "res://ui/theme.tres")
##
## Run it from a headless tool script that loads the theme and sets only these entries, so the rest of the theme
## (tuned in the editor) stays.

## Button states and the file suffix each reads: hover_pressed shares the pressed frame.
const STATES := {&"normal": "", &"hover": "_hover", &"pressed": "_pressed", &"disabled": "_disabled",
	&"hover_pressed": "_pressed"}


## A StyleBoxTexture of `texture` with `slice` px fixed at each edge. `pad` = content margins (left, top, right,
## bottom); `sink` moves the content down that many px (a pressed button).
static func box(texture: Texture2D, slice: int, pad: Vector4, sink: float = 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = slice
	style.texture_margin_top = slice
	style.texture_margin_right = slice
	style.texture_margin_bottom = slice
	style.content_margin_left = pad.x
	style.content_margin_top = pad.y + sink
	style.content_margin_right = pad.z
	style.content_margin_bottom = pad.w - sink
	return style


## Sets the five button styleboxes of theme type `type` from `pattern` % suffix (STATES): pattern
## "res://ui/frame/primary%s.png" reads primary.png, primary_hover.png, primary_pressed.png, primary_disabled.png.
## A missing state file falls back to the normal frame. Pressed states sink the content by `sink` px.
## Returns false (and sets nothing) when the normal frame is missing.
static func button_states(theme: Theme, type: StringName, pattern: String, slice: int, pad: Vector4,
		sink: float = 2.0) -> bool:
	var normal: Texture2D = frame(pattern % "")
	if normal == null:
		push_error("nine_slice: no frame at " + pattern % "")
		return false
	for state: StringName in STATES:
		var texture: Texture2D = frame(pattern % STATES[state])
		if texture == null:
			texture = normal
		var pressed: bool = state == &"pressed" or state == &"hover_pressed"
		theme.set_stylebox(state, type, box(texture, slice, pad, sink if pressed else 0.0))
	return true


## The texture at `path`: the imported resource, else a PNG read straight from the file (user://, or before the
## first import); null when there is neither.
static func frame(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			return ImageTexture.create_from_image(image)
	return null
