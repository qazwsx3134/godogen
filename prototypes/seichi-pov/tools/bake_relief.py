#!/usr/bin/env python3
"""Bake the Hokage Rock cliff: relief heightfield -> cliff.obj + textures + cliff_top.json.

Production tool only. The game never runs this; its outputs under spots/hokage_rock/baked/
are the maintained source files. Re-running overwrites them, so diff before committing.

    python3 tools/bake_relief.py            # full bake
    python3 tools/bake_relief.py --preview  # fast shaded preview PNG only (art iteration)

Coordinates (metres): cliff face plane z=0 facing +z, x right, y up, ground y=0.
The relief grid is parameterised by (x, v): v climbs the face, then folds back over the
cliff top (ytop) into a plateau, so one texture covers face + top edge.
"""
import argparse
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "spots", "hokage_rock", "baked")
PREVIEW = os.path.join(ROOT, "art_src", "relief_preview.png")

# Relief (high-res textured) span and the wings (tiling rock) beyond it.
RX = 150.0              # relief covers x in [-RX, RX]
WING_X = 430.0          # cliff ends at |x| = WING_X
VMAX = 172.0            # v range: face + top fold + plateau
TILE_M = 16.0           # world metres per rock tile repeat
TEX_W, TEX_H = 4096, 2048
STEP_X_CENTER, STEP_X_WING, STEP_V = 1.5, 7.0, 1.5
FOLD_R = 4.0            # top edge bevel radius

# Faces left -> right as seen from the village: 1st..4th Hokage (Part I rock).
R = 21.0
FACES = [
    {"kind": "hashirama", "cx": -78.0, "cy": 78.0},
    {"kind": "tobirama", "cx": -26.0, "cy": 78.0},
    {"kind": "hiruzen", "cx": 26.0, "cy": 78.0},
    {"kind": "minato", "cx": 78.0, "cy": 78.0},
]

RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- shared shape functions
def ytop(x):
    """Cliff top height along x (array ok). Faces sit below ~117 m."""
    ax = np.abs(x)
    base = np.where(ax < 120, 114.0,
           np.where(ax < 300, 114.0 - 50.0 * smooth((ax - 120) / 180),
                    64.0 - 64.0 * smooth((ax - 300) / 130)))
    wob = 3.0 * np.sin(x * 0.045 + 1.3) + 1.6 * np.sin(x * 0.13 + 0.4)
    wob = wob + smooth((ax - 130) / 60) * (9.0 * np.sin(x * 0.027 + 0.7) + 5.0 * np.sin(x * 0.071 + 2.1))
    return np.maximum(base + wob * np.clip(base / 40.0, 0, 1), 0.0)


def zbase(x):
    """Wings curve toward the village so the cliff wraps the valley."""
    ax = np.abs(x)
    return np.where(ax < 180, 0.0, ((ax - 180) / 250.0) ** 2 * 60.0)


