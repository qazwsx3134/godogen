extends "res://addons/proto_kit/test_kit.gd"
## Investigation with talk topics and places (the Phase 4 sample, story_src/phase4.*): topics play
## once and come back, `require` hides a topic until its item; moving to the kitchen shows its own
## picture and spots, each place keeps its own checked spots, a searched-out side place sends the
## player home; only required spots gate 繼續; saves, old saves and a Game Over retry never grant a
## material twice. Also the data checks for investigations, offscreen lines, entrances and placards.

const StoryRunner = preload("res://scripts/story_runner.gd")
const STORY: String = "res://data/phase4_story.json"
const BROKEN: String = "user://investigation_broken.json"
const HOME_SPOTS: Array[String] = ["empty_milk_bottle", "gintoki_mouth", "kombu_wrapper", "floor_paw_print"]


func _init() -> void:
	_test_talk_topics()
	_test_places_keep_their_own_spots()
	_test_reactions_and_completion()
	_test_saves()
	_test_game_over_retry_keeps_materials()
	_test_validation_errors()
	_finish("INVESTIGATION TESTS")


func _test_talk_topics() -> void:
	var runner: RefCounted = _at_search()
	var search: Dictionary = runner.call("current")
	_expect(search["place"] == "home" and search["bg"] == "yorozuya_living_room" and search["place_label"] == "客廳",
		"the search starts in the living room (%s)" % [search.get("place")])
	_expect(_ids(search["talk"]) == ["gintoki_bedtime", "kagura_dinner"], "two topics are open; Sadaharu's waits for the footprints")
	_expect(_ids(search["moves"]) == ["kitchen"] and search["progress"] == [0, 4] and not search["complete"],
		"one other place; four required spots, none found")
	_expect(not runner.call("talk_topic", "sadaharu_witness"), "a topic whose item is missing cannot be picked")
	_expect(runner.call("talk_topic", "gintoki_bedtime") and runner.get("node_id") == "talk_gintoki", "a topic plays its scene")
	_back_to_search(runner)
	search = runner.call("current")
	_expect(_ids(search["talk"]) == ["kagura_dinner"], "a played topic is gone from the list")
	_expect(not runner.call("talk_topic", "gintoki_bedtime"), "and cannot be played again")


func _test_places_keep_their_own_spots() -> void:
	var runner: RefCounted = _at_search()
	runner.call("inspect_hotspot", "empty_milk_bottle")
	_expect(runner.call("move_to", "kitchen"), "moving to the kitchen")
	var kitchen: Dictionary = runner.call("current")
	_expect(kitchen["place"] == "kitchen" and kitchen["bg"] == "yorozuya_kitchen" and kitchen["home_bg"] == "yorozuya_living_room"
		and _ids(kitchen["hotspots"]) == ["fridge"] and _ids(kitchen["moves"]) == ["home"] and (kitchen["talk"] as Array).is_empty(),
		"the kitchen has its own picture, its fridge, no topics, and the way back (%s)" % [kitchen.get("moves")])
	_expect(kitchen["progress"] == [1, 4], "progress counts the required spots of every place (the fridge is optional)")
	_expect(not runner.call("inspect_hotspot", "gintoki_mouth"), "a living-room spot cannot be searched from the kitchen")
	_expect(not runner.call("move_to", "kitchen") and not runner.call("move_to", "attic"), "no move to where you are or to nowhere")
	_expect(runner.call("move_to", "home"), "moving back")
	var home: Dictionary = runner.call("current")
	_expect(home["place"] == "home" and home["hotspots"][0]["checked"] and not home["hotspots"][1]["checked"],
		"the living room kept its checked spot")
	runner.call("inspect_hotspot", "empty_milk_bottle")
	_expect(runner.get("items") == ["milk_bottle"], "searching a checked spot again grants nothing")


