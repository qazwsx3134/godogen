# 派工：像素斑 7 姿勢（P2）

## 背景
- P1 的像素斑 `pixel1/madara/candidate-01.png` 已選定（站姿）。
- 遊戲裡要有 7 個姿勢，動作要和上一輪動畫風選定的姿勢一致。
- 上一輪的姿勢在 `art_src/selected/madara_poses/<姿勢>.png`，只當**姿勢參考**，畫風和造型一律照像素斑。

## 做法
- 每個姿勢用 `master_still.py edit`：
  - FIRST 圖：`--still /Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1/madara/candidate-01.png`
  - `--extra-reference`：對應的姿勢參考圖。
  - `--extra-role`：pose reference only: copy the body pose, limb positions and held-fan angle; do NOT copy its drawing style, line art, face or proportions.
- 每個姿勢 1 張；都加 `--route codex-cli --finish pixel --class hero --key green`。
- keep：像素斑的服裝、配色、髮型、團扇、比例、畫風、約 20° 俯視、朝右下。
- 只有 edit 失敗時才改用 generate＋`--identity-ref` 像素斑，並在回報裡寫明。
- 不多骰。額度不夠就停在已完成的項目，在回報裡寫明。

| 資料夾 | 參考圖 | 姿勢 |
|---|---|---|
| `idle/` | `idle.png` | 待命，團扇立在身側 |
| `run_a/` | `run_a.png` | 跑步 A：前傾、左腳在前 |
| `run_b/` | `run_b.png` | 跑步 B：高抬膝，換腳（腿要和 A 明顯不同） |
| `punch/` | `punch.png` | 直拳出手 |
| `kick/` | `kick.png` | 飛踢 |
| `fan/` | `fan.png` | 揮團扇 |
| `seal/` | `seal.png` | 雙手胸前結印，團扇背在背上或夾在臂間 |

## 輸出
- 每個姿勢：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel2/<資料夾>/candidate-01.png`
- 總比較圖：`pixel2/poses-contact.png`

## 驗收
- 透明背景、全身不裁切、朝右下、7 張是同一個像素斑。
- 跑 A 和跑 B 的腿要分得出來。

## 回報
1. 寫 `pixel2/REPORT.md`，最多 12 行，寫明：
   - route
   - 偏差
   - 額度
2. 完成後建立 `pixel2/DONE`。
