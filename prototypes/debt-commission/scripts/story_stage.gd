extends Node2D

## The complete 720 x 620 paper-theatre stage for the debt commission scene.
##
## Everything is built at runtime so the stage can be dropped into the UI
## worker's root scene without requiring a companion .tscn.  The stage's
## `_world` child owns both artwork and actors; camera commands therefore never
## transform the dialogue UI that contains this Node2D.

const ACTOR_DOLL_SCRIPT = preload("res://scripts/actor_doll.gd")
const DESIGN_SIZE := Vector2(720.0, 620.0)
const SNAPSHOT_VERSION := 1
const INK := Color("30262a")
const PAPER := Color("f3dfb8")
const WALL := Color("f5e7cb")
const WOOD_DARK := Color("573b31")
const WOOD := Color("76503b")
const WOOD_LIGHT := Color("a87951")
const TATAMI := Color("c6aa72")
const TATAMI_LIGHT := Color("d8c188")
const SKY := Color("b8d5d0")
const SKY_LIGHT := Color("d9e7dc")
const RED := Color("b54b42")
const TEA := Color("af6d46")

const MARKERS := {
	"reader": Vector2(205.0, 495.0),
	"host": Vector2(468.0, 426.0),
	"door": Vector2(637.0, 469.0),
	"landlady": Vector2(558.0, 430.0),
	"other_side": Vector2(393.0, 313.0),
	"center": Vector2(360.0, 310.0),
}


## Each artwork layer is a child of `_world`, so the camera transform applies
## consistently to the room, furniture, and characters.
class StageArt extends Node2D:
	var stage: Node = null
	var layer: int = 0

	func _draw() -> void:
		if is_instance_valid(stage):
			stage.call("_draw_stage_art", self, layer)


var _world: Node2D = null
var _backdrop: StageArt = null
var _table_back: StageArt = null
var _actors_root: Node2D = null
var _table_front: StageArt = null
var _actors: Dictionary = {}
var _generation: int = 0
var _active_tweens: Array[Tween] = []
var _camera_target: String = "center"


func _ready() -> void:
	_ensure_built()
	reset_stage()


func _ensure_built() -> void:
	if is_instance_valid(_world):
		return

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_backdrop = StageArt.new()
	_backdrop.name = "Backdrop"
	_backdrop.stage = self
	_backdrop.layer = 0
	# Keep every stage layer above the embedding Control's opaque panel.
	_backdrop.z_index = 0
	_world.add_child(_backdrop)

	_table_back = StageArt.new()
	_table_back.name = "TableBack"
	_table_back.stage = self
	_table_back.layer = 1
	_table_back.z_index = 1
	_world.add_child(_table_back)

	_actors_root = Node2D.new()
	_actors_root.name = "Actors"
	_world.add_child(_actors_root)

	for actor_id in ["gintoki", "shinpachi", "otose"]:
		var actor: Node2D = ACTOR_DOLL_SCRIPT.new() as Node2D
		actor.name = actor_id.capitalize()
		actor.call("setup", actor_id, false)
		actor.visible = false
		_actors_root.add_child(actor)
		_actors[actor_id] = actor

	_table_front = StageArt.new()
	_table_front.name = "TableFront"
	_table_front.stage = self
	_table_front.layer = 2
	# Sort the table at its front edge, so a near-side actor's face stays visible.
	_table_front.z_index = 385
	_world.add_child(_table_front)


## Resets the first-shot composition without rebuilding nodes.
func reset_stage() -> void:
	_ensure_built()
	cancel()

	_set_actor_state("gintoki", MARKERS["host"], true, "neutral", "left", false)
	_set_actor_state("shinpachi", MARKERS["reader"], true, "neutral", "right", false)
	_set_actor_state("otose", MARKERS["door"], false, "neutral", "left", false)
	_camera_target = "center"
	_world.position = Vector2.ZERO
	_world.scale = Vector2.ONE
	_refresh_depth()


