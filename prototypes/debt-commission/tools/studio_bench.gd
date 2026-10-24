extends SceneTree
## Fixed-input CPU microbenchmark. Run headless with --fixed-fps 60; isolates its own save paths.
const ITERATIONS := 60
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	game.story_path = "res://data/chapter1_story.json"
	game.save_path = "user://studio_bench.save"
	game.settings_path = "user://studio_bench_settings.cfg"
	game.progress_path = "user://studio_bench_progress.cfg"
	root.add_child(game)
	await process_frame
	game._on_begin_pressed()
	for i: int in 15:
		await process_frame
	game._complete_current_line()
	var payload: Dictionary = game._build_save_payload("")
	var before: Dictionary = game._runner.snapshot()
	var samples: Array[float] = []
	var accepted: int = 0
	for i: int in ITERATIONS + 3:
		var started: int = Time.get_ticks_usec()
		var valid: bool = game._validate_save_payload(payload)
		var elapsed: float = float(Time.get_ticks_usec() - started)
		accepted += int(valid)
		if i >= 3:
			samples.append(elapsed)
	samples.sort()
	print("STUDIO_DEBT_BENCH ", JSON.stringify({"iterations":ITERATIONS,"accepted":accepted,"unchanged":before==game._runner.snapshot(),"mean_us":samples.reduce(func(a:float,b:float)->float:return a+b,0.0)/samples.size(),"median_us":samples[samples.size()/2],"p95_us":samples[int(samples.size()*0.95)]}))
	game.queue_free()
	await process_frame
	await process_frame
	quit()
