extends SceneTree
## Frame cost of the push on this machine: plays main.tscn with the stage for a few seconds of fighting (a volley and
## a telegraph included) and prints average and worst frame time (wall clock) and draw calls.
##   godot --path prototypes/hero-horde-idle --resolution 780x1688 --script res://tools/perf_probe.gd
## Desktop numbers only bound the problem; the phone is the real test.

const PushSim = preload("res://domain/push_sim.gd")

var _main: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	var sim: PushSim = _main.sim
	sim.skip_muster()
	for k: int in 60:
		await process_frame
	var times: Array[float] = []
	var draws: Array[int] = []
	var last: int = Time.get_ticks_usec()
	for k: int in 600:
		if k == 200:
			sim.morale = PushSim.MORALE_MAX
			sim.volley()
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	times.sort()
	var avg: float = 0.0
	for t: float in times:
		avg += t
	avg /= times.size()
	print("PERF frames=%d avg_ms=%.2f p95_ms=%.2f max_ms=%.2f draw_calls_max=%d draw_calls_avg=%d" % [times.size(), avg,
		times[int(times.size() * 0.95)], times[-1], draws.max(), int(draws.reduce(func(a, b): return a + b) / draws.size())])
	quit(0)
