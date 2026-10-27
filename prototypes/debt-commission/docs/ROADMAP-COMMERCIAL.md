# debt-commission 商業級打磨 Roadmap

日期：2026-10-18。由 Claude（遊戲本體、UI、內容）與 Codex（編輯器、發行／品質）共同盤點。逐項證據見各 TODO 的「證據」欄。
量級：S ≈ 半天到一天，M ≈ 2–4 工程日，L ≈ 1–2 週以上。這是工程量的粗估，不含授權洽談、劇本產量與真人測試排期。
優先度：P0 不做就不能公開發行；P1 達到商業品質的必要項；P2 加分項。

## 已決定（使用者，2026-10-19）

1. **發行路線：私人原型。** 原聲帶與現有角色圖可以留在本機版本；不上傳 itch.io 或其他公開平台。標 P0 的發行關卡（B01 allowlist、B04 真機矩陣、素材授權）降為「改路線時才需要」，其餘照常做。
2. **劇本來源：** 既有章節以 `.dialogue` 為唯一來源，編輯器對它們只做檢視與診斷；新故事以編輯器的 JSON 為唯一來源，提供一次性的「轉成圖編輯來源」。不做 JSON → `.dialogue` 的反向轉換。
3. **美術方向與系統定位（2026-10-19）：** 先維持手繪蠟筆風，不重繪。長期目標是讓創作者用這套系統，自己提供故事與畫作，做出不同的作品；第一章是示範作品。新功能優先考慮「別人的故事與圖也能放進來」，不寫死萬事屋的角色或畫風。

## 待辦總覽（2026-10-23 更新）

細節與證據在下方各里程碑的表格；這裡只列還沒完成的，依「誰來做」分組。

```
等你決定 ──→ 第一章署名 ──→ Claude／Codex 才動手
等你做（真人）  C2 試讀、C3 音效、B04/B17 真機
Claude 下一批   G6（碰到哪拆到哪）
編輯器下一步    A07 複製子圖、A11 複雜互動表單；依第一篇短篇的實際需要調整
```

**等你決定**
- 第一章的署名：劇本、美術各寫什麼名字（寫進 `story_src/chapter1.blocks.json` 的 `story.credits`，製作名單與章節列就會出現）。
- 舊的 repo 層級問題（不屬本專案、這輪沒動）：`.claude/` 約 200 個檔案在 `.gitignore` 裡卻仍被追蹤；`prototypes/survivor-series/art_src/` 有 274 張候選圖被它自己的 `.gitignore` 排除卻仍被追蹤。要不要移出版控。

**等你做（真人才能完成）**
- C2 第一章作者試讀與修訂；`BR` 開頭的分支結局台詞是 Claude 寫的，一併試讀（C1）。
- C3 正式音效與配樂（目前是合成佔位音加原聲帶）。
- B04／B17 Android Chrome、iOS Safari 實機：首次點擊、切到背景再回來是否有聲音（B05）、單手操作、遊玩時間、金色氣焰與光束的強度（TODO.md B 段）。

**Claude 下一批（建議順序）**
1. G6 拆分 `main.gd`：調查、回合、QA 快照在功能碰到時再拆。
2. 之後：B06 PWA safe area（真機確認需要才做）、G4 流程圖、G7 多語系、C4 第二章流程（與你一起）。

**Codex**
- 已完成（2026-10-23）：編輯器以「場景」為單位（契約見 `IMPLEMENTATION.md`「編輯器的場景檢視」）——場景卡的背景縮圖與 BGM 試聽（沿用／依路線不同／無）、可收合的流程小節點、分七類的新增步驟，以及 A01、A10／A11 的一部分、A12 量測。
- 已完成：步驟改用中文名稱、A03 存回專案檔案＋A05 一鍵驗證並存檔、編輯器的外觀包／封面／預設視角（codex-03）。編輯器的故事包支援由 Claude 完成。
- 2026-10-27：從選定場景試玩（A09）：可帶入旗標／線索，在獨立遊戲資料中玩尚未存檔的內容；前置舞台與互動狀態不自動重建。
- 2026-10-27：新場景的佔位結尾會在新增分支時替換；結尾後有無法執行的步驟時，編輯器與遊戲驗證皆會報錯。已用瀏覽器從空白建立三個結局，再讓 StoryRunner 逐條走完；M2 的 30 節點完整作者驗收仍待實作與試用。
- 之後：A07、A11；發行／品質 B01、B02、B03、B08、B13、B16。

