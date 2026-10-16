extends SceneTree
## Fixed-input CPU microbenchmark. Run headless with --fixed-fps 60; isolates its own save paths.
const Grid := preload("res://scripts/grid.gd")
const Def := preload("res://scripts/enemy_def.gd")
const QUERIES := 4096
class Actor extends Node2D:
	var dead: bool = false
	var definition: Resource
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var dense: bool = "--clustered" in OS.get_cmdline_user_args()
	var extent := Vector2(90,90) if dense else Vector2(552,792)
	var query_extent := Vector2(40,40) if dense else extent
	var actors: Array = []
	for i: int in 140:
		var actor := Actor.new()
		actor.definition = Def.new()
		actor.definition.radius = rng.randf_range(10.0,48.0)
		actor.position = Vector2(rng.randf_range(-extent.x,extent.x),rng.randf_range(-extent.y,extent.y))
		actor.set_meta("index",i)
		root.add_child(actor)
		actors.append(actor)
	var grid := Grid.new()
	grid.rebuild(actors)
	var points: Array[Vector2] = []
	for i: int in QUERIES:
		points.append(Vector2(rng.randf_range(-query_extent.x,query_extent.x),rng.randf_range(-query_extent.y,query_extent.y)))
	var rows: Dictionary = {}
	for mode: String in ["query","nearest","crowded"]:
		var samples: Array[float] = []
		var checksum: int = 0
		for repetition: int in 6:
			var started: int = Time.get_ticks_usec()
			var result: int = 0
			for at: Vector2 in points:
				if mode=="query":
					result += grid.query(at,120.0).size()
				elif mode=="crowded":
					result += int(grid.call("has_at_least",at,120.0,8)) if grid.has_method("has_at_least") else int(grid.query(at,120.0).size() >= 8)
				else:
					var nearest: Node2D = grid.nearest(at,260.0)
					result += int(nearest.get_meta("index")) if nearest != null else -1
			if repetition > 0:
				samples.append(float(Time.get_ticks_usec()-started)/QUERIES)
			checksum = result
		samples.sort()
		rows[mode]={"median_us_per_call":samples[2],"checksum":checksum,"queries":QUERIES}
	print("STUDIO_GRID_BENCH ",JSON.stringify(rows))
	for actor: Node2D in actors:
		actor.free()
	quit()
