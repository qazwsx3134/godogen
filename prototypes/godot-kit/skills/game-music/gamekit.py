"""遊戲配樂合成工具庫：樂譜腳本 import 這個檔，只寫「什麼時候彈什麼」。

做法見 skill `game-music` 的 SKILL.md；專案裡的副本不要直接改，改 godot-kit/skills/game-music/ 的來源檔。重點是讓合成聽起來像樂團而不是音序器：
  - 弦樂器用 Karplus-Strong 弦模型（每次撥弦的激發都不同，等於自帶 round-robin）
  - 人演奏的聲部用 Song.put(..., human=秒) 加時間與力度抖動；合成器聲部留在網格上
  - 失真、房間、壓縮都做在整條 bus 上，不做在單一音符上
"""
import numpy as np
import scipy.signal as ss
import soundfile as sf
from scipy.ndimage import maximum_filter1d

SR = 48000
rng = np.random.default_rng(86)


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def tv(d):
    return np.arange(int(d * SR)) / SR


def filt(x, kind, fc, order=2):
    return ss.sosfilt(ss.butter(order, fc, kind, fs=SR, output="sos"), x)


def noise(d):
    return rng.standard_normal(int(d * SR))


class Song:
    """一張 BPM 網格加幾條立體聲 bus。位置單位是十六分音符；尾音留在 tail，master() 會摺回開頭。"""

    def __init__(self, bpm, bars, buses, tail=4.0):
        self.s16 = 60 / bpm / 4
        self.n, self.tail = round(bars * 16 * self.s16 * SR), int(tail * SR)
        self.bus = {k: np.zeros((2, self.n + self.tail)) for k in buses}

    def put(self, bus, sig, pos, gain=1.0, pan=0.0, human=0.0):
        """human：時間抖動的標準差（秒），同時帶 0–12% 的力度變化。等功率聲像。"""
        s = max(0, round((pos * self.s16 + (rng.normal(0, human) if human else 0)) * SR))
        sig = sig[: self.n + self.tail - s] * gain * (rng.uniform(0.88, 1) if human else 1)
        a = (pan + 1) * np.pi / 4
        self.bus[bus][0, s:s + len(sig)] += sig * np.cos(a)
        self.bus[bus][1, s:s + len(sig)] += sig * np.sin(a)

    def duck(self, hits, depth=0.3, rel=0.12):
        """sidechain 包絡：hits（十六分位置）落點壓下去再放開。"""
        e = np.ones(self.n + self.tail); c = 1 - depth * np.exp(-tv(0.5) / rel)
        for p in hits:
            s = round(p * self.s16 * SR)
            e[s:s + len(c)] = np.minimum(e[s:s + len(c)], c[: len(e) - s])
        return e


# ---------------------------------------------------------------- 弦（吉他、貝斯）
def string(m, d, sustain=4.0, damp=0.08, pick=0.18, bright=6000):
    """Karplus-Strong：一段噪音在延遲線裡循環、每圈被低通一次。
    sustain＝衰減 60dB 的秒數；damp 0–0.25 越大越悶；pick＝撥弦位置；bright＝撥片硬度。"""
    f0 = hz(m) * (1 + rng.normal(0, 0.0015))               # 每次音準差一點點
    n, per = int(d * SR), SR / f0 - 1
    P = int(per)
    c = np.convolve([damp, 1 - 2 * damp, damp], [1 - (per - P), per - P]) * 10 ** (-3 / (f0 * sustain))
    e = filt(rng.standard_normal(P + 200), "low", bright)[200:]
    e -= np.roll(e, max(1, int(pick * P)))
    o = P + 3
    y = np.zeros(o + max(n, 2 * P)); y[o:o + P] = e / np.abs(e).max()
    for s in range(o + P, len(y), P):                      # 一次算一個週期
        k = min(P, len(y) - s)
        for j in range(4):
            y[s:s + k] += c[j] * y[s - P - j:s - P - j + k]
    return y[o:o + n] * np.minimum(1, (n - np.arange(n)) / (0.005 * SR))


def power(root, d, mute=False):
    """強力和弦的乾聲。mute＝悶音（右手掌壓弦）。失真用 amp() 做在整條 bus。"""
    if mute:
        return sum(string(root + i, d, 0.25, 0.25, 0.12, 1800) for i in (0, 7))
    return sum(string(root + i, d, 5.0, 0.06) for i in (0, 7, 12))


