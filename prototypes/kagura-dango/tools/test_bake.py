#!/usr/bin/env python3
"""The baked cue sounds sit exactly on their chart beats: bake toss with and without cues; adding each cue alone starts
its sound within 2 ms of its beat and is silent everywhere else.   python3 tools/test_bake.py"""
import json, pathlib, sys
import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import bake_music as bm

fail = 0
total = 0
for path in sorted((bm.ROOT / "data/songs").glob("*.json")):
    chart = json.loads(path.read_text())
    if not chart["cues"]:
        continue
    with_cues = bm.bake_song(chart)
    without = bm.bake_song({**chart, "cues": []})
    diff = np.abs(with_cues - without)
    spb = 60.0 / chart["bpm"]
    covered = np.zeros(len(diff), bool)
    cues = chart["cues"]
    for k, cue in enumerate(cues):
        at = chart["offset"] + cue["beat"] * spb
        i = int(round(at * bm.SR))
        step = np.abs(bm.bake_song({**chart, "cues": cues[: k + 1]}) - bm.bake_song({**chart, "cues": cues[:k]}))
        onset = i + int(np.argmax(step[i - 200 : i + 2000] > 1e-4)) - 200
        if abs(onset - i) > 0.002 * bm.SR:
            print(f"FAIL {chart['id']} cue at beat {cue['beat']}: sound starts {(onset - i) / bm.SR * 1000:.1f} ms off")
            fail += 1
        covered[i : i + int(0.8 * bm.SR)] = True
    stray = np.max(diff[~covered]) if (~covered).any() else 0.0
    if stray > 1e-6:
        print(f"FAIL cue sound outside any cue window (peak {stray:.4f})")
        fail += 1

    total += len(chart["cues"])
print("BAKE TESTS FAILED" if fail else f"BAKE TESTS PASSED ({total} cues in every chart)")
sys.exit(1 if fail else 0)
