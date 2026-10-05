# V1 驗證紀錄

更新：2026-09-25。引擎 `4.7.stable.official.5b4e0cb0f`，官方單執行緒 Web 範本、Compatibility renderer。

## Phase 1：直立外殼

驗證對象是直立外殼，試玩文本為第一場《請幫我向你老闆討債》。

| 檢查 | 結果與證據 |
| --- | --- |
| Phase 0 基準 | 啟用 MCP Toolkit、匯出排除 addon 後，舊版的 `test_story`、`test_stage`、Web 匯出與觸控 smoke 全部通過；pck 內沒有 addon 腳本，runtime autoload 已清除 |
| 劇情執行器 | `tests/test_story.gd` 通過：兩路結尾、旗標、分支回扣、無效選項、版本／節點還原、重置、錯誤引用 |
| 手勢（headless） | `tests/test_vn_shell.gd` 通過：第一下補完、第二下前進；長按隱藏 UI、恢復的那一下不推進；上滑開紀錄；(≡) 拖曳後吸左邊且停在對話框上方；點與長按 (S) 都開啟手動存檔欄位；閒置淡到 40%；點選單背景關閉；SKIP 停在選項 |
| 桌機 A 路線 | Chromium 1280×900 滑鼠：53 個閱讀點，選「先聽說明」走到 `debt_recall_hearing` 結尾；14 組檢查 |
| 觸控 B 路線 | Chromium 觸控模擬 390×844：52 個閱讀點，選「先查明細」走到 `debt_recall_ledger` 結尾；15 組檢查 |
| 版面 | 對話框佔畫面 28%（±2%）；快捷列、懸浮按鈕、選項在 390×844、360×800、320×568 都位於畫面內，按鈕與選項在對話框上方 |
| 手勢（瀏覽器） | 兩條路線與觸控 smoke 都驗過：點背景推進、長按隱藏／恢復、上滑紀錄、點與長按 (S) 開啟欄位、拖曳 (≡) 吸邊、閒置透明、選單開關、AUTO 自動前進、SKIP 停在選項。長按、拖曳、上滑在觸控模式用 CDP 觸控事件 |
| 選項與紀錄 | 選項等待玩家；懸浮按鈕（包含拖到左側的 (≡)）停在選項上方，不會蓋住選項。在選項畫面開啟約 30 筆的對話紀錄：手機以觸控拖曳、桌機以滾輪都能捲動 |
| 續讀 | 兩路都在 `debt_ask_salary` 重新整理後按「繼續」：同一句、同樣旗標、立繪可見性與表情一致 |
| 一般試玩網址 | 不帶 `?qa=1` 時沒有 `window.__debtQA` |
| 錯誤紀錄 | 兩條路線與 smoke 均無瀏覽器或 Godot 執行期錯誤 |
| Windows 編輯器實跑 | 透過 Godot MCP `game_start` 在使用者的編輯器執行 main scene，`runtime_screenshot` 顯示標題畫面正常；console 無腳本錯誤（有編輯器重新掃描檔案時的 progress dialog 錯誤，與遊戲無關） |

