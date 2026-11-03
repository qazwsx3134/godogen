extends "res://addons/proto_kit/test_kit.gd"
## godot --headless --path . --script res://tests/test_song_clock.gd

const SongClock = preload("res://addons/proto_kit/song_clock.gd")
const GUARD := preload("res://addons/proto_kit/orientation_guard.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var c: Node = SongClock.new()
	root.add_child(c)
	c.load_song({bpm = 120.0, offset = 0.5, music = "res://missing.mp3"})
	_expect(is_equal_approx(c.beat_time(4.0), 2.5), "beat 4 at 120 bpm, offset 0.5 = 2.5 s")
	_expect(is_equal_approx(c.beat_at(2.5), 4.0), "beat_at inverts beat_time")
	_expect(not c.playing() and c.time() < 0.0, "stopped: time -1")
	c.play()
	_expect(c.playing() and c.time() >= 0.0, "plays without a stream (wall clock)")
	await _frames(3)
	var t1: float = c.time()
	await _frames(3)
	_expect(c.time() >= t1, "never goes backwards")
	c.stop()
	_expect(not c.playing(), "stop")
	var fake := [3.0]
	c.clock = func(): return fake[0]
	_expect(c.time() == 3.0, "injected clock wins")

	var g: CanvasLayer = GUARD.instantiate()
	root.add_child(g)
	await _frames(1)
	_expect(not g.visible, "desktop: guard stays hidden")
	_expect(g.wrong_way(Vector2(390, 844)) and not g.wrong_way(Vector2(844, 390)), "landscape guard: portrait is wrong")
	g.want_landscape = false
	_expect(g.wrong_way(Vector2(844, 390)), "portrait guard: landscape is wrong")
	_finish("song_clock")
