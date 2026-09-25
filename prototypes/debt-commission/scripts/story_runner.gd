extends RefCounted

## Data-driven story runtime for the debt commission prototype.
## The script deliberately does not use class_name; callers preload it directly.

const MAX_INTERNAL_TRANSITIONS: int = 128
const ASSET_CATALOG_PATH: String = "res://data/asset_catalog.json"
const HEX_DIGITS: String = "0123456789abcdefABCDEF"
const DEFAULT_GAMEPLAY: Dictionary = {
    "glasses": 5,
    "max_glasses": 5,
    "power": 0,
    "max_power": 100,
}
const VALID_BOKE_RESULTS: Array[String] = ["perfect", "weak", "fail", "hidden"]

const VALID_OPS: Array[String] = [
    "bg",
    "char",
    "say",
    "choice",
    "item",
    "flag",
    "show",
    "hide",
    "move",
    "face",
    "expression",
    "camera",
    "wait",
    "sound",
    "end",
    "set_flag",
    "condition",
    "goto",
    "investigate",
    "boke_round",
    "profile",
]

const VALID_STAGE_POSITIONS: Array[String] = ["reader", "host", "door", "landlady", "other_side"]
const VALID_CHARACTER_POSITIONS: Array[String] = ["left", "center", "right"]
const VALID_EXPRESSIONS: Array[String] = ["neutral", "smile", "annoyed", "surprised", "thinking"]
const VALID_DIRECTIONS: Array[String] = ["left", "right", "up", "down"]
const VALID_SOUNDS: Array[String] = ["paper", "knock", "step", "stamp"]

var flags: Dictionary = {}
var items: Array[String] = []
## Character profiles unlocked by `profile` steps, in unlock order (the case file).
var profiles: Array[String] = []
var gameplay: Dictionary = DEFAULT_GAMEPLAY.duplicate(true)
var checked_hotspots: Dictionary = {}
var error_message: String = ""
var node_id: String = ""
var step_index: int = 0

var _story: Dictionary = {}
var _asset_catalog: Dictionary = {}
var _initial_flags: Dictionary = {}
var _allowed_flag_values: Dictionary = {}
var _loaded: bool = false
var _has_phase3_ops: bool = false
var _boke_round_id: String = ""
var _boke_line_index: int = 0
var _listened_line_ids: Array[String] = []
var _checkpoint: Dictionary = {}
var _game_over_active: bool = false
var _profiles_before_normalize: Array[String] = []


func load_story(path: String) -> bool:
    if not FileAccess.file_exists(path):
        return _reject("Story file does not exist: %s" % path)

    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _reject("Unable to open story file: %s" % path)

    var parser := JSON.new()
    var parse_error: Error = parser.parse(file.get_as_text())
    if parse_error != OK:
        return _reject("Invalid story JSON at %s: %s" % [path, parser.get_error_message()])

    var parsed: Variant = parser.data
    var catalog_result: Dictionary = _read_asset_catalog()
    if not bool(catalog_result.get("ok", false)):
        return _reject("Invalid asset catalog: %s" % String(catalog_result.get("error", "unknown error")))

    var candidate_catalog: Dictionary = catalog_result["catalog"] as Dictionary
    var validation_error: String = _validate_story(parsed, candidate_catalog)
    if not validation_error.is_empty():
        return _reject("Invalid story: %s" % validation_error)

    var candidate: Dictionary = parsed as Dictionary
    var candidate_flags: Dictionary = candidate["initial_flags"].duplicate(true)
    var candidate_allowed_values: Dictionary = _collect_allowed_flag_values(candidate)
    var candidate_has_phase3_ops: bool = _story_has_phase3_ops(candidate)

    # Keep the current story intact if a validated-but-looping story cannot
    # establish its initial position.
    var previous_story: Dictionary = _story
    var previous_asset_catalog: Dictionary = _asset_catalog
    var previous_initial_flags: Dictionary = _initial_flags
    var previous_allowed_values: Dictionary = _allowed_flag_values
    var previous_flags: Dictionary = flags
    var previous_loaded: bool = _loaded
    var previous_node_id: String = node_id
    var previous_step_index: int = step_index
    var previous_items: Array[String] = items.duplicate()
    var previous_gameplay: Dictionary = gameplay.duplicate(true)
    var previous_checked_hotspots: Dictionary = checked_hotspots.duplicate(true)
    var previous_has_phase3_ops: bool = _has_phase3_ops
    var previous_boke_round_id: String = _boke_round_id
    var previous_boke_line_index: int = _boke_line_index
    var previous_listened_line_ids: Array[String] = _listened_line_ids.duplicate()
    var previous_checkpoint: Dictionary = _checkpoint.duplicate(true)
    var previous_game_over_active: bool = _game_over_active

    _story = candidate.duplicate(true)
    _asset_catalog = candidate_catalog.duplicate(true)
    _initial_flags = candidate_flags
    _allowed_flag_values = candidate_allowed_values
    _has_phase3_ops = candidate_has_phase3_ops
    _loaded = true
    flags = {}
    items = []
    profiles = []
    gameplay = DEFAULT_GAMEPLAY.duplicate(true)
    checked_hotspots = {}
    _boke_round_id = ""
    _boke_line_index = 0
    _listened_line_ids = []
    _checkpoint = {}
    _game_over_active = false
    node_id = ""
    step_index = 0
    error_message = ""

    if not _reset_state():
        _story = previous_story
        _asset_catalog = previous_asset_catalog
        _initial_flags = previous_initial_flags
        _allowed_flag_values = previous_allowed_values
        flags = previous_flags
        _loaded = previous_loaded
        node_id = previous_node_id
        step_index = previous_step_index
        items = previous_items
        gameplay = previous_gameplay
        checked_hotspots = previous_checked_hotspots
        _has_phase3_ops = previous_has_phase3_ops
        _boke_round_id = previous_boke_round_id
        _boke_line_index = previous_boke_line_index
        _listened_line_ids = previous_listened_line_ids
        _checkpoint = previous_checkpoint
        _game_over_active = previous_game_over_active
        error_message = "Invalid story: unable to initialize entry command."
        return false

    return true


func get_asset_catalog() -> Dictionary:
    return _asset_catalog.duplicate(true)


## Collected materials and unlocked character profiles with their catalog text, in the
## order the player got them. Intended for a materials/profiles screen.
func case_file() -> Dictionary:
    var materials: Array = []
    var item_catalog: Dictionary = _asset_catalog.get("items", {}) as Dictionary
    for item_id: String in items:
        var item: Dictionary = item_catalog.get(item_id, {}) as Dictionary
        materials.append({"id": item_id, "name": String(item.get("name", item_id)), "description": String(item.get("description", ""))})
    var people: Array = []
    var characters: Dictionary = _character_catalog()
    for character_id: String in profiles:
        var character: Dictionary = characters.get(character_id, {}) as Dictionary
        people.append({"id": character_id, "name": String(character.get("name", character_id)), "profile": String(character.get("profile", ""))})
    return {"materials": materials, "profiles": people}


func reset() -> void:
    if not _loaded:
        flags = {}
        items = []
        profiles = []
        gameplay = DEFAULT_GAMEPLAY.duplicate(true)
        checked_hotspots = {}
        _boke_round_id = ""
        _boke_line_index = 0
        _listened_line_ids = []
        _checkpoint = {}
        _game_over_active = false
        node_id = ""
        step_index = 0
        error_message = "No story is loaded."
        return
    _reset_state()


func current() -> Dictionary:
    if not _loaded:
        return {}

    var command: Dictionary = _current_command()
    if command.is_empty():
        return {}

    _prepare_interactive_command(command)
    if String(command.get("op", "")) == "investigate":
        command = _decorate_investigation(command)
    elif String(command.get("op", "")) == "boke_round":
        command = _decorate_boke_round(command)

    command["node_id"] = node_id
    command["node_title"] = _node_title(node_id)
    command["step_index"] = step_index
    return command


func advance() -> Dictionary:
    if not _loaded:
        error_message = "No story is loaded."
        return {}

    var command: Dictionary = current()
    if command.is_empty():
        if error_message.is_empty():
            error_message = "No presentable command is available."
        return {}

    var op: String = String(command.get("op", ""))
    if op == "choice" or op == "end" or op == "boke_round":
        error_message = "The current command requires a choice or is already at the end."
        return command
    if op == "investigate" and not _investigation_is_complete(command):
        error_message = "Inspect every hotspot before continuing."
        return command

    error_message = ""
    step_index += 1
    if not _normalize_position():
        return command
    return current()


