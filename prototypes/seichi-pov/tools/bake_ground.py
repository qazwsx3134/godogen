#!/usr/bin/env python3
"""Bake the village ground texture from spots/hokage_rock/layout.json.

Production tool only; output spots/hokage_rock/baked/ground_albedo.png is the source file.
Image covers the square `ground.center ± ground.size/2`; row 0 = far side (smallest z).
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPOT = os.path.join(ROOT, "spots", "hokage_rock")
N = 1024


def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    u = np.clip(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
    return np.hypot(px - ax - u * dx, pz - az - u * dz)


def main():
    lay = json.load(open(os.path.join(SPOT, "layout.json")))
    cx, cz = lay["ground"]["center"]
    size = lay["ground"]["size"]
    xs = cx - size / 2 + (np.arange(N) + 0.5) / N * size
    zs = cz - size / 2 + (np.arange(N) + 0.5) / N * size
    X, Z = np.meshgrid(xs, zs)
    rng = np.random.default_rng(3)
    lat = rng.random((40, 40))
    from PIL import Image as _I
    noise = np.asarray(_I.fromarray((lat * 255).astype(np.uint8)).resize((N, N), _I.BICUBIC), np.float32) / 255
    fine = rng.random((N, N)).astype(np.float32)

    grass = np.array([0.36, 0.50, 0.25]) * (0.85 + 0.25 * noise[..., None]) * (0.95 + 0.1 * fine[..., None])
    v = lay["village"]
    inside = ((X > v["x0"]) & (X < v["x1"]) & (Z > v["z0"]) & (Z < v["z1"])).astype(np.float32)
    lot = np.array([0.55, 0.52, 0.42]) * (0.9 + 0.15 * noise[..., None])
    col = grass * (1 - 0.65 * inside[..., None]) + lot * 0.65 * inside[..., None]

    road = np.zeros_like(X)
    for r in lay["roads"]:
        pts = r["pts"]
        for a, b in zip(pts, pts[1:]):
            d = seg_dist(X, Z, a, b)
            road = np.maximum(road, np.clip((r["w"] / 2 + 0.8 - d) / 1.6, 0, 1))
    for p in lay["plazas"]:
        d = np.hypot(X - p["c"][0], Z - p["c"][1])
        road = np.maximum(road, np.clip((p["r"] + 0.8 - d) / 1.6, 0, 1))
    dirt = np.array([0.70, 0.62, 0.48]) * (0.92 + 0.12 * fine[..., None])
    col = col * (1 - road[..., None]) + dirt * road[..., None]
    out = os.path.join(SPOT, "baked", "ground_albedo.png")
    Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)).save(out, optimize=True)
    print("ground ->", out)


if __name__ == "__main__":
    main()
