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