func inspect_hotspot(hotspot_id: String) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "investigate":
        return _reject("The current command is not an investigation.")
    var investigation_id: String = String(command.get("id", ""))
    var hotspots: Array = command.get("hotspots", []) as Array
    var selected_hotspot: Dictionary = {}
    for raw_hotspot: Variant in hotspots:
        if raw_hotspot is Dictionary and String((raw_hotspot as Dictionary).get("id", "")) == hotspot_id:
            selected_hotspot = raw_hotspot as Dictionary
            break
    if selected_hotspot.is_empty():
        return _reject("Unknown hotspot '%s' in investigation '%s'." % [hotspot_id, investigation_id])
    var checked: Array[String] = _checked_hotspots_for(investigation_id)
    if not checked.has(hotspot_id):
        checked.append(hotspot_id)
        checked_hotspots[investigation_id] = checked
    var item_id: String = String(selected_hotspot.get("item", ""))
    if not items.has(item_id):
        items.append(item_id)
    error_message = ""
    return true


func set_boke_line(index: int) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "boke_round":
        return _reject("The current command is not a boke round.")
    var lines: Array = command.get("lines", []) as Array
    if index < 0 or index >= lines.size():
        return _reject("Boke line index is outside the round.")
    _prepare_interactive_command(command)
    _boke_line_index = index
    error_message = ""
    return true


func listen_boke_line() -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "boke_round":
        return _reject("The current command is not a boke round.")
    _prepare_interactive_command(command)
    var lines: Array = command.get("lines", []) as Array
    var line: Dictionary = lines[_boke_line_index] as Dictionary
    if not _is_non_empty_string(line.get("listen", null)):
        return _reject("The current boke line has no Listen follow-up.")
    var line_id: String = String(line.get("id", ""))
    if not _listened_line_ids.has(line_id):
        _listened_line_ids.append(line_id)
    error_message = ""
    return true


func resolve_boke(option_id: String) -> Dictionary:
    if not _loaded:
        _reject("No story is loaded.")
        return {}
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "boke_round":
        _reject("The current command is not a boke round.")
        return {}
    _prepare_interactive_command(command)
    var visible_options: Array = _visible_boke_options(command)
    for raw_option: Variant in visible_options:
        if not raw_option is Dictionary:
            continue
        var option: Dictionary = raw_option as Dictionary
        if String(option.get("id", "")) == option_id:
            return _resolve_boke_result(command, option)
    _reject("Invalid or unavailable boke option: %s" % option_id)
    return {}


func timeout_boke() -> Dictionary:
    if not _loaded:
        _reject("No story is loaded.")
        return {}
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "boke_round":
        _reject("The current command is not a boke round.")
        return {}
    var tsukkomi: Dictionary = command.get("tsukkomi", {}) as Dictionary
    var timeout: Dictionary = tsukkomi.get("timeout", {}) as Dictionary
    return _resolve_boke_result(command, timeout)


func retry_checkpoint() -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    if not _game_over_active or _checkpoint.is_empty():
        return _reject("There is no game-over checkpoint to retry.")
    var checkpoint: Dictionary = _checkpoint.duplicate(true)
    flags = checkpoint["flags"].duplicate(true)
    items = _copy_string_array(checkpoint["items"] as Array)
    profiles = _copy_string_array(checkpoint.get("profiles", profiles) as Array)
    gameplay = checkpoint["gameplay"].duplicate(true)
    checked_hotspots = checkpoint["checked_hotspots"].duplicate(true)
    node_id = String(checkpoint["node_id"])
    step_index = int(checkpoint["step_index"])
    _boke_round_id = String(checkpoint["round_id"])
    _boke_line_index = 0
    _listened_line_ids = []
    _game_over_active = false
    error_message = ""
    if not _normalize_position():
        _game_over_active = true
        return false
    return true


func _prepare_interactive_command(command: Dictionary) -> void:
    var op: String = String(command.get("op", ""))
    if op == "investigate":
        var investigation_id: String = String(command.get("id", ""))
        if not checked_hotspots.has(investigation_id):
            checked_hotspots[investigation_id] = []
    elif op == "boke_round":
        var round_id: String = String(command.get("id", ""))
        if _boke_round_id != round_id:
            _boke_round_id = round_id
            _boke_line_index = 0
            _listened_line_ids = []
        if _checkpoint.get("round_id", "") != round_id:
            _capture_round_checkpoint(command)


func _capture_round_checkpoint(command: Dictionary) -> void:
    _checkpoint = {
        "round_id": String(command.get("id", "")),
        "game_over": String(command.get("game_over", "")),
        "node_id": node_id,
        "step_index": step_index,
        "flags": flags.duplicate(true),
        "items": items.duplicate(),
        "profiles": profiles.duplicate(),
        "gameplay": gameplay.duplicate(true),
        "checked_hotspots": checked_hotspots.duplicate(true),
    }


func _decorate_investigation(command: Dictionary) -> Dictionary:
    var decorated: Dictionary = command.duplicate(true)
    var investigation_id: String = String(decorated.get("id", ""))
    var checked: Array[String] = _checked_hotspots_for(investigation_id)
    var hotspots: Array = decorated.get("hotspots", []) as Array
    for index: int in range(hotspots.size()):
        var hotspot: Dictionary = hotspots[index] as Dictionary
        hotspot["checked"] = checked.has(String(hotspot.get("id", "")))
        hotspots[index] = hotspot
    decorated["hotspots"] = hotspots
    return decorated


func _decorate_boke_round(command: Dictionary) -> Dictionary:
    var decorated: Dictionary = command.duplicate(true)
    var lines: Array = decorated.get("lines", []) as Array
    var line: Dictionary = lines[_boke_line_index] as Dictionary
    var current_line: Dictionary = line.duplicate(true)
    var listened: bool = _listened_line_ids.has(String(line.get("id", "")))
    current_line["listened"] = listened
    current_line["listen_text"] = String(line.get("listen", "")) if listened else ""
    decorated["line_index"] = _boke_line_index
    decorated["listened"] = listened
    decorated["current_line"] = current_line
    decorated["listened_line_ids"] = _listened_line_ids.duplicate()
    var tsukkomi: Dictionary = decorated.get("tsukkomi", {}) as Dictionary
    tsukkomi["options"] = _visible_boke_options(command)
    decorated["tsukkomi"] = tsukkomi
    return decorated


func _visible_boke_options(command: Dictionary) -> Array:
    var visible_options: Array = []
    var tsukkomi: Dictionary = command.get("tsukkomi", {}) as Dictionary
    var raw_options: Variant = tsukkomi.get("options", [])
    if not raw_options is Array:
        return visible_options
    for raw_option: Variant in raw_options as Array:
        if not raw_option is Dictionary:
            continue
        var option: Dictionary = raw_option as Dictionary
        if not option.has("require") or items.has(String(option["require"])):
            visible_options.append(option.duplicate(true))
    return visible_options


func _checked_hotspots_for(investigation_id: String) -> Array[String]:
    var value: Variant = checked_hotspots.get(investigation_id, [])
    if value is Array:
        return _copy_string_array(value as Array)
    return []


func _investigation_is_complete(command: Dictionary) -> bool:
    var investigation_id: String = String(command.get("id", ""))
    var hotspots: Array = command.get("hotspots", []) as Array
    var checked: Array[String] = _checked_hotspots_for(investigation_id)
    if hotspots.is_empty():
        return false
    for raw_hotspot: Variant in hotspots:
        if not raw_hotspot is Dictionary or not checked.has(String((raw_hotspot as Dictionary).get("id", ""))):
            return false
    return true