## 里程碑

```
M0 來源與發行界線 ─┬→ M1 作者不丟稿 → M2 能寫完一章 ─┐
                   │                                  ├→ M4 Web 發行候選
                   └→ M3 劇本系統補齊（分支／結局）───┘
M5 內容：第一章定稿 → 第二章起量產（與 M2／M3 並行）
```

| 里程碑 | 目標 | 驗收 |
| --- | --- | --- |
| M0 來源與發行界線 | 路線決定；每個故事有唯一來源；存檔相容政策；出貨素材 allowlist | 素材 manifest 列出每一件素材的授權狀態；`build_web.sh` 只打包 allowlist 裡的素材 |
| M1 作者不丟稿 | 編輯器有 undo/redo、草稿復原、存回檔案、一鍵驗證 | 編輯 → 存檔 → 關閉 → 重開 → 預覽，修改都還在；寫入衝突時拒絕寫入 |
| M2 能寫完一章 | 搜尋、複製子圖、素材縮圖、常用 op 表單、從任一節點試玩 | 用編輯器從零寫一段 30 節點、3 個結局的分支，不必手改 JSON |
| M3 劇本系統補齊 | 複合條件、數值、結局收集、跨章旗標、流程圖畫面 | 第一章的選擇能影響第二章；結局一覽會記下已看過的結局 |
| M4 Web 發行候選 | 第一章完整的 E2E、CI、大小與冷啟動預算、真機測試矩陣、無障礙 | CI 全綠；iOS Safari 和 Android Chrome 的真機清單逐項打勾 |
| M5 內容 | 第一章從草稿 v0.2 定稿；建立第二章起的量產流程 | 作者試讀完成；真人試玩量到遊玩時間 |

## TODO

狀態：☐ 未做｜◐ 進行中｜☑ 完成。負責：C = Claude，X = Codex，U = 使用者。

### M0 來源與發行界線
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| R1 | ☑ | 發行路線：私人原型 | 見上方「已決定」 | — | U |
| B01 | P0 | 建立素材 manifest（路徑、作者、來源、授權、允許用途、核准狀態），並建立公開版的 allowlist | `assets/audio/music/sources.json` 沒有授權欄位；`assets/image/` 沒有來源 manifest；`export_presets.cfg` 設成 all_resources | M | X |
| A01 | ☑ P0 | 每個故事只有一個可寫來源：registry 記錄 authoring mode；產物設為唯讀；提供「轉成圖編輯來源」（2026-10-23 Codex：建置產物在編輯器唯讀；「轉成圖編輯來源」複製成新 id、拿掉 `generated_from`，下載新故事與含新列的 stories.json） | `stories.json` 每筆 `authoring`；`editor.js:372` 唯讀、`:376` 轉來源；`story_core.js:478` `graphCopy` | M | X |
| B10 | ☑ P1 | 存檔相容政策：只改文案的補丁不影響舊檔；結構改版時做映射，或清楚告知玩家並保留舊檔（2026-10-19：`version` 本來就只算結構；結構改版時舊自動檔改名 `<存檔>.<舊 version>` 保留、標題說明一次，手動欄位標「舊版劇本的存檔」） | `main.gd` `_archive_other_version_save`；`tests/test_save_slots.gd` `_test_older_story_structure` | M/L | C |

### M1 作者不丟稿（編輯器）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| A02 | ☑ P1 | undo/redo（以命令為單位記錄；連續的文字輸入合併成一步） | `editor_state.js:5–23` History；`editor.js:468` 合併聚焦輸入（Codex 2026-10-23 盤點） | M | X |
| A04 | ☑ P1 | 草稿自動存到 localStorage 並能復原；確認存檔真的成功才清掉 dirty；寫入失敗時持續提示 | `editor.js:80–142` 草稿復原／刪除與衝突；`864–877` 比對下載才解除 dirty | M | X |
| A03 | ☑ P1 | 透過本機專案服務直接存回檔案：原子寫入、以基底 hash 偵測衝突 | `project_server.py`、`test_project_server.py` | M | X |
| A05 | ☑ P1 | 一鍵「驗證並存檔」：呼叫 Godot 的 `check_story.gd`，不在 JS 重寫 fingerprint | `editor.js`、`check_story.gd`、`test_project_server.py` | M | X |
| A13 | ☑ P1 | 錯誤處理：讀檔失敗、儲存空間滿、快速切換故事時的請求競態 | `editor.js:903,929` loadTicket 防競態；`batch1_regression.mjs:120,166` | M | X |

