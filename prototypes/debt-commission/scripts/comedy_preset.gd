extends Control
## One manga overlay preset (scenes/comedy/<preset>.tscn). The root's exports are the timeline and
## the effects of that preset, adjustable in the editor; ComedyLayer instantiates the scene, calls
## `play`, and carries out the stage-level requests (shake, sound, zoom) this node raises.
## Pieces are looked up by unique name and each is optional: Dim, SpeedLines, CutInPanel, Portrait,
## Burst, TextArea (the room for the line), Text (centred in it), Spot (small_reaction: where the balloon hangs, set by `place_at`).

signal sound_requested(sound_id: String)
signal shake_requested(strength: String)
signal zoom_requested(factor: float, duration: float)
signal finished

const INK: String = "#141414"
const RED: String = "#d7191c"
## Where a line's clauses end, and the marks that close a shout (see `colored`).
const CLAUSE_END: String = "，、。,；;"
const SHOUT_MARKS: String = "！？!?～"
## A face crop keeps this share of the picture's width (centred), from its top edge down.
const FACE_WIDTH: float = 0.78
const FAST_FORWARD_SEC: float = 0.1
const MIN_FONT: int = 24

@export_group("Timeline (seconds)")
@export var dim_in: float = 0.05
@export var cutin_at: float = 0.05
@export var cutin_slide: float = 0.12
@export var shake_at: float = 0.10
@export var sound_at: float = 0.12
@export var burst_at: float = 0.15
@export var hold_until: float = 0.90
@export var fade_at: float = 1.20
@export var end_at: float = 1.35
@export_group("Effects")
@export_enum("none", "small", "big") var shake_strength: String = "big"
@export var sound_id: String = "comedy_don"
## The stage behind grows to this scale from the balloon's pop to the hold's end (1 = no zoom).
@export var stage_zoom: float = 1.05
@export_group("Text")
## The line's largest font size; it shrinks to whatever fits the balloon (never below MIN_FONT).
@export var font_max: int = 150

var _timeline: Tween = null
var _ending: bool = false
@onready var _dim: CanvasItem = get_node_or_null("%Dim") as CanvasItem
@onready var _speed_lines: CanvasItem = get_node_or_null("%SpeedLines") as CanvasItem
@onready var _cutin: Control = get_node_or_null("%CutInPanel") as Control
@onready var _portrait: TextureRect = get_node_or_null("%Portrait") as TextureRect
@onready var _burst: Control = get_node_or_null("%Burst") as Control
@onready var _text_area: Control = get_node_or_null("%TextArea") as Control
@onready var _text: RichTextLabel = get_node_or_null("%Text") as RichTextLabel
@onready var _spot: Control = get_node_or_null("%Spot") as Control


## Starts the timeline. `portrait` is the speaker's picture (null keeps the scene's own).
func play(portrait: Texture2D, line: String) -> void:
	_ignore_input(self)
	if _portrait != null and portrait != null:
		_portrait.texture = _face(portrait)
	if _text != null:
		_text.text = colored(line)
	for piece: CanvasItem in [_dim, _speed_lines, _cutin, _burst]:
		if piece != null:
			piece.modulate.a = 0.0
	_timeline = create_tween().set_parallel()
	if _dim != null:
		_timeline.tween_property(_dim, "modulate:a", 1.0, maxf(dim_in, 0.001))
	if _cutin != null:
		_timeline.tween_callback(_slide_in).set_delay(cutin_at)
	if shake_strength != "none":
		_timeline.tween_callback(shake_requested.emit.bind(shake_strength)).set_delay(shake_at)
	if not sound_id.is_empty():
		_timeline.tween_callback(sound_requested.emit.bind(sound_id)).set_delay(sound_at)
	if _burst != null:
		_timeline.tween_callback(_pop).set_delay(burst_at)
	if absf(stage_zoom - 1.0) > 0.001:
		_timeline.tween_callback(zoom_requested.emit.bind(stage_zoom, maxf(hold_until - burst_at, 0.05))).set_delay(burst_at)
	_timeline.tween_property(self, "modulate:a", 0.0, maxf(end_at - fade_at, 0.001)).set_delay(fade_at)
	if absf(stage_zoom - 1.0) > 0.001:
		_timeline.tween_callback(zoom_requested.emit.bind(1.0, maxf(end_at - fade_at, 0.05))).set_delay(fade_at)
	_timeline.tween_callback(_finish).set_delay(end_at)


