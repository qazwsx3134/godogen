extends RefCounted

## Data-driven story runtime for the debt commission prototype.
## The script deliberately does not use class_name; callers preload it directly.

const MAX_INTERNAL_TRANSITIONS: int = 128
const ASSET_CATALOG_PATH: String = "res://data/asset_catalog.json"
const TsukkomiRound = preload("res://scripts/tsukkomi_round.gd")
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
const GRADES: Array[String] = ["S", "A", "B", "C"]
## Expression ids for `char` and line tags; what each means and which art to make:
## docs/story-telling-game/EXPRESSIONS.md.
const VALID_EXPRESSIONS: Array[String] = ["neutral", "smile", "annoyed", "surprised", "thinking", "sweat", "smug", "shout",
    "broken", "angry", "panic", "nervous", "serious", "cry", "nosepick", "mock",
    "sit_serious", "sit_talking"]
## `comedy` presets (scripts/comedy_layer.gd): the manga overlay a line of the script asks for.
const VALID_COMEDY_PRESETS: Array[String] = ["tsukkomi_impact", "small_reaction", "full_manga_panel"]
## `choice` perspectives: a reaction in a character's head (pov, the default) or the player stepping out
## as the director to decide what happens next. A pov choice says whose thought it is (`pov`, default
## Shinpachi) and may tag its options with a tone; a director choice may carry a footnote (`note`).
const VALID_PERSPECTIVES: Array[String] = ["pov", "director"]
const DEFAULT_POV: String = "shinpachi"
const VALID_TONES: Array[String] = ["loud", "calm", "tired"]
const VALID_DIRECTIONS: Array[String] = ["left", "right", "up", "down"]
const VALID_SOUNDS: Array[String] = ["paper", "knock", "step", "stamp"]
## An investigation's own place (its step-level hotspots, talk and bg); `places` add the others.
const HOME_PLACE: String = "home"
const INTERNAL_OPS: Array[String] = ["set_flag", "flag", "item", "condition", "goto", "placard"]

var flags: Dictionary = {}
var items: Array[String] = []
## Character profiles unlocked by `profile` steps, in unlock order (the case file).
var profiles: Array[String] = []
var gameplay: Dictionary = DEFAULT_GAMEPLAY.duplicate(true)
## Checked hotspot ids per investigation id; another place of it keys as "<id>/<place>".
var checked_hotspots: Dictionary = {}
## Per investigation id: {"place": where the player is, "talked": topic ids already played}.
var investigations: Dictionary = {}
## Story-level text on the placard (`placard` steps); a round line with a placard slot shows its own.
var placard: String = ""
## Character ids on stage right now. The stage lives in the shell, which sets this before it asks about
## an investigation; only `character` hotspots read it. Not part of a save.
var cast: Array = []
## Live state of the v2 round in play (see tsukkomi_round.gd); kept while its reaction nodes play.
var round_state: Dictionary = {}
## Totals for the chapter result: caught, perfect, fails, hidden, max_combo.
var stats: Dictionary = {}
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
var _placard_before_normalize: String = ""
var _round_before_normalize: Dictionary = {}


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
    var previous_investigations: Dictionary = investigations.duplicate(true)
    var previous_placard: String = placard
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
    round_state = {}
    stats = {}
    gameplay = DEFAULT_GAMEPLAY.duplicate(true)
    checked_hotspots = {}
    investigations = {}
    placard = ""
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
        investigations = previous_investigations
        placard = previous_placard
        _has_phase3_ops = previous_has_phase3_ops
        _boke_round_id = previous_boke_round_id
        _boke_line_index = previous_boke_line_index
        _listened_line_ids = previous_listened_line_ids
        _checkpoint = previous_checkpoint
        _game_over_active = previous_game_over_active
        error_message = "Invalid story: unable to initialize entry command."
        return false

    return true


## True when the story uses investigation or tsukkomi rounds, so the shell shows the
## glasses/power HUD, the materials button and Game Over retry.
func has_gameplay() -> bool:
    return _loaded and _has_phase3_ops


## The story's own `title` and `note`, for the title screen.
func story_info() -> Dictionary:
    return {"title": String(_story.get("title", "")), "note": String(_story.get("note", ""))}


func get_asset_catalog() -> Dictionary:
    return _asset_catalog.duplicate(true)


## Collected materials and unlocked character profiles with their catalog text, in the
## order the player got them. Intended for a materials/profiles screen.
## The chapter's closing numbers for the current `result` step: tsukkomi caught out of tries,
## perfects, best combo, cold takes, hidden routes found (of the chapter's hidden_total), glasses
## left, Game Overs, and the grade with its closing line. Stats survive checkpoint retries.
func chapter_result() -> Dictionary:
    var command: Dictionary = current()
    if String(command.get("op", "")) != "result":
        return {}
    var grade: String = grade_for(int(gameplay.get("glasses", 0)), int(stats.get("game_overs", 0)))
    var line: Dictionary = ((command.get("lines", {}) as Dictionary).get(grade, {}) as Dictionary).duplicate()
    return {
        "title": String(command.get("title", "")),
        "grade": grade,
        "line": line,
        "caught": int(stats.get("caught", 0)),
        "tries": int(stats.get("caught", 0)) + int(stats.get("fails", 0)),
        "perfect": int(stats.get("perfect", 0)),
        "max_combo": int(stats.get("max_combo", 0)),
        "fails": int(stats.get("fails", 0)),
        "hidden": int(stats.get("hidden", 0)),
        "hidden_total": int(command.get("hidden_total", 0)),
        "glasses": int(gameplay.get("glasses", 0)),
        "max_glasses": int(gameplay.get("max_glasses", 5)),
        "game_overs": int(stats.get("game_overs", 0)),
    }


