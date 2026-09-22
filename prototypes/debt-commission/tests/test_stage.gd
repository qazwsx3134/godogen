extends SceneTree

const StageScript = preload("res://scripts/story_stage.gd")
var stage: Node2D
var failures: int = 0
var cancelled_returned: bool = false


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _cancelled_move() -> void:
	await stage.perform({"op": "move", "actor": "shinpachi", "target": "reader", "duration": 2.0})
	cancelled_returned = true


func _run() -> void:
	# Fail with a nonzero exit if an animation coroutine never returns.
	create_timer(12.0).timeout.connect(func() -> void:
		push_error("Stage test timed out")
		quit(1)
	)
	stage = StageScript.new()
	root.add_child(stage)
	await process_frame
	var initial: Dictionary = stage.get_actor_state()
	_check(initial.gintoki.visible and initial.shinpachi.visible and not initial.otose.visible, "Opening cast visibility")
	var reader: Vector2 = initial.shinpachi.position
	await stage.perform({"op": "show", "actor": "otose", "at": "door"})
	var door: Vector2 = stage.get_actor_state().otose.position
	await stage.perform({"op": "move", "actor": "otose", "target": "landlady", "duration": 0.08})
	var arrived: Dictionary = stage.get_actor_state()
	_check(arrived.otose.visible and door.distance_to(arrived.otose.position) > 30.0, "Otose enters and approaches the table")
	await stage.perform({"op": "move", "actor": "shinpachi", "target": "other_side", "duration": 0.12})
	var crossed: Dictionary = stage.get_actor_state()
	_check(reader.distance_to(crossed.shinpachi.position) > 100.0, "Shinpachi changes sides")
	_check(not crossed.shinpachi.walking, "Walking stops when the command completes")
	await stage.perform({"op": "face", "actor": "shinpachi", "direction": "down"})
	stage.set_speaker("shinpachi", "annoyed")
	_check(stage.get_actor_state().shinpachi.expression == "annoyed", "Speaker expression applies")
	_check(stage.get_actor_state().shinpachi.speaking and not stage.get_actor_state().gintoki.speaking, "Only current speaker is emphasized")
	await stage.perform({"op": "camera", "target": "shinpachi", "zoom": 1.08, "duration": 0.03})
	var saved: Dictionary = stage.snapshot()
	# Use the same binary serialization as the game, including Vector2 and Color.
	var encoded: PackedByteArray = var_to_bytes(saved)
	stage.reset_stage()
	stage.restore(bytes_to_var(encoded))
	_check(stage.snapshot() == saved, "Save/restore keeps all actor and camera state")
	_cancelled_move()
	await process_frame
	stage.cancel()
	for frame in range(5):
		await process_frame
	_check(cancelled_returned, "Cancelling an active tween releases its awaiting caller")
	_check(not stage.get_actor_state().shinpachi.walking, "Cancel clears walking state")
	stage.reset_stage()
	_check(stage.get_actor_state().shinpachi.position == reader, "Restart restores opening position")
	_check(not stage.get_actor_state().otose.visible, "Restart hides Otose")
	stage.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: stage entrance, movement, speaker, camera, serialized restore and cancellation")
	quit(1 if failures else 0)
