extends SceneTree
## Renders the chiptune tracks into res://assets/audio/*.wav (a tiny 4-channel tracker: pulse lead, pulse
## harmony, triangle bass, noise drums). Original compositions.
##   godot --headless --path . --script res://tools/render_music.gd

const RATE := 22050

# Each song: bpm, steps per bar (16ths), and per-channel bar strings. Tokens: note (D5, C#6, Bb4), "-" hold, "." rest.
# Melody/harmony tokens are 8ths (each spans 2 steps); bass and drums are 16ths.
const RUN := {
	"bpm": 150.0,
	"lead": [
		"D5 - A4 D5 F5 - E5 D5", "F5 - D5 F5 Bb5 - A5 G5", "G5 - E5 G5 C6 - Bb5 A5", "A5 - - - E5 - C#5 -",
		"D5 - A4 D5 F5 - E5 D5", "F5 - D5 F5 Bb5 - A5 G5", "Bb5 - A5 G5 F5 - E5 D5", "C#5 - E5 - A5 - - -",
		"D6 - - C6 Bb5 - A5 -", "C6 - - Bb5 A5 - G5 -", "A5 - E5 - A5 - C#6 -", "D6 - - - A5 - F5 -",
		"D6 - - C6 Bb5 - A5 -", "C6 - - Bb5 A5 - G5 -", "G5 - Bb5 - D6 - G5 -", "E5 - C#5 - A4 - - -"],
	"harm": [
		"A4 - - - A4 - - -", "D5 - - - D5 - - -", "E5 - - - E5 - - -", "C#5 - - - A4 - - -",
		"A4 - - - A4 - - -", "D5 - - - D5 - - -", "D5 - - - Bb4 - - -", "A4 - C#5 - E5 - - -",
		"F5 - - - F5 - - -", "G5 - - - E5 - - -", "E5 - - - C#5 - - -", "F5 - - - D5 - - -",
		"F5 - - - F5 - - -", "G5 - - - E5 - - -", "D5 - - - Bb4 - - -", "C#5 - - - A4 - - -"],
	"bass": ["D", "Bb", "C", "A", "D", "Bb", "G", "A", "Bb", "C", "A", "D", "Bb", "C", "G", "A"],
	"drum": "K.hhS.hhK.hKS.hh",
}
const BOSS := {
	"bpm": 168.0,
	"lead": [
		"E5 - - E5 G5 - F#5 E5", "B5 - - - A5 - G5 -", "C6 - B5 A5 G5 - E5 -", "F#5 - - - D#5 - B4 -",
		"E5 - - E5 G5 - F#5 E5", "B5 - - - D6 - C6 B5", "C6 - B5 A5 B5 - G5 -", "F#5 - D#5 - B4 - - -"],
	"harm": [
		"B4 - - - B4 - - -", "E5 - - - E5 - - -", "E5 - - - C5 - - -", "D#5 - - - B4 - - -",
		"B4 - - - B4 - - -", "E5 - - - G5 - - -", "E5 - - - D5 - - -", "D#5 - B4 - F#4 - - -"],
	"bass": ["E", "E", "C", "B", "E", "E", "C", "B"],
	"drum": "K.KhS.hKK.hKS.SS",
}
const END := {
	"bpm": 112.0,
	"lead": [
		"D5 - F#5 - A5 - - -", "B5 - A5 - F#5 - - -", "G5 - B5 - D6 - - -", "C#6 - - - A5 - - -",
		"D6 - - C#6 B5 - A5 -", "G5 - - F#5 E5 - D5 -", "E5 - - - A5 - C#6 -", "D6 - - - - - - -"],
	"harm": [
		"A4 - - - - - - -", "F#4 - - - - - - -", "B4 - - - - - - -", "A4 - - - E5 - - -",
		"F#5 - - - - - - -", "B4 - - - - - - -", "C#5 - - - - - - -", "F#5 - - - - - - -"],
	"bass": ["D", "B", "G", "A", "D", "G", "A", "D"],
	"drum": "K.h.S.h.K.h.S.hh",
}
const SEMI := {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7,
	"G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


func _initialize() -> void:
	_save(RUN, "res://assets/audio/bgm_run.wav")
	_save(BOSS, "res://assets/audio/bgm_boss.wav")
	_save(END, "res://assets/audio/bgm_end.wav")
	quit(0)


func _freq(token: String) -> float:
	var octave := int(token.right(1))
	var semi: int = SEMI[token.left(token.length() - 1)]
	return 440.0 * pow(2.0, (semi - 9 + (octave - 4) * 12) / 12.0)


## Expand bar strings of 8th tokens into one note (freq, start step, length in steps) list.
func _line(bars: Array) -> Array:
	var out := []
	var step := 0
	for bar in bars:
		for token in (bar as String).split(" ", false):
			if token == "-":
				if not out.is_empty() and out[-1][1] + out[-1][2] == step:
					out[-1][2] += 2
			elif token != ".":
				out.append([_freq(token), step, 2])
			step += 2
	return out


func _save(song: Dictionary, path: String) -> void:
	var bars: int = song.lead.size()
	var step_len: float = 60.0 / song.bpm / 4.0
	var steps := bars * 16
	var n := int(steps * step_len * RATE)
	var mix := PackedFloat32Array()
	mix.resize(n)
	_voice(mix, _line(song.lead), step_len, 0.25, 0.20, 0.0)
	_voice(mix, _line(song.harm), step_len, 0.5, 0.09, 0.0)
	var bass := []
	for b in bars:  # galloping bass: long-short-short on the bar's root, octave 2/3
		var f := _freq(song.bass[b] + "2")
		for s in [0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15]:
			bass.append([f * (2.0 if s % 8 == 4 else 1.0), b * 16 + s, 1])
	_voice(mix, bass, step_len, -1.0, 0.22, 0.0)
	var noise := RandomNumberGenerator.new()
	noise.seed = 1014
	for s in steps:
		var hit: String = song.drum[s % 16]
		if hit == ".":
			continue
		var start := int(s * step_len * RATE)
		var dur := int((0.12 if hit == "K" else 0.09 if hit == "S" else 0.03) * RATE)
		for i in dur:
			if start + i >= n:
				break
			var t := float(i) / RATE
			var v := 0.0
			if hit == "K":
				v = sin(TAU * (110.0 - 600.0 * t) * t) * exp(-28.0 * t) * 0.45
			elif hit == "S":
				v = noise.randf_range(-1.0, 1.0) * exp(-30.0 * t) * 0.22
			else:
				v = noise.randf_range(-1.0, 1.0) * exp(-90.0 * t) * 0.08
			mix[start + i] += v
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(tanh(mix[i] * 1.2), -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := stream.save_to_wav(path)
	print("%s  %.1fs  err=%d" % [path, n / float(RATE), err])


## duty < 0 = triangle. Notes: [freq, start step, length steps].
func _voice(mix: PackedFloat32Array, notes: Array, step_len: float, duty: float, vol: float, _pan: float) -> void:
	for note in notes:
		var f: float = note[0]
		var start := int(note[1] * step_len * RATE)
		var length := int(note[2] * step_len * RATE * 0.92)
		var phase := 0.0
		for i in length:
			if start + i >= mix.size():
				break
			phase = fmod(phase + f / RATE, 1.0)
			var w := 0.0
			if duty < 0.0:
				w = 4.0 * absf(phase - 0.5) - 1.0
			else:
				w = 1.0 if phase < duty else -1.0
			var t := float(i) / RATE
			var env := minf(1.0, t * 200.0) * (0.55 + 0.45 * exp(-6.0 * t)) * minf(1.0, float(length - i) / (0.01 * RATE))
			mix[start + i] += w * env * vol
