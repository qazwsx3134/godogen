# C ground handoff — complete

Status: **complete**. The canonical C ground kit is ready for export: one opaque pavement base plus five transparent overlays. No image generation was performed by this worker; Root supplied the raw jobs through `codex-cli`.

## Canonical export

Export worker files are `pavement.png`, `manhole.png`, `drain_grate.png`, `puddle.png`, `cracks.png`, and `zebra.png`.

All are runtime `128x128`. `pavement.png` is opaque RGB; the five overlays are isolated native-alpha RGBA. The superseded initial puddle remains diagnostic-only at `diagnostic/puddle-initial.png` and must not be exported.

## Raw provenance

Seven raw generation sets are preserved without overwriting: `raw-ground`, `raw-manhole`, `raw-drain-grate`, the initial `raw-puddle`, `raw-cracks`, `raw-zebra`, and the accepted `raw-puddle-clean`. Each retains `generated.png`, `prompt.txt`, `job.json`, and `run.json`. The JSON handoff records every raw path, SHA-256, size/mode, route, provider, model, and the clean job/run identifiers.

The accepted clean puddle raw is [raw-puddle-clean/generated.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/raw-puddle-clean/generated.png), actual PIL size `1774x887`, RGBA, SHA-256 `9077674dfd1019eeb3efa767f5fa6207fb2267674897b0d0f4fd6bbb69a29254`. Its preserved `job.json` is `status=done`, `route=codex-cli`, provider `openai`, requested model `codex-image_gen`; its preserved `run.json` is `status=done`, `route=local:codex-cli`, model `codex-image_gen`, CLI run id `677657e6892548a59d9645b623a689b0`, thread id `01a11e3b-9d29-7c83-8746-334175480e94`.

## Base extraction and QC

The canonical base came from the repository extractor `skills/generate2dmap/scripts/extract_terrain_tiles.py` v0.4.0 with nearest resampling, opaque background, one cell, `128x128`, `--edge-policy seamless`, `--max-seam-ratio 1.25`, and strict QC. The result is [pavement.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/pavement.png), RGB `128x128`, SHA-256 `34a6e5745fde6b816976b69521664d5c78685ee06bf26f95606b030dd5341155`.

Strict QC passed with empty warnings: contrast `0.117631` against `0.035`, variant difference `1.0` against `0.025`, border delta `0.0` against `0.1`, X wrap ratio `0.441609`, and Y wrap ratio `0.926504` against max `1.25`. The repository manifest keeps `seamless_verified=false`; this is a known QC limitation, not a pending task. The kit therefore records continuous wrap metrics, not exact mathematical seamlessness.

## Clean puddle extraction

The accepted puddle is from one successful `codex-cli` water-only regeneration with no baked paver grid. Because the actual raw was wide, it was transparently padded without crop or stretch: input `1774x887` → square `1774x1774`, left/right `0`, top `443`, bottom `444`. The padded source is [source-padded-square.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/prep-puddle-clean-01/source-padded-square.png), SHA-256 `6f16c006f3ae198a75d49bb0e04cf50c108e8cc8e74fc6dd363f2edcca3fdfd1`.

Repository extraction used `extract-overlay-puddle-clean-01/terrain-bundle.json`, native alpha, nearest resampling, isolated edge policy, and strict QC. The canonical [puddle.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/puddle.png) is `128x128` RGBA, SHA-256 `4e192d39dd75c6bea60c6001ca27ad4e27f38e4b4bdcea214dae9d7156495d32`; alpha bbox `[28,54,103,82]`, visible fraction `0.080566`, alpha extrema `[0,251]`, contrast `0.158077` against `0.035`, warnings empty. The base-plus-hero90 comparison was accepted: [puddle-base-hero90-qc.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/puddle-base-hero90-qc.png), SHA-256 `d8bb623f3414c0861d631b5e4457587b7de7243cb68f516aaca8d1236537bd91`.

## Contact and diagnostics

The final raw/runtime contact is [ground-contact-raw-runtime.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/ground-contact-raw-runtime.png), `632x1848`, SHA-256 `b3db0e0ca937d7985e3d0204ff853d9088da0b6cda6c7367ce0f03623d35cca3`; it includes all six selected runtime rows and the clean puddle row. The pavement repeat comparison is [ground-3x3.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/ground-3x3.png), SHA-256 `64e1dc543c03d89635f1424b1a702a26a0d22f96a41e3399b91ef71689aeaec7`.

The initial puddle raw/runtime/preview remain under `diagnostic/` and are explicitly excluded from export because their interior baked paver texture had a visibly different density from the base. They were not overwritten.

## Resolved prompt normalization note

`raw-puddle-clean/job.json` records prompt SHA-256 `3723950955b400c9ae559564b4cea7209d1d5af0d7535589eea04739db2bcfa2`, which equals SHA-256 of `prompt.txt` after `strip()`. The preserved `raw-puddle-clean/prompt.txt` and extractor prompt record SHA-256 `0118befe2f416814a9042dba5fb0d9e3e6ceff93934ce23b9edb45b322921b9a`; those full prompt bytes match and differ only by the trailing newline. This is resolved CLI prompt normalization, not a provenance failure.

Machine-readable details are in [C-ground-handoff.json](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/C-ground-handoff.json) and [ground-kit.json](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/C/map/ground/ground-kit.json).
