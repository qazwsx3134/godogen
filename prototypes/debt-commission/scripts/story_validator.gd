extends RefCounted

## Load-time checks of a story and its asset catalog, used by story_runner.gd's load_story.
## Everything is static: give it the data, get an error message back ("" = valid). No state is kept.
## The runner keeps the play-time state and the save/snapshot checks (they need the loaded story).

const TsukkomiRound = preload("res://scripts/tsukkomi_round.gd")
const HEX_DIGITS: String = "0123456789abcdefABCDEF"
const VALID_BOKE_RESULTS: Array[String] = ["perfect", "weak", "fail", "hidden"]
const VALID_OPS: Array[String] = [
    "bg",
    "char",
    "portrait_exit",
    "portrait_lighting",
    "portrait_effect",
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
    "result",
    "set_flag",
    "condition",
    "goto",
    "investigate",
    "boke_round",
    "profile",
    "shake",
    "flash",
    "cutin",
    "comedy",
    "freeze",
    "fade",
    "beam",
    "bgm",
    "se",
    "placard",
]
const VALID_STAGE_POSITIONS: Array[String] = ["reader", "host", "door", "landlady", "other_side"]
const VALID_CHARACTER_POSITIONS: Array[String] = ["left", "center", "right"]
const VALID_CHARACTER_TRANSITIONS: Array[String] = ["fade", "slide_left", "slide_right", "instant"]
## How a bg step changes the picture (scripts/stage_motion.gd): crossfade, or a 筆刷／墨暈／故障 wipe.
const VALID_BACKGROUND_TRANSITIONS: Array[String] = ["fade", "brush", "ink", "glitch"]
const VALID_PORTRAIT_EFFECTS: Array[String] = ["shake", "bounce"]
const GRADES: Array[String] = ["S", "A", "B", "C"]
## Expression ids for `char` and line tags; what each means and which art to make:
## docs/story-telling-game/EXPRESSIONS.md.
const VALID_EXPRESSIONS: Array[String] = ["neutral", "smile", "annoyed", "surprised", "thinking", "sweat", "smug", "shout",
    "broken", "angry", "panic", "nervous", "serious", "cry", "nosepick", "mock",
    "sit_serious", "sit_talking"]
## `comedy` presets (scripts/comedy_layer.gd): the manga overlay a line of the script asks for.
const VALID_COMEDY_PRESETS: Array[String] = ["tsukkomi_impact", "small_reaction", "full_manga_panel", "emotion_band"]
## `choice` perspectives: a reaction in a character's head (pov, the default) or the player stepping out
## as the director to decide what happens next. A pov choice says whose thought it is (`pov`, else
## default_pov()) and may tag its options with a tone; a director choice may carry a footnote (`note`).
const VALID_PERSPECTIVES: Array[String] = ["pov", "director"]
const VALID_TONES: Array[String] = ["loud", "calm", "tired"]
const VALID_DIRECTIONS: Array[String] = ["left", "right", "up", "down"]
const VALID_SOUNDS: Array[String] = ["paper", "knock", "step", "stamp"]
## An investigation's own place (its step-level hotspots, talk and bg); `places` add the others.
const HOME_PLACE: String = "home"


## A story's optional `credits` (and data/credits.json's): [{role, names: [String]}], every
## string non-empty. Returns "" when valid.
static func validate_credits(credits: Variant) -> String:
    if not credits is Array:
        return "credits must be an array of {role, names}"
    for entry: Variant in credits:
        if not entry is Dictionary or not is_non_empty_string((entry as Dictionary).get("role")):
            return "each credit needs a non-empty role"
        var names: Variant = (entry as Dictionary).get("names")
        if not names is Array or (names as Array).is_empty() \
                or not (names as Array).all(func(name: Variant) -> bool: return is_non_empty_string(name)):
            return "credit '%s' needs a non-empty list of names" % (entry as Dictionary)["role"]
    return ""


static func catalog_has_character(asset_catalog: Dictionary, character_id: String) -> bool:
    var characters: Dictionary = asset_catalog.get("characters", {}) as Dictionary
    return not character_id.is_empty() and characters.has(character_id)


## A catalog character, or several joined with "+" for a line said together ("gintoki+kagura").
static func _is_speaker(asset_catalog: Dictionary, speaker: String) -> bool:
    var parts: PackedStringArray = speaker.split("+")
    for part: String in parts:
        if not catalog_has_character(asset_catalog, part):
            return false
    return parts.size() >= 1


static func _catalog_has_background(asset_catalog: Dictionary, background_id: String) -> bool:
    var backgrounds: Dictionary = asset_catalog.get("backgrounds", {}) as Dictionary
    return not background_id.is_empty() and backgrounds.has(background_id)


static func catalog_has_item(asset_catalog: Dictionary, item_id: String) -> bool:
    var item_catalog: Dictionary = asset_catalog.get("items", {}) as Dictionary
    return not item_id.is_empty() and item_catalog.has(item_id)


static func _is_normalized_position(value: Variant) -> bool:
    if not value is Array or (value as Array).size() != 2:
        return false
    var position: Array = value as Array
    return _is_number_between(position[0], 0.0, 1.0) and _is_number_between(position[1], 0.0, 1.0)


static func story_has_phase3_ops(story: Dictionary) -> bool:
    var nodes: Dictionary = story.get("nodes", {}) as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        for raw_step: Variant in node.get("steps", []) as Array:
            var step: Dictionary = raw_step as Dictionary
            if String(step.get("op", "")) == "investigate" or String(step.get("op", "")) == "boke_round":
                return true
    return false


static func _validate_phase3_ids(nodes: Dictionary) -> String:
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