func _resolve_boke_result(command: Dictionary, resolution: Dictionary) -> Dictionary:
    if _game_over_active:
        _reject("The current boke round is already resolved.")
        return {}
    var result: String = String(resolution.get("result", ""))
    if not VALID_BOKE_RESULTS.has(result):
        _reject("Invalid boke result: %s" % result)
        return {}

    var target: String = String(resolution.get("goto", ""))
    if not _story_node_exists(target):
        _reject("Boke result target does not exist: %s" % target)
        return {}

    var next_flags: Dictionary = flags.duplicate(true)
    var set_flags: Dictionary = resolution.get("set_flags", {}) as Dictionary
    for key: Variant in set_flags.keys():
        var flag_key: String = String(key)
        var value: Variant = set_flags[key]
        if not _flag_value_is_allowed(flag_key, value):
            _reject("Boke result writes an invalid flag value: %s" % flag_key)
            return {}
        next_flags[flag_key] = value

    var next_gameplay: Dictionary = gameplay.duplicate(true)
    match result:
        "perfect":
            next_gameplay["power"] = mini(int(next_gameplay["max_power"]), int(next_gameplay["power"]) + 30)
        "weak":
            next_gameplay["power"] = mini(int(next_gameplay["max_power"]), int(next_gameplay["power"]) + 10)
        "fail":
            next_gameplay["glasses"] = maxi(0, int(next_gameplay["glasses"]) - 1)

    var game_over: bool = result == "fail" and int(next_gameplay["glasses"]) == 0
    if game_over:
        target = String(command.get("game_over", ""))

    var before: Dictionary = snapshot()
    flags = next_flags
    gameplay = next_gameplay
    node_id = target
    step_index = 0
    _boke_round_id = ""
    _boke_line_index = 0
    _listened_line_ids = []
    _game_over_active = game_over
    error_message = ""
    if not _normalize_position():
        restore(before)
        return {}
    return {"result": result, "goto": target, "game_over": game_over}


func choose(option_id: String) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")

    var command: Dictionary = current()
    if command.is_empty() or String(command.get("op", "")) != "choice":
        return _reject("The current command is not a choice.")

    var selected_option: Dictionary = {}
    var options: Array = command.get("options", [])
    for option_variant: Variant in options:
        if typeof(option_variant) != TYPE_DICTIONARY:
            continue
        var option: Dictionary = option_variant as Dictionary
        if String(option.get("id", "")) == option_id:
            selected_option = option
            break

    if selected_option.is_empty():
        return _reject("Invalid choice option: %s" % option_id)

    var target: String = String(selected_option.get("next", ""))
    if not _story_node_exists(target):
        return _reject("Choice target does not exist: %s" % target)

    var next_flags: Dictionary = flags.duplicate(true)
    var set_flags: Dictionary = selected_option.get("set_flags", {})
    for key: Variant in set_flags.keys():
        var flag_key: String = String(key)
        var value: Variant = set_flags[key]
        if not _flag_value_is_allowed(flag_key, value):
            return _reject("Choice writes an invalid flag value: %s" % flag_key)
        next_flags[flag_key] = value

    var previous_flags: Dictionary = flags
    var previous_node_id: String = node_id
    var previous_step_index: int = step_index
    var previous_items: Array[String] = items.duplicate()
    flags = next_flags
    node_id = target
    step_index = 0
    error_message = ""
    if not _normalize_position():
        flags = previous_flags
        node_id = previous_node_id
        step_index = previous_step_index
        items = previous_items
        return false

    return true


func snapshot() -> Dictionary:
    if not _loaded:
        return {}
    var command: Dictionary = _current_command()
    _prepare_interactive_command(command)

    return {
        "story_id": String(_story.get("id", "")),
        "version": _story.get("version", ""),
        "node_id": node_id,
        "step_index": step_index,
        "flags": flags.duplicate(true),
        "items": items.duplicate(),
        "profiles": profiles.duplicate(),
        "gameplay": gameplay.duplicate(true),
        "checked_hotspots": checked_hotspots.duplicate(true),
        "boke": {
            "round_id": _boke_round_id,
            "line_index": _boke_line_index,
            "listened_line_ids": _listened_line_ids.duplicate(),
        },
        "checkpoint": _checkpoint.duplicate(true),
        "game_over_active": _game_over_active,
    }


func restore(snapshot_data: Dictionary) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")

    var validation_error: String = _validate_snapshot(snapshot_data)
    if not validation_error.is_empty():
        return _reject("Invalid snapshot: %s" % validation_error)

    # All validation is complete before any live state is assigned. Invalid
    # or incompatible save data therefore cannot partially mutate the runner.
    flags = snapshot_data["flags"].duplicate(true)
    items = _copy_string_array(snapshot_data["items"] as Array)
    profiles = _copy_string_array(snapshot_data.get("profiles", []) as Array)
    node_id = String(snapshot_data["node_id"])
    step_index = int(snapshot_data["step_index"])
    gameplay = (snapshot_data.get("gameplay", DEFAULT_GAMEPLAY) as Dictionary).duplicate(true)
    checked_hotspots = (snapshot_data.get("checked_hotspots", {}) as Dictionary).duplicate(true)
    var boke_state: Dictionary = snapshot_data.get("boke", {}) as Dictionary
    _boke_round_id = String(boke_state.get("round_id", ""))
    _boke_line_index = int(boke_state.get("line_index", 0))
    _listened_line_ids = _copy_string_array(boke_state.get("listened_line_ids", []) as Array)
    _checkpoint = snapshot_data.get("checkpoint", {}).duplicate(true)
    _game_over_active = bool(snapshot_data.get("game_over_active", false))
    error_message = ""
    return true


func _reset_state() -> bool:
    flags = _initial_flags.duplicate(true)
    items = []
    profiles = []
    gameplay = DEFAULT_GAMEPLAY.duplicate(true)
    checked_hotspots = {}
    _boke_round_id = ""
    _boke_line_index = 0
    _listened_line_ids = []
    _checkpoint = {}
    _game_over_active = false
    node_id = String(_story.get("entry", ""))
    step_index = 0
    error_message = ""
    return _normalize_position()


func _normalize_position() -> bool:
    var original_node_id: String = node_id
    var original_step_index: int = step_index
    var original_flags: Dictionary = flags.duplicate(true)
    var original_items: Array[String] = items.duplicate()
    _profiles_before_normalize = profiles.duplicate()
    var transitions: int = 0

    while transitions < MAX_INTERNAL_TRANSITIONS:
        if not _story_node_exists(node_id):
            return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Unknown node: %s" % node_id)

        var node: Dictionary = _story["nodes"][node_id] as Dictionary
        var steps: Array = node["steps"] as Array
        if step_index >= steps.size():
            if not node.has("next"):
                return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Node has no next target: %s" % node_id)
            node_id = String(node["next"])
            step_index = 0
            transitions += 1
            continue

        if step_index < 0:
            return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Negative step index in node: %s" % node_id)

        var step: Dictionary = steps[step_index] as Dictionary
        var op: String = String(step.get("op", ""))
        match op:
            "set_flag":
                var flag_key: String = String(step["key"])
                flags[flag_key] = step["value"]
                step_index += 1
            "flag":
                var flag_op_key: String = String(step["key"])
                flags[flag_op_key] = step["value"]
                step_index += 1
            "item":
                var item_id: String = String(step["id"])
                if not items.has(item_id):
                    items.append(item_id)
                step_index += 1
            "profile":
                var profile_id: String = String(step["id"])
                if not profiles.has(profile_id):
                    profiles.append(profile_id)
                step_index += 1
            "condition":
                var condition_key: String = String(step["flag"])
                var target: String = String(step["else"])
                if flags.get(condition_key, null) == step["equals"]:
                    target = String(step["then"])
                if not _story_node_exists(target):
                    return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Condition target does not exist: %s" % target)
                node_id = target
                step_index = 0
            "goto":
                var goto_target: String = String(step["target"])
                if not _story_node_exists(goto_target):
                    return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Goto target does not exist: %s" % goto_target)
                node_id = goto_target
                step_index = 0
            _:
                error_message = ""
                return true

        transitions += 1

    return _rollback_normalization(original_node_id, original_step_index, original_flags, original_items, "Internal story jump limit exceeded.")


func _rollback_normalization(original_node_id: String, original_step_index: int, original_flags: Dictionary, original_items: Array[String], message: String) -> bool:
    node_id = original_node_id
    step_index = original_step_index
    flags = original_flags
    items = original_items.duplicate()
    profiles = _profiles_before_normalize.duplicate()
    error_message = message
    return false


func _current_command() -> Dictionary:
    if not _story_node_exists(node_id):
        return {}

    var node: Dictionary = _story["nodes"][node_id] as Dictionary
    var steps: Array = node["steps"] as Array
    if step_index < 0 or step_index >= steps.size():
        return {}

    var command: Dictionary = steps[step_index] as Dictionary
    var op: String = String(command.get("op", ""))
    if op == "set_flag" or op == "flag" or op == "item" or op == "condition" or op == "goto":
        return {}

    var presentable_command: Dictionary = command.duplicate(true)
    if op == "char":
        var character_id: String = String(presentable_command.get("id", ""))
        var character_entry: Dictionary = _character_catalog().get(character_id, {}) as Dictionary
        if not presentable_command.has("visible"):
            presentable_command["visible"] = true
        if not presentable_command.has("expression"):
            presentable_command["expression"] = "neutral"
        if not presentable_command.has("position"):
            presentable_command["position"] = String(character_entry.get("slot", "center"))
    elif op == "choice":
        presentable_command["options"] = _visible_choice_options(presentable_command.get("options", []))
    return presentable_command


