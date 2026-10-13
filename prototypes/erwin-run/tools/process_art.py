"""Turn Codex-generated images (art_src/gen/<id>/generated.*) into game-size pixel assets under assets/.

Sprites: key out the magenta background, split the row into frames by empty columns, scale every frame of a
sheet by the same factor, bottom-centre each in a fixed cell, harden alpha, cap the palette.
Backgrounds: key magenta (sky area) where asked, scale to a target height, then append a mirrored copy so the
strip tiles seamlessly (ponytail: mirror tiling instead of hand-made seams; replace with a true seamless
tile if the mirror symmetry ever reads badly).
An asset whose generated image is missing gets a flat placeholder of the same size, so the game always runs.

  uv run --no-project --with pillow --with numpy python tools/process_art.py [ids...]
  ... python tools/process_art.py --self-test
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "art_src" / "gen"
OUT = ROOT / "assets"

# id: (kind, out path, frames, cell w, cell h, colors)   kind: sheet | grid | bg | bgkey | full
SPECS = {
    "erwin_gallop": ("sheet", "sprites/erwin_gallop.png", 6, 112, 96, 40),
    "erwin_actions": ("sheet", "sprites/erwin_actions.png", 3, 112, 104, 40),
    "titan_tall": ("sheet", "sprites/titan_tall.png", 4, 76, 140, 32),
    "titan_fat": ("sheet", "sprites/titan_fat.png", 4, 84, 96, 32),
    "titan_runner": ("sheet", "sprites/titan_runner.png", 4, 92, 118, 32),
    "beast_body": ("sheet", "sprites/beast_body.png", 3, 230, 290, 40),
    "beast_arm": ("sheet", "sprites/beast_arm.png", 1, 380, 96, 32),
    "levi": ("sheet", "sprites/levi.png", 5, 72, 64, 32),
    "rocks": ("grid", "sprites/rocks.png", 4, 34, 34, 24),
    "emblem": ("grid", "ui/emblem.png", 4, 26, 26, 24),
    "bg_sky": ("bg", "bg/sky.png", 0, 0, 360, 48),
    "bg_far": ("bgkey", "bg/far.png", 0, 0, 230, 32),
    "bg_mid": ("bgkey", "bg/mid.png", 0, 0, 230, 40),
    "bg_ruins": ("bgkey", "bg/ruins.png", 0, 0, 250, 40),
    "wall_gate": ("bgkey_once", "bg/wall_gate.png", 0, 0, 330, 48),
    "ground": ("bg", "bg/ground.png", 0, 0, 120, 24),
    "title_art": ("full", "ui/title_art.png", 0, 640, 360, 64),
    "ending_art": ("full", "ui/ending_art.png", 0, 640, 360, 64),
}
PLACEHOLDER = {"erwin": (236, 236, 228), "titan": (226, 170, 140), "beast": (110, 70, 50), "levi": (60, 90, 60),
               "rocks": (120, 116, 110), "emblem": (90, 140, 220), "bg_sky": (240, 170, 110), "bg_far": (90, 90, 130),
               "bg_mid": (70, 120, 60), "bg_ruins": (110, 80, 60), "wall_gate": (130, 120, 110),
               "ground": (100, 70, 40), "title": (40, 50, 70), "ending": (240, 190, 110)}


def source(asset_id):
    for d in [GEN / f"{asset_id}-r3", GEN / f"{asset_id}-r2", GEN / asset_id]:
        for ext in ("png", "webp", "jpg", "jpeg"):
            p = d / f"generated.{ext}"
            if p.exists():
                return p
    return None


def key_magenta(img):
    """RGBA array with the magenta background (and its fringe) made transparent, spill pulled out of edges."""
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    magenta = (r - g > 70) & (b - g > 70) & (np.abs(r - b) < 110)
    rgba = np.dstack([a, np.where(magenta, 0, 255)]).astype(np.uint8)
    # despill: pixels next to the key that lean magenta lose the excess red/blue
    spill = (~magenta) & (r > g + 30) & (b > g + 30)
    rgba[spill, 0] = np.minimum(r[spill], g[spill] + 30)
    rgba[spill, 2] = np.minimum(b[spill], g[spill] + 30)
    return rgba


def split_columns(alpha, frames):
    """Frame spans along x: runs of columns holding content, merged/split until there are `frames` of them."""
    cols = alpha.sum(axis=0) > 2
    spans, start = [], None
    for x, on in enumerate(list(cols) + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 3:
                spans.append([start, x])
            start = None
    while len(spans) > frames:  # merge the pair with the smallest gap (a frame split by a thin gap)
        gaps = [spans[i + 1][0] - spans[i][1] for i in range(len(spans) - 1)]
        i = gaps.index(min(gaps))
        spans[i:i + 2] = [[spans[i][0], spans[i + 1][1]]]
    if len(spans) < frames:  # fall back to equal slices of the content range
        x0, x1 = spans[0][0], spans[-1][1]
        w = (x1 - x0) / frames
        spans = [[int(x0 + i * w), int(x0 + (i + 1) * w)] for i in range(frames)]
    return spans


def bbox(alpha):
    ys, xs = np.nonzero(alpha > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def harden(img, colors):
    """Hard alpha and a capped palette so the downscale reads as pixel art."""
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    rgb = Image.fromarray(a[..., :3]).quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = np.dstack([np.asarray(rgb.convert("RGB")), a[..., 3]])
    out[out[..., 3] == 0] = 0
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def components(alpha, block=4):
    """Connected blobs of opaque pixels, found on a block-downsampled mask (max-pooled so nothing is lost).
    Returns a full-size label map (0 = empty) and the number of labels."""
    h, w = alpha.shape
    hb, wb = (h + block - 1) // block, (w + block - 1) // block
    pad = np.zeros((hb * block, wb * block), bool)
    pad[:h, :w] = alpha > 0
    small = pad.reshape(hb, block, wb, block).any(axis=(1, 3))
    labels = np.zeros(small.shape, np.int32)
    count = 0
    for y0, x0 in zip(*np.nonzero(small)):
        if labels[y0, x0]:
            continue
        count += 1
        stack = [(y0, x0)]
        labels[y0, x0] = count
        while stack:
            y, x = stack.pop()
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < hb and 0 <= nx < wb and small[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = count
                    stack.append((ny, nx))
    full = np.repeat(np.repeat(labels, block, axis=0), block, axis=1)[:h, :w]
    return np.where(alpha > 0, full, 0), count


def frame_masks(alpha, frames):
    """One mask per frame, left to right: the `frames` biggest blobs are the frames, every other blob joins
    the frame whose box is nearest. Falls back to column spans when the frames touch each other."""
    labels, count = components(alpha)
    if count < frames:
        return [np.pad(np.ones((alpha.shape[0], x1 - x0), bool), ((0, 0), (x0, alpha.shape[1] - x1)))
                for x0, x1 in split_columns(alpha, frames)]
    areas = np.bincount(labels.ravel(), minlength=count + 1)
    areas[0] = 0
    big = list(np.argsort(areas)[::-1][:frames])
    boxes = {}
    for lab in range(1, count + 1):
        ys, xs = np.nonzero(labels == lab)
        boxes[lab] = (xs.min(), xs.max())
    big.sort(key=lambda lab: boxes[lab][0])
    owner = {lab: lab for lab in big}
    for lab in range(1, count + 1):
        if lab in owner:
            continue
        x0, x1 = boxes[lab]
        gap = [max(0, boxes[b][0] - x1, x0 - boxes[b][1]) for b in big]
        owner[lab] = big[int(np.argmin(gap))]
    return [np.isin(labels, [lab for lab, o in owner.items() if o == b]) for b in big]


def sheet(rgba, frames, cw, ch, colors):
    crops = []
    for mask in frame_masks(rgba[..., 3], frames):
        part = rgba.copy()
        part[~mask] = 0
        bx0, by0, bx1, by1 = bbox(part[..., 3])
        crops.append(part[by0:by1, bx0:bx1])
    scale = min(min(cw / c.shape[1], ch / c.shape[0]) for c in crops)
    out = Image.new("RGBA", (cw * frames, ch), (0, 0, 0, 0))
    for i, c in enumerate(crops):
        w, h = max(1, round(c.shape[1] * scale)), max(1, round(c.shape[0] * scale))
        im = Image.fromarray(c, "RGBA").resize((w, h), Image.Resampling.BOX)
        out.alpha_composite(im, (i * cw + (cw - w) // 2, ch - h))
    return harden(out, colors)


def grid(rgba, cells, cw, ch, colors):
    """2x2 kit: each quadrant's content fitted into its own cell (no shared scale: icons differ in size)."""
    h, w = rgba.shape[:2]
    out = Image.new("RGBA", (cw * cells, ch), (0, 0, 0, 0))
    for i in range(cells):
        q = rgba[(i // 2) * h // 2:(i // 2 + 1) * h // 2, (i % 2) * w // 2:(i % 2 + 1) * w // 2]
        bx0, by0, bx1, by1 = bbox(q[..., 3])
        c = q[by0:by1, bx0:bx1]
        s = min(cw / c.shape[1], ch / c.shape[0])
        cw2, ch2 = max(1, round(c.shape[1] * s)), max(1, round(c.shape[0] * s))
        im = Image.fromarray(c, "RGBA").resize((cw2, ch2), Image.Resampling.BOX)
        out.alpha_composite(im, (i * cw + (cw - cw2) // 2, (ch - ch2) // 2))
    return harden(out, colors)


def background(img, height, colors, keyed, mirror=True):
    rgba = key_magenta(img) if keyed else np.asarray(img.convert("RGBA")).copy()
    if keyed:  # drop the empty sky rows above the silhouette
        rows = np.nonzero(rgba[..., 3].sum(axis=1) > 0)[0]
        rgba = rgba[rows.min():]
    im = Image.fromarray(rgba, "RGBA")
    w = round(im.width * height / im.height)
    im = harden(im.resize((w, height), Image.Resampling.BOX), colors)
    if not mirror:
        return im
    tile = Image.new("RGBA", (w * 2, height), (0, 0, 0, 0))
    tile.paste(im, (0, 0))
    tile.paste(im.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (w, 0))
    return tile


def full(img, w, h, colors):
    src = img.convert("RGB")
    s = max(w / src.width, h / src.height)  # cover, centre crop
    src = src.resize((round(src.width * s), round(src.height * s)), Image.Resampling.BOX)
    x, y = (src.width - w) // 2, (src.height - h) // 2
    q = src.crop((x, y, x + w, y + h)).quantize(colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGBA")


def placeholder(asset_id, spec):
    kind, _, frames, cw, ch, _ = spec
    col = next((c for k, c in PLACEHOLDER.items() if asset_id.startswith(k)), (200, 200, 200))
    if kind in ("sheet", "grid"):
        im = Image.new("RGBA", (cw * frames, ch), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        for i in range(frames):
            bob = (i % 2) * 3
            d.rectangle([i * cw + cw // 6, ch // 5 + bob, i * cw + cw - cw // 6, ch - 1], fill=col + (255,),
                        outline=(20, 16, 24, 255))
            d.rectangle([i * cw + cw // 2, ch // 5 + bob + 4, i * cw + cw // 2 + 4, ch // 5 + bob + 8],
                        fill=(20, 16, 24, 255))
        return im
    if kind == "full":
        return Image.new("RGBA", (cw, ch), col + (255,))
    w = 640
    im = Image.new("RGBA", (w, ch), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if kind == "bg":
        d.rectangle([0, 0, w, ch], fill=col + (255,))
    else:
        for x in range(0, w, 40):
            top = ch // 3 + (x * 7919 % 37)
            d.rectangle([x, top, x + 39, ch], fill=col + (255,))
    return im


def build(asset_id):
    spec = SPECS[asset_id]
    kind, rel, frames, cw, ch, colors = spec
    src = source(asset_id)
    if src is None:
        im, how = placeholder(asset_id, spec), "placeholder"
    else:
        img = Image.open(src)
        if kind == "sheet":
            im = sheet(key_magenta(img), frames, cw, ch, colors)
        elif kind == "grid":
            im = grid(key_magenta(img), frames, cw, ch, colors)
        elif kind in ("bg", "bgkey"):
            if asset_id == "ground":  # grass edge and soil, deep enough to fill the bottom of 4:3 screens
                img = img.crop((0, int(img.height * 0.03), img.width, int(img.height * 0.76)))
            im = background(img, ch, colors, kind == "bgkey")
        elif kind == "bgkey_once":
            im = background(img, ch, colors, True, mirror=False)
        else:
            im = full(img, cw, ch, colors)
        how = str(src.relative_to(ROOT))
    out = OUT / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out)
    print(f"{asset_id:14s} {im.width}x{im.height}  <- {how}")


def self_test():
    # a fake 3-frame magenta sheet: three squares of different heights must land bottom-aligned in 3 cells
    img = Image.new("RGB", (300, 100), (255, 0, 255))
    d = ImageDraw.Draw(img)
    for i, h in enumerate((40, 60, 80)):
        d.rectangle([i * 100 + 20, 90 - h, i * 100 + 70, 90], fill=(200, 180, 40))
    out = np.asarray(sheet(key_magenta(img), 3, 30, 30, 8))
    assert out.shape == (30, 90, 4), out.shape
    assert (out[-1, :, 3] > 0).sum() > 0 and (out[0, 0:30, 3] == 0).all(), "frames bottom-aligned"
    assert set(np.unique(out[..., 3])) <= {0, 255}, "alpha is hard"
    assert len(split_columns(key_magenta(img)[..., 3], 3)) == 3
    # overlapping columns (a blade reaching into the next frame) must still split by blob, not by column
    img2 = Image.new("RGB", (300, 100), (255, 0, 255))
    d2 = ImageDraw.Draw(img2)
    d2.rectangle([10, 40, 90, 90], fill=(200, 180, 40)); d2.line([90, 40, 130, 10], fill=(200, 200, 200), width=3)
    d2.rectangle([110, 40, 190, 90], fill=(40, 180, 200)); d2.rectangle([210, 40, 290, 90], fill=(40, 200, 40))
    masks = frame_masks(key_magenta(img2)[..., 3], 3)
    assert masks[0][12, 125] and not masks[1][12, 125], "blade tip stays with its own frame"
    t = background(img, 50, 8, True)
    assert t.width % 2 == 0 and np.array_equal(np.asarray(t)[:, 0], np.asarray(t)[:, -1]), "mirror tile seams match"
    print("self-test ok")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        for asset_id in (sys.argv[1:] or SPECS):
            build(asset_id)