def smooth(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def value_noise_periodic(n, cells, seed):
    """Periodic 2D value noise on an n x n grid with `cells` lattice cells per side."""
    rng = np.random.default_rng(seed)
    lat = rng.random((cells, cells))
    coords = np.arange(n) / n * cells
    i0 = np.floor(coords).astype(int)
    f = smooth(coords - i0)
    i1 = (i0 + 1) % cells
    a = lat[np.ix_(i0, i0)]
    b = lat[np.ix_(i0, i1)]
    c = lat[np.ix_(i1, i0)]
    d = lat[np.ix_(i1, i1)]
    fy, fx = f[:, None], f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def noise_lo(x, v):
    """Low-frequency rock undulation baked into geometry (both relief and wings)."""
    return (1.6 * np.sin(x * 0.11 + np.sin(v * 0.05) * 2.0) * np.sin(v * 0.07 + 0.8)
            + 0.9 * np.sin(x * 0.031 + v * 0.023 + 2.0)
            + 0.7 * np.sin(v * 0.21 + x * 0.013))


def box_blur(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis, dtype=np.float64)
    hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
    lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def gauss_blur(a, sigma_px_x, sigma_px_y):
    out = a
    for _ in range(3):
        out = box_blur(out, int(round(sigma_px_x * 0.58)), 1)
        out = box_blur(out, int(round(sigma_px_y * 0.58)), 0)
    return out


# ---------------------------------------------------------------- faces
def g(s, t, s0, t0, ss, st):
    return np.exp(-(((s - s0) / ss) ** 2) - (((t - t0) / st) ** 2))


def ell(s, t, a, b):
    return np.sqrt(np.clip(1.0 - (s / a) ** 2 - (t / b) ** 2, 0.0, 1.0))


def sstep(edge0, edge1, x):
    return smooth((x - edge0) / (edge1 - edge0))


def tri_wave(x):
    """0 at integers, 1 at half-integers."""
    return 1.0 - np.abs((x % 1.0) * 2.0 - 1.0)


def line_mask(s, t, s0, t0, s1, t1, width):
    """Soft stroke from (s0,t0) to (s1,t1)."""
    ds, dt = s1 - s0, t1 - t0
    L2 = ds * ds + dt * dt
    u = np.clip(((s - s0) * ds + (t - t0) * dt) / L2, 0, 1)
    d2 = (s - s0 - u * ds) ** 2 + (t - t0 - u * dt) ** 2
    return np.exp(-d2 / (width * width))


STYLE = {
    #            jaw   brow_k mouth_curve cheek  age
    "hashirama": (0.10, -0.15, 0.15, 0.03, 0.0),
    "tobirama":  (0.18, 0.55, -0.35, 0.05, 0.0),
    "hiruzen":   (0.08, 0.05, 0.05, 0.05, 1.0),
    "minato":    (0.34, -0.05, 0.30, 0.02, 0.0),
}


def face_height(kind, s, t):
    """Face + hair relief in units of R (protrusion toward +z)."""
    jaw, brow_k, curve, cheek, age = STYLE[kind]
    a_t = 0.74 * (1.0 - jaw * np.clip(-t - 0.05, 0, 1) ** 1.2)
    face = 0.40 * ell(s, t + 0.02, a_t, 1.0) ** 0.6
    inside = sstep(0.0, 0.25, ell(s, t + 0.02, a_t, 1.0))

    f = np.zeros_like(s)
    f -= 0.06 * (g(s, t, 0.29, 0.10, 0.17, 0.09) + g(s, t, -0.29, 0.10, 0.17, 0.09))
    # almond eyes: carved upper lid groove + lower lid line
    for sx in (-0.29, 0.29):
        f -= 0.05 * line_mask(s, t, sx - 0.13, 0.08, sx + 0.13, 0.08, 0.03)
        f += 0.02 * g(s, t, sx, 0.065, 0.08, 0.035)
    # brows: inner end lowered by brow_k (stern) or raised (gentle)
    for sign in (-1, 1):
        f += 0.06 * line_mask(s, t, sign * 0.13, 0.22 - 0.08 * brow_k, sign * 0.46, 0.27 + 0.04 * brow_k, 0.04)
    # nose bridge + tip + nostrils
    bridge = np.clip((0.22 - t) / 0.44, 0, 1) ** 1.1 * (t > -0.24)
    f += 0.13 * bridge * np.exp(-((s / 0.07) ** 2))
    f += 0.06 * g(s, t, 0, -0.21, 0.10, 0.07)
    f -= 0.025 * (g(s, t, 0.07, -0.27, 0.035, 0.03) + g(s, t, -0.07, -0.27, 0.035, 0.03))
    # mouth groove + lips + chin
    tm = -0.47 + curve * s * s
    f -= 0.045 * np.exp(-(((t - tm) / 0.022) ** 2)) * np.clip(1 - (s / 0.21) ** 2, 0, 1)
    f += 0.025 * g(s, t, 0, -0.51, 0.16, 0.04)
    f += 0.05 * g(s, t, 0, -0.80, 0.20, 0.12)
    f += cheek * (g(s, t, 0.43, -0.08, 0.14, 0.12) + g(s, t, -0.43, -0.08, 0.14, 0.12))
    # ears
    ears = 0.20 * (g(s, t, 0.79, 0.02, 0.07, 0.17) + g(s, t, -0.79, 0.02, 0.07, 0.17))
    if age > 0:
        for tl in (0.40, 0.47, 0.54):
            f -= 0.014 * age * np.exp(-(((t - tl - 0.03 * np.cos(s * 6)) / 0.012) ** 2)) * np.clip(1 - (s / 0.38) ** 2, 0, 1)
        for sign in (-1, 1):
            f -= 0.03 * age * line_mask(s, t, sign * 0.13, -0.22, sign * 0.27, -0.50, 0.02)
            f -= 0.015 * age * line_mask(s, t, sign * 0.20, -0.02, sign * 0.40, 0.02, 0.015)
            f -= 0.012 * age * line_mask(s, t, sign * 0.43, 0.10, sign * 0.53, 0.04, 0.012)
    face_total = face + f * inside + ears

    hair = np.zeros_like(s)
    if kind == "hashirama":
        # long straight hair, centre part, falling past the jaw on both sides
        crown = 0.48 * ell(s, t - 0.18, 1.06, 1.02) ** 0.5
        hairline = 0.60 + 0.12 * np.clip(0.3 - np.abs(s), 0, 1) - 0.30 * np.clip(np.abs(s) - 0.35, 0, 1)
        crown_mask = sstep(hairline - 0.02, hairline + 0.04, t)
        outer = 1.06 + 0.16 * np.clip(-t, 0, 1.5)
        side = (sstep(0.66, 0.72, np.abs(s)) * (1 - sstep(outer - 0.06, outer, np.abs(s)))
                * sstep(-1.55, -1.25, t) * (1 - sstep(0.75, 0.95, t)))
        side_h = (0.36 - 0.06 * np.clip(-t, 0, 1.5)) * side
        strands = 1 + 0.10 * np.sin(s * 70 + np.sin(t * 9) * 0.6)
        hair = np.maximum(crown * crown_mask, side_h) * strands
        hair -= 0.08 * np.exp(-((s / 0.035) ** 2)) * (t > 0.55) * crown_mask   # centre part
    elif kind in ("tobirama", "hiruzen"):
        tall = 0.30 if kind == "tobirama" else 0.18
        n = 3.0 if kind == "tobirama" else 4.0
        top = 0.98 + tall * tri_wave(s * n + 0.5) * np.clip(1 - np.abs(s) / 1.05, 0, 1) ** 0.5
        hairline = 0.56 - 0.15 * np.clip(np.abs(s) - 0.4, 0, 1) - 2.5 * np.clip(np.abs(s) - 0.66, 0, 1)
        if kind == "hiruzen":
            hairline = hairline + 0.05 + 0.06 * np.exp(-((s / 0.2) ** 2))   # receding
        region = sstep(hairline - 0.02, hairline + 0.04, t) * (1 - sstep(top - 0.04, top, t - 0.0))
        width = ell(s, t - 0.2, 0.98, 1.3)
        side = sstep(0.66, 0.72, np.abs(s)) * (1 - sstep(0.92, 0.98, np.abs(s))) * sstep(-0.05, 0.12, t) * (t < 0.7)
        strand_dir = s * 0.5 + t
        strands = 1 + 0.12 * np.sin(strand_dir * 45 + s * 20)
        hair = np.maximum(0.46 * width ** 0.4 * region, 0.32 * side) * strands
        if kind == "hiruzen":   # goatee
            beard = (1 - sstep(0.17, 0.24, np.abs(s))) * sstep(-1.06, -0.98, t) * (1 - sstep(-0.66, -0.6, t))
            hair = np.maximum(hair, (0.40 + 0.04 * np.sin(s * 90)) * beard)
            hair = np.maximum(hair, 0.36 * line_mask(s, t, -0.2, -0.40, 0.2, -0.40, 0.03) * (1 - np.exp(-((s / 0.05) ** 2))))
    elif kind == "minato":
        top = 0.98 + 0.30 * tri_wave(s * 3.2 + 0.3) * np.clip(1 - np.abs(s) / 1.1, 0, 1) ** 0.5
        hl = 0.54 - 2.5 * np.clip(np.abs(s) - 0.66, 0, 1)
        region = sstep(hl - 0.02, hl + 0.04, t) * (1 - sstep(top - 0.04, top, t))
        width = ell(s, t - 0.25, 1.0, 1.3)
        hair = 0.46 * width ** 0.4 * region
        # forehead bangs: downward spikes
        for sx, tip in ((-0.36, 0.30), (-0.12, 0.22), (0.12, 0.26), (0.36, 0.32)):
            w = 0.13 * np.clip((t - tip) / (0.62 - tip), 0, 1)
            spike = (1 - sstep(w - 0.025, w + 0.005, np.abs(s - sx))) * (t > tip) * (t < 0.66)
            hair = np.maximum(hair, (0.44 + 0.10 * np.clip((t - tip) / 0.3, 0, 1)) * spike)
        # long side bangs framing the face, tapering to a point near the jaw
        for sign in (-1, 1):
            u = sign * s
            tip = -0.62
            w = 0.12 * np.clip((t - tip) / (0.6 - tip), 0, 1) ** 0.8
            cx = 0.68 + 0.05 * np.clip((0.3 - t), 0, 1)
            band = (1 - sstep(w - 0.02, w + 0.01, np.abs(u - cx))) * (t > tip) * (t < 0.65)
            hair = np.maximum(hair, 0.46 * band)
        hair *= 1 + 0.10 * np.sin((s + t * 0.4) * 55)
    # neck/shoulder mass merging into the cliff below the chin
    swell = 0.09 * ell(s, t + 0.80, 0.85, 0.80) ** 2.2
    out = smax(face_total, hair, 0.04)
    return np.maximum(np.maximum(out, swell) - 0.012, 0.0)


def smax(a, b, k):
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0, 1)
    return a * h + b * (1 - h) + k * h * (1 - h)


