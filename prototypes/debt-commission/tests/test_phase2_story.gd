extends SceneTree

const StoryRunner = preload("../scripts/story_runner.gd")
const STORY_PATH: String = "res://data/phase2_story.json"
const MAX_STEPS: int = 128

var failures: Array[String] = []


func _init() -> void:
    _test_catalog_and_phase2_routes()
    _test_conditional_option_visibility_and_rejection()
    _test_duplicate_item_acquisition()
    _test_snapshot_items_and_strict_restore()
    _test_invalid_references_are_rejected()
    _test_failed_load_preserves_story()

    if failures.is_empty():
        print("PHASE 2 STORY TESTS PASSED")
        quit(0)
    else:
        for failure: String in failures:
            push_error(failure)
        print("PHASE 2 STORY TESTS FAILED: %d" % failures.size())
        quit(1)


func _test_catalog_and_phase2_routes() -> void:
    var runner = StoryRunner.new()
    _expect(runner.load_story(STORY_PATH), "phase2 story loads")
    if not runner.get_asset_catalog().is_empty():
        var catalog: Dictionary = runner.get_asset_catalog()
        _expect(catalog.has("backgrounds") and catalog.has("characters") and catalog.has("items"), "catalog has all collections")
        _expect(catalog["backgrounds"].has("yorozuya_living_room"), "catalog has living room")
        _expect(catalog["backgrounds"].has("yorozuya_kitchen"), "catalog has kitchen")
        for character_id: String in ["shinpachi", "gintoki", "otose", "kagura", "sadaharu"]:
            _expect(catalog["characters"].has(character_id), "catalog has character %s" % character_id)
        for item_id: String in ["milk_bottle", "milk_trace", "kagura_kombu", "sadaharu_footprint"]:
            _expect(catalog["items"].has(item_id), "catalog has item %s" % item_id)

        var changed_catalog: Dictionary = catalog.duplicate(true)
        changed_catalog["characters"]["shinpachi"]["name"] = "mutated"
        _expect(String(runner.get_asset_catalog()["characters"]["shinpachi"]["name"]) != "mutated", "catalog is returned as a deep copy")

    var first_command: Dictionary = runner.current()
    _expect(String(first_command.get("op", "")) == "bg", "phase2 starts with a background")
    _expect(String(first_command.get("id", "")) == "yorozuya_living_room", "phase2 starts in the living room")

    runner.advance()
    var first_character: Dictionary = runner.current()
    _expect(String(first_character.get("op", "")) == "char", "phase2 presents a character")
    _expect(String(first_character.get("id", "")) == "shinpachi", "phase2 presents shinpachi")
    _expect(bool(first_character.get("visible", false)), "char defaults to visible")
    _expect(String(first_character.get("expression", "")) == "neutral", "char defaults to neutral expression")
    _expect(String(first_character.get("position", "")) == "left", "char defaults to catalog slot")

    runner.advance()
    runner.advance()
    var positioned_character: Dictionary = runner.current()
    _expect(String(positioned_character.get("id", "")) == "gintoki", "phase2 presents gintoki")
    _expect(String(positioned_character.get("position", "")) == "right", "char accepts an explicit position override")

    var choice: Dictionary = _advance_until_op(runner, "choice", "phase2 reaches choice")
    _expect(runner.items.size() == 1 and runner.items.has("milk_bottle"), "item op grants milk bottle once")
    _expect(bool(runner.flags.get("test_started", false)), "flag op sets test_started")
    _expect(_option_exists(choice, "inspect_milk"), "required option appears when item is owned")
    _expect(_option_exists(choice, "skip_test"), "unconditional option appears")

    _expect(runner.choose("inspect_milk"), "phase2 required route can be chosen")
    var visited_kitchen: bool = false
    var visited_kagura: bool = false
    var reached_end: bool = false
    for _step: int in range(MAX_STEPS):
        var command: Dictionary = runner.current()
        if command.is_empty():
            break
        if String(command.get("op", "")) == "bg" and String(command.get("id", "")) == "yorozuya_kitchen":
            visited_kitchen = true
        if String(command.get("op", "")) == "char" and String(command.get("id", "")) == "kagura":
            visited_kagura = true
            _expect(String(command.get("position", "")) == "right", "kagura defaults to catalog slot")
        if String(command.get("op", "")) == "end":
            reached_end = true
            break
        runner.advance()
    _expect(visited_kitchen, "required phase2 route uses kitchen background")
    _expect(visited_kagura, "required phase2 route presents kagura")
    _expect(reached_end, "required phase2 route reaches an ending")

    var skip_runner = StoryRunner.new()
    _expect(skip_runner.load_story(STORY_PATH), "phase2 skip runner loads")
    _advance_until_op(skip_runner, "choice", "phase2 skip reaches choice")
    _expect(skip_runner.choose("skip_test"), "phase2 unconditional route can be chosen")
    var skip_end: bool = false
    for _step: int in range(MAX_STEPS):
        var skip_command: Dictionary = skip_runner.current()
        if skip_command.is_empty():
            break
        if String(skip_command.get("op", "")) == "end":
            skip_end = true
            break
        skip_runner.advance()
    _expect(skip_end, "unconditional phase2 route reaches an ending")
    _expect(String(skip_runner.flags.get("route", "")) == "skip", "choice set_flags is retained")


