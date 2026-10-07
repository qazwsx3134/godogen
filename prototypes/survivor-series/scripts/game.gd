extends Node
enum State { MENU, RUNNING, PAUSED, RESULTS, UPGRADE, SHOP }
@export var session_duration: float = 600.0
## Coins per kill, per surviving minute, and for a full-length win.
@export var coins_per_kill: float = 0.1
@export var coins_per_minute: int = 10
@export var win_bonus: int = 150
@export var coin_value: int = 5
@onready var street: Node2D = %Street
@onready var stick: Control = %Stick
@onready var menu: Control = %Menu
@onready var hud: Control = %Hud
@onready var results: Control = %Results
@onready var pause_panel: Control = %PausePanel
@onready var sfx: Node = %Sfx
@onready var upgrade_panel: Control = %UpgradePanel
@onready var shop: Control = %Shop
@onready var meta: Node = %Meta
var current_offers: Array[Resource] = []
var upgrade_generation: int = 0
var state: State = State.MENU
var elapsed: float = 0.0
var won: bool = false
var revivals: int = 0
var earned: int = 0
var fresh_unlocks: Array[Resource] = []
var auto_play: bool = false
var sound_events: Dictionary = {}
var _report_left: float = 0.0

func _ready() -> void:
	street.time_control = %TimeControl
	street.sfx = sfx
	street.score_changed.connect(refresh_hud)
	upgrade_panel.chosen.connect(choose_upgrade)
	sfx.played.connect(func(event: StringName) -> void: sound_events[event] = int(sound_events.get(event, 0)) + 1)
	menu.get_node("%Start").pressed.connect(start_run)
	menu.get_node("%OpenShop").pressed.connect(open_shop)
	shop.closed.connect(show_menu)
	results.get_node("%Retry").pressed.connect(start_run)
	results.get_node("%Home").pressed.connect(show_menu)
	hud.get_node("%Pause").pressed.connect(pause_run)
	pause_panel.get_node("%Resume").pressed.connect(resume_run)
	hud.get_node("%ShakeToggle").toggled.connect(set_shake_enabled)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--autoplay":
			auto_play = true
		if argument.begins_with("--duration="):
			session_duration = clampf(argument.get_slice("=", 1).to_float(), 0.3, 600.0)
		if argument.begins_with("--seed="):
			street.rng.seed = argument.get_slice("=", 1).to_int()
	show_menu()
	if auto_play:
		start_run()

func set_shake_enabled(enabled: bool) -> void:
	street.shake.shake_scale = 1.0 if enabled else 0.0
	if not enabled:
		street.shake.trauma = 0.0
		street.camera.offset = Vector2.ZERO
		street.camera.rotation = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_node_ready() and state == State.RUNNING and not auto_play:
			pause_run()

func _hide_screens() -> void:
	for screen: Control in [menu, results, pause_panel, upgrade_panel, shop]:
		screen.hide()

func start_run() -> void:
	get_tree().paused = false
	stick.release()
	street.meta_bonus = meta.bonuses()
	street.meta_unlocks = meta.unlocked
	street.reset()
	revivals = int(street.build.stat(&"revival"))
	current_offers.clear()
	elapsed = 0.0
	won = false
	earned = 0
	fresh_unlocks.clear()
	sound_events.clear()
	state = State.RUNNING
	_hide_screens()
	street.show()
	hud.show()
	stick.show()
	hud.get_node("%TimeBar").max_value = session_duration
	sfx.play(&"start")
	refresh_hud()

func show_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	stick.release()
	street.clear()
	current_offers.clear()
	_hide_screens()
	street.hide()
	hud.hide()
	stick.hide()
	menu.get_node("%Wallet").text = "金幣  %d  ·  最佳 %s" % [meta.coins, clock(float(meta.records.best_time))]
	menu.show()

func open_shop() -> void:
	state = State.SHOP
	_hide_screens()
	shop.present(meta)

func pause_run() -> void:
	if state != State.RUNNING:
		return
	state = State.PAUSED
	stick.release()
	%TimeControl.reset()
	get_tree().paused = true
	pause_panel.show()

func resume_run() -> void:
	if state != State.PAUSED:
		return
	stick.release()
	get_tree().paused = false
	state = State.RUNNING
	pause_panel.hide()

