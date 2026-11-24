#!/usr/bin/env python3
"""Draw the layered 64 px traveler cels and export an OpenRaster source and game atlas."""

from __future__ import annotations

from dataclasses import dataclass
from math import floor, hypot
from pathlib import Path
from struct import pack
from xml.etree.ElementTree import Element, SubElement, tostring
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile, ZipInfo
from zlib import compress, crc32

CELL = 64
ANCHOR = (32, 57)
TRAVELER_SCALE = 5 / 6
RUN_CELS_PER_STEP = 20
CONTACT_END = 12
RUN_DISTANCE_PER_CEL = 2
WIDTH, HEIGHT = 8 * CELL, 6 * CELL
Point = tuple[int, int]
PALETTE = {
    "outline": "211d2d", "ink_green": "202d3b", "green_dark": "294859",
    "green": "38706d", "green_light": "569185", "green_high": "85aa87",
    "pants_dark": "2c2c43", "pants": "414b65", "pants_high": "617181",
    "boot": "48313b", "boot_light": "79574e", "sole": "a47d60",
    "bag_dark": "533945", "bag": "87533c", "bag_light": "bb8050", "buckle": "e9bd70",
    "scarf_dark": "803640", "scarf": "bf5344", "scarf_high": "ed8052",
    "skin_dark": "a36050", "skin": "d99267", "skin_light": "f6c08d",
    "hair_dark": "2c2531", "hair": "593742", "hair_light": "8a5150",
}
INKS = {name: bytes.fromhex(rgb) + b"\xff" for name, rgb in PALETTE.items()}


class Layer:
    def __init__(self) -> None:
        self.pixels = bytearray(CELL * CELL * 4)

    def pixel(self, x: int, y: int, ink: str) -> None:
        if 0 <= x < CELL and 0 <= y < CELL:
            index = (y * CELL + x) * 4
            self.pixels[index:index + 4] = INKS[ink]

    def polygon(self, points: list[Point], ink: str) -> None:
        for y in range(min(p[1] for p in points), max(p[1] for p in points) + 1):
            for x in range(min(p[0] for p in points), max(p[0] for p in points) + 1):
                inside = False
                previous = points[-1]
                for vertex in points:
                    px, py = previous
                    vx, vy = vertex
                    if (py > y + 0.5) != (vy > y + 0.5):
                        border_x = px + (vx - px) * (y + 0.5 - py) / (vy - py)
                        if x + 0.5 < border_x:
                            inside = not inside
                    previous = vertex
                if inside:
                    self.pixel(x, y, ink)

    def stroke(self, start: Point, end: Point, width: int, ink: str) -> None:
        ax, ay = start
        bx, by = end
        distance = max(hypot(bx - ax, by - ay), 1.0)
        normal = (-(by - ay) / distance * width / 2, (bx - ax) / distance * width / 2)
        nx, ny = normal
        self.polygon([
            (round(ax + nx), round(ay + ny)), (round(bx + nx), round(by + ny)),
            (round(bx - nx), round(by - ny)), (round(ax - nx), round(ay - ny)),
        ], ink)

    def stamp(self, origin: Point, points: list[Point], ink: str) -> None:
        x, y = origin
        self.polygon([(x + px, y + py) for px, py in points], ink)


@dataclass(frozen=True)
class Pose:
    lean: int
    bob: int
    near_leg: tuple[Point, Point]  # knee, heel
    far_leg: tuple[Point, Point]
    near_arm: tuple[Point, Point]  # elbow, wrist
    far_arm: tuple[Point, Point]
    scarf: int = 0


def leg(layer: Layer, hip: Point, joints: tuple[Point, Point], near: bool) -> None:
    knee, heel = joints
    # Shared hip, knee and ankle thickness keep the body proportions through every cel.
    for p, q in [(hip, knee), (knee, heel)]:
        layer.stroke(p, q, 9 if p == hip else 7, "outline")
    tone = "pants" if near else "pants_dark"
    for p, q in [(hip, knee), (knee, heel)]:
        layer.stroke(p, q, 6 if p == hip else 4, tone)
    if near:
        layer.stroke((hip[0] + 1, hip[1]), (knee[0] + 1, knee[1]), 2, "pants_high")
        layer.pixel(knee[0] + 1, knee[1] + 1, "pants_high")
    layer.stamp(heel, [(-3,-4),(3,-4),(4,-1),(8,0),(9,3),(8,4),(-4,4),(-5,2)], "outline")
    layer.stamp(heel, [(-2,-3),(2,-3),(3,0),(7,1),(8,2),(-3,2)], "boot_light" if near else "boot")
    if near:
        layer.stamp(heel, [(-3,2),(8,2),(8,3),(-3,3)], "sole")
        layer.pixel(heel[0] + 1, heel[1] - 1, "buckle")


