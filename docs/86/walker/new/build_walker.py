# Build the walker from new/three-view.png + new/top-and-45.png, bake one albedo atlas, export GLB.
# Run: blender.exe -b --factory-startup --python build_walker.py -- <out_dir(windows path)>
# Units: meters. Nose points to Blender -Y (= glTF +Z = Godot MODEL_FRONT). Origin = ground, between feet.
# Proportions read off the side view (3.0 m tall); lateral spread is a compromise between the
# front view (feet tucked in) and the top / 45-degree views (feet splayed out).
import bpy, bmesh, sys, os, math
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]
TEX = 2048  # mobile: 2K albedo / normal / ORM + 1K emission, one material -> one draw call per part

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
col = scn.collection

# ---------- materials (procedural; baked later) ----------
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m

def ramp(nd, lk, src, a, b, ca=(0, 0, 0, 1), cb=(1, 1, 1, 1)):
    r = nd.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = a, ca
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = b, cb
    lk.new(src, r.inputs[0])
    return r

def noise(nd, lk, pos, scale, detail=6, rough=0.6):
    n = nd.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    lk.new(pos, n.inputs["Vector"])
    return n

def mix(nd, lk, fac, a, b, blend="MIX"):
    x = nd.new("ShaderNodeMix")
    x.data_type, x.blend_type = "RGBA", blend
    for s, v in ((x.inputs[0], fac), (x.inputs[6], a), (x.inputs[7], b)):
        if isinstance(v, (tuple, list, float, int)):
            s.default_value = v
        else:
            lk.new(v, s)
    return x.outputs[2]

def worn(name, base, chips, rust=None, edge=None, seams=None):
    """Base color + noise chips [(color, scale, threshold)], rust, worn edges, painted plate seams,
    AO + grime. Normal = rounded-edge bevel (+ seam grooves); only the normal-map bake reads it."""
    m = new_mat(name)
    nt = m.node_tree; nd, lk = nt.nodes, nt.links
    geo = nd.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    bev = nd.new("ShaderNodeBevel"); bev.samples = 8; bev.inputs["Radius"].default_value = 0.012
    nrm = bev.outputs["Normal"]
    c = base
    if edge:  # bevel normal drifts from the face normal only on edges -> edge mask
        dot = nd.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
        lk.new(nrm, dot.inputs[0]); lk.new(geo.outputs["Normal"], dot.inputs[1])
        em = ramp(nd, lk, dot.outputs["Value"], 0.93, 0.985, (1, 1, 1, 1), (0, 0, 0, 1))
        en = ramp(nd, lk, noise(nd, lk, pos, 14, 6, 0.7).outputs["Fac"], 0.4, 0.6)
        c = mix(nd, lk, mix(nd, lk, 1.0, em.outputs[0], en.outputs[0], "MULTIPLY"), c, edge)
    if seams:  # straight plate seams: planes every seams[0] m along Y, every seams[1] m along Z
        sep = nd.new("ShaderNodeSeparateXYZ"); lk.new(pos, sep.inputs[0])
        h = None
        for axis, period in zip("YZ", seams):
            w = nd.new("ShaderNodeMath"); w.operation = "PINGPONG"; w.inputs[1].default_value = period / 2
            lk.new(sep.outputs[axis], w.inputs[0])
            r = ramp(nd, lk, w.outputs[0], 0.004, 0.009).outputs[0]
            h = r if h is None else mix(nd, lk, 1.0, h, r, "MULTIPLY")
        c = mix(nd, lk, 1.0, c, ramp(nd, lk, h, 0, 1, (0.45, 0.43, 0.4, 1)).outputs[0], "MULTIPLY")
        bump = nd.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.8; bump.inputs["Distance"].default_value = 0.004
        lk.new(h, bump.inputs["Height"]); lk.new(nrm, bump.inputs["Normal"]); nrm = bump.outputs["Normal"]
    lk.new(nrm, nd["Principled BSDF"].inputs["Normal"])
    for chip_col, sc, th in chips:
        n = noise(nd, lk, pos, sc, 10, 0.72)
        c = mix(nd, lk, ramp(nd, lk, n.outputs["Fac"], th, th + 0.02).outputs[0], c, chip_col)
    if rust:
        rm = ramp(nd, lk, noise(nd, lk, pos, 2.5, 4, 0.5).outputs["Fac"], 0.6, 0.72)
        c = mix(nd, lk, rm.outputs[0], c, rust)
    grm = ramp(nd, lk, noise(nd, lk, pos, 1.2, 3, 0.5).outputs["Fac"], 0.35, 0.75,
               (0.75, 0.72, 0.67, 1), (1, 1, 1, 1))
    c = mix(nd, lk, 1.0, c, grm.outputs[0], "MULTIPLY")
    ao = nd.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.25
    c = mix(nd, lk, 1.0, c, ramp(nd, lk, ao.outputs["AO"], 0.0, 1.0, (0.35, 0.33, 0.3, 1)).outputs[0], "MULTIPLY")
    lk.new(c, nd["Principled BSDF"].inputs["Base Color"])
    return m

