"""Check UV triangle bounds, area and positive-area overlaps on the imported GLB.

Run in a disposable Blender scene. Shared edges are not treated as overlaps.
"""
import collections
import math
import sys
from pathlib import Path

import bpy

HERE = Path(r'D:\repo\godot\godogen\docs\86\enemy\boss\rebuild\meshy_refined')
if '__file__' in globals() and Path(__file__).name == 'audit_uv.py':
    HERE = Path(__file__).resolve().parent
if '--out' in sys.argv:
    HERE = Path(sys.argv[sys.argv.index('--out') + 1])
for obj in list(bpy.data.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(HERE / 'boss_meshy_refined.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if len(meshes) != 1 or meshes[0].data.uv_layers.active is None:
    raise RuntimeError('Expected one GLB mesh with a UV map')
mesh = meshes[0].data
mesh.calc_loop_triangles()
uvdata = mesh.uv_layers.active.data
triangles = [tuple(tuple(uvdata[i].uv) for i in tri.loops) for tri in mesh.loop_triangles]


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def area(poly):
    if len(poly) < 3:
        return 0.0
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] -
                   poly[(i + 1) % len(poly)][0] * poly[i][1]
                   for i in range(len(poly)))) * .5


def intersection_area(subject, clip):
    sign = 1 if cross(*clip) >= 0 else -1
    polygon = list(subject)
    for i in range(3):
        a, b = clip[i], clip[(i + 1) % 3]
        previous = polygon
        polygon = []
        if not previous:
            break
        start = previous[-1]
        start_dist = sign * cross(a, b, start)
        for end in previous:
            end_dist = sign * cross(a, b, end)
            if (start_dist >= 0) != (end_dist >= 0):
                t = start_dist / (start_dist - end_dist)
                polygon.append((start[0] + t * (end[0] - start[0]),
                                start[1] + t * (end[1] - start[1])))
            if end_dist >= 0:
                polygon.append(end)
            start, start_dist = end, end_dist
    return area(polygon)


grid = collections.defaultdict(list)
candidate_pairs = set()
areas = []
invalid = 0
for i, tri in enumerate(triangles):
    if any(not math.isfinite(n) or n < -1e-5 or n > 1 + 1e-5 for uv in tri for n in uv):
        invalid += 1
    areas.append(area(tri))
    lo = [max(0, min(63, int(min(uv[axis] for uv in tri) * 64))) for axis in range(2)]
    hi = [max(0, min(63, int(max(uv[axis] for uv in tri) * 64))) for axis in range(2)]
    for x in range(lo[0], hi[0] + 1):
        for y in range(lo[1], hi[1] + 1):
            for other in grid[x, y]:
                candidate_pairs.add((other, i))
            grid[x, y].append(i)
overlaps = [(a, b) for a, b in candidate_pairs
            if intersection_area(triangles[a], triangles[b]) > 1e-10]
zero_area = sum(value < 1e-12 for value in areas)
subpixel_albedo = sum(value * 2048 * 2048 < 1 for value in areas)
subpixel_orm = sum(value * 1024 * 1024 < 1 for value in areas)
print('UV_AUDIT', 'triangles', len(triangles), 'outside', invalid, 'zero_area', zero_area,
      'overlap_pairs', len(overlaps), 'coverage', round(sum(areas), 5),
      'under_one_albedo_texel', subpixel_albedo, 'under_one_orm_texel', subpixel_orm)
if overlaps:
    print('UV_OVERLAP_EXAMPLES', overlaps[:10])
if invalid or zero_area or overlaps:
    raise RuntimeError('UV audit failed')
print('UV_AUDIT_PASS')
