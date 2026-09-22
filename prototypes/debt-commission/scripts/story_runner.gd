extends RefCounted

## Data-driven story runtime for the debt commission prototype.
## The script deliberately does not use class_name; callers preload it directly.

const MAX_INTERNAL_TRANSITIONS: int = 128

const VALID_OPS: Array[String] = [
    "say",
    "choice",
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
]

const VALID_SPEAKERS: Array[String] = ["shinpachi", "gintoki", "otose", "narrator"]
const VALID_ACTORS: Array[String] = ["shinpachi", "gintoki", "otose"]
const VALID_STAGE_POSITIONS: Array[String] = ["reader", "host", "door", "landlady", "other_side"]
const VALID_EXPRESSIONS: Array[String] = ["neutral", "smile", "annoyed", "surprised", "thinking"]
const VALID_DIRECTIONS: Array[String] = ["left", "right", "up", "down"]
const VALID_SOUNDS: Array[String] = ["paper", "knock", "step", "stamp"]

var flags: Dictionary = {}
var error_message: String = ""
var node_id: String = ""
var step_index: int = 0

var _story: Dictionary = {}
var _initial_flags: Dictionary = {}
var _allowed_flag_values: Dictionary = {}
var _loaded: bool = false


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
    var validation_error: String = _validate_story(parsed)
    if not validation_error.is_empty():
        return _reject("Invalid story: %s" % validation_error)

    var candidate: Dictionary = parsed as Dictionary
    var candidate_flags: Dictionary = candidate["initial_flags"].duplicate(true)
    var candidate_allowed_values: Dictionary = _collect_allowed_flag_values(candidate)

    # Keep the current story intact if a validated-but-looping story cannot
    # establish its initial position.
    var previous_story: Dictionary = _story
    var previous_initial_flags: Dictionary = _initial_flags
    var previous_allowed_values: Dictionary = _allowed_flag_values
    var previous_flags: Dictionary = flags
    var previous_loaded: bool = _loaded
    var previous_node_id: String = node_id
    var previous_step_index: int = step_index

    _story = candidate.duplicate(true)
    _initial_flags = candidate_flags
    _allowed_flag_values = candidate_allowed_values
    _loaded = true
    flags = {}
    node_id = ""
    step_index = 0
    error_message = ""

    if not _reset_state():
        _story = previous_story
        _initial_flags = previous_initial_flags
        _allowed_flag_values = previous_allowed_values
        flags = previous_flags
        _loaded = previous_loaded
        node_id = previous_node_id
        step_index = previous_step_index
        error_message = "Invalid story: unable to initialize entry command."
        return false

    return true


func reset() -> void:
    if not _loaded:
        flags = {}
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
    if op == "choice" or op == "end":
        error_message = "The current command requires a choice or is already at the end."
        return command

    error_message = ""
    step_index += 1
    if not _normalize_position():
        return command
    return current()


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
    flags = next_flags
    node_id = target
    step_index = 0
    error_message = ""
    if not _normalize_position():
        flags = previous_flags
        node_id = previous_node_id
        step_index = previous_step_index
        return false

    return true


