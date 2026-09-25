extends Node
## Small original synthesized chimes; no third-party recordings.

const Synth = preload("res://addons/proto_kit/synth.gd")

var enabled: bool = true
var music_enabled: bool = true
var volume: float = 0.65
var music_player: AudioStreamPlayer

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var ambience := Synth.notes([261.63, 329.63, 392.0, 329.63, 293.66, 349.23, 440.0, 349.23], 0.8, true)
	ambience.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience.loop_end = ambience.data.size() / 2
	music_player.stream = ambience
	music_player.volume_db = -33.0

func configure(settings: Dictionary) -> void:
	enabled = bool(settings.get("sound", true))
	music_enabled = bool(settings.get("music", true))
	volume = float(settings.get("volume", 0.65))
	if not is_instance_valid(music_player):
		return
	if music_enabled and not music_player.playing:
		music_player.play()
	elif not music_enabled:
		music_player.stop()
	music_player.volume_db = linear_to_db(maxf(volume * 0.035, 0.0001))

func play(kind: String) -> void:
	if not enabled:
		return
	var notes: Array = [523.25, 659.25]
	match kind:
		"eat": notes = [392.0, 523.25, 659.25]
		"clean": notes = [880.0, 1174.66, 1396.91]
		"train", "attack": notes = [196.0, 392.0]
		"hatch", "evolve", "victory": notes = [523.25, 659.25, 783.99, 1046.5]
		"sleep": notes = [392.0, 329.63, 261.63]
		"defeat": notes = [329.63, 293.66, 261.63]
		"heal": notes = [659.25, 783.99, 987.77]
	var player := AudioStreamPlayer.new()
	player.stream = Synth.notes(notes, 0.105)
	player.volume_db = linear_to_db(maxf(volume * 0.27, 0.0001))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