def arm(layer: Layer, shoulder: Point, joints: tuple[Point, Point], near: bool) -> None:
    elbow, wrist = joints
    layer.stroke(shoulder, elbow, 8, "outline")
    layer.stroke(elbow, wrist, 7, "outline")
    layer.stroke(shoulder, elbow, 5, "green" if near else "green_dark")
    layer.stroke(elbow, wrist, 4, "green_light" if near else "green_dark")
    layer.stamp(wrist, [(-2,-3),(2,-3),(4,-1),(4,2),(2,4),(-2,3),(-3,0)], "outline")
    layer.stamp(wrist, [(-1,-2),(2,-2),(3,0),(2,2),(-1,2),(-2,0)], "skin" if near else "skin_dark")
    if near:
        layer.pixel(wrist[0] + 1, wrist[1] - 1, "skin_light")


def backpack(layer: Layer, at: Point) -> None:
    layer.stamp(at, [(-12,0),(-7,-2),(0,1),(2,8),(0,15),(-10,16),(-14,12),(-15,5)], "outline")
    layer.stamp(at, [(-12,2),(-7,0),(-1,2),(0,8),(-2,13),(-10,14),(-12,11),(-13,5)], "bag")
    layer.stamp(at, [(-12,2),(-7,0),(-2,2),(-3,6),(-9,6),(-13,5)], "bag_light")
    layer.stamp(at, [(-12,9),(-2,8),(-2,13),(-10,14)], "bag_dark")
    layer.stamp(at, [(-8,4),(-6,4),(-6,12),(-8,12)], "buckle")


def torso(layer: Layer, at: Point, lean: int) -> None:
    # The coat leans at the shoulders; the hem remains centered at the hips.
    layer.stamp(at, [(-6,-3),(5,-3),(8,2),(6-lean,12),(4-lean,15),(-5-lean,15),(-8-lean,13),(-8,3)], "outline")
    layer.stamp(at, [(-5,-2),(4,-2),(6,2),(4-lean,11),(3-lean,13),(-5-lean,13),(-6-lean,12),(-6,4)], "green")
    layer.stamp(at, [(-6,4),(-3,2),(-3-lean,11),(-5-lean,13),(-6-lean,12)], "green_dark")
    layer.stamp(at, [(-2,-1),(4,-1),(6,2),(3,5),(-1,3)], "green_light")
    layer.stamp(at, [(-5-lean,10),(5-lean,9),(4-lean,12),(-6-lean,13)], "bag_dark")
    layer.stamp(at, [(1-lean,10),(4-lean,10),(4-lean,12),(1-lean,12)], "buckle")
    layer.pixel(at[0] + 2, at[1] + 6, "green_high")


def head(layer: Layer, at: Point) -> None:
    # Choppy hair, a one-pixel brow, warm cheek and a clear right-facing nose.
    layer.stamp(at, [(-8,-6),(-5,-8),(4,-8),(8,-5),(9,-1),(11,1),(9,4),(7,7),(0,8),(-6,5),(-8,1)], "outline")
    layer.stamp(at, [(-6,-3),(-1,-6),(4,-6),(7,-3),(7,0),(9,1),(7,3),(6,6),(0,7),(-5,4),(-6,0)], "skin")
    layer.stamp(at, [(1,-5),(5,-5),(7,-2),(7,0),(9,1),(6,2),(5,4),(1,2)], "skin_light")
    layer.stamp(at, [(-8,-6),(-5,-8),(4,-8),(8,-5),(8,-3),(6,-2),(4,-5),(2,-3),(-1,-2),(-4,3),(-7,3),(-8,0)], "hair")
    layer.stamp(at, [(-7,-5),(-5,-7),(3,-7),(6,-5),(2,-5),(-2,-4),(-5,-2)], "hair_light")
    layer.stamp(at, [(-8,-4),(-6,-2),(-5,4),(-7,4),(-8,1)], "hair_dark")
    layer.stamp(at, [(-5,0),(-3,-1),(-2,2),(-4,4),(-5,3)], "skin_dark")
    layer.stamp(at, [(3,-1),(7,-1),(7,0),(3,0)], "hair_dark")
    layer.pixel(at[0] + 5, at[1], "outline")
    layer.pixel(at[0] + 6, at[1] + 4, "skin_dark")


