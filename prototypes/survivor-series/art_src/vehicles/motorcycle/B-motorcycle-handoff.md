# B motorcycle handoff

Status: **complete** candidate handoff, not approval. All 8 candidates are present and visually/metadata QC passed. No C work was started.

## Provenance and framing

All four selected runs completed with actual route local:codex-cli, provider Codex (local CLI), model codex-image_gen, status ok, and run warnings 0. The normal generate runs record identity FIRST/style SECOND. The E and NE fix runs record the approved SE master as edit FIRST and the hero style as extra SECOND; those are the actual run roles and paths. E candidates now come from dir-e/fix-e-01; the original dir-e/generate-batch-01 raw remains preserved.

Pad contract for every candidate: class mob, facing none, green key #00FF00, canvas 1024x1024, subject height 471, top margin 406, ground/bottom y=877. Raw generated images are 1254x1254 and remain in their original run folders with prompt/job/run/spec files.

## Candidate measurements

| Direction | Heading observed | Candidate | Output bbox | Projected size | Ratio | Pad scale | Warnings |
|---|---|---|---|---:|---:|---:|---|
| s | DOWN | dir-s/candidate-01.png | [382,406,642,877] | 260x471 | 0.552017 | 0.6156862745 | none |
| s | DOWN | dir-s/candidate-02.png | [391,406,633,877] | 242x471 | 0.513800 | 0.5358361775 | none |
| e | RIGHT | dir-e/candidate-01.png | [248,406,776,877] | 528x471 | 1.121019 | 0.6541666667 | none |
| e | RIGHT | dir-e/candidate-02.png | [244,406,779,877] | 535x471 | 1.135881 | 0.7302325581 | none |
| ne | UPPER-RIGHT, rear 3/4 | dir-ne/candidate-01.png | [314,406,709,877] | 395x471 | 0.838641 | 0.6936671576 | none |
| ne | UPPER-RIGHT, rear 3/4 | dir-ne/candidate-02.png | [323,406,701,877] | 378x471 | 0.802548 | 0.6845930233 | none |
| n | TOP, rear/back | dir-n/candidate-01.png | [380,406,644,877] | 264x471 | 0.560510 | 0.6173001311 | none |
| n | TOP, rear/back | dir-n/candidate-02.png | [386,406,638,877] | 252x471 | 0.535032 | 0.6116883117 | none |

The widths are actual image-space projections. They vary by view and take; this handoff does not claim that physical motorcycle length is exactly equal across directions.

All eight were viewed individually and in the overview. Each retains the navy scooter, white helmet, dark rider, wheels, mirrors and relevant taillight; all are inbounds with ground_y=877. The replacement E pair was visually checked as exact RIGHT: nose/front wheel to the right, tail to the left, and near-horizontal axle/tyre contact line. Alpha/key QC found opaque_green_px=0 for every candidate. Pad warnings, crop warnings, source touches and key warnings are all empty. No text, baked shadow or visible crop was observed.

## Contacts

- [s candidates-contact.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/vehicles/motorcycle/dir-s/candidates-contact.png)
- [e candidates-contact.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/vehicles/motorcycle/dir-e/candidates-contact.png)
- [ne candidates-contact.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/vehicles/motorcycle/dir-ne/candidates-contact.png)
- [n candidates-contact.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/vehicles/motorcycle/dir-n/candidates-contact.png)
- [directions-contact.png](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/vehicles/motorcycle/directions-contact.png) — four directions with both candidates; approved SE master centered.

The original wrong-heading NE raw run remains preserved at dir-ne/generate-batch-01; the selected corrected NE raw run is dir-ne/fix-ne-01. The original E draft raw run remains preserved at dir-e/generate-batch-01; selected E candidates are from dir-e/fix-e-01. No raw image was overwritten, and no new generation was initiated by this worker.

Machine-readable details, hashes and every candidate actual provenance are in [B-motorcycle-handoff.json](/Users/peter/repo/agent-sprite-forge/.forge/survivor-assets-20261009/B/B-motorcycle-handoff.json).
