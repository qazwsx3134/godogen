class_name Settings
extends RefCounted
## Player settings in a ConfigFile. Tests and QA runs pass `-- --settings=<path>` so they never touch the real user://
## (on macOS XDG_DATA_HOME does not move user://).
## Volumes are 0..1 per audio bus (default_bus_layout.tres: Music = songs and the dialogue BGM, SFX = hits, chomps,
## buttons, Voice = the characters' lines); apply() sets the buses, and load_all() applies what it loaded.

const DEFAULT_PATH := "user://settings.cfg"
const BUSES := [&"Music", &"SFX", &"Voice"]

static var path := ""
static var calib_ms := 0.0
static var volumes := {&"Music": 1.0, &"SFX": 1.0, &"Voice": 1.0}
static var haptics := true


static func file_path() -> String:
	if path.is_empty():
		path = DEFAULT_PATH
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--settings="):
				path = arg.trim_prefix("--settings=")
	return path


static func load_all() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(file_path()) == OK:
		calib_ms = float(cfg.get_value("timing", "calib_ms", 0.0))
		for bus in BUSES:
			volumes[bus] = clampf(float(cfg.get_value("audio", String(bus), 1.0)), 0.0, 1.0)
		haptics = bool(cfg.get_value("feel", "haptics", true))
	apply()


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("timing", "calib_ms", calib_ms)
	for bus in BUSES:
		cfg.set_value("audio", String(bus), volumes[bus])
	cfg.set_value("feel", "haptics", haptics)
	cfg.save(file_path())


## Sets every bus to its volume (0 mutes it).
static func apply() -> void:
	for bus in BUSES:
		var i := AudioServer.get_bus_index(bus)
		if i < 0:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