## The chapter grade from the glasses left (5 S, 4 A, 3–2 B, 1 C); each Game Over drops it one
## grade, never below C, so retrying cannot farm an S.
static func grade_for(glasses: int, game_overs: int) -> String:
    var index: int = 0 if glasses >= 5 else 1 if glasses == 4 else 2 if glasses >= 2 else 3
    return GRADES[mini(index + maxi(game_overs, 0), GRADES.size() - 1)]


func _count(key: String) -> void:
    stats[key] = int(stats.get(key, 0)) + 1


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
        round_state = {}
        stats = {}
        gameplay = DEFAULT_GAMEPLAY.duplicate(true)
        checked_hotspots = {}
        investigations = {}
        placard = ""
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
    elif TsukkomiRound.is_v2(command):
        command = TsukkomiRound.decorate(command, round_state, items, gameplay)
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
    if op == "choice" or op == "end" or op == "boke_round" or op == "result":
        error_message = "The current command requires a choice or is already at the end."
        return command
    if op == "investigate" and not _investigation_is_complete(command):
        error_message = "Inspect every hotspot before continuing."
        return command
    if op == "investigate":
        _set_place(String(command.get("id", "")), HOME_PLACE)  # the search is over; back where it began

    error_message = ""
    step_index += 1
    if not _normalize_position():
        return command
    return current()


## Inspects a hotspot of the current place: marks it checked (per place), grants its item once and,
## the first time, writes its `set` flags and plays its `goto` reaction (which leads back to the
## investigation's node). A hotspot with `lines` plays on every tap instead: tap n plays lines[n]
## (the last one from then on), and the taps are counted in investigations[id].counts. A side place
## whose hotspots are all checked sends the player back to the home place.
func inspect_hotspot(hotspot_id: String) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "investigate":
        return _reject("The current command is not an investigation.")
    var investigation_id: String = String(command.get("id", ""))
    var place: Dictionary = _current_place(command)
    var selected_hotspot: Dictionary = {}
    for raw_hotspot: Variant in place["hotspots"] as Array:
        if raw_hotspot is Dictionary and String((raw_hotspot as Dictionary).get("id", "")) == hotspot_id:
            selected_hotspot = raw_hotspot as Dictionary
            break
    if selected_hotspot.is_empty():
        return _reject("Unknown hotspot '%s' in investigation '%s' (place '%s')." % [hotspot_id, investigation_id, place["id"]])
    if _is_off_stage(selected_hotspot):
        return _reject("Hotspot '%s' belongs to %s, who is not on stage." % [hotspot_id, selected_hotspot["character"]])
    var key: String = _checked_key(investigation_id, String(place["id"]))
    var checked: Array[String] = _checked_hotspots_for(key)
    var lines: Array = selected_hotspot.get("lines", []) as Array
    var first_time: bool = not checked.has(hotspot_id)
    if not first_time and lines.is_empty():
        error_message = ""
        return true  # already searched: nothing new, no replay
    var before: Dictionary = snapshot()
    var reaction: String = String(selected_hotspot.get("goto", ""))
    if not lines.is_empty():
        var state: Dictionary = _investigation_state(investigation_id)
        var counts: Dictionary = state.get("counts", {}) as Dictionary  # only written once a tap happens: old saves have none
        counts[hotspot_id] = int(counts.get(hotspot_id, 0)) + 1
        state["counts"] = counts
        investigations[investigation_id] = state
        reaction = String(lines[mini(int(counts[hotspot_id]), lines.size()) - 1])
    if first_time:
        checked.append(hotspot_id)
        checked_hotspots[key] = checked
        var item_id: String = String(selected_hotspot.get("item", ""))
        if not item_id.is_empty() and not items.has(item_id):
            items.append(item_id)
        var writes: Dictionary = selected_hotspot.get("set", {}) as Dictionary
        for flag_key: Variant in writes.keys():
            flags[String(flag_key)] = writes[flag_key]
        if String(place["id"]) != HOME_PLACE and _all_checked(place["hotspots"] as Array, checked):
            _set_place(investigation_id, HOME_PLACE)
    error_message = ""
    if reaction.is_empty():
        return true
    return _jump_from_investigation(before, reaction)


## Plays a talk topic of the current place once; its node leads back to the investigation.
func talk_topic(topic_id: String) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "investigate":
        return _reject("The current command is not an investigation.")
    var investigation_id: String = String(command.get("id", ""))
    for topic: Dictionary in _visible_topics(command):
        if String(topic["id"]) == topic_id:
            var before: Dictionary = snapshot()
            var state: Dictionary = _investigation_state(investigation_id)
            (state["talked"] as Array).append(topic_id)
            investigations[investigation_id] = state
            return _jump_from_investigation(before, String(topic["goto"]))
    return _reject("Topic '%s' is not open in investigation '%s'." % [topic_id, investigation_id])


## Moves the search to another place of the current investigation (its own background, hotspots
## and topics). The checked spots of every place are kept.
func move_to(place_id: String) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "investigate":
        return _reject("The current command is not an investigation.")
    var investigation_id: String = String(command.get("id", ""))
    var here: String = String(_current_place(command)["id"])
    for place: Dictionary in _investigation_places(command):
        if String(place["id"]) == place_id and place_id != here:
            _set_place(investigation_id, place_id)
            error_message = ""
            return true
    return _reject("Cannot move to '%s' in investigation '%s'." % [place_id, investigation_id])


func _jump_from_investigation(before: Dictionary, target: String) -> bool:
    node_id = target
    step_index = 0
    if not _normalize_position():
        var message: String = error_message
        restore(before)
        return _reject(message)
    error_message = ""
    return true