def bass(m, d):
    t = tv(d)
    return string(m, d, 1.5, 0.18, 0.3, 2500) + 0.5 * np.sin(2 * np.pi * hz(m) * t) * np.exp(-t / 0.4) * np.minimum(1, t / 0.004)


def amp(x, drive=9.0):
    """吉他音箱：推中頻 → 兩級不對稱削波 → 箱體（切低切高、2.5k 突出、挖 350Hz）。"""
    x = filt(x, "high", 100)
    x = x + 2 * filt(x, "band", [500, 1200])
    y = np.tanh(drive * x / (np.abs(x).max() + 1e-9))
    y = np.tanh(1.5 * y + 0.25 * y * y)
    y = filt(filt(y, "high", 80), "low", 4800, 4)
    return y + 0.6 * filt(y, "band", [2000, 3200]) - 0.3 * filt(y, "band", [250, 450])


# ---------------------------------------------------------------- 鼓（v＝力度 0–1，影響音量也影響音色）
def kick(v=1.0):
    t = tv(0.4); f = 42 + 95 * np.exp(-t / 0.018)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16) + filt(noise(0.4), "band", [2500, 6000]) * np.exp(-t / 0.0035) * 0.5 * v) * v


def snare(v=1.0):
    t = tv(0.35); k = 1 + rng.normal(0, 0.02)
    body = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t / 0.07) for f, a in ((185, 1), (330, 0.5)))
    return (body * 0.6 + filt(noise(0.35), "band", [1500, 9000]) * np.exp(-t / (0.08 + 0.06 * v)) * (0.4 + 0.6 * v)) * v


def _metal(d):                                             # 六個不成倍數的方波：鈸的金屬感
    t = tv(d); b = 540 * (1 + rng.normal(0, 0.01))
    return sum(np.sign(np.sin(2 * np.pi * b * r * t + rng.uniform(0, 6.28))) for r in (2, 3, 4.16, 5.43, 6.79, 8.21)) / 6


def hat(v=1.0, open_=False):
    d = 0.3 if open_ else 0.06
    return filt(_metal(d) + 0.4 * noise(d), "high", 7000, 4) * np.exp(-tv(d) / (d / 3.5)) * v


def crash():
    return filt(_metal(3.0) * 0.6 + noise(3.0), "high", 3500, 3) * np.exp(-tv(3.0) / 0.8)


def tom(m, v=1.0):
    t = tv(0.5); f = hz(m) * (1 + 0.5 * np.exp(-t / 0.03))
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.2) + filt(noise(0.5), "low", 3000) * np.exp(-t / 0.01) * 0.4) * v


def boom():                                                # 段落開頭的低頻重擊
    t = tv(2.0); f = 30 + 55 * np.exp(-t / 0.15)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.6)


# ---------------------------------------------------------------- 合成器
def saw(f, d, top=9000):
    """帶限鋸齒；f 可為逐樣本陣列（顫音、滑音）。"""
    fa = np.full(int(d * SR), f) if np.isscalar(f) else f
    ph = 2 * np.pi * np.cumsum(fa) / SR
    return sum(np.sin(k * ph + rng.uniform(0, 6.28)) / k for k in range(1, int(top / fa.max()) + 1))


def _env(d, a, r):
    t = tv(d)
    return np.minimum(1, t / a) * np.minimum(1, (d - t) / r).clip(0)


def pad(m, d):
    return filt(sum(saw(hz(m) * (1 + x), d, 5000) for x in (-0.009, -0.003, 0.004, 0.01)) / 4, "low", 1800) * _env(d, 0.4, 0.5)


def pulse(m, d, cut):
    """音序器低音：鋸齒＋低通，cut 由樂譜逐音給（濾波器開合）。"""
    return filt(saw(hz(m), d, 6000) + saw(hz(m) * 1.007, d, 6000), "low", cut, 4) * np.exp(-tv(d) / 0.09) * _env(d, 0.003, 0.01)


def lead(m, d, prev=None):
    n = int(d * SR); t = np.arange(n) / SR
    f = np.full(n, hz(m))
    if prev is not None:
        f *= 2 ** ((prev - m) / 12 * np.exp(-t / 0.025))   # 滑音
    f *= 1 + 0.007 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 0.3)
    return np.tanh(filt(saw(f, d, 7000) + saw(f * 1.006, d, 7000), "low", 3000) * 1.5) * _env(d, 0.02, 0.08)