func _node_title(target_node_id: String) -> String:
    if not _story_node_exists(target_node_id):
        return ""
    var node: Dictionary = _story["nodes"][target_node_id] as Dictionary
    return String(node.get("title", ""))


func _story_node_exists(target_node_id: String) -> bool:
    if not _story.has("nodes"):
        return false
    var nodes: Dictionary = _story["nodes"] as Dictionary
    return nodes.has(target_node_id) and typeof(nodes[target_node_id]) == TYPE_DICTIONARY


func _visible_choice_options(raw_options: Variant) -> Array:
    var visible_options: Array = []
    if typeof(raw_options) != TYPE_ARRAY:
        return visible_options
    for raw_option: Variant in raw_options as Array:
        if typeof(raw_option) != TYPE_DICTIONARY:
            continue
        var option: Dictionary = raw_option as Dictionary
        if not option.has("require") or items.has(String(option["require"])):
            visible_options.append(option.duplicate(true))
    return visible_options


func _character_catalog() -> Dictionary:
    return _asset_catalog.get("characters", {}) as Dictionary


func _catalog_has_character(asset_catalog: Dictionary, character_id: String) -> bool:
    var characters: Dictionary = asset_catalog.get("characters", {}) as Dictionary
    return not character_id.is_empty() and characters.has(character_id)


func _catalog_has_background(asset_catalog: Dictionary, background_id: String) -> bool:
    var backgrounds: Dictionary = asset_catalog.get("backgrounds", {}) as Dictionary
    return not background_id.is_empty() and backgrounds.has(background_id)


func _catalog_has_item(asset_catalog: Dictionary, item_id: String) -> bool:
    var item_catalog: Dictionary = asset_catalog.get("items", {}) as Dictionary
    return not item_id.is_empty() and item_catalog.has(item_id)


func _is_normalized_position(value: Variant) -> bool:
    if not value is Array or (value as Array).size() != 2:
        return false
    var position: Array = value as Array
    return _is_number_between(position[0], 0.0, 1.0) and _is_number_between(position[1], 0.0, 1.0)


func _story_has_phase3_ops(story: Dictionary) -> bool:
    var nodes: Dictionary = story.get("nodes", {}) as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        for raw_step: Variant in node.get("steps", []) as Array:
            var step: Dictionary = raw_step as Dictionary
            if String(step.get("op", "")) == "investigate" or String(step.get("op", "")) == "boke_round":
                return true
    return false


func _validate_phase3_ids(nodes: Dictionary) -> String:
    var investigation_ids: Dictionary = {}
    var round_ids: Dictionary = {}
    for raw_node_id: Variant in nodes.keys():
        var node: Dictionary = nodes[raw_node_id] as Dictionary
        var steps: Array = node["steps"] as Array
        for index: int in range(steps.size()):
            var step: Dictionary = steps[index] as Dictionary
            var prefix: String = "node '%s' step %d" % [raw_node_id, index]
            var op: String = String(step.get("op", ""))
            if op == "investigate":
                var investigation_id: String = String(step.get("id", ""))
                if investigation_ids.has(investigation_id):
                    return "%s repeats investigation id '%s'" % [prefix, investigation_id]
                investigation_ids[investigation_id] = true
            elif op == "boke_round":
                var round_id: String = String(step.get("id", ""))
                if round_ids.has(round_id):
                    return "%s repeats boke_round id '%s'" % [prefix, round_id]
                round_ids[round_id] = true
    return ""


func _read_asset_catalog() -> Dictionary:
    if not FileAccess.file_exists(ASSET_CATALOG_PATH):
        return {"ok": false, "error": "catalog file does not exist: %s" % ASSET_CATALOG_PATH}

    var file: FileAccess = FileAccess.open(ASSET_CATALOG_PATH, FileAccess.READ)
    if file == null:
        return {"ok": false, "error": "unable to open catalog file"}

    var parser := JSON.new()
    var parse_error: Error = parser.parse(file.get_as_text())
    if parse_error != OK:
        return {"ok": false, "error": "invalid catalog JSON: %s" % parser.get_error_message()}

    var parsed: Variant = parser.data
    var validation_error: String = _validate_asset_catalog(parsed)
    if not validation_error.is_empty():
        return {"ok": false, "error": validation_error}

    return {"ok": true, "catalog": (parsed as Dictionary).duplicate(true)}


func _validate_asset_catalog(value: Variant) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "root must be an object"

    var catalog: Dictionary = value as Dictionary
    for required_key: String in ["backgrounds", "characters", "items"]:
        if not catalog.has(required_key):
            return "missing collection '%s'" % required_key
        if typeof(catalog[required_key]) != TYPE_DICTIONARY:
            return "collection '%s' must be an object" % required_key

    var backgrounds: Dictionary = catalog["backgrounds"] as Dictionary
    for raw_id: Variant in backgrounds.keys():
        if typeof(raw_id) != TYPE_STRING or String(raw_id).is_empty():
            return "background ids must be non-empty strings"
        var background_id: String = String(raw_id)
        if typeof(backgrounds[raw_id]) != TYPE_DICTIONARY:
            return "background '%s' must be an object" % background_id
        var background: Dictionary = backgrounds[raw_id] as Dictionary
        for required_key: String in ["label", "top", "bottom"]:
            if not background.has(required_key):
                return "background '%s' missing '%s'" % [background_id, required_key]
        if not _is_non_empty_string(background["label"]):
            return "background '%s' label must be a non-empty string" % background_id
        if not _is_css_hex(background["top"]) or not _is_css_hex(background["bottom"]):
            return "background '%s' top and bottom must be CSS hex colors" % background_id
        var background_path_error: String = _validate_optional_asset_path(background, "background", background_id)
        if not background_path_error.is_empty():
            return background_path_error

    var characters: Dictionary = catalog["characters"] as Dictionary
    for raw_id: Variant in characters.keys():
        if typeof(raw_id) != TYPE_STRING or String(raw_id).is_empty():
            return "character ids must be non-empty strings"
        var character_id: String = String(raw_id)
        if typeof(characters[raw_id]) != TYPE_DICTIONARY:
            return "character '%s' must be an object" % character_id
        var character: Dictionary = characters[raw_id] as Dictionary
        for required_key: String in ["name", "color", "slot"]:
            if not character.has(required_key):
                return "character '%s' missing '%s'" % [character_id, required_key]
        if not _is_non_empty_string(character["name"]):
            return "character '%s' name must be a non-empty string" % character_id
        if not _is_css_hex(character["color"]):
            return "character '%s' color must be a CSS hex color" % character_id
        if typeof(character["slot"]) != TYPE_STRING or not VALID_CHARACTER_POSITIONS.has(String(character["slot"])):
            return "character '%s' slot must be left, center, or right" % character_id
        var character_path_error: String = _validate_optional_asset_path(character, "character", character_id)
        if not character_path_error.is_empty():
            return character_path_error

    var item_catalog: Dictionary = catalog["items"] as Dictionary
    for raw_id: Variant in item_catalog.keys():
        if typeof(raw_id) != TYPE_STRING or String(raw_id).is_empty():
            return "item ids must be non-empty strings"
        var item_id: String = String(raw_id)
        if typeof(item_catalog[raw_id]) != TYPE_DICTIONARY:
            return "item '%s' must be an object" % item_id
        var item: Dictionary = item_catalog[raw_id] as Dictionary
        for required_key: String in ["name", "description"]:
            if not item.has(required_key):
                return "item '%s' missing '%s'" % [item_id, required_key]
        if not _is_non_empty_string(item["name"]) or not _is_non_empty_string(item["description"]):
            return "item '%s' name and description must be non-empty strings" % item_id
        var item_path_error: String = _validate_optional_asset_path(item, "item", item_id)
        if not item_path_error.is_empty():
            return item_path_error

    return ""


func _validate_optional_asset_path(entry: Dictionary, kind: String, asset_id: String) -> String:
    if not entry.has("path"):
        return ""
    if typeof(entry["path"]) != TYPE_STRING:
        return "%s '%s' path must be a string" % [kind, asset_id]
    var path: String = String(entry["path"])
    if path.is_empty():
        return ""
    if not path.begins_with("res://"):
        return "%s '%s' path must use res://" % [kind, asset_id]
    if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
        return "%s '%s' path does not exist: %s" % [kind, asset_id, path]
    return ""