GREY_CAMO = (0.42, 0.43, 0.45, 1)
PAINT = worn("Paint", (0.80, 0.73, 0.58, 1), [(GREY_CAMO, 2.5, 0.56), ((0.2, 0.19, 0.18, 1), 11, 0.66)],
             edge=(0.3, 0.3, 0.31, 1), seams=(0.45, 0.32))
METAL = worn("Metal", (0.17, 0.175, 0.18, 1), [((0.36, 0.36, 0.37, 1), 9, 0.62)], rust=(0.24, 0.12, 0.06, 1),
             edge=(0.42, 0.42, 0.43, 1), seams=(0.6, 0.45))
STEEL = worn("Steel", (0.5, 0.52, 0.54, 1), [((0.3, 0.3, 0.31, 1), 8, 0.64)], rust=(0.3, 0.17, 0.08, 1),
             edge=(0.75, 0.76, 0.78, 1))
RUST = worn("Rust", (0.2, 0.13, 0.09, 1), [((0.32, 0.3, 0.28, 1), 7, 0.6)], edge=(0.4, 0.36, 0.32, 1))
GLOW = new_mat("Glow")
GLOW.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.04, 0.02, 1)
FINAL = {  # (metallic, roughness, emission rgb)
    "Paint": (0.0, 0.72, None), "Metal": (0.65, 0.5, None), "Steel": (0.85, 0.35, None),
    "Rust": (0.4, 0.8, None), "Glow": (0.0, 0.3, (1.0, 0.05, 0.02)),
}

# ---------- geometry helpers (all built in world space) ----------
def obj_from_bm(bm, name, mat, smooth=False, bevel=0.0, sharp=40):
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel, segments=1,
                        affect="EDGES", profile=0.5, clamp_overlap=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    return o

def hull_pts(points, name, mat, bevel=0.015, smooth=False, sharp=40):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=res["geom_interior"] + res["geom_unused"], context="VERTS")
    if not smooth:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    return obj_from_bm(bm, name, mat, smooth=smooth, bevel=bevel, sharp=sharp)

def rings(profile, n=12):
    """Elliptic cross-sections along Y: (y, half_width, z_bottom, z_top) -> point cloud."""
    pts = []
    for y, hw, zb, zt in profile:
        zc, rz = (zb + zt) / 2, (zt - zb) / 2
        pts += [(hw * math.cos(a), y, zc + rz * math.sin(a))
                for a in (2 * math.pi * i / n for i in range(n))]
    return pts

def oriented(a, b, hint=Vector((0, 0, 1))):
    """Matrix placing local +Z along a->b, centered at midpoint."""
    a, b = Vector(a), Vector(b)
    z = (b - a).normalized()
    hint = hint if abs(z.dot(hint)) < 0.95 else Vector((1, 0, 0))
    x = hint.cross(z).normalized(); y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = (a + b) / 2
    return m, (b - a).length

def box(name, size, loc, mat, bevel=0.02):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((*size, 1)))
    return obj_from_bm(bm, name, mat, bevel=bevel)

def bar(name, a, b, w, d, mat, bevel=0.025, hint=Vector((0, 0, 1)), taper=1.0):
    m, L = oriented(a, b, hint)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=m @ Matrix.Diagonal((w, d, L, 1)))
    if taper != 1.0:  # shrink the b-end
        end = m @ Vector((0, 0, L / 2))
        for v in bm.verts:
            if (m.inverted() @ v.co).z > 0:
                v.co = end + (v.co - end) * taper
    return obj_from_bm(bm, name, mat, bevel=bevel)

def cyl(name, a, b, r, mat, seg=16, r2=None, smooth=True):
    m, L = oriented(a, b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=L, matrix=m)
    return obj_from_bm(bm, name, mat, smooth=smooth and seg > 8)

def ball(name, c, r, mat):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r, matrix=Matrix.Translation(c))
    return obj_from_bm(bm, name, mat, smooth=True)

def part(name, objs, pivot, parent=None):
    """Join objs into one object whose origin sits at pivot; parent keeps world placement."""
    for o in objs[1:]:
        for mt in o.data.materials:
            if mt.name not in objs[0].data.materials:
                objs[0].data.materials.append(mt)
    ctx = {"active_object": objs[0], "selected_editable_objects": objs, "object": objs[0]}
    with bpy.context.temp_override(**ctx):
        bpy.ops.object.join()
    o = objs[0]; o.name = o.data.name = name
    pivot = Vector(pivot)
    o.data.transform(Matrix.Translation(-pivot))
    o.location = pivot
    if parent:
        o.parent = parent
        o.location = pivot - parent.matrix_world.translation
        o.matrix_parent_inverse.identity()
        bpy.context.view_layer.update()
    return o

