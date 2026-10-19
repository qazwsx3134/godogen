# 派工：斑的 7 個關鍵姿勢（第二輪）

目標：以選定的斑原畫為身分參考，用 `master_still.py edit`（必要時改用 `generate`，加 `--identity-ref`）產生 7 張姿勢圖，
每個姿勢 2 張候選。只做靜態姿勢圖，不 approve、不做動畫。

## 環境
- forge：`/Users/peter/repo/agent-sprite-forge`，Python 用 `/Users/peter/repo/agent-sprite-forge/.venv/bin/python`。
- **一定要加 `--route codex-cli`**。

## 參考
- 身分參考：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round1/madara/candidate-03.png`。
  只換姿勢，以下都要和參考一致：
  - 臉、及腰黑色長刺髮（遮右眼）
  - 紅色分段甲、深藍衣服、小腿白繃帶
  - 白底紅圓的團扇
  - 動畫賽璐璐畫風、粗墨線
  - 約 42° 斜俯視、身體朝右下
- 共同風格同 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/docs/art-spec.md` 的「共同風格」。
- 背景透明、全身不裁切、`--key green`。

## 姿勢

| 資料夾 | 姿勢（英文寫進 THE ONLY CHANGE 或 pose） |
|---|---|
| `idle/` | calm standing idle, war fan held loosely at his side, slight lean back, arrogant |
| `run-a/` | running toward the lower-right, left leg forward, hair streaming behind, fan held back |
| `run-b/` | running toward the lower-right, right leg forward, the opposite stride of run-a |
| `punch/` | a fast straight punch with the left fist toward the lower-right, right hand holding the fan back |
| `kick/` | a powerful high flying side kick toward the lower-right (combo finisher), body horizontal, hair flaring |
| `fan-swing/` | a wide horizontal sweep of the war fan with both hands toward the lower-right, motion arc implied by the pose, no motion lines |
| `seal/` | both hands forming the tiger hand seal in front of his chest, fan tucked under his arm, eyes intense |

## 輸出位置
- 根目錄：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2/<資料夾>/`
- 每個姿勢的資料夾放 `candidate-01.png`、`candidate-02.png`。
- 全部候選做成一張總比較圖：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2/poses-contact.png`

## 驗收
- 7 個姿勢都是同一個斑，外觀和參考一致。
- 透明背景、全身、朝右下；朝向反了就水平鏡像。
- 做不到就直說並停下，不要用程式繪圖代替。

## 回報
寫到 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2/REPORT.md`，最多 15 行：
- 用的方法（edit 或 generate）與 route
- 每個姿勢的候選路徑
- 外觀偏差

完成後建立 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/round2/DONE`。
