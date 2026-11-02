# 萬事屋吐槽 ADV · debt-commission：進度與交接

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。每次 commit、出門／下班／暫停前更新本檔，根目錄 `Progress.md` 只更新一行摘要。接手順序：本檔 → [README](README.md) → [session-state](production/session-state/active.md) → [HANDOFF](docs/HANDOFF.md)。

## 2026-11-02｜立繪步驟、演出修正與角色身高

- 專案／分支：debt-commission／master，基準 HEAD `18a2c336`。本輪完成使用者連續要求：退場與暗化獨立、抖動／彈跳修正、準備站位及進退場動畫檢查、角色身高設定並自動縮放。未 commit／push；作者持續修改的 `stories/katsura_dog_ears/dog_ears_story.json` 保留，本輪未寫入該故事。前輪插入步驟的修改一併留在工作區。
- 已完成：立繪分類分成角色登場／表情、角色退場（portrait_exit）、立繪明暗（portrait_lighting）、立繪動作。舊 char visible:false 依退場表單呈現而不自動改檔；切換類型保留角色與相容動畫。明暗支援 dim／lit／auto，隨存讀檔與回合／調查舞台還原；舊存檔缺欄位時預設 auto／fade。
- 動作 bug：以「動作 → 第一句台詞」及「動作 → 漫畫吐槽」重現 shake／bounce 共四項 FAIL；原因是未登場的動作被略過，以及同幀漫畫層蓋住舞台。現在未登場先入場再做動作，動作與台詞可同拍，其他後續指令先等動作完成。準備站位會保留所選登場 transition；台詞原有 offscreen:true 仍不登場，表單新增明確的「畫外音（說話者不登場）」核取框，可由作者取消，未擅改故事。
- 身高設定：「素材設定 → 角色 → 身高 cm」，存檔後重新試玩生效；作品繼承的角色也可設定身高並建立作品覆寫。先填桂 175、銀時 177、神樂 155。以頭頂／腳底校準 height_bounds，排除透明留白及神樂的傘；按 177 cm＝1560 單位計算，等比縮放、對齊腳底，表情維持像素比例，站位示意亦套用身高。未設身高的角色沿用原 scene 大小；換成不同構圖的新主圖時需重新校準 height_bounds。
- 本輪 L2：Node `node --test prototypes/debt-commission/tools/story_editor/test_portrait_controls.cjs prototypes/debt-commission/tools/story_editor/test_step_insert.cjs prototypes/debt-commission/tools/story_editor/test_node_types.cjs` **15 PASS**。在 prototype 內用 `python3 tools/story_editor/run_coordinated.py <Godot> --headless --path . --script res://tests/test_<suite>.gd` 依序跑 character_height、portrait_reaction、portrait_controls、portrait_motion、save_validation、phase3_ui，**6 suites PASS**；最終 logs `/private/tmp/debt-portrait-final-20261102/`。比對實際 Art 位移、alpha、175/177 與 155/177 身高、共同腳底、切表情、身高單值變更，以及明暗存讀、非法資料與 offscreen。log 無 SCRIPT／Parse Error，部分有 macOS 憑證、MCP 沙箱監聽及退出資源清理訊息，不宣稱零錯誤。
- 真實 Chrome：`node prototypes/debt-commission/tools/story_editor/portrait_motion_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --godot /Applications/Godot.app/Contents/MacOS/Godot` **PASS**（沙箱外，暫存專案及實際 Godot validator），涵蓋獨立進退場／明暗、動作、畫外音切換、身高欄位存回／重開、繼承角色身高及新故事試玩。測試曾在讀取未完成的素材面板時失敗，補等待後完整重跑通過。JS 語法與 diff 空白檢查 PASS。
- 重要檔案：main.gd、scripts/{placeholder_sprite,story_runner,asset_usage}.gd、tools/story_build/dm_source.gd、tools/story_editor/{editor,story_core,catalog_editor}.js、兩份 catalog，以及三支新 Godot 測試與 JS／瀏覽器測試；README、STORY-EDITOR、IMPLEMENTATION、session-state 同步。未改 tscn、未生成／改寫圖片、未重匯 Web 舊包、未跑完整 L3／手機／GPU 視覺驗收。下一步：作者重新整理編輯器、存好素材設定後重開場景試玩；新台詞若期望開口登場，確認畫外音未勾選。

