extends RefCounted

## Data-driven story runtime for the debt commission prototype.
## The script deliberately does not use class_name; callers preload it directly.

const MAX_INTERNAL_TRANSITIONS: int = 128
const ASSET_CATALOG_PATH: String = "res://data/asset_catalog.json"
const TsukkomiRound = preload("res://scripts/tsukkomi_round.gd")
const StoryValidator = preload("res://scripts/story_validator.gd")
const DEFAULT_GAMEPLAY: Dictionary = {
    "glasses": 5,
    "max_glasses": 5,
    "power": 0,
    "max_power": 100,
}
const VALID_BOKE_RESULTS = StoryValidator.VALID_BOKE_RESULTS
const VALID_CHARACTER_TRANSITIONS = StoryValidator.VALID_CHARACTER_TRANSITIONS
const GRADES = StoryValidator.GRADES
## Share of caught slots that must be perfect for an S (see grade_for).
const S_PERFECT_RATIO: float = 0.6
const VALID_TONES = StoryValidator.VALID_TONES
const HOME_PLACE = StoryValidator.HOME_PLACE
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
## Every node the story has passed through since it loaded, for 流程圖 (story_library.gd keeps them).
var _visits: Dictionary = {}
var _new_visits: Array[String] = []
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


## catalog_path: the catalog to check it against; "" uses catalog_path_for(path).
func load_story(path: String, catalog_path: String = "") -> bool:
    _visits.clear()
    _new_visits.clear()
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
    var catalog_result: Dictionary = _read_asset_catalog(catalog_path if not catalog_path.is_empty() else catalog_path_for(path))
    if not bool(catalog_result.get("ok", false)):
        return _reject("Invalid asset catalog: %s" % String(catalog_result.get("error", "unknown error")))

    var candidate_catalog: Dictionary = catalog_result["catalog"] as Dictionary
    var validation_error: String = StoryValidator.validate_story(parsed, candidate_catalog)
    if not validation_error.is_empty():
        return _reject("Invalid story: %s" % validation_error)

    var candidate: Dictionary = parsed as Dictionary
    var candidate_flags: Dictionary = candidate["initial_flags"].duplicate(true)
    var candidate_allowed_values: Dictionary = StoryValidator.collect_allowed_flag_values(candidate)
    var candidate_has_phase3_ops: bool = StoryValidator.story_has_phase3_ops(candidate)

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


## An isolated state machine sharing this already-validated story definition.
## Story/catalog dictionaries are read-only after load; restore() copies only save state.
## This avoids file I/O and full story validation for every autosave or slot preview.
func create_validation_probe() -> RefCounted:
    if not _loaded:
        return null
    var probe: RefCounted = get_script().new() as RefCounted
    probe._story = _story
    probe._asset_catalog = _asset_catalog
    probe._initial_flags = _initial_flags
    probe._allowed_flag_values = _allowed_flag_values
    probe._has_phase3_ops = _has_phase3_ops
    probe._loaded = true
    return probe


## True when the story uses investigation or tsukkomi rounds, so the shell shows the
## glasses/power HUD, the materials button and Game Over retry.
func has_gameplay() -> bool:
    return _loaded and _has_phase3_ops


## The story's own `title` and `note`, for the title screen.
## Whose thought a choice without `pov` is (and who thinks while searching): the story's own
## `default_pov`, else the catalog's, else its first character.
func default_pov() -> String:
    var own: String = String(_story.get("default_pov", ""))
    if not own.is_empty():
        return own
    var characters: Dictionary = _asset_catalog.get("characters", {}) as Dictionary
    var from_catalog: String = String(_asset_catalog.get("default_pov", ""))
    if characters.has(from_catalog):
        return from_catalog
    return String(characters.keys()[0]) if not characters.is_empty() else ""


## The story's screen: "landscape" (default) or "portrait". Chosen before writing; main switches the canvas.
func orientation() -> String:
    return String(_story.get("orientation", "landscape"))