func set_boke_line(index: int) -> bool:
    if not _loaded:
        return _reject("No story is loaded.")
    var command: Dictionary = _current_command()
    if String(command.get("op", "")) != "boke_round":
        return _reject("The current command is not a boke round.")
    if TsukkomiRound.is_v2(command):
        _prepare_interactive_command(command)
        var moved: Dictionary = TsukkomiRound.set_line(command, round_state, index)
        if moved.has("error"):
            return _reject(String(moved["error"]))
        round_state = moved["state"]
        error_message = ""
        return true
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
    if TsukkomiRound.is_v2(command):
        var heard: Dictionary = TsukkomiRound.listen(command, round_state)
        if heard.has("error"):
            return _reject(String(heard["error"]))
        return _jump_within_round(heard["state"], String(heard["goto"]))
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
    if TsukkomiRound.is_v2(command):
        return _round_action("option", {"id": option_id})
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
    if TsukkomiRound.is_v2(command):
        return _round_action("timeout")
    var tsukkomi: Dictionary = command.get("tsukkomi", {}) as Dictionary
    var timeout: Dictionary = tsukkomi.get("timeout", {}) as Dictionary
    return _resolve_boke_result(command, timeout)


## Pressing 吐槽！ on a line with no tsukkomi slot (v2 rounds).
func whiff_boke() -> Dictionary:
    return _round_action("whiff")


## Tapping the fourth-wall censor bar of the current line (v2 rounds).
func resolve_censor() -> Dictionary:
    return _round_action("censor")


## Tapping the placard of the current line (v2 rounds; see placard_view()).
func resolve_placard() -> Dictionary:
    return _round_action("placard")


## What the placard shows now: {"text", "tappable", "slot"}. While a live round sits on an
## uncaught line with a placard slot, its text (tappable only on the round itself, not during its
## reaction scenes); otherwise the story-level text of the last `placard` step ("" = blank).
func placard_view() -> Dictionary:
    var view: Dictionary = {"text": placard, "tappable": false, "slot": false}
    if not _loaded or _game_over_active or round_state.is_empty():
        return view
    var step: Dictionary = _find_phase3_command("boke_round", String(round_state.get("id", "")))
    if not TsukkomiRound.is_v2(step):
        return view
    var line: Dictionary = (step["lines"] as Array)[TsukkomiRound.line_index(step, round_state)]
    var slot_placard: Dictionary = (line.get("slot", {}) as Dictionary).get("placard", {}) as Dictionary
    if slot_placard.is_empty() or (round_state["caught"] as Dictionary).has(String(line["id"])):
        return view
    var here: Dictionary = _current_command()
    return {"text": String(slot_placard["text"]), "slot": true,
        "tappable": TsukkomiRound.is_v2(here) and String(here.get("id", "")) == String(step["id"])}


## The QTE ring: tapped=false when the ring ran out; offset = seconds from the ring's target
## (negative = early).
func resolve_qte(tapped: bool, offset: float = 0.0) -> Dictionary:
    return _round_action("qte", {"tapped": tapped, "offset": offset})


## The ultimate tsukkomi, when round_state and power allow it (v2 rounds).
func use_super() -> Dictionary:
    return _round_action("super")


func _round_action(kind: String, payload: Dictionary = {}) -> Dictionary:
    if not _loaded:
        _reject("No story is loaded.")
        return {}
    var command: Dictionary = _current_command()
    if not TsukkomiRound.is_v2(command):
        _reject("The current command is not a v2 boke round.")
        return {}
    if _game_over_active:
        _reject("The current boke round is already resolved.")
        return {}
    _prepare_interactive_command(command)
    var decision: Dictionary = TsukkomiRound.resolve(command, round_state, gameplay, items, kind, payload, flags)
    if decision.has("error"):
        _reject(String(decision["error"]))
        return {}
    var next_flags: Dictionary = flags.duplicate(true)
    var set_flags: Dictionary = decision["set_flags"]
    for key: Variant in set_flags.keys():
        if not _flag_value_is_allowed(String(key), set_flags[key]):
            _reject("Boke result writes an invalid flag value: %s" % key)
            return {}
        next_flags[String(key)] = set_flags[key]
    var before: Dictionary = snapshot()
    flags = next_flags
    gameplay = decision["gameplay"]
    for key: String in (decision["stats"] as Dictionary).keys():
        if key == "combo":
            stats["max_combo"] = maxi(int(stats.get("max_combo", 0)), int(decision["stats"][key]))
        else:
            stats[key] = int(stats.get(key, 0)) + int(decision["stats"][key])
    round_state = {} if bool(decision["leaves_round"]) else decision["state"]
    _game_over_active = bool(decision["game_over"])
    if _game_over_active:
        _count("game_overs")
    node_id = String(decision["goto"])
    step_index = 0
    error_message = ""
    if not _normalize_position():
        var message: String = error_message
        restore(before)
        error_message = message
        return {}
    return {"result": decision["result"], "goto": decision["goto"], "game_over": decision["game_over"]}


## Plays a node from inside a v2 round (listen); it leads back to the round.
func _jump_within_round(next_state: Dictionary, target: String) -> bool:
    var before: Dictionary = snapshot()
    round_state = next_state
    node_id = target
    step_index = 0
    error_message = ""
    if not _normalize_position():
        var message: String = error_message
        restore(before)
        return _reject(message)
    return true


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
    investigations = (checkpoint.get("investigations", investigations) as Dictionary).duplicate(true)
    placard = String(checkpoint.get("placard", ""))
    node_id = String(checkpoint["node_id"])
    step_index = int(checkpoint["step_index"])
    _boke_round_id = String(checkpoint["round_id"])
    _boke_line_index = 0
    _listened_line_ids = []
    var retried_round: Dictionary = _find_phase3_command("boke_round", String(checkpoint["round_id"]))
    if TsukkomiRound.is_v2(retried_round):
        _boke_round_id = ""
        round_state = TsukkomiRound.retry_state(retried_round, round_state)
    _game_over_active = false
    error_message = ""
    if not _normalize_position():
        _game_over_active = true
        return false
    var retry_target: String = String(retried_round.get("retry", ""))
    if not retry_target.is_empty():
        node_id = retry_target
        step_index = 0
        if not _normalize_position():
            return false
    return true


