# 派工：三團的軍旗（flags）

## 背景
手機直式推王遊戲「全員推王」（Godot 4.7，HD-2D：像素圖立在 3D 舞台上）。100 名英雄分成三團，每團跟著自己的旗子走；玩家用手指拖旗子調度整團。旗子是玩家要一直抓的東西，必須在 40 px 高的英雄人群上方一眼認得出是哪一團。
- 遊戲裡旗子約 2.4 公尺高（約 96 px），比英雄高一倍。
- 現在用的暫用旗是方塊，這一批要換成正式的像素軍旗。
- 已經有的舞台道具 `art_src/hd1/props/banner/candidate-01.png`（深藍舊旗、金色太陽）是背景裝飾，新的團旗要明顯不同：更鮮豔、更新、更像「我方的旗」。

## 規則
- 用 agent-sprite-forge 的 `master_still.py`，**一定要加 `--route codex-cli`**，並用 `--finish pixel --class prop --facing none`。呼叫方式同 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1b/run_generation.py`。
- 每筆設時限 6 分鐘：超時停掉、記錄、重跑一次；再卡住就跳過並寫進回報。
- 每張只生 1 張，不多骰。額度不夠就停在已完成的團，依表格順序做。
- 做不到就直說並停下，不要用程式繪圖代替。

## 共同風格（每個 prompt 都套用，英文）
```text
detailed HD-2D pixel art game asset in the style of Octopath Traveler and Triangle Strategy: rich hand-placed shading,
crisp 1-pixel dark outline, lit by a warm low sun from the upper-left with cool shadows, seen from an elevated
three-quarter view about 45 degrees above, one tall vertical war banner standing upright, the whole pole and cloth
fully visible with margin, no background, no ground plate, no cast shadow, no text, no letters, no border.
```

## 旗子的樣子（三面共用，英文）
```text
a tall narrow vertical war banner of a heroes' army: a straight dark wooden pole with a small brass spear-tip finial
and a short crossbar at the top, a long rectangular cloth hanging from the crossbar with a swallowtail (two-pointed)
bottom edge and a thin gold trim, a single bold simple emblem in the middle of the cloth that reads clearly when the
banner is tiny, the cloth gently curving in a light breeze, the pole's foot is a plain iron spike (no stand)
```

## 項目

| 資料夾 | key | 布的顏色與圖案（英文，接在上面兩段之後） |
|---|---|---|
| `melee/` | green | bright crimson red cloth, emblem: a white crossed sword over a round shield |
| `ranged/` | magenta | bright azure blue cloth, emblem: a white drawn bow crossed with a mage staff |
| `support/` | magenta | warm golden yellow cloth, emblem: a white radiant sun ring (the same sun-ring shape as the healer's staff head) |

每一團兩張：
1. `<團>/frame_a/`：`generate`，用上面的文字（`--recap` 寫該團的一句摘要，例如 `a tall crimson war banner with a white crossed sword and shield emblem on a dark wooden pole`）。
2. `<團>/frame_b/`：`edit`，`--still` 用 `frame_a/candidate-01.png`，THE ONLY CHANGE：`the cloth flutters the other way in the breeze: its swallowtail end swings slightly to the left and the folds shift; the pole, finial, crossbar, emblem, colours and size stay exactly the same`。

## 對齊
交付前把每團的 frame_b 放到和 frame_a 同樣大小的畫布上，**旗桿底部（鐵尖）在同一個像素位置**，比例不變；做法同 hd1b／hd2b 的 `prepare_delivery.py`（以旗桿底部取代腳底）。

## 輸出
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/flags/<團>/<frame_a|frame_b>/candidate-01.png`
- 每團一張 `flags/<團>/frames-contact.png`：frame_a、frame_b 並排；另外一張 `flags/flags-40px.png`：三面旗縮到 96 px 高並排，檢查小尺寸認不認得出。

## 驗收
- 透明背景、整支旗桿與旗面不裁切、無文字。
- 三面旗一眼分得出：紅、藍、金，圖案在 96 px 高時還看得出來。
- 同一團 frame_a／frame_b 是同一面旗，只有布的擺動不同，旗桿底部對齊。

## 回報
寫 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/flags/REPORT.md`，最多 12 行：route、偏差、額度、跳過的項目。完成後建立 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/flags/DONE`。
