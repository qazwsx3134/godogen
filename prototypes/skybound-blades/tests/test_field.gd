extends "res://addons/proto_kit/test_kit.gd"
## The field scene end to end: real input events, HUD buttons, views and the run lifecycle.
## Run with game time: prototypes/godot-kit/tools/run_tests.sh prototypes/skybound-blades field:60

const FIELD := "res://scenes/field.tscn"
const SAVE := "user://test_field/save.json"
const SaveService = preload("res://domain/save_service.gd")

var field: Node3D
var _user_files_before: PackedStringArray


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_user_files_before = _user_files()
	root.size = Vector2i(1440, 900)
	field = load(FIELD).instantiate()
	field.save_path = SAVE
	SaveService.new(SAVE).erase()
	root.add_child(field)
	await _frames(3)
	# Hit stops run on the wall clock; under --fixed-fps that would slow many test frames. Use frames.
	field.time_control.clock = func() -> int: return Engine.get_process_frames() * 1000 / 60
	await test_field_layout_reads_the_authored_scene()
	await test_field_cast_visual_obeys_simulation_duration()
	test_field_uses_reviewed_art_resources()
	# The party starts in the safe camp; the combat cases below happen out in the field.
	for m: RefCounted in field.battle.party():
		m.pos = Vector2(-4.0, 0.0) + Vector2(m.id * 0.9, 0.0)
	await _frames(2)
	await test_field_click_monster_chases_and_kills()
	await test_field_walk_animation_advances()
	await test_field_hud_auto_button_toggles_auto_hunt()
	field.profile.warehouse_gold = 77  # must survive the death
	await test_field_leader_down_shows_end_and_keeps_rendering()
	await test_field_restart_resets_the_run()
	test_field_preferences_apply_and_survive_reload()
	test_field_saves_only_its_own_file()
	test_field_failed_save_warns_and_retries_soon()
	test_field_expedition_status_matches_risk()
	await test_field_death_failure_retries_before_next_generation()
	await test_field_phone_screen_scales_ui_and_fills_camp()
	SaveService.new(SAVE).erase()
	DirAccess.remove_absolute("user://test_field")
	_finish("FIELD")


func _battle() -> RefCounted:
	return field.battle


func _sim_frames(count: int) -> void:
	await _frames(count)


func test_field_layout_reads_the_authored_scene() -> void:
	var b := _battle()
	var monster_views: Array = field.get_node("%Monsters").get_children()
	_expect(b.monsters().size() == monster_views.size() and monster_views.size() >= 6, "layout: one unit per placed monster")
	var first: Node3D = monster_views[0]
	var unit: RefCounted = b.unit(field.views.find_key(first))
	_expect(unit.spawn.distance_to(Vector2(first.global_position.x, first.global_position.z)) < 0.01,
		"layout: a monster spawns where it stands in field.tscn")
	_expect(b.obstacles.size() >= 10, "layout: props with block_radius become obstacles (%d)" % b.obstacles.size())
	var cluster: Control = field.get_node("HUD").get_node("%ActionCluster")
	_expect(is_equal_approx(cluster.anchor_left, 0.5) and is_equal_approx(cluster.offset_left, -238.0) and is_equal_approx(cluster.offset_bottom, -44.0),
		"layout: HUD offsets stay as saved in hud.tscn")


func test_field_click_monster_chases_and_kills() -> void:
	var b := _battle()
	# Stand a slime up-left of the leader: clear of the HUD's action cluster (bottom-right).
	var target: RefCounted = b.monsters()[0]
	target.pos = b.leader.pos + Vector2(-2.5, -3.0)
	target.spawn = target.pos
	await _frames(2)
	var view: Node3D = field.views[target.id]
	var at: Vector2 = field.camera.unproject_position(view.global_position + Vector3(0, 0.8, 0))
	await _tap(at)
	_expect(b.leader.target_id == target.id, "click: tapping a monster locks it (target %d, got %d)" % [target.id, b.leader.target_id])
	var kills: int = b.kills
	for i in 60 * 30:
		await process_frame
		if b.kills > kills:
			break
	_expect(b.kills > kills, "click: the party kills the clicked monster with auto off")
	_expect(not b.auto_hunt, "click: auto hunt stayed off")


func test_field_walk_animation_advances() -> void:
	var b := _battle()
	var leader_view: Node3D = field.views[b.leader.id]
	await _tap(field.camera.unproject_position(Vector3(b.leader.pos.x + 2.5, 0, b.leader.pos.y + 2.5)))
	await _frames(30)
	var visual: Node3D = leader_view.get_node("Visual")
	var t0: float = visual.ticks
	await _frames(12)
	_expect(visual.anim == &"walk", "anim: a moving leader plays walk (got %s)" % visual.anim)
	_expect(visual.ticks - t0 > 8.0, "anim: walk frames advance instead of restarting (%.1f ticks)" % (visual.ticks - t0))


