"""Draw the pixel-art frames used by the aquarium's Godot nine-patch styles."""

import random
import struct
import zlib
from pathlib import Path


OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "notebook"


def draw_frame(name, size, width, field, selected=False, leaves=False):
    rng = random.Random(12)
    pixels = [[b"\0" * 4 for _ in range(size)] for _ in range(size)]

    def dot(x, y, color):
        pixels[y][x] = bytes((*color, 255))

    for y in range(size):
        for x in range(size):
            edge_x = min(x, size - 1 - x)
            edge_y = min(y, size - 1 - y)
            edge = min(edge_x, edge_y)
            if edge_x + edge_y < 3:
                continue
            grain = x if edge_y < edge_x else y
            if edge == 0:
                color = (89, 48, 32)
            elif edge < width:
                base = (188, 117, 68) if edge < width - 2 else (145, 79, 43)
                if edge == 1 or (grain + edge * 9) % 23 < 8:
                    base = (227, 158, 96)
                if rng.random() < 0.1:
                    base = (119, 61, 37)
                color = base
            elif selected and edge in (width, width + 1, width + 2):
                color = (255, 248, 184) if edge == width + 1 else (224, 149, 53)
            elif edge == width:
                color = (211, 168, 116)
            else:
                grain = rng.choices([0, -10, -5, 4], [9, 1, 3, 3])[0]
                color = tuple(min(255, value + grain) for value in field)
            dot(x, y, color)

    if leaves:
        sprig = [
            "..........dd.",
            ".........dld.",
            ".......dald..",
            "..dd..daldd..",
            ".daldddad....",
            "..ddldad.....",
            "....daadldd..",
            "...daadalald.",
            "..daad.lddd..",
            "..ad...dd....",
        ]
        colors = {"d": (99, 111, 60), "a": (129, 141, 75), "l": (175, 171, 87)}
        for flip_x, flip_y in ((False, False), (True, False), (False, True), (True, True)):
            for row, line in enumerate(sprig):
                for column, mark in enumerate(line):
                    if mark in colors:
                        x, y = column + width + 2, row + width + 2
                        dot(size - 1 - x if flip_x else x, size - 1 - y if flip_y else y, colors[mark])

    def chunk(tag, data):
        checksum = struct.pack(">I", zlib.crc32(tag + data))
        return struct.pack(">I", len(data)) + tag + data + checksum

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    data = zlib.compress(b"".join(b"\0" + b"".join(row) for row in pixels))
    (OUTPUT / f"{name}.png").write_bytes(
        b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", data) + chunk(b"IEND", b"")
    )


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    draw_frame("leaf_panel", 80, 6, (250, 226, 182), leaves=True)
    draw_frame("panel", 48, 5, (251, 231, 196))
    draw_frame("tile", 44, 4, (251, 229, 190))
    draw_frame("tile_highlight", 44, 4, (255, 222, 150), selected=True)