## Executes one runner command.  Commands that animate yield until they finish
## or until cancel() advances the generation token, so a restart cannot strand
## a caller waiting on Tween.finished.
func perform(command: Dictionary) -> void:
	_ensure_built()
	var token := _generation
	var op := str(command.get("op", ""))

	match op:
		"show":
			var show_id := str(command.get("actor", ""))
			var show_actor := _actor_for(show_id)
			if show_actor == null:
				return
			var show_at: Variant = command.get("at", "")
			if show_at is String and not str(show_at).is_empty():
				show_actor.position = _resolve_marker(show_at, show_actor.position)
			show_actor.visible = true
			_set_depth(show_actor)
		"hide":
			var hide_actor := _actor_for(str(command.get("actor", "")))
			if hide_actor == null:
				return
			hide_actor.visible = false
			hide_actor.call("set_speaking", false)
			_set_depth(hide_actor)
		"move":
			var move_id := str(command.get("actor", ""))
			var move_actor := _actor_for(move_id)
			if move_actor == null:
				return
			var move_target := _resolve_marker(command.get("target", ""), move_actor.position)
			var move_duration := maxf(float(command.get("duration", 0.6)), 0.0)
			await _move_actor(move_id, move_actor, move_target, move_duration, token)
		"face":
			var face_actor := _actor_for(str(command.get("actor", "")))
			if face_actor != null:
				face_actor.call("set_facing", str(command.get("direction", "right")))
		"expression":
			var expression_actor := _actor_for(str(command.get("actor", "")))
			if expression_actor != null:
				expression_actor.call("set_expression", str(command.get("value", "neutral")))
		"camera":
			var zoom := clampf(float(command.get("zoom", 1.0)), 0.95, 1.15)
			var camera_duration := maxf(float(command.get("duration", 0.45)), 0.0)
			await _move_camera(str(command.get("target", "center")), zoom, camera_duration, token)
		"wait":
			await _wait_interruptible(maxf(float(command.get("duration", 0.0)), 0.0), token)
		# sound is intentionally consumed by main.gd; the stage stays silent and
		# remains safe to use in a scene that has no audio buses.
		"sound":
			return
		"_":
			return


func set_speaker(actor_id: String, expression: String = "neutral") -> void:
	_ensure_built()
	var requested := actor_id.to_lower()
	for id in _actors:
		var actor: Node2D = _actors[id] as Node2D
		if actor == null:
			continue
		var is_speaker: bool = id == requested and actor.visible
		actor.call("set_speaking", is_speaker)
		if is_speaker:
			actor.call("set_expression", expression)
			actor.modulate = Color.WHITE
		else:
			# A quiet, warm dim keeps the current speaker readable without hiding
			# the reaction silhouette of the other two characters.
			actor.modulate = Color(0.72, 0.68, 0.63, 1.0) if actor.visible else Color.WHITE


## Takes a purely declarative snapshot.  No motion is replayed by restore().
func snapshot() -> Dictionary:
	_ensure_built()
	var actor_states: Dictionary = {}
	for id in _actors:
		var actor: Node2D = _actors[id] as Node2D
		if actor == null:
			continue
		var doll_state: Dictionary = actor.call("get_state")
		actor_states[id] = {
			"position": actor.position,
			"visible": actor.visible,
			"expression": str(doll_state.get("expression", "neutral")),
			"facing": str(doll_state.get("facing", "right")),
			"speaking": bool(doll_state.get("speaking", false)),
			"modulate": actor.modulate,
		}
	return {
		"version": SNAPSHOT_VERSION,
		"actors": actor_states,
		"camera": {
			"position": _world.position,
			"zoom": _world.scale.x,
			"target": _camera_target,
		},
	}


func restore(state: Dictionary) -> void:
	_ensure_built()
	if int(state.get("version", -1)) != SNAPSHOT_VERSION:
		return
	var actor_states: Variant = state.get("actors", null)
	var camera_state: Variant = state.get("camera", null)
	if not actor_states is Dictionary or not camera_state is Dictionary:
		return

	cancel()
	for id in _actors:
		var saved: Variant = (actor_states as Dictionary).get(id, null)
		if not saved is Dictionary:
			continue
		var actor: Node2D = _actors[id] as Node2D
		if actor == null:
			continue
		actor.position = _as_vector2((saved as Dictionary).get("position", actor.position), actor.position)
		actor.visible = bool((saved as Dictionary).get("visible", actor.visible))
		actor.call("set_expression", str((saved as Dictionary).get("expression", "neutral")))
		actor.call("set_facing", str((saved as Dictionary).get("facing", "right")))
		actor.call("set_speaking", bool((saved as Dictionary).get("speaking", false)))
		actor.call("set_walking", false)
		var saved_modulate: Variant = (saved as Dictionary).get("modulate", Color.WHITE)
		if saved_modulate is Color:
			actor.modulate = saved_modulate

	var saved_camera := camera_state as Dictionary
	_world.position = _as_vector2(saved_camera.get("position", Vector2.ZERO), Vector2.ZERO)
	var saved_zoom := clampf(float(saved_camera.get("zoom", 1.0)), 0.95, 1.15)
	_world.scale = Vector2.ONE * saved_zoom
	_camera_target = str(saved_camera.get("target", "center"))
	_refresh_depth()


