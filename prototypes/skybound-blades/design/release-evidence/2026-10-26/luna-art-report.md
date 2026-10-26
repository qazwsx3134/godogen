# Skybound Blades polish-v2 image report

## Generation mode

Used the built-in `image_gen` tool, one call per prompt/asset, with one targeted retry only where the first result clearly missed a stated requirement. The controlling session is GPT-6 Luna MAX; the underlying image-generation model is not identified here. Generated PNGs remain in their original built-in output directory; project copies are byte-for-byte originals for the main session to normalize and pack.

## Priority assets 01/06/07

### 01 — Windcourt Gatekeeper

- Status: best-effort candidate selected after one retry; the edge is still imperfect.
- Prompt: [01-gatekeeper-master.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/01-gatekeeper-master.txt), used as the prompt body with a short wrapper identifying the captain master as style/camera reference only. Retry added an explicit prohibition on bright outlines, red/yellow fringe, rim light and matte spill.
- Reference: `/mnt/d/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/captain/master/master_rgba.png`, viewed before generation and attached as reference only.
- Selected generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-7a66e17b-5da7-4bad-82e1-9229dc9b2b58.png` (retry; first attempt: `.../exec-9884656d-20cd-4441-9e63-b161b01e2176.png`).
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/gatekeeper.png` and `prototypes/skybound-blades/assets/art/polish-v2/gatekeeper.png`.
- Output: 1254×1254, 8-bit RGBA. Actual transparent pixels surround the subject; subject pixels are mostly near-opaque. The alpha>=128 subject bounds are x=60..1206, y=88..1189, leaving about 47 px on the right and 64 px on the bottom at generated resolution. The prompt's 64 px inset is therefore slightly missed on the right. A thin red/yellow edge fringe and isolated low-alpha edge pixels remain visible after the only retry. The selected result has less fringe than the first take, but does not fully meet clean-alpha criteria.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

### 06 — Windcourt ground

- Status: best-effort candidate selected after one retry; repeat seams remain measurable.
- Prompt: [06-windcourt-ground.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/06-windcourt-ground.txt), with the standard asset wrapper. The retry appended a targeted instruction that opposite borders are physically adjacent and brushwork must continue across them.
- Selected generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-d7df080e-7777-4be2-b7cd-7bc7a88f0d47.png` (first take; retry: `.../exec-d6cc90bc-d1fd-4b10-9c70-5e7d9d1c4aa3.png`).
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/ground.png` and `prototypes/skybound-blades/assets/art/polish-v2/ground.png`.
- Output: 1254×1254, 8-bit RGB, fully opaque. Edge inspection found top/bottom mean absolute RGB difference 7.9 versus 3.34/3.12 for adjacent interior rows; left/right difference 8.92 versus 4.18/3.94 for adjacent interior columns. The retry measured 9.3 and 11.2 respectively, so the first take was kept. Both takes remain visibly at risk of a repeat seam; only one retry was used.
- Tool mode: built-in `image_gen`, `transparent_background: false`.

### 07 — Windcourt oak

- Status: best-effort candidate selected after one retry; padding meets the requested margin at visible alpha, though color fringe remains.
- Prompt: [07-windcourt-oak.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/07-windcourt-oak.txt), used with a wrapper identifying the captain master as camera/rendering reference only. Retry explicitly asked for 96 px transparent margins, a smaller centered silhouette, and no colored outline, red/yellow fringe, rim light, glow or matte spill.
- Reference: `/mnt/d/repo/godot/godogen/prototypes/skybound-blades/art_src/chars/captain/master/master_rgba.png`.
- Selected generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-b1314f3d-17ef-4811-b0bb-7b9e8f37b602.png` (retry; first attempt: `.../exec-a26b6b0d-4bb8-4774-b9ef-9c73f42e5934.png`).
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/oak.png` and `prototypes/skybound-blades/assets/art/polish-v2/oak.png`.
- Output: 1254×1254, 8-bit RGBA, alpha range 0–255. Alpha>=128 bounds are x=97..1157, y=78..1168, leaving 96 px right, 97 px left, 78 px top and 85 px bottom. A few isolated alpha pixels reach the canvas edge but remain below alpha 8. The retry improved the silhouette padding; colored edge fringe is still visible, so the alpha edge is not fully clean.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

The priority set 01/06/07 was completed and reported before the captain pose batch.

## Captain pose progress

### 02 — Captain walk A

- Status: best-effort retry selected; running silhouette and identity are readable, but the sword does not meet the requested edge clearance.
- Prompt: [02-captain-walk-a.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/02-captain-walk-a.txt), used with the master image as identity/camera reference. Retry added a 96 px safety margin, asked for a slightly adjusted sword angle/reach, and explicitly excluded colored edge fringe and glow.
- Selected generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-4868b216-b6d2-454c-95ab-aef94e2896e4.png` (retry; first attempt: `.../exec-2fba6698-915d-4c26-936f-d5ed8113478d.png`).
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/captain-walk-a.png` and `prototypes/skybound-blades/assets/art/polish-v2/captain-walk-a.png`.
- Output: 1254×1254, 8-bit RGBA, transparent background. Alpha>=128 bounds x=78..1244, y=195..1139; right margin is only 9 px, below the requested 48 px. Thin colored edge fringe remains despite retry. No further retry used.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

Pose 02 is recorded; poses 03–05 were in progress at that point.

### 03 — Captain walk B

