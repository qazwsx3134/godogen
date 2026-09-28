extends Node
## Stage effects the story asks for: shake, flash, cut-in, freeze, background music and sound
## effects (`shake`/`flash`/`cutin`/`freeze`/`bgm`/`se` steps). main.gd hands each step over while
## it drives the story; only freeze makes the story wait. None of them takes input.
## The catalog's sounds and music are labels until real files get a `path`; until then each id
## plays a synthesized placeholder.

const Synth = preload("res://addons/proto_kit/synth.gd")
const CUTIN_SCENE: PackedScene = preload("res://scenes/ui/cutin.tscn")
const BGM_DB: float = -14.0
const SHAKE: Dictionary = {"small": [10.0, 0.25], "big": [28.0, 0.45]}
const GREY_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
void fragment() {
	vec3 below = texture(screen_tex, SCREEN_UV).rgb;
	float grey = dot(below, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(grey * 0.85), 1.0);
}
"""

## The music id playing now ("" = none); saves keep it.
var current_bgm: String = ""

var _shake_layers: Array[Control] = []
var _overlay: Control = null
var _catalog: Dictionary = {}
var _names: Dictionary = {}
var _style_id: String = "cinema"
var _muted: bool = false
## Music and sound levels 0–1 from the settings; 0 is silent.
var _bgm_level: float = 1.0
var _se_level: float = 1.0
var _se_player: AudioStreamPlayer = null
var _bgm_player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var _shake_tween: Tween = null


## shake_layers move together on a shake; overlay holds the flash, the freeze and cut-ins.
func setup(shake_layers: Array[Control], overlay: Control, catalog: Dictionary) -> void:
	_shake_layers = shake_layers
	_overlay = overlay
	_catalog = catalog
	for actor_id: String in (catalog.get("characters", {}) as Dictionary).keys():
		_names[actor_id] = str(catalog["characters"][actor_id].get("name", actor_id))
	_se_player = AudioStreamPlayer.new()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.volume_db = BGM_DB
	add_child(_se_player)
	add_child(_bgm_player)


func set_style(style_id: String) -> void:
	_style_id = style_id


## Muting stops the players instead of turning them down: Web exports play in Sample mode,
## which ignores volume changes on a playing stream.
func set_muted(muted: bool) -> void:
	_muted = muted
	_se_player.stop()
	_bgm_player.stop()
	if not muted and not current_bgm.is_empty() and _bgm_level > 0.0:
		_bgm_player.stream = _stream("music", current_bgm)
		_bgm_player.play()


## Levels 0–1 from the settings. Like muting, a change restarts the music: Sample mode ignores
## volume changes on a playing stream.
func set_volumes(bgm: float, se: float) -> void:
	_bgm_level = bgm
	_se_level = se
	_bgm_player.volume_db = BGM_DB + linear_to_db(maxf(bgm, 0.0001))
	_se_player.volume_db = linear_to_db(maxf(se, 0.0001))
	set_muted(_muted)


## Plays one effect step. While skipping only the music changes. Returns how long the story
## should hold (freeze), else 0.
func play(step: Dictionary, skipping: bool) -> float:
	var op: String = str(step.get("op", ""))
	if op == "bgm":
		play_bgm(str(step.get("id", "")))
		return 0.0
	if skipping:
		return 0.0
	match op:
		"se":
			_play_se(str(step.get("id", "")))
		"shake":
			var spec: Array = SHAKE[str(step.get("strength", "small"))]
			_shake(spec[0], float(step.get("duration", spec[1])))
		"flash":
			_flash(Color(str(step.get("color", "#ffffff"))), float(step.get("duration", 0.3)))
		"cutin":
			var cutin: Control = CUTIN_SCENE.instantiate() as Control
			cutin.set("style_id", _style_id)
			_overlay.add_child(cutin)
			cutin.call("play", str(step.get("text", "")), _speaker_name(str(step.get("speaker", ""))))
		"freeze":
			var hold: float = float(step.get("duration", 0.8))
			_freeze(hold)
			return hold
	return 0.0


func play_bgm(id: String) -> void:
	if id == current_bgm:
		return
	current_bgm = id
	_bgm_player.stop()
	if not id.is_empty() and not _muted and _bgm_level > 0.0:
		_bgm_player.stream = _stream("music", id)
		_bgm_player.play()


func _play_se(id: String) -> void:
	if _muted or _se_level <= 0.0:
		return
	_se_player.stream = _stream("sounds", id)
	_se_player.play()


func _shake(strength: float, duration: float) -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = maxi(4, int(duration / 0.035))
	for index: int in range(steps):
		var fade: float = 1.0 - float(index) / steps
		var offset: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade
		_shake_tween.tween_callback(_offset_layers.bind(offset))
		_shake_tween.tween_interval(duration / steps)
	_shake_tween.tween_callback(_offset_layers.bind(Vector2.ZERO))


func _offset_layers(offset: Vector2) -> void:
	for layer: Control in _shake_layers:
		layer.position = offset


func _flash(color: Color, duration: float) -> void:
	var rect: ColorRect = _full_rect(ColorRect.new())
	rect.color = color
	var tween: Tween = rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, duration).from(0.85)
	tween.tween_callback(rect.queue_free)


## The screen greys out and holds (the story waits the same time).
func _freeze(hold: float) -> void:
	var rect: ColorRect = _full_rect(ColorRect.new())
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = GREY_SHADER
	rect.material = material
	var tween: Tween = rect.create_tween()
	tween.tween_interval(hold)
	tween.tween_property(rect, "modulate:a", 0.0, 0.15)
	tween.tween_callback(rect.queue_free)


func _full_rect(rect: Control) -> Control:
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(rect)
	_overlay.move_child(rect, 0)  # cut-ins stay on top
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _speaker_name(speaker: String) -> String:
	var names: PackedStringArray = []
	for actor_id: String in speaker.split("+", false):
		names.append(str(_names.get(actor_id, actor_id)))
	return "・".join(names)


## The catalog file when the id has a `path`, else a synthesized placeholder.
func _stream(collection: String, id: String) -> AudioStream:
	var key: String = collection + "/" + id
	if _streams.has(key):
		return _streams[key]
	var path: String = str(((_catalog.get(collection, {}) as Dictionary).get(id, {}) as Dictionary).get("path", ""))
	var stream: AudioStream = load(path) as AudioStream if not path.is_empty() and ResourceLoader.exists(path) else null
	if stream == null:
		stream = _placeholder(collection, id)
	_streams[key] = stream
	return stream


# ponytail: one synth recipe per catalog id; replace by giving the id a `path` in the catalog.
func _placeholder(collection: String, id: String) -> AudioStream:
	if collection == "music":
		var motifs: Dictionary = {
			"bgm_daily": [392, 440, 494, 440], "bgm_meeting": [330, 392, 330, 294],
			"bgm_boke": [440, 523, 440, 392], "bgm_combo": [523, 587, 659, 784],
			"bgm_serious": [220, 208, 196, 208], "bgm_result": [523, 659, 784, 1047],
		}
		var loop: AudioStreamWAV = Synth.notes(motifs.get(id, [392, 330]), 0.32, true)
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = loop.data.size() / 2
		return loop
	match id:
		"crow":
			return Synth.ramp(760.0, 430.0, 0.32, 0.45, 0.0, 1.6)
		"tsukkomi_hit", "bite":
			return Synth.click(0.14, 0.7, 18.0)
		"glass_crack":
			return Synth.ramp(3200.0, 1400.0, 0.16, 0.4, 0.0, 2.0)
		"glass_shatter", "tear", "door_slide":
			return Synth.click(0.4, 0.5, 7.0)
		"censor_beep":
			return Synth.ramp(1000.0, 1000.0, 0.3, 0.3, 0.3)
		"qte_hit":
			return Synth.ramp(1200.0, 1900.0, 0.1, 0.5, 0.2)
		"combo_up":
			return Synth.notes([660, 880, 1320], 0.07)
		"combo_break":
			return Synth.ramp(520.0, 170.0, 0.3, 0.45, 0.0)
		"super_charge":
			return Synth.ramp(220.0, 1700.0, 0.6, 0.2, 0.5)
		"gulp":
			return Synth.ramp(320.0, 150.0, 0.15, 0.5, 0.0)
		_:
			return Synth.ramp(90.0, 70.0, 0.4, 0.3, 0.05)