def relief_height(X, V):
    """Sum of all carved heads, metres. Zero away from the faces."""
    H = np.zeros_like(X)
    for face in FACES:
        s = (X - face["cx"]) / R
        t = (V - face["cy"]) / R
        box = (np.abs(s) < 1.4) & (t > -1.95) & (t < 1.4)
        if not box.any():
            continue
        h = np.zeros_like(X)
        h[box] = face_height(face["kind"], s[box], t[box]) * R
        H = np.maximum(H, h)
    return H


# ---------------------------------------------------------------- rock tile
def make_tile(n=512):
    h = np.zeros((n, n), np.float32)
    for cells, amp, seed in ((4, 0.35, 1), (8, 0.25, 2), (16, 0.14, 3), (32, 0.08, 4), (64, 0.04, 5)):
        h += amp * value_noise_periodic(n, cells, seed)
    # horizontal strata + vertical cracks
    yy = np.arange(n)[:, None] / n
    xx = np.arange(n)[None, :] / n
    strata = 0.02 * np.sin((yy * 3 + 0.15 * value_noise_periodic(n, 8, 9)) * 2 * math.pi)
    cracks = value_noise_periodic(n, 12, 11)
    crack = -0.07 * np.exp(-((np.abs(cracks - 0.5) / 0.018) ** 2)) * (value_noise_periodic(n, 6, 12) > 0.45)
    h = h + strata + crack + 0 * xx
    h = (h - h.min()) / (h.max() - h.min())
    tone = value_noise_periodic(n, 6, 21)
    base = np.array([0.66, 0.55, 0.42], np.float32)
    warm = np.array([0.74, 0.58, 0.40], np.float32)
    cool = np.array([0.55, 0.50, 0.44], np.float32)
    col = base[None, None] * (1 - tone[..., None]) + warm[None, None] * tone[..., None]
    col = col * (1 - 0.35 * value_noise_periodic(n, 24, 22)[..., None] * 0.6) + cool * 0.0
    col *= (0.86 + 0.20 * h)[..., None]
    return h.astype(np.float32), np.clip(col, 0, 1).astype(np.float32)


