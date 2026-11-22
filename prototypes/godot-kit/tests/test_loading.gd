extends "res://addons/proto_kit/test_kit.gd"
## tools/run_tests.sh prototypes/godot-kit loading

const LoadingScene = preload("res://addons/proto_kit/loading/loading_system.tscn")
const GameData = preload("res://addons/proto_kit/loading/game_data.gd")
const TARGET := "res://tests/fixtures/loading_target.tscn"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_loading()
	_test_game_data()
	_finish("LOADING TESTS")


func _test_loading() -> void:
	var ls: CanvasLayer = LoadingScene.instantiate()
	root.add_child(ls)
	ls._loader.min_show_time = 0.2
	var uid := ResourceUID.path_to_uid(TARGET)
	_expect(uid.begins_with("uid://"), "fixture has a uid")
	_expect(ls.resolve(uid) == TARGET, "uid resolves to path")
	_expect(ls.resolve("uid://doesnotexist") == "", "unknown uid -> empty")
	_expect(not await ls.go("res://nope.tscn"), "missing scene refused")
	_expect(not ls.is_busy() and ls.get_node("%Root").modulate.a == 0.0, "missing scene leaves screen hidden")
	var values: Array[float] = []
	ls.get_node("%Bar").value_changed.connect(func(v): values.append(v))
	ls.go(uid)
	_expect(ls.is_busy() and not ls.go(TARGET), "second go while busy refused")
	await _until(func(): return current_scene != null and current_scene.name == "LoadingTarget", "scene changed via uid")
	var mono := true
	for i in range(1, values.size()):
		mono = mono and values[i] >= values[i - 1]
	_expect(values.size() > 2 and mono and values[-1] == 100.0, "bar fills forward to 100")
	await _until(func(): return not ls.is_busy(), "fades out and frees input")
	_expect(ls.get_node("%Root").modulate.a == 0.0, "overlay faded out")
	ls.queue_free()


func _test_game_data() -> void:
	var path := "user://test_game_data.save"
	DirAccess.remove_absolute(path)
	var gd: Node = GameData.new()
	gd.save_path = path
	_expect(not gd.load_data() and gd.unlocked == 1, "no save -> defaults")
	gd.complete_level(1, 300)
	gd.complete_level(1, 100)
	gd.current_level = 2
	gd.save()
	var gd2: Node = GameData.new()
	gd2.save_path = path
	_expect(gd2.load_data(), "save loads")
	_expect(gd2.unlocked == 2 and gd2.is_unlocked(2) and not gd2.is_unlocked(3), "next level unlocked")
	_expect(gd2.best(1) == 300 and gd2.current_level == 2, "best score kept, current level saved")
	gd.free(); gd2.free()
	DirAccess.remove_absolute(path)
