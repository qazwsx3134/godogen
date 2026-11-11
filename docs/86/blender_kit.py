# Shared Blender helpers for the docs/86 mech models (enemy builds import this; walker/new keeps its own copy).
# Units: meters. Nose to Blender -Y (glTF +Z = Godot MODEL_FRONT), up +Z, origin on the ground.
#   import sys, os; sys.path.append(<dir of this file>); from blender_kit import *
import bpy, bmesh, os, math
from mathutils import Vector, Matrix

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


# ---------------------------------------------------------------- procedural materials (baked later)
def _ramp(nd, lk, src, a, b, ca=(0, 0, 0, 1), cb=(1, 1, 1, 1)):
    r = nd.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].position, r.color_ramp.elements[0].color = a, ca
    r.color_ramp.elements[1].position, r.color_ramp.elements[1].color = b, cb
    lk.new(src, r.inputs[0])
    return r


def _noise(nd, lk, pos, scale, detail=6, rough=0.6):
    n = nd.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = scale
    n.inputs["Detail"].default_value = detail
    n.inputs["Roughness"].default_value = rough
    lk.new(pos, n.inputs["Vector"])
    return n


def _mix(nd, lk, fac, a, b, blend="MIX"):
    x = nd.new("ShaderNodeMix")
    x.data_type, x.blend_type = "RGBA", blend
    for s, v in ((x.inputs[0], fac), (x.inputs[6], a), (x.inputs[7], b)):
        if isinstance(v, (tuple, list, float, int)):
            s.default_value = v
        else:
            lk.new(v, s)
    return x.outputs[2]