## 2026-11-02｜故事編輯器指定位置插入步驟

- 專案／分支：debt-commission／master，基準 HEAD `18a2c336`。使用者希望在長場景的指定位置直接插入步驟，避免從尾端逐次上移。本輪功能完成，未 commit／push；保留原有 `stories/katsura_dog_ears/dog_ears_story.json` 修改，未改故事內容。
- 已完成：側欄每一步前提供「＋ 插入步驟」，就地選七類型後插入或取消；新增後自動捲到並聚焦新步驟，支援復原／重做與唯讀限制。Core.addStep 接受指定索引，拒絕無效位置、在終止步驟後插入，以及把終止步驟插入段落中間；保留原有尾端新增、分支目標及台詞未知欄位。
- 本輪 L2：`node --test prototypes/debt-commission/tools/story_editor/test_step_insert.cjs prototypes/debt-commission/tools/story_editor/test_node_types.cjs` **12 tests PASS**；`node prototypes/debt-commission/tools/story_editor/step_insert_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'` **PASS**（沙箱外 Chrome，僅暫存記憶體故事），涵蓋 60 句長場景中間／開頭／結尾前插入、捲動聚焦、取消、復原／重做、禁止中間終止步驟、原新增鈕及唯讀。初次瀏覽器測試因 fixture 誤用 `background:bg` 失敗，改用正式 `scene:bg` 後完整重跑通過。JS 語法與 `git diff --check` 通過。
- 重要檔案：`tools/story_editor/story_core.js`、`editor.js`、`editor.css`、`test_step_insert.cjs`、`step_insert_smoke.mjs`；README、STORY-EDITOR 與 session-state 已更新。沒有 scene／Godot runtime 變更，未跑 Godot 或完整遊戲 suite；手機與實際存回檔案流程本輪未重驗。下一步：重新整理編輯器，在原有場景試用指定位置插入；沒有其他延期功能或阻礙。

## 2026-11-02｜故事編輯器節點與步驟類型

- 專案／分支：debt-commission／master，基準 HEAD `0f52e45a`。使用者要求右鍵節點切換類型／新增選項，以及更改既有步驟類型。未 commit／push；原有 VFX、故事背景與其他未提交修改保留。
- 已完成：場景卡右鍵或標題列「⋮」可切換一般場景、選項／條件分支、跳轉、結局，也能新增選項；右鍵流程小節點可定位步驟類型，側欄每一步可切換。轉換計畫先在副本執行，取代已寫內容需確認；可沿用的文字與單一出口保留，多個不同目標不猜測，支援復原／重做及唯讀限制。使用和開啟方式見 `prototypes/debt-commission/docs/STORY-EDITOR.md`。
- 本輪 L2：`node --test --test-isolation=none prototypes/debt-commission/tools/story_editor/test_node_types.cjs`（9 tests PASS）；以 `/tmp/debt-node-ui-smoke.cjs` 的 Domino 模擬 DOM 執行實際編輯器腳本，涵蓋右鍵、選項、取消、復原／重做、步驟切換、⋮、Esc、唯讀 PASS；以轉換產生的暫存分支故事執行 `godot --headless --path prototypes/debt-commission --script res://tools/story_editor/check_story.gd -- /tmp/debt-type-conversion-story.json --write`，4 節點驗證與版本重算 PASS（Godot MCP 監聽因沙箱被拒，與驗證分開）。JS 語法與 diff 空白檢查 PASS。未改 `.tscn`。
- 未驗範圍：新增 `node_type_smoke.mjs` 的 Chromium 實際瀏覽器回歸因沙箱 `setsockopt: Operation not permitted` 無法啟動，非瀏覽器 PASS；視覺位置、手機操作與本機服務的實際儲存流程尚待正常桌面環境驗收。未重跑完整遊戲 suite。下一步在桌機啟動 `python3 preview/start.py`，開故事編輯器試用右鍵／⋮與步驟切換；有 Playwright 時依編輯器說明重跑瀏覽器回歸。