func cancel() -> void:
	_generation += 1
	for tween in _active_tweens.duplicate():
		if is_instance_valid(tween):
			tween.kill()
	_active_tweens.clear()
	for id in _actors:
		var actor: Node2D = _actors[id] as Node2D
		if actor != null:
			actor.call("set_walking", false)


func get_actor_state() -> Dictionary:
	_ensure_built()
	var result: Dictionary = {}
	for id in _actors:
		var actor: Node2D = _actors[id] as Node2D
		if actor == null:
			continue
		var doll_state: Dictionary = actor.call("get_state")
		result[id] = {
			"visible": actor.visible,
			"position": actor.position,
			"position_xy": {"x": actor.position.x, "y": actor.position.y},
			"x": actor.position.x,
			"y": actor.position.y,
			"expression": str(doll_state.get("expression", "neutral")),
			"facing": str(doll_state.get("facing", "right")),
			"speaking": bool(doll_state.get("speaking", false)),
			"walking": bool(doll_state.get("walking", false)),
		}
	return result


func _set_actor_state(id: String, at: Vector2, visible: bool, expression: String, facing: String, speaking: bool) -> void:
	var actor := _actor_for(id)
	if actor == null:
		return
	actor.position = at
	actor.visible = visible
	actor.call("set_expression", expression)
	actor.call("set_facing", facing)
	actor.call("set_speaking", speaking)
	actor.call("set_walking", false)
	actor.modulate = Color.WHITE


func _move_actor(id: String, actor: Node2D, target: Vector2, duration: float, token: int) -> bool:
	if not actor.visible:
		actor.visible = true

	var waypoints: Array[Vector2] = []
	if id == "shinpachi" and target.distance_to(MARKERS["other_side"]) < 2.0:
		# Reader -> left wall -> back edge -> far side of the low table.  This
		# route is intentionally visible in the 720 px composition and never cuts
		# through the ledger/dango props.
		waypoints = [
			Vector2(145.0, 495.0),
			Vector2(134.0, 302.0),
			Vector2(322.0, 286.0),
			target,
		]
	else:
		waypoints = [target]

	var total_distance := 0.0
	var previous := actor.position
	for point in waypoints:
		total_distance += previous.distance_to(point)
		previous = point
	if total_distance <= 0.1 or duration <= 0.0:
		actor.position = target
		_set_depth(actor)
		return token == _generation

	actor.call("set_walking", true)
	previous = actor.position
	for point in waypoints:
		if token != _generation:
			actor.call("set_walking", false)
			return false
		_set_facing_toward(actor, point - previous)
		var segment_duration := duration * previous.distance_to(point) / total_distance
		var reached := await _tween_actor_to(actor, point, segment_duration, token)
		if not reached:
			actor.call("set_walking", false)
			return false
		previous = point
	actor.call("set_walking", false)
	_set_depth(actor)
	return token == _generation


func _tween_actor_to(actor: Node2D, target: Vector2, duration: float, token: int) -> bool:
	if duration <= 0.0:
		actor.position = target
		_set_depth(actor)
		return token == _generation
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(actor, "position", target, duration)
	return await _await_tween(tween, token)


func _move_camera(target_name: String, zoom: float, duration: float, token: int) -> bool:
	var target := _resolve_camera_target(target_name)
	var destination := Vector2(360.0, 310.0) - target * zoom
	# A close-up pans within the room instead of revealing empty canvas edges.
	if zoom >= 1.0:
		destination.x = clampf(destination.x, DESIGN_SIZE.x * (1.0 - zoom), 0.0)
		destination.y = clampf(destination.y, DESIGN_SIZE.y * (1.0 - zoom), 0.0)
	else:
		destination = DESIGN_SIZE * (1.0 - zoom) * 0.5
	if duration <= 0.0:
		_world.position = destination
		_world.scale = Vector2.ONE * zoom
		_camera_target = target_name
		return token == _generation

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_world, "position", destination, duration)
	tween.parallel().tween_property(_world, "scale", Vector2.ONE * zoom, duration)
	var completed := await _await_tween(tween, token)
	if completed:
		_camera_target = target_name
	return completed