func test_field_hud_auto_button_toggles_auto_hunt() -> void:
	var hud: CanvasLayer = field.get_node("HUD")
	var button: BaseButton = hud.get_node("%AutoButton")
	await _press(button)
	await _frames(2)
	_expect(_battle().auto_hunt, "hud: the auto button turns auto hunt on")
	await _press(button)
	await _frames(2)
	_expect(not _battle().auto_hunt, "hud: pressing again turns it off")


func test_field_leader_down_shows_end_and_keeps_rendering() -> void:
	var b := _battle()
	b.auto_potion = false
	b.leader.hp = 1.0
	b.guardian.alive = false
	b.support.alive = false
	var hound: RefCounted = null
	for m: RefCounted in b.monsters():
		if m.alive:
			hound = m
			break
	hound.pos = b.leader.pos + Vector2(1.0, 0.0)
	hound.target_id = b.leader.id
	for i in 60 * 10:
		await process_frame
		if b.ended:
			break
	_expect(b.ended, "death: the run ends when the leader falls")
	await _frames(5)
	var hud: CanvasLayer = field.get_node("HUD")
	_expect(hud.get_node("%EndPanel").visible, "death: the end panel shows")
	var visual: Node3D = field.views[b.leader.id].get_node("Visual")
	var flash: float = visual.flash
	await _frames(20)
	_expect(visual.anim == &"down", "death: the leader shows the down pose")
	_expect(visual.flash < flash or flash == 0.0, "death: the view keeps updating after the end (flash fades)")


func test_field_restart_resets_the_run() -> void:
	var hud: CanvasLayer = field.get_node("HUD")
	await _press(hud.get_node("%RestartButton"))
	await _frames(3)
	var b := _battle()
	_expect(not b.ended and b.level == 1 and b.gold == 0 and b.kills == 0, "next generation: a fresh run")
	_expect(b.run.generation == 2 and field.profile.memorial.size() == 1, "next generation: generation 2, one memorial entry")
	_expect(int(b.inventory.tonic_small) == 5 and b.leader.hp == b.leader.max_hp, "next generation: issued supplies and full HP")
	_expect(b.in_camp(b.leader), "next generation: starts in camp")
	_expect(not hud.get_node("%EndPanel").visible, "next generation: end panel hidden")
	_expect(field.profile.warehouse_gold == 77, "next generation: the warehouse survived")
	var doc: Dictionary = SaveService.new(SAVE).load_state()
	_expect(doc.run is Dictionary and String(doc.run.id) == b.run.id, "next generation: saved as the live run")


func test_field_saves_only_its_own_file() -> void:
	_expect(FileAccess.file_exists(SAVE), "save: the field writes its save file")
	var expected := _user_files_before.duplicate()
	if not "test_field/" in expected:
		expected.append("test_field/")
	var now := _user_files()
	now.sort()
	expected.sort()
	_expect(now == expected, "save: nothing else appears in user:// (%s)" % [now])


func test_field_failed_save_warns_and_retries_soon() -> void:
	# Arrange: a save path under the save *file*, so its folder cannot be made
	var good: RefCounted = field.save_service
	field.save_service = SaveService.new(SAVE + "/blocked.json")
	# Act
	var err: Error = field.save_game()
	# Assert
	_expect(err != OK and String(field.hud._feed_lines[0].text).contains("存檔失敗") and field._save_left <= field.SAVE_RETRY,
		"save: a failed write warns the player and retries soon (%s)" % error_string(err))
	field.save_service = good
	_expect(field.save_game() == OK and field._save_left == field.autosave_seconds, "save: the next good write resets the timer")


