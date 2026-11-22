"""Render the original aquarium score and water effects as loop-ready Ogg files."""
import ctypes as ct
import math
import random
from array import array
from functools import lru_cache
from pathlib import Path

RATE = 22050
BEAT = 60 / 68
TWO_PI = 2 * math.pi
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


class SoundFileInfo(ct.Structure):
    _fields_ = [("frames", ct.c_int64), ("rate", ct.c_int), ("channels", ct.c_int),
                ("format", ct.c_int), ("sections", ct.c_int), ("seekable", ct.c_int)]


def write(name, samples):
    lib = ct.CDLL("libsndfile.so.1")
    lib.sf_open.argtypes = [ct.c_char_p, ct.c_int, ct.POINTER(SoundFileInfo)]
    lib.sf_open.restype = ct.c_void_p
    lib.sf_writef_float.argtypes = [ct.c_void_p, ct.POINTER(ct.c_float), ct.c_int64]
    lib.sf_writef_float.restype = ct.c_int64
    lib.sf_close.argtypes = [ct.c_void_p]
    metadata = SoundFileInfo(0, RATE, 1, 0x200060, 0, 0)  # Ogg/Vorbis
    handle = lib.sf_open(str(OUT / f"{name}.ogg").encode(), 0x20, ct.byref(metadata))
    if not handle:
        raise RuntimeError(f"Could not encode {name}")
    for offset in range(0, len(samples), 4096):
        count = min(4096, len(samples) - offset)
        chunk = (ct.c_float * count).from_buffer(samples, offset * ct.sizeof(ct.c_float))
        if lib.sf_writef_float(handle, chunk, count) != count:
            raise RuntimeError(f"Short write for {name}")
    lib.sf_close(handle)


@lru_cache(maxsize=64)
def key(midi, length, soft=False):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    frames = round(length * RATE)
    sound = array("f")
    for i in range(frames):
        t = i / RATE
        a = min(1, t / (0.065 if soft else 0.016))
        r = min(1, (frames - i) / (0.48 * RATE))
        v = TWO_PI * frequency * t
        fundamental = math.sin(v) + 0.14 * math.sin(v * 2.002) + 0.045 * math.sin(v * 3.03)
        sound.append(fundamental * a * r * math.exp(-t / (2.2 if soft else 0.83)))
    return sound


def layer(target, clip, start, gain):
    for i, value in enumerate(clip):
        target[(start + i) % len(target)] += value * gain


def score():
    bars = 56
    frames = round(bars * 4 * BEAT * RATE)
    bed = array("f", [0]) * frames
    melody = array("f", [0]) * frames
    chords = [
        (48, 55, 62, 64), (45, 55, 59, 64), (41, 53, 57, 64), (43, 55, 57, 62),
        (40, 55, 59, 62), (45, 52, 60, 64), (41, 53, 57, 62), (43, 55, 62, 65),
    ]
    phrases = [
        ((0.5, 67), (1.75, 71), (2.5, 69)),
        ((1.0, 64), (2.5, 67)),
        ((0.75, 69), (2.5, 72), (3.2, 71)),
        ((0.5, 67), (2.5, 62)),
        ((0.5, 64), (1.5, 67), (3.0, 71)),
        ((1.5, 69), (2.5, 67)),
        ((0.5, 65), (2.0, 69), (3.0, 64)),
        ((0.5, 62),),
    ]
    for bar in range(bars):
        chord = chords[bar % 8]
        start = bar * 4 * BEAT
        layer(bed, key(chord[0], 3.2, True), round(start * RATE), 0.105)
        for index, note in enumerate(chord[1:]):
            onset = (start + (0.15, 0.85, 1.9)[index] * BEAT)
            layer(bed, key(note, 2.9, True), round(onset * RATE), 0.10 - index * 0.016)
        if bar % 16 in (0, 7, 11, 15) or bar >= 52:
            continue
        phrase = phrases[bar % 8]
        for onset, note in phrase[::2] if bar >= 28 else phrase:
            layer(melody, key(note, 2.45), round((start + onset * BEAT) * RATE), 0.146)
    write("harmony", bed)
    write("melody", melody)


def drop(duration, pitch, seed):
    rng = random.Random(seed)
    samples = array("f")
    smoothed = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        smoothed += 0.09 * (rng.uniform(-1, 1) - smoothed)
        phase = TWO_PI * pitch * (t + 3.4 * t * t)
        decay = math.exp(-t / (duration * 0.18))
        samples.append(min(1, t * 500) * decay * (math.sin(phase) * 0.38 + smoothed * 0.22))
    return samples


def water():
    rng = random.Random(43)
    size = 24 * RATE
    samples = array("f")
    fast = slow = 0.0
    for i in range(size):
        noise = rng.uniform(-1, 1)
        fast += 0.13 * (noise - fast)
        slow += 0.009 * (noise - slow)
        background = (fast - slow) * 0.19 + slow * 0.26
        edge = min(1, min(i, size - 1 - i) / (RATE * 0.2))
        samples.append(background * edge)
    for start, pitch in [(1.9, 150), (7.28, 212), (12.5, 190), (20.8, 168)]:
        layer(samples, drop(0.31, pitch, pitch), round(start * RATE), 0.12)
    write("water", samples)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    score()
    water()
    write("splash", drop(0.27, 186, 5))
    for index, pitch in enumerate((246, 287, 263), 1):
        write(f"peck{index}", drop(0.125, pitch, index))
    write("panel", drop(0.10, 198, 28))
    for name, notes in [("hatch", (64, 67, 72)), ("moon", (67, 72, 76, 79))]:
        cue = array("f", [0]) * round(1.65 * RATE)
        for i, pitch in enumerate(notes):
            layer(cue, key(pitch, 1.0), round(i * RATE * 0.14), 0.20 - i * 0.022)
        write(name, cue)


if __name__ == "__main__":
    main()
