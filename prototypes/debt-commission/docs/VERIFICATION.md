# Phase 1 驗證紀錄

更新：2026-09-23。引擎 `4.7.stable.official.5b4e0cb0f`，官方單執行緒 Web 範本、Compatibility renderer。驗證對象是 V1 Phase 1 直立外殼，試玩文本為第一場《請幫我向你老闆討債》。

| 檢查 | 結果與證據 |
| --- | --- |
| Phase 0 基準 | 啟用 MCP Toolkit、匯出排除 addon 後，舊版的 `test_story`、`test_stage`、Web 匯出與觸控 smoke 全部通過；pck 內沒有 addon 腳本，runtime autoload 已清除 |
| 劇情執行器 | `tests/test_story.gd` 通過：兩路結尾、旗標、分支回扣、無效選項、版本／節點還原、重置、錯誤引用 |
| 手勢（headless） | `tests/test_vn_shell.gd` 通過：第一下補完、第二下前進；長按隱藏 UI、恢復的那一下不推進；上滑開紀錄；(≡) 拖曳後吸左邊且停在對話框上方；長按 (S) 存檔並提示、點 (S) 只提示；閒置淡到 40%；點選單背景關閉；SKIP 停在選項 |
| 桌機 A 路線 | Chromium 1280×900 滑鼠：53 個閱讀點，選「先聽說明」走到 `debt_recall_hearing` 結尾；12 組檢查 |
| 觸控 B 路線 | Chromium 觸控模擬 390×844：52 個閱讀點，選「先查明細」走到 `debt_recall_ledger` 結尾；13 組檢查 |
| 版面 | 對話框佔畫面 28%（±2%）；快捷列、懸浮按鈕、選項在 390×844、360×800、320×568 都位於畫面內，按鈕與選項在對話框上方 |
| 手勢（瀏覽器） | 兩條路線與觸控 smoke 都驗過：點背景推進、長按隱藏／恢復、上滑紀錄、點與長按 (S)、拖曳 (≡) 吸邊、閒置透明、選單開關、AUTO 自動前進、SKIP 停在選項。長按、拖曳、上滑在觸控模式用 CDP 觸控事件 |
| 續讀 | 兩路都在 `debt_ask_salary` 重新整理後按「繼續」：同一句、同樣旗標、立繪可見性與表情一致 |
| 一般試玩網址 | 不帶 `?qa=1` 時沒有 `window.__debtQA` |
| 錯誤紀錄 | 兩條路線與 smoke 均無瀏覽器或 Godot 執行期錯誤 |
| Windows 編輯器實跑 | 透過 Godot MCP `game_start` 在使用者的編輯器執行 main scene，`runtime_screenshot` 顯示標題畫面正常；console 無腳本錯誤（有編輯器重新掃描檔案時的 progress dialog 錯誤，與遊戲無關） |

原始報告：[完整路線](browser-report.json)、[觸控 smoke](smoke-report.json)。[手機畫面預覽](preview-phone.png) 為 390×844 的實際 Web 截圖。重跑方式見 [README](../README.md#驗證)。

尚待真人驗證：Android／iOS 實機的手感、按鈕大小、透明度與字級。桌機的觸控模擬不代表實機已通過。
