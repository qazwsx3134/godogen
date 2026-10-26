extends "res://addons/proto_kit/test_kit.gd"

const Draft = preload("res://addons/proto_kit/card_draft.gd")
const UpgradeTree = preload("res://addons/proto_kit/upgrade_tree.gd")
const UiTheme = preload("res://addons/proto_kit/ui/ui_theme.gd")
const Layouts = preload("res://tools/make_ui_layouts.gd")
const Builder = preload("res://addons/proto_kit/scene_builder.gd")
const Goals = preload("res://addons/proto_kit/run_goals.gd")


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_draft()
	_test_tree()
	_test_goals()
	_test_ui()
	await _test_layout_sizes()
	print("checks: ", checks)
	_finish("GENRE MODULES TESTS")


func _test_draft() -> void:
	var pool: Array[Dictionary] = []
	for index: int in range(10):
		pool.append({"id": str(index), "kind": "upgrade", "weight": index + 1, "max_level": 10})
	var a := Draft.new(pool, _rng(), {"rerolls": 1, "banishes": 1})
	var b := Draft.new(pool, _rng(), {"rerolls": 1, "banishes": 1})
	for index: int in range(20):
		var offered: Array = a.offer()
		_expect(offered == b.offer(), "same seed offer %d" % index)
		_expect(offered.size() == 3 and offered[0] != offered[1] and offered[1] != offered[2] and offered[0] != offered[2], "unique offer")
	var old: Array = a.current.duplicate()
	_expect(a.reroll(), "reroll succeeds")
	for id: String in a.current:
		_expect(id not in old, "reroll avoids previous set when possible")
	old = a.current.duplicate()
	_expect(not a.reroll() and old == a.current, "exhausted reroll does not change current")
	var banned: String = a.current[0]
	_expect(a.banish(banned) and a.current.size() == 3, "banish refills")
	_expect(not a.banish(a.current[0]), "banish budget enforced")
	for index: int in range(200):
		_expect(banned not in a.offer(), "banished absent %d" % index)
	_expect(not a.pick("missing"), "pick requires current membership")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	b.from_dict(snapshot)
	_expect(a.current == b.current and a.banishes_left == b.banishes_left and a.rerolls_left == b.rerolls_left, "draft restores current and budgets")
	for index: int in range(20):
		_expect(a.offer() == b.offer(), "restored RNG continues identically")
	var limited: Array[Dictionary] = [{"id": "s1", "kind": "skill", "max_level": 3, "branch": "fire"}, {"id": "s2", "kind": "skill"}, {"id": "up", "kind": "upgrade", "branch": "fire", "max_level": 3}, {"id": "ult", "kind": "ultimate", "branch": "fire", "ultimate_need": 2}, {"id": "req", "kind": "upgrade", "requires": ["s1"]}]
	var d := Draft.new(limited, _rng(), {"slots": 1})
	_expect("ult" not in d.offer(20) and "req" not in d.current, "ultimate and requires locked")
	_expect(d.pick("s1") and d.slots_used() == 1 and d.level("s1") == 1 and d.current.is_empty(), "pick updates level and slot and clears offer")
	d.offer(20)
	_expect("s2" not in d.current and "up" in d.current and "s1" in d.current and "req" in d.current, "full slots permit upgrades and held skills")
	_expect(d.pick("up") and d.branch_progress("fire") == 2 and d.ultimate_ready("fire", 2), "branch threshold reached")
	_expect("ult" in d.offer(20), "ultimate offered at threshold")
	_expect(d.pick("ult") and "ult" not in d.offer(20), "maxed card excluded")
	var restored := Draft.new(limited, _rng())
	restored.from_dict(d.to_dict())
	_expect(restored.level("s1") == 1 and restored.slots_used() == 1 and restored.branch_progress("fire") == d.branch_progress("fire"), "levels and branch restore")
	_expect(d.offer(0).is_empty(), "zero count offer")


