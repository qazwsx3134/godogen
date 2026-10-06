extends "res://addons/proto_kit/sfx_bank.gd"
const Synth = preload("res://addons/proto_kit/synth.gd")
func _ready() -> void:
	_streams = {
		&"punch": Synth.click(0.07, 0.38, 38.0),
		&"hit": mix(Synth.click(0.14, 0.7, 25.0), Synth.ramp(160.0, 55.0, 0.16, 0.6, 0.0)),
		&"metal": mix(Synth.click(0.1, 0.5, 35.0), Synth.ramp(920.0, 230.0, 0.22, 0.4, 0.0)),
		&"launch": mix(Synth.click(0.32, 0.6, 10.0), Synth.ramp(220.0, 32.0, 0.38, 0.8, 0.0)),
		&"hurt": Synth.notes([196.0, 130.0], 0.08),
		&"warning": Synth.notes([659.0, 0.0, 659.0], 0.07),
		&"start": Synth.notes([392.0, 523.0, 784.0], 0.07),
		&"finish": Synth.notes([784.0, 659.0, 523.0, 1046.0], 0.13)
	}
	_streams[&"wave"] = mix(Synth.ramp(620.0, 110.0, 0.24, 0.45, 0.0), Synth.click(0.15, 0.3, 25.0))
	_streams[&"kick"] = mix(Synth.ramp(240.0, 55.0, 0.2, 0.7, 0.0), Synth.click(0.16, 0.55, 22.0))
	_streams[&"level"] = Synth.notes([523.0, 659.0, 784.0, 1046.0], 0.08)
	_streams[&"upgrade"] = Synth.notes([784.0, 1046.0, 1568.0], 0.065)
	_streams[&"combo"] = Synth.notes([880.0, 1175.0], 0.05)
	_streams[&"heavy"] = mix(Synth.ramp(180.0, 38.0, 0.22, 0.8, 0.0), Synth.click(0.17, 0.5, 24.0))
	super()
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
	_streams.clear()
	_resolved.clear()
func mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(maxi(a.data.size(), b.data.size()))
	for offset: int in range(0, bytes.size(), 2):
		var sample: int = (a.data.decode_s16(offset) if offset < a.data.size() else 0) + (b.data.decode_s16(offset) if offset < b.data.size() else 0)
		bytes.encode_s16(offset, clampi(sample, -32767, 32767))
	return Synth.to_stream(bytes)
