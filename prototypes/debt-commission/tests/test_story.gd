extends SceneTree

const StoryRunner = preload("../scripts/story_runner.gd")
const STORY_PATH: String = "res://data/debt_story.json"
const MAX_STEPS: int = 256

var failures: Array[String] = []


func _init() -> void:
    _test_route("hear_first", "debt_recall_hearing", "先聽說明")
    _test_route("ledger_first", "debt_recall_ledger", "先查明細")
    _test_invalid_choice_does_not_mutate()
    _test_invalid_scene_references_are_rejected()
    _test_restore_and_reset()

    if failures.is_empty():
        print("STORY TESTS PASSED")
        quit(0)
    else:
        for failure: String in failures:
            push_error(failure)
        print("STORY TESTS FAILED: %d" % failures.size())
        quit(1)


func _test_route(option_id: String, expected_recall_node: String, label: String) -> void:
    var runner = StoryRunner.new()
    _expect(runner.load_story(STORY_PATH), "%s: story loads" % label)

    var choice: Dictionary = _advance_until_op(runner, "choice", "%s reaches choice" % label)
    _expect(not choice.is_empty(), "%s: choice is present" % label)
    if choice.is_empty():
        return
    _expect(String(choice.get("node_id", "")) == "debt_choose_method", "%s: choice node" % label)
    _expect(runner.choose(option_id), "%s: valid option is accepted" % label)
    _expect(String(runner.flags.get("question_method", "")) == option_id, "%s: question_method flag" % label)

    var visited_nodes: Array[String] = []
    var visible_text: Array[String] = []
    var reached_end: bool = false
    for _step: int in range(MAX_STEPS):
        var command: Dictionary = runner.current()
        if command.is_empty():
            _expect(false, "%s: current command never becomes empty" % label)
            break
        var current_node: String = String(command.get("node_id", ""))
        if not visited_nodes.has(current_node):
            visited_nodes.append(current_node)
        if String(command.get("op", "")) == "say":
            visible_text.append(String(command.get("text", "")))
        if current_node == expected_recall_node:
            _expect(visited_nodes.has("debt_ask_salary"), "%s: salary question precedes recall" % label)
        if String(command.get("op", "")) == "end":
            reached_end = true
            _expect(current_node == "debt_end", "%s: end node" % label)
            break
        if String(command.get("op", "")) == "choice":
            _expect(false, "%s: unexpected second choice" % label)
            break
        runner.advance()

    _expect(reached_end, "%s: reaches end" % label)
    _expect(bool(runner.flags.get("repayment_promised", false)), "%s: repayment promise flag" % label)
    _expect(visited_nodes.has(expected_recall_node), "%s: expected recall branch" % label)
    _expect(visited_nodes.has("debt_agreement"), "%s: agreement branch" % label)
    _expect(visible_text.has("明天下午三點，到樓下洗碗。工錢先抵一部分房租。"), "%s: concrete repayment action" % label)
    if option_id == "hear_first":
        _expect(visible_text.has("再前面。『先讓阿銀把理由說完。』"), "%s: hearing callback text" % label)
    else:
        _expect(visible_text.has("照你剛才說的，一筆一筆來。領薪水的收據呢？"), "%s: ledger callback text" % label)


func _test_invalid_choice_does_not_mutate() -> void:
    var runner = StoryRunner.new()
    _expect(runner.load_story(STORY_PATH), "invalid choice: story loads")
    _advance_until_op(runner, "choice", "invalid choice reaches choice")
    var before: Dictionary = runner.snapshot()
    _expect(not runner.choose("not-an-option"), "invalid choice is rejected")
    _expect(runner.snapshot() == before, "invalid choice leaves snapshot unchanged")
    _expect(String(runner.current().get("op", "")) == "choice", "invalid choice leaves current command")