func _test_tree() -> void:
	var nodes: Array[Dictionary] = [{"id": "power", "max_level": 5, "cost_base": 10.0, "cost_growth": 2.0, "effect": {"attack": 2.0}}, {"id": "health", "max_level": 2, "costs": [7, 11], "effect": {"hp": 5.0, "attack": 1.0}}]
	var t := UpgradeTree.new(nodes)
	var spent: int = 0
	for price: int in [10, 20, 40, 80, 160]:
		_expect(t.cost("power") == price, "five-level cost curve %d" % price)
		var result: Dictionary = t.buy("power", 1000)
		_expect(result.ok and result.spent == price and result.remaining == 1000 - price, "buy accounting")
		spent += price
	_expect(t.cost("power") == -1 and t.buy("power", 1000).reason == "maxed", "maxed cost and reason")
	_expect(t.preview("health", 3).short_by == 4 and t.preview("health", 100).short_by == 0, "short_by clamps")
	_expect(t.buy("health", 3).reason == "short" and not t.can_buy("health", 3), "insufficient funds")
	_expect(t.preview("health", 10).now.hp == 0.0 and t.preview("health", 10).after.hp == 5.0, "effect preview")
	t.buy("health", 100)
	t.buy("health", 100)
	spent += 18
	_expect(t.totals() == {"attack": 12.0, "hp": 10.0} and t.count_bought() == 7, "totals and bought levels")
	var restored := UpgradeTree.new(nodes)
	var save: Dictionary = t.to_dict()
	save.levels["obsolete"] = 999
	restored.from_dict(save)
	_expect(restored.totals() == t.totals() and restored.count_bought() == 7, "restore ignores obsolete ids")
	_expect(restored.respec() == spent and restored.count_bought() == 0, "restored refund computed from levels")
	_expect(t.respec() == spent and t.respec() == 0, "refund exact and cannot repeat")
	var graph: Array[Dictionary] = [{"id": "a", "max_level": 1, "cost_base": 1, "adj": ["root", "b"]}, {"id": "b", "max_level": 1, "cost_base": 1}, {"id": "c", "max_level": 1, "cost_base": 1}]
	var invalid := UpgradeTree.new(graph)
	_expect(not invalid.configuration_error.is_empty(), "graph without root reports configuration error")
	var tree := UpgradeTree.new(graph, {"root": "root"})
	_expect(tree.is_available("a") and not tree.is_available("b") and not tree.is_available("c"), "root adjacency and isolated lock")
	_expect(tree.buy("b", 10).reason == "locked", "locked purchase rejected")
	tree.buy("a", 10)
	_expect(tree.is_available("b") and tree.buy("b", 10).ok, "one-sided adjacency is undirected")


func _test_goals() -> void:
	var definitions: Array[Dictionary] = [{"id": "run", "event": "kill", "need": 3, "reward": "hero"}, {"id": "all", "event": "kill", "need": 5, "per_run": false, "reward": "weapon"}, {"id": "hard", "event": "kill", "need": 2, "tier": 1, "reward": "hero"}]
	var g := Goals.new(definitions)
	g.begin_run()
	_expect(g.total() == 3 and g.claimed() == 0, "goal counts initial")
	_expect(g.note("other", 100).is_empty(), "event filter")
	g.note("kill", 2)
	_expect(g.progress("hard") == Vector2i(-1, 2), "tier locks progress")
	g.begin_run()
	_expect(g.progress("run") == Vector2i(0, 3) and g.progress("all") == Vector2i(2, 5), "per-run reset and persistent accumulation")
	g.note("kill", 1)
	_expect(g.progress("hard") == Vector2i(-1, 2), "low tier events do not unlock")
	var loaded := Goals.new(definitions)
	loaded.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	_expect(loaded.progress("run") == Vector2i(0, 3) and loaded.progress("all") == Vector2i(3, 5), "save excludes run counts and preserves lifetime counts")
	g.begin_run(1)
	_expect(g.progress("hard") == Vector2i(0, 2), "locked events were not counted")
	var completed: Array = g.note("kill", 3)
	_expect(completed.size() == 3 and g.claimed() == 3, "all matching goals complete once")
	_expect(g.note("kill", 100).is_empty(), "completion does not repeat")
	_expect(g.rewards_unlocked() == ["hero", "weapon"], "unique rewards")
	loaded.from_dict(g.to_dict())
	_expect(loaded.claimed() == g.claimed() and loaded.rewards_unlocked() == g.rewards_unlocked(), "completed rewards and claimed restore")
	loaded.begin_run(1)
	_expect(loaded.note("kill", 100).is_empty() and loaded.progress("run") == Vector2i(3, 3), "completed remains permanent after run reset")


func _luminance(color: Color) -> float:
	var linear: Color = color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722


func _owners(node: Node, scene: Node) -> void:
	for child: Node in node.get_children():
		_expect(child.owner == scene, "saved owner: " + str(child.name))
		_owners(child, scene)