static func validate_asset_catalog(value: Variant) -> String:
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
        if not is_non_empty_string(background["label"]):
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
        if not is_non_empty_string(character["name"]):
            return "character '%s' name must be a non-empty string" % character_id
        if not _is_css_hex(character["color"]):
            return "character '%s' color must be a CSS hex color" % character_id
        if typeof(character["slot"]) != TYPE_STRING or not VALID_CHARACTER_POSITIONS.has(String(character["slot"])):
            return "character '%s' slot must be left, center, or right" % character_id
        var character_path_error: String = _validate_optional_asset_path(character, "character", character_id)
        if not character_path_error.is_empty():
            return character_path_error
        if character.has("scene"):
            var scene_error: String = _validate_optional_asset_path({"path": character["scene"]}, "character scene", character_id)
            if not scene_error.is_empty():
                return scene_error
        if character.has("voice_pitch") and (not _is_number(character["voice_pitch"]) or float(character["voice_pitch"]) <= 0.0):
            return "character '%s' voice_pitch must be a positive number (Hz)" % character_id
        if character.has("height_cm") and (not _is_number(character["height_cm"]) or float(character["height_cm"]) <= 0.0):
            return "character '%s' height_cm must be a positive number (cm)" % character_id
        if character.has("height_bounds"):
            var bounds: Variant = character["height_bounds"]
            if not bounds is Array or bounds.size() != 2:
                return "character '%s' height_bounds must contain crown and sole fractions" % character_id
            if not _is_number_between(bounds[0], 0.0, 1.0) or not _is_number_between(bounds[1], 0.0, 1.0) or float(bounds[0]) >= float(bounds[1]):
                return "character '%s' height_bounds must satisfy 0 <= crown < sole <= 1" % character_id
        if character.has("expressions"):
            if typeof(character["expressions"]) != TYPE_DICTIONARY:
                return "character '%s' expressions must map expression ids to pictures" % character_id
            for expression: Variant in (character["expressions"] as Dictionary).keys():
                if not VALID_EXPRESSIONS.has(String(expression)):
                    return "character '%s' expression '%s' is not one of %s" % [character_id, expression, VALID_EXPRESSIONS]
                var expression_error: String = _validate_optional_asset_path({"path": character["expressions"][expression]},
                    "character", "%s:%s" % [character_id, expression])
                if not expression_error.is_empty():
                    return expression_error

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
        if not is_non_empty_string(item["name"]) or not is_non_empty_string(item["description"]):
            return "item '%s' name and description must be non-empty strings" % item_id
        var item_path_error: String = _validate_optional_asset_path(item, "item", item_id)
        if not item_path_error.is_empty():
            return item_path_error

    # Optional defaults: whose thought an unmarked choice is, and the picture before a story starts.
    if catalog.has("default_pov") and (typeof(catalog["default_pov"]) != TYPE_STRING or not characters.has(catalog["default_pov"])):
        return "default_pov must be a character id"
    if catalog.has("default_background") and (typeof(catalog["default_background"]) != TYPE_STRING
            or not backgrounds.has(catalog["default_background"])):
        return "default_background must be a background id"

    # Optional audio: entries without a path play a synthesized placeholder.
    for collection: String in ["sounds", "music"]:
        if not catalog.has(collection):
            continue
        if typeof(catalog[collection]) != TYPE_DICTIONARY:
            return "collection '%s' must be an object" % collection
        var audio: Dictionary = catalog[collection] as Dictionary
        for raw_id: Variant in audio.keys():
            var audio_id: String = String(raw_id)
            if audio_id.is_empty() or typeof(audio[raw_id]) != TYPE_DICTIONARY or not is_non_empty_string((audio[raw_id] as Dictionary).get("label", null)):
                return "%s '%s' must be an object with a label" % [collection, audio_id]
            var audio_path_error: String = _validate_optional_asset_path(audio[raw_id] as Dictionary, collection, audio_id)
            if not audio_path_error.is_empty():
                return audio_path_error

    return ""


static func _validate_optional_asset_path(entry: Dictionary, kind: String, asset_id: String) -> String:
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


static func _is_css_hex(value: Variant) -> bool:
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


static func validate_story(value: Variant, asset_catalog: Dictionary) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "root must be an object"

    var root: Dictionary = value as Dictionary
    for required_key: String in ["id", "version", "title", "entry", "initial_flags", "nodes"]:
        if not root.has(required_key):
            return "missing root field '%s'" % required_key

    if not is_non_empty_string(root["id"]):
        return "id must be a non-empty string"
    if not is_non_empty_string(root["version"]):
        return "version must be a non-empty string"
    if not is_non_empty_string(root["title"]):
        return "title must be a non-empty string"
    if not is_non_empty_string(root["entry"]):
        return "entry must be a non-empty string"
    if typeof(root["initial_flags"]) != TYPE_DICTIONARY:
        return "initial_flags must be an object"
    if typeof(root["nodes"]) != TYPE_DICTIONARY:
        return "nodes must be an object"

    var initial_flags: Dictionary = root["initial_flags"] as Dictionary
    var flag_error: String = _validate_flag_dictionary(initial_flags, "initial_flags")
    if not flag_error.is_empty():
        return flag_error
    if root.has("carry") and (not root["carry"] is Array \
            or not (root["carry"] as Array).all(func(key: Variant) -> bool: return typeof(key) == TYPE_STRING and initial_flags.has(key))):
        return "carry must list flags declared in initial_flags"
    if root.has("default_pov") and (typeof(root["default_pov"]) != TYPE_STRING
            or not catalog_has_character(asset_catalog, String(root["default_pov"]))):
        return "default_pov must be a character in the asset catalog"
    if root.has("credits"):
        var credits_error: String = validate_credits(root["credits"])
        if not credits_error.is_empty():
            return credits_error

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


