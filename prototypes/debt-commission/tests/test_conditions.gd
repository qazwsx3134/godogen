extends "res://addons/proto_kit/test_kit.gd"
## Flag add, compound condition tests and their `.dialogue` syntax (IMPLEMENTATION.md「旗標加減與複合條件」).
const Runner := preload("res://scripts/story_runner.gd")
const DmSource := preload("res://tools/story_build/dm_source.gd")
const SOURCE := "user://test_conditions_story.json"

func _initialize() -> void:
	_run.call_deferred()

func _story() -> Dictionary:
	return {
		"id": "conditions", "version": "1", "title": "條件", "entry": "open",
		"initial_flags": {"trust": 0, "met": false, "asked": ""},
		"nodes": {
			"open": {"title": "open", "steps": [
				{"op": "flag", "key": "trust", "add": 3},
				{"op": "flag", "key": "trust", "add": -1},
				{"op": "item", "id": "milk_bottle"},
				{"op": "say", "speaker": "shinpachi", "text": "開始"},
				{"op": "condition", "test": {"all": [
					{"flag": "trust", "cmp": ">=", "value": 2},
					{"has": "milk_bottle"},
					{"not": {"flag": "met", "cmp": "==", "value": true}}]}, "then": "yes", "else": "no"}]},
			"yes": {"title": "yes", "steps": [
				{"op": "condition", "test": {"any": [
					{"flag": "asked", "cmp": "!=", "value": ""},
					{"flag": "trust", "cmp": "<", "value": 2}]}, "then": "no", "else": "legacy"}]},
			"legacy": {"title": "legacy", "steps": [
				{"op": "condition", "flag": "met", "equals": false, "then": "end", "else": "no"}]},
			"end": {"title": "end", "steps": [{"op": "say", "speaker": "shinpachi", "text": "通過"}, {"op": "end", "text": "完"}]},
			"no": {"title": "no", "steps": [{"op": "end", "text": "錯"}]},
		},
	}

func _load(story: Dictionary) -> Runner:
	var file := FileAccess.open(SOURCE, FileAccess.WRITE)
	file.store_string(JSON.stringify(story))
	file.close()
	var runner := Runner.new()
	runner.load_story(SOURCE)
	return runner

func _rejects(change: Callable, why: String) -> void:
	var story: Dictionary = _story()
	change.call(story)
	var runner := _load(story)
	_expect(not runner.error_message.is_empty() and runner.current().is_empty(), "%s (%s)" % [why, runner.error_message])

