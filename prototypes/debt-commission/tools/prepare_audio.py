#!/usr/bin/env python3
"""Create the prototype's original, quiet PCM foley and room music. No dependencies."""

from array import array
from pathlib import Path
import math
import random
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"


def write(name, seconds, render):
    frames = array("h")
    for i in range(int(seconds * RATE)):
        sample = max(-1.0, min(1.0, render(i / RATE, seconds)))
        frames.append(round(sample * 32767))
    import sys
    if sys.byteorder != "little":
        frames.byteswap()
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(frames.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rng = random.Random(2709)
    write("paper", 0.25, lambda t, d: rng.uniform(-1, 1) * 0.11 * math.sin(math.pi * t / d) ** 2)

    def knock(t, _duration):
        out = 0.0
        for start in (0.0, 0.18):
            local = t - start
            if local >= 0:
                out += math.sin(math.tau * 185 * local) * math.exp(-42 * local) * 0.44
                out += rng.uniform(-0.06, 0.06) * math.exp(-90 * local)
        return out

    write("knock", 0.45, knock)
    write("step", 0.16, lambda t, d: (math.sin(math.tau * 95 * t) * 0.24 + rng.uniform(-0.05, 0.05)) * math.exp(-36 * t))
    write("stamp", 0.25, lambda t, d: (math.sin(math.tau * 115 * t) * 0.33 + rng.uniform(-0.11, 0.11)) * math.exp(-27 * t))

    # Sparse plucked notes; the loop begins/ends in silence, leaving room for dialogue.
    notes = [(0.6, 293.66), (2.2, 440.0), (3.8, 392.0), (6.0, 329.63),
             (8.0, 293.66), (9.6, 220.0), (12.0, 261.63), (13.8, 293.66)]

    def ambient(t, _duration):
        out = 0.0
        for start, frequency in notes:
            local = t - start
            if 0 <= local < 3.0:
                envelope = min(1.0, local / 0.016) * math.exp(-1.9 * local)
                tone = (math.sin(math.tau * frequency * local)
                        + 0.22 * math.sin(math.tau * frequency * 2 * local)
                        + 0.08 * math.sin(math.tau * frequency * 3 * local))
                out += tone * envelope * 0.1
        return out * min(1.0, max(0.0, (18.0 - t) / 1.5))

    write("ambient", 18.0, ambient)
    print(f"Created five original WAV files in {OUT}")


if __name__ == "__main__":
    main()