func test_field_phone_screen_scales_ui_and_fills_camp() -> void:
	# Arrange: an 844x390 landscape phone (CSS px; headless has a device pixel ratio of 1)
	root.size = Vector2i(844, 390)
	field.fit_screen()
	field.battle.run.make_gear("novice_sword", "rare")
	field.open_camp("裝備")
	await _frames(2)
	# Act
	var panel: Control = field.hud.get_node("%CampLayer/CampPanel")
	var visible := field.get_viewport().get_visible_rect()
	var row: Control = null
	for r: Control in panel.get_node("Rows/CampTabs/裝備/List").get_children():
		if r.visible and r._row.has("more"):
			row = r
	# Assert
	_expect(is_equal_approx(root.content_scale_factor, 900.0 / field.phone_design_height),
		"phone: the UI is drawn for a %d-high screen" % int(field.phone_design_height))
	_expect(visible.encloses(panel.get_global_rect()) and panel.size.x > visible.size.x * 0.9,
		"phone: the camp fills the screen (%s in %s)" % [panel.get_global_rect(), visible])
	_expect(not field.hud.get_node("%ClaimButton").visible, "phone: quests are handed in from the camp")
	_expect((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "phone: the HUD does not show through the camp")
	if row != null:
		var button: Control = row.get_node("%RowActions").get_child(0)
		_expect(button.size.y >= 68.0 and button.size.y < 96.0 and row.size.y < 96.0,
			"phone: rows are shorter but buttons stay >= 44 CSS px (row %.0f, button %.0f)" % [row.size.y, button.size.y])
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		row.gui_input.emit(tap)
		_expect(String(row.get_node("%RowDetail").text).contains(String(row._row.more)), "phone: tapping a gear row shows its stats")
	else:
		_expect(false, "phone: the bag has a gear row to compare")
	# Back to the desktop window
	root.size = Vector2i(1440, 900)
	field.fit_screen()
	field.hud.hide_camp()
	await _frames(2)
	_expect(is_equal_approx(root.content_scale_factor, 1.0) and is_equal_approx(panel.offset_left, -560.0)
		and field.hud.get_node("%ClaimButton").visible, "desktop: the scene's own layout comes back (%s, %s, %s)" % [
			root.content_scale_factor, panel.offset_left, field.hud.get_node("%ClaimButton").visible])
	if row != null:
		_expect(is_equal_approx(row.custom_minimum_size.y, 104.0)
			and is_equal_approx(row.get_node("%RowActions").get_child(0).custom_minimum_size.y, 96.0),
			"desktop: rows get the scene's heights back")


func _user_files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("user://")
	if dir == null:
		return out
	for name: String in dir.get_files():
		out.append(name)
	for name: String in dir.get_directories():
		if name != "logs" and name != "shader_cache" and name != "vulkan":
			out.append(name + "/")
	return out


func test_field_death_failure_retries_before_next_generation() -> void:
	var good: RefCounted = field.save_service
	var generation: int = field.profile.generation
	var memorials: int = field.profile.memorial.size()
	field.save_service = SaveService.new(SAVE + "/blocked.json")
	field.battle.ended = true
	field._record_death()
	_expect(field.profile.generation == generation and not field._pending_death.is_empty(),
		"death failure: profile stays unchanged until journal is durable")
	field.next_generation()
	_expect(field.battle.ended and field.profile.generation == generation,
		"death failure: next generation waits for persistence")
	field.save_service = good
	field._save_left = 0.0
	await _frames(2)
	_expect(field._pending_death.is_empty() and field.profile.generation == generation + 1,
		"death retry: defeat screen retries without simulation")
	_expect(field.profile.memorial.size() == memorials + 1, "death retry: memorial added once")
	field.next_generation()
	_expect(not field.battle.ended and field.battle.run.generation == generation + 1,
		"death retry: next generation starts after durable save")


func test_field_expedition_status_matches_risk() -> void:
	var b: RefCounted = field.battle
	var at: Vector2 = b.leader.pos
	b.leader.pos = Vector2(-4, 0)
	var tonic: int = b.run.count("tonic_small")
	b.run.stacks["tonic_small"] = 0
	_expect(field.expedition_status().contains("藥水用盡"), "risk: empty supplies are visible")
	b.retreat_at_ms = b.now_ms + 1500.0
	_expect(field.expedition_status().contains("1.5") and field.expedition_status().contains("仍會受傷"),
		"risk: retreat displays remaining time and exposure")
	b.retreat_at_ms = -1.0
	b.leader.pos = at
	b.run.stacks["tonic_small"] = tonic


func test_field_preferences_apply_and_survive_reload() -> void:
	field._on_setting("screen_shake", false)
	field._on_setting("auto_retreat", false)
	field.load_game()
	_expect(not field.screen_shake and not field.battle.auto_retreat,
		"settings: reloading applies the saved preferences to gameplay")
	_expect(not field.hud.get_node("%AutoRetreatCheck").button_pressed,
		"settings: checkbox reflects saved preference without emitting changes")
	field._on_setting("screen_shake", true)
	field._on_setting("auto_retreat", true)


func test_field_cast_visual_obeys_simulation_duration() -> void:
	var actor: Node3D = load("res://scenes/actors/actor.tscn").instantiate()
	actor.sheet = load("res://resources/sheets/leader_polish.tres")
	root.add_child(actor)
	await _frames(1)
	var unit: RefCounted = field.battle.leader
	actor.bind(unit)
	var previous_action: StringName = unit.action
	var previous_ms: float = unit.action_ms
	unit.action = &"skill"
	unit.action_ms += 1.0
	actor.prepare_cast(0.2)
	actor.sync(unit, 1.0, 0.1, false)
	_expect(actor.visual.anim == &"anticipation", "cast art: holds anticipation during actual cast")
	actor.sync(unit, 1.0, 0.0, false)
	_expect(actor.visual.anim == &"anticipation", "cast art: pause freezes anticipation")
	actor.sync(unit, 1.0, 0.11, false)
	_expect(actor.visual.anim == &"skill", "cast art: impact follows cast completion")
	unit.action = previous_action
	unit.action_ms = previous_ms
	actor.free()


func test_field_uses_reviewed_art_resources() -> void:
	var leader: Node = field.get_node("%Party/Leader")
	_expect(leader.sheet.resource_path == "res://resources/sheets/leader_polish.tres",
		"art: leader uses the shared reviewed sheet, not an embedded stale copy")
	for actor: Node in field.get_node("%Monsters").get_children():
		if actor.kind_id == "gatekeeper":
			_expect(actor.sheet.resource_path == "res://resources/sheets/gatekeeper.tres"
				and actor.sheet.atlas.resource_path.ends_with("gatekeeper_illustrated.res"),
				"art: actual field boss uses normalized atlas")