func _is_css_hex(value: Variant) -> bool:
    if typeof(value) != TYPE_STRING:
        return false
    var color: String = String(value)
    if not [4, 5, 7, 9].has(color.length()) or not color.begins_with("#"):
        return false
    var digits: String = color.substr(1)
    for character: String in digits:
        if not HEX_DIGITS.contains(character):
            return false
    return true


func _validate_story(value: Variant, asset_catalog: Dictionary) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "root must be an object"

    var root: Dictionary = value as Dictionary
    for required_key: String in ["id", "version", "title", "entry", "initial_flags", "nodes"]:
        if not root.has(required_key):
            return "missing root field '%s'" % required_key

    if not _is_non_empty_string(root["id"]):
        return "id must be a non-empty string"
    if not _is_non_empty_string(root["version"]):
        return "version must be a non-empty string"
    if not _is_non_empty_string(root["title"]):
        return "title must be a non-empty string"
    if not _is_non_empty_string(root["entry"]):
        return "entry must be a non-empty string"
    if typeof(root["initial_flags"]) != TYPE_DICTIONARY:
        return "initial_flags must be an object"
    if typeof(root["nodes"]) != TYPE_DICTIONARY:
        return "nodes must be an object"

    var initial_flags: Dictionary = root["initial_flags"] as Dictionary
    var flag_error: String = _validate_flag_dictionary(initial_flags, "initial_flags")
    if not flag_error.is_empty():
        return flag_error

    var nodes: Dictionary = root["nodes"] as Dictionary
    if nodes.is_empty():
        return "nodes must not be empty"
    if not nodes.has(String(root["entry"])):
        return "entry node does not exist: %s" % root["entry"]

    for raw_node_id: Variant in nodes.keys():
        if typeof(raw_node_id) != TYPE_STRING or String(raw_node_id).is_empty():
            return "node ids must be non-empty strings"
        var current_node_id: String = String(raw_node_id)
        if typeof(nodes[raw_node_id]) != TYPE_DICTIONARY:
            return "node '%s' must be an object" % current_node_id
        var node: Dictionary = nodes[raw_node_id] as Dictionary
        var node_error: String = _validate_node(current_node_id, node, nodes, asset_catalog)
        if not node_error.is_empty():
            return node_error

    var phase3_id_error: String = _validate_phase3_ids(nodes)
    if not phase3_id_error.is_empty():
        return phase3_id_error

    var consistency_error: String = _validate_flag_consistency(root)
    if not consistency_error.is_empty():
        return consistency_error
    return ""