func finish_run(victory: bool) -> void:
	state = State.RESULTS
	won = victory
	get_tree().paused = false
	stick.release()
	stick.hide()
	hud.hide()
	var kills: int = street.kills
	var level: int = street.build.level
	earned = int(round((street.coins * coin_value + kills * coins_per_kill + floorf(elapsed / 60.0) * coins_per_minute + (win_bonus if victory else 0)) * (1.0 + street.build.stat(&"greed"))))
	fresh_unlocks = meta.record_run(elapsed, kills, level, victory, earned)
	results.get_node("%Title").text = "撐過十分鐘！" if victory else "倒下了…"
	results.get_node("%ResultStats").text = "存活 %s  ·  揍飛 %d\n最高連殺 %d  ·  成長到 Lv.%d\n獲得金幣 %d（共 %d）" % [clock(elapsed), kills, street.best_combo, level, earned, meta.coins]
	results.get_node("%BuildSummary").text = street.build.summary()
	var names: PackedStringArray = []
	for goal: Resource in fresh_unlocks:
		names.append("解鎖：%s" % goal.reward)
	results.get_node("%Unlocks").text = "\n".join(names)
	street.clear()
	_hide_screens()
	results.show()
	sfx.play(&"finish" if victory else &"death")

func _physics_process(delta: float) -> void:
	if state == State.UPGRADE and auto_play:
		choose_upgrade(current_offers[0].id)
		return
	if state != State.RUNNING:
		return
	var direction: Vector2 = stick.vector
	if auto_play:
		direction = autopilot()
	else:
		var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keyboard != Vector2.ZERO:
			direction = keyboard.normalized()
	elapsed = minf(session_duration, elapsed + delta)
	street.step(delta, direction, elapsed)
	refresh_hud()
	# Death wins over the clock, and the clock wins over queued level-ups.
	if street.player.hp <= 0.0:
		if revivals > 0:
			revivals -= 1
			street.player.revive(0.5)
			street.blast(street.player.position, 220.0, 9999.0, 2.0, Color("ffe08a"), "再來一碗！")
			sfx.play(&"heal")
		else:
			finish_run(false)
			return
	if elapsed >= session_duration:
		finish_run(true)
	elif street.build.pending_choices > 0:
		show_upgrades()

## Plays like a cautious human: closes in to punch, backs off when crowded or hurt, grabs gems when safe.
## Used for recordings and soak runs.
func autopilot() -> Vector2:
	var hero: Vector2 = street.player.position
	var near: Array = street.grid.query(hero, 150.0)
	var push := Vector2.ZERO
	var danger: int = 0
	for enemy: Node2D in near:
		var away: Vector2 = hero - enemy.position
		var weight: float = 1.0 - away.length() / 170.0
		if enemy.definition.kind in ["car", "fatty"] or enemy.elite or enemy.phase == "dash":
			weight *= 2.5
		if away.length() < 75.0:
			danger += 1
		push += away.normalized() * maxf(0.0, weight)
	for enemy: Node2D in street.enemies.get_children():
		if not enemy.dead and enemy.phase in ["warning", "dash"]:
			var lane: Vector2 = Geometry2D.get_closest_point_to_segment(hero, enemy.position, enemy.position + enemy.dash_direction * 650.0)
			if lane.distance_to(hero) < 60.0:
				push += (hero - lane).normalized() * 3.0
	for cloud: Node2D in street.hazards.get_children():
		var away: Vector2 = hero - cloud.position
		if away.length() < cloud.radius + 40.0:
			push += away.normalized() * 2.0
			danger += 1
	var hurt: bool = street.player.hp < street.player.hp_limit * 0.35
	var heading: Vector2
	if danger >= 3 or hurt or push.length() > 2.0:
		heading = push
	else:
		var gem: Node2D
		var best: float = 260.0
		for item: Node2D in street.pickups.get_children():
			var gap: float = item.position.distance_to(hero)
			if gap < best:
				best = gap
				gem = item
		var prey: Node2D = street.grid.nearest(hero, 600.0)
		if gem != null and danger == 0:
			heading = (gem.position - hero).normalized() + push * 0.6
		elif prey != null and prey.position.distance_to(hero) > 90.0:
			heading = (prey.position - hero).normalized() + push * 0.8
		else:
			heading = push
	heading += (street.bounds.get_center() - hero) / street.bounds.size * 0.6
	return heading.normalized() if heading.length() > 0.1 else Vector2.ZERO

