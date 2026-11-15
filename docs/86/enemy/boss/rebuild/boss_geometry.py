"""Editable, closed hard-surface building blocks for the redesigned boss."""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector


def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    mat.diffuse_color = (*color, 1)
    return mat


class Builder:
    """One parent per editable assembly. Geometry coordinates are in metres."""

    def __init__(self):
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        self.scene = bpy.context.scene
        self.scene.render.fps = 30
        bpy.context.preferences.filepaths.save_version = 0
        self.root = bpy.data.objects.new('Boss_40m', None)
        self.scene.collection.objects.link(self.root)
        self.root.empty_display_type = 'CIRCLE'
        self.root.empty_display_size = 1.0
        self.parts = []
        self.groups = {}
        self.white = material('V2_Ice_White', (.78, .87, .92), .19, .28)
        self.pale = material('V2_Armor_Silver', (.56, .68, .76), .46, .31)
        self.blue = material('V2_Blue_Steel', (.18, .30, .39), .64, .34)
        self.frame = material('V2_Inner_Frame', (.055, .095, .125), .56, .41)
        self.black = material('V2_Recess', (.012, .022, .03), .22, .65)
        self.steel = material('V2_Bright_Metal', (.42, .57, .67), .78, .25)
        self.accent = material('V2_Cold_Accent', (.18, .37, .46), .53, .30)

    def group(self, name, pivot=(0, 0, 0)):
        obj = bpy.data.objects.new(name, None)
        self.scene.collection.objects.link(obj)
        obj.parent = self.root
        obj.location = pivot
        obj.empty_display_type = 'SPHERE'
        obj.empty_display_size = .25
        self.groups[name] = obj
        bpy.context.view_layer.update()
        return obj

    def mesh(self, name, vertices, faces, mat, parent, smooth=False, face_materials=None):
        mesh = bpy.data.meshes.new(name + '_Mesh')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        mesh.update()
        materials = mat if isinstance(mat, (tuple, list)) else (mat,)
        for material_slot in materials:
            mesh.materials.append(material_slot)
        for i, face in enumerate(mesh.polygons):
            face.use_smooth = smooth
            if face_materials is not None:
                face.material_index = face_materials[i]
        obj = bpy.data.objects.new(name, mesh)
        self.scene.collection.objects.link(obj)
        obj.parent = parent
        bpy.context.view_layer.update()
        obj.matrix_world = Matrix.Identity(4)
        self.parts.append(obj)
        return obj

    def section_loft(self, name, stations, mat, parent, sides=12, smooth=False):
        """Stations (x, y, z, half-width, half-height), along the Y axis."""
        vertices = []
        for x, y, z, halfwidth, halfheight in stations:
            for i in range(sides):
                angle = 2 * math.pi * i / sides
                vertices.append((x + halfwidth * math.cos(angle), y,
                                 z + halfheight * math.sin(angle)))
        faces = []
        for ring in range(len(stations) - 1):
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((ring*sides+i, ring*sides+j,
                              (ring+1)*sides+j, (ring+1)*sides+i))
        faces += [tuple(reversed(range(sides))),
                  tuple((len(stations)-1)*sides+i for i in range(sides))]
        return self.mesh(name, vertices, faces, mat, parent, smooth)

    def beveled_band(self, name, stations, mat, parent):
        """Smooth, closed armor ribbon with a wide top and bevelled shoulders."""
        shape = [(-1,0),(-.90,.62),(-.65,1),(.65,1),(.90,.62),
                 (1,0),(.90,-.62),(.65,-1),(-.65,-1),(-.90,-.62)]
        n = len(shape)
        vertices = [(x + hw*dx, y, z + hh*dz)
                    for x,y,z,hw,hh in stations for dx,dz in shape]
        faces = []
        for ring in range(len(stations)-1):
            for i in range(n):
                j = (i+1) % n
                faces.append((ring*n+i,ring*n+j,(ring+1)*n+j,(ring+1)*n+i))
        faces += [tuple(reversed(range(n))),
                  tuple((len(stations)-1)*n+i for i in range(n))]
        return self.mesh(name, vertices, faces, mat, parent, smooth=True)

    def ring_profile(self, name, profile, cx, cz, mats, parent, sides=24, band_materials=None):
        """Closed axial profile (y, radius) with a genuine hollow bore."""
        vertices = [(cx + radius * math.cos(2 * math.pi * i/sides), y,
                     cz + radius * math.sin(2 * math.pi * i/sides))
                    for y, radius in profile for i in range(sides)]
        faces, slots = [], []
        for ring in range(len(profile)):
            next_ring = (ring + 1) % len(profile)
            for i in range(sides):
                j = (i + 1) % sides
                faces.append((ring*sides+i, ring*sides+j, next_ring*sides+j, next_ring*sides+i))
                slots.append(band_materials[ring] if band_materials is not None else 0)
        return self.mesh(name, vertices, faces, mats, parent, smooth=True, face_materials=slots)

    def rod(self, name, a, b, radius, mat, parent, sides=8, radius_end=None):
        """Closed tapered rod in arbitrary direction."""
        a, b = Vector(a), Vector(b)
        axis = (b - a).normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u).normalized()
        radius_end = radius if radius_end is None else radius_end
        verts = []
        for point, r in ((a, radius), (b, radius_end)):
            for i in range(sides):
                angle = 2 * math.pi * i / sides
                verts.append(point + r * (math.cos(angle)*u + math.sin(angle)*v))
        faces = [(i, (i+1) % sides, sides+(i+1) % sides, sides+i) for i in range(sides)]
        faces += [tuple(reversed(range(sides))), tuple(sides+i for i in range(sides))]
        return self.mesh(name, verts, faces, mat, parent, smooth=sides >= 12)

    def panel(self, name, outline, thickness, mat, parent):
        """A closed plate with deliberately authored outline, thickness along Z."""
        n = len(outline)
        verts = [(x, y, z-thickness/2) for x, y, z in outline]
        verts += [(x, y, z+thickness/2) for x, y, z in outline]
        faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
        faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
        return self.mesh(name, verts, faces, mat, parent)


def triangle_count(objects):
    return sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)


def curved(stations, subdivisions=3):
    """Interpolate section centres and radii without collapsing the tips."""
    result = []
    for i in range(len(stations)-1):
        p0 = stations[max(0,i-1)]
        p1, p2 = stations[i], stations[i+1]
        p3 = stations[min(len(stations)-1,i+2)]
        for step in range(subdivisions):
            t = step/subdivisions
            values = [.5*((2*p1[j])+(-p0[j]+p2[j])*t+
                      (2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t*t+
                      (-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t*t*t)
                      for j in range(5)]
            values[3] = max(.015, values[3])
            values[4] = max(.015, values[4])
            result.append(tuple(values))
    result.append(stations[-1])
    return result