func snapshot() -> Dictionary:
    if not _loaded:
        return {}

    return {
        "story_id": String(_story.get("id", "")),
        "version": _story.get("version", ""),
        "node_id": node_id,
        "step_index": step_index,
        "flags": flags.duplicate(true),
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
    node_id = String(snapshot_data["node_id"])
    step_index = int(snapshot_data["step_index"])
    error_message = ""
    return true


func _reset_state() -> bool:
    flags = _initial_flags.duplicate(true)
    node_id = String(_story.get("entry", ""))
    step_index = 0
    error_message = ""
    return _normalize_position()


func _normalize_position() -> bool:
    var original_node_id: String = node_id
    var original_step_index: int = step_index
    var original_flags: Dictionary = flags.duplicate(true)
    var transitions: int = 0

    while transitions < MAX_INTERNAL_TRANSITIONS:
        if not _story_node_exists(node_id):
            return _rollback_normalization(original_node_id, original_step_index, original_flags, "Unknown node: %s" % node_id)

        var node: Dictionary = _story["nodes"][node_id] as Dictionary
        var steps: Array = node["steps"] as Array
        if step_index >= steps.size():
            if not node.has("next"):
                return _rollback_normalization(original_node_id, original_step_index, original_flags, "Node has no next target: %s" % node_id)
            node_id = String(node["next"])
            step_index = 0
            transitions += 1
            continue

        if step_index < 0:
            return _rollback_normalization(original_node_id, original_step_index, original_flags, "Negative step index in node: %s" % node_id)

        var step: Dictionary = steps[step_index] as Dictionary
        var op: String = String(step.get("op", ""))
        match op:
            "set_flag":
                var flag_key: String = String(step["key"])
                flags[flag_key] = step["value"]
                step_index += 1
            "condition":
                var condition_key: String = String(step["flag"])
                var target: String = String(step["else"])
                if flags.get(condition_key, null) == step["equals"]:
                    target = String(step["then"])
                if not _story_node_exists(target):
                    return _rollback_normalization(original_node_id, original_step_index, original_flags, "Condition target does not exist: %s" % target)
                node_id = target
                step_index = 0
            "goto":
                var goto_target: String = String(step["target"])
                if not _story_node_exists(goto_target):
                    return _rollback_normalization(original_node_id, original_step_index, original_flags, "Goto target does not exist: %s" % goto_target)
                node_id = goto_target
                step_index = 0
            _:
                error_message = ""
                return true

        transitions += 1

    return _rollback_normalization(original_node_id, original_step_index, original_flags, "Internal story jump limit exceeded.")


func _rollback_normalization(original_node_id: String, original_step_index: int, original_flags: Dictionary, message: String) -> bool:
    node_id = original_node_id
    step_index = original_step_index
    flags = original_flags
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
    if op == "set_flag" or op == "condition" or op == "goto":
        return {}
    return command.duplicate(true)


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


func _validate_story(value: Variant) -> String:
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
        var node_error: String = _validate_node(current_node_id, node, nodes)
        if not node_error.is_empty():
            return node_error

    var consistency_error: String = _validate_flag_consistency(root)
    if not consistency_error.is_empty():
        return consistency_error
    return ""


func _validate_node(current_node_id: String, node: Dictionary, nodes: Dictionary) -> String:
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
        var step_error: String = _validate_step(current_node_id, index, step, nodes)
        if not step_error.is_empty():
            return step_error
        final_op = String(step.get("op", ""))

    if final_op == "end" and node.has("next"):
        return "end node '%s' cannot have next" % current_node_id
    if final_op == "choice" and node.has("next"):
        return "choice node '%s' cannot have next" % current_node_id
    if not node.has("next") and final_op != "end" and final_op != "choice" and final_op != "goto" and final_op != "condition":
        return "node '%s' needs next or a terminal step" % current_node_id
    return ""


func _validate_step(current_node_id: String, index: int, step: Dictionary, nodes: Dictionary) -> String:
    var prefix: String = "node '%s' step %d" % [current_node_id, index]
    if not step.has("op") or not _is_non_empty_string(step["op"]):
        return "%s must have an op" % prefix
    var op: String = String(step["op"])
    if not VALID_OPS.has(op):
        return "%s has unsupported op '%s'" % [prefix, op]

    match op:
        "say":
            if not _is_non_empty_string(step.get("speaker", null)) or not VALID_SPEAKERS.has(String(step["speaker"])):
                return "%s say speaker is invalid" % prefix
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
                if option.has("set_flags"):
                    var option_flag_error: String = _validate_flag_dictionary(option["set_flags"], "%s option '%s' set_flags" % [prefix, option_id])
                    if not option_flag_error.is_empty():
                        return option_flag_error
        "show":
            if not VALID_ACTORS.has(String(step.get("actor", ""))):
                return "%s show actor is invalid" % prefix
            if step.has("at") and not VALID_STAGE_POSITIONS.has(String(step["at"])):
                return "%s show at position is invalid" % prefix
        "hide":
            if not VALID_ACTORS.has(String(step.get("actor", ""))):
                return "%s hide actor is invalid" % prefix
        "move":
            if not VALID_ACTORS.has(String(step.get("actor", ""))):
                return "%s move actor is invalid" % prefix
            if not VALID_STAGE_POSITIONS.has(String(step.get("target", ""))):
                return "%s move target position is invalid" % prefix
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s move duration must be non-negative" % prefix
        "face":
            if not VALID_ACTORS.has(String(step.get("actor", ""))) or not VALID_DIRECTIONS.has(String(step.get("direction", ""))):
                return "%s face actor or direction is invalid" % prefix
        "expression":
            if not VALID_ACTORS.has(String(step.get("actor", ""))) or not VALID_EXPRESSIONS.has(String(step.get("value", ""))):
                return "%s expression actor or value is invalid" % prefix
        "camera":
            var camera_target: String = String(step.get("target", ""))
            if camera_target != "center" and not VALID_ACTORS.has(camera_target):
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
            if String(step["op"]) == "set_flag":
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
    for required_key: String in ["story_id", "version", "node_id", "step_index", "flags"]:
        if not snapshot_data.has(required_key):
            return "missing field '%s'" % required_key
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
    if candidate_op == "set_flag" or candidate_op == "condition" or candidate_op == "goto":
        return "snapshot points to an internal command"

    if typeof(snapshot_data["flags"]) != TYPE_DICTIONARY:
        return "flags must be an object"
    var candidate_flags: Dictionary = snapshot_data["flags"] as Dictionary
    if candidate_flags.size() != _allowed_flag_values.size():
        return "flags do not match the story schema"
    for key: Variant in _allowed_flag_values.keys():
        if not candidate_flags.has(key):
            return "missing flag '%s'" % key
        var allowed_values: Array = _allowed_flag_values[key] as Array
        if not allowed_values.has(candidate_flags[key]):
            return "invalid value for flag '%s'" % key

    return ""


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
            if String(step["op"]) == "set_flag":
                _add_allowed_flag_value(values, String(step["key"]), step["value"])
            elif String(step["op"]) == "choice":
                for raw_option: Variant in (step["options"] as Array):
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
