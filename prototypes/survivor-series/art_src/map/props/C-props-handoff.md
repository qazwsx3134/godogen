# C props handoff: COMPLETED

- Scope: `.forge/survivor-assets-20261009/C/map/props/` only; B remains untouched. No SS/report/preview/Godot/API/codeart/approve/animation work.
- Root completed all 6 `--route codex-cli` calls with exit 0. Each raw folder retains `generated.png`, `prompt.txt`, `job.json`, and `run.json`; job route is `codex-cli`, run route is `local:codex-cli`, model is `codex-image_gen`.
- Refs were viewed: selected street block FIRST material/style; hero master-green SECOND style-only; comparisons use the hero alpha-cropped subject at `44×90` via nearest sampling (not the full `1024×1024` canvas).
- 8 accepted runtime PNGs are in this root: `stall-fruit.png`, `stall-snack.png`, `lantern_post.png`, `bollard.png` (`20×52`), `parked_scooter.png`, `planter.png`, `cone.png`, `fruit_crate.png`.
- `lantern_post` is visibly one post with a connected vertical string of THREE lanterns. Compact pack accepted planter/cone/fruit-crate; empty fourth cell is recorded as `skipped-label`.
- Keys used exactly as requested: blue stalls/planter/cone/crate, green lantern/scooter, magenta bollard. No redraw or independent-axis stretch.
- Every accepted pack passed repo `skills/generate2dmap/scripts/extract_prop_pack.py` with native alpha, `--component-mode all`, `--reject-edge-touch`; wide/tall assets used explicit boxes.
- Runtime transforms are uniform nearest with actual bounds/anchors/source hashes/QC in `postprocess/runtime/*.json`; individual comparisons are in `postprocess/comparisons/` and total contact is `props-contact.png`.
- Bollard tiny fix: old `16×48` pixels are retained unchanged at `postprocess/runtime/bollard-16x48-diagnostic.png`; active runtime is a transparent `20×52` canvas with integer offset `+2,+2`, source hash unchanged, bbox inbounds and `edge_touch=false`. Export worker recommended size is `20×52`.
- Full machine-readable handoff: `prop-kit.json` and `C-props-handoff.json`.
