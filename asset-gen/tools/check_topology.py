"""Topology report and wireframe sheets for a model's .blend (source) and .glb (what ships).

Run with Blender 5.1 (Windows path under WSL, see README):
  blender -b --factory-startup --python check_topology.py -- <model.blend> <out_dir>
Prints one JSON line starting with TOPOLOGY and writes <out_dir>/<name>_wire.png (shaded + wireframe,
three views) and <name>_issues.png (red = faces buried inside another part, yellow = sliver
triangles under 12 deg, blue = triangles under 2 cm^2, orange = partly inside another part, i.e.
interpenetrating). Read-only: the .blend is not saved.
"""
import json
import math
import os
import statistics
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = os.path.abspath(args[0]), os.path.abspath(args[1])
NAME = os.path.splitext(os.path.basename(SRC))[0]
os.makedirs(OUT, exist_ok=True)
SLIVER_DEG = 12.0
TINY_AREA = 2e-4  # m^2 (2 cm^2): a few pixels at gameplay distance
TEX = 1024        # baked atlas size, for texel density
PROBE = 0.01      # m outside a face; still inside another part there = buried (not just touching)

bpy.ops.wm.open_mainfile(filepath=SRC)
scn = bpy.context.scene
rig = next((o for o in scn.objects if o.type == "ARMATURE"), None)
if rig and rig.animation_data:
    rig.animation_data.action = None
meshes = [o for o in scn.objects if o.type == "MESH" and not o.hide_render]
obj = max(meshes, key=lambda o: len(o.data.polygons))
me = obj.data

# ---------------------------------------------------------------- source polygons
sizes = [len(p.vertices) for p in me.polygons]
report = {"model": NAME, "objects": len(meshes), "verts": len(me.vertices), "faces": len(me.polygons),
          "tris": sizes.count(3), "quads": sizes.count(4), "ngons": sum(1 for s in sizes if s > 4),
          "max_ngon": max(sizes), "smooth_faces": sum(1 for p in me.polygons if p.use_smooth)}

bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
bm.faces.ensure_lookup_table()
report["non_manifold_edges"] = sum(1 for e in bm.edges if len(e.link_faces) != 2)
report["boundary_edges"] = sum(1 for e in bm.edges if len(e.link_faces) == 1)
valence = [len(v.link_edges) for v in bm.verts]
report["poles_over_8_edges"] = sum(1 for v in valence if v > 8)
report["max_valence"] = max(valence)
uv = bm.loops.layers.uv.active
seams = 0
if uv:
    for e in bm.edges:
        if len(e.link_faces) == 2:
            f0, f1 = e.link_faces
            a = {l.vert.index: l[uv].uv.copy() for l in f0.loops}
            b = {l.vert.index: l[uv].uv.copy() for l in f1.loops}
            if any((a[v.index] - b[v.index]).length > 1e-5 for v in e.verts):
                seams += 1
report["uv_seam_edges"] = seams

# Connected parts (each part was one generated primitive before the join).
part_of = [-1] * len(bm.faces)
parts = []
for f in bm.faces:
    if part_of[f.index] >= 0:
        continue
    stack, members = [f], []
    part_of[f.index] = len(parts)
    while stack:
        g = stack.pop()
        members.append(g.index)
        for e in g.edges:
            for h in e.link_faces:
                if part_of[h.index] < 0:
                    part_of[h.index] = len(parts)
                    stack.append(h)
    parts.append(members)
report["parts"] = len(parts)

# ---------------------------------------------------------------- triangles: slivers, tiny, buried
bm_tri = bm.copy()
bmesh.ops.triangulate(bm_tri, faces=bm_tri.faces)
bm_tri.faces.ensure_lookup_table()
tri_part = []
for f in bm_tri.faces:  # triangulate keeps the source face's vertices; find its part via a vertex
    tri_part.append(None)
vert_part = {}
for pi, members in enumerate(parts):
    for fi in members:
        for v in bm.faces[fi].verts:
            vert_part[v.index] = pi