### M2 能寫完一章（編輯器）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| A06 | ☑ P1 | 全文搜尋（節點 ID、台詞、角色）並能跳轉 | `editor_state.js:25` 巢狀全文搜尋；`editor.js:439` 定位步驟 | S | X |
| A07 | P1 | 多選、複製貼上子圖（內部連線重新對應，ID 不衝突） | 目前只能單選 | M | X |
| A09 | ◐ P1 | 從選定場景試玩（旗標／線索、未存稿與作品素材，獨立遊戲資料）；前置舞台及進行中的回合／調查狀態不自動重建 | `preview.gd`、`project_server.py`、`preview_smoke.mjs`、`test_project_server.py` | M | X＋C |
| A10 | ◐ P1 | 素材面板：背景、立繪、表情的縮圖；表情只列該角色有的（2026-10-23：背景縮圖、BGM 試聽、角色表情篩選與預覽已做；獨立的素材面板未做） | `editor.js:577` 表情只列該角色有圖的；`:328` 背景縮圖；角色預覽圖；BGM 試聽 | M | X |
| A11 | ◐ P1 | 表單：condition、旗標、道具、bg、char、bgm、se、result，再來是 investigate 與 boke_round 的範本（2026-10-23：result、investigate、boke_round 仍用 JSON） | `editor.js:651` bg／bgm／se／char／profile／item／flag／condition 表單，`:632` 遞迴條件樹 | L | X |
| A12 | ◐ P1 | 200+ 節點的密集圖效能：先量測再改成局部更新（2026-10-23：已量測並做卡片局部更新；邊線局部更新與重算節流未做） | `tools/story_editor/measure_scene.mjs`；chapter1 開啟 173→226 ms、拖動 20 次 408→437 ms、改欄位 9.3→8.6 ms；`editor.js:414` 未變卡片保留 DOM | M | X |
| A14 | ☑ P1 | 測試補上 200+ 節點、存檔失敗、多分頁等案例 | `test_core.mjs`／`scene_regression.mjs` 的 240 節點；`batch1_regression.mjs` 存檔失敗與多分頁 | M | X |
| A08 | ◐ P2 | 群組、註解框、折疊（存在 layout sidecar，不改 runner schema）（2026-10-23：步驟收合已做；跨場景分組與註解框未做） | `story_core.js:420` 連續同類步驟收合，存在 layout sidecar | M | X |

### M3 劇本系統補齊（遊戲本體）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| G1 | ☑ P1 | 複合條件：AND／OR、數值比較、持有道具；旗標可以加減 | `story_runner.gd` 的 `condition` 只支援「單一 flag == 值」；`flag` 只能直接設值 | M | C |
| G2 | ☑ P1 | 結局 id 與結局收集：`ending` 欄位、progress 記錄、章節選擇顯示「結局 x/y」，以及章節選擇裡的「結局收集」（看過的顯示結局名，沒看過「？？？」，2026-10-19） | `scenes/ui/chapter_select.tscn`、`ending_row.tscn`；`tests/test_chapter_flow.gd` | M | C |
| G3 | ☑ P1 | 跨章旗標（根層 `carry`）：章末把指定旗標寫進 progress，下一章開始時讀入 | `story_runner.gd` 每次載入都把 flags 重設成 `initial_flags`；progress 只記評價 | M | C |
| G4 | P2 | 流程圖畫面（底特律式）：已走過的節點與分支，未解鎖的顯示問號 | 搜尋不到 | L | C |
| G5 | ☑ P2 | 片尾製作名單、CG 鑑賞、音樂鑑賞（2026-10-23：製作名單完成——章節選擇的「製作名單」捲動顯示每個故事的署名與 `data/credits.json` 的工具、字型、音樂；拖曳或點一下停住，「畫面效果：減少」時不自動捲動。CG 與音樂鑑賞未做）（2026-10-23 下午：鑑賞完成——章節選擇的「鑑賞」分畫廊與音樂，劇情裡遇過的背景與 BGM 解鎖，看過的圖可放大、聽過的曲子可試聽，播放時劇情音樂暫停。這個遊戲沒有獨立的 CG，畫廊收背景；之後有 CG 時加進 catalog 即可） | `scripts/gallery_panel.gd`、`scenes/ui/gallery_panel.tscn`；`tests/test_gallery.gd`、`tests/test_credits.gd` | M | C |
| G6 | ◐ P1 | 拆分 `main.gd`（3856 行）：調查、回合、存檔、UI 掛載各自成為控制器（2026-10-23：照「改到哪拆到哪」——先拆出故事清單與進度（`story_library.gd`：清單、標題署名、評價、結局、跨章旗標、解鎖、鑑賞），鑑賞直接用它。`main.gd` 保留測試用到的一行轉接；調查、回合、QA 快照還在 main，等功能碰到再拆） | `scripts/story_library.gd`；`main.gd` 4158 → 4061 行（純拆出），之後加了鑑賞與章節卡欄位為 4149 行 | L | C |
| G7 | P2 | 多語系（`tr()`、把文字抽出來） | 搜尋不到 | L | — |