func _run() -> void:
	var runner := _load(_story())
	_expect(runner.error_message.is_empty(), "the condition story loads: %s" % runner.error_message)
	_expect(runner.flags["trust"] == 2, "add +3 then -1 gives 2")
	var saved: Dictionary = runner.snapshot()
	runner.advance()
	_expect(String(runner.current().get("text", "")) == "通過", "all / any / not / has / ordering / legacy pick the right branches")

	var probe: RefCounted = runner.create_validation_probe()
	_expect(probe.restore(saved) and probe.flags["trust"] == 2, "restoring a save does not run the adds again")
	var counted: Dictionary = saved.duplicate(true)
	counted.flags.trust = 7
	_expect(probe.restore(counted), "a counter accepts any number in a save")
	counted.flags.trust = "7"
	_expect(not probe.restore(counted), "a counter rejects a non-number in a save")
	var loaded: Variant = bytes_to_var(var_to_bytes(saved))
	_expect(probe.restore(loaded) and probe.flags["trust"] == 2, "a save file round-trip (var_to_bytes, as save_slots.gd) restores")

	_rejects(func(s: Dictionary) -> void: s.nodes.open.steps[0] = {"op": "flag", "key": "nope", "add": 1}, "add needs a declared flag")
	_rejects(func(s: Dictionary) -> void: s.nodes.open.steps[0] = {"op": "flag", "key": "met", "add": 1}, "add needs a number flag")
	_rejects(func(s: Dictionary) -> void: s.nodes.open.steps[0] = {"op": "flag", "key": "trust", "add": 1.5}, "add must be whole")
	_rejects(func(s: Dictionary) -> void: s.nodes.open.steps[0] = {"op": "flag", "key": "trust", "add": 1, "value": 1}, "add and value are exclusive")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"flag": "asked", "cmp": "<", "value": "a"}, "ordering a string flag")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"flag": "trust", "cmp": "==", "value": true}, "comparing a number flag with a bool")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"flag": "ghost", "cmp": "==", "value": 1}, "testing an undeclared flag")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"has": "not_an_item"}, "has needs a catalog item")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"all": []}, "all needs at least one test")
	_rejects(func(s: Dictionary) -> void: s.nodes.yes.steps[0].test = {"flag": "trust", "cmp": "~", "value": 1}, "unknown comparison")
	_rejects(func(s: Dictionary) -> void: s.nodes.legacy.steps[0].test = {"has": "milk_bottle"}, "flag/equals and test are exclusive")

	var tokens := func(expression: String) -> Dictionary: return DmSource.condition_test(DmSource.expression_tokens(expression))
	_expect(tokens.call("met == true") == {"flag": "met", "equals": true}, "a lone key == value keeps the old fields")
	_expect(tokens.call('trust >= 2 and not has("milk_bottle")') == {"test": {"all": [
		{"flag": "trust", "cmp": ">=", "value": 2}, {"not": {"has": "milk_bottle"}}]}}, "and / not / has become a test tree")
	_expect(tokens.call('asked == "x" or trust < 1') == {"test": {"any": [
		{"flag": "asked", "cmp": "==", "value": "x"}, {"flag": "trust", "cmp": "<", "value": 1}]}}, "or becomes any")
	_expect(tokens.call("trust != 1") == {"test": {"flag": "trust", "cmp": "!=", "value": 1}}, "a lone != is a test")
	_expect(tokens.call("a == 1 and b == 2 or c == 3").is_empty(), "mixing and / or is refused")
	var compiled: DMCompilerResult = DMCompiler.compile_string("~ s\nset trust += 2\nset trust -= 3\n=> END\n", "test")
	var adds: Array = []
	for line: Dictionary in compiled.lines.values():
		if String(line.get("type", "")) == "mutation":
			adds.append(DmSource._mutation(line, "test"))
	_expect(adds.has({"op": "flag", "key": "trust", "add": 2}) and adds.has({"op": "flag", "key": "trust", "add": -3}), "+= / -= become add")
	var ends: Array = []
	for source: String in ['do end("被開除")', 'do end("被開除", "fired")', 'do end("被開除", "fired", "失業結局")']:
		var parsed: DMCompilerResult = DMCompiler.compile_string("~ s\n%s\n=> END\n" % source, "test")
		for line: Dictionary in parsed.lines.values():
			if String(line.get("type", "")) == "mutation":
				ends.append(DmSource._mutation(line, "test"))
	_expect(ends == [{"op": "end", "text": "被開除"}, {"op": "end", "text": "被開除", "ending": "fired"},
		{"op": "end", "text": "被開除", "ending": "fired", "ending_title": "失業結局"}], "do end() takes an ending id and title: %s" % [ends])
	_expect(Runner.endings_of({"nodes": {"a": {"steps": [{"op": "end", "text": "壞", "ending": "bad"}]},
		"b": {"steps": [{"op": "result", "title": "結算", "ending": "good", "ending_title": "好結局"}, {"op": "end", "text": "x", "ending": "bad"}]}}})
		== [{"id": "bad", "title": "壞"}, {"id": "good", "title": "好結局"}], "endings_of lists each ending once with its title")
	_rejects(func(s: Dictionary) -> void: s.nodes.no.steps[0].ending = "", "an ending id must be non-empty")
	_rejects(func(s: Dictionary) -> void: s.nodes.no.steps[0].ending_title = "x", "ending_title needs an ending")
	_rejects(func(s: Dictionary) -> void: s.carry = ["ghost"], "carry lists declared flags")
	_finish("CONDITION TESTS")
