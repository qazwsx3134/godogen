#!/usr/bin/env python3
"""Bakes the placeholder songs and sound effects into WAV files (offline, deterministic).

    python3 tools/bake_music.py            # from prototypes/kagura-dango

Songs read data/songs/<id>.json, the same chart the game reads: the cue sounds (Gintoki's tosses) are mixed into
the track at their beats, so the web build has no per-frame jitter on them. The player's own chomp is played live.
Replacing a song later: drop a real recording in assets/music/ and set "bpm"/"offset" in its JSON.
"""
import json, pathlib, wave
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
SR = 44100
rng = np.random.default_rng(66)


def env(n, attack=0.004, decay=12.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / attack) if attack > 0 else np.ones(n)
    return a * np.exp(-decay * t)


def tone(freq, dur, decay=10.0, shape="sine", f_end=None):
    n = int(dur * SR)
    f = np.full(n, float(freq)) if f_end is None else np.geomspace(freq, f_end, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    w = np.sin(ph) if shape == "sine" else np.sign(np.sin(ph)) * 0.6 if shape == "square" else 2 * (ph / (2 * np.pi) % 1) - 1
    return w * env(n, decay=decay)


def noise(dur, decay=30.0):
    n = int(dur * SR)
    return rng.uniform(-1, 1, n) * env(n, attack=0.001, decay=decay)


SOUNDS = {
    "kick": lambda: tone(110, 0.25, 14, f_end=40) * 0.9,
    "snare": lambda: mix(noise(0.18, 22) * 0.45, tone(190, 0.12, 25) * 0.25),
    "hat": lambda: np.diff(noise(0.05, 70), prepend=0) * 0.35,
    "cowbell": lambda: mix(tone(800, 0.25, 14, "square"), tone(540, 0.25, 14, "square")) * 0.35,
    "count": lambda: tone(1200, 0.08, 40) * 0.5,
    # Gintoki throws: a wooden "pok" with a rising whistle. quick = two short high pips, big = low and long.
    "toss": lambda: mix(tone(520, 0.07, 45, "square") * 0.5, tone(700, 0.35, 8, f_end=1400) * 0.35),
    "quick": lambda: _cat(tone(1300, 0.05, 50) * 0.5, np.zeros(int(0.03 * SR)), tone(1700, 0.2, 14, f_end=2600) * 0.45),
    # Round 1 flavours, one pitch per person: low = Gintoki (left), middle = Shinpachi, high = Kagura (right).
    "anko": lambda: mix(tone(196, 0.09, 30, "square") * 0.55, tone(262, 0.3, 9, f_end=330) * 0.35),
    "soy": lambda: mix(tone(392, 0.09, 30, "square") * 0.5, tone(523, 0.3, 9, f_end=659) * 0.33),
    "tri": lambda: mix(tone(784, 0.09, 30, "square") * 0.45, tone(1047, 0.3, 9, f_end=1319) * 0.3),
    "clap": lambda: noise(0.09, 35) * 0.3,
    # round 2: Gintoki kicks a rival (low), Shinpachi packs a bento (middle), Kagura rice / dango (high)
    "rival": lambda: mix(tone(150, 0.12, 25, "square") * 0.6, noise(0.08, 40) * 0.3),
    "bento": lambda: mix(tone(392, 0.06, 45, "square") * 0.5, tone(330, 0.06, 45, "square") * 0.4),
    "rice": lambda: tone(988, 0.12, 30) * 0.5,
    "dango": lambda: mix(tone(784, 0.09, 30, "square") * 0.45, tone(1047, 0.3, 9, f_end=1319) * 0.3),
    "big": lambda: mix(tone(260, 0.12, 25, "square") * 0.55, tone(330, 0.7, 4, f_end=880) * 0.4),
    # live sound effects
    "chomp": lambda: mix(noise(0.06, 60) * 0.6, tone(300, 0.09, 30, "square", f_end=160) * 0.45),
    "miss": lambda: tone(420, 0.35, 6, "saw", f_end=180) * 0.35,
    "whiff": lambda: noise(0.08, 40) * 0.25,
    "ui": lambda: tone(880, 0.06, 40) * 0.4,
}


def _cat(*parts):
    return np.concatenate(parts)


def mix(*parts):
    out = np.zeros(max(len(x) for x in parts))
    for x in parts:
        out[: len(x)] += x
    return out


def add(buf, sound, at):
    i = int(round(at * SR))
    if i < 0 or i >= len(buf):
        return
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[: end - i]


# Japanese "yo" pentatonic (D E G A B) in two octaves, a tune that loops every 2 bars
MELODY = [74, 76, 79, 81, 79, 76, 74, None, 76, 79, 81, 83, 81, 79, 76, None]
BASS = [50, 50, 55, 55, 57, 57, 55, 52]


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def bake_song(chart, band=True):
    global rng
    rng = np.random.default_rng(66)  # same drums on every bake of a song
    spb = 60.0 / chart["bpm"]
    total = chart["offset"] + (chart["end_beat"] + 4) * spb
    buf = np.zeros(int(total * SR))
    s = {k: f() for k, f in SOUNDS.items()}
    beats = int(chart["end_beat"]) + 4
    count_in = chart["count_in_beats"]
    level = chart.get("intensity", 1)  # 1..3: each round adds layers
    for b in range(beats):
        t = chart["offset"] + b * spb
        if not band:
            add(buf, s["cowbell"], t)
            continue
        if b < count_in:
            add(buf, s["hat"], t)
            if b >= count_in - 4:
                add(buf, s["count"], t)
            continue
        if b >= chart["end_beat"]:
            if b == chart["end_beat"]:
                add(buf, s["kick"], t)
                add(buf, tone(midi(74), 1.2, 3) * 0.3, t)
            continue
        add(buf, s["kick"] if b % 2 == 0 else s["snare"], t)
        add(buf, s["hat"], t)
        add(buf, s["hat"] * 0.6, t + spb / 2)
        add(buf, tone(midi(BASS[(b // 2) % len(BASS)] - 12), spb * 0.9, 5, "saw") * 0.22, t)
        if level >= 2:  # melody
            for half in range(2):
                n = MELODY[((b - count_in) * 2 + half) % len(MELODY)]
                if n is not None:
                    add(buf, tone(midi(n), spb * 0.45, 9, "square") * 0.10, t + half * spb / 2)
        else:  # round 1: a softer, sparser tune
            n = MELODY[((b - count_in) * 2) % len(MELODY)]
            if n is not None and b % 2 == 0:
                add(buf, tone(midi(n), spb * 0.9, 6) * 0.10, t)
        if level >= 3:  # fever: 16th hats, claps on the off-beats, a lead an octave up, kick doubled
            for q in (0.25, 0.75):
                add(buf, s["hat"] * 0.4, t + q * spb)
            add(buf, s["clap"], t + spb / 2)
            if b % 2 == 1:
                add(buf, s["kick"] * 0.7, t + spb / 2)
            n = MELODY[((b - count_in) * 2 + 1) % len(MELODY)]
            if n is not None:
                add(buf, tone(midi(n + 12), spb * 0.3, 12, "square") * 0.06, t + spb / 2)
    for cue in chart["cues"]:
        add(buf, s[cue["type"]], chart["offset"] + cue["beat"] * spb)
    return buf


def write_wav(path, buf):
    peak = max(1e-9, np.max(np.abs(buf)))
    data = (np.clip(buf / max(peak, 1.0) * 0.9, -1, 1) * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"wrote {path.relative_to(ROOT)}  {len(buf) / SR:.2f} s")


def main():
    # Rounds play the user's songs (mp3) with no cue sounds: the notes are on the song's own beats.
    write_wav(ROOT / "assets/music/calibrate.wav", bake_song(json.loads((ROOT / "data/songs/calibrate.json").read_text()), band=False))
    for name in ("chomp", "miss", "whiff", "ui"):
        write_wav(ROOT / f"assets/sfx/{name}.wav", SOUNDS[name]())


if __name__ == "__main__":
    main()
