extends RefCounted
## Procedural placeholder audio: 16-bit mono AudioStreamWAV at 22050 Hz, no asset files.
## `const Synth = preload("res://addons/proto_kit/synth.gd")`, then `player.stream = Synth.ramp(...)`.
##
## Web exports play streams in Sample mode, which drops runtime pitch/volume control on the
## player. Bake sweeps into the samples (ramp) instead of animating the player.

const RATE: int = 22050


## A sine sweep from freq_a to freq_b with a volume ramp; curve > 1 steepens the tail.
static func ramp(freq_a: float, freq_b: float, dur: float,
		vol_a: float = 0.5, vol_b: float = 0.5, curve: float = 1.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var fade_len := maxf(1.0, 0.006 * RATE)
	for i in n:
		var t := pow(float(i) / float(n), curve)
		phase += TAU * lerpf(freq_a, freq_b, t) / float(RATE)
		# 6 ms fades at both ends; without them every tone starts and stops with a pop.
		var fade := minf(1.0, minf(float(i), float(n - i)) / fade_len)
		var s := sin(phase) * lerpf(vol_a, vol_b, t) * fade
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return to_stream(data)


## A decaying noise burst for hits and clicks. Seeded, so every call returns the same sound.
static func click(dur: float, vol: float = 0.4, decay: float = 24.0) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260917
	for i in n:
		var t := float(i) / float(RATE)
		var s := rng.randf_range(-1.0, 1.0) * vol * exp(-decay * t)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	return to_stream(data)


## Notes played back to back, each note_dur long, with a fast attack and quadratic decay.
## soft keeps pure sines; otherwise each wave is pushed toward a square for a chiptune edge.
static func notes(freqs: Array, note_dur: float, soft: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	var count: int = int(RATE * note_dur)
	bytes.resize(count * freqs.size() * 2)
	for note_index in freqs.size():
		for sample in count:
			var t: float = float(sample) / RATE
			var envelope: float = minf(t * 90.0, 1.0) * pow(1.0 - float(sample) / count, 2.0)
			var wave: float = sin(TAU * float(freqs[note_index]) * t)
			if not soft:
				wave = wave * 0.65 + signf(wave) * 0.35
			bytes.encode_s16((note_index * count + sample) * 2, int(wave * envelope * 15000.0))
	return to_stream(bytes)


static func to_stream(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