def sample_periodic(img, U, Vv):
    """Bilinear sample of a periodic image at tile coords (U, V) in tile units; V up."""
    n = img.shape[0]
    px = (U % 1.0) * n
    py = (1.0 - (Vv % 1.0)) * n
    x0 = np.floor(px).astype(int) % n
    y0 = np.floor(py).astype(int) % n
    fx = (px - np.floor(px))
    fy = (py - np.floor(py))
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    if img.ndim == 3:
        fx, fy = fx[..., None], fy[..., None]
    return ((img[y0, x0] * (1 - fx) + img[y0, x1] * fx) * (1 - fy)
            + (img[y1, x0] * (1 - fx) + img[y1, x1] * fx) * fy)


def normal_map(h, mx, my, strength=1.0):
    """OpenGL (Y+) tangent-space normal map; h in metres, mx/my metres per pixel; row 0 = top."""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * mx)
    dy = -(np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * my)   # image rows go down; world v goes up
    nx, ny = -dx * strength, -dy * strength
    nz = np.ones_like(h)
    L = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / L, ny / L, nz / L], -1) * 0.5 + 0.5


def to_png(arr, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, optimize=True)


# ---------------------------------------------------------------- bake
def relief_fields(w, h_px):
    xs = -RX + (np.arange(w) + 0.5) / w * 2 * RX
    vs = VMAX - (np.arange(h_px) + 0.5) / h_px * VMAX          # row 0 = top
    X, V = np.meshgrid(xs.astype(np.float32), vs.astype(np.float32))
    return X, V


