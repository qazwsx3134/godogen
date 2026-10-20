extends RefCounted
## QA switches after `--` on the command line:
##   --autoplay        the autopilot plays (recording, soak tests)
##   --stress=<n>      spawn n enemies around the player at once (performance)
##   --seed=<n>        fixed spawn randomness
##   --duration=<s>    shorter run (win at this many seconds)
##   --no-hud-perf     hide the performance line
##   --cam=<preset>    camera preset (pokebonk, madara, high, higher; camera_rig.gd PRESETS)
##   --cam-height=<m> --cam-back=<m> --cam-ahead=<m> --fov=<deg>   override one number of the view
##   --learn=fireball:5,gunbai:3      start with these jutsu at these levels (ids in data/jutsu)
##   --dominance=100                  start with this much Dominance
##   --start-z=<m>     start this far along the route (negative z is forward)
##   --perf=<s>        after `perf-warmup` seconds (default 10) record wall-clock frame times for s seconds, print
##                     p95 / slowest / enemies in view as a PERF line, then quit
##   --density=033|025|020   placeholder cast pixel density (default 025; scripts/sprite_set.gd)
##   --ult-at=<s>      autoplay fires the ultimate at this game time (a mass hit inside a perf window)
##   --no-warmup       skip the start-of-run shader warm-up (to measure what it saves)
##   --act=<n>         play act n (scenes/acts/act_<n>.tscn); 0 = the free-run sandbox; default: main's default_act,
##                     or the sandbox when perf, stress or shot is given
##   --skip-cutscenes  cutscenes end as soon as they start (tests, soak runs)
##   --cutscene=<name> play scenes/cutscenes/<name>.tscn right after the warm-up, no act (with --shot: check a shot)
##   --shot=<png>      after `shot-delay` real seconds (default 2) save a screenshot, print the composition, quit
## On the web the same switches come from the page URL: index.html?stress=400&autoplay&seed=3

var autoplay: bool = false
var stress: int = 0
var seed: int = -1
var duration: float = -1.0
var show_perf: bool = true
var cam: String = ""
## height, back, look_ahead, fov overrides; negative = keep the scene's value.
var cam_height: float = -1.0
var cam_back: float = -1.0
var cam_ahead: float = -1.0
var fov: float = -1.0
var learn: String = ""
var dominance: float = -1.0
var start_z: float = 0.0
var shot: String = ""
var perf: float = 0.0
var ult_at: float = -1.0
var warmup: bool = true
var density: String = "025"
var perf_warmup: float = 10.0
var shot_delay: float = 2.0
var act: int = -1
var skip_cutscenes: bool = false
var cutscene: String = ""


## Command-line switches, plus the page URL's query on the web.
static func current() -> RefCounted:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var query: String = str(JavaScriptBridge.eval("window.location.search", true)).trim_prefix("?")
		for pair: String in query.split("&", false):
			args.append("--" + pair)
	return from_args(args)


static func from_args(args: PackedStringArray) -> RefCounted:
	var qa := new()
	for arg: String in args:
		if arg == "--autoplay":
			qa.autoplay = true
		elif arg == "--no-hud-perf":
			qa.show_perf = false
		elif arg.begins_with("--stress="):
			qa.stress = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--seed="):
			qa.seed = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--dominance="):
			qa.dominance = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--learn="):
			qa.learn = arg.get_slice("=", 1)
		elif arg.begins_with("--start-z="):
			qa.start_z = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--density="):
			qa.density = arg.get_slice("=", 1)
		elif arg.begins_with("--ult-at="):
			qa.ult_at = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--act="):
			qa.act = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--cutscene="):
			qa.cutscene = arg.get_slice("=", 1)
		elif arg == "--skip-cutscenes":
			qa.skip_cutscenes = true
		elif arg == "--no-warmup":
			qa.warmup = false
		elif arg.begins_with("--perf="):
			qa.perf = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--perf-warmup="):
			qa.perf_warmup = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--shot="):
			qa.shot = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-delay="):
			qa.shot_delay = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--cam="):
			qa.cam = arg.get_slice("=", 1)
		elif arg.begins_with("--cam-height="):
			qa.cam_height = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--cam-back="):
			qa.cam_back = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--cam-ahead="):
			qa.cam_ahead = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--fov="):
			qa.fov = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--duration="):
			qa.duration = arg.get_slice("=", 1).to_float()
	return qa