### M4 Web 發行候選（發行／品質）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| B07 | ☑ P0 | 第一章 Web 完整 E2E：QTE（perfect／early／late）→ 結算 → 評價 → 重新載入後評價與結局仍在（2026-10-19，最終版本 390×844／320×568 連續 3 次通過；其中一次 320 寬第一下偏差 0.433 秒判失敗、重試後命中，是軟體渲染 Chromium 的輸入延遲，路線允許最多 3 次）。Game Over 重試與下一章解鎖由引擎測試 `test_chapter_flow`／`test_chapter1` 涵蓋；目前只有一章，Web 無下一章可解鎖 | `tools/check_reading_chapter1.mjs` | M | C |
| B04 | P0 | 真機測試矩陣（iOS Safari、Android Chrome）：首次點擊、切到背景再回來、來電中斷、網址列伸縮、靜音 | 目前只有 Chromium 模擬 | M | U＋C |
| B08 | P1 | CI 單一品質入口：故事建置一致性、原生關鍵測試、編輯器測試、Web 必要流程 | 沒有 debt-commission 的 workflow | M | X |
| B02 | ◐ P1 | 大小與冷啟動預算：量 PCK、字型裁字、移除未使用素材，評估分章下載 | ICU 斷行資料 +4.8 MB 已量；尚無大小／冷啟動預算與自動檢查 | M | X |
| B03 | P1 | 自訂繁中載入畫面，載入失敗可重試 | 目前用 Godot 預設 shell | M | X |
| B05 | ◐ P1 | 音訊解鎖與回到前景後恢復播放，並取得實際聽到聲音的證據（2026-10-19 查證：Godot 4.7 Web 每次觸控輸入都呼叫 `godot_audio_resume`，切回前景後第一下點擊就恢復，不另加程式；「實際聽到」需真機） | 匯出的 `index.js` `_godot_audio_resume` | S/M | C＋U |
| B06 | P1 | 全螢幕／PWA 與 Web 的 safe area（先在真機確認需要再做） | Web 的 safe area 一律是 0 | M | C |
| B11 | ☑ P1 | 玩家可以匯出、匯入存檔（2026-10-23：設定的「存檔備份」列；Web 下載與瀏覽器選檔，桌機原生對話框；匯入只在標題、整組取代並留 `.before_import`，壞檔整份拒絕） | `scripts/save_transfer.gd`；`tests/test_save_transfer.gd`；`browser_check.mjs --backup`（匯出、壞檔、不含自動檔的備份讓「繼續」消失、完整備份帶回且重新整理後仍在） | M | C |
| B12 | ☑ P1 | 設定寫入失敗時提示；寫入改成原子操作（2026-10-19：`atomic_file.gd`，失敗時提示「設定無法儲存，這次遊玩仍會套用」） | `scripts/settings.gd`；`tests/test_settings.gd` | S | C |
| B13 | P1 | 錯誤診斷包：版本、故事 hash、node/step、近期錯誤（不收集個資） | 搜尋不到 | M | X |
| B15 | ☑ P1 | 減少搖晃與閃光；QTE 時限延長或輔助模式（2026-10-19：設定「畫面效果」減少＝震動 ×0.2、閃光亮度 1/3；「吐槽輔助」寬鬆＝選詞時間 ×1.5、QTE 判定窗 ×2） | `scripts/settings.gd`、`stage_effects.gd`；`tests/test_settings.gd` | M | C |
| B14 | ☑ P1 | 最大字級時不截字、照片上的對比度，逐個場景驗收（2026-10-23：`tools/text_fit_audit.gd` 以最大字級走第一章 31 個畫面（標題、設定、章節選擇、製作名單、調查前每一句、調查與收合列、回顧、目錄、存檔、案件檔、回合、吐槽選單、QTE、Game Over、結算），找被藏行、裁切、修剪、超出畫面的文字並截圖；四款介面 × 390／320 CSS px 全部 0 處。過程修掉：結算卡與 Game Over 標題不換行，長章名把卡片撐出畫面（四個 scene 的 `Heading` 開自動換行）；矮螢幕上結算卡比畫面高（兩款結算卡包進 `Scroll`，放得下仍置中）；調查收合列在 320 寬變三行、蓋住地上的線索（提示縮成「拖曳背景，點可疑的地方」，QA 的熱區可點範圍扣掉收合列）。cinema／ledger／manga 對話框標題列的章名在說話者名字長時用省略號縮短，列為設計如此的備註。照片上的對比沿用 `test_ui_styles` 既有檢查） | `tools/text_fit_audit.gd`；`tools/add_result_scroll.gd` | M | C |
| B16 | ◐ P2 | 色盲：不只靠顏色區分；鍵盤焦點 | `editor.js:302` 出線文字與遺失標記；缺鍵盤操作與焦點驗收 | M/L | X |
| B17 | P2 | 單手真人試玩 | 已有 48 CSS px 的檢查 | S | U |
| B20 | ☑ P1 | `browser_check.mjs --ep00` 失敗：「Gintoki alone is on stage」（2026-10-19 在 HEAD 版同樣失敗，不是這輪造成的；未查原因）（2026-10-23：新八與神樂在調查開始時淡出，測試在淡出完成前就讀舞台；改成等舞台定下來再檢查。同一路線另有短台詞「汪。」在點擊前就打完、點擊變成換句的時序抖動，剩不到 6 字的句子不做點擊補完檢查。修後連續 3 次通過） | `tools/browser_check.mjs` `reveal` 與 ep00 第 4 段 | S | C |
| U1 | ☑ P1 | 銀魂和紙：調查列、回合 HUD、QTE、placard、toast 的樣式統一（2026-10-23：銀魂款的 HUD 面板、線索條、調查收合列改用 `assets/ui/gintama_hud/` 的 StyleBox，toast 改深藍銀框名牌，HUD／toast／地名／QTE 提示改明體；切到其他款時還原。順手修：明體行高撐高統計列讓眼鏡圖示黏成一串（`glasses_icon.tscn` 改垂直置中）；cinema／ledger 對話正文的 Open Sans 沒有中文備援、原生版顯示豆腐字（10-06 起），補 `story-cjk.ttc` 備援） | `scripts/ui_styles.gd` `gintama_hud`／`set_hud_font`；`tests/test_ui_styles.gd` 的 HUD 與字型涵蓋檢查；截圖工具 `tools/shots_chapter1.gd` | S | C |
| U3 | ☑ P1 | 標題卡只留開始／繼續／讀檔／設定：A–D 風格鈕在四款標題 scene 設為隱藏，換風格改在設定的「介面風格」或目錄；版本字改為「v0.5」（2026-10-19） | `scenes/ui/title_screen_*.tscn`；`tests/test_ui_styles.gd` | S | C |
| B18 | ☑ P1 | 中文禁則：Web 版把「。」「，」排到行首（匯出沒帶 ICU 斷行資料）。`project.godot` 開 `internationalization/locale/include_text_server_data`，pck +4.8 MB（2026-10-19） | 結算台詞、選詞題目的 Web 截圖 | S | C |
| B19 | ☑ P1 | 320×568 回合畫面對話框比畫面寬 23 px（右緣被切）：回合操作列四顆 48 CSS px 按鈕加 17 px 間距放不進窄手機；銀魂款 `RoundBar` 間距改 10。順手修正 `browser_check.mjs` 預設路線沒帶 `?sample=debt`（第一章改為預設後一直失敗）；兩者在 HEAD 版也失敗，修後 `--rounds` 與預設路線通過。`browser_check.mjs` 的點擊會先捲動目錄／設定把列帶進畫面（目錄加了回滾與快速存讀後「回標題」落到捲動區下方，`--slots`、`--choices` 在 HEAD 版因此失敗，修後通過）。`--ep00` 的「Gintoki alone is on stage」在 HEAD 版同樣失敗，未處理（2026-10-19） | `scenes/ui/dialogue_box_gintama.tscn`、`tools/browser_check.mjs` | S | C |
| U2 | ☑ P2 | 其他三款的對話框名牌會浮在結算畫面上面（2026-10-19：預防性修正，`chapter_result.tscn`、`game_over.tscn` 根節點比照銀魂款設 `z_index = 2`；這輪沒重現原問題，也沒拍 cinema 結算截圖驗證）（2026-10-23 截圖確認：cinema、ledger、manga 三款的結算畫面上，對話框名牌都在暗幕底下） | `tools/shots_chapter1.gd` 系列截圖 | S | C |
| U4 | ☑ P1 | 參考 `docs/gintama-like/new/` 的銀魂手遊介面（使用者 2026-10-23 指定 status、scene、episode；決定：版面照參考、配色維持和紙）：章節選擇改成章節路線圖、案件檔下半部改成 status 卡。scene（對話）沿用作者已核准的銀魂和紙對話框，沒有改。順手修：十幾個 Label 用任意斷行，「。」會被排到行首，全部改成依字詞斷行；線索 toast 會蓋住案件檔 | `scenes/ui/episode_card.tscn`、`tools/add_episode_cards.gd`、`tools/restyle_case_file.gd`；`tests/test_credits.gd`、`tests/test_phase4_ui.gd` | M | C |
| U5 | ☑ P1 | 只留銀魂和紙（使用者 2026-10-23）：刪掉月下映畫、委託簿、吐槽分鏡三款的 20 個 scene、標題／目錄／設定的換風格按鈕、偏好檔 `ui_preferences.cfg`、`tools/check_ui_parity.mjs` 與沒在用的 `ui_reference.gd`；銀魂款借用別款的列 scene 改指向自己的。順手修：調查時沒有熱區的角色隱形、有熱區的半透明，回合的線索列縮成「線索 ×N」小牌；標題與對話的雲形名牌不再被拉伸（對話名牌九宮格、依名字變寬） | `tools/remove_style_switches.gd`、`tools/fix_gintama_plaques.gd`；`tests/test_ui_styles.gd`、`tests/test_search_cast.gd` | M | C |
| K6 | ☑ P1 | 外觀包（使用者 2026-10-23：「換掉一些元素就能變成別部動畫的視覺小說」；決定：玩法可以關、外觀跟著故事走）：`skins/<id>/skin.json`（場景、`washi`／`flat` 外觀、配色、HUD 資源、生命圖示、標題背景與音樂、用語 `terms`、scene 靜態字 `texts`）；故事在 `stories.json` 寫 `skin`。寫死的新八、萬事屋客廳、各角色打字音高搬進 catalog（`default_pov`、`default_background`、`voice_pitch`）。沒有回合與調查的故事不顯示 HUD、案件檔與「輔助」設定 | `scripts/skin.gd`、`skins/gintama/skin.json`、`tests/fixtures/skins/plain/`；`tests/test_skin.gd` | L | C |

