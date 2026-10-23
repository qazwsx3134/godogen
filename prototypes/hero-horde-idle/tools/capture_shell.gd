extends SceneTree
## Screenshots of the home screen and the shell: the 離線戰報 on arrival, the 營地 (行軍 panel), the 養成 roster and a
## hero page, the 關卡 page, the 道具 page (armory, the march squad's charms, bag, an item, relics), the 招募 page
## (banner, a 十連's results, 商店, 機率說明), the 離線戰報 after 領取 (看廣告), the settings, the first push's hint and its pause menu, on a save with three stages cleared and 3 march hours banked (kept aside; the player's save and settings are never touched). Needs a display:
##   godot --path prototypes/hero-horde-idle --resolution 390x844 --script res://tools/capture_shell.gd -- <out dir>

const Progression = preload("res://domain/progression.gd")
const Settings = preload("res://domain/settings.gd")
const Items = preload("res://domain/items.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
const SAVE := "user://progress_shell_shots.json"

var _out: String


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_out = Screenshot.out_dir()
	var p := Progression.new()
	p.cleared = 3
	p.gold = 4820
	p.shards = 6
	p.class_level.fill(44)
	# 道具: some equipped, some in the bag (a few 新), two relics found.
	p.stones = 24
	for spec: Array in [[0, 2], [1, 1], [3, 0]]:
		p.add_item(Items.weapon_id(spec[0], spec[1]))
		p.equip_weapon(Items.weapon_id(spec[0], spec[1]))
	p.armory_level[0] = 8
	p.armory_level[1] = 5
	p.fresh.clear()
	for id: String in [Items.weapon_id(1, 3), Items.charm_id(6), Items.weapon_id(4, 2), Items.charm_id(4), Items.charm_id(2),
			Items.weapon_id(2, 1), Items.charm_id(3), Items.charm_id(0), Items.charm_id(0), Items.weapon_id(5, 0)]:
		p.add_item(id)
	p.fresh = PackedStringArray([Items.weapon_id(1, 3), Items.charm_id(4)])
	p.relic_stars[0] = 2
	p.relic_stars[1] = 1
	p.charm[p.march[0]] = 5
	p.charm[p.march[2]] = 2
	p.captains = PackedInt32Array([p.march[0], p.march[3]])
	p.tickets = 12
	p.pity = 7
	p.recent = PackedInt32Array([p.march[0], 30, 61, 75, 2])
	p.march_since = int(Time.get_unix_time_from_system()) - 3 * Progression.MARCH_SECONDS - 1500
	p.save(SAVE)
	var app: Node = root.get_node(^"App")
	app.progress_path = SAVE
	app.settings_path = "user://settings_shell_shots.json"
	app.settings = Settings.new()
	var store: Node = root.get_node(^"Store")
	store.test_file = "user://store_shell_shots.json"
	store.ad_seconds = 0.0
	change_scene_to_file("res://scenes/home.tscn")
	await _frames(10)
	await _shot("19_offline")
	var home: Node = current_scene
	home.find_child("OfflineReport", true, false).visible = false
	await _frames(330)
	await _shot("20_camp")
	home.find_child("CampPage", true, false).find_child("Claim", true, false).pressed.emit()
	await _shot("20b_claimed")
	home.show_tab(&"growth")
	home.find_child("GrowthPage", true, false).select_class(1)
	await _shot("21_roster")
	var growth: Node = home.find_child("GrowthPage", true, false)
	var shown: int = growth.find_child("Cards", true, false).get_child(0).hero
	app.progress().charm[shown] = 6  # an SSR charm on the hero page's 強度 line
	growth.select_hero(shown)
	await _shot("22_hero")
	growth.close_hero()
	home.show_tab(&"stages")
	await _shot("23_stages")
	home.show_tab(&"items")
	await _shot("27_items")
	var items: Node = home.find_child("ItemsPage", true, false)
	items.select({"kind": "item", "id": Items.weapon_id(1, 3)})
	await _shot("28_item_detail")
	items.select({"kind": "charm", "slot": 0})
	await _shot("28b_charm")
	items.show_tab(&"relic")
	await _shot("29_relics")
	home.show_tab(&"recruit")
	await _shot("30_recruit")
	var recruit: Node = home.find_child("RecruitPage", true, false)
	recruit.pull(10)
	await _shot("31_results")
	recruit.find_child("ResultsOverlay", true, false).visible = false
	recruit.find_child("ShopOverlay", true, false).visible = true
	await _shot("32_shop")
	recruit.find_child("ShopOverlay", true, false).visible = false
	recruit.find_child("RatesOverlay", true, false).visible = true
	await _shot("33_rates")
	recruit.find_child("RatesOverlay", true, false).visible = false
	home.show_tab(&"camp")
	app.progress().march_since = int(Time.get_unix_time_from_system()) - 2 * Progression.MARCH_SECONDS - 60
	home.find_child("OfflineReport", true, false).visible = true
	var offline_claim: Button = home.find_child("OfflineClaim", true, false)
	offline_claim.text = "領取"
	offline_claim.pressed.emit()
	await _shot("19b_offline_claimed")
	home.find_child("OfflineReport", true, false).visible = false
	home.find_child("SettingsOverlay", true, false).visible = true
	await _shot("24_settings")
	home.find_child("SettingsOverlay", true, false).visible = false
	home.find_child("CampPage", true, false).push(4)
	await _frames(40)
	current_scene.sim.skip_muster()
	await _frames(30)
	await _shot("25_hint")
	await _frames(30)
	current_scene.find_child("Hud", true, false).pause()
	await _shot("26_pause")
	paused = false
	DirAccess.remove_absolute(SAVE)
	DirAccess.remove_absolute("user://store_shell_shots.json")
	quit(0)


func _shot(moment: String) -> void:
	await _frames(4)
	Screenshot.save(root, _out, moment)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame
