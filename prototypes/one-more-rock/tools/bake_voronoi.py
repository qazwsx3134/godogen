"""Bake eight repeating Voronoi cells for RockVolume. Run from any directory."""

from itertools import product
from math import atan2, sqrt
from pathlib import Path
from random import Random


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(v, scale):
    return tuple(x * scale for x in v)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    return mul(v, 1 / sqrt(dot(v, v)))


def clip(faces, step, normal, plane):
    clipped = []
    cap = {}
    for neighbor, polygon in faces:
        kept = []
        for a, b in zip(polygon, polygon[1:] + polygon[:1]):
            da, db = dot(normal, a) - plane, dot(normal, b) - plane
            if da <= 0:
                kept.append(a)
            if (da <= 0) != (db <= 0):
                point = add(a, mul(sub(b, a), da / (da - db)))
                kept.append(point)
                cap[tuple(round(x, 9) for x in point)] = point
        if len(kept) >= 3:
            clipped.append((neighbor, kept))
    if len(cap) >= 3:
        points = list(cap.values())
        center = tuple(sum(v[i] for v in points) / len(points) for i in range(3))
        axis = unit(sub(points[0], center))
        vertical = cross(axis, normal)
        points.sort(key=lambda p: atan2(dot(sub(p, center), vertical), dot(sub(p, center), axis)))
        clipped.append((step, points))
    return clipped


def build_cell(key, offsets):
    seeds = []
    center = offsets[key]
    for step in product(range(-2, 3), repeat=3):
        if step == (0, 0, 0):
            continue
        neighbor = add(step, offsets[tuple(x % 2 for x in add(key, step))])
        delta = sub(neighbor, center)
        normal = unit(delta)
        seeds.append((dot(delta, delta), step, normal, dot(normal, mul(add(center, neighbor), 0.5))))

    bounds = [-2.0, 3.0]
    faces = []
    for axis in range(3):
        for side in bounds:
            points = []
            for a, b in ((-2, -2), (-2, 3), (3, 3), (3, -2)):
                vertex = [a, b]
                vertex.insert(axis, side)
                points.append(tuple(vertex))
            faces.append((None, points))
    for _, step, normal, plane in sorted(seeds):
        faces = clip(faces, step, normal, plane)
    assert all(step is not None for step, _ in faces)
    normals = {step: normal for _, step, normal, _ in seeds}
    return [(step, normals[step], points) for step, points in sorted(faces)]


def vector(values, integer=False):
    kind = "Vector3i" if integer else "Vector3"
    numbers = ", ".join(str(x) if integer else f"{x:.6f}" for x in values)
    return f"{kind}({numbers})"


def bake():
    rng = Random(72)
    keys = list(product(range(2), repeat=3))
    sites = {key: tuple(rng.uniform(0.25, 0.75) for _ in range(3)) for key in keys}
    cells = {key: build_cell(key, sites) for key in keys}

    # Shared faces have identical vertices after translation and opposite outward normals.
    for key, faces in cells.items():
        for step, normal, points in faces:
            other = tuple(x % 2 for x in add(key, step))
            reverse = mul(step, -1)
            match = next(face for face in cells[other] if face[0] == reverse)
            assert dot(normal, match[1]) < -0.99999
            assert len(points) == len(match[2])
            assert all(any(dot(sub(v, add(w, step)), sub(v, add(w, step))) < 1e-12 for w in match[2]) for v in points)
            assert max(map(abs, step)) == 1

    lines = [
        'extends RefCounted',
        '',
        '# Baked with tools/bake_voronoi.py. Each face stores neighbor, normal, then clockwise polygon.',
        'const FACES := [',
    ]
    for key in keys:
        lines.append('\t[')
        for step, normal, points in cells[key]:
            vertices = ', '.join(map(vector, points))
            lines.append(f'\t\t[{vector(step, True)}, {vector(normal)}, [{vertices}]],')
        lines.append('\t],')
    lines.append(']')
    (Path(__file__).resolve().parents[1] / 'voronoi_cells.gd').write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    bake()