### M5 內容
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| C1 | ◐ P1 | 第一章分支（使用者 2026-10-19 要求先加一個分支結局）：已做：薪水袋之後的選擇「自己去鞋櫃拿／叫阿銀拿過來」，兩個結局 `ch1_sadaharu`「這次真的是定春」、`ch1_gintoki`「試毒試到一滴不剩」，結算畫面標出結局名；`BR` 開頭的台詞是 Claude 寫的，待作者試讀。未做：更早、影響更大的分支 | `story_src/chapter1.dialogue` 的 `ch1_twist_gin`；`tests/test_chapter1.gd` 的 gin 路線 | M | U＋C |
| C2 | P1 | 第一章作者試讀與修訂（目前是草稿 v0.2）；補齊缺少的表情圖 | — | M | U |
| C3 | P1 | 正式音效與配樂（依 R1 的結果決定用授權素材或原創） | 目前是合成的 WAV 加上原聲帶 | M | U |
| C4 | P1 | 第二章起的故事大綱與量產流程 | `stories.json` 裡只有一個 chapter | L | U＋C |

### M6 創作者可用（依決定 3；提案，尚未排程）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| K1 | ☑ P1 | 創作者美術規格：背景與立繪的尺寸、透明 PNG、表情命名、取景，附蠟筆風現有圖當範例 | `docs/ART-SPEC.md`（2026-10-23），`docs/AUTHORING.md` 開頭連過去 | S | C |
| K2 | ☑ P1 | 故事包：一個故事一個資料夾（劇本、自己的素材 catalog、作者資訊），放進去就出現在章節選擇，不改程式（2026-10-23：`stories/<作品>/pack.json`＋`catalog.json`＋劇本與 `art/`，放進去就出現在章節選擇；catalog 可寫相對路徑與 `extends`；換作品時重建立繪、音效與音樂；解鎖、下一章、跨章旗標、「第 N 章」、結局收集、鑑賞都按作品分開；撞 id 的故事不載入；沒有回合的本篇走到結尾就算破關。附範例作品 `stories/example/`（末班車，出現在章節選擇）與扁平外觀 `skins/example/`；匯出設定帶上 `stories/`、`skins/` 的 JSON。編輯器：作品分組、作品自己的 catalog、存回作品資料夾與 `pack.json`、「新作品」範本） | `scripts/story_library.gd`、`StoryRunner.catalog_path_for`／`read_catalog`；`tests/test_story_packs.gd`、`browser_check.mjs --packs`、`tools/story_editor/pack_smoke.mjs` | M/L | C＋X |
| K3 | ☑ P1 | 署名：章節選擇與結算顯示作者／畫師，片尾名單（併入 G5）（2026-10-23：故事根層選填 `credits: [{role, names}]`，`.dialogue` 故事寫在 `blocks.json` 的 `story`；章節列第三行與結算卡顯示前三個職務。第一章的作者／畫師名字待使用者提供） | `scripts/story_runner.gd` `validate_credits`；`tests/test_credits.gd` | S/M | C |
| K4 | ☑ P1 | 投稿檢查：一鍵檢查缺圖、缺表情、尺寸不符與劇本錯誤，產生創作者看得懂的報告（2026-10-23：`tools/art_check/`，Godot 選單「作品：投稿檢查」與 `run.gd`；錯誤／美術待辦／建議／缺授權／沒用到，報告在 `build/art_check/`） | `tools/art_check/art_check.gd`、`tests/test_art_check.gd` | M | X |
| K5 | ☑ P1 | 創作者素材的授權聲明欄位（與 B01 manifest 共用格式）（2026-10-23：catalog 每筆可有 `license`（author、source、license、approved、role），製作名單自動列出故事用到的素材作者；格式見 IMPLEMENTATION.md「素材授權」，B01 沿用） | `scripts/asset_usage.gd`、`story_library.credit_sections` | S | X＋U |

## 協作方式

- Claude 獨占遊戲本體：`scripts/`、`main.gd`、`scenes/`、`tests/`、`story_src/`、`data/`。Codex 獨占：`tools/story_editor/**`、`docs/STORY-EDITOR.md`、CI 與建置腳本、素材 manifest。
- A01 歸 Codex，可以動 `data/stories.json`（新增 authoring 欄位）與 `tools/story_build/story_builder.gd`、`build_story.gd`；`tools/story_build/dm_source.gd` 歸 Claude（G1 的 `.dialogue` 條件語法）。
- 會跨兩邊的 schema 變更（例如 G1 的條件語法、G2 的結局欄位），由 Claude 先在 `IMPLEMENTATION.md` 定好契約，Codex 再接進編輯器表單。
- 每一項完成時：實作方回報改動檔、測試與實跑結果；對方讀實際 diff 後回 ACK，或附 file:line 的意見。commit 等使用者指示。