func story_info() -> Dictionary:
    return {"title": String(_story.get("title", "")), "note": String(_story.get("note", "")),
        "credits": (_story.get("credits", []) as Array).duplicate(true)}


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
    var grade: String = grade_for(int(gameplay.get("glasses", 0)), int(stats.get("game_overs", 0)),
            int(stats.get("perfect", 0)), int(stats.get("caught", 0)))
    var line: Dictionary = ((command.get("lines", {}) as Dictionary).get(grade, {}) as Dictionary).duplicate()
    return {
        "title": String(command.get("title", "")),
        "ending_title": String(command.get("ending_title", command.get("ending", ""))),
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
## grade, never below C, so retrying cannot farm an S. S also needs at least S_PERFECT_RATIO of
## the caught slots answered perfect: playing safe with weak answers tops out at A.
static func grade_for(glasses: int, game_overs: int, perfect: int = 0, caught: int = 0) -> String:
    var index: int = 0 if glasses >= 5 else 1 if glasses == 4 else 2 if glasses >= 2 else 3
    if index == 0 and caught > 0 and perfect < ceili(caught * S_PERFECT_RATIO):
        index = 1
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
    var found: Dictionary = _collectables()
    return {"materials": materials, "profiles": people,
        "material_total": maxi(found["items"].size(), materials.size()), "profile_total": maxi(found["profiles"].size(), people.size())}


## Every material and profile this story can give: `item` and `profile` steps and the items of search
## spots (every place). The case file shows the ones not found yet as numbered blanks.
func _collectables() -> Dictionary:
    var item_ids: Dictionary = {}
    var profile_ids: Dictionary = {}
    for node: Variant in (_story.get("nodes", {}) as Dictionary).values():
        for step: Variant in (node as Dictionary).get("steps", []):
            var command: Dictionary = step as Dictionary
            match String(command.get("op", "")):
                "item":
                    item_ids[String(command.get("id", ""))] = true
                "profile":
                    profile_ids[String(command.get("id", ""))] = true
                "investigate":
                    var spots: Array = (command.get("hotspots", []) as Array).duplicate()
                    for place: Variant in command.get("places", []):
                        spots.append_array((place as Dictionary).get("hotspots", []))
                    for spot: Variant in spots:
                        if (spot as Dictionary).has("item"):
                            item_ids[String((spot as Dictionary)["item"])] = true
    return {"items": item_ids.keys(), "profiles": profile_ids.keys()}


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


## The immediately following authored step in this node, without changing the reading position.
func following_op() -> String:
    if not _loaded or not _story_node_exists(node_id):
        return ""
    var steps: Array = (_story["nodes"][node_id] as Dictionary).get("steps", []) as Array
    if step_index + 1 >= steps.size():
        return ""
    return String((steps[step_index + 1] as Dictionary).get("op", ""))


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
    if not StoryValidator.is_non_empty_string(line.get("listen", null)):
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
    return {"result": decision["result"], "goto": decision["goto"], "game_over": decision["game_over"], "action": kind}


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
        if not _visits.has(node_id):
            _visits[node_id] = true
            _new_visits.append(node_id)
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
            "set_flag", "flag":
                var flag_key: String = String(step["key"])
                if step.has("add"):
                    flags[flag_key] = flags[flag_key] + step["add"]
                else:
                    flags[flag_key] = step["value"]
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
                var target: String = String(step["else"])
                var passed: bool = _test_passes(step["test"]) if step.has("test") \
                        else flags.get(String(step["flag"]), null) == step["equals"]
                if passed:
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
        if bool(presentable_command["visible"]):
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


## The catalog a story uses: catalog.json beside the story file (a story pack), else the game's.
static func catalog_path_for(story_path: String) -> String:
    var beside: String = story_path.get_base_dir().path_join("catalog.json")
    return beside if story_path.begins_with("res://") and FileAccess.file_exists(beside) else ASSET_CATALOG_PATH


## The catalog at `path` with what it `extends` laid under it and its relative asset paths made
## res:// (relative to its own folder): {catalog} or {error}. Not validated.
## `redirect` {catalog path: file to read instead} lets a candidate stand in for a catalog, also
## where another catalog `extends` it (the story editor checks an edit before saving it).
static func read_catalog(path: String, redirect: Dictionary = {}) -> Dictionary:
    var source: String = String(redirect.get(path, path))
    if not FileAccess.file_exists(source):
        return {"error": "catalog file does not exist: %s" % path}
    var parser := JSON.new()
    if parser.parse(FileAccess.get_file_as_string(source)) != OK:
        return {"error": "invalid catalog JSON in %s: %s" % [path, parser.get_error_message()]}
    if not parser.data is Dictionary:
        return {"error": "%s: root must be an object" % path}
    var own: Dictionary = _resolved_paths(parser.data as Dictionary, path.get_base_dir())
    if not own.has("extends"):
        return {"catalog": own}
    var base_path: String = String(own["extends"])
    if base_path == path or not base_path.begins_with("res://"):
        return {"error": "%s: extends must name another res:// catalog" % path}
    var base: Dictionary = read_catalog(base_path, redirect)
    if base.has("error"):
        return base
    var merged: Dictionary = (base["catalog"] as Dictionary).duplicate(true)
    for key: String in own.keys():
        if key == "extends":
            continue
        if merged.get(key) is Dictionary and own[key] is Dictionary:
            (merged[key] as Dictionary).merge(own[key] as Dictionary, true)
        else:
            merged[key] = own[key]
    return {"catalog": merged}


## Asset paths that are not res:// (path, expression pictures, a character's scene) are made
## relative to `folder`.
static func _resolved_paths(catalog: Dictionary, folder: String) -> Dictionary:
    var result: Dictionary = catalog.duplicate(true)
    var resolve: Callable = func(value: Variant) -> Variant:
        return folder.path_join(String(value)) if value is String and not String(value).is_empty() \
            and not String(value).contains("://") else value
    for collection: String in ["backgrounds", "characters", "items", "sounds", "music"]:
        if not result.get(collection) is Dictionary:
            continue
        for id: Variant in (result[collection] as Dictionary).keys():
            var entry: Variant = result[collection][id]
            if not entry is Dictionary:
                continue
            for field: String in ["path", "scene"]:
                if (entry as Dictionary).has(field):
                    entry[field] = resolve.call(entry[field])
            if (entry as Dictionary).get("expressions") is Dictionary:
                for expression: Variant in (entry["expressions"] as Dictionary).keys():
                    entry["expressions"][expression] = resolve.call(entry["expressions"][expression])
    return result


func _read_asset_catalog(path: String = ASSET_CATALOG_PATH) -> Dictionary:
    var read: Dictionary = read_catalog(path)
    if read.has("error"):
        return {"ok": false, "error": read["error"]}
    var validation_error: String = StoryValidator.validate_asset_catalog(read["catalog"])
    if not validation_error.is_empty():
        return {"ok": false, "error": validation_error}
    return {"ok": true, "catalog": (read["catalog"] as Dictionary).duplicate(true)}


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
        if not _flag_value_is_allowed(String(key), candidate_flags[key]):
            return "invalid value for flag '%s'" % key
    return ""


func _validate_saved_profiles(value: Variant) -> String:
    if not value is Array:
        return "profiles must be an array"
    var seen: Dictionary = {}
    for profile_value: Variant in value as Array:
        var profile_id: String = String(profile_value) if typeof(profile_value) == TYPE_STRING else ""
        if not StoryValidator.catalog_has_character(_asset_catalog, profile_id) or seen.has(profile_id):
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
        if not StoryValidator.catalog_has_item(_asset_catalog, item_id):
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


func _copy_string_array(value: Array) -> Array[String]:
    var copied: Array[String] = []
    for entry: Variant in value:
        copied.append(String(entry))
    return copied


## The endings a story can reach, [{id, title}] in node order, one per id. The title is
## `ending_title`, else the end's text or the result's title.
static func endings_of(story: Dictionary) -> Array[Dictionary]:
    var found: Array[Dictionary] = []
    var seen: Dictionary = {}
    for node: Variant in (story.get("nodes", {}) as Dictionary).values():
        for step: Variant in (node as Dictionary).get("steps", []):
            var ending: String = String((step as Dictionary).get("ending", ""))
            if ending.is_empty() or seen.has(ending):
                continue
            seen[ending] = true
            var fallback: String = String(step.get("text", step.get("title", ending)))
            found.append({"id": ending, "title": String(step.get("ending_title", fallback))})
    return found


## The nodes passed through for the first time since the last call (oldest first), then forgets them.
func take_visits() -> Array[String]:
    var taken: Array[String] = _new_visits
    _new_visits = []
    return taken


## The `carry` flags (root field) with their current values, to hand to the next chapter.
func carry_out() -> Dictionary:
    var carried: Dictionary = {}
    for key: Variant in _story.get("carry", []):
        carried[key] = flags[key]
    return carried


## Starts this story with carried values for its `carry` flags (those a save of this story could
## hold; others keep initial_flags), then resets to the entry.
func carry_in(values: Dictionary) -> bool:
    if not _loaded:
        return false
    _initial_flags = _initial_flags.duplicate(true)
    for key: Variant in _story.get("carry", []):
        if values.has(key) and _flag_value_is_allowed(String(key), values[key]):
            _initial_flags[key] = values[key]
    return _reset_state()


func _test_passes(test: Dictionary) -> bool:
    if test.has("all"):
        return (test["all"] as Array).all(func(part: Dictionary) -> bool: return _test_passes(part))
    if test.has("any"):
        return (test["any"] as Array).any(func(part: Dictionary) -> bool: return _test_passes(part))
    if test.has("not"):
        return not _test_passes(test["not"])
    if test.has("has"):
        return items.has(String(test["has"]))
    var current: Variant = flags[String(test["flag"])]
    var value: Variant = test["value"]
    match String(test["cmp"]):
        "==":
            return current == value
        "!=":
            return current != value
        "<":
            return current < value
        "<=":
            return current <= value
        ">":
            return current > value
    return current >= value


func _flag_value_is_allowed(key: String, value: Variant) -> bool:
    if not _allowed_flag_values.has(key):
        return false
    if _allowed_flag_values[key] is Dictionary:  # {"kind": type}: a counter or a `carry` flag
        return StoryValidator.flag_kind(value) == int(_allowed_flag_values[key]["kind"])
    var allowed_values: Array = _allowed_flag_values[key] as Array
    return allowed_values.has(value)


func _reject(message: String) -> bool:
    error_message = message
    return false


func validate_credits(credits: Variant) -> String:
    return StoryValidator.validate_credits(credits)
