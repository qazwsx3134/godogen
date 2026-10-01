# 聖地展望台 — TODO

可執行清單。決策與規格數字以 [PROJECT.md](PROJECT.md) 為準；操作方式見 [README.md](README.md)。標記 **[你]** 的項目需要使用者動手，其他由 Claude 做。

## 現在的狀態（2026-10-01）

- v0 能跑：觀看器、HUD、品質檔位、互動測試 21 項全過、截圖與效能預算檢查都有。
- 美術不合格：程序生成的臉和方盒子村莊都要換掉。路線已定為「AI 生成高模 → 減面烘焙」，見 PROJECT 的 D1–D10。
- **v0 尚未 commit**。工作區另有 `prototypes/debt-commission/` 的未完成變更（不屬於這個原型）。commit 時只加入 `prototypes/seichi-pov/` 和 `prototypes/README.md`。

## 1. Spike：一顆頭跑完整流程（四代・湊）

步驟對應 PROJECT「B 路線：火影岩完整流程」的階段 0–7 與關卡 A–D。做完才決定後面三顆頭和村莊要不要照這條路走。

**階段 0：前置**
- [ ] **[你]** 安裝 Blender：`brew install --cask blender`（或官網版）。裝好後 Claude 用 `blender -b --version` 確認
- [ ] 修 v0 的貼圖匯入設定（VRAM 壓縮、mipmap、法線貼圖旗標），重新截圖作為新基準（同第 3 節第 1 項）
- [ ] 寫 `tools/blender/`：normalize → cull → decimate → uv → bake → export → report。每一步都可單獨重跑，參數放在同一個設定檔
- [ ] 先用 v0 的程序化臉當假高模，把整條管線跑通，不必等 AI 模型

**階段 1–3：生成（你）**
- [ ] **[你]** 生成定稿圖：整面岩壁、四顆頭、寫實花崗岩、從村子仰視（規格見 PROJECT「輸入圖規格」）。也可以請 Claude 用 `asset_gen.py image --model gemini` 生成，約 10¢
- [ ] **[你] 關卡 A**：四張臉都認得出來、風格一致、是寫實的花崗岩
- [ ] **[你]** 從定稿圖裁出四代的頭，整理成單顆的輸入圖；若用多視角輸入，加一張側面圖
- [ ] **[你]** 同一張輸入圖在 Meshy 和 Tripo 各生成一次（最高品質、不設 face limit、PBR、GLB），放到 `art_src/hokage_rock/heads/minato/{meshy,tripo}/`，附 `notes.md`

**階段 4–5：處理與進 Godot**
- [ ] 兩家的模型各跑一次 Blender 管線，比較原始面數、清理難度、烘焙後的辨識度、像素誤差
- [ ] **關卡 B**：每顆頭 ≤ 15k 面；輪廓誤差 55° 時 ≤ 1 px、24° 時 ≤ 2 px
- [ ] 把四代的低模嵌進崖體（崖體高度場拿掉那顆頭的程序浮雕）；high、mid、low 三個檔位各跑一次 `capture.gd`
- [ ] **關卡 C**：效能預算 OK；`test_viewer.gd` 全過

**階段 6–7：審核與收尾**
- [ ] **[你] 關卡 D**：看平台視角、望遠鏡、Meshy 與 Tripo 並排比較的截圖；確認辨識度和寫實度過關，選定一家
- [ ] 把 spike 結果寫進 PROJECT（選哪一家、預算要不要調整），更新本清單
- [ ] commit：只加入 `prototypes/seichi-pov/` 和 `prototypes/README.md`

## 2. 火影岩完成

- [ ] **[你]** 另外三顆頭（初代、二代、三代）走階段 2、3，用 spike 選定的平台生成
- [ ] 三顆頭走階段 4–7，通過關卡 B、C、D
- [ ] 崖體換成 CC0 實拍岩石 PBR 貼圖（ambientCG／Poly Haven），加大尺度的色差變化打散重複感，記錄來源、版本、授權
- [ ] 刪掉 `bake_relief.py` 裡的程序化臉（或只留作沒有資產時的 fallback），README 一併更新
- [ ] 比較 Compatibility 和 Mobile renderer 的寫實度與效能，把結論記進 PROJECT 待決事項

## 3. v0 技術債（在 spike 前後順手修）

- [ ] **貼圖匯入設定**：`baked/*.png` 目前是 Lossless、沒有 mipmap，遠看會閃，VRAM 也偏高（4096×2048 一張約 43 MB）。改成 VRAM 壓縮、開 mipmap，法線貼圖開 `normal_map` 旗標；改完重新截圖比對顆粒感
- [ ] 截 mid 檔位（手機實際只會拿到 mid 或 low），把數字補進 README 的表格
- [ ] 測試補上真實手機的輸入路徑：用 `Input.parse_input_event` 送觸控（會經過觸控轉滑鼠的模擬），確認拖曳不會被算兩次；加一個「一指按搖桿、另一指拖曳環顧」同時進行的案例
- [ ] HUD 依 `DisplayServer.get_display_safe_area()` 避開瀏海；加一張 19.5:9 的截圖
- [ ] 編輯器驗收（AGENTS.md）：在 `hud.tscn` 改一個間距或按鈕文字，執行後確認還在；跑測試與截圖前後對 `*.tscn`／`*.tres` 做 hash，確認執行不會改到 scene

## 4. 之後（岩壁驗收通過才開工）

- [ ] 村莊：8–12 種房型加火影大樓，用 Meshy／Tripo 生成（face limit 2–5k）；做近、中、遠三層 LOD 和 `visibility_range`；加上木葉的辨識元素
- [ ] 實機匯出（iOS 優先），量 FPS、發熱，校正品質檔位的判斷門檻
- [ ] 時段切換（白天／黃昏），驗證 D7「只烘焙 AO」夠不夠用
- [ ] 第五張臉（綱手）
- [ ] 第二個景點，驗證「景點可替換」

## 已完成

- [x] v0 原型：專案骨架、godot-kit 同步、程序岩壁與村莊、Viewer／HUD／品質檔位、互動測試、截圖與效能預算（2026-10-01）
- [x] README 修正：卡片文字來源、拿掉未實作的壓縮預算說法、效能預算標暫定（2026-10-01）
- [x] 決定美術風格、建模路線、生成分工與光照策略（PROJECT D1–D10，2026-10-01）