func _await_tween(tween: Tween, token: int) -> bool:
	var monitor := {"done": false}
	tween.finished.connect(func() -> void:
		monitor["done"] = true
	)
	_active_tweens.append(tween)
	while not bool(monitor["done"]):
		if token != _generation or not is_inside_tree():
			if is_instance_valid(tween):
				tween.kill()
			_active_tweens.erase(tween)
			return false
		await get_tree().process_frame
	_active_tweens.erase(tween)
	return token == _generation


func _wait_interruptible(duration: float, token: int) -> bool:
	if duration <= 0.0:
		return token == _generation
	if not is_inside_tree():
		return false
	var elapsed := 0.0
	var previous_usec := Time.get_ticks_usec()
	while elapsed < duration:
		if token != _generation:
			return false
		await get_tree().process_frame
		var now_usec := Time.get_ticks_usec()
		elapsed += float(now_usec - previous_usec) / 1000000.0
		previous_usec = now_usec
	return token == _generation


func _set_facing_toward(actor: Node2D, direction: Vector2) -> void:
	if absf(direction.x) >= absf(direction.y):
		actor.call("set_facing", "right" if direction.x >= 0.0 else "left")
	else:
		actor.call("set_facing", "down" if direction.y >= 0.0 else "up")


func _resolve_camera_target(target_name: String) -> Vector2:
	if target_name == "center" or target_name.is_empty():
		return MARKERS["center"]
	var actor := _actor_for(target_name)
	if actor != null and actor.visible:
		return actor.position + Vector2(0.0, -55.0)
	return MARKERS.get(target_name, MARKERS["center"])


func _resolve_marker(marker: Variant, fallback: Vector2) -> Vector2:
	if marker is Vector2:
		return marker
	if marker is Dictionary:
		return _as_vector2(marker, fallback)
	var key := str(marker)
	if MARKERS.has(key):
		return MARKERS[key]
	return fallback


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var data := value as Dictionary
		return Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)))
	if value is Array and (value as Array).size() >= 2:
		var values := value as Array
		return Vector2(float(values[0]), float(values[1]))
	return fallback


func _actor_for(id: String) -> Node2D:
	return _actors.get(id.to_lower(), null) as Node2D


func _set_depth(actor: Node2D) -> void:
	if actor != null:
		actor.z_index = int(roundf(actor.position.y))


func _refresh_depth() -> void:
	for id in _actors:
		_set_depth(_actors[id] as Node2D)


func _draw_stage_art(canvas: CanvasItem, layer: int) -> void:
	match layer:
		0:
			_draw_backdrop(canvas)
		1:
			_draw_table_back(canvas)
		2:
			_draw_table_front(canvas)


func _draw_backdrop(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0.0, 0.0, DESIGN_SIZE.x, DESIGN_SIZE.y), WOOD_DARK)
	canvas.draw_rect(Rect2(17.0, 16.0, 686.0, 588.0), WALL)

	# Warm wall paper with a lower wood dado.
	canvas.draw_rect(Rect2(20.0, 20.0, 680.0, 285.0), PAPER)
	canvas.draw_rect(Rect2(20.0, 295.0, 680.0, 18.0), WOOD)
	canvas.draw_rect(Rect2(20.0, 313.0, 680.0, 7.0), WOOD_DARK)

	# Tatami floor: broad quiet stripes and dark seams establish the room plane.
	canvas.draw_rect(Rect2(20.0, 320.0, 680.0, 284.0), TATAMI)
	for row in range(4):
		var y := 320.0 + float(row) * 71.0
		canvas.draw_rect(Rect2(20.0, y, 680.0, 1.5), Color("a1875b"))
		canvas.draw_line(Vector2(22.0, y + 3.0), Vector2(698.0, y + 3.0), TATAMI_LIGHT, 1.0, true)
	for column in range(3):
		var x := 190.0 + float(column) * 170.0
		canvas.draw_line(Vector2(x, 320.0), Vector2(x, 604.0), Color("a58a5e"), 2.0, true)
		canvas.draw_line(Vector2(x + 3.0, 320.0), Vector2(x + 3.0, 604.0), TATAMI_LIGHT, 1.0, true)

	# Heavy wooden frame and ceiling lintel.
	canvas.draw_rect(Rect2(14.0, 8.0, 692.0, 12.0), WOOD_DARK)
	canvas.draw_rect(Rect2(15.0, 24.0, 10.0, 580.0), WOOD_DARK)
	canvas.draw_rect(Rect2(695.0, 24.0, 10.0, 580.0), WOOD_DARK)
	canvas.draw_rect(Rect2(20.0, 24.0, 680.0, 9.0), WOOD)
	canvas.draw_rect(Rect2(20.0, 282.0, 680.0, 9.0), WOOD_LIGHT)

	_draw_window(canvas)
	_draw_door(canvas)
	_draw_wall_details(canvas)


