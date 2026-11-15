"""Audit the editable Boss source in Blender, without modifying the scene.

Run against boss.blend with --python, or after build_boss.py in the same session.
The contact graph is a tolerance-based assembly check, not a boolean union test.
"""
import collections
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def belongs_to_boss(obj):
    while obj is not None:
        if obj.name == 'Boss_40m':
            return True
        obj = obj.parent
    return False


parts = [o for o in bpy.context.scene.objects if o.type == 'MESH' and belongs_to_boss(o)]
if not parts:
    raise RuntimeError('No editable meshes found under Boss_40m')
bpy.context.view_layer.update()
counts = collections.Counter()
bad_parts = []
entries = []
surfaces = []
for ob in parts:
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    boundary = sum(len(e.link_faces) == 1 for e in bm.edges)
    nonmanifold = sum(len(e.link_faces) != 2 for e in bm.edges)
    nonmanifold_vertices = sum(not v.is_manifold for v in bm.verts)
    inconsistent = sum(e.is_manifold and not e.is_contiguous for e in bm.edges)
    loose = sum(not v.link_faces for v in bm.verts)
    # Consistent winding alone still permits an entirely inside-out component.
    signed_volume = bm.calc_volume(signed=True) * ob.matrix_world.to_3x3().determinant()
    inward = int(signed_volume <= 1e-12)
    bm.free()
    ob.data.calc_loop_triangles()
    verts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    triangles = [tuple(t.vertices) for t in ob.data.loop_triangles]
    nonfinite = sum(not all(math.isfinite(c) for c in v) for v in verts)
    degenerate = sum((verts[b] - verts[a]).cross(verts[c] - verts[a]).length < 2e-9
                     for a, b, c in triangles)
    tree = BVHTree.FromPolygons(verts, triangles, all_triangles=True, epsilon=0)
    # Non-neighbour triangles on the same closed component should not intersect.
    crossings = sum(1 for i, j in tree.overlap(tree)
                    if i < j and not set(triangles[i]).intersection(triangles[j]))
    values = dict(boundary=boundary, nonmanifold=nonmanifold, nonmanifold_vertices=nonmanifold_vertices,
                  inconsistent=inconsistent, inward=inward, loose=loose, degenerate=degenerate,
                  nonfinite=nonfinite, self_intersections=crossings)
    counts.update(values)
    counts.update(parts=1, triangles=len(triangles), vertices=len(verts))
    if any(values.values()):
        bad_parts.append((ob.name, {k: v for k, v in values.items() if v}))
    lo = Vector(tuple(min(v[i] for v in verts) for i in range(3)))
    hi = Vector(tuple(max(v[i] for v in verts) for i in range(3)))
    # A 5 mm tolerance is small at this 40 m scale, but should not be read as a weld.
    contact_tree = BVHTree.FromPolygons(verts, triangles, all_triangles=True, epsilon=.005)
    entries.append((ob, contact_tree, lo, hi))
    strict_tree = BVHTree.FromPolygons(verts, triangles, all_triangles=True, epsilon=.00001)
    surfaces.append((ob.name, verts, triangles, strict_tree, lo, hi))

parents = list(range(len(entries)))


def find(i):
    while parents[i] != i:
        parents[i] = parents[parents[i]]
        i = parents[i]
    return i


def inside(tree, point):
    votes = 0
    for direction in (Vector((.577, .577, .577)), Vector((-.6, .48, -.64)),
                      Vector((.31, -.9, .3))):
        pos = point.copy()
        hits = 0
        for _ in range(100):
            loc, _, _, _ = tree.ray_cast(pos, direction)
            if loc is None:
                break
            hits += 1
            pos = loc + direction * .0001
        votes += hits % 2
    return votes >= 2


candidates = 0
for i, (_, at, alo, ahi) in enumerate(entries):
    for j in range(i):
        _, bt, blo, bhi = entries[j]
        if any(ahi[k] + .01 < blo[k] or bhi[k] + .01 < alo[k] for k in range(3)):
            continue
        candidates += 1
        intersects = bool(at.overlap(bt))
        if not intersects:
            a_in_box = all(alo[k] >= blo[k] - .01 and ahi[k] <= bhi[k] + .01 for k in range(3))
            b_in_box = all(blo[k] >= alo[k] - .01 and bhi[k] <= ahi[k] + .01 for k in range(3))
            intersects = ((a_in_box and inside(bt, (alo + ahi) * .5)) or
                          (b_in_box and inside(at, (blo + bhi) * .5)))
        if intersects:
            parents[find(i)] = find(j)

groups = collections.defaultdict(list)
for i, (ob, _, _, _) in enumerate(entries):
    groups[find(i)].append(ob.name)
ordered = sorted(groups.values(), key=len, reverse=True)
lo = tuple(min(e[2][i] for e in entries) for i in range(3))
hi = tuple(max(e[3][i] for e in entries) for i in range(3))
coplanar = []
for i, (aname, av, af, at, alo, ahi) in enumerate(surfaces):
    for bname, bv, bf, bt, blo, bhi in surfaces[:i]:
        if any(ahi[k] + .0001 < blo[k] or bhi[k] + .0001 < alo[k] for k in range(3)):
            continue
        hits = 0
        for ai, bi in at.overlap(bt):
            va = [av[n] for n in af[ai]]
            vb = [bv[n] for n in bf[bi]]
            na = (va[1] - va[0]).cross(va[2] - va[0])
            nb = (vb[1] - vb[0]).cross(vb[2] - vb[0])
            if na.length < 1e-10 or nb.length < 1e-10:
                continue
            na.normalize()
            nb.normalize()
            if abs(na.dot(nb)) > .99999 and max(abs((v - va[0]).dot(na)) for v in vb) < .0001:
                hits += 1
        if hits:
            coplanar.append((aname, bname, hits))
print('SOURCE_COUNTS', dict(counts))
print('SOURCE_BOUNDS', 'min', lo, 'max', hi, 'dimensions', tuple(hi[i] - lo[i] for i in range(3)))
print('SOURCE_CONTACT_GRAPH', 'groups', len(ordered), 'largest', len(ordered[0]), 'candidates', candidates)
print('SOURCE_NEAR_COPLANAR_CANDIDATES', len(coplanar), 'triangle_pairs', sum(x[2] for x in coplanar))
for candidate in coplanar:
    print('SOURCE_WARN_COPLANAR', *candidate)
for item in bad_parts:
    print('SOURCE_BAD_PART', *item)
for group in ordered[1:]:
    print('SOURCE_DISCONNECTED', ', '.join(group))
if bad_parts or len(ordered) != 1 or not 39.9 <= hi[1] - lo[1] <= 40.1 or not -.02 <= lo[2] <= .1:
    raise RuntimeError('Boss source audit failed; see SOURCE_BAD_PART or SOURCE_DISCONNECTED')
print('SOURCE_AUDIT_PASS')
