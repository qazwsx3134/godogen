extends CanvasLayer
## Moving between screens with a fade, plus values handed to the next screen. Make it the script (or the base of
## the script) of an autoload scene: a CanvasLayer with a high `layer` and a full-rect ColorRect child that is a
## %Fade unique name, colour set in the scene. Without %Fade it switches at once.
##   extends "res://addons/proto_kit/scene_router.gd"      # scripts/app.gd: add the game's shared state
##
##   App.go("res://scenes/main.tscn", {&"stage": 3})       # fade out, change scene, fade in
##   var stage: int = App.take(&"stage", 1)                # in the next screen's _ready; the default when run alone
##
## The fades run on PROCESS_MODE_ALWAYS and unpause the tree before the change, so a pause menu can go(). While a
## change is under way (busy()), another go() is ignored and the fade swallows taps. Screens should still run without
## the autoload (tests instantiate them directly): take() is the only coupling, and it has a default.

signal screen_changed(path: String)

## Seconds of each half of the fade.
@export var fade_seconds: float = 0.2

var _hand: Dictionary = {}
var _busy: bool = false
var _fade: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = get_node_or_null(^"%Fade") as ColorRect
	if _fade != null:
		_fade.modulate.a = 0.0
		_fade.visible = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fades out, switches to the scene at `path`, fades in. `hand`: values for the next screen's take(). Returns false
## when a change is already under way or `path` cannot be loaded (the current screen stays).
func go(path: String, hand: Dictionary = {}) -> bool:
	if _busy:
		return false
	if not ResourceLoader.exists(path):
		push_error("scene_router: no scene at " + path)
		return false
	_busy = true
	_hand = hand
	await _fade_to(1.0)
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("scene_router: cannot open %s (%s)" % [path, error_string(error)])
		_hand = {}
	else:
		# The new scene enters the tree at the end of this frame; its _ready runs before the fade-in starts.
		await get_tree().process_frame
		await get_tree().process_frame
	await _fade_to(0.0)
	_busy = false
	if error == OK:
		screen_changed.emit(path)
	return error == OK


## A change is under way.
func busy() -> bool:
	return _busy


## A value handed over by go() for this screen (removed once taken), or `default`.
func take(key: StringName, default: Variant = null) -> Variant:
	if not _hand.has(key):
		return default
	var value: Variant = _hand[key]
	_hand.erase(key)
	return value


func _fade_to(alpha: float) -> void:
	if _fade == null:
		return
	_fade.visible = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, ^"modulate:a", alpha, fade_seconds)
	await tween.finished
	if alpha <= 0.0:
		_fade.visible = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
