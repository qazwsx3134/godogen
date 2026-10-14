"""Builds assets/ui/title_art.png (640x360) from the game's own generated art: sky, far hills, the wall, the ground,
Erwin mid-slash, the beast titan and Levi diving at its nape.
    uv run --no-project --with pillow python art_src/cover/compose.py
The title screen covers the art (keep-aspect-covered): keep faces between y 40 and 264 (the lower band is shaded)."""
from pathlib import Path
from PIL import Image, ImageEnhance

A = Path(__file__).resolve().parents[2] / "assets"
OUT = A / "ui" / "title_art.png"
W, H = 640, 360
GROUND_Y = 318


def frame(path, index, frames, scale=1):
    sheet = Image.open(A / path).convert("RGBA")
    w = sheet.width // frames
    im = sheet.crop((w * index, 0, w * (index + 1), sheet.height))
    return im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST) if scale > 1 else im


def layer(path):
    return Image.open(A / path).convert("RGBA")


canvas = Image.new("RGBA", (W, H))
canvas.alpha_composite(layer("bg/sky.png").crop((200, 0, 200 + W, H)))
canvas.alpha_composite(layer("bg/far.png").crop((300, 0, 300 + W, 230)), (0, 96))
canvas.alpha_composite(layer("bg/mid.png").crop((0, 0, W, 230)), (0, 94))
canvas = ImageEnhance.Brightness(canvas).enhance(0.85)
canvas.alpha_composite(layer("bg/wall_gate.png"), (-150, -6))
ground = layer("bg/ground.png")
for x in range(0, W, ground.width):
    canvas.alpha_composite(ground, (x, 310))

beast = frame("sprites/beast_body.png", 0, 3)
canvas.alpha_composite(beast, (470, GROUND_Y - beast.height))
levi = frame("sprites/levi.png", 1, 5, 2)
canvas.alpha_composite(levi, (416, -8))
erwin = frame("sprites/erwin_actions.png", 1, 3, 2)
canvas.alpha_composite(erwin, (150, GROUND_Y - erwin.height + 8))
canvas.convert("RGB").save(OUT)
print("wrote", OUT, canvas.size)