def scarf(layer: Layer, at: Point, flutter: int) -> None:
    layer.stamp(at, [(-7,-1),(-2,-2),(6,-2),(8,0),(6,4),(-2,5),(-7,3)], "outline")
    layer.stamp(at, [(-6,0),(-1,-1),(6,-1),(7,0),(5,3),(-1,4),(-5,3)], "scarf")
    layer.stamp(at, [(-5,0),(6,-1),(6,1),(-4,2)], "scarf_high")
    layer.stamp(at, [(-7,1),(-10,2-flutter),(-17,4-flutter),(-19,7-flutter),(-13,7-flutter),(-8,5),(-5,4)], "scarf_dark")
    layer.stamp(at, [(-8,2),(-11,3-flutter),(-17,5-flutter),(-14,6-flutter),(-9,5)], "scarf")


LAYER_NAMES = ["Far boot and leg", "Far sleeve", "Backpack", "Coat", "Near boot and leg",
               "Head and hair", "Scarf", "Near sleeve"]


def draw_pose(pose: Pose) -> list[Layer]:
    far_leg, far_arm, bag, coat, near_leg, face, neckwear, near_arm = [Layer() for _ in LAYER_NAMES]
    lean, bob = pose.lean, pose.bob
    shoulder = (32 + lean, 27 + bob)
    leg(far_leg, (33, 39 + bob), pose.far_leg, False)
    arm(far_arm, (35 + lean, 28 + bob), pose.far_arm, False)
    backpack(bag, (30 + lean, 25 + bob))
    torso(coat, shoulder, lean)
    leg(near_leg, (30, 39 + bob), pose.near_leg, True)
    head(face, (34 + lean, 17 + bob))
    scarf(neckwear, (34 + lean, 23 + bob), pose.scarf)
    arm(near_arm, (28 + lean, 28 + bob), pose.near_arm, True)
    return [far_leg, far_arm, bag, coat, near_leg, face, neckwear, near_arm]


RUN_KEY_CELS = (0, 5, 9, CONTACT_END, 16, RUN_CELS_PER_STEP)


def sample_track(keys: list[tuple[int, ...]], cel: int) -> tuple[int, ...]:
    for index, end in enumerate(RUN_KEY_CELS[1:]):
        if cel <= end:
            start = RUN_KEY_CELS[index]
            weight = (cel - start) / (end - start)
            return tuple(round(a + (b - a) * weight) for a, b in zip(keys[index], keys[index + 1], strict=True))
    raise ValueError(f"Run cel {cel} is outside the step")


def sample_joints(keys: list[tuple[int, ...]], cel: int) -> tuple[Point, Point]:
    ax, ay, bx, by = sample_track(keys, cel)
    return (ax, ay), (bx, by)


def run_cycle() -> list[Pose]:
    # Each step blends from plant through push-off into the opposite leg's contact.
    support_leg = [(39,44,46,53), (36,46,34,53), (30,46,24,53), (25,45,17,53),
                   (23,44,14,48), (25,44,17,48)]
    swing_leg = [(25,44,17,48), (25,42,24,45), (39,43,31,48), (43,42,37,47),
                 (44,45,41,48), (39,44,46,53)]
    back_swing = [(21,34,23,31), (23,35,24,32), (31,36,35,33), (39,34,44,28),
                  (40,33,45,26), (39,33,44,27)]
    forward_swing = [(39,33,44,27), (38,35,43,31), (32,36,35,32), (26,34,25,30),
                     (23,33,23,29), (21,34,23,31)]
    poses: list[Pose] = []
    for near_supports in (True, False):
        for cel in range(RUN_CELS_PER_STEP):
            planted, lifted = sample_joints(support_leg, cel), sample_joints(swing_leg, cel)
            if cel <= CONTACT_END:
                # Two rendered pixels of backward sole travel per cel cancel body travel.
                planted = planted[0], (round(46 - cel * RUN_DISTANCE_PER_CEL / TRAVELER_SCALE), 53)
            back_arm = sample_joints(back_swing, cel)
            forward_arm = sample_joints(forward_swing, cel)
            bob, flutter = sample_track([(0,3),(1,2),(1,4),(0,5),(-1,3),(0,3)], cel)
            if near_supports:
                poses.append(Pose(3, bob, planted, lifted, back_arm, forward_arm, flutter))
            else:
                poses.append(Pose(3, bob, lifted, planted, forward_arm, back_arm, flutter))
    return poses


