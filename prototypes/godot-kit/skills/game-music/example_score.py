#!/usr/bin/env python3
"""魔都傭兵 BGM〈Neon Riot〉：降 D 調的重搖滾＋合成器，可無縫循環。

  uv run --with numpy --with scipy --with soundfile python scripts/make_bgm.py
輸出 public/audio/bgm_neon_riot.ogg（96 BPM 半拍律動，D 小調／弗里吉亞，32 小節 = 80s）。

段落（各 8 小節）：RIFF 重 riff → LEAD 主奏旋律 → CLEAN 乾淨吉他分解 → BUILD 漸強，尾拍留白後摔回 RIFF。
skill `game-music` 的範例樂譜：複製成專案的 scripts/make_bgm.py，連同 gamekit.py 一起放，再改樂譜與輸出路徑。
"""
from pathlib import Path

import numpy as np

import gamekit as gk

song = gk.Song(96, 32, ("gtr", "clean", "bass", "drum", "synth", "pad", "lead", "fx"))
S, put = song.s16, song.put
PROG = [(38, 3), (46, 4), (43, 3), (45, 4)]                # (根音, 三度)：Dm–B♭–Gm–A
MEL = [[(0, 8, 69), (8, 4, 74), (12, 4, 77)], [(0, 10, 74), (10, 2, 72), (12, 4, 70)],
       [(0, 6, 67), (6, 2, 70), (8, 8, 74)], [(0, 8, 73), (8, 4, 76), (12, 4, 69)],
       [(0, 4, 74), (4, 4, 77), (8, 8, 81)], [(0, 6, 82), (6, 2, 81), (8, 8, 77)],
       [(0, 6, 79), (6, 2, 77), (8, 4, 74), (12, 4, 70)], [(0, 4, 69), (4, 4, 73), (8, 6, 76), (14, 2, 73)]]
kicks = []


def K(p, v=1.0):
    put("drum", gk.kick(v), p, 1, 0, 0.004); kicks.append(p)


def Sn(p, v=1.0):
    put("drum", gk.snare(v), p, 1, 0.05, 0.004)


def H(p, v=0.5, open_=False):
    put("drum", gk.hat(v, open_), p, 0.5, 0.3, 0.005)


def G(p, ln, root, mute=False, g=1.0):
    """吉他左右各彈一次（double-tracking），貝斯低八度跟著。"""
    for pan in (-0.85, 0.85):
        put("gtr", gk.power(root, ln * S + 0.05, mute), p, g * (0.8 if mute else 1), pan, 0.006)
    put("bass", gk.bass(root - 12, ln * S + 0.1), p, g, 0, 0.004)


