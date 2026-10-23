extends "res://addons/proto_kit/test_kit.gd"
## The game shell driven like a player through the App autoload's real scene changes, on its own progress and
## settings files: the home screen's 營地 page (next stage card) and nav bar (營地／養成／關卡, the 關卡 page with
## only 1-1 open), 設定 (音效 and 震動, applied and saved), 推王 into 1-1, 暫停 and 繼續, 撤退回營地 (the push does
## not count), a won push and 回營地 (1-2 is next, 1-1 shows 已通關), the 養成 page and its hero page (above the nav
## bar), the 道具 page with the boss's drop, 前往養成 from a result; coming back after 3 hours away (the 離線戰報 pays the march).
##   godot --headless --path prototypes/hero-horde-idle --script res://tests/test_shell.gd

const Progression = preload("res://domain/progression.gd")
const Settings = preload("res://domain/settings.gd")
const SAVE_TEST := "user://progress_test_shell.json"
const SETTINGS_TEST := "user://settings_test_shell.json"

var app: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(720, 1280)
	DirAccess.remove_absolute(SAVE_TEST)
	DirAccess.remove_absolute(SETTINGS_TEST)
	app = root.get_node(^"App")
	app.progress_path = SAVE_TEST
	app.settings_path = SETTINGS_TEST
	app.settings = Settings.new()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _until(func() -> bool: return _scene_is("Home"), "the game opens on the home screen")
	var home: Node = current_scene
	var camp: Node = home.find_child("CampPage", true, false)
	_expect(home.tab == &"camp" and camp.visible, "it opens on the 營地 page")
	_expect(camp.find_child("StageLabel", true, false).text == "1-1", "a new save's next stage is 1-1")
	var pixel: Material = preload("res://ui/pixel_sharp.tres")
	_expect(camp.find_child("Push", true, false).material == pixel and home.find_child("NavCamp", true, false).material == pixel,
		"buttons draw their pixel frames with even-width pixels (scripts/pixel_ui.gd)")
	_expect(Settings.new().quality == 1, "畫質 defaults to 標準")
	await _frames(2)
	_expect(camp.find_child("Push", true, false).get_global_rect().end.y <= home.find_child("NavBar", true, false).get_global_rect().position.y + 1.0,
		"the 營地 fits above the nav bar on a 16:9 screen")
	await _press(home.find_child("NavStages", true, false))
	_expect(home.tab == &"stages" and not camp.visible, "the 關卡 tab shows the stage page")
	var rows: Array = _rows(home)
	_expect(rows.size() == 10, "the stage page lists all 10 stages")
	_expect(not rows[0].disabled and rows[1].disabled, "only 1-1 is open")
	await _press(home.find_child("NavCamp", true, false))
	_expect(Progression.load_from(SAVE_TEST).march_since > 0, "the first visit starts the march clock and saves it")

	# The 行軍 view fights on its own: a monster comes, falls, gold pops.
	var view: Node = camp.find_child("MarchView", true, false)
	for k: int in 200:
		view.step(0.1)
	_expect(view.kills >= 1 and camp.find_child("KillLabel", true, false).text.contains(str(view.kills)),
		"the 行軍小隊 beats monsters on its own (%d in 20 s)" % view.kills)
	# 待辦 and the nav bar's dot: gold to spend shows on both; a 待辦 row opens its page.
	app.progress().gold = 500
	camp.refresh()
	home.update_dots()
	var todo: Node = camp.find_child("TodoList", true, false)
	_expect(todo.get_child(0).visible and todo.get_child(0).text.contains("職業等級"), "待辦 says a class can level up")
	_expect(home.find_child("NavGrowth", true, false).get_node(^"Dot").visible, "the 養成 tab wears a red dot")
	await _press(todo.get_child(0))
	_expect(home.tab == &"growth", "the 待辦 row opens the 養成 page")
	app.progress().gold = 0
	await _press(home.find_child("NavCamp", true, false))

	await _press(camp.find_child("SettingsButton", true, false))
	_expect(camp.find_child("SettingsOverlay", true, false).visible, "設定 opens the settings")
	(camp.find_child("SfxSlider", true, false) as HSlider).value = 0.3
	await _press(camp.find_child("Haptics", true, false))
	var saved: RefCounted = Settings.load_from(SETTINGS_TEST)
	_expect(is_equal_approx(saved.sfx, 0.3) and not saved.haptics, "音效 and 震動 are saved")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.3)), "音效 sets the volume")
	await _press(camp.find_child("QualityChoices", true, false).get_child(0))
	await _press(camp.find_child("FpsChoices", true, false).get_child(0))
	saved = Settings.load_from(SETTINGS_TEST)
	_expect(saved.quality == 0 and saved.fps == 30 and is_equal_approx(root.scaling_3d_scale, Settings.QUALITY_SCALE[0])
		and Engine.max_fps == 30, "畫質 省電 and 幀率 30 apply and are saved")
	await _press(camp.find_child("QualityChoices", true, false).get_child(1))
	await _press(camp.find_child("FpsChoices", true, false).get_child(1))
	await _press(camp.find_child("Close", true, false))

	await _press(camp.find_child("Push", true, false))
	await _until(func() -> bool: return _scene_is("Main"), "推王 goes to the push")
	var main: Node = current_scene
	await _frames(3)
	_expect(main.pushing == 1 and not main.haptics.enabled, "the push is 1-1, with 震動 off as set")
	var hud: Node = main.find_child("Hud", true, false)
	await _press(hud.find_child("Pause", true, false))
	_expect(paused and hud.find_child("PauseMenu", true, false).visible, "‖ pauses the push")
	var t: float = main.sim.muster_t
	await _frames(5)
	_expect(main.sim.muster_t == t, "nothing moves while paused")
	await _press(hud.find_child("Resume", true, false))
	_expect(not paused, "繼續 resumes")
	await _press(hud.find_child("Pause", true, false))
	await _press(hud.find_child("Retreat", true, false))
	await _until(func() -> bool: return _scene_is("Home") and current_scene.tab == &"camp", "撤退 goes back to the 營地")
	_expect(not paused and Progression.load_from(SAVE_TEST).pushes == 0, "a retreat does not count as a push")

	await _press(current_scene.find_child("Push", true, false))
	await _until(func() -> bool: return _scene_is("Main"), "推王 again")
	main = current_scene
	await _frames(3)
	main.sim.skip_muster()
	main.sim.boss_hp = 1.0
	hud = main.find_child("Hud", true, false)
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "the push is won")
	await _press(hud.find_child("ResultCamp", true, false))
	await _until(func() -> bool: return _scene_is("Home") and current_scene.tab == &"camp", "回營地 after the result")
	home = current_scene
	_expect(home.find_child("CampPage", true, false).find_child("StageLabel", true, false).text == "1-2",
		"1-2 is next after 1-1 falls")
	await _press(home.find_child("NavStages", true, false))
	rows = _rows(home)
	_expect(rows[0].find_child("StateLabel", true, false).text == "已通關" and not rows[1].disabled, "1-1 shows 已通關 and 1-2 opens")

	await _press(home.find_child("NavGrowth", true, false))
	var growth: Node = home.find_child("GrowthPage", true, false)
	_expect(home.tab == &"growth" and growth.visible, "the 養成 tab shows the growth page")
	await _press(growth.find_child("Cards", true, false).get_child(0))
	_expect(home.find_child("NavBar", true, false).visible and growth.find_child("HeroPage", true, false).visible,
		"a hero page opens with the nav bar still under it")
	await _frames(2)
	var ascend: Control = growth.find_child("Ascend", true, false)
	_expect(ascend.get_global_rect().end.y <= home.find_child("NavBar", true, false).get_global_rect().position.y + 1.0,
		"the hero page's buttons sit above the nav bar (%s vs %s)" % [ascend.get_global_rect(),
		home.find_child("NavBar", true, false).get_global_rect()])
	await _press(growth.find_child("Back", true, false))
	# 道具: the won push dropped an item into the bag; the page fits above the nav bar.
	await _press(home.find_child("NavItems", true, false))
	var items: Node = home.find_child("ItemsPage", true, false)
	await _frames(2)
	_expect(home.tab == &"items" and items.visible and app.progress().bag.size() == 1,
		"the 道具 tab shows the bag with the boss's drop (%s)" % str(app.progress().bag))
	_expect(items.find_child("Detail", true, false).get_global_rect().end.y <= home.find_child("NavBar", true, false).get_global_rect().position.y + 1.0,
		"the 道具 page sits above the nav bar")

	# 前往養成 from a result opens the home on the 養成 page.
	await _press(home.find_child("NavCamp", true, false))
	await _press(home.find_child("Push", true, false))
	await _until(func() -> bool: return _scene_is("Main"), "推王 once more")
	main = current_scene
	await _frames(3)
	main.sim.skip_muster()
	main.sim.t = main.sim.DURATION - 0.01
	hud = main.find_child("Hud", true, false)
	await _until(func() -> bool: return hud.find_child("Result", true, false).visible, "the push times out")
	await _press(hud.find_child("GoGrow", true, false))
	await _until(func() -> bool: return _scene_is("Home") and current_scene.tab == &"growth", "前往養成 lands on the 養成 page")

	# Back after 3 hours away: the 離線戰報 opens on arrival and pays the march hours.
	var away := Progression.load_from(SAVE_TEST)
	away.march_since = int(Time.get_unix_time_from_system()) - 3 * Progression.MARCH_SECONDS - 10
	var gold: int = away.gold
	away.save(SAVE_TEST)
	app.reload_progress()
	change_scene_to_file("res://scenes/home.tscn")
	await _until(func() -> bool: return _scene_is("Home") and current_scene.is_node_ready(), "the home again")
	await _frames(2)
	camp = current_scene.find_child("CampPage", true, false)
	var report: Control = camp.find_child("OfflineReport", true, false)
	_expect(report.visible and camp.find_child("OfflineText", true, false).text.contains("3 小時"), "the 離線戰報 says 3 hours")
	await _press(camp.find_child("OfflineClaim", true, false))
	var lines: Array = camp.find_child("ResourcesGrid", true, false).get_children()
	_expect(camp.find_child("OfflineScroll", true, false).visible and lines.size() >= 2
		and lines[0].find_child("RowName", true, false).text == "金幣"
		and camp.find_child("HeroesGrid", true, false).get_child_count() == 5,
		"領取 lists what came back: 金幣 and 強化石 first, the 5 march heroes' levels")
	var panel: Control = report.find_child("Panel", true, false)
	_expect(panel.get_global_rect().end.y <= 1280 - 116 + 1 and panel.get_global_rect().position.y >= 0,
		"the dialog fits the screen (%s)" % panel.get_global_rect())
	var back: RefCounted = Progression.load_from(SAVE_TEST)
	_expect(back.gold > gold and back.march_hours(int(Time.get_unix_time_from_system())) == 0, "the hours are paid and saved")
	await _press(camp.find_child("OfflineClaim", true, false))
	_expect(not report.visible and (camp.find_child("Claim", true, false) as Button).disabled, "好 closes it; nothing left to claim")
	DirAccess.remove_absolute(SAVE_TEST)
	DirAccess.remove_absolute(SETTINGS_TEST)
	_finish("SHELL TESTS")


## The stage page's rows (its region headings left out).
func _rows(home: Node) -> Array:
	return home.find_child("StageList", true, false).get_children().filter(func(n: Node) -> bool: return n is Button)


func _scene_is(name: String) -> bool:
	return current_scene != null and current_scene.name == name and not app.busy()
