extends "res://addons/proto_kit/test_kit.gd"
var game: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 900)
	var source_hash: String = FileAccess.get_sha256("res://scenes/main.tscn")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game.driver.enabled = false
	_expect(game.get_node("%Pages").get_tab_count() == 6, "six functional authored pages")
	_expect(game.roster_panel.get_node("%UnitCards").get_child_count() == 6, "six authored reusable unit-card instances")
	_expect(game.lane.get_node("%Actors").get_child_count() == 5, "real battle scene contains two allies and three enemies")
	for name: String in ["Gold", "Save", "Pause", "BagSummary", "SaveStatus", "Toast"]:
		var rectangle: Rect2 = game.get_node("%" + name).get_global_rect()
		_expect(rectangle.position.y >= 0 and rectangle.end.y <= 901, name + " stays in viewport")
	await _tap_control(game.get_node("%DismissHelp"))
	_expect(game.model.state.tutorial_seen and not game.get_node("%HelpBar").visible, "real mouse dismisses hint and stores preference")
	var roster: Node = game.roster_panel.get_node("%UnitCards")
	await _tap_control(roster.get_node("Dew").get_node("%Inspect"))
	_expect(game.selected_unit == "dew", "real inspect button selects correct UID")
	await _tap_control(roster.get_node("Dew").get_node("%Deploy"))
	_expect(game.model.state.deployed.size() == 2 and "上陣格已滿" in game.get_node("%Toast").text, "full party is rejected with visible reason")
	await _tap_control(roster.get_node("Ember").get_node("%Deploy"))
	await _tap_control(roster.get_node("Dew").get_node("%Deploy"))
	_expect(game.model.state.deployed == ["moss", "dew"] and game.model.bonds().grove, "mouse withdrawal and deploy activate grove composition")
	var gold: int = int(game.model.state.gold)
	await _tap_control(game.roster_panel.get_node("%Train"))
	_expect(int(game.model.state.roster.dew.level) == 2 and int(game.model.state.gold) < gold, "training button executes paid domain command")
	await _tab(3)
	game.model.state.gold = 1000
	game.refresh()
	await _tap_control(game.talent_panel.get_node("%TalentCards/Might").get_node("%BuyTalent"))
	await _tap_control(game.talent_panel.get_node("%TalentCards/Company").get_node("%BuyTalent"))
	_expect(game.model.slots() == 3, "talent page purchases third party slot through real controls")
	await _tab(2)
	game.model.state.best_stage = 0
	game.model.state.cleared = [0]
	game.refresh()
	await _frames(2)
	await _tap_control(game.map_panel.get_node("%StageCards/Stage1").get_node("%Travel"))
	_expect(int(game.model.state.stage) == 1, "map button changes to unlocked stage")
	game.select_unit("sun") # Locked selection must not leak into the equipment owner command.
	await _tab(1)
	await _tap_control(game.equipment_panel.get_node("%RemoveArmor"))
	_expect(str(game.model.state.equipped.moss.armor).is_empty(), "equipment fallback picker and unequip command use the same owned unit")
	var count_before: int = _count(game)
	for i: int in 20: game.refresh()
	await _frames(3)
	_expect(_count(game) == count_before, "refresh never rebuilds the screen or leaks item nodes")
	await _tap_control(game.get_node("%Save"))
	_expect(game.repository.restore().source == "main", "save button produces a valid persisted profile")
	await _tab(4)
	_expect("旅途中的六位夢靈" in game.codex_panel.get_node("%CodexText").text, "codex has real content")
	await _tab(5)
	_expect("有效治療" in game.report_panel.get_node("%StatsText").text, "report explains actual contribution metrics")
	await _tap_control(game.get_node("%Pause"))
	_expect(game.model.paused and game.get_node("%Pause").text == "繼續", "pause button changes both model and label")
	_expect(FileAccess.get_sha256("res://scenes/main.tscn") == source_hash, "runtime never writes original scene")
	game.queue_free()
	await _frames(3)
	await _test_authored_edits_survive_ready()
	print("checks: ", checks)
	_finish("DREAMLING UI AND EDITOR CONTRACT")


func _tap_control(button: Control) -> void:
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await _frames(4)
	await _tap(button.get_global_rect().get_center())
	await _frames(3)


func _tab(index: int) -> void:
	var bar: TabBar = game.get_node("%Pages").get_tab_bar()
	await _tap(bar.global_position + bar.get_tab_rect(index).get_center())
	await _frames(4)
	_expect(game.get_node("%Pages").current_tab == index, "mouse opens tab %d" % index)


func _test_authored_edits_survive_ready() -> void:
	var source: PackedScene = load("res://scenes/main.tscn")
	var authored: Control = source.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	authored.get_node("%HeaderTitle").text = "編輯器保留測試"
	authored.get_node("%BodyRows").add_theme_constant_override("separation", 17)
	var packed := PackedScene.new()
	_expect(packed.pack(authored) == OK, "edited scene packs")
	var path: String = "user://editor_contract.tscn"
	_expect(ResourceSaver.save(packed, path) == OK, "edited scene saves with Godot")
	authored.free()
	var edited: Control = load(path).instantiate()
	root.add_child(edited)
	await _frames(5)
	_expect(edited.get_node("%HeaderTitle").text == "編輯器保留測試", "authored static text survives ready")
	_expect(edited.get_node("%BodyRows").get_theme_constant("separation") == 17, "authored spacing survives ready")
	edited.queue_free()
	await _frames(3)


func _count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children(): count += _count(child)
	return count
