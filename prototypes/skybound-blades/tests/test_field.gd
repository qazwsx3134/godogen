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
	await test_field_click_monster_chases_and_kills()
	await test_field_walk_animation_advances()
	await test_field_hud_auto_button_toggles_auto_hunt()
	await test_field_leader_down_shows_end_and_keeps_rendering()
	await test_field_restart_resets_the_run()
	test_field_saves_only_its_own_file()
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
	_expect(is_equal_approx(cluster.offset_left, -420.0) and is_equal_approx(cluster.offset_bottom, -44.0),
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
	await _tap(field.camera.unproject_position(Vector3(b.leader.pos.x + 4.0, 0, b.leader.pos.y - 2.5)))
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
	_expect(not b.ended and b.level == 1 and b.gold == 0 and b.kills == 0, "restart: a fresh run")
	_expect(int(b.inventory.tonic_small) == 5 and b.leader.hp == b.leader.max_hp, "restart: supplies and HP from tuning")
	_expect(not hud.get_node("%EndPanel").visible, "restart: end panel hidden")


func test_field_saves_only_its_own_file() -> void:
	_expect(FileAccess.file_exists(SAVE), "save: the field writes its save file")
	var expected := _user_files_before.duplicate()
	if not "test_field/" in expected:
		expected.append("test_field/")
	var now := _user_files()
	now.sort()
	expected.sort()
	_expect(now == expected, "save: nothing else appears in user:// (%s)" % [now])


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