func _test_reactions_and_completion() -> void:
	var runner: RefCounted = _at_search()
	runner.call("move_to", "kitchen")
	_expect(runner.call("inspect_hotspot", "fridge") and runner.get("node_id") == "kitchen_fridge", "the fridge plays its scene")
	runner.call("advance")
	var line: Dictionary = runner.call("current")
	_expect(line["op"] == "say" and line["speaker"] == "gintoki" and line.get("offscreen", false),
		"Gintoki answers from off stage (%s)" % [line])
	_back_to_search(runner)
	var search: Dictionary = runner.call("current")
	_expect(search["place"] == "home", "a searched-out side place sends the player back home after its scene")
	runner.call("move_to", "kitchen")
	_expect(runner.call("current")["hotspots"][0]["checked"] and runner.call("inspect_hotspot", "fridge")
		and runner.call("current")["op"] == "investigate", "the fridge stays checked and does not replay")
	runner.call("move_to", "home")
	_expect(runner.call("inspect_hotspot", "floor_paw_print") and runner.get("node_id") == "spot_floor", "the footprints have a scene too")
	_back_to_search(runner)
	search = runner.call("current")
	_expect(runner.get("profiles").has("sadaharu") and _ids(search["talk"]).has("sadaharu_witness"),
		"the scene unlocked Sadaharu's profile; his topic opens now that the footprints are held")
	for spot: String in ["empty_milk_bottle", "gintoki_mouth", "kombu_wrapper"]:
		runner.call("inspect_hotspot", spot)
	search = runner.call("current")
	_expect(search["complete"] and search["progress"] == [4, 4], "four required spots complete the search")
	runner.call("move_to", "kitchen")
	runner.call("advance")
	_expect(runner.call("current")["op"] == "say" and runner.get("investigations")["living_room_search"]["place"] == "home",
		"繼續 works from any place and ends the search at home")


func _test_saves() -> void:
	var runner: RefCounted = _at_search()
	runner.call("inspect_hotspot", "empty_milk_bottle")
	runner.call("talk_topic", "kagura_dinner")
	_back_to_search(runner)
	runner.call("move_to", "kitchen")
	var saved: Dictionary = runner.call("snapshot")
	_expect(saved["investigations"] == {"living_room_search": {"place": "kitchen", "talked": ["kagura_dinner"]}},
		"the snapshot keeps where the player is and what was talked about (%s)" % [saved["investigations"]])
	var resumed: RefCounted = _loaded()
	_expect(resumed.call("restore", saved), "a save in the kitchen restores: %s" % resumed.get("error_message"))
	var kitchen: Dictionary = resumed.call("current")
	_expect(kitchen["place"] == "kitchen" and resumed.get("items") == ["milk_bottle"], "back in the kitchen with one material")
	resumed.call("move_to", "home")
	var home: Dictionary = resumed.call("current")
	_expect(home["hotspots"][0]["checked"] and _ids(home["talk"]) == ["gintoki_bedtime"], "the living room remembers its spot and topic")

	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("investigations")
	legacy.erase("placard")
	_expect(resumed.call("restore", legacy) and resumed.call("current")["place"] == "home",
		"a save from before places loads at home")
	for broken: Dictionary in [{"living_room_search": {"place": "attic", "talked": []}},
			{"living_room_search": {"place": "home", "talked": ["gossip"]}},
			{"living_room_search": {"place": "home", "talked": ["kagura_dinner", "kagura_dinner"]}},
			{"nowhere": {"place": "home", "talked": []}}]:
		var bad: Dictionary = saved.duplicate(true)
		bad["investigations"] = broken
		_expect(not resumed.call("restore", bad), "a save with %s is rejected" % [broken])
	var bad_spots: Dictionary = saved.duplicate(true)
	bad_spots["checked_hotspots"]["living_room_search/home"] = ["empty_milk_bottle"]
	_expect(not resumed.call("restore", bad_spots), "the home place never keys as <id>/home")
	bad_spots = saved.duplicate(true)
	bad_spots["checked_hotspots"]["living_room_search/kitchen"] = ["empty_milk_bottle"]
	_expect(not resumed.call("restore", bad_spots), "a kitchen key only lists kitchen spots")


