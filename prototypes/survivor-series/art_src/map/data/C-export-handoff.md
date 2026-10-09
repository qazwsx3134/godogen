# Survivor Series C — export handoff

Status: ready for publish. Root acceptance is recorded as pass. All final artifacts are under `C/map/`; publish by copying only `C/map/` to `SS/art_src/map/`. The `C/map-bundle/` directory is an archive/template only and is not a final dependency.

## Final map

- Bundle: `C/map/data/C-night-market.map-bundle.json`
- Bundle report: `C/map/data/C-night-market.map-bundle-report.json`
- Data layout: `C/map/data/ground-layer.json`, `C/map/data/C-object-layout.json`, `C/map/data/C-placements.json`
- Tilesets: `C/map/data/tilesets/` contains pavement plus all five accepted overlays.
- Navigation QC: `C/map/data/nav/nav-report.json`, `nav-grid.json`, `nav-debug.png`
- Full machine-readable handoff/QC: `C/map/data/C-final-qc.json`

The bundle is `generate2dmap.map_bundle.v2`, 768×768 px, 128 px tiles, 6×6 grid, layered tile layers in ground → five grounddecor layers → `props-y-sorted` order. It contains eight props and independent contact footprints; the hero is preview-only and is not in the map bundle.

## Godot deliverable

Standalone project: `C/map/godot/project.godot`

- Main scene: `res://survivor-series-C-night-market.tscn`
- TileSet: `res://survivor-series-C-night-market.tileset.tres`
- Generated asset root: `res://assets/`
- Scene/TileSet resource references use `res://`; no absolute runtime path or `C/map-bundle` dependency remains.
- Export report: `C/map/godot/godot-export.json`
- Root import proof: `C/map/root-validation.json`

Worker export command used:

```sh
python3 skills/generate2dmap/scripts/export_godot.py \
  --bundle .forge/survivor-assets-20261009/C/map/data/C-night-market.map-bundle.json \
  --output-dir /tmp/C-night-market-godot \
  --name survivor-series-C-night-market \
  --texture-filter nearest --strict-qc
```

Export parse-back: pass; 6 tile layers, 8 objects, 8 collision shapes, markers and copied assets round-trip. Root validation now records Godot 4.7 editor import pass, 14 images imported, and the two-frame main-scene load pass with no errors/warnings (session 12731). The final engine resource hashes are recorded in `root-validation.json`.

The original import command was:

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path .forge/survivor-assets-20261009/C/map/godot \
  --editor --quit
```

The six exporter warnings are retained: each flat atlas source has no complete Wang/blob-mask data, so no terrain set was made. This is expected for these flat pavement/isolated overlay sources; Wang data was not fabricated. The exporter also reports the camera as bundle-only. Neither warning is an export failure.

## QC and previews

- `map_bundle.py validate --require-sha256`: pass, 0 errors, 0 warnings.
- `map_nav.py check`: pass, unreachable 0, thin gaps 0.
- Strict compose: pass, 0 warnings, audit pass, 9 placements (8 props + hero demo).
- `preview/ground-repeat-3x3.png`: actual 3×3 tile repeat, 384×384.
- `preview/ground-grid-6x6.png`: actual pavement repeat, 768×768.
- `preview/ground-layered-6x6.png`: base plus all five sparse alpha overlay layers, 768×768.
- `preview/night-market-composite.png`: layered ground + eight props + approved hero demo.
- `preview/hero-se-demo.png`: 44×90, alpha bbox crop then nearest fit from the approved master-green SE source.
- Compose report/audit: `preview/night-market-composite.report.json` and `preview/night-market-composite.audit.json`.

Pavement QC is X 0.441609 / Y 0.926504 with threshold 1.25, warnings 0. `seamless_verified` remains `false`; a ratio pass is not an exact-zero seam proof.

## Accepted asset facts

Ground overlays are all 128×128 RGBA and strict-QC accepted: manhole, drain_grate, puddle, cracks, zebra. The accepted clean puddle is:

- canonical PNG SHA-256: `4e192d39dd75c6bea60c6001ca27ad4e27f38e4b4bdcea214dae9d7156495d32`
- terrain bundle SHA-256: `600dd8f720190093183e461da283c43f511dedde18c310747f873f77527ca226`
- alpha bbox `[28,54,103,82]`, visible fraction `0.080566`, contrast `0.158077`, warnings `0`
- diagnostic initial puddle is excluded from every final tileset/bundle/export.

Props use the final prop-kit dimensions and measured runtime anchors. The bollard is the mechanically padded 20×52 canvas with anchor `[10,49]`; its old 16×48 image is provenance-only and its silhouette was not changed. Full dimension/anchor/hash/transform inventory is in `C/map/data/C-final-qc.json`.

## Provenance and warnings

Integration route was `local:codex-cli`; C made no API calls and did not generate art. Root-managed generation outputs, ground-kit, prop-kit, canonical PNG hashes, prompt/source provenance, and the resolved puddle prompt normalization note are preserved in the source kits and final QC JSON. Ground-kit SHA-256 is `0f2bc85ee3dc9b77e618a6ddf5da0d85a80ae043cb9867259760d5d25ec322ea`; status is `complete`, `pending=[]`, `warnings=[]`. The raw prompt trailing-newline versus CLI strip discrepancy is resolved: job SHA `3723950955b400c9ae559564b4cea7209d1d5af0d7535589eea04739db2bcfa2` equals `sha256(prompt.txt.strip())`, while preserved source/full prompt SHA `0118befe2f416814a9042dba5fb0d9e3e6ceff93934ce23b9edb45b322921b9a` and bytes match.

Root proof is complete. No game source was changed, no animation/API/approval flow was added, and the worker is stopped at this handoff. Static scene load does not exercise player movement or physics gameplay.