func _test_conditional_option_visibility_and_rejection() -> void:
    var story: Dictionary = _base_story()
    story["nodes"]["entry"]["steps"] = [
        {
            "op": "choice",
            "prompt": "條件測試",
            "options": [
                { "id": "locked", "label": "需要瓶子", "require": "milk_bottle", "next": "done" },
                { "id": "fallback", "label": "無條件", "next": "done" }
            ]
        }
    ]
    story["nodes"]["done"] = {"title": "結束", "steps": [{"op": "end", "text": "done"}]}
    var path: String = _write_temp_story("conditional_options", story)
    var runner = StoryRunner.new()
    _expect(runner.load_story(path), "conditional option story loads")
    var choice: Dictionary = runner.current()
    _expect(not _option_exists(choice, "locked"), "unowned required option is hidden")
    _expect(_option_exists(choice, "fallback"), "fallback option remains visible")
    var before: Dictionary = runner.snapshot()
    _expect(not runner.choose("locked"), "hidden required option is rejected")
    _expect(runner.snapshot() == before, "choosing hidden option does not mutate state")
    _remove_temp_story(path)


func _test_duplicate_item_acquisition() -> void:
    var story: Dictionary = _base_story()
    story["nodes"]["entry"]["steps"] = [
        { "op": "item", "id": "milk_bottle" },
        { "op": "item", "id": "milk_bottle" },
        { "op": "say", "speaker": "narrator", "text": "duplicate check" },
        { "op": "end", "text": "done" }
    ]
    var path: String = _write_temp_story("duplicate_item", story)
    var runner = StoryRunner.new()
    _expect(runner.load_story(path), "duplicate item story loads")
    _expect(runner.items.size() == 1 and runner.items[0] == "milk_bottle", "duplicate item acquisition is idempotent")
    _remove_temp_story(path)


func _test_snapshot_items_and_strict_restore() -> void:
    var source = StoryRunner.new()
    _expect(source.load_story(STORY_PATH), "snapshot source loads")
    _advance_until_op(source, "choice", "snapshot reaches choice")
    var saved: Dictionary = source.snapshot()
    _expect(saved.has("items"), "snapshot includes items")
    _expect((saved["items"] as Array).has("milk_bottle"), "snapshot stores acquired item")

    var restored = StoryRunner.new()
    _expect(restored.load_story(STORY_PATH), "snapshot target loads")
    _expect(restored.restore(saved), "snapshot with items restores")
    _expect(restored.snapshot() == saved, "restored snapshot including items is exact")
    _expect(restored.items.has("milk_bottle"), "restore restores inventory")

    var before_bad: Dictionary = restored.snapshot()
    var unknown_item: Dictionary = before_bad.duplicate(true)
    (unknown_item["items"] as Array).append("not_a_catalog_item")
    _expect(not restored.restore(unknown_item), "snapshot rejects unknown item")
    _expect(restored.snapshot() == before_bad, "unknown item restore leaves state unchanged")

    var duplicate_item: Dictionary = before_bad.duplicate(true)
    (duplicate_item["items"] as Array).append("milk_bottle")
    _expect(not restored.restore(duplicate_item), "snapshot rejects duplicate item")
    _expect(restored.snapshot() == before_bad, "duplicate item restore leaves state unchanged")

    var missing_items: Dictionary = before_bad.duplicate(true)
    missing_items.erase("items")
    _expect(not restored.restore(missing_items), "snapshot rejects missing items field")
    _expect(restored.snapshot() == before_bad, "missing items restore leaves state unchanged")