X = Vector((1, 0, 0))
Y = Vector((0, 1, 0))
Z = Vector((0, 0, 1))
EDGE = worn("Edge", (0.78, 0.8, 0.82, 1), [((0.55, 0.56, 0.58, 1), 12, 0.62)])
BORE = worn("Bore", (0.02, 0.02, 0.02, 1), [])
FINAL.update({"Edge": (0.95, 0.25, None), "Bore": (0.0, 0.9, None)})

def bezier(p0, c, p2, n):
    return [p0 * (1 - t) ** 2 + c * 2 * (1 - t) * t + p2 * t * t for t in (i / (n - 1) for i in range(n))]

def tube(name, pts, sizes, mat, hint, n=10, square=0.6):
    """Sweep a rounded-rect section (w along hint, d across) through pts; sizes[i] = (w, d)."""
    bm = bmesh.new()
    loops = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = (hint - t * hint.dot(t)).normalized(); b = t.cross(a)
        w, d = sizes[i]
        ring = []
        for k in range(n):
            ang = 2 * math.pi * (k + 0.5) / n
            ca, sa = math.cos(ang), math.sin(ang)
            ca = math.copysign(abs(ca) ** square, ca); sa = math.copysign(abs(sa) ** square, sa)
            ring.append(bm.verts.new(p + a * (w / 2 * ca) + b * (d / 2 * sa)))
        loops.append(ring)
    for r0, r1 in zip(loops, loops[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    bm.faces.new(list(reversed(loops[0]))); bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, name, mat, smooth=True, sharp=50)

def prism(name, yz, hw, mat, bevel=0.02, x0=0.0):
    """Convex side profile [(y, z)] extruded across x0-hw .. x0+hw."""
    return hull_pts([(x0 + s * hw, y, z) for y, z in yz for s in (-1, 1)], name, mat, bevel)

def band(name, y, hw, zb, zt, mat, thick=0.07):
    """Dark trim ring: a thin elliptic slice slightly larger than the shell it wraps."""
    return hull_pts(rings([(y - thick / 2, hw, zb, zt), (y + thick / 2, hw, zb, zt)], 16),
                    name, mat, 0, smooth=True, sharp=60)

def disc(name, c, axis, r, t, mat, seg=16):
    c = Vector(c)
    return cyl(name, c - axis * t / 2, c + axis * t / 2, r, mat, seg)

def bolts(prefix, c, axis, r, mat, k=5):
    """Ring of bolt heads on a joint disc face."""
    axis = axis.normalized()
    u = (Z if abs(axis.dot(Z)) < 0.9 else X).cross(axis).normalized(); v = axis.cross(u)
    return [disc(f"{prefix}{i}", Vector(c) + (u * math.cos(a) + v * math.sin(a)) * r, axis, 0.025, 0.03, STEEL, 6)
            for i, a in enumerate(2 * math.pi * j / k for j in range(k))]

LEGS = []
for sx, sy, tag in ((1, -1, "FL"), (-1, -1, "FR"), (1, 1, "BL"), (-1, 1, "BR")):
    hip = Vector((sx * 0.82, sy * 0.72, 1.6))
    knee = Vector((sx * 1.35, sy * 1.3, 2.0))
    out = Vector((knee.x - hip.x, knee.y - hip.y, 0)).normalized()  # outward, horizontal
    LEGS.append((tag, hip, knee, Vector((sx * 1.75, sy * 2.15, 0.0)), out, out.cross(Z).normalized()))

# ---------- root ----------
root = bpy.data.objects.new("Walker", None); col.objects.link(root)

# ---------- hull: low head with the eye in front, raised carapace behind ----------
head = hull_pts(rings([
    (-1.46, 0.20, 1.40, 1.60), (-1.36, 0.42, 1.30, 1.76), (-1.10, 0.56, 1.26, 1.84),
    (-0.70, 0.60, 1.26, 1.86), (-0.40, 0.55, 1.30, 1.82),
], 16), "head", PAINT, 0, smooth=True, sharp=50)
carapace = hull_pts(rings([
    (-0.75, 0.45, 1.45, 1.86), (-0.40, 0.66, 1.30, 2.10), (0.30, 0.72, 1.28, 2.22),
    (0.90, 0.66, 1.30, 2.20), (1.20, 0.50, 1.38, 2.05), (1.32, 0.30, 1.50, 1.85),
], 16), "carapace", PAINT, 0, smooth=True, sharp=50)
trims = [
    band("band_carapace", -0.43, 0.68, 1.27, 2.13, METAL),
    band("band_face", -1.31, 0.45, 1.27, 1.79, METAL, 0.05),
    band("band_rear", 1.18, 0.53, 1.35, 2.08, METAL, 0.05),
    *[bar(f"trim{s}", (s * 0.66, -0.4, 1.74), (s * 0.69, 1.05, 1.8), 0.05, 0.06, METAL, 0.01) for s in (-1, 1)],
    *[bar(f"headtrim{s}", (s * 0.55, -1.2, 1.6), (s * 0.58, -0.45, 1.62), 0.05, 0.05, METAL, 0.01) for s in (-1, 1)],
]
face = [
    hull_pts(rings([(-1.49, 0.17, 1.39, 1.61), (-1.43, 0.25, 1.33, 1.67)], 16), "faceplate", METAL, 0, True),
    cyl("eye_ring", (0, -1.46, 1.5), (0, -1.53, 1.5), 0.115, METAL, 16),
    cyl("eye", (0, -1.52, 1.5), (0, -1.555, 1.5), 0.08, GLOW, 16),
]
roof = [
    box("roof_vent", (0.26, 0.14, 0.05), (0.32, 0.55, 2.2), METAL, 0.01),
    *[cyl(f"cable{s}", (s * 0.25, -0.35, 2.08), (s * 0.3, 0.05, 2.22), 0.03, METAL, 8) for s in (-1, 1)],
]
under = [
    box("belly", (0.8, 2.0, 0.28), (0, 0.05, 1.12), METAL),
    box("chin", (0.5, 0.45, 0.22), (0, -1.05, 1.2), METAL),
    cyl("belly_cyl", (0, -0.9, 1.0), (0, 0.9, 1.0), 0.12, METAL, 12),
    *[cyl(f"tank{s}", (s * 0.5, -0.05, 1.12), (s * 0.5, 0.45, 1.12), 0.12, PAINT, 12) for s in (-1, 1)],
    *[ball(f"tankcap{s}{e}", (s * 0.5, e, 1.12), 0.12, PAINT) for s in (-1, 1) for e in (-0.05, 0.45)],
    *[cyl(f"hyd{s}{i}", (s * 0.28, -0.7 + i * 0.6, 1.02), (s * 0.4, -0.35 + i * 0.6, 1.28), 0.045, STEEL, 8)
      for s in (-1, 1) for i in range(3)],
    *[cyl(f"hose{s}", (s * 0.38, -0.9, 1.25), (s * 0.6, 0.6, 1.0), 0.035, METAL, 8) for s in (-1, 1)],
]
tail = [box(f"tail{s}", (0.14, 0.04, 0.08), (s * 0.24, 1.33, 1.52), GLOW, 0.005) for s in (-1, 1)]
mech = [
    *bolts("facebolt", (0, -1.47, 1.5), Y, 0.165, STEEL, k=6),
    *[cyl(f"sublens_h{s}", (s * 0.17, -1.4, 1.6), (s * 0.17, -1.47, 1.6), 0.04, METAL, 10) for s in (-1, 1)],
    *[cyl(f"sublens{s}", (s * 0.17, -1.47, 1.6), (s * 0.17, -1.48, 1.6), 0.026, GLOW, 8) for s in (-1, 1)],
    *[box(f"headvent{s}{i}", (0.03, 0.2, 0.025), (s * 0.575, -0.95, 1.46 + i * 0.07), BORE, 0.004)
      for s in (-1, 1) for i in range(3)],
    *[disc(f"trimbolt{s}{i}", (s * 0.71, -0.3 + i * 0.26, 1.77), X, 0.025, 0.03, STEEL, 6)
      for s in (-1, 1) for i in range(6)],
    *[c for s in (-1, 1) for c in (  # grab handles on the carapace
        cyl(f"grip{s}a", (s * 0.35, -0.12, 2.08), (s * 0.35, -0.12, 2.16), 0.018, STEEL, 6),
        cyl(f"grip{s}b", (s * 0.35, 0.12, 2.08), (s * 0.35, 0.12, 2.16), 0.018, STEEL, 6),
        cyl(f"grip{s}c", (s * 0.35, -0.12, 2.16), (s * 0.35, 0.12, 2.16), 0.018, STEEL, 6))],
    box("deck_grille", (0.5, 0.28, 0.03), (0, 1.0, 2.16), METAL, 0.008),
    *[box(f"deckfin{i}", (0.46, 0.025, 0.04), (0, 0.9 + i * 0.05, 2.19), STEEL, 0.003) for i in range(5)],
    cyl("antenna_base", (-0.42, 0.85, 2.08), (-0.42, 0.85, 2.2), 0.045, METAL, 8),
    cyl("antenna", (-0.42, 0.85, 2.2), (-0.42, 0.95, 3.1), 0.009, STEEL, 6),
    *[cyl(f"exhaust{s}", (s * 0.2, 1.18, 1.45), (s * 0.24, 1.42, 1.62), 0.045, METAL, 10) for s in (-1, 1)],
    *[disc(f"exhaust_hole{s}", (s * 0.242, 1.425, 1.623), Vector((0.04, 0.24, 0.17)).normalized(), 0.03, 0.01, BORE, 8)
      for s in (-1, 1)],
    box("gearbox", (0.42, 0.34, 0.24), (0, 0.65, 0.92), METAL, 0.02),
    *[box(f"gearfin{i}", (0.46, 0.025, 0.2), (0, 0.52 + i * 0.065, 0.92), METAL, 0.003) for i in range(5)],
    *[cyl(f"cable{i}", (-0.12 + i * 0.08, -0.85, 0.97), (-0.12 + i * 0.08, 0.45, 0.95), 0.022, BORE, 6)
      for i in range(4)],
]
for tag, hip, knee, foot, out, side in LEGS:  # clevis forks on the hull hold each hip disc
    for e in (-1, 1):
        c = hip + side * e * 0.135
        mech.append(hull_pts([c + out * u + Z * v + side * t for u in (-0.3, 0.06) for v in (-0.24, 0.24)
                              for t in (-0.025, 0.025)], f"fork{tag}{e}", METAL, 0.012))
        mech += bolts(f"forkbolt{tag}{e}", c + side * e * 0.03, side * e, 0.17, STEEL, k=4)
hips = [box(f"hipb{sx}{sy}", (0.3, 0.4, 0.4), (sx * 0.62, sy * 0.72, 1.6), METAL)
        for sx in (-1, 1) for sy in (-1, 1)]
blades = []
for s in (-1, 1):  # parallelogram plates tilted down-and-out, bright cutting edge along the low side
    inner = Vector((s * 0.3, 0, 1.34))
    across = Vector((s * 0.63, 0, -0.13)).normalized()
    nrm = across.cross(Y).normalized() * 0.025
    W = 0.52
    def P(y, v, off=0.0):
        return inner + across * v + Vector((0, y, 0)) + nrm * off
    plate = [P(y, v, o) for (y, v) in ((-0.72, 0), (-0.86, W), (-2.75, W), (-2.15, 0)) for o in (-1, 1)]
    edge = [P(y, v, o) for (y, v) in ((-0.86, W - 0.07), (-0.88, W + 0.03), (-2.8, W + 0.03), (-2.62, W - 0.07))
            for o in (-1.3, 1.3)]
    blades += [hull_pts(plate, f"blade{s}", STEEL, 0.006), hull_pts(edge, f"bladeedge{s}", EDGE, 0.004),
               bar(f"bladebracket{s}", (s * 0.3, -0.85, 1.3), P(-0.95, 0.25), 0.1, 0.12, METAL, 0.015),
               *[disc(f"rivet{s}{i}", P(-1.0 - i * 0.35, 0.1, 1.2), nrm.normalized(), 0.022, 0.02, STEEL, 6)
                 for i in range(4)]]
hull = part("Hull", [head, carapace, *trims, *face, *roof, *under, *tail, *mech, *hips, *blades],
            (0, 0, 1.6), root)

# ---------- turret: receiver on a pedestal, big rear ammo block ----------
TP = Vector((0, 0.3, 2.05))
t_parts = [
    box("pedestal", (0.45, 0.6, 0.25), (0, 0.3, 2.08), METAL, 0.03),
    *[bar(f"link{s}", (s * 0.32, -0.05, 1.98), (s * 0.32, 0.55, 2.3), 0.06, 0.1, METAL, 0.01) for s in (-1, 1)],
    *[disc(f"linkhub{s}", (s * 0.33, 0.55, 2.3), X, 0.11, 0.06, METAL) for s in (-1, 1)],
    prism("receiver", [(0.3, 2.2), (0.3, 2.72), (0.5, 2.85), (1.95, 2.85), (1.95, 2.2)], 0.28, METAL, 0.03),
    box("front_post", (0.2, 0.22, 0.26), (0, 0.38, 2.96), METAL, 0.05),
    cyl("rod", (0, 0.45, 3.0), (0, 1.0, 3.0), 0.045, STEEL, 10),
    *[cyl(f"rodring{i}", (0, 0.6 + i * 0.25, 3.0), (0, 0.64 + i * 0.25, 3.0), 0.06, RUST, 10) for i in range(2)],
    box("rear_post", (0.26, 0.24, 0.34), (0, 1.1, 2.98), METAL, 0.04),
    box("mech", (0.42, 0.5, 0.24), (0, 1.65, 2.96), METAL, 0.03),
    disc("gear", (0.24, 1.75, 3.0), X, 0.15, 0.06, METAL, 16),
    disc("gear_hub", (0.28, 1.75, 3.0), X, 0.06, 0.04, STEEL, 10),
    disc("gear2", (0.24, 1.45, 3.05), X, 0.08, 0.05, METAL, 12),
    disc("sideplate_hub", (0.3, 0.75, 2.45), X, 0.14, 0.05, METAL, 16),
    bar("sideplate", (0.3, 0.75, 2.45), (0.3, 1.4, 2.5), 0.04, 0.16, METAL, 0.01, hint=X),
    box("ammo", (0.95, 0.6, 1.25), (0, 2.15, 2.1), METAL, 0.04),
    *[box(f"panel{s}", (0.03, 0.42, 0.85), (s * 0.48, 2.2, 2.05), METAL, 0.01) for s in (-1, 1)],
    box("rail", (0.04, 0.04, 0.9), (0.49, 1.9, 2.05), STEEL, 0.005),
    *[box(f"rung{i}", (0.03, 0.12, 0.025), (0.5, 1.95, 1.7 + i * 0.16), STEEL, 0.004) for i in range(5)],
    box("ammo_light", (0.04, 0.08, 0.12), (0.5, 1.9, 2.6), GLOW, 0.005),
    *[box(f"fin{i}", (0.04, 0.38, 0.06), (-0.2 + i * 0.08, 2.15, 2.75), STEEL, 0.004) for i in range(6)],
    *[bar(f"xbrace{s}", (-0.38, 2.46, 1.6 if s > 0 else 2.6), (0.38, 2.46, 2.6 if s > 0 else 1.6),
          0.06, 0.04, METAL, 0.008, hint=Y) for s in (-1, 1)],
    box("backframe", (0.85, 0.03, 1.1), (0, 2.455, 2.1), METAL, 0.01),
    disc("xbolt", (0, 2.49, 2.1), Y, 0.05, 0.03, STEEL, 8),
    *[disc(f"rcvbolt{s}{z}{i}", (s * 0.29, 0.55 + i * 0.22, z), X, 0.022, 0.025, STEEL, 6)
      for s in (-1, 1) for z in (2.27, 2.78) for i in range(7)],
    *[box(f"access{s}", (0.025, 0.55, 0.28), (s * 0.29, 1.25, 2.5), METAL, 0.01) for s in (-1, 1)],
    *[box(f"latch{s}", (0.03, 0.06, 0.05), (s * 0.305, 1.0, 2.5), STEEL, 0.004) for s in (-1, 1)],
    *[cyl(f"turret_hose{s}", (s * 0.22, 0.85, 2.2), (s * 0.4, 0.45, 1.98), 0.03, BORE, 6) for s in (-1, 1)],
    *[c for s in (-1, 1) for c in (  # carry handles on the ammo box back
        cyl(f"ahandle{s}a", (s * 0.25, 2.45, 2.55), (s * 0.25, 2.55, 2.55), 0.02, STEEL, 6),
        cyl(f"ahandle{s}b", (s * 0.25, 2.45, 2.4), (s * 0.25, 2.55, 2.4), 0.02, STEEL, 6),
        cyl(f"ahandle{s}c", (s * 0.25, 2.55, 2.55), (s * 0.25, 2.55, 2.4), 0.02, STEEL, 6))],
]
turret = part("Turret", t_parts, TP, hull)

# ---------- cannon: chamber housing, tapering barrel, flared muzzle brake, under-barrel sensor ----------
CP = Vector((0, 0.1, 2.54))  # elevation pivot inside the chamber housing
GZ = 2.54
def g(y, z=GZ):
    return (0, y, z)
c_parts = [
    cyl("housing", g(0.35), g(-0.15), 0.23, METAL, 20),
    cyl("housing_front", g(-0.15), g(-0.28), 0.23, METAL, 20, r2=0.17),
    cyl("chamber", g(-0.28), g(-0.8), 0.15, METAL, 16, r2=0.105),
    cyl("barrel", g(-0.8), g(-2.35), 0.1, METAL, 16, r2=0.08),
    cyl("band", g(-1.05), g(-1.12), 0.12, RUST, 16),
    cyl("housing_ring", g(0.02), g(-0.04), 0.24, STEEL, 20),
    cyl("fume_back", g(-1.35), g(-1.42), 0.085, METAL, 16, r2=0.125),
    cyl("fume", g(-1.42), g(-1.75), 0.125, METAL, 16),
    cyl("fume_front", g(-1.75), g(-1.82), 0.125, METAL, 16, r2=0.083),
    cyl("clamp", g(-2.05), g(-2.1), 0.095, STEEL, 16),
    *[cyl(f"recoil{s}", (s * 0.15, 0.3, GZ - 0.19), (s * 0.15, -0.5, GZ - 0.19), 0.05, STEEL, 10) for s in (-1, 1)],
    *[cyl(f"recoilcap{s}", (s * 0.15, -0.5, GZ - 0.19), (s * 0.15, -0.56, GZ - 0.19), 0.06, METAL, 10)
      for s in (-1, 1)],
    cyl("collar", g(-2.3), g(-2.4), 0.098, STEEL, 16),
    cyl("brake", g(-2.4), g(-2.68), 0.12, METAL, 16),
    cyl("brake_flare", g(-2.68), g(-2.8), 0.12, METAL, 16, r2=0.14),
    disc("bore", g(-2.805), Y, 0.075, 0.012, BORE, 12),
    *[box(f"port{s}{i}", (0.02, 0.06, 0.13), (s * 0.12, -2.48 - i * 0.1, GZ), BORE, 0.004)
      for s in (-1, 1) for i in range(2)],
    bar("sensor_arm", g(-2.25, GZ - 0.06), g(-2.12, GZ - 0.24), 0.05, 0.05, METAL, 0.005, hint=X),
    cyl("sensor", g(-2.0, GZ - 0.27), g(-2.36, GZ - 0.27), 0.055, METAL, 12),
    cyl("sensor_lens", g(-2.36, GZ - 0.27), g(-2.38, GZ - 0.27), 0.04, GLOW, 12),
    cyl("sensor_cap", g(-1.97, GZ - 0.27), g(-2.0, GZ - 0.27), 0.065, STEEL, 12),
]
cannon = part("Cannon", c_parts, CP, turret)
muzzle = bpy.data.objects.new("Muzzle", None)  # spawn point for shells / flash
col.objects.link(muzzle); muzzle.parent = cannon
muzzle.location = Vector(g(-2.82)) - CP

# ---------- legs: disc joints, broad thigh up to the knee, bowed bone shin with a hydraulic, hex foot ----------
for tag, hip, knee, foot, out, side in LEGS:
    ankle = foot + Vector((0, 0, 0.36))
    thigh_pts = bezier(hip, (hip + knee) / 2 + Z * 0.08, knee, 5)
    thigh = part(f"Leg_{tag}_Thigh", [
        disc("hipdisc", hip, side, 0.2, 0.2, METAL, 16),
        disc("hiphub", hip + side * 0.11, side, 0.08, 0.04, STEEL, 10),
        *bolts("hipbolt", hip + side * 0.105, side, 0.14, STEEL),
        tube("thigh", thigh_pts, [(0.22, 0.3), (0.26, 0.36), (0.27, 0.38), (0.26, 0.36), (0.24, 0.32)],
             PAINT, side),
        *[c for e in (-1, 1) for c in (
            cyl(f"thigh_cyl{e}", hip - Z * 0.12 + out * 0.12 + side * e * 0.15,
                hip + (knee - hip) * 0.5 - Z * 0.14 + side * e * 0.15, 0.04, METAL, 8),
            cyl(f"thigh_rod{e}", hip + (knee - hip) * 0.5 - Z * 0.14 + side * e * 0.15,
                knee - Z * 0.16 - out * 0.06 + side * e * 0.15, 0.022, STEEL, 8))],
        box("knee_actuator", (0.16, 0.16, 0.16), knee - out * 0.22 + Z * 0.16, METAL, 0.02),
        disc("kneedisc", knee, side, 0.2, 0.3, METAL, 16),
        *[disc(f"kneehub{e}", knee + side * 0.16 * e, side, 0.09, 0.04, STEEL, 10) for e in (-1, 1)],
        *bolts("kneebolt", knee + side * 0.155, side, 0.145, STEEL),
    ], hip, hull)
    top = ankle + Z * 0.22
    shin_pts = bezier(knee + out * 0.08 - Z * 0.05, (knee + top) / 2 + out * 0.28 + Z * 0.1, top, 9)
    sizes = [(0.3 - 0.11 * i / 8, 0.36 - 0.16 * i / 8) for i in range(9)]
    hyd_a = shin_pts[2] - out * 0.1
    hyd_b = shin_pts[7] - out * 0.1
    shin = part(f"Leg_{tag}_Shin", [
        tube("shin", shin_pts, sizes, PAINT, side),
        cyl("hyd_body", hyd_a, hyd_a + (hyd_b - hyd_a) * 0.55, 0.055, METAL, 10),
        cyl("hyd_rod", hyd_a + (hyd_b - hyd_a) * 0.55, hyd_b, 0.03, STEEL, 8),
        cyl("shin_cuff", top + Z * 0.05, top - Z * 0.08, 0.13, METAL, 10),
        cyl("piston", top, ankle, 0.07, METAL, 10),
        *[cyl(f"coil{i}", top - Z * (0.11 + i * 0.03), top - Z * (0.125 + i * 0.03), 0.105, STEEL, 10)
          for i in range(4)],
        *[tube(f"shincuff{j}", [shin_pts[j] - (shin_pts[j + 1] - shin_pts[j]) * 0.15,
                                shin_pts[j] + (shin_pts[j + 1] - shin_pts[j]) * 0.15],
               [(sizes[j][0] + 0.03, sizes[j][1] + 0.03)] * 2, METAL, side) for j in (1, 5)],
        *[disc(f"shinbolt{j}{e}", shin_pts[j] + side * e * (sizes[j][0] / 2 + 0.012), side * e, 0.024, 0.025,
               STEEL, 6) for j in (2, 3, 4, 6) for e in (-1, 1)],
    ], knee, thigh)
    part(f"Leg_{tag}_Foot", [
        disc("ankledisc", ankle, side, 0.11, 0.18, METAL, 12),
        cyl("foot_neck", ankle, foot + Z * 0.26, 0.08, METAL, 10),
        cyl("foot_top", foot + Z * 0.27, foot + Z * 0.1, 0.17, RUST, 6, r2=0.3, smooth=False),
        cyl("foot_base", foot + Z * 0.1, foot, 0.33, RUST, 6, r2=0.3, smooth=False),
        *bolts("footbolt", foot + Z * 0.115, Z, 0.24, STEEL, k=6),
    ], ankle, shin)

meshes = [o for o in col.objects if o.type == "MESH"]
bpy.context.view_layer.update()

# ---------- one shared UV atlas ----------
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = hull
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004, scale_to_bounds=False)
bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------- bake: albedo, tangent normal, ORM (glTF R=AO 1, G=roughness, B=metallic), emission ----------
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = 16
scn.render.bake.margin = 8
for m in bpy.data.materials:
    m.node_tree.nodes.new("ShaderNodeTexImage").name = "BAKE"

