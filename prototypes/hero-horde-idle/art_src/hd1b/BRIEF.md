# 派工：棍棒巨魔 3 個姿勢（hd1b）

## 背景
- hd1 的巨魔已選定：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1/boss/candidate-01.png`（待命站姿、朝左）。
- 遊戲裡還要 3 個姿勢，同一隻巨魔、同一張畫布比例。

## 做法
- 每個姿勢用 `master_still.py edit`，FIRST 圖 `--still` 用上面那張 candidate-01.png。
- 都加 `--route codex-cli --finish pixel --class hero --key magenta --facing left`。
- keep：外觀、配色、角、獠牙、鐵片護具、狼牙棒、比例、畫風、約 45° 俯視、朝左。
- 只有 edit 失敗時才改用 generate＋`--identity-ref` 那張圖，並在回報寫明。
- 每個姿勢 1 張，不多骰；每筆時限 6 分鐘（同 hd1 規則）。

| 資料夾 | 姿勢（edit 的 THE ONLY CHANGE） |
|---|---|
| `windup/` | winding up a huge attack: club raised high overhead with both hands, body leaning back, mouth open roaring |
| `slam/` | the moment of impact: club smashed down onto the ground in front of him (to the left), body bent forward, a few small rock chips flying (no dust cloud covering the body) |
| `stunned/` | staggered and dazed: knees buckling, club dragging on the ground from one hand, head tilted, eyes unfocused, a small cracked plate on the harness |

## 輸出
- 每個姿勢：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/hd1b/<資料夾>/candidate-01.png`
- 總比較圖：`hd1b/poses-contact.png`（含 hd1 那張待命站姿，共 4 張並排）

## 驗收
- 透明背景、全身與狼牙棒不裁切、朝左、4 張是同一隻巨魔。
- 腳底大致在同一高度（遊戲裡腳底對齊地面）。

## 回報
寫 `hd1b/REPORT.md`，最多 10 行：route、偏差、額度。完成後建立 `hd1b/DONE`。