## Cuts the rest of the timeline: fades out at once (the layer is gone within FAST_FORWARD_SEC).
func fast_forward() -> void:
	if _ending:
		return
	_ending = true
	if _timeline != null:
		_timeline.kill()
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, FAST_FORWARD_SEC)
	if absf(stage_zoom - 1.0) > 0.001:
		zoom_requested.emit(1.0, FAST_FORWARD_SEC)
	tween.chain().tween_callback(_finish)


## Hangs the balloon above `point` (this node's coordinates), kept inside `bounds`.
func place_at(point: Vector2, bounds: Vector2) -> void:
	if _spot == null or _burst == null:
		return
	var box: Rect2 = _burst.get_rect()  # relative to Spot
	_spot.position = Vector2(
		clampf(point.x, -box.position.x, maxf(bounds.x - box.end.x, -box.position.x)),
		clampf(point.y, -box.position.y, maxf(bounds.y - box.end.y, -box.position.y)))


## The line as BBCode, black and red. Clauses (split after CLAUSE_END) alternate black, red, ...;
## a line of one clause is black with its closing exclamation marks, and two characters before
## them when it is long, in red.
static func colored(line: String) -> String:
	var text: String = line.strip_edges()
	var clauses: Array[String] = []
	var current: String = ""
	for character: String in text:
		current += character
		if CLAUSE_END.contains(character):
			clauses.append(current)
			current = ""
	if not current.is_empty():
		clauses.append(current)
	if clauses.size() < 2:
		var marks: int = 0
		while marks < text.length() and SHOUT_MARKS.contains(text[text.length() - 1 - marks]):
			marks += 1
		var red_count: int = marks + (2 if text.length() > 8 and marks > 0 else 0)
		if marks == 0:
			red_count = ceili(text.length() * 0.4)
		red_count = clampi(red_count, 1, text.length())
		clauses.assign([text.substr(0, text.length() - red_count), text.substr(text.length() - red_count)])
		if clauses[0].is_empty():
			return "[color=%s]%s[/color]" % [RED, _escape(clauses[1])]
	var markup: String = ""
	for index: int in range(clauses.size()):
		markup += "[color=%s]%s[/color]" % [RED if index % 2 == 1 else INK, _escape(clauses[index])]
	return markup


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


## The top of the picture, cropped to the picture frame's shape: the face and shoulders.
func _face(texture: Texture2D) -> Texture2D:
	var frame: Vector2 = _portrait.size if _portrait.size.x > 1.0 and _portrait.size.y > 1.0 else Vector2(1.4, 1.0)
	var width: float = float(texture.get_width()) * FACE_WIDTH
	var height: float = width * frame.y / frame.x
	if height > texture.get_height():
		height = float(texture.get_height())
		width = height * frame.x / frame.y
	var crop: AtlasTexture = AtlasTexture.new()
	crop.atlas = texture
	crop.region = Rect2((float(texture.get_width()) - width) * 0.5, 0.0, width, height)
	return crop


func _slide_in() -> void:
	_speed_lines_in()
	var rest: Vector2 = _cutin.position
	_cutin.modulate.a = 1.0
	_cutin.position = Vector2(-_cutin.size.x - 120.0, rest.y)  # fully past the left edge, tilt included
	var tween: Tween = _cutin.create_tween()
	tween.tween_property(_cutin, "position", rest, maxf(cutin_slide, 0.001)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _speed_lines_in() -> void:
	if _speed_lines != null:
		_speed_lines.create_tween().tween_property(_speed_lines, "modulate:a", 1.0, 0.08)


## The balloon pops in: its text is sized to fit, then it scales up with a bounce.
func _pop() -> void:
	_fit_text()
	_burst.pivot_offset = _burst.size * 0.5
	_burst.modulate.a = 1.0
	_burst.scale = Vector2(0.35, 0.35)
	_burst.create_tween().tween_property(_burst, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The largest font size, font_max down to MIN_FONT, at which the line fits TextArea (with a
## tenth to spare for the outline); Text is then given that height, centred on the area. The label
## itself measures its wrapped content, so every text server wraps the way it draws.
func _fit_text() -> void:
	if _text == null or _text_area == null:
		return
	var box: Vector2 = _text_area.size
	var height: float = box.y
	for font_size: int in range(font_max, MIN_FONT - 1, -4):
		_text.add_theme_font_size_override("normal_font_size", font_size)
		_text.add_theme_font_size_override("bold_font_size", font_size)
		_text.add_theme_constant_override("outline_size", maxi(6, font_size / 9))
		height = float(_text.get_content_height()) * 1.1
		if height <= box.y:
			break
	_text.offset_top = -height * 0.5
	_text.offset_bottom = height * 0.5


func _finish() -> void:
	finished.emit()


func _ignore_input(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_input(child)
