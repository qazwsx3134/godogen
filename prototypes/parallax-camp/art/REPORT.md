# REPORT
風格：明亮飽和、圓潤可愛的原創 Q 版像素美術；`bg_sky.png` 為白天天空，另附 `bg_sky_night.png`；驗收：所有 PNG alpha 僅 0/255、每張 ≤48 色；背景與地面左右邊緣逐像素相同；四份 sheet_qc 均 PASS。
初測 sheet_qc（已修正並複測 PASS）：safe_frame value=6 threshold=0 file=props/campfire_sheet.png (WARN)；safe_frame value=4 threshold=0 file=hero/idle.png (WARN)；safe_frame value=6 threshold=0 file=hero/walk.png (WARN)；sheet_edge value=3 threshold=0 file=hero/jump.png (FAIL)；safe_frame value=3 threshold=0 file=hero/jump.png (WARN)。

| 檔案 | 尺寸 | 色數 | 檢查 |
|---|---:|---:|---|
| `bg_sky.png` | 960x270 | 48 | PASS alpha 0/255, <=48 colors, seam exact |
| `bg_sky_night.png` | 960x270 | 48 | PASS alpha 0/255, <=48 colors, seam exact |
| `bg_far.png` | 960x270 | 41 | PASS alpha 0/255, <=48 colors, seam exact |
| `bg_mid.png` | 960x270 | 48 | PASS alpha 0/255, <=48 colors, seam exact |
| `bg_near.png` | 960x270 | 48 | PASS alpha 0/255, <=48 colors, seam exact |
| `bg_closest.png` | 960x270 | 48 | PASS alpha 0/255, <=48 colors, seam exact |
| `fg_occluder.png` | 480x270 | 48 | PASS alpha 0/255, <=48 colors |
| `ground_tile.png` | 32x32 | 38 | PASS alpha 0/255, <=48 colors, seam exact |
| `props/campfire_sheet.png` | 192x32 | 47 | PASS alpha 0/255, <=48 colors, sheet_qc pass |
| `props/tent.png` | 64x48 | 47 | PASS alpha 0/255, <=48 colors |
| `props/item_rack.png` | 48x48 | 47 | PASS alpha 0/255, <=48 colors |
| `props/cook_pot.png` | 32x32 | 46 | PASS alpha 0/255, <=48 colors |
| `props/street_lamp.png` | 32x64 | 47 | PASS alpha 0/255, <=48 colors |
| `hero/idle.png` | 128x48 | 48 | PASS alpha 0/255, <=48 colors, sheet_qc pass |
| `hero/walk.png` | 192x48 | 47 | PASS alpha 0/255, <=48 colors, sheet_qc pass |
| `hero/jump.png` | 128x48 | 48 | PASS alpha 0/255, <=48 colors, sheet_qc pass |
| `preview.png` | 480x270 | 47 | PASS alpha 0/255, <=48 colors |
| `hero/frames.json` | — | — | PASS; 32x48 frames; idle 4 / walk 6 / jump 4 |
| `PROMPTS.md` | — | — | PASS; prompts and route provenance |
| `source-art.zip` | — | — | PASS; 18 source PNGs plus pixel-look metadata |
| `qa/campfire-sheet.json` | — | — | PASS; no WARN/FAIL |
| `qa/hero-idle-sheet.json` | — | — | PASS; no WARN/FAIL |
| `qa/hero-walk-sheet.json` | — | — | PASS; no WARN/FAIL |
| `qa/hero-jump-sheet.json` | — | — | PASS; no WARN/FAIL |