func _prepare_interactive_command(command: Dictionary) -> void:
    var op: String = String(command.get("op", ""))
    if op == "investigate":
        var investigation_id: String = String(command.get("id", ""))
        if not checked_hotspots.has(investigation_id):
            checked_hotspots[investigation_id] = []
    elif TsukkomiRound.is_v2(command):
        var v2_round_id: String = String(command.get("id", ""))
        if String(round_state.get("id", "")) != v2_round_id:
            round_state = TsukkomiRound.new_state(v2_round_id)
        if _checkpoint.get("round_id", "") != v2_round_id:
            _capture_round_checkpoint(command)
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
        "investigations": investigations.duplicate(true),
        "placard": placard,
    }


## The investigation as the shell draws it: the current place's hotspots (with `checked`),
## `place`, `place_label`, `bg` (the place's background, "" = keep the current one), `home_bg`,
## `prompt`, the open `talk` topics, `moves` to the other places, `complete` (every required
## hotspot of every place checked) and `progress` [found, required].
func _decorate_investigation(command: Dictionary) -> Dictionary:
    var decorated: Dictionary = command.duplicate(true)
    var investigation_id: String = String(decorated.get("id", ""))
    var place: Dictionary = _current_place(command)
    var checked: Array[String] = _checked_hotspots_for(_checked_key(investigation_id, String(place["id"])))
    var hotspots: Array = (place["hotspots"] as Array).duplicate(true)
    for index: int in range(hotspots.size()):
        var hotspot: Dictionary = hotspots[index] as Dictionary
        hotspot["checked"] = checked.has(String(hotspot.get("id", "")))
        if hotspot.has("character"):
            hotspot["present"] = not _is_off_stage(hotspot)
        hotspots[index] = hotspot
    decorated["hotspots"] = hotspots
    decorated["place"] = place["id"]
    decorated["place_label"] = place["label"]
    decorated["bg"] = place["bg"]
    decorated["home_bg"] = String(command.get("bg", ""))
    decorated["prompt"] = place["prompt"]
    decorated["talk"] = _visible_topics(command).map(func(topic: Dictionary) -> Dictionary:
        return {"id": topic["id"], "label": topic["label"]})
    var moves: Array = []
    for other: Dictionary in _investigation_places(command):
        if other["id"] != place["id"]:
            moves.append({"id": other["id"], "label": other["label"]})
    decorated["moves"] = moves
    decorated["complete"] = _investigation_is_complete(command)
    decorated["progress"] = _investigation_progress(command)
    decorated.erase("places")
    return decorated


## Every place of an investigation step, home first: {id, bg, label, prompt, hotspots, talk}.
func _investigation_places(command: Dictionary) -> Array[Dictionary]:
    var home_bg: String = String(command.get("bg", ""))
    var places: Array[Dictionary] = [{"id": HOME_PLACE, "bg": home_bg,
        "label": String(command.get("label", _background_label(home_bg))), "prompt": String(command.get("prompt", "")),
        "hotspots": command.get("hotspots", []), "talk": command.get("talk", [])}]
    for raw_place: Variant in command.get("places", []):
        var place: Dictionary = raw_place as Dictionary
        var bg: String = String(place.get("bg", ""))
        places.append({"id": String(place.get("id", "")), "bg": bg, "label": String(place.get("label", _background_label(bg))),
            "prompt": String(place.get("prompt", command.get("prompt", ""))), "hotspots": place.get("hotspots", []),
            "talk": place.get("talk", [])})
    return places


func _current_place(command: Dictionary) -> Dictionary:
    var where: String = String(_investigation_state(String(command.get("id", "")))["place"])
    var places: Array[Dictionary] = _investigation_places(command)
    for place: Dictionary in places:
        if place["id"] == where:
            return place
    return places[0]


func _investigation_state(investigation_id: String) -> Dictionary:
    var state: Dictionary = (investigations.get(investigation_id, {}) as Dictionary).duplicate(true)
    if not state.has("place"):
        state["place"] = HOME_PLACE
    if not state.has("talked"):
        state["talked"] = []
    return state


func _set_place(investigation_id: String, place_id: String) -> void:
    var state: Dictionary = _investigation_state(investigation_id)
    state["place"] = place_id
    investigations[investigation_id] = state


## Topics of the current place not played yet whose `require` item is held.
func _visible_topics(command: Dictionary) -> Array[Dictionary]:
    var talked: Array = _investigation_state(String(command.get("id", "")))["talked"]
    var topics: Array[Dictionary] = []
    for raw_topic: Variant in _current_place(command)["talk"] as Array:
        var topic: Dictionary = raw_topic as Dictionary
        if talked.has(String(topic.get("id", ""))):
            continue
        if topic.has("require") and not items.has(String(topic["require"])):
            continue
        topics.append(topic)
    return topics


static func _checked_key(investigation_id: String, place_id: String) -> String:
    return investigation_id if place_id == HOME_PLACE else "%s/%s" % [investigation_id, place_id]


func _background_label(background_id: String) -> String:
    var backgrounds: Dictionary = _asset_catalog.get("backgrounds", {}) as Dictionary
    return String((backgrounds.get(background_id, {}) as Dictionary).get("label", background_id))


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