func _test_ui() -> void:
	for style: String in UiTheme.ids():
		_expect(load(Layouts.THEME_DIRECTORY + style + ".tres") is Theme, "shared theme resource " + style)
	var catalog: Dictionary = UiTheme.tokens()
	_expect(UiTheme.ids().size() == 3, "three styles")
	for id: String in UiTheme.ids():
		var theme: Theme = UiTheme.build(id)
		_expect(theme != null, "theme builds: " + id)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			_expect(theme.has_stylebox(state, "Button"), id + " button " + state)
		for type: String in ["Panel", "PanelContainer", "TabContainer"]:
			_expect(theme.has_stylebox("panel", type), id + " " + type + " panel")
		_expect(theme.has_stylebox("background", "ProgressBar") and theme.has_stylebox("fill", "ProgressBar"), id + " progress styles")
		_expect(theme.get_font_size("font_size", "Label") == int(catalog[id].font_sizes.body), "body token preserved")
		_expect(theme.get_font_size("font_size", "TitleLabel") == int(catalog[id].font_sizes.title), "title token preserved")
		var background: float = _luminance(Color(catalog[id].panel))
		for token: String in ["text", "text_dim", "accent", "danger"]:
			var foreground: float = _luminance(Color(catalog[id][token]))
			var ratio: float = (maxf(background, foreground) + 0.05) / (minf(background, foreground) + 0.05)
			print("CONTRAST %s %s/panel %.3f" % [id, token, ratio])
			_expect(ratio >= 4.5, id + " contrast " + token)
	var expected_counts: Dictionary = {"idle_split_panel": 42, "tabbed_modal": 47, "card_draft": 17, "settings_list": 26, "quest_list": 27, "hud_arpg": 27, "result_report": 24, "dialogue_portrait": 16}
	for id: String in Layouts.REQUIRED:
		var source: String = FileAccess.get_file_as_string(Layouts.DIRECTORY + id + ".tscn")
		_expect(not source.contains('[sub_resource type="Theme"'), "no embedded Theme: " + id)
		var packed: PackedScene = load(Layouts.DIRECTORY + id + ".tscn") as PackedScene
		_expect(packed != null, "scene loads: " + id)
		var scene: Control = packed.instantiate()
		_expect(scene.theme.resource_path == Layouts.THEME_DIRECTORY + "dark_gothic.tres", "shared theme reference " + id)
		_expect(scene.get_script() == null, "layout root has no script")
		_expect(Builder.count_nodes(scene) == expected_counts[id] and scene.get_meta("authored_node_count") == expected_counts[id], "saved node count " + id)
		_owners(scene, scene)
		for unique: String in Layouts.REQUIRED[id]:
			_expect(scene.get_node_or_null("%" + unique) != null, id + " unique " + unique)
		if id == "card_draft":
			_expect(scene.get_node("%Reroll").custom_minimum_size.y >= 96 and scene.get_node("%Banish").custom_minimum_size.y >= 96, "draft touch targets")
		if id == "dialogue_portrait":
			_expect(scene.get_node("%Skip").custom_minimum_size.y >= 48, "skip touch target")
		scene.free()


func _test_layout_sizes() -> void:
	root.size = Vector2i(390, 844)
	for style: String in UiTheme.ids():
		for id: String in Layouts.REQUIRED:
			var scene: Control = (load(Layouts.DIRECTORY + id + ".tscn") as PackedScene).instantiate()
			scene.theme = UiTheme.build(style)
			root.add_child(scene)
			scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await _frames(3)
			_check_unwrapped_labels(scene, style + " " + id)
			var body: Control = scene.get_node("SafeMargin/Body")
			_expect(body.get_global_rect().end.y <= 845 and body.get_global_rect().end.x <= 391, style + " " + id + " fits portrait")
			for unique: String in Layouts.REQUIRED[id]:
				var control: Control = scene.get_node("%" + unique) as Control
				if control is Button:
					_expect(control.get_global_rect().end.x <= 391 and control.get_global_rect().end.y <= 845, style + " " + id + " button visible " + unique)
			scene.free()
	# Editing static content remains authoritative after entering the tree; no runtime builder resets it.
	var editable: Control = (load(Layouts.DIRECTORY + "dialogue_portrait.tscn") as PackedScene).instantiate()
	editable.get_node("%Text").text = "手動調整文字"
	editable.get_node("SafeMargin").add_theme_constant_override("margin_left", 23)
	root.add_child(editable)
	await _frames(2)
	_expect(editable.get_node("%Text").text == "手動調整文字" and editable.get_node("SafeMargin").get_theme_constant("margin_left") == 23, "editor changes survive entering tree")
	editable.free()
	var pristine: Control = (load(Layouts.DIRECTORY + "dialogue_portrait.tscn") as PackedScene).instantiate()
	_expect(pristine.get_node("%Text").text != "手動調整文字", "instance edits do not contaminate saved scene")
	pristine.free()


func _check_unwrapped_labels(node: Node, context: String) -> void:
	if node is Label and node.is_visible_in_tree() and node.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var label: Label = node as Label
		var font: Font = label.get_theme_font("font")
		var line_height: float = font.get_height(label.get_theme_font_size("font_size"))
		_expect(label.size.y <= line_height * 2.0 + 1.0, context + " unwrapped label height " + str(label.name))
		_expect(label.get_line_count() <= 2, context + " unwrapped label line count " + str(label.name))
	for child: Node in node.get_children():
		_check_unwrapped_labels(child, context)