- Status: one candidate selected; running pose, opposite leg contact and identity are readable. The sword overlaps the foreground leg in projection, so check the atlas/game-scale read before adopting it.
- Prompt: [03-captain-walk-b.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/03-captain-walk-b.txt), with the captain master as the sole identity/camera reference. The prompt wrapper also stated no colored edge fringe, rim light, glow or matte spill.
- Generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-65af5292-95c2-4a02-81ef-f3a71adf79ee.png`.
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/captain-walk-b.png` and `prototypes/skybound-blades/assets/art/polish-v2/captain-walk-b.png`.
- Output: 1254×1254, 8-bit RGBA, alpha range 0–255 with transparent pixels. Alpha>=128 bounds x=87..1177, y=181..1160; the sword, scarf and boots remain inside the canvas. Colored edge fringe remains visible; one generation used, no retry.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

Progress marker at the time of this entry; poses 04 and 05 were generated afterward.

### 04 — Captain attack anticipation

- Status: one candidate selected; the stored-weight stance, raised sword, counterbalancing hand and face remain readable.
- Prompt: [04-captain-attack-anticipation.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/04-captain-attack-anticipation.txt), with the captain master as the identity/camera reference and an explicit no-colored-fringe/no-glow transparency constraint.
- Generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-88a0f4a9-1e6d-43ee-9038-87686a10e81d.png`.
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/captain-attack-anticipation.png` and `prototypes/skybound-blades/assets/art/polish-v2/captain-attack-anticipation.png`.
- Output: 1254×1254, 8-bit RGBA, transparent background. Alpha>=128 bounds x=61..1184, y=57..1209; bottom margin is 44 px, four pixels short of the requested 48 px. Thin colored edge fringe remains. No retry used.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

Pose 04 is recorded; pose 05 was in progress at that point.


### 05 — Captain attack impact

- Status: one candidate selected; the follow-through, face, sword hand and blade separation are readable. No effects were baked in.
- Prompt: [05-captain-attack-impact.txt](/mnt/d/repo/godot/godogen/prototypes/skybound-blades/design/assets/prompts-v2/05-captain-attack-impact.txt), with the captain master as identity/camera reference and an explicit no-colored-fringe/no-glow transparency constraint.
- Generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-f47c7942-19c5-4a82-a49c-30a394e7576d.png`.
- Project copies: `prototypes/skybound-blades/art_src/polish-v2/captain-attack-impact.png` and `prototypes/skybound-blades/assets/art/polish-v2/captain-attack-impact.png`.
- Output: 1254×1254, 8-bit RGBA, alpha range includes transparent pixels. Alpha>=128 bounds x=74..1215, y=197..1161; right margin is 38 px, 10 px short of the requested 48 px. Thin colored edge fringe remains. No retry used.
- Tool mode: built-in `image_gen`, `transparent_background: true`.

## Final status

All seven requested assets have a selected full-resolution source in `prototypes/skybound-blades/art_src/polish-v2/` and an unchanged copy in `prototypes/skybound-blades/assets/art/polish-v2/`. The generated images were not cropped, resized, packed or otherwise edited. Ground is the sole opaque asset; the other six have real transparent RGBA backgrounds. All generated images are 1254×1254; the requested 1024×1024 prompt size was not honored by the built-in tool. The prompt file for each asset is linked above, and additions used for targeted retries are recorded with each entry.

Limitations requiring main-session review: ground repeat seams remain measurable after the allowed retry; gatekeeper, oak and captain sprites retain some colored edge fringe; walk A sword clearance is severely short; walk B's sword overlaps the foreground leg; anticipation and impact each miss the requested clearance by a small amount. No asset was regenerated beyond its one allowed retry. Main session owns any later cleanup, atlas normalization and adoption decision.

Final directory check: the source directory contains exactly the seven selected PNGs. The project art directory contains those seven byte-matching PNGs plus four `.import` sidecars (`captain-walk-a.png.import`, `gatekeeper.png.import`, `ground.png.import`, `oak.png.import`); the sidecars were left untouched and are not selected image outputs.

Git inventory: the seven raw PNGs under `art_src/polish-v2/` match the existing `prototypes/skybound-blades/art_src/.gitignore` rule `*.png` and are ignored. The seven project PNGs and four `.import` sidecars are untracked. Nothing was staged or committed.

## User-authorized corrected walk A — one final attempt

- Prompt used: a corrected walk-A prompt based on `02-captain-walk-a.txt`; Image 1 was the approved master for identity and asymmetry, and Image 2 was `captain-walk-b.png` for the current stride/camera. The prompt described the required screen-space reversal explicitly: B's low screen-right planted boot should become the raised rear leg, while the opposite boot plants below the screen-left half of the pelvis. It also locked the sword hand to the same screen-left hand as master/B and the shoulder guard to screen-right. No prompt file was edited.
- Generated original: `/home/ronghao/.codex/generated_images/01a1737d-1a0e-7073-a637-50ae99468584/exec-5f27d3d1-909f-498a-aa61-83c09b7b7e95.png`.
- Saved copies: `prototypes/skybound-blades/art_src/polish-v2/captain-walk-a-corrected.png` and `prototypes/skybound-blades/assets/art/polish-v2/captain-walk-a-corrected.png`.
- Output: 1254×1254, 8-bit RGBA, real transparent pixels; alpha>=128 bounds x=77..1203, y=175..1184.
- Review result: **leg exchange not confirmed**. The new image still shows the weight-bearing boot at lower-right and the other leg bent up/back toward screen-left, matching B's screen-space contact arrangement. **Sword hand preserved: yes**—it remains on screen-left of the torso, with the steel shoulder guard on screen-right.
- Decision: do not adopt this candidate as the alternate gait. Keep the prior verified gait and use the newer attack frames as directed. Original `captain-walk-a.png` and `captain-walk-b.png` were not changed. This was the one authorized extra generation; no retry was made.
- Tool mode: built-in `image_gen`, `transparent_background: true`; underlying image model not identified.
