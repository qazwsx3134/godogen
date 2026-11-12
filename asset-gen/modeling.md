# Procedural Hard-Surface Models (Blender script → GLB)

For mechs, vehicles and props built by a Blender Python script from a reference image, instead of
Tripo3D. Use it when the shape must match a reference closely, the model needs named rigid parts (legs,
turret, weapons) with animation, or the triangle budget is tight. Needs Blender 4.2+ (tested 5.1); on
WSL use the Windows build and pass paths through `wslpath -w`.

## Pipeline

Each stage ends at a gate; don't start the next stage on a failed gate.

| # | Stage | Output | Gate |
|---|---|---|---|
| 1 | **Reference** — image-to-image from the photo/concept to an orthographic three-view (front, side, top, same scale, solid bg) | `three-view.png` | Silhouettes agree across views; every part you will model is visible in at least two |
| 2 | **Spec** — write before modeling | `README.md` table | Size in m, forward axis, origin on the ground, triangle budget, bone list, clip list, attachment markers (muzzle, hook points) |
| 3 | **Blockout** — one script builds every part from primitives, named after the bone that will move it | `build_<name>.py`, `.blend` | Render from the three reference angles next to `three-view.png`; proportions match |
| 4 | **Topology pass** — see the rules below | same script | `check_topology.py` within the limits below |
| 5 | **UV and bake** — seams on hard edges, one atlas, albedo + ORM | `_albedo.png`, `_orm.png` | Texel density spread p90/p10 ≤ 1.3 |
| 6 | **Rig and clips** — rigid weights (one bone per vertex), loops start and end on the same pose | armature + actions | Interrupting any clip and switching to another leaves no part in the old pose |
| 7 | **Export GLB** — apply transforms, one mesh, one material, forward = the engine's forward | `<name>.glb` | Re-import the GLB and render `render_check.png` (6 views) and `render_motion.png` |
| 8 | **Engine check** — import into the engine, then a crowd test | report | Mesh/surface/bone/clip counts as specified; draw calls and triangles for the expected crowd |
| 9 | **Integration** — game-side scene: collision, hit zones, markers, shadow and LOD choices | game scene | Measured on the target device, not on a desktop software renderer |

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"   # WSL; plain `blender` elsewhere
"$B" -b --factory-startup --python-exit-code 1 --python "$(wslpath -w build_<name>.py)"
"$B" -b --factory-startup --python "$(wslpath -w ${ASSET_GEN_SKILL_DIR}/tools/check_topology.py)" -- \
    "$(wslpath -w <name>.blend)" "$(wslpath -w <out_dir>)"
```

`check_topology.py` prints one `TOPOLOGY {...}` JSON line and writes `<name>_wire.png` (shaded +
wireframe) and `<name>_issues.png` (red = buried, orange = interpenetrating, yellow = slivers, blue =
tiny). It reads the `.blend` and never saves it.

## Topology rules for rigid, script-built models

These models are rigid-skinned: every vertex follows one bone, nothing bends. Edge loops for
deformation don't matter. What matters is wasted triangles, shading, editability and GPU vertex count.

**Measured on two script-built mechs (2026-11-12)**: 86–88 joined primitives, about 1.4k triangles, all
triangles in the source, 15% of triangles completely buried inside other parts, 45% partly inside
another part, 38% slivers, and 2.9 GPU vertices per mesh vertex. These are the typical failure numbers
for this way of building.

1. **Delete what nobody sees; overlap only at joints.** Joining primitives keeps every face that lies
   inside another primitive. Deleting the faces that are buried completely inside a part on the *same*
   bone is the cheap, safe step: in the script, run the same inside test the checker uses before the
   join, and the `buried_tris` count must be 0. A full boolean union of convex-hull parts is usually
   worse: it cuts new slivers and n-gons along the seams. Keep the remaining interpenetration small.
   Parts on *different* bones must stay separate and overlap only at the joint. Size that overlap so the
   largest animated angle never opens a gap.
2. **Flat plates as quads/n-gons, not convex-hull fans.** `convex_hull` triangulates large flat armor into
   long fans from one vertex. Fans are slivers: the GPU shades 2×2 pixel quads, so thin triangles waste
   fill. They also cannot be beveled or edited. Build plates as extruded outlines (or dissolve coplanar
   triangles back to an n-gon) and triangulate only at export. Long thin legs and barrels are naturally
   thin; slivers only matter on wide flat areas.
3. **Hard edges = UV seams = the only vertex splits.** Each flat-normal edge and each UV seam duplicates
   vertices on the GPU. Mark sharp edges by angle (30–40°) and cut UV seams on exactly those edges, rather
   than letting automatic projection cut its own islands. Target `gpu_vertex_ratio` ≤ 2.0; the measured
   2.9 means almost every triangle is its own island. The checker's `gpu_vertices` matched the vertex
   count Godot 4.7 reported for the imported GLBs exactly (2,612 and 2,406), so the gate uses it.
4. **Spend triangles on the silhouette.** At gameplay distance only the outline and big planes read. Use
   chamfers (one extra edge) on silhouette edges and the hard edges facing the camera, and none on
   hidden or bottom faces. Any triangle under ~2 cm² (`tiny_tris`) is wasted.
5. **No coplanar overlap.** Two parts with surfaces in the same plane z-fight. The checker counts them as
   partly buried. Offset one by ≥ 5 mm or cut the overlap away.
6. **Closed, consistent parts.** Check `non_manifold_edges` = 0 and `degenerate_tris` = 0. Recalculate
   normals outward per part before joining. Swept tubes with collapsed tips need merge-by-distance.
7. **Uniform texel density.** One atlas for the whole model. Keep density within p90/p10 ≤ 1.3 and pick
   it from the closest gameplay camera distance. About 70 px/m on a 1024 atlas suits a 5 m enemy seen
   from 10 m or more, but not a player hero seen up close.
8. **Budget the shipped mesh, not the source.** Report triangles and GPU vertices of the exported GLB.
   A crowd's cost is roughly instances × draw calls (one per mesh/material, plus one per shadow pass).

## Engine import

- Keep markers that game code needs (muzzle, hook points, camera targets) as named empties in the
  GLB, or add them in the engine scene wrapping the model. Never compute them from vertex positions.
- Collision is separate: use a few primitive shapes per bone, not the render mesh.
- Animation clips: the importer may rename loops (`walk` → `walk-loop`). Check the imported names before
  wiring playback.
