class_name Settings
extends RefCounted
## Player settings in a ConfigFile. Tests and QA runs pass `-- --settings=<path>` so they never touch the real user://
## (on macOS XDG_DATA_HOME does not move user://).

const DEFAULT_PATH := "user://settings.cfg"

static var path := ""
static var calib_ms := 0.0


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


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("timing", "calib_ms", calib_ms)
	cfg.save(file_path())
