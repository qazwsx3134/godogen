extends "res://addons/proto_kit/test_kit.gd"
## The story layer and act 4 on the real main scene: the dialogue box blocks until tapped, subtitles and toasts do
## not, the title card and cutscenes hold the game clock, a cutscene borrows the camera and gives it back, triggers
## fire on arrival in route order, the bridge stays shut until the Haki and rises after it, and the act clears at
## the platform.

const FontCheck = preload("res://addons/proto_kit/font_check.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The scenes only: Madara's leftover jutsu data still writes a character the font lacks.
	var missing: String = FontCheck.missing_characters(load("res://ui/fonts/NotoSansTC.ttf"), "res://scenes/")
	_expect(missing.is_empty(), "the font has every character the story writes (missing: %s)" % missing)

	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.default_act = 4
	root.add_child(main)
	await _frames(1)
	main.player._invuln = 9999.0
	var story: StoryUi = main.story
	var act: Act = main.act
	_expect(act != null and act.number == 4, "act 4 loads by default")
	_expect(is_equal_approx(main.player.position.z, act.start_z), "the player starts at the act's start")
	_expect(act.get_node_or_null(^"Reference") == null, "the editor-only route reference is gone at run time")

	# Opening: the bridge sinks, the title card holds the clock.
	await _until(func() -> bool: return act.holds_game(), "the act begins after the warm-up")
	_expect(not main.route.bridge_open, "the bridge is shut at the start of act 4")
	var stop: Vector2 = main.route.clamp_move(Vector2(0.0, main.route.bridge_from + 0.5), Vector2(0.0, main.route.bridge_from - 2.0), 0.55)
	_expect(is_equal_approx(stop.y, main.route.bridge_from + 0.55), "a shut bridge stops the player at the crack (%s)" % stop)
	var held_at: float = main.elapsed
	await _frames(20)
	_expect(is_equal_approx(main.elapsed, held_at), "the title card holds the game clock")

	# The hormone cutscene takes the camera, then gives it back.
	await _until(func() -> bool: return main.rig.borrowed(), "the opening cutscene borrows the camera", 8.0)
	_expect(story.cinema_on(), "letterbox and skip show during a cutscene")
	await _until(func() -> bool: return story.line_visible(), "a cutscene line shows as a subtitle", 3.0)
	story.skip_pressed.emit()
	await _frames(2)
	_expect(not main.rig.borrowed() and not story.cinema_on(), "skip ends the cutscene and releases the camera")
	await _until(func() -> bool: return main.unlocked.get("hormone", false), "the hormone unlocks after the cutscene")
	await _until(func() -> bool: return story.toast_count() > 0, "Ivankov's toast slides in")
	await _until(func() -> bool: return not act.holds_game(), "the game resumes after the opening")
	await _frames(5)
	_expect(main.elapsed > held_at, "the game clock runs again")
	_expect(main.hud.get_node(^"%GoalLabel").text.begins_with("克比"), "the goal bar names the next trigger (%s)" % main.hud.get_node(^"%GoalLabel").text)

	# Coby: subtitle lines, the game keeps running.
	main.qa.skip_cutscenes = true
	main.player.position.z = -71.0
	await _until(func() -> bool: return story.line_visible(), "Coby's line shows")
	_expect(not act.holds_game(), "a subtitle does not hold the game")
	await _until(func() -> bool: return main._blockers.size() == 1, "Coby blocks the way")
	_expect(act.next_goal().name == "廣場", "the plaza is the next goal while Coby stands")
	await _knock(main._blockers[0])
	await _until(func() -> bool: return main._blockers.is_empty(), "Coby is knocked away")

	# Plaza: execution cutscene (skipped), the Haki, Whitebeard's toast, the bridge rises.
	main.player.position.z = -147.0
	await _until(func() -> bool: return main.ultimate.active(), "the Haki fires at the plaza", 8.0)
	await _until(func() -> bool: return main.route.bridge_open, "the bridge rises after the Haki", 10.0)
	var through: Vector2 = main.route.clamp_move(Vector2(0.0, main.route.bridge_from + 0.5), Vector2(0.0, main.route.bridge_from - 2.0), 0.55)
	_expect(is_equal_approx(through.y, main.route.bridge_from - 2.0), "the risen bridge is walkable")

	# Garp: the dialogue box holds the game until tapped (first tap finishes typing, second moves on).
	main.player.position.z = -227.0
	await _until(func() -> bool: return story.dialogue_open(), "Garp's dialogue opens")
	_expect(act.holds_game(), "dialogue holds the game")
	var clock: float = main.elapsed
	await _frames(10)
	_expect(is_equal_approx(main.elapsed, clock), "the clock stands still while Garp talks")
	story.tap()
	_expect(story.dialogue_open(), "the first tap only finishes the typing")
	story.tap()
	await _until(func() -> bool: return story.dialogue_open(), "Luffy's reply opens")
	story.tap()
	story.tap()
	await _until(func() -> bool: return main._blockers.size() == 1, "Garp stands in the way after the dialogue")
	_expect(not act.holds_game(), "the game runs while Garp blocks")
	await _knock(main._blockers[0])
	await _until(func() -> bool: return main._blockers.is_empty(), "Garp is knocked away")

	# Platform: golden fist (skipped), the act clears.
	main.player.position.z = -250.0
	await _until(func() -> bool: return main.finished, "the act clears at the platform", 8.0)
	_expect(act.done, "the act is done")
	_expect(main.hud.result_open(), "the result screen shows")
	main.queue_free()
	await _frames(2)
	_finish("STORY")


## Strikes a blocker until it goes down (spacing the hits past its recovery).
func _knock(blocker: Node3D) -> void:
	while not blocker.is_down():
		blocker.set(&"_recover", 0.0)
		blocker.take_strike(10.0, Vector2(0.0, -1.0))
		await _frames(1)
