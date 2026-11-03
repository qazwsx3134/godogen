extends SceneTree
## Captures representative runtime screens in a virtual display for the art handoff.

const TITLE := "res://scenes/title.tscn"
const ROUND_ONE := "res://scenes/three_eat.tscn"
const ROUND_TWO := "res://scenes/feast.tscn"
const FINAL_ROUND := "res://scenes/toss_game.tscn"

var _shot_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://../../.claude/tasks/kagura-dango/shots")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var title: Node = await _attach_scene(TITLE)
	_save_viewport("v3-title.png")
	title.queue_free()
	await process_frame
	for who in [["銀時", "甜食可是阿銀的主場。"], ["神樂", "全部吃光光阿魯！"]]:
		var story: Node = await _attach_scene("res://scenes/story.tscn")
		story.play([who])
		await process_frame
		_save_viewport("v3-story-%s.png" % ("gintoki" if who[0] == "銀時" else "kagura"))
		story.queue_free()
		await process_frame
	var bday: Node = await _attach_scene("res://scenes/story.tscn")
	bday.play([["萬事屋", "神樂，生日快樂！", "res://assets/sprites/kagura_birthday.png"]])
	await process_frame
	_save_viewport("v3-birthday.png")
	bday.queue_free()
	await process_frame
	await _capture_round_one()
	await _capture_round_two()
	await _capture_final_round()
	await _capture_eye_hit()
	quit()


## Round 2: a rival sneaking in, Kagura on rice, Shinpachi packing.
func _capture_round_two() -> void:
	MatchState.reset()
	MatchState.eaten[&"gintoki"] = 8
	MatchState.eaten[&"shinpachi"] = 9
	MatchState.eaten[&"kagura"] = 13
	MatchState.score = 30000
	var level: Node = await _attach_scene(ROUND_TWO)
	var hits: Array = level.get("hits")
	var rival_index := hits.find_custom(func(h): return h.type == &"rival")
	var t: float = (hits[rival_index].time + level.conductor.beat_time(hits[rival_index].cue_beat)) * 0.5
	level.get_node("%Conductor").clock = func(): return t
	level.call("_on_cue", rival_index)
	await create_timer(0.2).timeout
	level.get_node("%Kagura").call("play_pose", &"rice", 2.0)
	level.get_node("%Shinpachi").call("play_pose", &"pack", 2.0)
	level.hud.add_score(1000, 31000, true)  # an ace just landed: the score pops and "+1000" floats up
	await create_timer(0.08).timeout
	_save_viewport("v3-round-2.png")
	level.get_node("%Gintoki").call("play_pose", &"kick", 3.0)
	await create_timer(1.05).timeout
	_save_viewport("v3-round-2-kick.png")
	level.queue_free()
	await process_frame


## Round 3: Kagura hit in the eye, one life gone.
func _capture_eye_hit() -> void:
	MatchState.reset()
	MatchState.eaten[&"kagura"] = 50
	var level: Node = await _attach_scene(FINAL_ROUND, "res://data/songs/toss3.json")
	level.get_node("%HUD").set_lives(2, 3)
	level.get_node("%Kagura").call("play_pose", &"eye", 3.0)
	level.get_node("%Shinpachi").call("play_pose", &"dart", 3.0)
	await create_timer(0.2).timeout
	_save_viewport("v3-round-3-eye.png")
	level.queue_free()
	await process_frame


func _attach_scene(path: String, chart_path := "") -> Node:
	var scene := load(path) as PackedScene
	var instance := scene.instantiate()
	if not chart_path.is_empty():
		instance.set("chart_path", chart_path)
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance


func _capture_round_one() -> void:
	MatchState.reset()
	var level: Node = await _attach_scene(ROUND_ONE)
	level.call("_on_cue", 0)
	var skewers: Node2D = level.get_node("%Skewers")
	var skewer: Node = skewers.get_child(skewers.get_child_count() - 1)
	var served_at := float(skewer.get("t1"))
	level.get_node("%Conductor").clock = func(): return served_at
	await process_frame
	_save_viewport("v3-round-1.png")
	level.queue_free()
	await process_frame


func _capture_final_round() -> void:
	MatchState.reset()
	MatchState.eaten[&"gintoki"] = 8
	MatchState.eaten[&"shinpachi"] = 9
	MatchState.eaten[&"kagura"] = 36  # a perfect run's count: round 3 opens with her round 2 body
	MatchState.score = 97000
	var level: Node = await _attach_scene(FINAL_ROUND, "res://data/songs/toss3.json")
	level.call("_on_cue", 0)
	var skewers: Node2D = level.get_node("%Skewers")
	var skewer: Node = skewers.get_child(skewers.get_child_count() - 1)
	var midflight := (float(skewer.get("t0")) + float(skewer.get("t1"))) * 0.5
	level.get_node("%Conductor").clock = func(): return midflight
	await process_frame
	await process_frame
	_save_viewport("v3-round-3.png")
	level.queue_free()
	await process_frame


func _save_viewport(filename: String) -> void:
	var image := root.get_texture().get_image()
	var path := _shot_dir.path_join(filename)
	var result := image.save_png(path)
	assert(result == OK, "Could not save screenshot %s: %s" % [path, error_string(result)])
	print("Saved screenshot %s (%dx%d)" % [path, image.get_width(), image.get_height()])