func _draw_window(canvas: CanvasItem) -> void:
	var frame := Rect2(57.0, 69.0, 205.0, 171.0)
	canvas.draw_rect(frame.grow(8.0), WOOD_DARK)
	canvas.draw_rect(frame, WOOD)
	canvas.draw_rect(Rect2(66.0, 78.0, 187.0, 153.0), SKY)
	canvas.draw_rect(Rect2(66.0, 78.0, 187.0, 58.0), SKY_LIGHT)
	# A soft hill and cloud keep the window from reading as a flat blue tile.
	_canvas_poly(canvas, [
		Vector2(66.0, 188.0), Vector2(110.0, 151.0), Vector2(143.0, 183.0),
		Vector2(178.0, 145.0), Vector2(253.0, 198.0), Vector2(253.0, 231.0),
		Vector2(66.0, 231.0),
	], Color("87a99b"))
	_canvas_ellipse(canvas, Vector2(188.0, 110.0), Vector2(28.0, 9.0), Color(1.0, 1.0, 1.0, 0.38))
	canvas.draw_line(Vector2(159.0, 78.0), Vector2(159.0, 231.0), WOOD, 6.0, true)
	canvas.draw_line(Vector2(66.0, 154.0), Vector2(253.0, 154.0), WOOD, 6.0, true)
	canvas.draw_rect(Rect2(50.0, 64.0, 8.0, 185.0), WOOD_DARK)
	canvas.draw_rect(Rect2(261.0, 64.0, 8.0, 185.0), WOOD_DARK)
	# Plain curtains are a readable warm accent behind the actors.
	_canvas_poly(canvas, [
		Vector2(39.0, 57.0), Vector2(74.0, 57.0), Vector2(74.0, 174.0),
		Vector2(55.0, 203.0), Vector2(39.0, 192.0),
	], Color("d49a77"))
	_canvas_poly(canvas, [
		Vector2(246.0, 57.0), Vector2(281.0, 57.0), Vector2(281.0, 193.0),
		Vector2(264.0, 202.0), Vector2(246.0, 174.0),
	], Color("d49a77"))


func _draw_door(canvas: CanvasItem) -> void:
	var outer := Rect2(548.0, 54.0, 133.0, 252.0)
	canvas.draw_rect(outer.grow(9.0), WOOD_DARK)
	canvas.draw_rect(outer, WOOD)
	canvas.draw_rect(Rect2(559.0, 65.0, 111.0, 231.0), Color("9a6848"))
	for row in range(3):
		var y := 73.0 + float(row) * 73.0
		canvas.draw_rect(Rect2(570.0, y, 89.0, 56.0), Color("b17c55"))
		canvas.draw_rect(Rect2(575.0, y + 5.0, 79.0, 46.0), Color("a8724f"), false, 2.0)
	canvas.draw_line(Vector2(614.0, 65.0), Vector2(614.0, 296.0), WOOD_DARK, 3.0, true)
	canvas.draw_circle(Vector2(646.0, 181.0), 5.5, Color("e2bd67"))
	canvas.draw_circle(Vector2(645.0, 180.0), 2.0, INK)
	# Small entry mat gives the door actor a grounded arrival mark.
	_canvas_ellipse(canvas, Vector2(621.0, 325.0), Vector2(75.0, 13.0), Color("a7865e"))
	_canvas_ellipse(canvas, Vector2(621.0, 322.0), Vector2(67.0, 9.0), Color("d4b37a"))


func _draw_wall_details(canvas: CanvasItem) -> void:
	# A tiny hanging scroll ties the paper palette to the story's ledger motif.
	canvas.draw_rect(Rect2(405.0, 54.0, 90.0, 8.0), WOOD)
	canvas.draw_rect(Rect2(413.0, 62.0, 74.0, 128.0), Color("e8d7b0"))
	canvas.draw_rect(Rect2(421.0, 70.0, 58.0, 112.0), Color("f7edcf"))
	canvas.draw_line(Vector2(450.0, 88.0), Vector2(450.0, 162.0), Color("9c6d57"), 2.0, true)
	canvas.draw_circle(Vector2(450.0, 105.0), 6.0, RED)
	canvas.draw_line(Vector2(437.0, 126.0), Vector2(463.0, 126.0), INK, 2.0, true)
	canvas.draw_line(Vector2(437.0, 139.0), Vector2(463.0, 139.0), INK, 2.0, true)
	canvas.draw_rect(Rect2(400.0, 185.0, 101.0, 8.0), WOOD)


