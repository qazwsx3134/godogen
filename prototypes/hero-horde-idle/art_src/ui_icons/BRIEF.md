# 派工：招牌技圖示、職業徽章、英雄頁背景（ui_icons）

## 背景
「全員推王」的養成畫面已經在遊戲裡做好了（Claude 做的，`scenes/hero_page.tscn`、`scenes/growth.tscn`），外觀照使用者偏好的稿
`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/detail_refinement_v2/hero_detail.png`（墨綠、暖白、古銅細框）。
現在缺三樣圖，暫時用職業頭像代替：招牌技圖示、職業徽章、英雄頁背景。這一批只生圖，**不要改遊戲的任何檔案**（scenes、scripts、assets、tests、tools），接進遊戲由 Claude 做。
英雄頁的實作已經交給 Claude，你之前做的 hero_detail 版本已原樣保留在 `art_src/ui_concepts/codex_hero_detail_wip/`，不用再處理。

參考圖（只借風格，不要照抄構圖）：
- 圖示風格：上面那張稿裡「斷鋼斬」的方形圖示、「職業加成」的綠色小旗徽章
- 英雄像素畫：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/assets/heroes/portraits/sword.png`
- 舞台氣氛：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/props/gate/candidate-01.png`

## 規則
- 用 Codex 內建 image_gen（同 detail_refinement_v2）。每張只生 1 張，不多骰；失敗重跑一次，再失敗就跳過並寫進回報。額度不夠就停在已完成的項目，依下表順序做。
- 圖裡不能有任何文字、字母、數字、邊框以外的 UI。
- 做不到就直說並停下，不要用程式繪圖代替。

## 共同風格（英文，每個 prompt 都套用）
```text
detailed HD-2D pixel art in the style of Octopath Traveler: hand-placed pixel shading, crisp dark outlines, limited
palette, warm light from the upper-left; colours sit well on a dark forest-green UI with warm white text and thin
bronze lines. No text, no letters, no numbers, no watermark.
```

## 1. 招牌技圖示 ×7（`sig/<id>.png`，正方形，不透明）
每張：`a square skill icon, a single bold symbol filling the square, on a dark near-black brown background with a soft
glow behind the symbol, readable at 96 px, no frame, no border`，加上下表的內容。

| 檔名 | 招式 | 內容（英文） |
|---|---|---|
| `wall` | 不動城牆 | a large tower shield planted in the ground radiating a pale blue protective dome |
| `cleave` | 斷鋼斬 | a heavy sword swing leaving a bright orange-gold crescent arc that splits a steel plate |
| `gale` | 疾風連斬 | three fast pale-green wind slashes crossing, with leaves caught in the wind |
| `pierce` | 破甲突刺 | a spear tip punching through a cracked armour plate, sparks flying |
| `arrow` | 穿雲箭 | a single glowing arrow shooting upward through a parted cloud, a bright streak behind it |
| `meteor` | 隕石術 | a flaming meteor falling diagonally with a trail of embers |
| `dawn` | 黎明之光 | a golden sunrise ring with soft rays and small rising sparkles of healing light |

## 2. 職業徽章 ×6（`class/<id>.png`，背景純洋紅 #FF00FF，之後由 Claude 去背）
每張：`a small hanging pennant emblem: a short dark wooden rod with brass end caps at the top, a dark forest-green cloth
banner with a pointed bottom and a thin bronze trim, a single simple pale cream symbol in the middle, centred, the
whole emblem fully visible with margin, on a perfectly flat pure magenta #FF00FF background, no shadow on the
background`，加上下表的圖案。六張要像同一套：同樣的旗形、配色、大小。

| 檔名 | 職業 | 圖案（英文） |
|---|---|---|
| `shield` | 盾 | a round shield |
| `sword` | 劍 | two crossed swords |
| `spear` | 槍 | a single upright spear |
| `bow` | 弓 | a drawn bow with an arrow |
| `mage` | 法 | a staff topped with a crystal |
| `healer` | 補 | a radiant sun ring |

## 3. 英雄頁背景 ×1（`bg/hero_page.png`，直式約 2:3.5，例如 1024×1792，不透明）
`a quiet ruined fortress courtyard at dusk seen from ground level: crumbling stone arches and a broken gate far in the
upper background, dark pines and ferns at the sides, mossy cracked flagstones in the lower middle where a hero would
stand, thin mist; deep forest-green and slate tones with very low contrast, the lower 40 percent fades to near-black
green so text can sit on it, the centre-right is empty open space, no characters, no creatures, no text`

## 輸出
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/sig/<id>.png`
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/class/<id>.png`
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/bg/hero_page.png`
- 一張 `ui_icons/contact.png`：14 張縮小並排（圖示縮到 96 px，看得出就算過）。
- 完整 prompt 寫進 `ui_icons/inputs/prompts.md`。

## 驗收
- 7 個招牌技圖示一眼分得出，96 px 時還看得出是什麼。
- 6 個徽章同一套，背景是平的洋紅、沒有陰影或漸層。
- 背景下方夠暗、右中空著、沒有人物和文字。

## 回報
寫 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/REPORT.md`，最多 10 行：工具、重試／跳過、偏差、額度。完成後建立 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/DONE`。
