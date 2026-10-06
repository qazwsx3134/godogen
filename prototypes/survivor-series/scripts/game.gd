extends Node
enum State { MENU, RUNNING, PAUSED, RESULTS, UPGRADE }
@export var session_duration: float = 90.0
@onready var street: Node2D = %Street
@onready var stick: Control = %Stick
@onready var menu: Control = %Menu
@onready var hud: Control = %Hud
@onready var results: Control = %Results
@onready var pause_panel: Control = %PausePanel
@onready var sfx: Node = %Sfx
@onready var upgrade_panel: Control = %UpgradePanel
var current_offers: Array[Resource] = []
var upgrade_generation: int = 0
var state: State = State.MENU
var elapsed: float = 0.0
var auto_play: bool = false
var sound_events: Dictionary = {}
var _report_left: float = 0.0

func _ready() -> void:
	street.time_control = %TimeControl
	street.sfx = sfx
	street.score_changed.connect(refresh_hud)
	street.experience_gained.connect(gain_experience)
	upgrade_panel.chosen.connect(choose_upgrade)
	sfx.played.connect(func(event: StringName) -> void: sound_events[event] = int(sound_events.get(event, 0)) + 1)
	menu.get_node("%Start").pressed.connect(start_run)
	results.get_node("%Retry").pressed.connect(start_run)
	results.get_node("%Home").pressed.connect(show_menu)
	hud.get_node("%Pause").pressed.connect(pause_run)
	pause_panel.get_node("%Resume").pressed.connect(resume_run)
	hud.get_node("%ShakeToggle").toggled.connect(set_shake_enabled)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--autoplay":
			auto_play = true
		if argument.begins_with("--duration="):
			session_duration = clampf(argument.get_slice("=", 1).to_float(), 0.3, 90.0)
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
		if is_node_ready() and state == State.RUNNING:
			pause_run()

func start_run() -> void:
	get_tree().paused = false
	stick.release()
	street.reset()
	current_offers.clear()
	upgrade_panel.hide()
	elapsed = 0.0
	sound_events.clear()
	state = State.RUNNING
	menu.hide()
	results.hide()
	pause_panel.hide()
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
	upgrade_panel.hide()
	street.hide()
	hud.hide()
	stick.hide()
	results.hide()
	pause_panel.hide()
	menu.show()

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

func finish_run() -> void:
	state = State.RESULTS
	stick.release()
	stick.hide()
	hud.hide()
	street.clear()
	upgrade_panel.hide()
	current_offers.clear()
	results.get_node("%ResultStats").text = "揍飛 %d 個敵人  ·  最高連殺 %d\n受擊 %d 次  ·  出拳 %d 次\n成長到 Lv.%d" % [street.kills, street.best_combo, street.hits_taken, street.punches, street.build.level]
	results.get_node("%BuildSummary").text = street.build.summary()
	results.show()
	sfx.play(&"finish")

func _physics_process(delta: float) -> void:
	if state == State.UPGRADE and auto_play:
		choose_upgrade(current_offers[0].id)
		return
	if state != State.RUNNING:
		return
	var direction: Vector2 = stick.vector
	if auto_play:
		var target: Node2D = street.nearest_enemy()
		if target == null:
			var best: float = INF
			for enemy: Node2D in street.enemies.get_children():
				var gap: float = enemy.position.distance_to(street.player.position)
				if not enemy.dead and gap < best:
					target = enemy
					best = gap
		if target != null:
			direction = (target.position - street.player.position).normalized()
	else:
		var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keyboard != Vector2.ZERO:
			direction = keyboard.normalized()
	elapsed = minf(session_duration, elapsed + delta)
	street.step(delta, direction, elapsed)
	refresh_hud()
	if elapsed >= session_duration:
		finish_run()
	elif street.build.pending_choices > 0:
		show_upgrades()

func gain_experience(amount: int) -> void:
	if state != State.RUNNING:
		return
	street.build.award(amount)
	refresh_hud()

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
	var offered: bool = false
	for item: Resource in current_offers:
		if item.id == id:
			offered = true
	if not offered or not street.build.pick(id):
		return false
	current_offers.clear()
	upgrade_panel.hide()
	stick.release()
	get_tree().paused = false
	state = State.RUNNING
	sfx.play(&"upgrade", 0.1)
	refresh_hud()
	if street.build.pending_choices > 0:
		show_upgrades()
	return true

func refresh_hud() -> void:
	hud.get_node("%Time").text = "%02d 秒" % ceili(maxf(0.0, session_duration - elapsed))
	hud.get_node("%Kills").text = "揍飛  %d" % street.kills
	hud.get_node("%Hits").text = "受擊  %d" % street.hits_taken
	hud.get_node("%TimeBar").value = maxf(0.0, session_duration - elapsed)
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
	return {"state": State.keys()[state], "elapsed": elapsed, "kills": street.kills, "hits": street.hits_taken, "punches": street.punches, "warnings": street.warnings, "smoke": street.smoke_spawns, "living": street.living_count(), "actors": street.enemies.get_child_count(), "effects": street.effects.get_child_count(), "hazards": street.hazards.get_child_count(), "waves": street.projectiles.get_child_count(), "waves_fired": street.waves_fired, "kicks": street.kicks, "combo": street.combo, "best_combo": street.best_combo, "level": street.build.level if street.build != null else 1, "xp": street.build.experience if street.build != null else 0, "stacks": street.build.stacks if street.build != null else {}, "offers": offers, "player": [street.player.position.x, street.player.position.y], "stick": [stick.vector.x, stick.vector.y], "sounds": sound_events}

func qa_layout() -> Dictionary:
	var layout: Dictionary = {}
	for entry: Array in [["start", menu.get_node("%Start")], ["pause", hud.get_node("%Pause")], ["resume", pause_panel.get_node("%Resume")], ["retry", results.get_node("%Retry")]]:
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