def bake(name, size, kind, data, **kw):
    img = bpy.data.images.new(name, size, size, alpha=False, is_data=data)
    for m in bpy.data.materials:
        nt = m.node_tree
        nt.nodes["BAKE"].image = img; nt.nodes.active = nt.nodes["BAKE"]
    bpy.ops.object.bake(type=kind, use_clear=True, **kw)
    img.filepath_raw = os.path.join(OUT, name + ".png"); img.file_format = "PNG"; img.save()
    return img

def set_emission(fn):
    for m in bpy.data.materials:
        b = m.node_tree.nodes["Principled BSDF"]
        col_, strength = fn(m.name)
        b.inputs["Emission Color"].default_value = (*col_, 1)
        b.inputs["Emission Strength"].default_value = strength

alb = bake("walker_albedo", TEX, "DIFFUSE", False, pass_filter={"COLOR"})
nrm = bake("walker_normal", TEX, "NORMAL", True, normal_space="TANGENT")
set_emission(lambda n: ((1.0, FINAL[n][1], FINAL[n][0]), 1.0))
orm = bake("walker_orm", TEX, "EMIT", True)
set_emission(lambda n: (FINAL[n][2] or (0, 0, 0), 1.0))
emi = bake("walker_emission", TEX // 2, "EMIT", False)

# ---------- one material for every part (mobile: one surface per mesh) ----------
mat = bpy.data.materials.new("Walker"); mat.use_nodes = True
nt = mat.node_tree; nd, lk = nt.nodes, nt.links
b = nd["Principled BSDF"]
def tex(img):
    t = nd.new("ShaderNodeTexImage"); t.image = img
    return t
lk.new(tex(alb).outputs["Color"], b.inputs["Base Color"])
sep = nd.new("ShaderNodeSeparateColor"); lk.new(tex(orm).outputs["Color"], sep.inputs[0])
lk.new(sep.outputs["Green"], b.inputs["Roughness"]); lk.new(sep.outputs["Blue"], b.inputs["Metallic"])
nm = nd.new("ShaderNodeNormalMap"); lk.new(tex(nrm).outputs["Color"], nm.inputs["Color"])
lk.new(nm.outputs["Normal"], b.inputs["Normal"])
lk.new(tex(emi).outputs["Color"], b.inputs["Emission Color"])
b.inputs["Emission Strength"].default_value = 4.0
for o in meshes:
    o.data.materials.clear(); o.data.materials.append(mat)
    for p in o.data.polygons:
        p.material_index = 0

tris = sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons)
print(f"WALKER tris={tris} objects={len(meshes)}")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "walker.blend"))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "walker.glb"), export_format="GLB",
                          export_apply=True, export_yup=True)
print("WALKER done")