## Every hotspot without `optional: true`, in every place, has been checked.
func _investigation_is_complete(command: Dictionary) -> bool:
    var progress: Array = _investigation_progress(command)
    return int(progress[0]) == int(progress[1]) and not (command.get("hotspots", []) as Array).is_empty()


## [required hotspots checked, required hotspots] over every place of the investigation.
## A character who is off stage takes their hotspot out of the count.
func _investigation_progress(command: Dictionary) -> Array:
    var investigation_id: String = String(command.get("id", ""))
    var found: int = 0
    var required: int = 0
    for place: Dictionary in _investigation_places(command):
        var checked: Array[String] = _checked_hotspots_for(_checked_key(investigation_id, String(place["id"])))
        for raw_hotspot: Variant in place["hotspots"] as Array:
            var hotspot: Dictionary = raw_hotspot as Dictionary
            if bool(hotspot.get("optional", false)) or _is_off_stage(hotspot):
                continue
            required += 1
            if checked.has(String(hotspot.get("id", ""))):
                found += 1
    return [found, required]


func _all_checked(hotspots: Array, checked: Array[String]) -> bool:
    return hotspots.all(func(raw: Variant) -> bool:
        return checked.has(String((raw as Dictionary).get("id", ""))) or _is_off_stage(raw as Dictionary))


## A hotspot of a character (`keep_cast` investigations) who is not in `cast`.
func _is_off_stage(hotspot: Dictionary) -> bool:
    return hotspot.has("character") and not cast.has(String(hotspot["character"]))


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
    match result:
        "perfect", "weak":
            _count("caught")
            if result == "perfect":
                _count("perfect")
        "fail":
            _count("fails")
        "hidden":
            _count("hidden")
    if game_over:
        _count("game_overs")
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
        "investigations": investigations.duplicate(true),
        "placard": placard,
        "boke": {
            "round_id": _boke_round_id,
            "line_index": _boke_line_index,
            "listened_line_ids": _listened_line_ids.duplicate(),
        },
        "checkpoint": _checkpoint.duplicate(true),
        "game_over_active": _game_over_active,
        "round": round_state.duplicate(true),
        "stats": stats.duplicate(),
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
    investigations = (snapshot_data.get("investigations", {}) as Dictionary).duplicate(true)
    placard = String(snapshot_data.get("placard", ""))
    var boke_state: Dictionary = snapshot_data.get("boke", {}) as Dictionary
    _boke_round_id = String(boke_state.get("round_id", ""))
    _boke_line_index = int(boke_state.get("line_index", 0))
    _listened_line_ids = _copy_string_array(boke_state.get("listened_line_ids", []) as Array)
    _checkpoint = snapshot_data.get("checkpoint", {}).duplicate(true)
    _game_over_active = bool(snapshot_data.get("game_over_active", false))
    round_state = (snapshot_data.get("round", {}) as Dictionary).duplicate(true)
    stats = (snapshot_data.get("stats", {}) as Dictionary).duplicate()
    error_message = ""
    return true


func _reset_state() -> bool:
    flags = _initial_flags.duplicate(true)
    items = []
    profiles = []
    round_state = {}
    stats = {}
    gameplay = DEFAULT_GAMEPLAY.duplicate(true)
    checked_hotspots = {}
    investigations = {}
    placard = ""
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
    _placard_before_normalize = placard
    _round_before_normalize = round_state.duplicate(true)
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
        # Coming back into a live v2 round: queued reactions (hint, combo break) play first,
        # and once every slot is caught the round hands over to its exit.
        if TsukkomiRound.is_v2(step) and String(round_state.get("id", "")) == String(step.get("id", "")) and not _game_over_active:
            if not (round_state["queue"] as Array).is_empty():
                node_id = String((round_state["queue"] as Array).pop_front())
                step_index = 0
                transitions += 1
                continue
            if TsukkomiRound.all_caught(step, round_state):
                node_id = TsukkomiRound.exit_target(step, round_state)
                step_index = 0
                round_state = {}
                transitions += 1
                continue
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
            "placard":
                placard = String(step["text"])
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
    placard = _placard_before_normalize
    round_state = _round_before_normalize.duplicate(true)
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
    if INTERNAL_OPS.has(op):
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


## A catalog character, or several joined with "+" for a line said together ("gintoki+kagura").
func _is_speaker(asset_catalog: Dictionary, speaker: String) -> bool:
    var parts: PackedStringArray = speaker.split("+")
    for part: String in parts:
        if not _catalog_has_character(asset_catalog, part):
            return false
    return parts.size() >= 1


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
        if not _is_non_empty_string(item["name"]) or not _is_non_empty_string(item["description"]):
            return "item '%s' name and description must be non-empty strings" % item_id
        var item_path_error: String = _validate_optional_asset_path(item, "item", item_id)
        if not item_path_error.is_empty():
            return item_path_error

    # Optional audio: entries without a path play a synthesized placeholder.
    for collection: String in ["sounds", "music"]:
        if not catalog.has(collection):
            continue
        if typeof(catalog[collection]) != TYPE_DICTIONARY:
            return "collection '%s' must be an object" % collection
        var audio: Dictionary = catalog[collection] as Dictionary
        for raw_id: Variant in audio.keys():
            var audio_id: String = String(raw_id)
            if audio_id.is_empty() or typeof(audio[raw_id]) != TYPE_DICTIONARY or not _is_non_empty_string((audio[raw_id] as Dictionary).get("label", null)):
                return "%s '%s' must be an object with a label" % [collection, audio_id]
            var audio_path_error: String = _validate_optional_asset_path(audio[raw_id] as Dictionary, collection, audio_id)
            if not audio_path_error.is_empty():
                return audio_path_error

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

    if (final_op == "end" or final_op == "result") and node.has("next"):
        return "%s node '%s' cannot have next" % [final_op, current_node_id]
    if final_op == "choice" and node.has("next"):
        return "choice node '%s' cannot have next" % current_node_id
    if not node.has("next") and final_op != "end" and final_op != "result" and final_op != "choice" and final_op != "goto" and final_op != "condition" and final_op != "boke_round":
        return "node '%s' needs next or a terminal step" % current_node_id
    return ""