part_bvh, part_box = [], []
for pi, members in enumerate(parts):
    vs = sorted({v.index for fi in members for v in bm.faces[fi].verts})
    remap = {v: i for i, v in enumerate(vs)}
    co = [bm.verts[v].co.copy() for v in vs]
    polys = [[remap[v.index] for v in bm.faces[fi].verts] for fi in members]
    part_bvh.append(BVHTree.FromPolygons(co, polys))
    part_box.append((Vector([min(c[k] for c in co) for k in range(3)]), Vector([max(c[k] for c in co) for k in range(3)])))


def inside(pi, p):
    lo, hi = part_box[pi]
    if any(p[k] < lo[k] - 1e-4 or p[k] > hi[k] + 1e-4 for k in range(3)):
        return False
    votes = 0
    for d in (Vector((0.577, 0.577, 0.577)), Vector((-0.6, 0.48, -0.64)), Vector((0.31, -0.9, 0.3))):
        hits, o = 0, p.copy()
        for _ in range(64):
            loc, nrm, idx, dist = part_bvh[pi].ray_cast(o, d)
            if loc is None:
                break
            hits += 1
            o = loc + d * 1e-5
        votes += hits % 2
    return votes >= 2


def buried_fraction(pi, pts, normal):
    """Share of sample points (just outside the face) that sit inside some other part."""
    c = sum(pts, Vector()) / len(pts)
    samples = [c] + [c.lerp(p, 0.8) for p in pts] + [c.lerp((pts[i] + pts[i - 1]) / 2, 0.8) for i in range(len(pts))]
    hidden = 0
    for q in samples:
        q = q + normal * PROBE
        if any(inside(k, q) for k in range(len(parts)) if k != pi):
            hidden += 1
    return hidden / len(samples)


min_angles, areas, texel, flags = [], [], [], []
buried_area = total_area = 0.0
partly_buried = 0
for f in bm_tri.faces:
    a, b, c = (v.co for v in f.verts)
    area = f.calc_area()
    angs = []
    for p, q, r in ((a, b, c), (b, c, a), (c, a, b)):
        u, w = q - p, r - p
        angs.append(math.degrees(u.angle(w)) if u.length > 1e-9 and w.length > 1e-9 else 0.0)
    min_angles.append(min(angs))
    areas.append(area)
    total_area += area
    pi = vert_part[f.verts[0].index]
    share = buried_fraction(pi, [a, b, c], f.normal)
    buried_area += area * share
    is_buried = share == 1.0
    if 0.0 < share < 1.0:
        partly_buried += 1
    if uv and area > 1e-9:
        u0, u1, u2 = (l[bm_tri.loops.layers.uv.active].uv for l in f.loops)
        uv_area = abs((u1 - u0).cross(u2 - u0)) / 2
        texel.append(math.sqrt(uv_area / area) * TEX)
    flags.append(2 if is_buried else 1 if min(angs) < SLIVER_DEG else 3 if area < TINY_AREA else 0)

report["tris_total"] = len(bm_tri.faces)
report["sliver_tris"] = sum(1 for m in min_angles if m < SLIVER_DEG)
report["degenerate_tris"] = sum(1 for x in areas if x < 1e-7)
report["tiny_tris"] = sum(1 for x in areas if x < TINY_AREA)
report["buried_tris"] = sum(1 for f in flags if f == 2)
report["partly_buried_tris"] = partly_buried
report["buried_area_pct"] = round(100 * buried_area / total_area, 1)
if texel:
    q = statistics.quantiles(texel, n=10)
    report["texel_px_per_m_p10_median_p90"] = [round(q[0]), round(statistics.median(texel)), round(q[-1])]

# ---------------------------------------------------------------- what ships: GPU vertices after splits
gpu = set()
for poly in me.polygons:
    for li in poly.loop_indices:
        loop = me.loops[li]
        n = me.corner_normals[li].vector if hasattr(me, "corner_normals") else loop.normal
        key = (loop.vertex_index, tuple(round(x, 4) for x in n),
               tuple(round(x, 5) for x in me.uv_layers.active.data[li].uv) if me.uv_layers.active else ())
        gpu.add(key)
report["gpu_vertices"] = len(gpu)
report["gpu_vertex_ratio"] = round(len(gpu) / len(me.vertices), 2)
print("TOPOLOGY " + json.dumps(report))

