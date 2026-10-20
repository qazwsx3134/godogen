@tool
class_name Act
extends Node3D
## One act of the Marineford script (docs/one-piece-marineford/acts.md): the root of scenes/acts/act_<n>.tscn.
## Its ActTrigger children are places on the route; each holds Beat children that run in order when the player gets
## there (story fires on arrival, never on a timer). Main adds the act to the world, calls begin() and then step()
## every frame with the game dt (0 while the game is held), and skips its own simulation while holds_game().
##
## The host (main) answers: play_cutscene(scene) -> Signal, story_banner(title, subtitle, color, portrait id), and
## every CALL beat's method(arg) (returning a Signal to wait on, or nothing).

signal cleared

@export var number: int = 4
@export var number_text: String = "第四幕"
@export var title: String = "處刑台"
## Where the player starts (route Z) and which way the act runs: -1 toward the platform (-Z), +1 back toward the bay.
@export var start_z: float = 30.0
@export var heading: float = -1.0
## Alive-enemy target over the act as (seconds, count); replaces main's run curve.
@export var army_curve: PackedVector2Array = PackedVector2Array([Vector2(0, 30), Vector2(60, 90), Vector2(150, 160), Vector2(240, 220)])
## Luffy's moves at the start of the act ("id:level"), see docs/one-piece-marineford/README.md 跨關成長.
@export var kit: PackedStringArray = PackedStringArray()
## Story unlocks already true at the start (gear2, haki, hormone).
@export var unlocked: PackedStringArray = PackedStringArray()
@export var companions: PackedStringArray = PackedStringArray()

var story: StoryUi
var host: Node
## Game time since begin().
var clock: float = 0.0
var done: bool = false

var _holds: int = 0
var _running: bool = false
var _queue: Array[ActTrigger] = []

signal _ticked


func _ready() -> void:
	# Editor-only context (a route instance to place triggers against) must not draw a second route in the game.
	if not Engine.is_editor_hint() and has_node(^"Reference"):
		get_node(^"Reference").free()


func triggers() -> Array[ActTrigger]:
	var out: Array[ActTrigger] = []
	for child: Node in get_children():
		if child is ActTrigger:
			out.append(child)
	return out


func begin(story_ui: StoryUi, host_node: Node) -> void:
	story = story_ui
	host = host_node
	for t: ActTrigger in triggers():
		if t.on_start:
			t.fired = true
			_queue.append(t)
	_pump()


## True while a blocking beat (dialogue, title card, cutscene) is running: the game clock stands still.
func holds_game() -> bool:
	return _holds > 0


## Has the player at ground point `at` reached `trigger` along the act's heading?
func reached(trigger: ActTrigger, at: Vector2) -> bool:
	return (at.y - trigger.global_position.z) * heading >= 0.0


func step(dt: float, at: Vector2) -> void:
	clock += dt
	_ticked.emit()
	if done:
		return
	for t: ActTrigger in triggers():
		if not t.fired and not t.on_start and reached(t, at):
			t.fired = true
			_queue.append(t)
	_pump()


## The next goal ahead: {name, z}, or {} when none is left.
func next_goal() -> Dictionary:
	for t: ActTrigger in triggers():
		if not t.fired and not t.goal_name.is_empty():
			return {"name": t.goal_name, "z": t.global_position.z}
	return {}


func wait_game(seconds: float) -> void:
	var end: float = clock + seconds
	while clock < end:
		await _ticked


func _pump() -> void:
	if _running or _queue.is_empty():
		return
	_running = true
	_run_queue()


func _run_queue() -> void:
	while not _queue.is_empty() and not done:
		var t: ActTrigger = _queue.pop_front()
		for beat: Beat in t.beats():
			if done:
				break
			await _run(beat)
	_running = false


func _hold(on: bool) -> void:
	_holds += 1 if on else -1


func _run(b: Beat) -> void:
	match b.kind:
		Beat.Kind.SAY:
			_hold(true)
			await story.say(b.speaker, b.text, b.portrait, b.color)
			_hold(false)
		Beat.Kind.LINE:
			story.line(b.speaker, b.text, b.seconds, b.color)
		Beat.Kind.TOAST:
			story.toast(b.speaker, b.text, b.portrait, b.color)
		Beat.Kind.BANNER:
			host.call(&"story_banner", b.text, b.speaker, b.color, b.portrait)
		Beat.Kind.TITLE:
			_hold(true)
			await story.title_card(number_text, b.text if not b.text.is_empty() else title)
			_hold(false)
		Beat.Kind.CUTSCENE:
			if b.cutscene:
				_hold(true)
				# A coroutine called through call() would not be awaitable: the host returns a Signal instead.
				var ended: Variant = host.call(&"play_cutscene", b.cutscene)
				if ended is Signal:
					await ended
				_hold(false)
		Beat.Kind.CALL:
			var result: Variant = host.call(b.method, b.arg)
			if b.wait and result is Signal:
				await result
		Beat.Kind.WAIT:
			await wait_game(b.seconds)
		Beat.Kind.WIN:
			done = true
			cleared.emit()