## `perspective`, `pov` and `note` of a `choice` step (its options are known to be an array here).
func _validate_choice_marks(step: Dictionary, prefix: String, asset_catalog: Dictionary) -> String:
    var perspective: Variant = step.get("perspective", "pov")
    if typeof(perspective) != TYPE_STRING or not VALID_PERSPECTIVES.has(String(perspective)):
        return "%s choice perspective '%s' is not one of %s" % [prefix, perspective, ", ".join(VALID_PERSPECTIVES)]
    var director: bool = String(perspective) == "director"
    if step.has("pov"):
        if director:
            return "%s choice pov is only for a pov choice (this one is a director choice)" % prefix
        if typeof(step["pov"]) != TYPE_STRING or not _catalog_has_character(asset_catalog, String(step["pov"])):
            return "%s choice pov '%s' is not a character in the asset catalog" % [prefix, step["pov"]]
    if step.has("note"):
        if not director:
            return "%s choice note is only for a director choice (this one is a pov choice)" % prefix
        if not _is_non_empty_string(step["note"]):
            return "%s choice note must be a non-empty string" % prefix
    if director and (step["options"] as Array).size() < 2:
        return "%s director choice needs at least two options (it decides what happens next)" % prefix
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
            if step.has("enter") and typeof(step["enter"]) != TYPE_BOOL:
                return "%s char enter must be boolean" % prefix
            if bool(step.get("enter", false)) and not bool(step.get("visible", true)):
                return "%s char cannot enter and hide at once" % prefix
        "placard":
            if typeof(step.get("text", null)) != TYPE_STRING:
                return "%s placard text must be a string (\"\" clears the placard)" % prefix
        "say":
            var speaker: String = String(step.get("speaker", ""))
            if not _is_non_empty_string(step.get("speaker", null)):
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
            if not _is_non_empty_string(step.get("prompt", null)):
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
                if not _is_non_empty_string(option.get("id", null)) or not _is_non_empty_string(option.get("label", null)):
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
            return _validate_investigation(step, prefix, index, nodes, asset_catalog)
        "boke_round":
            if step.has("retry") and (not _is_non_empty_string(step["retry"]) or not nodes.has(String(step["retry"]))):
                return "%s boke retry target is invalid" % prefix
            if TsukkomiRound.is_v2(step):
                var v2_error: String = TsukkomiRound.validate(step, prefix,
                    func(target: String) -> bool: return nodes.has(target),
                    func(item_id: String) -> bool: return _catalog_has_item(asset_catalog, item_id),
                    func(speaker: String) -> bool: return _is_speaker(asset_catalog, speaker))  # "gintoki+kagura" too
                if not v2_error.is_empty():
                    return v2_error
                for writes: Dictionary in TsukkomiRound.flag_writes(step):
                    var writes_error: String = _validate_flag_dictionary(writes, "%s boke option set_flags" % prefix)
                    if not writes_error.is_empty():
                        return writes_error
                return ""
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
            if not _is_non_empty_string(step.get("text", null)):
                return "%s cutin needs text" % prefix
            if step.has("speaker") and not _is_speaker(asset_catalog, String(step["speaker"])):
                return "%s cutin speaker '%s' is not in asset catalog" % [prefix, step["speaker"]]
        "comedy":
            var comedy_preset: String = String(step.get("preset", ""))
            if not VALID_COMEDY_PRESETS.has(comedy_preset):
                return "%s comedy preset '%s' is not one of %s" % [prefix, comedy_preset, ", ".join(VALID_COMEDY_PRESETS)]
            if not _catalog_has_character(asset_catalog, String(step.get("speaker", ""))):
                return "%s comedy speaker '%s' is not a character in the asset catalog" % [prefix, step.get("speaker", "")]
            if not _is_non_empty_string(step.get("text", null)):
                return "%s comedy needs text" % prefix
            if step.has("expression") and (typeof(step["expression"]) != TYPE_STRING or not VALID_EXPRESSIONS.has(String(step["expression"]))):
                return "%s comedy expression is invalid" % prefix
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
        "result":
            if not _is_non_empty_string(step.get("title", null)):
                return "%s result needs a title" % prefix
            if not step.get("lines", null) is Dictionary:
                return "%s result lines must map grades to {speaker, text}" % prefix
            for grade: Variant in (step["lines"] as Dictionary).keys():
                var grade_line: Variant = step["lines"][grade]
                if not GRADES.has(String(grade)) or not grade_line is Dictionary \
                        or not _is_non_empty_string((grade_line as Dictionary).get("text", null)) \
                        or not _is_speaker(asset_catalog, String((grade_line as Dictionary).get("speaker", "narrator"))):
                    return "%s result line '%s' needs a known speaker and text (grades %s)" % [prefix, grade, GRADES]
            if step.has("hidden_total") and (typeof(step["hidden_total"]) != TYPE_INT and typeof(step["hidden_total"]) != TYPE_FLOAT
                    or int(step["hidden_total"]) < 0):
                return "%s result hidden_total must be a non-negative whole number" % prefix
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


