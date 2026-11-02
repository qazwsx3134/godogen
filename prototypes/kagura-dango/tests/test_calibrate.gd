extends "res://addons/proto_kit/test_kit.gd"
## Calibration: taps 50 ms after each cowbell give an average of +50 ms; Apply needs 8 taps, saves it, and a reload
## reads it back. Uses a settings file in the temp dir, never the real user://.

const CALIBRATE := preload("res://scenes/calibrate.tscn")

var _t := 0.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.path = OS.get_temp_dir().path_join("kagura-dango-test-settings.cfg")
	DirAccess.remove_absolute(Settings.path)
	Settings.calib_ms = 0.0
	var screen := CALIBRATE.instantiate()
	screen.get_node("Conductor").clock = func(): return _t
	root.add_child(screen)
	screen.start()
	for beat in range(2, 9):
		_t = screen.conductor.beat_time(beat) + 0.05
		screen.tap()
	_expect(screen.get_node("%Apply").disabled, "Apply stays off below 8 taps")
	_t = screen.conductor.beat_time(9) + 0.05
	screen.tap()
	_t = screen.conductor.beat_time(10) + 0.3
	screen.tap()
	_expect(screen.samples.size() == 8, "a tap half a beat (0.3 s) from any beat is not a sample (got %d)" % screen.samples.size())
	_expect(absf(screen.average_ms() - 50.0) < 0.5, "average is +50 ms (got %.2f)" % screen.average_ms())
	_expect(not screen.get_node("%Apply").disabled, "Apply is on at 8 taps")
	await _frames(1)
	await _press(screen.get_node("%Apply"))
	await _frames(2)
	_expect(is_equal_approx(Settings.calib_ms, 50.0), "Apply sets 50 ms (got %.2f)" % Settings.calib_ms)
	Settings.calib_ms = 0.0
	Settings.load_all()
	_expect(is_equal_approx(Settings.calib_ms, 50.0), "the saved value reloads (got %.2f)" % Settings.calib_ms)
	_expect(Settings.file_path().begins_with(OS.get_temp_dir()), "the test never wrote user://")
	screen.queue_free()
	DirAccess.remove_absolute(Settings.path)
	_finish("CALIBRATE")
