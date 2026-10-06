extends RefCounted
## Player settings (ConfigFile [settings]): each is an index into its list of choices, which is
## also the button's position in its row of scenes/ui/settings_panel.tscn. The defaults are the
## speeds and volumes the game had before settings existed.

## Seconds per character; 0 shows the whole line at once.
const TEXT_INTERVALS: Array[float] = [0.06, 0.032, 0.016, 0.0]
## Multiplies the auto-play wait.
const AUTO_FACTORS: Array[float] = [1.6, 1.0, 0.5]
const VOLUMES: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const FONT_SCALES: Array[float] = [0.85, 1.0, 1.2]
const PAPER_OPACITIES: Array[float] = [0.65, 0.82, 1.0]
const DEFAULTS: Dictionary = {"text_speed": 1, "auto_speed": 1, "bgm_volume": 4, "se_volume": 4, "font_size": 1, "paper_opacity": 2}
const SIZES: Dictionary = {"text_speed": 4, "auto_speed": 3, "bgm_volume": 5, "se_volume": 5, "font_size": 3, "paper_opacity": 3}


static func load_settings(path: String) -> Dictionary:
	var values: Dictionary = DEFAULTS.duplicate()
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK:
		return values
	for key: String in DEFAULTS.keys():
		var value: Variant = config.get_value("settings", key, DEFAULTS[key])
		if typeof(value) == TYPE_INT and int(value) >= 0 and int(value) < int(SIZES[key]):
			values[key] = int(value)
	return values


static func save_settings(path: String, values: Dictionary) -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: String in DEFAULTS.keys():
		config.set_value("settings", key, int(values.get(key, DEFAULTS[key])))
	return config.save(path)
