extends RefCounted
## The logic of a loading screen: loads a scene on a thread and says what the screen may show. The look (a bar,
## a percentage, tips, an error and a retry button) is the game's own scene. `const SceneLoader = preload("res://addons/proto_kit/scene_loader.gd")`
##
##   var loader := SceneLoader.new()
##   loader.request("res://main.tscn")              # false (and `failed`) if the file is missing or the request is refused
##   func _process(delta: float) -> void:
##       var packed: PackedScene = loader.step(delta)   # null until the scene is loaded AND the bar has been full for a moment
##       bar.value = loader.shown * 100.0
##       if loader.failed: show the error and a retry button that calls loader.request(path) again
##       elif packed != null and get_tree().change_scene_to_packed(packed) != OK: loader.fail()   # loaded, cannot be instantiated
##   func _exit_tree() -> void:
##       loader.cancel()                                 # a load nobody collected is taken off the thread, or the task leaks
##
## What `shown` does, and why: it only moves forward; it never gets ahead of the real load; and it never gets ahead of
## the clock either (`min_show_time`), so the screen is no flash and a load that finishes at once (a web build without
## threads loads inside the request) still fills the bar over that time. It moves at most `fill_speed` of the bar's
## length per second, and the full bar holds for `hold_at_full` seconds before `step` hands the scene over.
## Only the status LOADED lets the switch go ahead: the progress can read 1.0 a moment before the status says so.
## On a web build without threads, give the screen two frames to be drawn before calling request(): it loads inside the call.

## Seconds the screen is never up for less than.
var min_show_time: float = 1.2
## The bar moves at most this much of its length per second, and never backwards.
var fill_speed: float = 2.5
## The full bar stays this long before the switch.
var hold_at_full: float = 0.2

## What the bar may show, 0..1.
var shown: float = 0.0
## The last request failed (missing file, broken scene, refused). request() clears it.
var failed: bool = false
## The scene being loaded.
var path: String = ""

var _elapsed: float = 0.0
var _target: float = 0.0   # how far the load really is, 0..1
var _full_for: float = 0.0
var _requested: bool = false

## Starts loading `scene_path` (again, after a failure). Resets the clock and the bar. False when it could not start.
func request(scene_path: String) -> bool:
	path = scene_path
	_elapsed = 0.0
	_full_for = 0.0
	_target = 0.0
	shown = 0.0
	failed = false
	_requested = false
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
		failed = true
		return false
	_requested = true
	return true

## Once per frame, with the frame's delta. Returns the loaded scene once the bar has been full for `hold_at_full`
## seconds, else null (loading, failed, or not started). Call fail() if the game cannot use the scene it gets.
func step(delta: float) -> PackedScene:
	_elapsed += delta
	if not _requested or failed:
		return null
	var progress: Array = []
	var loaded: bool = false
	match ResourceLoader.load_threaded_get_status(path, progress):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_target = progress[0]
		ResourceLoader.THREAD_LOAD_LOADED:
			_target = 1.0
			loaded = true
		ResourceLoader.THREAD_LOAD_FAILED:
			ResourceLoader.load_threaded_get(path)   # takes the failed task away, or a retry would see it again
			_requested = false
			failed = true
			return null
		_:
			_requested = false
			failed = true
			return null
	shown = move_toward(shown, minf(_target, _elapsed / maxf(min_show_time, 0.01)), fill_speed * delta)
	if not loaded or shown < 1.0:
		return null
	_full_for += delta
	if _full_for < hold_at_full:
		return null
	var packed: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
	_requested = false
	if packed == null:
		failed = true
	return packed

## The game could not use what it was given (change_scene_to_packed refused it).
func fail() -> void:
	failed = true

## Takes a load nobody collected off the thread (call it when the screen leaves the tree).
func cancel() -> void:
	if _requested:
		ResourceLoader.load_threaded_get(path)
		_requested = false