def preview(path=PREVIEW, w=1800, h_px=1040):
    X, V = relief_fields(w, h_px)
    H = relief_height(X, V)
    mx, my = 2 * RX / w, VMAX / h_px
    n = normal_map(H, mx, my) * 2 - 1
    light = np.array([-0.45, 0.35, 0.82]); light /= np.linalg.norm(light)
    lam = np.clip((n * light).sum(-1), 0, 1)
    img = (0.25 + 0.75 * lam)[..., None] * np.array([0.78, 0.66, 0.52])
    img[V > ytop(X)] = [0.35, 0.5, 0.3]
    to_png(img, path)
    print("preview ->", path)


def bake():
    os.makedirs(OUT, exist_ok=True)
    tile_h, tile_col = make_tile()
    tile_h_m = tile_h * 0.9                                   # metres of micro relief
    to_png(tile_col, os.path.join(OUT, "rock_tile_albedo.png"))
    to_png(normal_map(tile_h_m, TILE_M / 512, TILE_M / 512), os.path.join(OUT, "rock_tile_normal.png"))

    X, V = relief_fields(TEX_W, TEX_H)
    mx, my = 2 * RX / TEX_W, VMAX / TEX_H
    H = relief_height(X, V)
    top = ytop(X)
    face_zone = V <= top
    H = H * face_zone
    blur_px = (STEP_X_CENTER / mx * 0.9, STEP_V / my * 0.9)
    H_lo = gauss_blur(H, *blur_px)
    micro = sample_periodic(tile_h_m, X / TILE_M, V / TILE_M)
    detail = (H - H_lo) + micro
    to_png(normal_map(detail, mx, my), os.path.join(OUT, "relief_normal.png"))

    # ambient occlusion from multi-scale height concavity (full height incl. geometry part)
    Hf = H + noise_lo(X, V)
    ao = np.ones_like(H)
    for r_m, k in ((0.6, 0.9), (2.0, 0.45), (6.0, 0.18)):
        b = gauss_blur(Hf + micro, r_m / mx, r_m / my)
        ao -= k * np.clip(b - (Hf + micro), 0, None) / r_m
    ao = np.clip(ao, 0.45, 1.0)

    col = sample_periodic(tile_col, X / TILE_M, V / TILE_M)
    big = sample_periodic(tile_h, X / 97.0, V / 61.0) * 0.6 + sample_periodic(tile_h, X / 41.0 + 0.3, V / 33.0) * 0.4
    col *= (0.82 + 0.30 * big)[..., None]
    # carved heads read slightly lighter and smoother than raw cliff (anime look)
    carve = np.clip(H / 3.0, 0, 1)[..., None]
    col = col * (1 - 0.25 * carve) + np.array([0.80, 0.68, 0.53]) * 0.25 * carve
    # moss on up-facing ledges, grass over the top edge, rain streaks below ledges
    gy = (np.roll(H_lo, 1, 0) - np.roll(H_lo, -1, 0)) / (2 * my)
    upness = np.clip(-gy * 0.6, 0, 1)                       # surfaces that turn upward
    moss = np.clip(upness * (0.5 + 0.5 * sample_periodic(tile_h, X / 37, V / 29)) - 0.25, 0, 1)
    green = np.array([0.36, 0.47, 0.26])
    col = col * (1 - 0.7 * moss[..., None]) + green * 0.7 * moss[..., None]
    streak = sample_periodic(tile_h, X / 3.0, V / 90.0)
    col *= (1 - 0.10 * np.clip(streak - 0.4, 0, 1) * 2)[..., None]
    grass = sstep(-2.5, 1.5, V - top)
    grass_col = np.array([0.30, 0.42, 0.22]) * (0.85 + 0.3 * sample_periodic(tile_h, X / 9, V / 9))[..., None]
    col = col * (1 - grass[..., None]) + grass_col * grass[..., None]
    col *= ao[..., None]
    # fade relief-only tints toward the plain tile at the seam with the wings
    seam = sstep(RX - 25, RX - 2, np.abs(X))[..., None]
    plain = sample_periodic(tile_col, X / TILE_M, V / TILE_M) * (1 - grass[..., None]) + grass_col * grass[..., None]
    col = col * (1 - seam) + plain * seam
    to_png(col, os.path.join(OUT, "relief_albedo.png"))

    # geometry: sample the blurred relief at grid vertices
    write_obj(H_lo, mx, my)
    print("baked ->", OUT)