func _test_invalid_references_are_rejected() -> void:
    var invalid_cases: Array[Dictionary] = [
        {"label": "missing_character", "step": {"op": "char", "id": "not_a_character"}},
        {"label": "missing_material", "step": {"op": "item", "id": "not_an_item"}},
        {"label": "missing_background", "step": {"op": "bg", "id": "not_a_background"}},
        {"label": "unknown_op", "step": {"op": "not_an_op"}}
    ]
    for test_case: Dictionary in invalid_cases:
        var story: Dictionary = _base_story()
        story["nodes"]["entry"]["steps"] = [test_case["step"]]
        var path: String = _write_temp_story(String(test_case["label"]), story)
        var runner = StoryRunner.new()
        _expect(not runner.load_story(path), "%s is rejected" % test_case["label"])
        _expect(runner.error_message.contains("node 'entry' step 0"), "%s error contains node and step" % test_case["label"])
        _remove_temp_story(path)

    var unknown_require_story: Dictionary = _base_story()
    unknown_require_story["nodes"]["entry"]["steps"] = [{
        "op": "choice",
        "prompt": "未知素材",
        "options": [
            {"id": "locked", "label": "locked", "require": "not_an_item", "next": "done"},
            {"id": "fallback", "label": "fallback", "next": "done"}
        ]
    }]
    unknown_require_story["nodes"]["done"] = {"title": "結束", "steps": [{"op": "end", "text": "done"}]}
    var unknown_require_path: String = _write_temp_story("unknown_require", unknown_require_story)
    var unknown_require_runner = StoryRunner.new()
    _expect(not unknown_require_runner.load_story(unknown_require_path), "unknown choice material is rejected")
    _expect(unknown_require_runner.error_message.contains("node 'entry' step 0"), "unknown choice material error contains node and step")
    _remove_temp_story(unknown_require_path)

    var invalid_node_story: Dictionary = _base_story()
    invalid_node_story["nodes"]["entry"]["steps"] = [{"op": "goto", "target": "missing_node"}]
    var invalid_node_path: String = _write_temp_story("missing_node", invalid_node_story)
    var invalid_node_runner = StoryRunner.new()
    _expect(not invalid_node_runner.load_story(invalid_node_path), "missing node target is rejected")
    _remove_temp_story(invalid_node_path)


func _test_failed_load_preserves_story() -> void:
    var runner = StoryRunner.new()
    _expect(runner.load_story(STORY_PATH), "preserve test source loads")
    _advance_until_op(runner, "choice", "preserve test reaches choice")
    var before: Dictionary = runner.snapshot()
    var invalid_story: Dictionary = _base_story()
    invalid_story["nodes"]["entry"]["steps"] = [{"op": "char", "id": "missing"}]
    var path: String = _write_temp_story("failed_load_preserve", invalid_story)
    _expect(not runner.load_story(path), "invalid story load is rejected")
    _expect(runner.snapshot() == before, "failed load preserves current story state")
    _remove_temp_story(path)


func _base_story() -> Dictionary:
    return {
        "id": "phase2_test",
        "version": "0.1",
        "title": "Phase 2 test",
        "entry": "entry",
        "initial_flags": {},
        "nodes": {
            "entry": {
                "title": "Entry",
                "steps": [
                    {"op": "say", "speaker": "narrator", "text": "test"},
                    {"op": "end", "text": "done"}
                ]
            }
        }
    }


func _option_exists(command: Dictionary, option_id: String) -> bool:
    for raw_option: Variant in command.get("options", []):
        if typeof(raw_option) == TYPE_DICTIONARY and String((raw_option as Dictionary).get("id", "")) == option_id:
            return true
    return false


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


func _write_temp_story(label: String, story: Dictionary) -> String:
    var path: String = "user://phase2_story_%s.json" % label
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _expect(false, "unable to create temporary story: %s" % label)
        return path
    file.store_string(JSON.stringify(story))
    file.close()
    return path


func _remove_temp_story(path: String) -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