func show_upgrades() -> void:
	current_offers = street.build.offers()
	if current_offers.is_empty():
		street.build.pending_choices = 0
		return
	state = State.UPGRADE
	upgrade_generation += 1
	stick.release()
	%TimeControl.reset()
	get_tree().paused = true
	upgrade_panel.present(street.build, current_offers, upgrade_generation)
	sfx.play(&"level", 0.1)

func choose_upgrade(id: StringName, generation: int = -1) -> bool:
	if state != State.UPGRADE or (generation >= 0 and generation != upgrade_generation):
		return false
	var chosen: Resource
	for item: Resource in current_offers:
		if item.id == id:
			chosen = item
	if chosen == null or not street.build.pick(id):
		return false
	if chosen.slot == "filler":
		if chosen.stat == &"heal":
			street.player.heal(chosen.per_level)
		elif chosen.stat == &"coins":
			street.coins += int(chosen.per_level)
	street.refresh_player_stats()
	current_offers.clear()
	upgrade_panel.hide()
	stick.release()
	get_tree().paused = false
	state = State.RUNNING
	sfx.play(&"evolve" if chosen.slot == "evolution" else &"upgrade", 0.1)
	refresh_hud()
	if street.build.pending_choices > 0:
		show_upgrades()
	return true

static func clock(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]

func refresh_hud() -> void:
	hud.get_node("%Time").text = clock(elapsed)
	hud.get_node("%Kills").text = "揍飛  %d" % street.kills
	hud.get_node("%Coins").text = "金幣  %d" % (street.coins * coin_value)
	hud.get_node("%TimeBar").value = elapsed
	if street.build != null:
		hud.get_node("%Level").text = "Lv.%d" % street.build.level
		hud.get_node("%Experience").max_value = street.build.threshold()
		hud.get_node("%Experience").value = street.build.experience
		hud.get_node("%Combo").text = "連續揍飛 ×%d" % street.combo if street.combo >= 2 else ""
		hud.get_node("%Build").text = street.build.summary()

func snapshot() -> Dictionary:
	var offers: Array[String] = []
	for item: Resource in current_offers:
		offers.append(String(item.id))
	return {"state": State.keys()[state], "elapsed": elapsed, "kills": street.kills, "hp": street.player.hp, "hits": street.hits_taken, "punches": street.arsenal.punches, "warnings": street.warnings, "smoke": street.smoke_spawns, "bursts": street.bursts_fired, "living": street.living_count(), "actors": street.enemies.get_child_count(), "effects": street.effects.get_child_count(), "hazards": street.hazards.get_child_count(), "projectiles": street.projectiles.get_child_count(), "pickups": street.pickups.get_child_count(), "combo": street.combo, "best_combo": street.best_combo, "level": street.build.level if street.build != null else 1, "weapons": street.build.weapons if street.build != null else [], "levels": street.build.levels if street.build != null else {}, "offers": offers, "player": [street.player.position.x, street.player.position.y], "stick": [stick.vector.x, stick.vector.y], "coins": meta.coins, "won": won, "sounds": sound_events}

func qa_layout() -> Dictionary:
	var layout: Dictionary = {}
	for entry: Array in [["start", menu.get_node("%Start")], ["shop", menu.get_node("%OpenShop")], ["pause", hud.get_node("%Pause")], ["resume", pause_panel.get_node("%Resume")], ["retry", results.get_node("%Retry")]]:
		var rect: Rect2 = entry[1].get_global_rect()
		layout[entry[0]] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var size: Vector2 = get_viewport().get_visible_rect().size
	var cards: Array = []
	for card: Control in upgrade_panel.options.get_children():
		var rect: Rect2 = card.get_global_rect()
		cards.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	layout["cards"] = cards
	layout["viewport"] = [size.x, size.y]
	return layout

func _process(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_report_left -= delta
	if _report_left <= 0.0:
		_report_left = 0.25
		# Read-only browser QA hook; no control or acceleration of production gameplay.
		JavaScriptBridge.eval("window.__survivorTelemetry = " + JSON.stringify(snapshot()))
		JavaScriptBridge.eval("window.__survivorLayout = " + JSON.stringify(qa_layout()))
		if state == State.RUNNING and JavaScriptBridge.eval("document.hidden"):
			pause_run()

func _exit_tree() -> void:
	get_tree().paused = false