def idle_and_air() -> list[Pose]:
    idle = [Pose(0, bob, ((30,46),(29,53)), ((36,46),(35,53)),
                 ((28,35),(30,39)), ((37,34),(38,38)), flutter)
            for bob, flutter in [(0,0), (-1,1), (-1,0), (0,-1)]]
    rise = Pose(1, 0, ((39,44),(37,52)), ((26,45),(24,53)), ((33,30),(43,22)), ((24,33),(22,29)), 4)
    apex = Pose(0, 0, ((38,44),(36,52)), ((26,46),(25,53)), ((29,33),(21,31)), ((41,30),(45,26)), 5)
    fall = Pose(0, 0, ((34,47),(35,53)), ((29,47),(27,53)), ((26,31),(20,26)), ((40,31),(46,26)), 3)
    return [*idle, rise, apex, fall]


def png(pixels: bytearray, width: int, height: int) -> bytes:
    def chunk(name: bytes, body: bytes) -> bytes:
        return pack(">I", len(body)) + name + body + pack(">I", crc32(name + body))
    stride = width * 4
    scanlines = b"".join(b"\x00" + pixels[start:start + stride] for start in range(0, len(pixels), stride))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", compress(scanlines, 9)) + chunk(b"IEND", b""))


def thumbnail(pixels: bytearray) -> bytes:
    half_size = bytearray()
    for y in range(0, HEIGHT, 2):
        for x in range(0, WIDTH, 2):
            offset = (y * WIDTH + x) * 4
            half_size.extend(pixels[offset:offset + 4])
    return png(half_size, WIDTH // 2, HEIGHT // 2)


def write_entry(archive: ZipFile, name: str, data: bytes | str, compression: int = ZIP_DEFLATED) -> None:
    entry = ZipInfo(name)
    entry.compress_type = compression
    archive.writestr(entry, data)


def sampling_axis(anchor: int) -> list[tuple[int, int]]:
    pairs = [(pixel, floor(anchor + (pixel + 0.5 - anchor) / TRAVELER_SCALE)) for pixel in range(CELL)]
    return [(dest, src) for dest, src in pairs if 0 <= src < CELL]


def save_frames(folder: Path) -> None:
    sample_x, sample_y = (sampling_axis(anchor) for anchor in ANCHOR)
    originals = [bytearray(WIDTH * HEIGHT * 4) for _ in LAYER_NAMES]
    for index, pose in enumerate(run_cycle() + idle_and_air()):
        cel_x, cel_y = index % 8 * CELL, index // 8 * CELL
        for atlas, layer in zip(originals, draw_pose(pose), strict=True):
            for y, src_y in sample_y:
                for x, src_x in sample_x:
                    start = ((cel_y + y) * WIDTH + cel_x + x) * 4
                    origin = (src_y * CELL + src_x) * 4
                    atlas[start:start + 4] = layer.pixels[origin:origin + 4]
    merged = bytearray(WIDTH * HEIGHT * 4)
    for layer in originals:
        for offset in range(0, len(layer), 4):
            if layer[offset + 3]:
                merged[offset:offset + 4] = layer[offset:offset + 4]
    composite = png(merged, WIDTH, HEIGHT)
    folder.mkdir(exist_ok=True)
    (folder / "traveler.png").write_bytes(composite)
    xml = Element("image", w=str(WIDTH), h=str(HEIGHT), name="Traveler", version="0.0.6")
    stack = SubElement(xml, "stack")
    with ZipFile(folder / "traveler.ora", "w", compression=ZIP_DEFLATED) as archive:
        write_entry(archive, "mimetype", "image/openraster", ZIP_STORED)
        for index in reversed(range(len(LAYER_NAMES))):
            source = f"data/layer{index}.png"
            SubElement(stack, "layer", {"name": LAYER_NAMES[index], "src": source, "x": "0", "y": "0",
                                       "opacity": "1.0", "visibility": "visible", "composite-op": "svg:src-over"})
            write_entry(archive, source, png(originals[index], WIDTH, HEIGHT))
        write_entry(archive, "stack.xml", tostring(xml, encoding="utf-8", xml_declaration=True))
        write_entry(archive, "mergedimage.png", composite)
        write_entry(archive, "Thumbnails/thumbnail.png", thumbnail(merged))


if __name__ == "__main__":
    save_frames(Path(__file__).resolve().parents[1] / "art" / "traveler")
