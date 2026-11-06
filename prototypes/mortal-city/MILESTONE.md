# Mortal City 里程碑紀錄

從 `PROGRESS.md` 搬出的較早段落（原文保留，新的在上）。

## 2026-11-05｜sprite 規格化與跑步循環（未提交）

- 專案／分支：mortal-city／master。
- 狀態：S2 16-bit 風格與主角 A 已選定；素材已生成並規格整理。工作樹未提交、未推送，使用者未授權 commit／push。
- 10 項正式 sprite 由內建 image_gen 生成，使用 S2 風格、A 候選及任務場景三張參考；窗外圖因首版高架軌道有列車，已重生無列車版本。

### 已完成

- 早先美術派工：7 張基本頭像／街景素材完成，紀錄在 prototypes/mortal-city/art_src/REPORT.md。
- 風格探索：4 張場景風格與 1 張主角候選完成，紀錄在 prototypes/mortal-city/art_src/STYLE_REPORT.md。
- Sprite 派工的 10 張規格化圖已存於 art_src/sprites_raw/；尺寸、內容、參考圖與接縫驗證列於 art_src/SPRITE_REPORT.md（≤12 行）。Claude pane `wT:pV`（`mortal-sprite-handoff`）完成規格化，未 commit／push。
- 視覺檢視包含空房綠窗、無列車窗景、家具／道具表、A 三姿勢、遠／中／前景、五節列車與無人機、屋頂條。
- 跑步循環依 RUN_BRIEF 生成並存到 art_src/sprites_raw/raw/hero_run_cycle.png；RUN_REPORT 記錄參考圖、格數及限制。

### 尚未完成／限制

- 跑步循環原圖為 1774×887，背景取樣 RGB(4,248,5)，不是精確 #00FF00；使用者指定只生成存檔、不後製，故未縮放或校色。詳見 art_src/RUN_REPORT.md。
- README 記錄 sprite 場景組裝入口；工作樹另有場景接入與預覽相關未提交修改，尚未做整體人工驗收。本次沒有改動那些程式。

### 驗證

- 本 session 用 Pillow 檢查 9 張非窗景成品：尺寸符合 brief、RGB、所有 4×4 區塊同色；另以 `sips` 確認 window_city.png 為 960×352，並視覺確認不透明且無列車。完整 10 張尺寸、綠幕與接縫結果見 SPRITE_REPORT.md。
- 跑步圖以 `sips` 確認為 1774×887；Pillow 取樣確認背景接近綠但非精確 #00FF00。圖像任務無需執行程式測試；未測試現有場景接入程式。
- 工作區另有 preview 與遊戲程式修改；本次保留、不重置、不提交。

### 重要入口與下一步

- 派工與回報：art_src/SPRITE_BRIEF.md、art_src/SPRITE_REPORT.md、art_src/RUN_BRIEF.md、art_src/RUN_REPORT.md。
- 素材根目錄：art_src/sprites_raw/；參考：art_src/style_explore/s2_16bit.png、art_src/style_explore/c1_heroes.png 與 art_src/ref/ 場景圖。
- 下一步：作者驗收城市 sprite 場景組裝；跑步循環如需用於引擎 sprite sheet，再另行授權尺寸整理／校色。
