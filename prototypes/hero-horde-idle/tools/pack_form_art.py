"""Packs the 怪獸 and 夢靈 placeholder sprites (art_src/forms, see its BRIEF.md) under the human rows of
assets/heroes/heroes.png, and writes their portraits. Rows 0-5 stay the humans (one per class); rows 6-11 are the
monsters, 12-17 the dreamlings, in class order. A source sheet is five 512 px frames facing right: ready, step,
step, lunge, hurt. They become the hero cells: run = ready, step, ready, step; attack = ready, lunge, lunge;
down = hurt; volley = lunge. Each class gets its own tint so the forms still read by class. heroes.json gains a
character per row ("monster_shield" ...). Rerunning starts from the human rows already in the atlas.
    uv run --with pillow python3 tools/pack_form_art.py      (from prototypes/hero-horde-idle)
"""
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "forms"
ATLAS = ROOT / "assets" / "heroes" / "heroes.png"
SHEETS = ROOT / "assets" / "heroes" / "heroes.json"
PORTRAITS = ROOT / "assets" / "heroes" / "portraits"
CELL = 48
COLUMNS = 9
CLASSES = ["shield", "sword", "spear", "bow", "mage", "healer"]
FORMS = {
    "monster": ["briar_boar", "ruin_hound", "briar_boar", "ruin_hound", "ruin_hound", "briar_boar"],
    "dream": ["meadow_slime"] * 6,
}
# Per class: (hue shift tint colour, strength) laid over the source, matching the class hues of scripts/army.gd.
TINTS = [((120, 160, 255), 0.25), ((255, 110, 100), 0.25), ((255, 190, 90), 0.3), ((140, 255, 140), 0.2),
         ((200, 140, 255), 0.35), ((255, 255, 235), 0.35)]
FRAME_ORDER = [0, 1, 0, 2, 0, 3, 3, 4, 3]
# How much of the cell a figure may fill (the humans stand about 40 px tall).
FIT = {"briar_boar": 46, "ruin_hound": 46, "meadow_slime": 30}
FOOT = 2


def frames(name):
    sheet = Image.open(SRC / f"{name}.png").convert("RGBA")
    w = sheet.width // 5
    return [sheet.crop((k * w, 0, (k + 1) * w, sheet.height)) for k in range(5)]


def tinted(img, tint):
    colour, k = tint
    overlay = Image.new("RGBA", img.size, colour + (255,))
    mixed = Image.blend(img, overlay, k)
    mixed.putalpha(img.getchannel("A"))
    return mixed


def fit_cell(img, size):
    box = img.getbbox()
    img = img.crop(box)
    scale = size / max(img.width, img.height)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    cell = Image.new("RGBA", (CELL, CELL))
    cell.alpha_composite(img, ((CELL - img.width) // 2, CELL - FOOT - img.height))
    # Hard alpha edge, like the pixel heroes.
    alpha = cell.getchannel("A").point(lambda a: 255 if a > 110 else 0)
    cell.putalpha(alpha)
    return cell


def main():
    base = Image.open(ATLAS).convert("RGBA")
    humans = base.crop((0, 0, COLUMNS * CELL, 6 * CELL))
    atlas = Image.new("RGBA", (COLUMNS * CELL, 18 * CELL))
    atlas.alpha_composite(humans, (0, 0))
    data = json.loads(SHEETS.read_text())
    template = data["characters"]["shield"]["anims"]
    row = 6
    for form, sources in FORMS.items():
        for c, name in enumerate(sources):
            src = frames(name)
            cells = [fit_cell(tinted(src[k], TINTS[c]), FIT[name]) for k in FRAME_ORDER]
            for col, cell in enumerate(cells):
                atlas.alpha_composite(cell, (col * CELL, row * CELL))
            anims = {}
            for anim, spec in template.items():
                anims[anim] = dict(spec, cell=row * COLUMNS + spec["cell"] % COLUMNS)
            data["characters"][f"{form}_{CLASSES[c]}"] = {"directions": 1, "mirror": False, "anims": anims}
            portrait = tinted(src[0], TINTS[c])
            portrait = portrait.crop(portrait.getbbox())
            portrait.thumbnail((192, 192), Image.LANCZOS)
            square = Image.new("RGBA", (200, 200))
            square.alpha_composite(portrait, ((200 - portrait.width) // 2, 200 - 4 - portrait.height))
            square.save(PORTRAITS / f"{form}_{CLASSES[c]}.png")
            row += 1
    data["rows"] = 18
    atlas.save(ATLAS)
    SHEETS.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print(f"{ATLAS.name}: {atlas.size}, characters {len(data['characters'])}")


if __name__ == "__main__":
    main()
