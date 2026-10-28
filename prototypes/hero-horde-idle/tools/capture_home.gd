extends SceneTree
## Screenshots of the home screen on every page, on a mid-game save (two stages cleared, 4 march slots, gear with
## affixes, a few 覺醒 heroes) kept aside from the player's save; a hero's detail, the offline report on arrival, a pull's result and
## the 行軍 strip mid-fight. Needs a display:
##   godot --path prototypes/hero-horde-idle --resolution 470x836 --script res://tools/capture_home.gd -- <out dir>
const Progression = preload("res://domain/progression.gd")
const Items = preload("res://domain/items.gd")
const Talents = preload("res://domain/talents.gd")
const Screenshot = preload("res://addons/proto_kit/screenshot.gd")
const HOME := "res://scenes/home.tscn"
const SAVE := "user://progress_home_shots.json"
const PAGES := [&"overview", &"train", &"backpack", &"heroes", &"adventure", &"store"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = Screenshot.out_dir()
	var p := Progression.new(7)
	p.cleared = 2
	p.march_stage = 3
	p.gold = 48200
	p.shards = 6
	p.stones = 24
	p.talent[Talents.SWORD] = 9
	p.talent[Talents.STAMINA] = 8
	p.talent[Talents.SPEED] = 2
	p.talent[Talents.COMPANY] = 1
	p.march = PackedInt32Array([13, 33, 99, 51])
	for i: int in [13, 33, 99, 51, 32]:
		p.hero_level[i] = 14
		p.ascension[i] = 1
	for id: String in [Items.weapon_id(1, 2), Items.weapon_id(0, 1), Items.charm_id(4)]:
		p.add_item(p.new_item(id))
	p.auto_equip()
	for id: String in [Items.weapon_id(1, 3), Items.charm_id(6), Items.weapon_id(4, 2), Items.charm_id(2), Items.weapon_id(2, 1),
			Items.charm_id(0), Items.weapon_id(5, 0), Items.weapon_id(3, 1)]:
		p.add_item(p.new_item(id))
	p.relic_stars[0] = 2
	p.relic_stars[2] = 1
	p.march_since = int(Time.get_unix_time_from_system()) - 3 * 3600 - 1200
	var home: Control = load(HOME).instantiate()
	home.progress = p
	home.save_path = SAVE
	root.add_child(home)
	await _frames(20)
	Screenshot.save(root, out, "00_offline")
	home.get_node("%Dialog").visible = false
	for k: int in 160:
		home.get_node("%MarchArena").step(1.0 / 30.0)
		await process_frame
	for tab: StringName in PAGES:
		home.show_tab(tab)
		await _frames(6)
		Screenshot.save(root, out, "%02d_%s" % [PAGES.find(tab) + 1, tab])
		if tab == &"heroes":
			home.get_node("%Heroes").open_detail(13)
			await _frames(4)
			Screenshot.save(root, out, "%02d_hero_detail" % (PAGES.find(tab) + 1))
			var heroes: Control = home.get_node("%Heroes")
			for pop: Array in [["%WeaponSlot", "equip"], ["%LevelButton", "level"], ["%StatsButton", "stats"]]:
				heroes.get_node(pop[0]).pressed.emit()
				await _frames(4)
				Screenshot.save(root, out, "%02d_hero_%s" % [PAGES.find(tab) + 1, pop[1]])
				heroes._close_popups()
			heroes.close_detail()
	home.show_tab(&"store")
	p.tickets = 10
	home.get_node("%Store")._card(1)
	await _frames(6)
	Screenshot.save(root, out, "08_pulls")
	DirAccess.remove_absolute(SAVE)
	quit()


func _frames(n: int) -> void:
	for k: int in n:
		await process_frame