func _validate_node(current_node_id: String, node: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if not node.has("title") or not _is_non_empty_string(node["title"]):
        return "node '%s' title must be a non-empty string" % current_node_id
    if not node.has("steps") or typeof(node["steps"]) != TYPE_ARRAY:
        return "node '%s' steps must be an array" % current_node_id

    var steps: Array = node["steps"] as Array
    if steps.is_empty():
        return "node '%s' must contain at least one step" % current_node_id
    if node.has("next") and not _is_non_empty_string(node["next"]):
        return "node '%s' next must be a non-empty string" % current_node_id
    if node.has("next") and not nodes.has(String(node["next"])):
        return "node '%s' next target does not exist: %s" % [current_node_id, node["next"]]

    var final_op: String = ""
    for index: int in range(steps.size()):
        if typeof(steps[index]) != TYPE_DICTIONARY:
            return "node '%s' step %d must be an object" % [current_node_id, index]
        var step: Dictionary = steps[index] as Dictionary
        var step_error: String = _validate_step(current_node_id, index, step, nodes, asset_catalog)
        if not step_error.is_empty():
            return step_error
        final_op = String(step.get("op", ""))

    if final_op == "end" and node.has("next"):
        return "end node '%s' cannot have next" % current_node_id
    if final_op == "choice" and node.has("next"):
        return "choice node '%s' cannot have next" % current_node_id
    if not node.has("next") and final_op != "end" and final_op != "choice" and final_op != "goto" and final_op != "condition" and final_op != "boke_round":
        return "node '%s' needs next or a terminal step" % current_node_id
    return ""


func _validate_step(current_node_id: String, index: int, step: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    var prefix: String = "node '%s' step %d" % [current_node_id, index]
    if not step.has("op") or not _is_non_empty_string(step["op"]):
        return "%s must have an op" % prefix
    var op: String = String(step["op"])
    if not VALID_OPS.has(op):
        return "%s has unsupported op '%s'" % [prefix, op]

    match op:
        "bg":
            var background_id: String = String(step.get("id", ""))
            if not _catalog_has_background(asset_catalog, background_id):
                return "%s bg id '%s' is not in asset catalog" % [prefix, background_id]
        "char":
            var character_id: String = String(step.get("id", ""))
            if not _catalog_has_character(asset_catalog, character_id):
                return "%s char id '%s' is not in asset catalog" % [prefix, character_id]
            if step.has("visible") and typeof(step["visible"]) != TYPE_BOOL:
                return "%s char visible must be boolean" % prefix
            if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
                return "%s char expression is invalid" % prefix
            if step.has("position") and (typeof(step["position"]) != TYPE_STRING or not VALID_CHARACTER_POSITIONS.has(String(step["position"]))):
                return "%s char position is invalid" % prefix
        "say":
            var speaker: String = String(step.get("speaker", ""))
            if not _is_non_empty_string(step.get("speaker", null)):
                return "%s say speaker is invalid" % prefix
            if speaker != "narrator" and not _catalog_has_character(asset_catalog, speaker):
                return "%s say speaker '%s' is not in asset catalog" % [prefix, speaker]
            if not step.has("text") or typeof(step["text"]) != TYPE_STRING:
                return "%s say text must be a string" % prefix
            if step.has("thought") and typeof(step["thought"]) != TYPE_BOOL:
                return "%s say thought must be boolean" % prefix
            if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
                return "%s say expression is invalid" % prefix
        "choice":
            if not _is_non_empty_string(step.get("prompt", null)):
                return "%s choice prompt must be a non-empty string" % prefix
            if typeof(step.get("options", null)) != TYPE_ARRAY:
                return "%s choice options must be an array" % prefix
            var options: Array = step["options"] as Array
            if options.is_empty():
                return "%s choice needs at least one option" % prefix
            var option_ids: Array[String] = []
            var unconditional_options: int = 0
            for option_index: int in range(options.size()):
                if typeof(options[option_index]) != TYPE_DICTIONARY:
                    return "%s option %d must be an object" % [prefix, option_index]
                var option: Dictionary = options[option_index] as Dictionary
                if not _is_non_empty_string(option.get("id", null)) or not _is_non_empty_string(option.get("label", null)):
                    return "%s option %d needs id and label" % [prefix, option_index]
                var option_id: String = String(option["id"])
                if option_ids.has(option_id):
                    return "%s repeats option id '%s'" % [prefix, option_id]
                option_ids.append(option_id)
                if not _is_non_empty_string(option.get("next", null)) or not nodes.has(String(option["next"])):
                    return "%s option '%s' has an invalid next target" % [prefix, option_id]
                if option.has("require"):
                    var required_item: String = String(option["require"])
                    if not _is_non_empty_string(option["require"]):
                        return "%s option '%s' require must be one item id" % [prefix, option_id]
                    if not _catalog_has_item(asset_catalog, required_item):
                        return "%s option '%s' require item '%s' is not in asset catalog" % [prefix, option_id, required_item]
                else:
                    unconditional_options += 1
                if option.has("set_flags"):
                    var option_flag_error: String = _validate_flag_dictionary(option["set_flags"], "%s option '%s' set_flags" % [prefix, option_id])
                    if not option_flag_error.is_empty():
                        return option_flag_error
            if unconditional_options == 0:
                return "%s choice needs at least one unconditional option" % prefix
        "item":
            var item_id: String = String(step.get("id", ""))
            if not _catalog_has_item(asset_catalog, item_id):
                return "%s item id '%s' is not in asset catalog" % [prefix, item_id]
        "profile":
            var profile_character: Dictionary = (asset_catalog.get("characters", {}) as Dictionary).get(String(step.get("id", "")), {}) as Dictionary
            if not _is_non_empty_string(profile_character.get("profile", null)):
                return "%s profile id '%s' needs a catalog character with profile text" % [prefix, step.get("id", "")]
        "investigate":
            var investigation_id: String = String(step.get("id", ""))
            if not _is_non_empty_string(step.get("id", null)):
                return "%s investigate id must be a non-empty string" % prefix
            if not _is_non_empty_string(step.get("prompt", null)):
                return "%s investigate prompt must be a non-empty string" % prefix
            if typeof(step.get("hotspots", null)) != TYPE_ARRAY or (step["hotspots"] as Array).is_empty():
                return "%s investigate hotspots must be a non-empty array" % prefix
            var hotspot_ids: Array[String] = []
            var hotspots: Array = step["hotspots"] as Array
            for hotspot_index: int in range(hotspots.size()):
                if not hotspots[hotspot_index] is Dictionary:
                    return "%s hotspot %d must be an object" % [prefix, hotspot_index]
                var hotspot: Dictionary = hotspots[hotspot_index] as Dictionary
                if not _is_non_empty_string(hotspot.get("id", null)) or not _is_non_empty_string(hotspot.get("label", null)):
                    return "%s hotspot %d needs id and label" % [prefix, hotspot_index]
                var hotspot_id: String = String(hotspot["id"])
                if hotspot_ids.has(hotspot_id):
                    return "%s repeats hotspot id '%s'" % [prefix, hotspot_id]
                hotspot_ids.append(hotspot_id)
                if not _is_normalized_position(hotspot.get("pos", null)):
                    return "%s hotspot '%s' pos must contain normalized x/y coordinates" % [prefix, hotspot_id]
                var hotspot_item: String = String(hotspot.get("item", ""))
                if not _catalog_has_item(asset_catalog, hotspot_item):
                    return "%s hotspot '%s' item '%s' is not in asset catalog" % [prefix, hotspot_id, hotspot_item]
        "boke_round":
            if not _is_non_empty_string(step.get("id", null)):
                return "%s boke_round id must be a non-empty string" % prefix
            var speaker: String = String(step.get("speaker", ""))
            if not _catalog_has_character(asset_catalog, speaker):
                return "%s boke_round speaker '%s' is not in asset catalog" % [prefix, speaker]
            if typeof(step.get("lines", null)) != TYPE_ARRAY or (step["lines"] as Array).is_empty():
                return "%s boke_round lines must be a non-empty array" % prefix
            var lines: Array = step["lines"] as Array
            var line_ids: Array[String] = []
            for line_index: int in range(lines.size()):
                if not lines[line_index] is Dictionary:
                    return "%s boke line %d must be an object" % [prefix, line_index]
                var line: Dictionary = lines[line_index] as Dictionary
                if not _is_non_empty_string(line.get("id", null)) or not _is_non_empty_string(line.get("text", null)):
                    return "%s boke line %d needs id and text" % [prefix, line_index]
                var line_id: String = String(line["id"])
                if line_ids.has(line_id):
                    return "%s repeats boke line id '%s'" % [prefix, line_id]
                line_ids.append(line_id)
                if line.has("listen") and not _is_non_empty_string(line["listen"]):
                    return "%s boke line '%s' listen must be a non-empty string" % [prefix, line_id]
            if not _is_number_between(step.get("timer_seconds", null), 0.001, 3600.0):
                return "%s boke_round timer_seconds must be positive" % prefix
            var game_over_node: String = String(step.get("game_over", ""))
            if not _is_non_empty_string(step.get("game_over", null)) or not nodes.has(game_over_node):
                return "%s boke_round game_over target is invalid" % prefix
            if typeof(step.get("tsukkomi", null)) != TYPE_DICTIONARY:
                return "%s boke_round tsukkomi must be an object" % prefix
            var tsukkomi: Dictionary = step["tsukkomi"] as Dictionary
            if typeof(tsukkomi.get("options", null)) != TYPE_ARRAY:
                return "%s boke_round options must be an array" % prefix
            var options: Array = tsukkomi["options"] as Array
            if options.is_empty():
                return "%s boke_round needs at least one option" % prefix
            var option_ids: Array[String] = []
            var unconditional_options: int = 0
            for option_index: int in range(options.size()):
                if not options[option_index] is Dictionary:
                    return "%s boke option %d must be an object" % [prefix, option_index]
                var option: Dictionary = options[option_index] as Dictionary
                if not _is_non_empty_string(option.get("id", null)) or not _is_non_empty_string(option.get("label", null)):
                    return "%s boke option %d needs id and label" % [prefix, option_index]
                var option_id: String = String(option["id"])
                if option_ids.has(option_id):
                    return "%s repeats boke option id '%s'" % [prefix, option_id]
                option_ids.append(option_id)
                var result: String = String(option.get("result", ""))
                if not VALID_BOKE_RESULTS.has(result):
                    return "%s boke option '%s' result is invalid" % [prefix, option_id]
                if not _is_non_empty_string(option.get("goto", null)) or not nodes.has(String(option["goto"])):
                    return "%s boke option '%s' goto target is invalid" % [prefix, option_id]
                if option.has("require"):
                    var required_item: String = String(option["require"])
                    if not _is_non_empty_string(option["require"]) or not _catalog_has_item(asset_catalog, required_item):
                        return "%s boke option '%s' require item '%s' is invalid" % [prefix, option_id, required_item]
                else:
                    unconditional_options += 1
                if option.has("set_flags"):
                    var option_flag_error: String = _validate_flag_dictionary(option["set_flags"], "%s boke option '%s' set_flags" % [prefix, option_id])
                    if not option_flag_error.is_empty():
                        return option_flag_error
            if unconditional_options == 0:
                return "%s boke_round needs at least one unconditional option" % prefix
            if typeof(tsukkomi.get("timeout", null)) != TYPE_DICTIONARY:
                return "%s boke_round timeout must be an object" % prefix
            var timeout: Dictionary = tsukkomi["timeout"] as Dictionary
            if not VALID_BOKE_RESULTS.has(String(timeout.get("result", ""))):
                return "%s boke timeout result is invalid" % prefix
            if not _is_non_empty_string(timeout.get("goto", null)) or not nodes.has(String(timeout["goto"])):
                return "%s boke timeout goto target is invalid" % prefix
        "flag":
            if not _is_non_empty_string(step.get("key", null)) or not _is_flag_value(step.get("value", null)):
                return "%s flag needs a key and scalar value" % prefix
        "show":
            if not _catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s show actor is invalid" % prefix
            if step.has("at") and not VALID_STAGE_POSITIONS.has(String(step["at"])):
                return "%s show at position is invalid" % prefix
        "hide":
            if not _catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s hide actor is invalid" % prefix
        "move":
            if not _catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s move actor is invalid" % prefix
            if not VALID_STAGE_POSITIONS.has(String(step.get("target", ""))):
                return "%s move target position is invalid" % prefix
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s move duration must be non-negative" % prefix
        "face":
            if not _catalog_has_character(asset_catalog, String(step.get("actor", ""))) or not VALID_DIRECTIONS.has(String(step.get("direction", ""))):
                return "%s face actor or direction is invalid" % prefix
        "expression":
            if not _catalog_has_character(asset_catalog, String(step.get("actor", ""))) or not VALID_EXPRESSIONS.has(String(step.get("value", ""))):
                return "%s expression actor or value is invalid" % prefix
        "camera":
            var camera_target: String = String(step.get("target", ""))
            if camera_target != "center" and not _catalog_has_character(asset_catalog, camera_target):
                return "%s camera target is invalid" % prefix
            if not _is_number_between(step.get("zoom", null), 0.95, 1.15):
                return "%s camera zoom must be between 0.95 and 1.15" % prefix
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s camera duration must be non-negative" % prefix
        "wait":
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s wait duration must be non-negative" % prefix
        "sound":
            if not VALID_SOUNDS.has(String(step.get("id", ""))):
                return "%s sound id is invalid" % prefix
        "end":
            if not step.has("text") or typeof(step["text"]) != TYPE_STRING:
                return "%s end text must be a string" % prefix
        "set_flag":
            if not _is_non_empty_string(step.get("key", null)) or not _is_flag_value(step.get("value", null)):
                return "%s set_flag needs a key and scalar value" % prefix
        "condition":
            if not _is_non_empty_string(step.get("flag", null)) or not _is_flag_value(step.get("equals", null)):
                return "%s condition needs a flag and scalar equals value" % prefix
            if not _is_non_empty_string(step.get("then", null)) or not nodes.has(String(step["then"])):
                return "%s condition then target is invalid" % prefix
            if not _is_non_empty_string(step.get("else", null)) or not nodes.has(String(step["else"])):
                return "%s condition else target is invalid" % prefix
        "goto":
            if not _is_non_empty_string(step.get("target", null)) or not nodes.has(String(step["target"])):
                return "%s goto target is invalid" % prefix

    return ""


func _validate_flag_consistency(root: Dictionary) -> String:
    var types: Dictionary = {}
    var values: Dictionary = {}
    var initial_flags: Dictionary = root["initial_flags"] as Dictionary
    for key: Variant in initial_flags.keys():
        var flag_key: String = String(key)
        var initial_value: Variant = initial_flags[key]
        types[flag_key] = typeof(initial_value)
        values[flag_key] = [initial_value]

    var nodes: Dictionary = root["nodes"] as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        var steps: Array = node["steps"] as Array
        for raw_step: Variant in steps:
            var step: Dictionary = raw_step as Dictionary
            if String(step["op"]) == "set_flag" or String(step["op"]) == "flag":
                var set_flag_error: String = _record_flag_value(types, values, String(step["key"]), step["value"])
                if not set_flag_error.is_empty():
                    return set_flag_error
            if String(step["op"]) == "choice":
                for raw_option: Variant in (step["options"] as Array):
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        var option_flag_error: String = _record_flag_value(types, values, String(key), set_flags[key])
                        if not option_flag_error.is_empty():
                            return option_flag_error
            elif String(step["op"]) == "boke_round":
                var tsukkomi: Dictionary = step["tsukkomi"] as Dictionary
                for raw_option: Variant in tsukkomi["options"] as Array:
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        var option_flag_error: String = _record_flag_value(types, values, String(key), set_flags[key])
                        if not option_flag_error.is_empty():
                            return option_flag_error

    return ""


func _record_flag_value(types: Dictionary, values: Dictionary, key: String, value: Variant) -> String:
    if types.has(key) and types[key] != typeof(value):
        return "flag '%s' changes value type" % key
    if not types.has(key):
        types[key] = typeof(value)
        values[key] = []
    if not (values[key] as Array).has(value):
        (values[key] as Array).append(value)
    return ""


func _validate_snapshot(snapshot_data: Dictionary) -> String:
    for required_key: String in ["story_id", "version", "node_id", "step_index", "flags", "items"]:
        if not snapshot_data.has(required_key):
            return "missing field '%s'" % required_key
    if typeof(snapshot_data["story_id"]) != TYPE_STRING:
        return "story_id must be a string"
    if typeof(snapshot_data["version"]) != TYPE_STRING:
        return "version must be a string"
    if snapshot_data["story_id"] != _story.get("id", ""):
        return "story id does not match"
    if snapshot_data["version"] != _story.get("version", ""):
        return "story version does not match"
    if typeof(snapshot_data["node_id"]) != TYPE_STRING or not _story_node_exists(String(snapshot_data["node_id"])):
        return "node does not exist"
    if typeof(snapshot_data["step_index"]) != TYPE_INT:
        return "step_index must be an integer"

    var candidate_node_id: String = String(snapshot_data["node_id"])
    var candidate_step_index: int = int(snapshot_data["step_index"])
    var candidate_node: Dictionary = _story["nodes"][candidate_node_id] as Dictionary
    var candidate_steps: Array = candidate_node["steps"] as Array
    if candidate_step_index < 0 or candidate_step_index >= candidate_steps.size():
        return "step_index is outside the node"
    var candidate_step: Dictionary = candidate_steps[candidate_step_index] as Dictionary
    var candidate_op: String = String(candidate_step.get("op", ""))
    if candidate_op == "set_flag" or candidate_op == "flag" or candidate_op == "item" or candidate_op == "condition" or candidate_op == "goto":
        return "snapshot points to an internal command"

    var flags_error: String = _validate_saved_flags(snapshot_data["flags"])
    if not flags_error.is_empty():
        return flags_error
    var items_error: String = _validate_saved_items(snapshot_data["items"])
    if items_error.is_empty() and snapshot_data.has("profiles"):
        items_error = _validate_saved_profiles(snapshot_data["profiles"])
    if not items_error.is_empty():
        return items_error

    var phase3_fields: Array[String] = ["gameplay", "checked_hotspots", "boke", "checkpoint", "game_over_active"]
    var has_any_phase3_field: bool = false
    for key: String in phase3_fields:
        has_any_phase3_field = has_any_phase3_field or snapshot_data.has(key)
    for key: String in phase3_fields:
        if _has_phase3_ops and not snapshot_data.has(key):
            return "missing field '%s'" % key
        if not _has_phase3_ops and has_any_phase3_field and not snapshot_data.has(key):
            return "incomplete Phase 3 snapshot; missing field '%s'" % key

    if not snapshot_data.has("gameplay"):
        return ""
    var gameplay_error: String = _validate_gameplay(snapshot_data["gameplay"])
    if not gameplay_error.is_empty():
        return gameplay_error
    var hotspots_error: String = _validate_checked_hotspots(snapshot_data["checked_hotspots"])
    if not hotspots_error.is_empty():
        return hotspots_error
    var boke_error: String = _validate_boke_snapshot(snapshot_data["boke"], candidate_op, candidate_step)
    if not boke_error.is_empty():
        return boke_error
    if typeof(snapshot_data["game_over_active"]) != TYPE_BOOL:
        return "game_over_active must be a boolean"
    var checkpoint_value: Variant = snapshot_data["checkpoint"]
    if not checkpoint_value is Dictionary:
        return "checkpoint must be an object"
    var checkpoint_error: String = _validate_checkpoint(checkpoint_value as Dictionary)
    if not checkpoint_error.is_empty():
        return checkpoint_error
    if bool(snapshot_data["game_over_active"]):
        if (checkpoint_value as Dictionary).is_empty():
            return "game over snapshot is missing a checkpoint"
        if candidate_node_id != String((checkpoint_value as Dictionary).get("game_over", "")):
            return "game over snapshot is not at the checkpoint's game_over node"
    if candidate_op == "boke_round" and String((snapshot_data["boke"] as Dictionary).get("round_id", "")) != String(candidate_step.get("id", "")):
        return "boke snapshot round_id does not match the current command"
    return ""


func _validate_saved_flags(value: Variant) -> String:
    if not value is Dictionary:
        return "flags must be an object"
    var candidate_flags: Dictionary = value as Dictionary
    if candidate_flags.size() != _allowed_flag_values.size():
        return "flags do not match the story schema"
    for key: Variant in _allowed_flag_values.keys():
        if not candidate_flags.has(key):
            return "missing flag '%s'" % key
        var allowed_values: Array = _allowed_flag_values[key] as Array
        if not allowed_values.has(candidate_flags[key]):
            return "invalid value for flag '%s'" % key
    return ""


func _validate_saved_profiles(value: Variant) -> String:
    if not value is Array:
        return "profiles must be an array"
    var seen: Dictionary = {}
    for profile_value: Variant in value as Array:
        var profile_id: String = String(profile_value) if typeof(profile_value) == TYPE_STRING else ""
        if not _catalog_has_character(_asset_catalog, profile_id) or seen.has(profile_id):
            return "profiles must list distinct catalog characters"
        seen[profile_id] = true
    return ""


func _validate_saved_items(value: Variant) -> String:
    if not value is Array:
        return "items must be an array"
    var seen_items: Dictionary = {}
    var candidate_items: Array = value as Array
    for item_index: int in range(candidate_items.size()):
        var item_value: Variant = candidate_items[item_index]
        if typeof(item_value) != TYPE_STRING or String(item_value).is_empty():
            return "items[%d] must be a non-empty string" % item_index
        var item_id: String = String(item_value)
        if not _catalog_has_item(_asset_catalog, item_id):
            return "items[%d] references unknown item '%s'" % [item_index, item_id]
        if seen_items.has(item_id):
            return "items contains duplicate item '%s'" % item_id
        seen_items[item_id] = true
    return ""


func _validate_gameplay(value: Variant) -> String:
    if not value is Dictionary:
        return "gameplay must be an object"
    var state: Dictionary = value as Dictionary
    for key: String in ["glasses", "max_glasses", "power", "max_power"]:
        if not state.has(key) or typeof(state[key]) != TYPE_INT:
            return "gameplay.%s must be an integer" % key
    if int(state["max_glasses"]) != int(DEFAULT_GAMEPLAY["max_glasses"]):
        return "gameplay.max_glasses does not match the runtime"
    if int(state["max_power"]) != int(DEFAULT_GAMEPLAY["max_power"]):
        return "gameplay.max_power does not match the runtime"
    if int(state["glasses"]) < 0 or int(state["glasses"]) > int(state["max_glasses"]):
        return "gameplay.glasses is outside its range"
    if int(state["power"]) < 0 or int(state["power"]) > int(state["max_power"]):
        return "gameplay.power is outside its range"
    return ""


func _validate_checked_hotspots(value: Variant) -> String:
    if not value is Dictionary:
        return "checked_hotspots must be an object"
    var saved: Dictionary = value as Dictionary
    for raw_investigation_id: Variant in saved.keys():
        if typeof(raw_investigation_id) != TYPE_STRING:
            return "checked_hotspots keys must be strings"
        var investigation_id: String = String(raw_investigation_id)
        var investigation: Dictionary = _find_phase3_command("investigate", investigation_id)
        if investigation.is_empty():
            return "checked_hotspots references unknown investigation '%s'" % investigation_id
        if not saved[raw_investigation_id] is Array:
            return "checked_hotspots['%s'] must be an array" % investigation_id
        var seen: Dictionary = {}
        var valid_ids: Dictionary = {}
        for raw_hotspot: Variant in investigation["hotspots"] as Array:
            valid_ids[String((raw_hotspot as Dictionary)["id"])] = true
        for raw_checked_id: Variant in saved[raw_investigation_id] as Array:
            if typeof(raw_checked_id) != TYPE_STRING or not valid_ids.has(String(raw_checked_id)):
                return "checked_hotspots['%s'] contains an unknown hotspot" % investigation_id
            if seen.has(raw_checked_id):
                return "checked_hotspots['%s'] contains duplicate hotspot '%s'" % [investigation_id, raw_checked_id]
            seen[raw_checked_id] = true
    return ""


func _validate_boke_snapshot(value: Variant, current_op: String, current_step: Dictionary) -> String:
    if not value is Dictionary:
        return "boke must be an object"
    var saved: Dictionary = value as Dictionary
    for key: String in ["round_id", "line_index", "listened_line_ids"]:
        if not saved.has(key):
            return "boke snapshot is missing '%s'" % key
    if typeof(saved["round_id"]) != TYPE_STRING or typeof(saved["line_index"]) != TYPE_INT or not saved["listened_line_ids"] is Array:
        return "boke snapshot fields have invalid types"
    var round_id: String = String(saved["round_id"])
    if round_id.is_empty():
        if int(saved["line_index"]) != 0 or not (saved["listened_line_ids"] as Array).is_empty():
            return "inactive boke snapshot contains line state"
        if current_op == "boke_round":
            return "boke snapshot is inactive at a boke_round command"
        return ""
    var round: Dictionary = _find_phase3_command("boke_round", round_id)
    if round.is_empty():
        return "boke snapshot references unknown round '%s'" % round_id
    if current_op != "boke_round" or String(current_step.get("id", "")) != round_id:
        return "boke snapshot round_id does not match the current command"
    var lines: Array = round["lines"] as Array
    if int(saved["line_index"]) < 0 or int(saved["line_index"]) >= lines.size():
        return "boke line_index is outside the round"
    var valid_ids: Dictionary = {}
    for raw_line: Variant in lines:
        valid_ids[String((raw_line as Dictionary)["id"])] = true
    var seen: Dictionary = {}
    for raw_line_id: Variant in saved["listened_line_ids"] as Array:
        if typeof(raw_line_id) != TYPE_STRING or not valid_ids.has(String(raw_line_id)):
            return "boke listened_line_ids contains an unknown line"
        if seen.has(raw_line_id):
            return "boke listened_line_ids contains a duplicate line"
        seen[raw_line_id] = true
    return ""


func _validate_checkpoint(checkpoint: Dictionary) -> String:
    if checkpoint.is_empty():
        return ""
    for key: String in ["round_id", "game_over", "node_id", "step_index", "flags", "items", "gameplay", "checked_hotspots"]:
        if not checkpoint.has(key):
            return "checkpoint is missing '%s'" % key
    if typeof(checkpoint["round_id"]) != TYPE_STRING or typeof(checkpoint["game_over"]) != TYPE_STRING:
        return "checkpoint ids must be strings"
    var round_id: String = String(checkpoint["round_id"])
    var round: Dictionary = _find_phase3_command("boke_round", round_id)
    if round.is_empty() or String(round.get("game_over", "")) != String(checkpoint["game_over"]):
        return "checkpoint references an unknown or mismatched round"
    if typeof(checkpoint["node_id"]) != TYPE_STRING or not _story_node_exists(String(checkpoint["node_id"])):
        return "checkpoint node does not exist"
    if typeof(checkpoint["step_index"]) != TYPE_INT:
        return "checkpoint step_index must be an integer"
    var saved_node: Dictionary = _story["nodes"][String(checkpoint["node_id"])] as Dictionary
    var saved_steps: Array = saved_node["steps"] as Array
    var saved_index: int = int(checkpoint["step_index"])
    if saved_index < 0 or saved_index >= saved_steps.size():
        return "checkpoint step_index is outside the node"
    var saved_step: Dictionary = saved_steps[saved_index] as Dictionary
    if String(saved_step.get("op", "")) != "boke_round" or String(saved_step.get("id", "")) != round_id:
        return "checkpoint does not point at its boke round"
    var flags_error: String = _validate_saved_flags(checkpoint["flags"])
    if not flags_error.is_empty():
        return "checkpoint %s" % flags_error
    var items_error: String = _validate_saved_items(checkpoint["items"])
    if not items_error.is_empty():
        return "checkpoint %s" % items_error
    var gameplay_error: String = _validate_gameplay(checkpoint["gameplay"])
    if not gameplay_error.is_empty():
        return "checkpoint %s" % gameplay_error
    return _validate_checked_hotspots(checkpoint["checked_hotspots"])


func _find_phase3_command(op: String, command_id: String) -> Dictionary:
    var nodes: Dictionary = _story.get("nodes", {}) as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        for raw_step: Variant in node.get("steps", []) as Array:
            var step: Dictionary = raw_step as Dictionary
            if String(step.get("op", "")) == op and String(step.get("id", "")) == command_id:
                return step
    return {}


func _collect_allowed_flag_values(story: Dictionary) -> Dictionary:
    var values: Dictionary = {}
    var initial_flags: Dictionary = story["initial_flags"] as Dictionary
    for key: Variant in initial_flags.keys():
        values[String(key)] = [initial_flags[key]]

    var nodes: Dictionary = story["nodes"] as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        for raw_step: Variant in (node["steps"] as Array):
            var step: Dictionary = raw_step as Dictionary
            if String(step["op"]) == "set_flag" or String(step["op"]) == "flag":
                _add_allowed_flag_value(values, String(step["key"]), step["value"])
            elif String(step["op"]) == "choice":
                for raw_option: Variant in (step["options"] as Array):
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        _add_allowed_flag_value(values, String(key), set_flags[key])
            elif String(step["op"]) == "boke_round":
                var tsukkomi: Dictionary = step["tsukkomi"] as Dictionary
                for raw_option: Variant in tsukkomi["options"] as Array:
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        _add_allowed_flag_value(values, String(key), set_flags[key])
    return values


func _add_allowed_flag_value(values: Dictionary, key: String, value: Variant) -> void:
    if not values.has(key):
        values[key] = []
    var allowed_values: Array = values[key] as Array
    if not allowed_values.has(value):
        allowed_values.append(value)


func _copy_string_array(value: Array) -> Array[String]:
    var copied: Array[String] = []
    for entry: Variant in value:
        copied.append(String(entry))
    return copied


func _validate_flag_dictionary(value: Variant, context: String) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "%s must be an object" % context
    var dictionary: Dictionary = value as Dictionary
    for key: Variant in dictionary.keys():
        if typeof(key) != TYPE_STRING or String(key).is_empty():
            return "%s keys must be non-empty strings" % context
        if not _is_flag_value(dictionary[key]):
            return "%s contains an invalid value for '%s'" % [context, key]
    return ""


func _is_non_empty_string(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not String(value).is_empty()


func _is_flag_value(value: Variant) -> bool:
    return typeof(value) == TYPE_BOOL or typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_STRING


func _is_non_negative_number(value: Variant) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return float(value) >= 0.0


func _is_number_between(value: Variant, minimum: float, maximum: float) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return number >= minimum and number <= maximum


func _flag_value_is_allowed(key: String, value: Variant) -> bool:
    if not _allowed_flag_values.has(key):
        return false
    var allowed_values: Array = _allowed_flag_values[key] as Array
    return allowed_values.has(value)


func _reject(message: String) -> bool:
    error_message = message
    return false