## An investigation: prompt, hotspots (home place), optional bg/label, talk topics and other
## places. Hotspot, topic and place ids are unique across the whole investigation.
func _validate_investigation(step: Dictionary, prefix: String, index: int, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if not _is_non_empty_string(step.get("id", null)):
        return "%s investigate id must be a non-empty string" % prefix
    if not _is_non_empty_string(step.get("prompt", null)):
        return "%s investigate prompt must be a non-empty string" % prefix
    if step.has("bg") and not _catalog_has_background(asset_catalog, String(step["bg"])):
        return "%s investigate bg '%s' is not in asset catalog" % [prefix, step["bg"]]
    if step.has("label") and not _is_non_empty_string(step["label"]):
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
            if not place is Dictionary or not _is_non_empty_string((place as Dictionary).get("id", null)):
                return "%s place %d needs an id" % [prefix, place_index]
            var place_id: String = String(place["id"])
            var where: String = "%s place '%s'" % [prefix, place_id]
            if place_id == HOME_PLACE or place_id.contains("/") or seen.has("place:" + place_id):
                return "%s: place ids must be unique, without '/', and not '%s'" % [where, HOME_PLACE]
            seen["place:" + place_id] = true
            if not _catalog_has_background(asset_catalog, String(place.get("bg", ""))):
                return "%s bg '%s' is not in asset catalog" % [where, place.get("bg", "")]
            for key: String in ["label", "prompt"]:
                if place.has(key) and not _is_non_empty_string(place[key]):
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


func _validate_hotspots(value: Variant, where: String, seen: Dictionary, nodes: Dictionary, asset_catalog: Dictionary, keep_cast: bool) -> String:
    if typeof(value) != TYPE_ARRAY or (value as Array).is_empty():
        return "%s investigate hotspots must be a non-empty array" % where
    var hotspots: Array = value as Array
    for hotspot_index: int in range(hotspots.size()):
        if not hotspots[hotspot_index] is Dictionary:
            return "%s hotspot %d must be an object" % [where, hotspot_index]
        var hotspot: Dictionary = hotspots[hotspot_index] as Dictionary
        if not _is_non_empty_string(hotspot.get("id", null)) or not _is_non_empty_string(hotspot.get("label", null)):
            return "%s hotspot %d needs id and label" % [where, hotspot_index]
        var hotspot_id: String = String(hotspot["id"])
        if seen.has("spot:" + hotspot_id):
            return "%s repeats hotspot id '%s'" % [where, hotspot_id]
        seen["spot:" + hotspot_id] = true
        if hotspot.has("character"):
            # The area of a character's hotspot is their portrait on stage, so it has no pos or size.
            if not keep_cast:
                return "%s hotspot '%s' has a character, so the investigation needs keep_cast: true" % [where, hotspot_id]
            if typeof(hotspot["character"]) != TYPE_STRING or not _catalog_has_character(asset_catalog, String(hotspot["character"])):
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
        if hotspot.has("item") and not _catalog_has_item(asset_catalog, String(hotspot["item"])):
            return "%s hotspot '%s' item '%s' is not in asset catalog" % [where, hotspot_id, hotspot["item"]]
        if hotspot.has("goto") and not nodes.has(String(hotspot["goto"])):
            return "%s hotspot '%s' goto target is invalid" % [where, hotspot_id]
        if hotspot.has("lines"):
            var lines: Variant = hotspot["lines"]
            if hotspot.has("goto"):
                return "%s hotspot '%s' has both goto and lines; use one" % [where, hotspot_id]
            if typeof(lines) != TYPE_ARRAY or (lines as Array).is_empty() or not (lines as Array).all(
                    func(target: Variant) -> bool: return _is_non_empty_string(target) and nodes.has(String(target))):
                return "%s hotspot '%s' lines must be a non-empty array of existing node ids" % [where, hotspot_id]
        if hotspot.has("set"):
            var set_error: String = _validate_flag_dictionary(hotspot["set"], "%s hotspot '%s' set" % [where, hotspot_id])
            if not set_error.is_empty():
                return set_error
        if hotspot.has("optional") and typeof(hotspot["optional"]) != TYPE_BOOL:
            return "%s hotspot '%s' optional must be boolean" % [where, hotspot_id]
    return ""


func _validate_topics(value: Variant, where: String, seen: Dictionary, nodes: Dictionary, asset_catalog: Dictionary) -> String:
    if typeof(value) != TYPE_ARRAY:
        return "%s talk must be an array of topics" % where
    for topic_index: int in range((value as Array).size()):
        var topic: Variant = value[topic_index]
        if not topic is Dictionary or not _is_non_empty_string((topic as Dictionary).get("id", null)) \
                or not _is_non_empty_string((topic as Dictionary).get("label", null)):
            return "%s talk topic %d needs id and label" % [where, topic_index]
        var topic_id: String = String(topic["id"])
        if seen.has("topic:" + topic_id):
            return "%s repeats talk topic id '%s'" % [where, topic_id]
        seen["topic:" + topic_id] = true
        if not nodes.has(String(topic.get("goto", ""))):
            return "%s talk topic '%s' goto target is invalid" % [where, topic_id]
        if topic.has("require") and not _catalog_has_item(asset_catalog, String(topic["require"])):
            return "%s talk topic '%s' require item '%s' is not in asset catalog" % [where, topic_id, topic["require"]]
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
func _hotspot_flag_writes(step: Dictionary) -> Array[Dictionary]:
    var all_writes: Array[Dictionary] = []
    for place: Dictionary in _investigation_places(step):
        for raw_hotspot: Variant in place["hotspots"] as Array:
            if (raw_hotspot as Dictionary).has("set"):
                all_writes.append((raw_hotspot as Dictionary)["set"] as Dictionary)
    return all_writes


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
    if INTERNAL_OPS.has(candidate_op):
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
    if hotspots_error.is_empty() and snapshot_data.has("investigations"):
        hotspots_error = _validate_investigations(snapshot_data["investigations"])
    if not hotspots_error.is_empty():
        return hotspots_error
    if snapshot_data.has("placard") and typeof(snapshot_data["placard"]) != TYPE_STRING:
        return "placard must be a string"
    var v1_op: String = "" if TsukkomiRound.is_v2(candidate_step) else candidate_op
    var boke_error: String = _validate_boke_snapshot(snapshot_data["boke"], v1_op, candidate_step)
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
    if v1_op == "boke_round" and String((snapshot_data["boke"] as Dictionary).get("round_id", "")) != String(candidate_step.get("id", "")):
        return "boke snapshot round_id does not match the current command"
    var saved_round: Variant = snapshot_data.get("round", {})
    if not saved_round is Dictionary:
        return "round must be an object"
    if not (saved_round as Dictionary).is_empty():
        var round_step: Dictionary = _find_phase3_command("boke_round", String((saved_round as Dictionary).get("id", "")))
        if not TsukkomiRound.is_v2(round_step):
            return "round state references an unknown round"
        var round_error: String = TsukkomiRound.validate_state(saved_round, round_step)
        if not round_error.is_empty():
            return round_error
    var saved_stats: Variant = snapshot_data.get("stats", {})
    if not saved_stats is Dictionary or not (saved_stats as Dictionary).values().all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and int(v) >= 0):
        return "stats must map names to non-negative integers"
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
    for raw_key: Variant in saved.keys():
        if typeof(raw_key) != TYPE_STRING:
            return "checked_hotspots keys must be strings"
        var key: String = String(raw_key)
        var investigation_id: String = key.get_slice("/", 0)
        var place_id: String = key.get_slice("/", 1) if key.contains("/") else HOME_PLACE
        var investigation: Dictionary = _find_phase3_command("investigate", investigation_id)
        if investigation.is_empty():
            return "checked_hotspots references unknown investigation '%s'" % investigation_id
        var place: Dictionary = {}
        for candidate: Dictionary in _investigation_places(investigation):
            if candidate["id"] == place_id:
                place = candidate
        if place.is_empty() or (key.contains("/") and place_id == HOME_PLACE):
            return "checked_hotspots references unknown place '%s'" % key
        if not saved[raw_key] is Array:
            return "checked_hotspots['%s'] must be an array" % key
        var seen: Dictionary = {}
        var valid_ids: Dictionary = {}
        for raw_hotspot: Variant in place["hotspots"] as Array:
            valid_ids[String((raw_hotspot as Dictionary)["id"])] = true
        for raw_checked_id: Variant in saved[raw_key] as Array:
            if typeof(raw_checked_id) != TYPE_STRING or not valid_ids.has(String(raw_checked_id)):
                return "checked_hotspots['%s'] contains an unknown hotspot" % key
            if seen.has(raw_checked_id):
                return "checked_hotspots['%s'] contains duplicate hotspot '%s'" % [key, raw_checked_id]
            seen[raw_checked_id] = true
    return ""