def sample_grid(img, x, v, mx, my):
    """Nearest-texel lookup of a relief-space field at world (x, v) arrays."""
    cx = np.clip(((x + RX) / mx).astype(int), 0, img.shape[1] - 1)
    cy = np.clip(((VMAX - v) / my).astype(int), 0, img.shape[0] - 1)
    return img[cy, cx]


def write_obj(H_lo, mx, my):
    xs_c = np.arange(-RX, RX + 1e-6, STEP_X_CENTER)
    xs_w = np.arange(RX + STEP_X_WING, WING_X + 1e-6, STEP_X_WING)
    xs = np.concatenate([-xs_w[::-1], xs_c, xs_w])
    vs = np.arange(0.0, VMAX + 1e-6, STEP_V)
    XX, VV = np.meshgrid(xs, vs)                                 # rows = v, cols = x
    center = np.abs(XX) <= RX + 1e-6
    rel = np.where(center, sample_grid(H_lo, XX, VV, mx, my), 0.0)
    top = ytop(XX)
    d = rel + noise_lo(XX, VV) * np.clip(top / 30.0, 0, 1)
    # fold: below ytop the face is vertical; above, bend over FOLD_R then run back as plateau
    over = VV - top
    ang = np.clip(over / FOLD_R, 0, math.pi / 2)
    py = np.where(over <= 0, VV, top + FOLD_R * np.sin(ang))
    pz_fold = d - FOLD_R * (1 - np.cos(ang)) - np.clip(over - FOLD_R * math.pi / 2, 0, None)
    pz = np.where(over <= 0, d, pz_fold) + zbase(XX)
    P = np.stack([XX, py, pz], -1)

    # normals from grid neighbours
    du = np.gradient(P, axis=1)
    dv = np.gradient(P, axis=0)
    N = np.cross(du, dv)
    N /= np.linalg.norm(N, axis=-1, keepdims=True) + 1e-9

    uv_rel = np.stack([(XX + RX) / (2 * RX), VV / VMAX], -1)
    uv_wing = np.stack([XX / TILE_M, VV / TILE_M], -1)
    rows, cols = XX.shape
    idx = lambda j, i: j * cols + i + 1
    path = os.path.join(OUT, "cliff.obj")
    with open(path, "w") as fh:
        fh.write("# baked by tools/bake_relief.py\nmtllib cliff.mtl\no Cliff\n")
        for p in P.reshape(-1, 3):
            fh.write("v %.3f %.3f %.3f\n" % tuple(p))
        for n in N.reshape(-1, 3):
            fh.write("vn %.4f %.4f %.4f\n" % tuple(n))
        # two UV sets written as one list: first relief UVs, then wing UVs
        for t in uv_rel.reshape(-1, 2):
            fh.write("vt %.5f %.5f\n" % tuple(t))
        for t in uv_wing.reshape(-1, 2):
            fh.write("vt %.4f %.4f\n" % tuple(t))
        off = rows * cols
        tris = {"relief": 0, "wing": 0}
        for mat in ("relief", "wing"):
            fh.write("usemtl %s\n" % mat)
            for i in range(cols - 1):
                x_mid = 0.5 * (xs[i] + xs[i + 1])
                is_rel = abs(x_mid) < RX
                if (mat == "relief") != is_rel:
                    continue
                uo = 0 if is_rel else off
                for j in range(rows - 1):
                    a, b, c, e = idx(j, i), idx(j, i + 1), idx(j + 1, i + 1), idx(j + 1, i)
                    fh.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (a, a + uo, a, b, b + uo, b, c, c + uo, c))
                    fh.write("f %d/%d/%d %d/%d/%d %d/%d/%d\n" % (a, a + uo, a, c, c + uo, c, e, e + uo, e))
                    tris[mat] += 2
    with open(os.path.join(OUT, "cliff.mtl"), "w") as fh:
        fh.write("newmtl relief\nKd 1 1 1\nnewmtl wing\nKd 1 1 1\n")
    print("cliff.obj verts=%d tris=%s" % (rows * cols, tris))

    # top edge samples for tree placement (x, top y, z of edge)
    top_x = np.arange(-WING_X, WING_X + 1e-6, 5.0)
    edge = [[round(float(x), 2), round(float(ytop(np.array(x))), 2), round(float(zbase(np.array(x))), 2)] for x in top_x]
    with open(os.path.join(OUT, "cliff_top.json"), "w") as fh:
        json.dump({"note": "baked by tools/bake_relief.py: [x, top_y, face_z]", "edge": edge}, fh)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    args = ap.parse_args()
    if args.preview:
        preview()
    else:
        bake()
