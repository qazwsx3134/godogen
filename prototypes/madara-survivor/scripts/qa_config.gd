extends RefCounted
## QA switches after `--` on the command line:
##   --autoplay        the autopilot plays (recording, soak tests)
##   --stress=<n>      spawn n enemies around the player at once (performance)
##   --seed=<n>        fixed spawn randomness
##   --duration=<s>    shorter run (win at this many seconds)
##   --no-hud-perf     hide the performance line
##   --pitch=<deg> --distance=<m>   try another camera angle / distance
##   --learn=fireball:5,gunbai:3      start with these jutsu at these levels (ids in data/jutsu)
##   --dominance=100                  start with this much Dominance
## On the web the same switches come from the page URL: index.html?stress=400&autoplay&seed=3

var autoplay: bool = false
var stress: int = 0
var seed: int = -1
var duration: float = -1.0
var show_perf: bool = true
var pitch: float = -1.0
var distance: float = -1.0
var learn: String = ""
var dominance: float = -1.0


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
		elif arg.begins_with("--pitch="):
			qa.pitch = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--distance="):
			qa.distance = arg.get_slice("=", 1).to_float()
		elif arg.begins_with("--duration="):
			qa.duration = arg.get_slice("=", 1).to_float()
	return qa