原始報告：[完整路線](browser-report.json)、[觸控 smoke](smoke-report.json)。[手機畫面預覽](preview-phone.png) 為 390×844 的實際 Web 截圖。重跑方式見 [README](../README.md#驗證)。

Safe Area：程式只在 Android／iOS 原生匯出讀取瀏海與手勢列的邊距。Web 版沒有設定 `viewport-fit=cover`，瀏覽器分頁本身會避開安全區，因此沒有額外處理；日後若做全螢幕或 PWA 版，需要改用 CSS `env(safe-area-inset-*)`。

尚待真人驗證：Android／iOS 實機的手感、按鈕大小、透明度與字級。桌機的觸控模擬不代表實機已通過。

## Phase 2：劇本與素材資料

驗證對象是 `data/phase2_story.json` 的草莓牛奶技術片段與原討債劇本的相容性。此片段非作者核准的第一章文本。

| 檢查 | 結果與證據 |
| --- | --- |
| 引擎資料測試 | `test_story.gd` 與 `test_phase2_story.gd` 通過：舊劇本雙路、catalog 引用、素材條件顯隱、非法選項拒絕、缺角色／背景／素材／節點／指令的啟動前錯誤、素材防重複與 snapshot 還原 |
| 引擎 UI 測試 | `test_vn_shell.gd` 與 `test_phase2_ui.gd` 通過：JSON 背景、立繪、表情、站位與條件分支進入 UI；讀檔保留閱讀點、背景、角色與素材；原手勢回歸通過 |
| Web 匯出 | `bash tools/build_web.sh` 成功；匯出日誌確認 `data/phase2_story.json` 與 `data/asset_catalog.json` 均進入 `.pck` |
| 草莓牛奶 Web 路線 | Chromium 390×844 觸控模擬走素材路線，1280×900 滑鼠走無條件路線；兩路均完成，重整後「繼續」保留背景、立繪、站位和素材，瀏覽器／Godot 執行期錯誤為空。見 [Phase 2 報告](phase2-browser-report.json) 與 [手機畫面](preview-phase2-phone.png) |
| 討債 Web 回歸 | Chromium 桌機 A 路線 53 個閱讀點、手機觸控 B 路線 52 個閱讀點，分別通過 14／15 組檢查，錯誤為空；見 [回歸報告](phase2-regression-report.json) |

Phase 2 的自動驗收完成。Android Chrome／iOS Safari 真人試玩、首次載入時間與笑點／8 秒吐槽手感，仍分別在手機試玩與 Phase 3 驗證。headless Godot 會記錄 MCP addon 在受限環境無法綁本機埠的警告；Web 匯出不含該 addon，測試進程以 exit 0 完成。

## 手動存讀檔欄位

存檔改為自動續讀檔與 18 個手動欄位分開；(S) 開啟欄位選擇，不會快速存檔。標題與遊戲內可選欄讀檔，覆寫有確認，空欄及損壞欄不能讀取。

| 檢查 | 結果與證據 |
| --- | --- |
| 引擎測試 | `test_save_slots.gd` 通過：多欄位不同進度、新遊戲保留手動欄位、標題讀檔、載入後 Continue、跨故事隔離、舊 schema 3 檔案、覆寫前的備份與損壞主檔還原；`test_vn_shell.gd` 回歸通過 |
| Web 實際操作 | Chromium 390×844 觸控模擬：存入兩個不同進度，遊戲內與標題均選欄讀檔；換頁到第 3 頁，重新整理後仍可看到欄位資料與正確還原。4 組檢查通過、無執行期錯誤；見[瀏覽器報告](save-slots-browser-report.json)與[手機畫面](preview-save-slots-phone.png) |
| 既有路線回歸 | 討債劇本桌機 A、手機 B 路線分別通過 14／15 組；Phase 2 草莓牛奶素材／非素材路線各通過 3 組。原測試中打字動畫與自動完成的計時競爭已改由等待完成處理；見[主線報告](save-slots-regression-report.json)與[Phase 2 報告](save-slots-phase2-regression-report.json) |
| 寫入策略 | 每個欄位先寫暫存檔，覆寫時將前一份有效檔留作備份；讀檔依序驗證主檔與備援檔 |

瀏覽器測試使用本機伺服器的同源儲存空間；跨網域或清除網站資料後，Web 本機檔案不會跟著轉移。Android／iOS 實機持久性仍待真人測試。

## Phase 3：調查與吐槽技術短循環

驗證對象是 `data/phase3_story.json`，為非正式第一章台詞的技術片段。調查一個熱區取得草莓牛奶瓶，再切換銀時發言、聽補充台詞、進入限時吐槽選詞。

| 檢查 | 結果與證據 |
| --- | --- |
| 劇本資料 | `test_phase3_story.gd` 通過：調查前不能前進、素材不重複取得、發言與聽下去還原、素材限定選項、perfect／weak／fail／hidden、逾時與 Game Over 檢查點；缺引用或無效結果在載入前拒絕 |
| 畫面與存讀檔 | `test_phase3_ui.gd` 通過：調查熱區與繼續門檻、HUD、兩種回合畫面的自動／手動存讀；發言閱讀 8.1 秒不扣眼鏡，按「吐槽！」才開始 8 秒；選單、紀錄、欄位畫面暫停倒數；零秒讀檔逾時一次、五次失敗後 Game Over 重試；舊限時存檔可還原 |
| 既有回歸 | `test_story.gd`、`test_vn_shell.gd`、Phase 2 story／UI、`test_save_slots.gd` 與 Phase 3 兩套測試，共七套 headless 測試均以 exit 0 結束 |
| Web 觸控 | Chromium 390×844 真實 canvas 觸控：調查取素材、選欄存檔、銀時立繪與發言切換、聽下去、閱讀超過 8 秒、吐槽選詞、選單暫停、重新整理後從指定欄位恢復剩餘秒數，最後選 perfect 並只增加一次力量；6 組檢查通過，錯誤為空。320×568 的四個選項都在畫面內、對話框上方；見[報告](phase3-browser-report.json)、[發言畫面](preview-phase3-boke-phone.png)與[窄畫面選詞](preview-phase3-tsukkomi-narrow.png) |

技術短循環已可從 Web 開啟。Phase 3 的整體關卡仍需作者確認一回合正式台詞，並在 Android Chrome／iOS Safari 真人試玩 8 秒反應時間、選項可讀性與笑點節奏；桌機觸控模擬不能代替實機結論。

## 底部對話層 UI Web 試版

2026-09-25 的[原版／前一版／素材試版畫面比較](UI-TRIAL.md)保留全寬對話層的歷次截圖。前一版有上緣細線；目前素材試版移除對話框邊線，將底色不透明度降至 0.62，並使用店面、客廳及銀時剪影素材。上方 Phase 1 的 28% 對話框紀錄是原版驗證。

| 檢查 | 結果與證據 |
| --- | --- |
| Godot UI | `test_vn_shell.gd` 與 `test_phase3_ui.gd` 通過；Web 匯出成功 |
| 討債主線 | Chromium 桌機 A 路線 53 個閱讀點、14 組檢查；390×844 觸控 B 路線 52 個閱讀點、15 組檢查。320×568 雙選項、底部全寬、層內快捷列與懸浮鈕避讓均通過；見[報告](ui-trial-main-report.json) |
| Phase 3 | 390×844 調查、發言、聆聽、吐槽選詞、限時暫停與存讀檔共 6 組檢查通過；320×568 的四個選項保持在對話層上方，調查繼續按鈕留在畫面內；見[報告](ui-trial-phase3-report.json) |
| 手動存讀檔 | 390×844 觸控欄位操作 4 組檢查通過；見[報告](ui-trial-slots-report.json) |

以上是 Web 試版技術驗證。對話層高度與透明度的實機閱讀手感仍待 Android Chrome 與 iOS Safari 對照後決定。

### 素材試版回歸

三張 PNG 已納入 Web 匯出；catalog 的路徑檢查同時接受原始檔與 Godot 匯入資源，避免匯出後誤判圖片不存在。最新 Web 截圖見[標題](preview-assets-title-phone.png)、[對話](preview-assets-dialogue-phone.png)、[Phase 3 發言](preview-assets-phase3-boke-phone.png)與[320×568 吐槽選詞](preview-assets-phase3-tsukkomi-narrow.png)。

| 檢查 | 結果與證據 |
| --- | --- |
| Godot 資料與 UI | `test_phase2_story.gd`、`test_phase3_ui.gd` 通過；Web 匯出成功 |
| 討債主線 | 桌機 A 路線 53 個閱讀點、14 組檢查；390×844 觸控 B 路線 52 個閱讀點、15 組檢查，錯誤為空；見[報告](ui-assets-main-report.json) |
| Phase 3 | 390×844 觸控 6 組檢查通過，320×568 四選項保持可見，錯誤為空；見[報告](ui-assets-phase3-report.json) |
| 手動存讀檔 | 390×844 觸控 4 組檢查通過，錯誤為空；見[報告](ui-assets-slots-report.json) |

## VN Framework Prototype v0.1 驗收（EP00 vertical slice）

2026-10-02。驗證對象是 `data/ep00_story.json`（`story_src/ep00.dialogue`＋`ep00.blocks.json` 建置，網址 `?sample=ep00`），把 v2 計畫（`docs/story-telling-game/v2/conversation4.md` 第 902–938 行）的 16 條驗收清單串成一集：`Story JSON → StoryRunner → A 畫面 → POV Choice → 真分支 → Comedy B → Interaction → State → Director Choice → Ending → Save/Load`。台詞取自 v2 EP00 草稿，非核准。

三份證據：

- **headless**：`tests/test_ep00.gd`（成功印 `EP00 TESTS PASSED`）。資料與 36 條路徑用 StoryRunner 窮舉，外殼層的操作多數走 `_tap`／`_press`；只有「快速走到某個畫面」的輔助函式 `_to_search`、`_to_director` 與兩處調查離開（`_on_investigation_continue_pressed`）直接呼叫處理函式（`_on_choice_pressed`、`_collect_hotspot`），真實的 canvas 點擊由 Web 的 `--ep00` 路線負責。全程用 Logger 攔截引擎錯誤。引用位置寫成「函式（行號）」，行號是這次驗收時的檔案。
- **Web**：`node tools/browser_check.mjs --ep00`，真實 canvas 觸控，390×844 走路徑 A、路徑 B，320×568 走路徑 A 到調查為止。報告 [ep00-browser-report.json](ep00-browser-report.json)，截圖 `preview-ep00-*.png`（[A 畫面](preview-ep00-a-screen-phone.png)、[POV 選項](preview-ep00-pov-phone.png)、[漫畫吐槽層](preview-ep00-comedy-phone.png)、[互動調查](preview-ep00-interaction-phone.png)、[導演選項](preview-ep00-director-phone.png)、[結局](preview-ep00-ending-phone.png)；窄螢幕的[POV](preview-ep00-pov-narrow.png)、[漫畫吐槽層](preview-ep00-comedy-narrow.png)、[互動調查](preview-ep00-interaction-narrow.png)）。
- **既有測試**：`tests/test_choices.gd`、`test_comedy.gd`、`test_interaction.gd` 等先前驗過各項功能本身，這裡只在 EP00 的劇本上重做串接的部分。

| # | v2 驗收項目 | 結果 | 證據 |
| --- | --- | --- | --- |
| 1 | 手機 9:16 正常顯示 | 已驗證（模擬視窗）；實機未驗證 | 設計尺寸是 1080×1920（9:16，`stretch aspect=expand`，較長的手機往下延伸）；headless 測試沒有另外斷言尺寸（`_game.size` 只用來算點擊座標）。Web 在 390×844 與 320×568 兩個模擬視窗跑 `--ep00`：第一句、調查（對話框展開與收起）過 `assertLayout`（遊戲區、對話框、工具列、名牌與所有可點元件在視窗內），POV 選項與導演卡片逐列檢查在遊戲區內，漫畫吐槽層的爆炸框與大字在遊戲區內，截圖見上 |
| 2 | Story JSON 可以載入 | 已驗證 | `_test_script_data`（94）：載入、與 `ep00.dialogue` 的新建置逐字相同、沒有到不了的節點、每個跳轉與 catalog 引用都存在、每個用到的表情都有圖、句數在 45–65（口徑見下，只算台詞是 38）；`--ep00` 每條路線都從 `?sample=ep00` 的標題開始 |
| 3 | Dialogue 可以逐字顯示 | 已驗證 | `_test_scene_one_in_the_shell`（416）：第一句從不完整開始、至少出現 3 種長度、最後完整；`--ep00` 的 scene one |
| 4 | 點擊完成文字／下一句 | 已驗證 | 同上（422–427）：打字中點一下補完且不前進，再點才前進；`--ep00` 路徑 A 有 3 次「點一下補完一句、劇情沒動」 |
| 5 | 三角色可左右中顯示 | 已驗證 | 同上（437–443）：新八 left、銀時 center、神樂 right，且立繪中心由左到右；`--ep00` 同樣斷言，截圖 `preview-ep00-a-screen-phone.png` |
| 6 | 可換表情 | 已驗證 | 同上（428、444–447）：新八 angry、神樂 smile、銀時 nosepick → smug；`_test_script_data`（94–181）確認每個（角色，表情）在 catalog 有圖；`--ep00` 路徑 A |
| 7 | Choice 可以跳不同 Story Branch | 已驗證 | `_test_every_path`（257）：3 個 POV × 找到委託書與否 × 碰草莓牛奶與否 × 3 個結局共 36 條路徑，每條斷言結局文字、四個旗標、道具、該路徑自己的反應句（且沒有別條的）；`_test_pov_choice_panel`（451）按真實按鈕走到 `s03_calm`；`--ep00` 路徑 A（loud）與 B（tired） |
| 8 | POV Choice 顯示正常 | 已驗證 | `_test_pov_choice_panel`（451–473）：掛的是該風格自己的面板、不是導演面板，提問是新八的想法（名牌「新八・心聲」）、三列文字、語氣標記、QA `choice` 欄位；`--ep00` 每列至少 48 CSS px 且在遊戲區內，截圖 `preview-ep00-pov-phone.png`、`preview-ep00-pov-narrow.png` |
| 9 | Director Choice 有不同 UI | 已驗證 | `_is_director_choice`（918）：導演面板的 scene、抬頭「── 導演選擇 ──」、提問、註腳、三張卡、QA 欄位，在 `_test_search_by_taps_without_the_job`（628）、`_test_endings_in_the_shell`（660）檢查；`--ep00` 與截圖 `preview-ep00-director-phone.png`；兩種面板互不相同、三款風格共用導演面板由 `test_choices.gd` 驗證 |
| 10 | Comedy B Overlay 可以從 A 畫面瞬間觸發 | 已驗證（觸發時間的毫秒數未量） | `_test_overlay_waits_and_taps_do_not_skip`（478）：讀完「嗯？」後在同一個畫面上疊起 `tsukkomi_impact`（沒有換 scene，下面還是那句），劇情停在 comedy 步驟、播完下一句出現；`--ep00` 的 `comedy.active` 與 `screen: busy`；`_test_other_reactions`（542）：`small_reaction` 不遮對話框 |
| 11 | Comic Cut-in／Shake／Big Text 正常 | 已驗證（cut-in 位置靠既有測試） | `_test_overlay_waits_and_taps_do_not_skip`（492–511）：舞台震動、zoom 不超過 1.05、大字放得進爆炸框（`text_fits`）、約 1.35 秒；`--ep00` 爆炸框與大字都在遊戲區內；cut-in 面板在遊戲區內由 `test_comedy.gd` 驗證，EP00 沒有另外斷言，只在截圖 `preview-ep00-comedy-phone.png`／`-narrow.png` 看得到 |
| 12 | 可以進入 Interaction Mode | 已驗證 | `_test_search_by_taps_without_the_job`（566–576）：留在場上的只有銀時、四個熱區、銀時的熱區是他的立繪、「繼續」一開始就能按；`--ep00` |
| 13 | Hotspot 可以觸發對話與 State | 已驗證 | 同上（594、606、612）：銀時四次點擊依序「幹嘛。」「你一直點我也不會掉道具。」「這不是手遊角色首頁。」、第四次重複第三句；草莓牛奶寫 `examined_strawberry_milk`；電視不寫旗標；`_test_search_with_the_job`（634）：委託書出現 toast、拿到 `job_document`、寫 `found_job`；`--ep00` 路徑 A 用真實拖曳與觸控點 |
| 14 | Condition 可以讀 State | 已驗證 | `_test_every_path`（257–313）：`found_job` 與 `examined_strawberry_milk` 兩個條件在 36 條路徑都走對；`_test_search_*`（566、634）在外殼看到「我自己找」或「這不是有工作嗎」、神樂補一句；`_test_bool_flags_in_the_adapters`（374）：`if found_job == true` 能建置；`--ep00` 路徑 A（找到＋碰牛奶）與 B（沒找到） |
| 15 | 三個不同 Ending | 已驗證（Web 走過結局 A 與 C，結局 B 只在 headless） | `_test_endings_in_the_shell`（660）按三張卡走到「EP00 完 ── 欠債篇／委託篇／？？？篇」，各設 `ep00_ending` debt／request／unknown；`_test_every_path` 另在 StoryRunner 走 36 次；`--ep00` 路徑 A 走結局 C、路徑 B 走結局 A，截圖 `preview-ep00-ending-phone.png` |
| 16 | 可以 Save／Load 回目前 Event | 已驗證 | `_test_save_in_the_search`（683）：調查中點銀時兩次後存，重建外殼讀檔，第三次點出第三句、第四次重複；手動欄位 payload 同；`_test_save_at_the_director_choice`（728）：自動檔與手動欄位都還原同一個導演選項；`_test_old_save_does_not_replay_the_overlay`（757）：停在 comedy 步驟的存檔讀回來不重播；`--ep00` 路徑 B：在調查與導演選項各存手動欄位，重新整理頁面，讀檔回到同一個事件（畫面、節點、旗標、場上角色、已查熱區、選項） |

這一輪的結果（2026-10-02，Godot `4.7.stable.official.5b4e0cb0f`，官方單執行緒 Web 範本）：

- headless：`--import` 後 `tests/test_*.gd` 全部 23 組印出 PASSED、exit 0（開工前基準 22 組，加上 `test_ep00`，它有 894 個斷言）。
- Web：`--ep00` 三組（路徑 A 390×844、路徑 B、路徑 A 320×568 前半）全過，沒有瀏覽器或 Godot 執行期錯誤。

劇本實況與偏離規格（為了讓這集跑得起來）：

- **句數口徑**：`_test_script_data` 的「45–65 句」把台詞（`say` 38）、漫畫吐槽層（2）、結局文字（3）、選項提問與選項（2 個選項步驟 × 4 ＝ 8）全算進去，合計 51；只算台詞是 38（含漫畫吐槽層是 40），比派工規格的「約 45–65」少一些。要不要補台詞，等量過實際遊玩時間再決定。
- **搜尋前新八、神樂退場**：三人同台時立繪蓋住整張背景，物件熱區看不見，所以 `s04_intro` 先讓新八與神樂退場，只留銀時；之後他們在調查中的台詞用 `[#offscreen]`（畫面外出聲），否則一開口就會重新上場、又蓋住背景。調查結束後（`s05_*`）他們開口時回到自己的站位。`keep_cast: true` 仍開著，場上的銀時是角色熱區。
- **「草莓牛奶」熱區放在桌上的紅色筆筒**：背景 `yorosuya-inside.png` 沒有畫牛奶，label 照劇情寫「草莓牛奶」。要有真正的牛奶需要補素材或換圖。電視與委託書（檯燈左邊的紙堆）對得上畫面。
- **加了兩句派工規格沒寫的台詞**：`s04_intro` 的銀時「委託書的話，應該還埋在桌上吧。」與調查提示「四處點點看吧。（左右拖曳背景可以看到更多）」。
- **已知缺口（不擋這集，沒修）**：角色熱區是整張立繪含透明邊（銀時的矩形比螢幕還寬），所以調查時點任何不是未找到物件的地方都算點銀時，熱區的淡框也只剩螢幕邊緣的線與 ✓，辨認度弱；有調查的故事整集顯示眼鏡／吐槽之力 HUD（`has_gameplay()` 只看有沒有 `investigate`／`boke_round`）；全部熱區選填時「繼續」寫「線索已取得・繼續」、進度列寫「線索 0/0」；POV 第一列「問題是你有工作的時候也在休息啊！！」在手機上換行後最後一個「！」單獨一行；結局 B 沒有電話鈴聲，用旁白「嘟嚕嚕嚕——電話響了。」代替。

尚未驗證：

- Android Chrome／iOS Safari 實機的 9:16 顯示與手感（第 1 項只在模擬視窗驗過）。
- 音效是合成佔位音（`crow`、`door_slide`），沒有試聽。
- 整集遊玩時間沒有量；v2 計畫的 5–8 分鐘目標未對照。
- 瀏覽器路線沒有點電視熱區，也沒有走結局 B（委託篇）；兩者只在 headless 驗證。

重跑：

```bash
cd prototypes/debt-commission
godot --headless --path . --import
XDG_DATA_HOME="$PWD/.cache/test-data" godot --headless --path . --script res://tests/test_ep00.gd
GODOT_BIN=/path/to/godot bash tools/build_web.sh && bash tools/serve_web.sh
node tools/browser_check.mjs --ep00 --playwright /path/to/node_modules/@playwright/test
```