func _validate_investigations(value: Variant) -> String:
    if not value is Dictionary:
        return "investigations must be an object"
    for raw_id: Variant in (value as Dictionary).keys():
        var investigation: Dictionary = _find_phase3_command("investigate", String(raw_id))
        var state: Variant = value[raw_id]
        if investigation.is_empty():
            return "investigations references unknown investigation '%s'" % raw_id
        if not state is Dictionary or typeof((state as Dictionary).get("place")) != TYPE_STRING \
                or not (state as Dictionary).get("talked") is Array:
            return "investigations['%s'] needs place and talked" % raw_id
        var place_ids: Array = _investigation_places(investigation).map(func(place: Dictionary) -> String: return place["id"])
        if not place_ids.has(String(state["place"])):
            return "investigations['%s'] is at an unknown place" % raw_id
        var topic_ids: Array = []
        for place: Dictionary in _investigation_places(investigation):
            for topic: Dictionary in place["talk"]:
                topic_ids.append(String(topic["id"]))
        var seen: Dictionary = {}
        for topic_id: Variant in state["talked"]:
            if typeof(topic_id) != TYPE_STRING or not topic_ids.has(String(topic_id)) or seen.has(topic_id):
                return "investigations['%s'] lists an unknown or repeated topic" % raw_id
            seen[topic_id] = true
        # `counts` (taps per `lines` hotspot) is optional: saves from before it have none.
        var counts: Variant = (state as Dictionary).get("counts", {})
        if not counts is Dictionary:
            return "investigations['%s'] counts must be an object" % raw_id
        var tapped_ids: Array = []
        for place: Dictionary in _investigation_places(investigation):
            for raw_hotspot: Variant in place["hotspots"] as Array:
                if (raw_hotspot as Dictionary).has("lines"):
                    tapped_ids.append(String((raw_hotspot as Dictionary)["id"]))
        for hotspot_id: Variant in (counts as Dictionary).keys():
            var taps: Variant = counts[hotspot_id]
            if typeof(hotspot_id) != TYPE_STRING or not tapped_ids.has(hotspot_id) or typeof(taps) != TYPE_INT or int(taps) < 1:
                return "investigations['%s'] counts must map lines hotspots to a tap count of 1 or more" % raw_id
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
    if checkpoint.has("placard") and typeof(checkpoint["placard"]) != TYPE_STRING:
        return "checkpoint placard must be a string"
    if checkpoint.has("investigations"):
        var investigations_error: String = _validate_investigations(checkpoint["investigations"])
        if not investigations_error.is_empty():
            return "checkpoint %s" % investigations_error
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
