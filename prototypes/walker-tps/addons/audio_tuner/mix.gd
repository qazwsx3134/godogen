extends RefCounted
## Call play() in place of an AudioStreamPlayer's play() to apply project offsets.
## Explicit pitch and volume arguments are the gameplay values before mixing.
const CONFIG_PATH := "res://audio_mix.cfg"
const LEGACY_PATH := "res://audio_mix.tres"
const BASE_META := &"_audio_tuner_base"
static var _clips: Dictionary
static var _loaded := false
static var _profile_text := ""
static var _profile_path := ""


static func read_legacy() -> Dictionary:
	if ResourceLoader.exists(LEGACY_PATH):
		var profile := ResourceLoader.load(LEGACY_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if profile != null:
			var clips: Variant = profile.get("clips")
			if clips is Dictionary:
				return clips
	return {}


static func decode(config: ConfigFile) -> Dictionary:
	var clips := {}
	for path in config.get_sections():
		if not path.begins_with("res://"):
			continue
		var pitch := float(config.get_value(path, "pitch", 1.0))
		var gain := float(config.get_value(path, "gain_db", 0.0))
		if is_finite(pitch) and is_finite(gain):
			clips[path] = {"pitch": clampf(pitch, 0.25, 4.0), "gain_db": clampf(gain, -60.0, 12.0)}
	return clips


static func _refresh_profile() -> void:
	if _loaded and not OS.is_debug_build():
		return
	var path := CONFIG_PATH if FileAccess.file_exists(CONFIG_PATH) else LEGACY_PATH
	# Compare contents so the next sound picks up saves within the same second.
	var content := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if _loaded and path == _profile_path and content == _profile_text:
		return
	if path == CONFIG_PATH:
		var config := ConfigFile.new()
		if config.parse(content) != OK:
			return
		_clips = decode(config)
	else:
		_clips = read_legacy()
	_profile_path = path
	_profile_text = content
	_loaded = true


static func play(player: Node, pitch: float = -1.0, gain_db: float = INF) -> void:
	_refresh_profile()
	if not player.has_meta(BASE_META):
		player.set_meta(BASE_META, Vector2(player.pitch_scale, player.volume_db))
	var base: Vector2 = player.get_meta(BASE_META)
	var original_pitch := pitch if pitch > 0.0 else base.x
	var original_gain := gain_db if is_finite(gain_db) else base.y
	var clip: AudioStream = player.stream
	var tuning: Dictionary = _clips.get(clip.resource_path, {}) if clip != null else {}
	player.pitch_scale = original_pitch * float(tuning.get("pitch", 1.0))
	player.volume_db = original_gain + float(tuning.get("gain_db", 0.0))
	player.play()


## play() with a small random spread per call, so repeated shots and footsteps never sound identical.
## pitch / gain_db are the centre values (defaults: the player's own); pitch varies by ±pitch_jitter
## (fraction) and volume by ±db_jitter.
static func play_varied(player: Node, pitch: float = -1.0, gain_db: float = INF, pitch_jitter: float = 0.06, db_jitter: float = 1.5) -> void:
	if not player.has_meta(BASE_META):
		player.set_meta(BASE_META, Vector2(player.pitch_scale, player.volume_db))
	var base: Vector2 = player.get_meta(BASE_META)
	var centre_pitch := pitch if pitch > 0.0 else base.x
	var centre_gain := gain_db if is_finite(gain_db) else base.y
	play(player, centre_pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter)), centre_gain + randf_range(-db_jitter, db_jitter))
