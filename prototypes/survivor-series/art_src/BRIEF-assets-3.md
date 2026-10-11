# 派工：地面重做、抽菸者改台灣流氓（第六輪）

使用者已同意這兩件（見 `PROGRESS.md`「下一步」）。依序 A → B，每件做完更新報告再接下一件，不用等回覆。只生成候選，不 approve、不做動畫。

`SS/` = `/mnt/d/repo/godot/godogen/prototypes/survivor-series/`；工具 repo `ASF/` = `/mnt/d/repo/agent-sprite-forge/`。
Python 不建 venv，一律用 uv：`uv run --no-project --with-requirements ASF/requirements.txt python ASF/skills/<skill>/scripts/<script>.py ...`（已驗證 `forge_doctor.py` 可跑，codex-cli 路徑 ready）。

## 共同規則（同第五輪）
- 生圖一律 `--route codex-cli`；不碰任何 API。
- 畫風參考 `--style-ref SS/art_src/heroes/man/master-green/master_rgba.png`。
- 原始 generated.png、prompt.txt、job.json、run.json 全留；每項一張並排比較圖。
- 每筆生成設 360 秒時限；逾時停掉該筆、記在報告，最多重跑一次（第五輪汽車 e 方向曾卡 3 小時）。
- 某項做不到就在報告寫明並跳過；整條生圖路徑不能用就停下回報，不改用 codeart。

## A. 地面重做（只做地面，道具 `map/props/` 保留不動）
現在的問題：地磚只有 128×128、橘色反光條紋鋪滿、對比太高（敵人與煙霧會看不清）、重複一眼可見、斜菱形鋪磚看不出來、斑馬線糊。
- 無縫地磚，遊戲尺寸 512 px 以上；低對比、中性暖灰褐；斜菱形鋪磚在遊戲尺寸清楚可辨。風格基準仍是 `SS/art_src/background/street_block/selected.png`。
- 反光從地磚拆出來，做成只放在燈籠附近的透明疊加層：暖色光暈、濕地反光各一。
- 斑馬線重做成清楚的透明疊加層。人孔蓋、排水溝蓋、水窪、裂縫若跟新地磚不搭就一起重做，否則沿用。
- `extract_terrain_tiles.py --edge-policy seamless --strict-qc`，不放寬門檻；報告附 QC 數字。
- 重新 `export_godot.py` 到 `SS/art_src/map/godot/`，並用 Godot 4.7 實際匯入確認無錯。
- 預覽：3×3 拼接圖、「地面＋疊加層＋道具＋主角 se 原畫 90 px」示意圖，放 `SS/art_src/map/preview/`。
- 舊地面移到 `SS/art_src/map/ground/v1/` 保留，新版放 `SS/art_src/map/ground/`。

## B. 抽菸者改成台灣流氓（3 張候選）
- 虛構的成年男性，手臂刺青、叼菸。髮型照 `SS/docs/reference/阿志.png`：兩側與後腦剃到見頭皮的高漸層（high skin fade），頭頂留短、剪成平頂的黑髮。
- **參考圖是真人照片：只借髮型，臉與身分要虛構，不畫成照片裡的人。** 不把照片當 identity-ref；prompt 用文字描述髮型即可，若要附圖只能當髮型參考並在 prompt 寫明。
- 其餘同其他敵人：`--class mob`、朝右下、50 度俯視、透明、pixel、`--style-ref` 男主角。
- 輸出 `SS/art_src/enemies/smoker-gangster/candidate-0{1,2,3}.png` 與 `candidates-contact.png`（附遊戲尺寸 90 px 預覽）。

## 回報
寫到 `SS/art_src/ASSETS-REPORT-4.md`，每完成一件更新一次（A、B 各一段，全部 ≤30 行）：生成路徑、輸出路徑與比較圖、地面 QC 數字、與要求不符之處、問題。全部完成後在對話最後只回一行：`DONE` 或 `BLOCKED：原因`。