def worn(name, base, chips=(), edge=None, grime=0.75, ao=0.35, gradient=None):
    """Procedural albedo: base color (optionally a vertical gradient (low, high, z0, z1)), noise chips
    [(color, scale, threshold)], worn/highlighted edges, low-frequency grime and AO darkening."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nd, lk = nt.nodes, nt.links
    geo = nd.new("ShaderNodeNewGeometry")
    pos = geo.outputs["Position"]
    c = base
    if gradient:
        lo, hi, z0, z1 = gradient
        sep = nd.new("ShaderNodeSeparateXYZ"); lk.new(pos, sep.inputs[0])
        mr = nd.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = z0, z1
        lk.new(sep.outputs["Z"], mr.inputs["Value"])
        c = _mix(nd, lk, mr.outputs["Result"], lo, hi)
    for chip_col, sc, th in chips:
        n = _noise(nd, lk, pos, sc, 10, 0.72)
        c = _mix(nd, lk, _ramp(nd, lk, n.outputs["Fac"], th, th + 0.02).outputs[0], c, chip_col)
    if edge:
        bev = nd.new("ShaderNodeBevel"); bev.samples = 8; bev.inputs["Radius"].default_value = 0.02
        dot = nd.new("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
        lk.new(bev.outputs["Normal"], dot.inputs[0]); lk.new(geo.outputs["Normal"], dot.inputs[1])
        em = _ramp(nd, lk, dot.outputs["Value"], 0.9, 0.985, (1, 1, 1, 1), (0, 0, 0, 1))
        c = _mix(nd, lk, em.outputs[0], c, edge)
    grm = _ramp(nd, lk, _noise(nd, lk, pos, 1.2, 3, 0.5).outputs["Fac"], 0.35, 0.75,
                (grime, grime * 0.97, grime * 0.92, 1), (1, 1, 1, 1))
    c = _mix(nd, lk, 1.0, c, grm.outputs[0], "MULTIPLY")
    a = nd.new("ShaderNodeAmbientOcclusion"); a.inputs["Distance"].default_value = 0.2
    c = _mix(nd, lk, 1.0, c, _ramp(nd, lk, a.outputs["AO"], 0, 1, (ao, ao, ao, 1)).outputs[0], "MULTIPLY")
    lk.new(c, nd["Principled BSDF"].inputs["Base Color"])
    return m


def flat_mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    return m


# ---------------------------------------------------------------- geometry (world space, one object per call)
def obj_from_bm(bm, name, mat, smooth=False, sharp=40):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = smooth
    if smooth:
        me.set_sharp_from_angle(angle=math.radians(sharp))
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def hull_pts(points, name, mat, smooth=False, sharp=40):
    bm = bmesh.new()
    for p in points:
        bm.verts.new(p)
    res = bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.delete(bm, geom=list({*res["geom_interior"], *res["geom_unused"]}), context="VERTS")
    if not smooth:
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1), verts=bm.verts, edges=bm.edges)
    return obj_from_bm(bm, name, mat, smooth, sharp)


def oriented(a, b, hint=Z):
    a, b = Vector(a), Vector(b)
    z = (b - a).normalized()
    hint = hint if abs(z.dot(hint)) < 0.95 else X
    x = hint.cross(z).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = (a + b) / 2
    return m, (b - a).length


def box(name, size, loc, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((*size, 1)))
    return obj_from_bm(bm, name, mat)


def cyl(name, a, b, r, mat, seg=8, r2=None, smooth=True):
    m, L = oriented(a, b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=L, matrix=m)
    return obj_from_bm(bm, name, mat, smooth and seg > 6)


def tube(name, pts, sizes, mat, hint, n=4, phase=0.0, smooth=False, sharp=40):
    """Sweep a polygon section (n sides; phase 0 puts corners on the hint axis -> diamond for n=4) along pts.
    sizes[i] = (w along hint, d across). A size of (0, 0) closes the tube to a point."""
    bm = bmesh.new()
    loops = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        a = (hint - t * hint.dot(t)).normalized()
        b = t.cross(a)
        w, d = sizes[i]
        loops.append([bm.verts.new(p + a * (w / 2 * math.cos(ang)) + b * (d / 2 * math.sin(ang)))
                      for ang in (2 * math.pi * (k + phase) / n for k in range(n))])
    for r0, r1 in zip(loops, loops[1:]):
        for k in range(n):
            bm.faces.new((r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]))
    bm.faces.new(list(reversed(loops[0])))
    bm.faces.new(loops[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)  # collapsed tips
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, name, mat, smooth, sharp)


def bezier(p0, c, p2, n):
    p0, c, p2 = Vector(p0), Vector(c), Vector(p2)
    return [p0 * (1 - t) ** 2 + c * 2 * (1 - t) * t + p2 * t * t for t in (i / (n - 1) for i in range(n))]


def mirror(points):
    """Points given for +X; returns them plus their -X mirror (x=0 points kept once)."""
    out = []
    for x, y, z in points:
        out.append((x, y, z))
        if x:
            out.append((-x, y, z))
    return out


def join(objs, name):
    for o in objs[1:]:
        for mt in o.data.materials:
            if mt.name not in objs[0].data.materials:
                objs[0].data.materials.append(mt)
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, object=objs[0]):
        bpy.ops.object.join()
    objs[0].name = objs[0].data.name = name
    return objs[0]


def weight_all(obj, group):
    """Rigid skinning: every vertex of obj belongs 100% to vertex group (= bone) `group`."""
    vg = obj.vertex_groups.new(name=group)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


# ---------------------------------------------------------------- UV + bake into one material
def uv_atlas(objs, margin=0.004):
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_single_material(objs, out_dir, prefix, final, sizes=(1024, 512, 256), emission_strength=3.0):
    """Bakes albedo / ORM (G=roughness, B=metallic) / emission from the procedural materials, then gives every
    object one material using those textures. final = {material name: (metallic, roughness, emission rgb|None)}.
    sizes = (albedo, orm, emission); emission 0 = no emission map (nothing glows: saves a texture fetch per pixel)."""
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 16
    scn.render.bake.margin = 6
    mats = [m for m in bpy.data.materials if m.name in final]
    for m in mats:
        m.node_tree.nodes.new("ShaderNodeTexImage").name = "BAKE"

    def bake(name, size, kind, data, **kw):
        img = bpy.data.images.new(name, size, size, alpha=False, is_data=data)
        for m in mats:
            nt = m.node_tree
            nt.nodes["BAKE"].image = img
            nt.nodes.active = nt.nodes["BAKE"]
        bpy.ops.object.bake(type=kind, use_clear=True, **kw)
        img.filepath_raw = os.path.join(out_dir, name + ".png")
        img.file_format = "PNG"
        img.save()
        return img

    def set_emission(fn):
        for m in mats:
            b = m.node_tree.nodes["Principled BSDF"]
            col, strength = fn(m.name)
            b.inputs["Emission Color"].default_value = (*col, 1)
            b.inputs["Emission Strength"].default_value = strength

    for o in objs:
        o.select_set(True)
    alb = bake(prefix + "_albedo", sizes[0], "DIFFUSE", False, pass_filter={"COLOR"})
    set_emission(lambda n: ((1.0, final[n][1], final[n][0]), 1.0))
    orm = bake(prefix + "_orm", sizes[1], "EMIT", True)
    emi = None
    if sizes[2]:
        set_emission(lambda n: (final[n][2] or (0, 0, 0), 1.0))
        emi = bake(prefix + "_emission", sizes[2], "EMIT", False)

    mat = bpy.data.materials.new(prefix.capitalize())
    mat.use_nodes = True
    nt = mat.node_tree
    nd, lk = nt.nodes, nt.links
    b = nd["Principled BSDF"]

    def tex(img):
        t = nd.new("ShaderNodeTexImage")
        t.image = img
        return t
    lk.new(tex(alb).outputs["Color"], b.inputs["Base Color"])
    sep = nd.new("ShaderNodeSeparateColor")
    lk.new(tex(orm).outputs["Color"], sep.inputs[0])
    lk.new(sep.outputs["Green"], b.inputs["Roughness"])
    lk.new(sep.outputs["Blue"], b.inputs["Metallic"])
    if emi:
        lk.new(tex(emi).outputs["Color"], b.inputs["Emission Color"])
        b.inputs["Emission Strength"].default_value = emission_strength
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.material_index = 0
    return mat


def tri_count(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)
