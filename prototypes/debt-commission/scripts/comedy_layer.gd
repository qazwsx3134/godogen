extends Control
## ComedyLayer of main.tscn: the manga overlay a `comedy` step asks for. It sits above the dialogue
## layer and below the overlays, hidden until a preset plays; the reading screen underneath is never
## rebuilt. A preset is a scene (scenes/comedy/<preset>.tscn, scripts/comedy_preset.gd) that this layer
## instantiates, then it carries out the preset's stage-level requests: shake and sound through the
## shared StageEffects, and the zoom of the background and character layers, which `stop` always
## puts back (scale, pivot) whatever ended the preset.
## Nothing here takes input; main.gd's tap catcher (below this layer) hears the tap and calls
## `fast_forward`.

signal finished

const PRESETS: Dictionary = {
	"tsukkomi_impact": preload("res://scenes/comedy/tsukkomi_impact.tscn"),
	"small_reaction": preload("res://scenes/comedy/small_reaction.tscn"),
	"full_manga_panel": preload("res://scenes/comedy/full_manga_panel.tscn"),
}
## The cut-in face when the step names none.
const DEFAULT_EXPRESSION: Dictionary = {
	"tsukkomi_impact": "shout", "small_reaction": "neutral", "full_manga_panel": "shout",
}
## A preset that has not reported its end this long after its own end time is cut.
const WATCHDOG_SEC: float = 1.0
## Where above a standing character the small reaction hangs: this far down their picture (the balloon sits above that point).
const HEAD_DEPTH: float = 0.04

var _effects: Node = null
var _stage_layers: Array[Control] = []
var _catalog: Dictionary = {}
var _speaker_rect: Callable = Callable()
var _dialog_rect: Callable = Callable()
var _preset: Control = null
var _preset_id: String = ""
var _active: bool = false
var _shaking: bool = false
var _rest: Dictionary = {}
var _zoom_tween: Tween = null
var _elapsed: float = 0.0
var _limit: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


## `effects` is the StageEffects node (shake, sound); `stage_layers` are zoomed; `speaker_rect`
## (speaker id -> the picture's rect on screen, empty when not on stage) and `dialog_rect`
## (-> the reading box's rect on screen) say where a small reaction hangs.
func setup(effects: Node, stage_layers: Array[Control], catalog: Dictionary, speaker_rect: Callable, dialog_rect: Callable) -> void:
	_effects = effects
	_stage_layers = stage_layers
	_catalog = catalog
	_speaker_rect = speaker_rect
	_dialog_rect = dialog_rect


## Plays the step's preset; returns how long it lasts (0 when the preset is unknown). A preset
## already playing is replaced after the stage is put back.
func play(step: Dictionary) -> float:
	_clear(false)
	var preset_id: String = str(step.get("preset", ""))
	if not PRESETS.has(preset_id):
		return 0.0
	var speaker: String = str(step.get("speaker", ""))
	_preset = (PRESETS[preset_id] as PackedScene).instantiate() as Control
	_preset_id = preset_id
	add_child(_preset)
	visible = true
	_active = true
	_elapsed = 0.0
	_limit = float(_preset.get("end_at")) + WATCHDOG_SEC
	set_process(true)
	for layer: Control in _stage_layers:
		_rest[layer] = [layer.scale, layer.pivot_offset]
	_preset.connect("sound_requested", _on_sound)
	_preset.connect("shake_requested", _on_shake)
	_preset.connect("zoom_requested", _on_zoom)
	_preset.connect("finished", stop)
	if _preset.has_method("place_at"):
		_preset.call("place_at", _spot_for(speaker), size)
	_preset.call("play", _portrait(speaker, str(step.get("expression", DEFAULT_EXPRESSION[preset_id]))),
		str(step.get("text", "")))
	return float(_preset.get("end_at"))


## Cuts what is left of the preset: it fades out within a tenth of a second.
func fast_forward() -> void:
	if not _active:
		return
	if _shaking:
		_effects.call("stop_shake")
	_preset.call("fast_forward")


## Ends the preset now, whatever it was doing: the layer empties and hides and the stage layers go
## back to their scale and pivot. Reports `finished` when a preset was playing.
func stop() -> void:
	_clear(true)


func is_active() -> bool:
	return _active


## The playing preset's id ("" when none).
func current_preset() -> String:
	return _preset_id


## For the QA snapshot: whether and which preset plays, and while one does, the balloon's and the
## big line's rectangles on screen and whether the line fits its box.
func qa_state() -> Dictionary:
	var state: Dictionary = {"active": _active, "preset": _preset_id}
	if _active and _preset != null:
		var burst: Control = _preset.get_node_or_null("%Burst") as Control
		var text: RichTextLabel = _preset.get_node_or_null("%Text") as RichTextLabel
		if burst != null:
			state["burst"] = _rect_of(burst)
		if text != null:
			state["text"] = _rect_of(text)
			state["text_fits"] = float(text.get_content_height()) <= text.size.y + 1.0
	return state


func _rect_of(control: Control) -> Dictionary:
	var rect: Rect2 = control.get_global_rect()
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > _limit:
		stop()


func _clear(report: bool) -> void:
	var was_active: bool = _active
	_active = false
	_preset_id = ""
	set_process(false)
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	for layer: Control in _rest.keys():
		layer.scale = (_rest[layer] as Array)[0]
		layer.pivot_offset = (_rest[layer] as Array)[1]
	_rest.clear()
	if _shaking and _effects != null:
		_effects.call("stop_shake")
		_effects.call("remove_shake_layer", _preset)
	_shaking = false
	if _preset != null:
		remove_child(_preset)
		_preset.queue_free()
		_preset = null
	visible = false
	if was_active and report:
		finished.emit()


func _on_sound(sound_id: String) -> void:
	_effects.call("play", {"op": "se", "id": sound_id}, false)


func _on_shake(strength: String) -> void:
	_shaking = true
	_effects.call("add_shake_layer", _preset)  # the overlay shakes with the stage
	_effects.call("play", {"op": "shake", "strength": strength}, false)


func _on_zoom(factor: float, duration: float) -> void:
	if _zoom_tween != null:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_parallel()
	for layer: Control in _stage_layers:
		layer.pivot_offset = layer.size * 0.5
		_zoom_tween.tween_property(layer, "scale", Vector2.ONE * factor, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The catalog picture of the speaker's expression, else their usual picture, else none.
func _portrait(speaker: String, expression: String) -> Texture2D:
	var info: Dictionary = (_catalog.get("characters", {}) as Dictionary).get(speaker, {}) as Dictionary
	for path: String in [str((info.get("expressions", {}) as Dictionary).get(expression, "")), str(info.get("path", ""))]:
		if not path.is_empty() and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## A small reaction hangs above the speaker's head on stage, else above the reading box's top
## edge in the middle; in this layer's coordinates.
func _spot_for(speaker: String) -> Vector2:
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var art: Rect2 = _speaker_rect.call(speaker) if _speaker_rect.is_valid() else Rect2()
	if art.has_area():
		return to_local * Vector2(art.get_center().x, art.position.y + art.size.y * HEAD_DEPTH)
	var box: Rect2 = _dialog_rect.call() if _dialog_rect.is_valid() else Rect2(Vector2.ZERO, size)
	return to_local * Vector2(box.get_center().x, box.position.y)