func _test_invalid_scene_references_are_rejected() -> void:
    var story_file: FileAccess = FileAccess.open(STORY_PATH, FileAccess.READ)
    _expect(story_file != null, "invalid references: source story opens")
    if story_file == null:
        return
    var story_text: String = story_file.get_as_text()

    var invalid_actor_path: String = _write_temp_story("invalid_actor", story_text.replace("\"actor\": \"otose\"", "\"actor\": \"unknown_actor\""))
    var invalid_actor_runner = StoryRunner.new()
    _expect(not invalid_actor_runner.load_story(invalid_actor_path), "invalid actor reference is rejected")

    var invalid_position_path: String = _write_temp_story("invalid_position", story_text.replace("\"at\": \"reader\"", "\"at\": \"unknown_spot\""))
    var invalid_position_runner = StoryRunner.new()
    _expect(not invalid_position_runner.load_story(invalid_position_path), "invalid stage position is rejected")

    var invalid_camera_path: String = _write_temp_story("invalid_camera", story_text.replace("\"target\": \"center\"", "\"target\": \"unknown_target\""))
    var invalid_camera_runner = StoryRunner.new()
    _expect(not invalid_camera_runner.load_story(invalid_camera_path), "invalid camera target is rejected")

    _remove_temp_story(invalid_actor_path)
    _remove_temp_story(invalid_position_path)
    _remove_temp_story(invalid_camera_path)


func _write_temp_story(label: String, content: String) -> String:
    var path: String = "user://story_%s.json" % label
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _expect(false, "unable to create temporary story: %s" % label)
        return path
    file.store_string(content)
    file.close()
    return path


func _remove_temp_story(path: String) -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_restore_and_reset() -> void:
    var source = StoryRunner.new()
    _expect(source.load_story(STORY_PATH), "restore: source loads")
    _advance_until_op(source, "choice", "restore reaches choice")
    _expect(source.choose("ledger_first"), "restore chooses ledger path")

    for _step: int in range(4):
        if String(source.current().get("op", "")) == "say":
            break
        source.advance()
    var saved: Dictionary = source.snapshot()
    var restored = StoryRunner.new()
    _expect(restored.load_story(STORY_PATH), "restore: target loads")
    _expect(restored.restore(saved), "valid snapshot restores")
    _expect(restored.snapshot() == saved, "restored snapshot is exact")
    _expect(restored.current() == source.current(), "restored command matches source")

    var before_bad_version: Dictionary = restored.snapshot()
    var bad_version: Dictionary = before_bad_version.duplicate(true)
    bad_version["version"] = "999.0"
    _expect(not restored.restore(bad_version), "different version is rejected")
    _expect(restored.snapshot() == before_bad_version, "different version leaves state unchanged")

    var bad_node: Dictionary = before_bad_version.duplicate(true)
    bad_node["node_id"] = "missing_node"
    _expect(not restored.restore(bad_node), "unknown node is rejected")
    _expect(restored.snapshot() == before_bad_version, "unknown node leaves state unchanged")

    var reached_end: bool = false
    for _step: int in range(MAX_STEPS):
        if String(restored.current().get("op", "")) == "end":
            reached_end = true
            break
        restored.advance()
    _expect(reached_end, "restored path remains playable")
    _expect(bool(restored.flags.get("repayment_promised", false)), "restored path reaches promise")

    restored.reset()
    _expect(restored.node_id == "debt_intro", "reset returns to entry node")
    _expect(restored.step_index == 0, "reset returns to first step")
    _expect(String(restored.flags.get("question_method", "")) == "unset", "reset clears question method")
    _expect(not bool(restored.flags.get("repayment_promised", true)), "reset clears repayment promise")
    _expect(String(restored.current().get("op", "")) == "camera", "reset returns to entry command")


func _advance_until_op(runner, desired_op: String, context: String) -> Dictionary:
    for _step: int in range(MAX_STEPS):
        var command: Dictionary = runner.current()
        if String(command.get("op", "")) == desired_op:
            return command
        if command.is_empty() or String(command.get("op", "")) == "end" or String(command.get("op", "")) == "choice":
            break
        runner.advance()
    _expect(false, "%s: did not reach %s" % [context, desired_op])
    return {}


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