## A Game Over in the round after the search goes back to the round's checkpoint: materials,
## checked spots and talked topics are what they were, and nothing is granted twice.
func _test_game_over_retry_keeps_materials() -> void:
	var runner: RefCounted = _at_search()
	runner.call("talk_topic", "gintoki_bedtime")
	_back_to_search(runner)
	for spot: String in HOME_SPOTS:
		runner.call("inspect_hotspot", spot)
		_back_to_search(runner)
	runner.call("advance")
	_advance_until(runner, "choice")
	runner.call("choose", "ask_gintoki")
	_advance_until(runner, "boke_round")
	var before: Dictionary = runner.call("snapshot")
	for _cold: int in range(5):
		runner.call("resolve_boke", "missed_comeback")
		_advance_until(runner, "boke_round" if runner.get("gameplay")["glasses"] > 0 else "end")
	_expect(runner.get("node_id") == "game_over", "five cold takes end on Game Over")
	_expect(runner.call("retry_checkpoint"), "the retry goes back to the round")
	_expect(runner.get("items") == before["items"] and (runner.get("items") as Array).size() == 4
		and runner.get("checked_hotspots") == before["checked_hotspots"] and runner.get("investigations") == before["investigations"],
		"the retry keeps the four materials once, the checked spots and the talked topics")


func _test_validation_errors() -> void:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	var cases: Array = [
		[func(s: Dictionary) -> void: (s["nodes"]["search"]["steps"] as Array).push_front({"op": "say", "speaker": "shinpachi", "text": "先說一句。"}),
			"node 'search' step 1 investigate 'living_room_search' has reactions"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0].erase("bg"), "node 'search' step 0 investigate with places needs its own bg"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["places"][0]["hotspots"][0].erase("goto"),
			"place 'kitchen' hotspot 'fridge' needs an item, a goto reaction, or both"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["talk"][0]["goto"] = "nowhere", "talk topic 'gintoki_bedtime' goto target is invalid"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["talk"][1]["id"] = "gintoki_bedtime", "repeats talk topic id 'gintoki_bedtime'"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["places"][0]["id"] = "home", "place ids must be unique"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["places"][0]["hotspots"][0]["id"] = "gintoki_mouth",
			"repeats hotspot id 'gintoki_mouth'"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["places"][0]["bg"] = "attic", "place 'kitchen' bg 'attic' is not in asset catalog"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["hotspots"][0]["optional"] = "yes", "optional must be boolean"],
		[func(s: Dictionary) -> void: s["nodes"]["search"]["steps"][0]["talk"][2]["require"] = "cake", "require item 'cake' is not in asset catalog"],
		[func(s: Dictionary) -> void: s["nodes"]["spot_floor"]["steps"][2]["speaker"] = "narrator",
			"node 'spot_floor' step 2 say offscreen needs a character speaker"],
		[func(s: Dictionary) -> void: s["nodes"]["spot_floor"]["steps"][2]["offscreen"] = "yes", "node 'spot_floor' step 2 say offscreen must be boolean"],
		[func(s: Dictionary) -> void: s["nodes"]["phase4_open"]["steps"][1] = {"op": "char", "id": "elisabeth", "enter": true, "visible": false},
			"node 'phase4_open' step 1 char cannot enter and hide at once"],
		[func(s: Dictionary) -> void: s["nodes"]["phase4_open"]["steps"][1] = {"op": "placard", "text": 3},
			"node 'phase4_open' step 1 placard text must be a string"],
	]
	for case: Array in cases:
		var story: Dictionary = base.duplicate(true)
		case[0].call(story)
		var file: FileAccess = FileAccess.open(BROKEN, FileAccess.WRITE)
		file.store_string(JSON.stringify(story))
		file.close()
		var runner: RefCounted = StoryRunner.new()
		_expect(not runner.call("load_story", BROKEN) and String(runner.get("error_message")).contains(case[1]),
			"invalid story is rejected with '%s' (got: %s)" % [case[1], runner.get("error_message")])
	DirAccess.remove_absolute(BROKEN)


func _loaded() -> RefCounted:
	var runner: RefCounted = StoryRunner.new()
	_expect(runner.call("load_story", STORY), "the sample loads: %s" % runner.get("error_message"))
	return runner


func _at_search() -> RefCounted:
	var runner: RefCounted = _loaded()
	_advance_until(runner, "investigate")
	return runner


## Reads a reaction scene through until the search is back.
func _back_to_search(runner: RefCounted) -> void:
	_advance_until(runner, "investigate")


func _advance_until(runner: RefCounted, op: String) -> void:
	for _step: int in range(40):
		if String(runner.call("current").get("op", "")) == op:
			return
		runner.call("advance")
	_expect(false, "reached op '%s' (stopped at %s)" % [op, runner.get("node_id")])


func _ids(entries: Array) -> Array:
	return entries.map(func(entry: Dictionary) -> String: return str(entry["id"]))