func _draw_table_back(canvas: CanvasItem) -> void:
	# Cushions and legs are behind the actors.  The front table layer is placed
	# above actors whose feet are on the far side, giving the room useful depth.
	_canvas_ellipse(canvas, Vector2(222.0, 503.0), Vector2(56.0, 16.0), Color("a98a5f"))
	_canvas_ellipse(canvas, Vector2(475.0, 447.0), Vector2(55.0, 15.0), Color("a98a5f"))
	canvas.draw_rect(Rect2(238.0, 358.0, 16.0, 125.0), WOOD_DARK)
	canvas.draw_rect(Rect2(482.0, 358.0, 16.0, 125.0), WOOD_DARK)
	canvas.draw_rect(Rect2(250.0, 371.0, 9.0, 111.0), WOOD_LIGHT)
	canvas.draw_rect(Rect2(477.0, 371.0, 9.0, 111.0), WOOD_LIGHT)
	canvas.draw_line(Vector2(251.0, 468.0), Vector2(492.0, 468.0), WOOD_DARK, 7.0, true)


func _draw_table_front(canvas: CanvasItem) -> void:
	# Low oval table with a distinct dark front edge, ledger, tea, and dango.
	_canvas_ellipse(canvas, Vector2(360.0, 383.0), Vector2(181.0, 30.0), Color(0.20, 0.12, 0.09, 0.24))
	_canvas_ellipse(canvas, Vector2(360.0, 353.0), Vector2(180.0, 34.0), WOOD_DARK)
	_canvas_ellipse(canvas, Vector2(360.0, 349.0), Vector2(170.0, 28.0), WOOD_LIGHT)
	_canvas_ellipse(canvas, Vector2(360.0, 345.0), Vector2(156.0, 22.0), Color("bc875b"))
	_canvas_poly(canvas, [
		Vector2(184.0, 349.0), Vector2(536.0, 349.0), Vector2(526.0, 382.0),
		Vector2(194.0, 382.0),
	], WOOD_DARK)
	canvas.draw_line(Vector2(201.0, 378.0), Vector2(519.0, 378.0), WOOD_LIGHT, 3.0, true)
	# Ledger on the left.
	_canvas_poly(canvas, [
		Vector2(292.0, 331.0), Vector2(361.0, 328.0), Vector2(366.0, 353.0),
		Vector2(296.0, 356.0),
	], Color("e9d8ad"))
	canvas.draw_line(Vector2(329.0, 330.0), Vector2(333.0, 354.0), Color("b7936a"), 1.5, true)
	for row in range(3):
		var y := 336.0 + float(row) * 5.0
		canvas.draw_line(Vector2(302.0, y), Vector2(355.0, y - 2.0), Color("92735e"), 1.0, true)
	# Dango skewer and three visible dumplings.
	canvas.draw_line(Vector2(421.0, 328.0), Vector2(480.0, 349.0), WOOD_DARK, 2.0, true)
	canvas.draw_circle(Vector2(433.0, 333.0), 8.0, Color("f1d1b4"))
	canvas.draw_circle(Vector2(451.0, 339.0), 8.0, Color("e69d83"))
	canvas.draw_circle(Vector2(469.0, 345.0), 8.0, Color("f1d1b4"))
	canvas.draw_circle(Vector2(433.0, 331.0), 2.0, Color(1.0, 1.0, 1.0, 0.45))
	canvas.draw_circle(Vector2(451.0, 337.0), 2.0, Color(1.0, 1.0, 1.0, 0.45))
	# Tea cup on a saucer to the right.
	_canvas_ellipse(canvas, Vector2(501.0, 350.0), Vector2(19.0, 6.0), Color("d9b985"))
	_canvas_ellipse(canvas, Vector2(501.0, 347.0), Vector2(13.0, 8.0), PAPER)
	_canvas_ellipse(canvas, Vector2(501.0, 345.0), Vector2(9.0, 5.0), TEA)
	canvas.draw_arc(Vector2(512.0, 347.0), 6.0, -1.2, 1.3, 10, PAPER, 2.0, true)


func _canvas_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color, segments: int = 24) -> void:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)


func _canvas_poly(canvas: CanvasItem, points: Array[Vector2], color: Color) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(point)
	canvas.draw_colored_polygon(packed, color)