## 2026-11-02｜桂極短篇與萬事屋背景

- 專案／分支：debt-commission／master，基準 HEAD `0f52e45a`；使用者指出 `aea4c5d9c46870d5a3cf077924d3d98076753644` 有短篇，已確認該 commit 是現行 HEAD 的祖先，包含《不是頭痛，是桂》。前次回答找不到新極短篇有誤：本篇有作者指定台詞、分句及玩家時機吐槽，已存 `stories/katsura_dog_ears/`。未改故事台詞或另建人物記憶。
- 使用者希望視覺小說背景貼近《銀魂》原作，並選擇**直接生成**所描述的一張萬事屋客廳背景。已以 imagegen 生成並補上「糖分」掛字 `stories/katsura_dog_ears/art/yorozuya_anime_bg_v2.png`，1672×941 RGB，1,769,884 bytes，SHA-256 `7feacfbb52ee2bbe75f7dec975ecb792c7859906d66ed8fce46bbf6d2a4a2c2e`；以本 repo 既有真人版室內照片作家具配置參考，以動畫上色呈現。原樣保存、僅供本篇作候選，無掛字 v1 保留；既有桂／伊莉莎白／新八圖未覆蓋。
- 本篇 `catalog.json` 覆寫 `yorozuya_living_room` 到新圖片；其他故事的 base catalog／背景與第一章調查熱區未改。作品 README 與原草稿已標記新候選，`art/README.md` 記錄來源；`docs/ART-SPEC.md` 註明現行橫向及 art-check 尺寸提示仍是舊直式規格。編輯器從 `http://127.0.0.1:8000/tools/story_editor/?story=katsura_dog_ears` 開，服務用 repo 根目錄 `python3 preview/start.py`。
- 本輪 L2：隔離 XDG 用 `godot --headless --path prototypes/debt-commission --editor --import --quit` 匯入（`/tmp/debt-katsura-20261102-import-v2.log`）；`godot --headless --path prototypes/debt-commission --script res://tests/test_katsura_dog_ears.gd` **PASS**（`/tmp/debt-katsura-20261102-tests-v2.log`），包含本篇背景解析、實際 reading scene 背景載入、base catalog 不變及原吐槽時機流程；`test_story_packs.gd` **PASS**（`/tmp/debt-katsura-20261102-packs-v2.log`）。`python3 preview/test_preview.py -v` **10 PASS**，含本篇被故事編輯器服務發現與 PNG 載入；這些 HTTP 測試使用記憶體 handler。Node 執行故事編輯器 `resolveCatalog`，本篇及 base 的路徑各自正確。PNG CRC／16:9／catalog 檢查 PASS，project.godot 雜湊前後不變。
- 限制：匯入／測試有沙箱 TCP 監聽 ERR_CANT_CREATE 與退出資源清理訊息，無最終 SCRIPT／SHADER／parse 錯誤；非 headless 實際畫面嘗試因 X11／Wayland 無法連線失敗（`/tmp/debt-katsura-20261102-visual.log`），因此新背景與角色／UI 疊合外觀、Web 及手機尚未驗收。現有 `build/web/index.pck` 不包含桂故事或新背景，未重匯 Web；不要說該舊包已更新。未跑完整遊戲 suite。`art_check.gd` 背景尺寸建議仍是舊直式，未改其行為。
- 下一步：使用者從編輯器以 Godot 4.7 試播本篇，確認新背景與既有角色畫風、裁切及 QTE 可讀性，再依回饋調整；其他場景若要換成原作風格需逐一盤點。本輪與先前其他專案／圖片修改均保留未提交；未 commit／push／發布。
