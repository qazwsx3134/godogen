extends "res://addons/proto_kit/test_kit.gd"
## Whole-run checks with the auto-player: a perfect run reaches the boss after 2-3 minutes of game time,
## the captain's finisher fires and the ending shows; doing nothing ends in game over with retry offered.
## Run with --fixed-fps 60 (tools/run_tests.sh <project> play:60).

const MAIN := preload("res://scenes/main.tscn")


func _init() -> void:
	_run.call_deferred()


func _game(bot: bool) -> Node:
	var main := MAIN.instantiate()
	main.bot = bot
	root.add_child(main)
	return main


func _run() -> void:
	root.size = Vector2i(640, 360)
	var main := _game(true)
	await _frames(2)
	main._start(false)
	await _until(func() -> bool: return main.state == main.S.BOSS, "bot reaches the boss", 240.0)
	_expect(main.t >= 150.0 and main.t < 180.0, "boss arrives after 2.5-3 min of game time (t=%.1f)" % main.t)
	_expect(main.hp > 0, "perfect play survives the run (hp=%d)" % main.hp)
	_expect(main.kills >= 10, "the run had titans to cut (kills=%d)" % main.kills)
	_expect(main.parries >= 5, "the run had rocks to parry (parries=%d)" % main.parries)
	await _until(func() -> bool: return main.state == main.S.LEVI, "a cut or parry triggers the finisher", 60.0)
	await _until(func() -> bool: return main.levi.visible, "the captain shows up", 5.0)
	await _until(func() -> bool: return main.state == main.S.ENDING, "finisher leads to the ending", 60.0)
	await _frames(60)
	_expect(main.screens.ending.visible, "ending screen is visible")
	_expect(main.beast.body.frame == main.beast.POSE_DOWN, "the boss is down")
	print("bot run: t=%.1f hp=%d kills=%d parries=%d perfects=%d score=%d" % [
		main.t, main.hp, main.kills, main.parries, main.perfects, main.score()])
	main.queue_free()
	await _frames(2)

	var idle := _game(false)
	await _frames(2)
	idle._start(false)
	await _until(func() -> bool: return idle.state == idle.S.OVER, "no input ends in game over", 120.0)
	_expect(idle.hp == 0, "three hits empty the lives")
	await _until(func() -> bool: return idle.screens.over.visible, "game over screen shows", 10.0)
	_expect(not idle.screens.boss_retry_button.visible, "no boss retry before reaching the boss")
	await _press(idle.screens.retry_button)
	await _frames(2)
	_expect(idle.state == idle.S.RUN and idle.hp == 3, "retry starts a fresh run")
	idle.queue_free()
	await _frames(2)

	var boss := _game(false)
	await _frames(2)
	boss._start(true)
	await _frames(2)
	_expect(boss.state == boss.S.BOSS, "boss checkpoint starts at the boss")
	await _until(func() -> bool: return boss.state == boss.S.OVER, "idle at the boss loses", 120.0)
	await _until(func() -> bool: return boss.screens.over.visible, "game over at boss", 10.0)
	_expect(boss.screens.boss_retry_button.visible, "boss retry offered after reaching the boss")
	_finish("PLAY")