prev = None
for bar in range(32):
    sec, b0, k = bar // 8, bar * 16, bar % 8
    root, third = PROG[bar % 4] if sec in (1, 2) else (38, 3)

    if sec == 0:      # RIFF：D 弦悶音 chug，第 3 拍 F5，小節尾落在 E♭／A♭（弗里吉亞二級、三全音）
        for p in (0, 1, 2, 4, 6, 7, 10, 11): G(b0 + p, 1, 38, True)
        G(b0 + 8, 2, 41); G(b0 + 12, 4, (39, 44, 39, 45)[bar % 4])
        for p in (0, 3, 6, 10, 11) if bar % 2 == 0 else (0, 3, 6, 7, 10): K(b0 + p, 1 if p in (0, 10) else 0.8)
        Sn(b0 + 8)
        if bar % 2: Sn(b0 + 13, 0.3)                       # ghost note
        if bar % 4 == 3:
            for i, p in enumerate((12, 13, 14, 15)): put("drum", gk.tom(48 - 3 * i, 0.9), b0 + p, 1, 0.4 - 0.25 * i, 0.004)
        for p in range(0, 16, 2): H(b0 + p, 0.6 if p % 4 == 0 else 0.4, p == 14 and bar % 2 == 0)
    elif sec == 1:    # LEAD：和弦走 Dm–B♭–Gm–A，主奏在上面
        G(b0, 4, root); G(b0 + 8, 2, root); G(b0 + 14, 2, root)
        for p in (4, 5, 6, 10, 11, 12, 13): G(b0 + p, 1, root, True)
        for p in (0, 6, 10) + ((14,) if bar % 2 else ()): K(b0 + p)
        Sn(b0 + 8)
        for p in range(0, 16, 2): H(b0 + p, 0.6 if p % 4 == 0 else 0.4)
        if k == 7:
            for p in range(10, 16): Sn(b0 + p, 0.4 + 0.1 * (p - 10))
        for p, ln, m in MEL[k]:
            put("lead", gk.lead(m, ln * S, prev), b0 + p); prev = m
    elif sec == 2:    # CLEAN：乾淨吉他分解和弦，鼓退到只剩大鼓，後半加輕小鼓
        arp = [root + i for i in (12, 19, 24, 24 + third, 31, 24 + third, 24, 19)]
        for i, m in enumerate(arp):
            for pan in (-0.5, 0.5): put("clean", gk.string(m, 1.6, 3.0, 0.1, 0.2, 4500), b0 + 2 * i, 1, pan, 0.008)
        put("bass", gk.bass(root - 12, 14 * S), b0, 0.8, 0, 0.004)
        K(b0, 0.8)
        if k >= 4:
            K(b0 + 10, 0.7); Sn(b0 + 8, 0.55)
            for p in range(0, 16, 2): H(b0 + p, 0.3)
    else:             # BUILD：十六分 chug 逐小節加重 → 長和弦 → 最後一拍留白
        g = 0.6 + 0.4 * k / 7
        if k < 4:
            for p in range(12): G(b0 + p, 1, 38, True, g * (1 if p % 4 == 0 else 0.8))
            G(b0 + 12, 4, (41, 43, 44, 45)[k], g=g)
        elif k < 7:
            for p in (0, 8): G(b0 + p, 8, (46, 48, 45)[k - 4], g=g)
        else:
            for p in (0, 4, 8): G(b0 + p, 4, 45)
            G(b0 + 12, 1.5, 45)
        for p in (0, 4, 8, 12): K(b0 + p)
        hits = {0: (8,), 1: (8,), 2: (4, 12), 3: (4, 12), 4: range(0, 16, 2), 5: range(0, 16, 2), 6: range(16)}.get(k)
        if hits is not None:
            for p in hits: Sn(b0 + p, 0.5 + 0.5 * (k * 16 + p) / 112)
        else:
            for p in range(12): put("drum", gk.tom(50 - p // 2, 1), b0 + p, 1, 0.4 - 0.07 * p, 0.004)
            Sn(b0 + 12)

    if sec != 2:      # 音序器低音：唯一不加抖動的聲部，機械感留給合成器
        for i in range(16):
            cut = 350 + 1500 * (0.5 - 0.5 * np.cos(2 * np.pi * (b0 + i) / 64))
            put("synth", gk.pulse(root, 0.9 * S, cut), b0 + i, 1 if i % 4 == 0 else 0.6, 0.15 if i % 2 else -0.15)
    if sec in (1, 2):
        for iv, pan in ((12, -0.4), (19, 0.4), (24, 0), (24 + third, 0.25)):
            put("pad", gk.pad(root + iv, 16 * S), b0, 1, pan)
    elif sec == 3:
        for iv, pan in ((0, 0), (12, -0.4), (19, 0.4)): put("pad", gk.pad(38 + iv, 16 * S), b0, 1, pan)
    if k == 0:
        if sec != 3: put("fx", gk.boom(), b0, 1)
        if sec != 2: put("drum", gk.crash(), b0, 0.6, -0.3)

for end in (8, 32):                                        # 倒放的鈸把人吸進下一段
    put("drum", gk.crash()[::-1], end * 16 - 3.0 / S, 0.35, 0.3)

# ---------------------------------------------------------------- 配平與混音（數字是各 bus 的 LUFS）
b, pump, d3 = song.bus, song.duck(kicks), round(3 * S * gk.SR)
drum = gk.compress(gk.level(gk.room(b["drum"], 0.12, 0.25, 150, 9000, 3), -18), -22, 4)
mix = (gk.level(drum, -18)
       + gk.level(gk.amp(b["gtr"]), -19)
       + gk.level(gk.filt(np.tanh(b["bass"] * 2 / np.abs(b["bass"]).max()), "low", 3000), -23)
       + gk.level(gk.echo(b["lead"], d3), -22)
       + gk.level(gk.room(gk.echo(b["clean"], d3, (0.3, 0.12)), 0.5, 0.3, seed=5), -23)
       + gk.level(b["synth"], -29) * pump
       + gk.level(b["pad"], -31) * pump
       + gk.level(b["fx"], -26))
mix = gk.room(mix, 0.3, 0.08)

out = gk.master(song, mix, Path(__file__).parent.parent / "public/audio/bgm_neon_riot.ogg")
q = out.shape[1] // 4
print("各段 RMS dB:", [round(float(10 * np.log10(np.mean(out[:, i * q:(i + 1) * q] ** 2))), 1) for i in range(4)])
