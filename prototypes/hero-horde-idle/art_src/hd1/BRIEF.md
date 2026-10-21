# 派工：全員推王 HD-2D 舞台與關卡王（hd1）

## 背景
手機直式推王遊戲「全員推王」（Godot 4.7）要改成 HD-2D 畫面：像素圖立在低多邊形 3D 舞台上，配合燈光、景深、光暈。
- 鏡頭固定，往下俯視約 50 度，看到的是一塊平地戰場：英雄在左，關卡王在右。
- 這一批做舞台素材與關卡王。英雄下一批再做。
- 題材是原創奇幻：黃昏時分，山谷裡一座被巨魔佔據的古代石造要塞廢墟。

## 規則
- 用 agent-sprite-forge 的 `master_still.py generate`，**一定要加 `--route codex-cli`**，並用 `--finish pixel`。參考 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1/run_generation.py` 的呼叫方式。
- 每筆生成設時限 6 分鐘：超時就停掉那一筆、記錄、重跑一次；再卡住就跳過，寫進回報。
- 照下表的張數生成，不要多骰。額度不夠就停在已完成的項目，並在回報裡寫明。
- 做不到就直說並停下，不要用程式繪圖代替。

## 共同風格（每個 prompt 都套用，英文）
```text
detailed HD-2D pixel art game asset in the style of Octopath Traveler and Triangle Strategy: rich hand-placed shading,
crisp 1-pixel dark outline, limited warm dusk palette (amber, moss green, slate blue-grey, weathered stone), lit by a
warm low sun from the upper-left with cool blue-violet shadows, seen from an elevated three-quarter view about 45
degrees above, no background, no ground plate, no cast shadow, no text, no border.
```

## 項目

| 資料夾 | class／key／facing／張數 | 描述 |
|---|---|---|
| `boss/` | hero／magenta／left／3 | 見下 |
| `props/pine/` | prop／magenta／none／1 | a tall dark-green mountain pine tree, layered needle clusters, visible trunk base |
| `props/oak/` | prop／magenta／none／1 | a broad leafy deciduous tree with warm autumn-touched green canopy and a thick trunk |
| `props/boulder/` | prop／magenta／none／1 | one large mossy grey granite boulder |
| `props/pillar/` | prop／magenta／none／1 | one broken ancient stone column, fluted, cracked top, ivy at the base |
| `props/gate/` | prop／magenta／none／1 | a ruined ancient stone fortress archway gate, wide and imposing, missing stones, dark opening, moss and hanging vines |
| `props/brazier/` | prop／green／none／1 | a stone brazier on a short pedestal with a bright orange fire burning |
| `props/banner/` | prop／magenta／none／1 | a tattered war banner on a wooden pole, deep navy cloth with a faded gold sun emblem (original, not any real crest) |
| `props/fern/` | prop／magenta／none／1 | a small cluster of ferns and tall grass tufts with a few tiny white flowers |

- **boss**：棍棒巨魔，關卡王。
  - 外觀：hulking grey-green mountain troll about three times human height, hunched broad shoulders, two curved ivory horns, small glowing amber eyes, tusked underbite, crude leather-and-iron-plate harness, carrying a huge spiked wooden club resting on one shoulder.
  - 姿勢：standing idle, menacing.
  - `--facing left`：整個身體與臉朝左（面向左邊的英雄）。工具不支援 left 就用 right 生成，交付時水平鏡像，並在回報寫明。
  - `--recap` 用：`a hulking grey-green horned mountain troll with tusks, an iron-plate harness and a huge spiked wooden club`
- **props** 的 `--extra` 同 madara pixel1 的 `prop_extra`：共同風格只管像素、色盤、外框與視角，不要畫人或生物，主體完整、留邊。

## 地面貼圖（另外三張，不走 master_still）
用 Codex 內建的生圖功能，各生 1 張 1024×1024 正方形、正上方俯視、**可無縫拼接**（seamless tileable）的像素風地面貼圖，同樣是 HD-2D 黃昏色調、沒有光源方向造成的大塊明暗：
- `tiles/grass.png`：茂密的短草地，零星小野花與小石子。
- `tiles/arena.png`：被踩實的泥土地，混著破碎的古老石板。
- `tiles/cliff.png`：層狀灰色岩壁的側面（給懸崖用），有細小裂縫與少量青苔。

原始輸出直接存檔即可，不必像素化或做無縫處理，我這邊會處理。

## 輸出位置
根目錄：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/`
- 每個 master_still 資料夾放 `candidate-NN.png`＋`candidates-contact.png`（forge 的預設輸出）。
- 地面貼圖放 `tiles/`。

## 驗收
- 透明背景、單一主體、不裁切；boss 朝左。
- 去背沒有吃掉主體顏色（火焰用 green key 就是為了這個）。

## 回報
寫到 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/REPORT.md`，最多 15 行：route、各資料夾路徑、偏差、額度狀況。
完成後建立 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/DONE`。
