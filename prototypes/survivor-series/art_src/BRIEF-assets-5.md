# 派工：地磚改成斜俯視長方形鋪磚（第八輪）

使用者已同意（2026-10-13）。只做地磚，其他地面疊加層與 `map/props/` 不動。只生候選，不定案。

路徑（WSL）：
- `SS/` = `/mnt/d/repo/godot/godogen/prototypes/survivor-series/`
- `ASF/` = `/mnt/d/repo/agent-sprite-forge/`
- Python：`uv run --no-project --with-requirements ASF/requirements.txt python ASF/skills/<skill>/scripts/<script>.py ...`

## 共同規則（同 `BRIEF-assets-3.md`）
- 生圖一律 `--route codex-cli`，不碰任何 API；畫風參考 `--style-ref SS/art_src/heroes/man/master-green/master_rgba.png`。
- 原始 generated.png、prompt.txt、job.json、run.json 全留。
- 每筆生成設 360 秒時限；逾時停掉、記在報告，最多重跑一次。
- 做不到就寫明並跳過；整條生圖路徑不能用就停下回報，不改用 codeart。

## 問題
現在的 `map/ground/pavement.png` 是斜菱形鋪磚，在遊戲裡看起來像 45° 等角地圖，跟人物、道具的 **50° 斜俯視（鏡頭在正南上方往下看，畫面上方＝遠處）** 不搭。

## 要求
- 台灣夜市街道地面：長方形水泥／石材鋪磚，**磚縫橫平豎直**（橫向一排排，可交錯排列 running bond），沒有任何斜線或菱形。
- 斜俯視的透視：磚塊在畫面上**橫向較寬、縱向被壓扁**（約 0.75），但沒有消失點（正交投影，每排一樣大）。
- 一塊磚在遊戲尺寸約 48–64 px 寬；低對比、中性暖灰褐，跟現在一樣不搶戲（敵人與煙霧要看得清）。
- 無縫 512×512：`extract_terrain_tiles.py --edge-policy seamless --strict-qc`，不放寬門檻；週期要整除 512 讓磚縫在接縫處對齊。
- 3 張候選：`SS/art_src/map/ground/r8/candidate-0{1,2,3}.png`（512，已無縫處理），每張附 3×3 拼接預覽與一張「地磚＋`map/props/` 攤位與燈籠柱＋主角 se 原畫 90 px」示意圖，放 `SS/art_src/map/preview/r8/`。
- 現行 `map/ground/pavement.png` 不要覆蓋。

## 回報
寫到 `SS/art_src/ASSETS-REPORT-6.md`（≤20 行）：生成路徑、輸出與預覽路徑、每張的 QC 數字、與要求不符之處。最後一行寫 `DONE` 或 `BLOCKED：原因`，對話也只回這一行。