# ---------------------------------------------------------------- sheets
scn.render.engine = "BLENDER_WORKBENCH"
scn.display.shading.light = "STUDIO"
scn.display.shading.color_type = "MATERIAL"
scn.display.shading.show_cavity = False
scn.render.resolution_x = scn.render.resolution_y = 720
scn.render.film_transparent = False
scn.world = scn.world or bpy.data.worlds.new("W")
scn.display.shading.background_type = "VIEWPORT"
scn.display.shading.background_color = (0.9, 0.9, 0.9)
scn.display.shading.show_object_outline = False
for o in scn.objects:
    if o.type == "MESH" and o is not obj:
        o.hide_render = True


def flat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    return m


base_mat = flat("chk_base", (0.62, 0.64, 0.66, 1))
obj.data.materials.clear()
obj.data.materials.append(base_mat)
for p in obj.data.polygons:
    p.material_index = 0
wire = obj.copy()
wire.data = obj.data.copy()
scn.collection.objects.link(wire)
mod = wire.modifiers.new("wire", "WIREFRAME")
mod.thickness = 0.014
mod.use_replace = True
mod.use_even_offset = False
wire.data.materials.clear()
wire.data.materials.append(flat("chk_wire", (0.03, 0.03, 0.05, 1)))
if wire.parent:  # keep the armature deform; rest pose anyway
    pass

lo = Vector([min((obj.matrix_world @ v.co)[k] for v in me.vertices) for k in range(3)])
hi = Vector([max((obj.matrix_world @ v.co)[k] for v in me.vertices) for k in range(3)])
center = (lo + hi) / 2
span = max(hi - lo) * 1.12
cam = bpy.data.objects.new("chk_cam", bpy.data.cameras.new("chk_cam"))
scn.collection.objects.link(cam)
scn.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = span


def shot(direction, up_z=True):
    cam.location = center + direction.normalized() * span * 3
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y" if up_z else "Z").to_euler()
    path = os.path.join(OUT, "_tmp.png")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path, check_existing=False)
    px = np.array(im.pixels[:]).reshape(720, 720, 4)
    bpy.data.images.remove(im)
    os.remove(path)
    return px


def sheet(name):
    views = [shot(Vector((1, -1.1, 0.75))), shot(Vector((1, 0, 0))), shot(Vector((0, 0, 1)), up_z=False)]
    px = np.hstack(views)
    im = bpy.data.images.new(name, px.shape[1], px.shape[0])
    im.pixels = px.ravel()
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()


sheet(NAME + "_wire")
# Issues: colour faces by the first flagged triangle of each source face (triangulation keeps face order
# within bmesh.ops.triangulate's output mapping only loosely, so colour by geometric test per source face).
mats = [base_mat, flat("chk_sliver", (0.95, 0.8, 0.1, 1)), flat("chk_buried", (0.9, 0.12, 0.1, 1)),
        flat("chk_tiny", (0.15, 0.4, 0.95, 1)), flat("chk_partly", (0.95, 0.5, 0.2, 1))]
obj.data.materials.clear()
for m in mats:
    obj.data.materials.append(m)
for p in obj.data.polygons:
    vs = [me.vertices[i].co for i in p.vertices]
    pi = vert_part[p.vertices[0]]
    share = buried_fraction(pi, [v.copy() for v in vs], p.normal)
    if share == 1.0:
        p.material_index = 2
        continue
    if share > 0.0:
        p.material_index = 4
        continue
    worst = 180.0
    for i in range(len(vs)):
        u, w = vs[i - 1] - vs[i], vs[(i + 1) % len(vs)] - vs[i]
        if u.length > 1e-9 and w.length > 1e-9:
            worst = min(worst, math.degrees(u.angle(w)))
    p.material_index = 1 if (len(vs) == 3 and worst < SLIVER_DEG) else 3 if p.area < TINY_AREA else 0
wire.hide_render = True
sheet(NAME + "_issues")
print("TOPOLOGY_SHEETS", os.path.join(OUT, NAME + "_wire.png"), os.path.join(OUT, NAME + "_issues.png"))