static func _validate_node(current_node_id: String, node: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if not node.has("title") or not is_non_empty_string(node["title"]):
        return "node '%s' title must be a non-empty string" % current_node_id
    if not node.has("steps") or typeof(node["steps"]) != TYPE_ARRAY:
        return "node '%s' steps must be an array" % current_node_id

    var steps: Array = node["steps"] as Array
    if steps.is_empty():
        return "node '%s' must contain at least one step" % current_node_id
    if node.has("next") and not is_non_empty_string(node["next"]):
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
        if index < steps.size() - 1 and final_op in ["end", "result", "choice", "goto", "condition", "boke_round"]:
            return "node '%s' step %d (%s) ends the scene; later steps cannot execute" % [current_node_id, index, final_op]

    if (final_op == "end" or final_op == "result") and node.has("next"):
        return "%s node '%s' cannot have next" % [final_op, current_node_id]
    if final_op == "choice" and node.has("next"):
        return "choice node '%s' cannot have next" % current_node_id
    if not node.has("next") and final_op != "end" and final_op != "result" and final_op != "choice" and final_op != "goto" and final_op != "condition" and final_op != "boke_round":
        return "node '%s' needs next or a terminal step" % current_node_id
    return ""


## `perspective`, `pov` and `note` of a `choice` step (its options are known to be an array here).
static func _validate_choice_marks(step: Dictionary, prefix: String, asset_catalog: Dictionary) -> String:
    var perspective: Variant = step.get("perspective", "pov")
    if typeof(perspective) != TYPE_STRING or not VALID_PERSPECTIVES.has(String(perspective)):
        return "%s choice perspective '%s' is not one of %s" % [prefix, perspective, ", ".join(VALID_PERSPECTIVES)]
    var director: bool = String(perspective) == "director"
    if step.has("pov"):
        if director:
            return "%s choice pov is only for a pov choice (this one is a director choice)" % prefix
        if typeof(step["pov"]) != TYPE_STRING or not catalog_has_character(asset_catalog, String(step["pov"])):
            return "%s choice pov '%s' is not a character in the asset catalog" % [prefix, step["pov"]]
    if step.has("note"):
        if not director:
            return "%s choice note is only for a director choice (this one is a pov choice)" % prefix
        if not is_non_empty_string(step["note"]):
            return "%s choice note must be a non-empty string" % prefix
    if director and (step["options"] as Array).size() < 2:
        return "%s director choice needs at least two options (it decides what happens next)" % prefix
    return ""


static func _validate_step(current_node_id: String, index: int, step: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    var prefix: String = "node '%s' step %d" % [current_node_id, index]
    if not step.has("op") or not is_non_empty_string(step["op"]):
        return "%s must have an op" % prefix
    var op: String = String(step["op"])
    if not VALID_OPS.has(op):
        return "%s has unsupported op '%s'" % [prefix, op]

    match op:
        "bg":
            var background_id: String = String(step.get("id", ""))
            if not _catalog_has_background(asset_catalog, background_id):
                return "%s bg id '%s' is not in asset catalog" % [prefix, background_id]
            if step.has("transition") and (typeof(step["transition"]) != TYPE_STRING or String(step["transition"]) not in VALID_BACKGROUND_TRANSITIONS):
                return "%s bg transition must be one of %s" % [prefix, ", ".join(VALID_BACKGROUND_TRANSITIONS)]
        "char":
            var character_id: String = String(step.get("id", ""))
            if not catalog_has_character(asset_catalog, character_id):
                return "%s char id '%s' is not in asset catalog" % [prefix, character_id]
            if step.has("visible") and typeof(step["visible"]) != TYPE_BOOL:
                return "%s char visible must be boolean" % prefix
            if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
                return "%s char expression is invalid" % prefix
            if step.has("position") and (typeof(step["position"]) != TYPE_STRING or not VALID_CHARACTER_POSITIONS.has(String(step["position"]))):
                return "%s char position is invalid" % prefix
            if step.has("enter") and typeof(step["enter"]) != TYPE_BOOL:
                return "%s char enter must be boolean" % prefix
            if bool(step.get("enter", false)) and not bool(step.get("visible", true)):
                return "%s char cannot enter and hide at once" % prefix
            if step.has("transition") and (typeof(step["transition"]) != TYPE_STRING or String(step["transition"]) not in VALID_CHARACTER_TRANSITIONS):
                return "%s char transition is invalid" % prefix
        "portrait_exit":
            if not catalog_has_character(asset_catalog, String(step.get("id", ""))):
                return "%s portrait_exit id is not a character in the asset catalog" % prefix
            if step.has("transition") and (typeof(step["transition"]) != TYPE_STRING or String(step["transition"]) not in VALID_CHARACTER_TRANSITIONS):
                return "%s portrait_exit transition is invalid" % prefix
        "portrait_lighting":
            if not catalog_has_character(asset_catalog, String(step.get("id", ""))):
                return "%s portrait_lighting id is not a character in the asset catalog" % prefix
            if typeof(step.get("mode", null)) != TYPE_STRING or String(step["mode"]) not in ["dim", "lit", "auto"]:
                return "%s portrait_lighting mode is invalid" % prefix
        "portrait_effect":
            if not catalog_has_character(asset_catalog, String(step.get("id", ""))):
                return "%s portrait_effect id is not a character in the asset catalog" % prefix
            if typeof(step.get("effect", null)) != TYPE_STRING or String(step["effect"]) not in VALID_PORTRAIT_EFFECTS:
                return "%s portrait_effect effect is invalid" % prefix
        "placard":
            if typeof(step.get("text", null)) != TYPE_STRING:
                return "%s placard text must be a string (\"\" clears the placard)" % prefix
        "say":
            var speaker: String = String(step.get("speaker", ""))
            if not is_non_empty_string(step.get("speaker", null)):
                return "%s say speaker is invalid" % prefix
            if speaker != "narrator" and not _is_speaker(asset_catalog, speaker):
                return "%s say speaker '%s' is not in asset catalog" % [prefix, speaker]
            if not step.has("text") or typeof(step["text"]) != TYPE_STRING:
                return "%s say text must be a string" % prefix
            if step.has("thought") and typeof(step["thought"]) != TYPE_BOOL:
                return "%s say thought must be boolean" % prefix
            if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
                return "%s say expression is invalid" % prefix
            if step.has("offscreen") and typeof(step["offscreen"]) != TYPE_BOOL:
                return "%s say offscreen must be boolean" % prefix
            if bool(step.get("offscreen", false)) and speaker == "narrator":
                return "%s say offscreen needs a character speaker (narration is never on stage)" % prefix
        "choice":
            return _validate_choice_step(step, prefix, nodes, asset_catalog)
        "item":
            var item_id: String = String(step.get("id", ""))
            if not catalog_has_item(asset_catalog, item_id):
                return "%s item id '%s' is not in asset catalog" % [prefix, item_id]
        "profile":
            var profile_character: Dictionary = (asset_catalog.get("characters", {}) as Dictionary).get(String(step.get("id", "")), {}) as Dictionary
            if not is_non_empty_string(profile_character.get("profile", null)):
                return "%s profile id '%s' needs a catalog character with profile text" % [prefix, step.get("id", "")]
        "investigate":
            return _validate_investigation(step, prefix, index, nodes, asset_catalog)
        "boke_round":
            return _validate_boke_round_step(step, prefix, nodes, asset_catalog)
        "flag":
            if not _flag_step_is_valid(step):
                return "%s flag needs a key and either a scalar value or a whole-number add" % prefix
        "show":
            if not catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s show actor is invalid" % prefix
            if step.has("at") and not VALID_STAGE_POSITIONS.has(String(step["at"])):
                return "%s show at position is invalid" % prefix
        "hide":
            if not catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s hide actor is invalid" % prefix
        "move":
            if not catalog_has_character(asset_catalog, String(step.get("actor", ""))):
                return "%s move actor is invalid" % prefix
            if not VALID_STAGE_POSITIONS.has(String(step.get("target", ""))):
                return "%s move target position is invalid" % prefix
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s move duration must be non-negative" % prefix
        "face":
            if not catalog_has_character(asset_catalog, String(step.get("actor", ""))) or not VALID_DIRECTIONS.has(String(step.get("direction", ""))):
                return "%s face actor or direction is invalid" % prefix
        "expression":
            if not catalog_has_character(asset_catalog, String(step.get("actor", ""))) or not VALID_EXPRESSIONS.has(String(step.get("value", ""))):
                return "%s expression actor or value is invalid" % prefix
        "camera":
            var camera_target: String = String(step.get("target", ""))
            if camera_target != "center" and not catalog_has_character(asset_catalog, camera_target):
                return "%s camera target is invalid" % prefix
            if not _is_number_between(step.get("zoom", null), 0.95, 1.15):
                return "%s camera zoom must be between 0.95 and 1.15" % prefix
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s camera duration must be non-negative" % prefix
        "wait":
            if not _is_non_negative_number(step.get("duration", null)):
                return "%s wait duration must be non-negative" % prefix
        "shake":
            if step.has("strength") and not ["small", "big"].has(String(step["strength"])):
                return "%s shake strength must be small or big" % prefix
            if step.has("duration") and not _is_number_between(step["duration"], 0.05, 5.0):
                return "%s shake duration must be 0.05-5 seconds" % prefix
        "flash":
            if step.has("color") and not _is_css_hex(step["color"]):
                return "%s flash color must be a CSS hex color" % prefix
            if step.has("duration") and not _is_number_between(step["duration"], 0.05, 5.0):
                return "%s flash duration must be 0.05-5 seconds" % prefix
        "cutin":
            if not is_non_empty_string(step.get("text", null)):
                return "%s cutin needs text" % prefix
            if step.has("speaker") and not _is_speaker(asset_catalog, String(step["speaker"])):
                return "%s cutin speaker '%s' is not in asset catalog" % [prefix, step["speaker"]]
        "comedy":
            return _validate_comedy_step(step, prefix, asset_catalog)
        "beam":
            if step.has("duration") and not _is_number_between(step["duration"], 0.05, 5.0):
                return "%s beam duration must be 0.05-5 seconds" % prefix
        "fade":
            if String(step.get("direction", "out")) not in ["out", "in"]:
                return "%s fade direction must be out or in" % prefix
            if step.has("duration") and not _is_number_between(step["duration"], 0.0, 10.0):
                return "%s fade duration must be 0-10 seconds" % prefix
        "freeze":
            if step.has("duration") and not _is_number_between(step["duration"], 0.05, 10.0):
                return "%s freeze duration must be 0.05-10 seconds" % prefix
        "se":
            var se_id: String = String(step.get("id", ""))
            if not VALID_SOUNDS.has(se_id) and not (asset_catalog.get("sounds", {}) as Dictionary).has(se_id):
                return "%s se id '%s' is not in the asset catalog sounds" % [prefix, se_id]
        "bgm":
            var bgm_id: String = String(step.get("id", ""))
            if not bgm_id.is_empty() and not (asset_catalog.get("music", {}) as Dictionary).has(bgm_id):
                return "%s bgm id '%s' is not in the asset catalog music (use \"\" to stop)" % [prefix, bgm_id]
        "sound":
            if not VALID_SOUNDS.has(String(step.get("id", ""))):
                return "%s sound id is invalid" % prefix
        "end":
            if not step.has("text") or typeof(step["text"]) != TYPE_STRING:
                return "%s end text must be a string" % prefix
            if not _ending_is_valid(step):
                return "%s ending must be a non-empty id (ending_title a string)" % prefix
        "result":
            return _validate_result_step(step, prefix, asset_catalog)
        "set_flag":
            if not _flag_step_is_valid(step):
                return "%s set_flag needs a key and either a scalar value or a whole-number add" % prefix
        "condition":
            if step.has("test") == step.has("flag"):
                return "%s condition needs either flag/equals or test" % prefix
            if step.has("test"):
                var test_error: String = _validate_test(step["test"], asset_catalog)
                if not test_error.is_empty():
                    return "%s condition test %s" % [prefix, test_error]
            elif not is_non_empty_string(step.get("flag", null)) or not _is_flag_value(step.get("equals", null)):
                return "%s condition needs a flag and scalar equals value" % prefix
            if not is_non_empty_string(step.get("then", null)) or not nodes.has(String(step["then"])):
                return "%s condition then target is invalid" % prefix
            if not is_non_empty_string(step.get("else", null)) or not nodes.has(String(step["else"])):
                return "%s condition else target is invalid" % prefix
        "goto":
            if not is_non_empty_string(step.get("target", null)) or not nodes.has(String(step["target"])):
                return "%s goto target is invalid" % prefix

    return ""


## A `choice` step: prompt, options (id, label, next, optional tone/require/set_flags) and its marks.
static func _validate_choice_step(step: Dictionary, prefix: String, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if not is_non_empty_string(step.get("prompt", null)):
        return "%s choice prompt must be a non-empty string" % prefix
    if typeof(step.get("options", null)) != TYPE_ARRAY:
        return "%s choice options must be an array" % prefix
    var options: Array = step["options"] as Array
    if options.is_empty():
        return "%s choice needs at least one option" % prefix
    var marks_error: String = _validate_choice_marks(step, prefix, asset_catalog)
    if not marks_error.is_empty():
        return marks_error
    var director_choice: bool = String(step.get("perspective", "pov")) == "director"
    var option_ids: Array[String] = []
    var unconditional_options: int = 0
    for option_index: int in range(options.size()):
        if typeof(options[option_index]) != TYPE_DICTIONARY:
            return "%s option %d must be an object" % [prefix, option_index]
        var option: Dictionary = options[option_index] as Dictionary
        if not is_non_empty_string(option.get("id", null)) or not is_non_empty_string(option.get("label", null)):
            return "%s option %d needs id and label" % [prefix, option_index]
        var option_id: String = String(option["id"])
        if option_ids.has(option_id):
            return "%s repeats option id '%s'" % [prefix, option_id]
        option_ids.append(option_id)
        if option.has("tone"):
            if director_choice:
                return "%s option '%s' tone is only for a pov choice (this one is a director choice)" % [prefix, option_id]
            if typeof(option["tone"]) != TYPE_STRING or not VALID_TONES.has(String(option["tone"])):
                return "%s option '%s' tone '%s' is not one of %s" % [prefix, option_id, option["tone"], ", ".join(VALID_TONES)]
        if not is_non_empty_string(option.get("next", null)) or not nodes.has(String(option["next"])):
            return "%s option '%s' has an invalid next target" % [prefix, option_id]
        if option.has("require"):
            var required_item: String = String(option["require"])
            if not is_non_empty_string(option["require"]):
                return "%s option '%s' require must be one item id" % [prefix, option_id]
            if not catalog_has_item(asset_catalog, required_item):
                return "%s option '%s' require item '%s' is not in asset catalog" % [prefix, option_id, required_item]
        else:
            unconditional_options += 1
        if option.has("set_flags"):
            var option_flag_error: String = _validate_flag_dictionary(option["set_flags"], "%s option '%s' set_flags" % [prefix, option_id])
            if not option_flag_error.is_empty():
                return option_flag_error
    if unconditional_options == 0:
        return "%s choice needs at least one unconditional option" % prefix
    return ""


## A `boke_round` step: v2 rounds are checked by tsukkomi_round.gd; older rounds by the fields here.
static func _validate_boke_round_step(step: Dictionary, prefix: String, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if step.has("expression") and not VALID_EXPRESSIONS.has(str(step["expression"])):
        return "%s boke expression is invalid" % prefix
    if step.has("retry") and (not is_non_empty_string(step["retry"]) or not nodes.has(String(step["retry"]))):
        return "%s boke retry target is invalid" % prefix
    if TsukkomiRound.is_v2(step):
        if step.get("lines") is Array:
            for line: Variant in step["lines"]:
                if line is Dictionary and line.has("expression") and not VALID_EXPRESSIONS.has(str(line["expression"])):
                    return "%s boke line expression is invalid" % prefix
        var v2_error: String = TsukkomiRound.validate(step, prefix,
            func(target: String) -> bool: return nodes.has(target),
            func(item_id: String) -> bool: return catalog_has_item(asset_catalog, item_id),
            func(speaker: String) -> bool: return _is_speaker(asset_catalog, speaker))  # "gintoki+kagura" too
        if not v2_error.is_empty():
            return v2_error
        for writes: Dictionary in TsukkomiRound.flag_writes(step):
            var writes_error: String = _validate_flag_dictionary(writes, "%s boke option set_flags" % prefix)
            if not writes_error.is_empty():
                return writes_error
        return ""
    if not is_non_empty_string(step.get("id", null)):
        return "%s boke_round id must be a non-empty string" % prefix
    var speaker: String = String(step.get("speaker", ""))
    if not catalog_has_character(asset_catalog, speaker):
        return "%s boke_round speaker '%s' is not in asset catalog" % [prefix, speaker]
    if typeof(step.get("lines", null)) != TYPE_ARRAY or (step["lines"] as Array).is_empty():
        return "%s boke_round lines must be a non-empty array" % prefix
    var lines: Array = step["lines"] as Array
    var line_ids: Array[String] = []
    for line_index: int in range(lines.size()):
        if not lines[line_index] is Dictionary:
            return "%s boke line %d must be an object" % [prefix, line_index]
        var line: Dictionary = lines[line_index] as Dictionary
        if not is_non_empty_string(line.get("id", null)) or not is_non_empty_string(line.get("text", null)):
            return "%s boke line %d needs id and text" % [prefix, line_index]
        var line_id: String = String(line["id"])
        if line_ids.has(line_id):
            return "%s repeats boke line id '%s'" % [prefix, line_id]
        line_ids.append(line_id)
        if line.has("listen") and not is_non_empty_string(line["listen"]):
            return "%s boke line '%s' listen must be a non-empty string" % [prefix, line_id]
    if not _is_number_between(step.get("timer_seconds", null), 0.001, 3600.0):
        return "%s boke_round timer_seconds must be positive" % prefix
    var game_over_node: String = String(step.get("game_over", ""))
    if not is_non_empty_string(step.get("game_over", null)) or not nodes.has(game_over_node):
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
        if not is_non_empty_string(option.get("id", null)) or not is_non_empty_string(option.get("label", null)):
            return "%s boke option %d needs id and label" % [prefix, option_index]
        var option_id: String = String(option["id"])
        if option_ids.has(option_id):
            return "%s repeats boke option id '%s'" % [prefix, option_id]
        option_ids.append(option_id)
        var result: String = String(option.get("result", ""))
        if not VALID_BOKE_RESULTS.has(result):
            return "%s boke option '%s' result is invalid" % [prefix, option_id]
        if not is_non_empty_string(option.get("goto", null)) or not nodes.has(String(option["goto"])):
            return "%s boke option '%s' goto target is invalid" % [prefix, option_id]
        if option.has("require"):
            var required_item: String = String(option["require"])
            if not is_non_empty_string(option["require"]) or not catalog_has_item(asset_catalog, required_item):
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
    if not is_non_empty_string(timeout.get("goto", null)) or not nodes.has(String(timeout["goto"])):
        return "%s boke timeout goto target is invalid" % prefix
    return ""


## A `comedy` step: preset, speaker, text and the options only some presets take (side, color).
static func _validate_comedy_step(step: Dictionary, prefix: String, asset_catalog: Dictionary) -> String:
    var comedy_preset: String = String(step.get("preset", ""))
    if not VALID_COMEDY_PRESETS.has(comedy_preset):
        return "%s comedy preset '%s' is not one of %s" % [prefix, comedy_preset, ", ".join(VALID_COMEDY_PRESETS)]
    if not catalog_has_character(asset_catalog, String(step.get("speaker", ""))):
        return "%s comedy speaker '%s' is not a character in the asset catalog" % [prefix, step.get("speaker", "")]
    if not is_non_empty_string(step.get("text", null)):
        return "%s comedy needs text" % prefix
    if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
        return "%s comedy expression is invalid" % prefix
    if step.has("side"):
        if comedy_preset != "tsukkomi_impact":
            return "%s comedy side is only for tsukkomi_impact" % prefix
        if typeof(step["side"]) != TYPE_STRING or String(step["side"]) not in ["left", "right"]:
            return "%s comedy side must be left or right" % prefix
    if step.has("color"):
        if comedy_preset != "emotion_band":
            return "%s comedy color is only for emotion_band" % prefix
        if typeof(step["color"]) != TYPE_STRING or String(step["color"]).length() != 7 or not String(step["color"]).begins_with("#") or not Color.html_is_valid(String(step["color"])):
            return "%s comedy color must be \"#rrggbb\"" % prefix
    return ""


## A `result` step: title, ending, the line for each grade and the optional hidden_total.
static func _validate_result_step(step: Dictionary, prefix: String, asset_catalog: Dictionary) -> String:
    if not is_non_empty_string(step.get("title", null)):
        return "%s result needs a title" % prefix
    if not _ending_is_valid(step):
        return "%s ending must be a non-empty id (ending_title a string)" % prefix
    if not step.get("lines", null) is Dictionary:
        return "%s result lines must map grades to {speaker, text}" % prefix
    for grade: Variant in (step["lines"] as Dictionary).keys():
        var grade_line: Variant = step["lines"][grade]
        if not GRADES.has(String(grade)) or not grade_line is Dictionary \
                or not is_non_empty_string((grade_line as Dictionary).get("text", null)) \
                or not _is_speaker(asset_catalog, String((grade_line as Dictionary).get("speaker", "narrator"))):
            return "%s result line '%s' needs a known speaker and text (grades %s)" % [prefix, grade, GRADES]
    if step.has("hidden_total") and (typeof(step["hidden_total"]) != TYPE_INT and typeof(step["hidden_total"]) != TYPE_FLOAT
            or int(step["hidden_total"]) < 0):
        return "%s result hidden_total must be a non-negative whole number" % prefix
    return ""


## An investigation: prompt, hotspots (home place), optional bg/label, talk topics and other
## places. Hotspot, topic and place ids are unique across the whole investigation.
static func _validate_investigation(step: Dictionary, prefix: String, index: int, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if not is_non_empty_string(step.get("id", null)):
        return "%s investigate id must be a non-empty string" % prefix
    if not is_non_empty_string(step.get("prompt", null)):
        return "%s investigate prompt must be a non-empty string" % prefix
    if step.has("bg") and not _catalog_has_background(asset_catalog, String(step["bg"])):
        return "%s investigate bg '%s' is not in asset catalog" % [prefix, step["bg"]]
    if step.has("label") and not is_non_empty_string(step["label"]):
        return "%s investigate label must be a non-empty string" % prefix
    if step.has("keep_cast") and typeof(step["keep_cast"]) != TYPE_BOOL:
        return "%s investigate keep_cast must be boolean" % prefix
    var keep_cast: bool = bool(step.get("keep_cast", false))
    var seen: Dictionary = {}
    var error: String = _validate_hotspots(step.get("hotspots", null), prefix, seen, nodes, asset_catalog, keep_cast)
    if error.is_empty():
        error = _validate_topics(step.get("talk", []), prefix, seen, nodes, asset_catalog)
    if not error.is_empty():
        return error
    var has_reactions: bool = step.has("talk") or step.has("places") \
        or (step["hotspots"] as Array).any(func(hotspot: Dictionary) -> bool: return hotspot.has("goto") or hotspot.has("lines"))
    if step.has("places"):
        if typeof(step["places"]) != TYPE_ARRAY or (step["places"] as Array).is_empty():
            return "%s investigate places must be a non-empty array" % prefix
        if not step.has("bg"):
            return "%s investigate with places needs its own bg (moving back home shows it)" % prefix
        for place_index: int in range((step["places"] as Array).size()):
            var place: Variant = step["places"][place_index]
            if not place is Dictionary or not is_non_empty_string((place as Dictionary).get("id", null)):
                return "%s place %d needs an id" % [prefix, place_index]
            var place_id: String = String(place["id"])
            var where: String = "%s place '%s'" % [prefix, place_id]
            if place_id == HOME_PLACE or place_id.contains("/") or seen.has("place:" + place_id):
                return "%s: place ids must be unique, without '/', and not '%s'" % [where, HOME_PLACE]
            seen["place:" + place_id] = true
            if not _catalog_has_background(asset_catalog, String(place.get("bg", ""))):
                return "%s bg '%s' is not in asset catalog" % [where, place.get("bg", "")]
            for key: String in ["label", "prompt"]:
                if place.has(key) and not is_non_empty_string(place[key]):
                    return "%s %s must be a non-empty string" % [where, key]
            error = _validate_hotspots(place.get("hotspots", null), where, seen, nodes, asset_catalog, keep_cast)
            if error.is_empty():
                error = _validate_topics(place.get("talk", []), where, seen, nodes, asset_catalog)
            if not error.is_empty():
                return error
            has_reactions = has_reactions or (place["hotspots"] as Array).any(
                func(hotspot: Dictionary) -> bool: return hotspot.has("goto") or hotspot.has("lines"))
    if has_reactions and index != 0:
        return "%s investigate '%s' has reactions (talk, places or hotspot goto/lines), so it must be the first step of its node; reactions come back with => <that node>" % [prefix, step["id"]]
    return ""


static func _validate_hotspots(value: Variant, where: String, seen: Dictionary, nodes: Dictionary, asset_catalog: Dictionary, keep_cast: bool) -> String:
    if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
        return "%s investigate hotspots must be a non-empty array" % where
    var hotspots: Array = value as Array
    for hotspot_index: int in range(hotspots.size()):
        if not hotspots[hotspot_index] is Dictionary:
            return "%s hotspot %d must be an object" % [where, hotspot_index]
        var hotspot: Dictionary = hotspots[hotspot_index] as Dictionary
        if not is_non_empty_string(hotspot.get("id", null)) or not is_non_empty_string(hotspot.get("label", null)):
            return "%s hotspot %d needs id and label" % [where, hotspot_index]
        var hotspot_id: String = String(hotspot["id"])
        if seen.has("spot:" + hotspot_id):
            return "%s repeats hotspot id '%s'" % [where, hotspot_id]
        seen["spot:" + hotspot_id] = true
        if hotspot.has("character"):
            # The area of a character's hotspot is their portrait on stage, so it has no pos or size.
            if not keep_cast:
                return "%s hotspot '%s' has a character, so the investigation needs keep_cast: true" % [where, hotspot_id]
            if typeof(hotspot["character"]) != TYPE_STRING or not catalog_has_character(asset_catalog, String(hotspot["character"])):
                return "%s hotspot '%s' character '%s' is not in asset catalog" % [where, hotspot_id, hotspot["character"]]
            if hotspot.has("pos") or hotspot.has("size"):
                return "%s hotspot '%s' has a character, so its area is the portrait: drop pos and size" % [where, hotspot_id]
            if hotspot.has("art_region"):
                var region: Variant = hotspot["art_region"]
                if not region is Array or region.size() != 4 or not region.all(func(n: Variant) -> bool: return _is_number_between(n,0.0,1.0)) \
                        or float(region[2]) <= 0.0 or float(region[3]) <= 0.0 or float(region[0])+float(region[2]) > 1.0 or float(region[1])+float(region[3]) > 1.0:
                    return "%s hotspot '%s' art_region must fit the portrait [x,y,w,h]" % [where, hotspot_id]
        elif hotspot.has("art_region"):
            return "%s hotspot '%s' art_region requires a character" % [where, hotspot_id]
        elif not _is_normalized_position(hotspot.get("pos", null)):
            return "%s hotspot '%s' pos must contain normalized x/y coordinates" % [where, hotspot_id]
        if hotspot.has("size") and (not _is_normalized_position(hotspot["size"]) \
                or float(hotspot["size"][0]) <= 0.0 or float(hotspot["size"][1]) <= 0.0):
            return "%s hotspot '%s' size must be a positive fraction of the picture [w, h]" % [where, hotspot_id]
        if not hotspot.has("item") and not hotspot.has("goto") and not hotspot.has("lines"):
            return "%s hotspot '%s' needs an item, a goto reaction, or both (or lines)" % [where, hotspot_id]
        if hotspot.has("item") and not catalog_has_item(asset_catalog, String(hotspot["item"])):
            return "%s hotspot '%s' item '%s' is not in asset catalog" % [where, hotspot_id, hotspot["item"]]
        if hotspot.has("goto") and not nodes.has(String(hotspot["goto"])):
            return "%s hotspot '%s' goto target is invalid" % [where, hotspot_id]
        if hotspot.has("lines"):
            var lines: Variant = hotspot["lines"]
            if hotspot.has("goto"):
                return "%s hotspot '%s' has both goto and lines; use one" % [where, hotspot_id]
            if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty() or not (lines as Array).all(
                    func(target: Variant) -> bool: return is_non_empty_string(target) and nodes.has(String(target))):
                return "%s hotspot '%s' lines must be a non-empty array of existing node ids" % [where, hotspot_id]
        if hotspot.has("set"):
            var set_error: String = _validate_flag_dictionary(hotspot["set"], "%s hotspot '%s' set" % [where, hotspot_id])
            if not set_error.is_empty():
                return set_error
        if hotspot.has("optional") and typeof(hotspot["optional"]) != TYPE_BOOL:
            return "%s hotspot '%s' optional must be boolean" % [where, hotspot_id]
    return ""


static func _validate_topics(value: Variant, where: String, seen: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if typeof(value) != TYPE_ARRAY:
        return "%s talk must be an array of topics" % where
    for topic_index: int in range((value as Array).size()):
        var topic: Variant = value[topic_index]
        if not topic is Dictionary or not is_non_empty_string((topic as Dictionary).get("id", null)) \
                or not is_non_empty_string((topic as Dictionary).get("label", null)):
            return "%s talk topic %d needs id and label" % [where, topic_index]
        var topic_id: String = String(topic["id"])
        if seen.has("topic:" + topic_id):
            return "%s repeats talk topic id '%s'" % [where, topic_id]
        seen["topic:" + topic_id] = true
        if not nodes.has(String(topic.get("goto", ""))):
            return "%s talk topic '%s' goto target is invalid" % [where, topic_id]
        if topic.has("require") and not catalog_has_item(asset_catalog, String(topic["require"])):
            return "%s talk topic '%s' require item '%s' is not in asset catalog" % [where, topic_id, topic["require"]]
    return ""


static func _validate_flag_consistency(root: Dictionary) -> String:
    var types: Dictionary = {}
    var values: Dictionary = {}
    var initial_flags: Dictionary = root["initial_flags"] as Dictionary
    for key: Variant in initial_flags.keys():
        var flag_key: String = String(key)
        var initial_value: Variant = initial_flags[key]
        types[flag_key] = flag_kind(initial_value)
        values[flag_key] = [initial_value]

    var nodes: Dictionary = root["nodes"] as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        var steps: Array = node["steps"] as Array
        for raw_step: Variant in steps:
            var step: Dictionary = raw_step as Dictionary
            if (String(step["op"]) == "set_flag" or String(step["op"]) == "flag") and not step.has("add"):
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
            elif TsukkomiRound.is_v2(step):
                for writes: Dictionary in TsukkomiRound.flag_writes(step):
                    for key: Variant in writes.keys():
                        var round_flag_error: String = _record_flag_value(types, values, String(key), writes[key])
                        if not round_flag_error.is_empty():
                            return round_flag_error
            elif String(step["op"]) == "investigate":
                for writes: Dictionary in _hotspot_flag_writes(step):
                    for key: Variant in writes.keys():
                        var hotspot_flag_error: String = _record_flag_value(types, values, String(key), writes[key])
                        if not hotspot_flag_error.is_empty():
                            return hotspot_flag_error
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

    # `add` and condition tests read flags, so each must be declared (a missing flag would be null).
    for raw_node_id: Variant in nodes.keys():
        var steps: Array = (nodes[raw_node_id] as Dictionary)["steps"] as Array
        for index: int in range(steps.size()):
            var step: Dictionary = steps[index] as Dictionary
            var op: String = String(step["op"])
            if (op == "flag" or op == "set_flag") and step.has("add"):
                var add_key: String = String(step["key"])
                if not initial_flags.has(add_key) or not _is_number(initial_flags[add_key]) or types[add_key] != TYPE_FLOAT:
                    return "node '%s' step %d add flag '%s' must be a number declared in initial_flags" % [raw_node_id, index, add_key]
            elif op == "condition" and step.has("test"):
                for leaf: Dictionary in _test_leaves(step["test"]):
                    if not leaf.has("flag"):
                        continue
                    var leaf_key: String = String(leaf["flag"])
                    if not initial_flags.has(leaf_key) or types[leaf_key] != flag_kind(leaf["value"]):
                        return "node '%s' step %d condition flag '%s' must be declared in initial_flags with a value of that type" % [raw_node_id, index, leaf_key]
                    if not ["==", "!="].has(String(leaf["cmp"])) and types[leaf_key] != TYPE_FLOAT:
                        return "node '%s' step %d condition flag '%s' can only be ordered (<, >) when it is a number" % [raw_node_id, index, leaf_key]

    # `when` cases may test flags: each must be a story flag with a value of the same type.
    # A hotspot's `set` may only write declared flags (a save lists exactly the declared ones).
    for raw_node_id: Variant in nodes.keys():
        var steps: Array = (nodes[raw_node_id] as Dictionary)["steps"] as Array
        for index: int in range(steps.size()):
            if String((steps[index] as Dictionary)["op"]) == "investigate":
                for writes: Dictionary in _hotspot_flag_writes(steps[index]):
                    for key: Variant in writes.keys():
                        if not initial_flags.has(String(key)):
                            return "node '%s' step %d hotspot set flag '%s' is not in initial_flags" % [raw_node_id, index, key]
            if not TsukkomiRound.is_v2(steps[index]):
                continue
            for condition: Dictionary in TsukkomiRound.flag_conditions(steps[index]):
                for key: Variant in condition.keys():
                    if not types.has(String(key)) or types[String(key)] != typeof(condition[key]):
                        return "node '%s' step %d when flags '%s' is not a story flag of that type" % [raw_node_id, index, key]
    return ""


## The `set` flags of every hotspot of an investigation step, home place and `places` alike.
static func _hotspot_flag_writes(step: Dictionary) -> Array[Dictionary]:
    var all_writes: Array[Dictionary] = []
    for hotspots: Variant in _hotspot_lists(step):
        for raw_hotspot: Variant in hotspots as Array:
            if (raw_hotspot as Dictionary).has("set"):
                all_writes.append((raw_hotspot as Dictionary)["set"] as Dictionary)
    return all_writes


static func _record_flag_value(types: Dictionary, values: Dictionary, key: String, value: Variant) -> String:
    if types.has(key) and types[key] != flag_kind(value):
        return "flag '%s' changes value type" % key
    if not types.has(key):
        types[key] = flag_kind(value)
        values[key] = []
    if not (values[key] as Array).has(value):
        (values[key] as Array).append(value)
    return ""


static func collect_allowed_flag_values(story: Dictionary) -> Dictionary:
    var values: Dictionary = {}
    var counters: Array[String] = []
    var initial_flags: Dictionary = story["initial_flags"] as Dictionary
    for key: Variant in initial_flags.keys():
        values[String(key)] = [initial_flags[key]]

    var nodes: Dictionary = story["nodes"] as Dictionary
    for raw_node: Variant in nodes.values():
        var node: Dictionary = raw_node as Dictionary
        for raw_step: Variant in (node["steps"] as Array):
            var step: Dictionary = raw_step as Dictionary
            if String(step["op"]) == "set_flag" or String(step["op"]) == "flag":
                if step.has("add"):
                    counters.append(String(step["key"]))
                else:
                    _add_allowed_flag_value(values, String(step["key"]), step["value"])
            elif String(step["op"]) == "choice":
                for raw_option: Variant in (step["options"] as Array):
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        _add_allowed_flag_value(values, String(key), set_flags[key])
            elif TsukkomiRound.is_v2(step):
                for writes: Dictionary in TsukkomiRound.flag_writes(step):
                    for key: Variant in writes.keys():
                        _add_allowed_flag_value(values, String(key), writes[key])
            elif String(step["op"]) == "investigate":
                for writes: Dictionary in _hotspot_flag_writes(step):
                    for key: Variant in writes.keys():
                        _add_allowed_flag_value(values, String(key), writes[key])
            elif String(step["op"]) == "boke_round":
                var tsukkomi: Dictionary = step["tsukkomi"] as Dictionary
                for raw_option: Variant in tsukkomi["options"] as Array:
                    var option: Dictionary = raw_option as Dictionary
                    if not option.has("set_flags"):
                        continue
                    var set_flags: Dictionary = option["set_flags"] as Dictionary
                    for key: Variant in set_flags.keys():
                        _add_allowed_flag_value(values, String(key), set_flags[key])
    # A `carry` flag can arrive from an earlier chapter with any value of its type, and a flag
    # that `add` changes can hold any number: a save only checks the type of these.
    for key: Variant in story.get("carry", []):
        values[String(key)] = {"kind": flag_kind(initial_flags[key])}
    for key: String in counters:
        values[key] = {"kind": TYPE_FLOAT}
    return values


static func _add_allowed_flag_value(values: Dictionary, key: String, value: Variant) -> void:
    if not values.has(key):
        values[key] = []
    var allowed_values: Array = values[key] as Array
    if not allowed_values.has(value):
        allowed_values.append(value)


static func _validate_flag_dictionary(value: Variant, context: String) -> String:
    if typeof(value) != TYPE_DICTIONARY:
        return "%s must be an object" % context
    var dictionary: Dictionary = value as Dictionary
    for key: Variant in dictionary.keys():
        if typeof(key) != TYPE_STRING or String(key).is_empty():
            return "%s keys must be non-empty strings" % context
        if not _is_flag_value(dictionary[key]):
            return "%s contains an invalid value for '%s'" % [context, key]
    return ""


static func is_non_empty_string(value: Variant) -> bool:
    return typeof(value) == TYPE_STRING and not String(value).is_empty()


static func _ending_is_valid(step: Dictionary) -> bool:
    if not step.has("ending"):
        return not step.has("ending_title")
    return is_non_empty_string(step["ending"]) and typeof(step.get("ending_title", "")) == TYPE_STRING


static func _is_number(value: Variant) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


## Flag type for consistency checks: JSON reads every number as float, so 1 and 1.0 match.
static func flag_kind(value: Variant) -> int:
    return TYPE_FLOAT if _is_number(value) else typeof(value)


static func _flag_step_is_valid(step: Dictionary) -> bool:
    if not is_non_empty_string(step.get("key", null)) or step.has("add") == step.has("value"):
        return false
    if step.has("add"):
        return _is_number(step["add"]) and float(step["add"]) == floorf(float(step["add"]))
    return _is_flag_value(step["value"])


## Structure of a condition `test` tree (see IMPLEMENTATION.md); "" when valid.
static func _validate_test(test: Variant, asset_catalog: Dictionary) -> String:
    if not test is Dictionary or (test as Dictionary).size() == 0:
        return "must be an object"
    var node: Dictionary = test as Dictionary
    if node.has("all") or node.has("any"):
        var parts: Variant = node.get("all", node.get("any"))
        if node.size() != 1 or not parts is Array or (parts as Array).is_empty():
            return "all/any needs a non-empty list"
        for part: Variant in parts as Array:
            var part_error: String = _validate_test(part, asset_catalog)
            if not part_error.is_empty():
                return part_error
        return ""
    if node.has("not"):
        return "not takes one test" if node.size() != 1 else _validate_test(node["not"], asset_catalog)
    if node.has("has"):
        if node.size() != 1 or not is_non_empty_string(node["has"]) or not catalog_has_item(asset_catalog, String(node["has"])):
            return "has '%s' is not a catalog item" % node.get("has", "")
        return ""
    if node.size() != 3 or not is_non_empty_string(node.get("flag", null)) or not _is_flag_value(node.get("value", null)) \
            or not ["==", "!=", "<", "<=", ">", ">="].has(String(node.get("cmp", ""))):
        return "needs flag, cmp (== != < <= > >=) and value"
    return ""


## The flag and has leaves of a validated test tree.
static func _test_leaves(test: Dictionary) -> Array[Dictionary]:
    if test.has("all") or test.has("any"):
        var leaves: Array[Dictionary] = []
        for part: Dictionary in test.get("all", test.get("any")):
            leaves.append_array(_test_leaves(part))
        return leaves
    if test.has("not"):
        return _test_leaves(test["not"])
    return [test]


static func _is_flag_value(value: Variant) -> bool:
    return typeof(value) == TYPE_BOOL or typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_STRING


static func _is_non_negative_number(value: Variant) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return float(value) >= 0.0


static func _is_number_between(value: Variant, minimum: float, maximum: float) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    var number: float = float(value)
    return number >= minimum and number <= maximum


## The hotspot lists of an investigation: the home place's, then each side place's (same order as the
## runner's _investigation_places).
static func _hotspot_lists(step: Dictionary) -> Array:
    var lists: Array = [step.get("hotspots", [])]
    for raw_place: Variant in step.get("places", []):
        lists.append((raw_place as Dictionary).get("hotspots", []))
    return lists
