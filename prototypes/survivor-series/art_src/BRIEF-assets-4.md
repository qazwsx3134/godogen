# 派工：地面兩項修正＋抽菸者改台灣流氓（第七輪）

使用者已同意（2026-10-12）。依序 A → B，每件做完更新報告再接下一件，不用等回覆。只生成候選，不 approve、不做動畫。

這輪在 **Mac** 上跑，路徑跟第六輪不同：
- `SS/` = `/Users/peter/repo/godot/godogen/prototypes/survivor-series/`
- `ASF/` = `/Users/peter/repo/agent-sprite-forge/`
- Godot 4.7：`/Applications/Godot.app/Contents/MacOS/Godot`
- Python 不建 venv：`uv run --no-project --with-requirements ASF/requirements.txt python ASF/skills/<skill>/scripts/<script>.py ...`

## 共同規則（同第六輪 `BRIEF-assets-3.md`）
- 生圖一律 `--route codex-cli`，不碰任何 API；`--style-ref SS/art_src/heroes/man/master-green/master_rgba.png`。
- 原始 generated.png、prompt.txt、job.json、run.json 全留；每項一張並排比較圖（舊 vs 新）。
- 每筆生成設 360 秒時限；逾時停掉、記在報告，最多重跑一次。
- 做不到就寫明並跳過；整條生圖路徑不能用就停下回報，不改用 codeart。

## A. 地面兩項修正（其他地面與 `map/props/` 不動）
1. **地磚水平接縫**：`SS/art_src/map/ground/pavement.png` 上下邊接不起來。`map/preview/ground-repeat-3x3.png` 在 y=512、1024 整列都有灰縫錯位的小缺口（菱形角對不上），遊戲裡每 512 px 會出現一條斷線。左右邊也順便查。
   - 要求：上下、左右拼接時灰縫線條連續，菱形角對齊，3×3 放大看不到任何一列／一行缺口。可以修現有圖（例如讓菱形格週期整除 512、或對邊重繪接縫帶），不一定要重生；其餘外觀（低對比、暖灰褐、菱形大小）保持。
   - `extract_terrain_tiles.py --edge-policy seamless --strict-qc`，不放寬門檻；報告附 QC 數字，並附一張接縫處（y=512 附近）放大 3 倍的截圖。
2. **濕地反光**：`map/ground/wet_reflection.png` 現在是一道往燈籠上方飄的亮點，看起來像火星或煙，不像地面倒影。
   - 要求：燈籠在濕地面上的倒影——暖紅橘、垂直拉長的模糊光帶，落在**燈籠柱底座附近及其下方（朝鏡頭方向）**的地面，邊緣柔和、半透明，不蓋掉地磚紋路。
   - 比較圖用 `map/props/` 的燈籠柱，擺法同 `map/preview/wet-reflection-comparison.png`。
3. 預覽 `map/preview/ground-layered-hero90.png` 重出：暖光暈與濕地反光都貼在燈籠柱底座旁（現在暖光暈離燈籠太遠）。
4. 重新 `export_godot.py` 到 `SS/art_src/map/godot/`，用 Godot 4.7 實際匯入確認 0 錯，更新 `root-validation.json`。

## B. 抽菸者改成台灣流氓（3 張候選）
- 虛構的成年男性，手臂刺青、叼菸。髮型照 `SS/docs/reference/阿志.png`：兩側與後腦剃到見頭皮的高漸層（high skin fade），頭頂留短、剪成平頂的黑髮。
- **參考圖是真人照片：只借髮型，臉與身分要虛構，不畫成照片裡的人。** 不把照片當 identity-ref；prompt 用文字描述髮型即可，若要附圖只能當髮型參考並在 prompt 寫明。
- 其餘同其他敵人：`--class mob`、朝右下、50 度俯視、透明、pixel、`--style-ref` 男主角。
- 輸出 `SS/art_src/enemies/smoker-gangster/candidate-0{1,2,3}.png` 與 `candidates-contact.png`（附遊戲尺寸 90 px 預覽）。

## 回報
寫到 `SS/art_src/ASSETS-REPORT-5.md`，每完成一件更新一次（A、B 各一段，全部 ≤30 行）：生成路徑、輸出路徑與比較圖、QC 數字、與要求不符之處、問題。全部完成後在報告最後一行寫 `DONE` 或 `BLOCKED：原因`，對話也只回這一行。
