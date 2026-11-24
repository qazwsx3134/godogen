# parallax-camp 實作交接（給 Codex）

你在另一個 pane 已經做完美術；這次換你實作 Godot 原型。主 session（Claude）只負責驗收。

## 1. 目標
2D 橫向捲軸、楓之谷式多層 parallax 的「森林營地」小場景原型。
假說：六層 parallax ＋ 逐漸入夜（越近的層暗得越快）＋ 只照亮自己那層的光源，能做出有景深、有氣氛的營地。
不是完整遊戲：一張可左右走動的營地地圖 + 三個互動點 + 日夜循環即可。

## 2. 使用者原始需求（docs/parallex/spec.md，必須全部做到）
- pixel art 遊戲。
- 分層與 `Parallax2D.scroll_scale.x`：sky 0.03、far 0.1、mid 0.24、near 0.45、closest 0.7、遮蔽（fg_occluder，介於角色與玩家之間）1.3。遮蔽放在不影響重要互動的地方（只在左右兩側，營地中央空出來）。
- 森林；夜晚有星空（sky_night.png 淡入取代 sky.png）。
- 營地：營火、看道具的地方（item_rack）、煮飯的地方（cook_rack），另有帳篷、路燈。
- 角色：左右走、跳；**起跳有聲音、落地有聲音**。
- 陰影：用 RayCast2D 做角色腳下陰影（往下射線，陰影貼在命中點，離地越高越小越淡）；另可用 LightOccluder2D 讓營火/路燈投影。
- 時間越來越晚：`CanvasModulate` 整體變暗；且**越近的 parallax 層暗得越快**（darker per row）：每層自己的 modulate 依深度乘一個額外暗化係數，closest/遮蔽最暗、sky 最少。
- 營火、路燈用 `PointLight2D`，用 **`range_item_cull_mask`（item cull mask）只點亮所在那一層**：每層 CanvasItem 設不同 `light_mask` 位元，光源只對自己那層的位元生效。

## 3. 素材（已完成，不要重生）
全部在 `prototypes/parallax-camp/art/final/`，說明見 `art/final/REPORT.md`、風格基準 `art/final/preview.png`（實作完的畫面要接近這張）。
- sky.png / sky_night.png 1080×360 不透明；far 1662×230、mid 1320×230、ground 492×120（可水平無縫平鋪，來自 erwin-run）；near、closest、fg_occluder 480×270 透明。
- props/：campfire_sheet.png（6 幀×64 橫排）、tent、item_rack、cook_rack（128²）、street_lamp（256²）—— 尺寸不一，在場景裡用 scale 對齊比例，參考 preview.png 的相對大小。
- hero/：idle/walk/jump 各 4 幀 × 64×64，frames.json 有錨點；walk 腿部交替偏弱是已知限制。
- 可直接搬 art/final 的檔案到 `assets/`（或直接引用 art/final），被否決的 art/_rejected/、style-options/ 不要用。
- 音效：用 godot-kit 的 `synth.gd` / `sfx_bank.gd` 合成佔位（jump、land、互動），不另外生成。

## 4. 技術規格
- Godot 4.7（`godot` 在 PATH，4.7.stable），GL Compatibility。
- 參考 `prototypes/erwin-run/`（同一套背景、640×360、Parallax2D 用法、project.godot 設定）。建議 480×270 或 640×360 viewport、`stretch/mode="viewport"`、紋理 filter Nearest、整數縮放。選一個並在 README 說明。
- 世界寬度約 3 個螢幕，相機跟隨角色（評估 godot-kit 的 Phantom Camera，`prototypes/godot-kit/docs/PHANTOM-CAMERA.md`；簡單 Camera2D 跟隨就夠也可以）。
- 互動：靠近營火/道具架/煮飯架顯示提示，按鍵（E）觸發簡單回饋（例：道具架彈出一個小面板列 3 件道具、煮飯架冒煙+音效、營火加柴變亮）。
- 日夜：一個時間參數 0→1（白天→深夜），約 60 秒一輪，或按 T 快轉；同時驅動 CanvasModulate、各層暗化、sky→sky_night 淡入、燈光能量（夜晚亮）。
- 操作：A/D 或 ←/→ 走、Space/W 跳、E 互動、T 快轉時間。

## 5. 專案規範（必讀）
- 先讀 `/mnt/d/repo/godot/godogen/AGENTS.md`（Godot 開發：畫面用 scene 與 node 組成）與 `prototypes/LESSONS.md`（Parallax2D 相關的坑在第 158–159 行附近）。
- 畫面、角色、營地物件、互動點做成 `.tscn`（互動點做一個 item scene 再實例化）；新建/大改 scene 用 Godot 存（headless 腳本 `PackedScene.pack()`＋`ResourceSaver.save()`），不要手寫大型 .tscn。存完 headless 匯入確認無錯誤。
- 版面交給 node；行為交給腳本，`%唯一名稱` 取子 node，跨節點事件用 typed signal。
- 建好 project.godot 後跑 `prototypes/godot-kit/sync.sh parallax-camp`，用 kit 的 synth / sfx_bank / test_kit。kit 副本不可直接改。
- 視窗擷取一律 offscreen（xvfb-run 或 headless），不要在使用者桌面彈視窗。
- 只改 `prototypes/parallax-camp/` 內的檔案（LESSONS.md 新增坑除外）。不 commit、不 push。

## 6. 驗收（L2：單元測試＋冒煙）
1. headless 匯入無錯誤。
2. test_kit 測試：六層 scroll_scale 數值正確；fg_occluder 在 1.3；角色起跳與落地各發一次音效事件；時間 t=1 時 closest 層亮度 < near < mid < far < sky；燈光只照自己層（檢查 light 的 range_item_cull_mask 與該層 light_mask 一致、與其他層不重疊）；RayCast2D 陰影在離地時縮小。
3. 用 xvfb-run / --write-movie 截兩張圖：白天與深夜，存 `captures/day.png`、`captures/night.png`；深夜圖裡營火只照亮營地那層。
4. 走到最左與最右，遮蔽層不擋住三個互動點（截圖或測試證明）。

## 7. 交付
- `README.md`：假說、執行方式、操作、主要 scene 與可調 node/export 欄位、狀態、已知限制。
- 更新 `PROGRESS.md`（新的在上）：日期、完成/未完成、驗證指令與結果。
- 最後寫 `prototypes/parallax-camp/IMPL-REPORT.md`（≤20 行）：完成項目逐條對照第 2 節、測試指令與結果、截圖路徑、做不到的項目直說。**這份檔案出現＝完成訊號**，請最後才寫。