# ---------------------------------------------------------------- 混音
def room(x, decay, wet, lo=250, hi=7000, seed=1):
    """殘響：指數衰減噪音當脈衝響應，15ms 預延遲。x 形狀 (2, N)。"""
    r = np.random.default_rng(seed); t = tv(decay * 4)
    ir = filt(filt(r.standard_normal((2, len(t))) * np.exp(-t / decay), "high", lo), "low", hi)
    ir[:, : int(0.015 * SR)] = 0
    w = np.stack([ss.fftconvolve(x[c], ir[c])[: x.shape[1]] for c in (0, 1)])
    return x + wet * w / np.sqrt((ir ** 2).sum(1))[:, None]


def echo(x, samples, gains=(0.35, 0.15)):
    """ping-pong delay：每次回聲左右互換。"""
    out = x.copy()
    for i, g in enumerate(gains, 1):
        y = x[::-1] if i % 2 else x
        out[:, i * samples:] += g * y[:, : x.shape[1] - i * samples]
    return out


def compress(x, thr_db, ratio=4.0, rel=0.08):
    lvl = maximum_filter1d(np.abs(x).max(0), 289)
    a = np.exp(-1 / (rel * SR))
    e = np.maximum(ss.lfilter([1 - a], [1, -a], lvl), 1e-9)
    return x * np.minimum(1, (e / 10 ** (thr_db / 20)) ** (1 / ratio - 1))


def lufs(x):
    """BS.1770 積分響度（K 加權、雙門限）。"""
    k = ss.lfilter([1.0, -2.0, 1.0], [1, -1.99004745483398, 0.99007225036621],
                   ss.lfilter([1.53512485958697, -2.69169618940638, 1.19839281085285], [1, -1.69065929318241, 0.73248077421585], x))
    blk, hop = int(0.4 * SR), int(0.1 * SR)
    z = np.array([np.mean(k[:, i:i + blk] ** 2, axis=1).sum() for i in range(0, x.shape[1] - blk, hop)])
    z = z[z > 10 ** ((-70 + 0.691) / 10)]
    z = z[z > z.mean() / 10]
    return -0.691 + 10 * np.log10(z.mean())


def level(x, db):
    """把一條 bus 調到指定響度。聽不到聲音時用它配平：各 bus 的相對值寫在樂譜腳本裡。"""
    return x * 10 ** ((db - lufs(x)) / 20)


def master(song, mix, out, target=-16.0, ceil_db=-1.5):
    """尾音摺回開頭 → 匯流排壓縮＋飽和 → 響度與峰值 → 檢查接縫 → 分段寫檔。"""
    n = song.n
    mix = mix.copy(); mix[:, : song.tail] += mix[:, n:]; mix = mix[:, :n]
    x = np.tile(level(mix, target), 2)                     # 接兩遍、取後半：壓縮器的狀態在接縫處連續
    x = compress(x, -20, 2.0, 0.2)
    x = filt(np.tanh(x * 1.6) / 1.6, "low", 15000)
    mix, ceil = x[:, n:], 10 ** (ceil_db / 20)
    for _ in range(3):
        mix = level(mix, target)
        peak = maximum_filter1d(np.abs(mix).max(0), 96, mode="wrap")
        mix = mix * np.convolve(np.minimum(1, ceil / np.maximum(peak, 1e-9)), np.ones(96) / 96, mode="same")
    seam = np.abs(mix[:, 0] - mix[:, -1]).max()
    assert seam <= np.abs(np.diff(mix)).max(), f"循環接縫跳變 {seam:.3f}"
    assert np.abs(mix).max() <= 1.0
    out.parent.mkdir(parents=True, exist_ok=True)
    kw = dict(format="OGG", subtype="VORBIS") if out.suffix == ".ogg" else dict(subtype="PCM_24")
    with sf.SoundFile(out, "w", SR, 2, **kw) as f:         # OGG 一次寫整段會 segfault
        for i in range(0, n, SR):
            f.write(mix[:, i:i + SR].T)
    print(f"{out.name}: {n / SR:.2f}s, {lufs(mix):.2f} LUFS, peak {20 * np.log10(np.abs(mix).max()):.2f} dBFS, 接縫 {seam:.4f}")
    return mix
