# debt-commission 系統與編輯器交接

更新：2026-10-28（Asia/Taipei）。作者要出門，要求交接並 commit；提交完成後停在這裡，等作者續作指示。沒有 push 授權。第一篇極短篇構想尚未提供，不代寫正式故事。

## 現行基準與提交

分支 master。先前遊戲實作基準 21604e3；本次提交前工作樹 HEAD 是其他原型的 6e9fb85。本次將 debt-commission 的漫畫演出、立繪動畫、人格協作與編輯器整合、測試及文件一併提交。提交完成後用 `git log -1 --oneline` 取得實際提交，不為了寫入本文件自己的 hash 重複提交。

## 已完成

| 區域 | 可用功能 |
|---|---|
| 閱讀 | 16:9 橫向、固定閱讀框、長台詞分頁、較小字級、舞台與閱讀框分離、精簡貼底收合列、集齊線索可繼續 |
| 演出 | 左右漫畫吐槽、黑白放射線與黑紅氣泡、快轉及去重、光束與台詞分層 |
| 立繪 | 進退場淡化、左右滑動、直接切換；抖動、彈跳；略讀／減少動作及退場存檔處理 |
| 故事編輯器 | 新故事、分支、存檔版本驗證、衝突保護、未存稿場景試玩；站位、角色進退場、動作與漫畫格左右表單 |
| 人格與記憶 | 銀時／新八／神樂 revision 2、三條基礎記憶 revision 1，均有真實人類確認及完整內容 hash；舊版保留存檔 |
| 編劇參考面板 | 正式庫唯讀查看，手選角色／記憶，產生及下載與 CLI 相同的 agent 上下文；按 known_to 分配；未確認、修改失效及過期面板阻擋 |

人物情境反應、語氣正反例、界線及關係差異，作者已回覆「可以 採用」。新增記憶或修改人格仍需另行確認。不可使用測試 fixture 證據作為真實人類採納。persona_meta／proposal_meta 類追蹤資料不是確認依據；以 confirmations.json 綁定完整內容的紀錄為準。

`data/strawberry_chapter1_graph_story.json` 是既有第一章的圖編輯副本，與 chapter1_story.json 僅 id 與 generated_from 不同；不是本次新寫故事或新採納的文本。

## 操作與接手順序

```text
讀 Progress.md → 本交接 → README／STORY-EDITOR
                                 ↓
                    啟動本機服務 → 編劇參考
                                 ↓
                     檢閱／選角色與記憶 → 匯出給 agent
                                 ↓
                   等作者提供短篇 → 共同編劇 → 編輯器試玩
```

在 prototypes/debt-commission 目錄執行：

```bash
python3 tools/story_editor/project_server.py --port 8000 --godot /Applications/Godot.app/Contents/MacOS/Godot
```

開啟 http://127.0.0.1:8000/tools/story_editor/ 。舊 Python 服務必須重啟才能載入新增 API；不要只重新整理網頁。若埠被占用，確認現有服務所屬後重啟，或以另一個埠啟動。不要假定前一 session 服務仍存活或程式已更新。

```bash
python3 tools/persona_context.py validate
python3 tools/persona_context.py context --characters gintoki shinpachi kagura --memories gintoki_yorozuya_baseline shinpachi_yorozuya_baseline kagura_yorozuya_baseline
```

正式人物資料在 authoring/characters，記憶在 authoring/memories；authoring/archive 與 proposals 只保留歷史，不由預設 context 載入。新面板不寫入故事或人格資料，也沒有自動確認操作。

## 本輪驗證（L2，2026-10-28）

在遊戲目錄執行，均通過：

```bash
python3 tools/test_persona_context.py
python3 tools/story_editor/test_persona_service.py
python3 tools/story_editor/test_project_server.py
node --check tools/story_editor/editor.js
node tools/story_editor/persona_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --out /private/tmp/debt-persona-editor-handoff-final
```

- 人格工具 11 項；人格 HTTP API 7 項；既有編輯器服務 16 項（包含實際 Godot 驗證、存檔、衝突及獨立試玩）。測試服務需允許 localhost 綁定；首次沙箱綁定被拒，授權重跑後通過。缺庫測試曾因 macOS /var 與 /private/var 差異失敗，fixture 改成 resolve 後七項通過，正式邏輯未繞過 gate。
- 最終瀏覽器 smoke 通過：未確認項目禁選、記憶 owner 限制、預設不載入記憶、知情隔離、UI 產物與 CLI 一致、JSON 下載、選取變更清除結果、已核准新版本也要求重看、對話框 Escape／關閉及故事內容保持、640×600 窄視窗、零 pageerror。Chrome 截圖已人工檢視，最後加上固定標頭後重跑通過。
- 證據為 /private/tmp/debt-persona-editor-handoff-final/report.json、persona-desktop.png、persona-narrow.png、server.log。都是本機暫存；下載的 authoring-context.fixture.json 使用合成測試確認，不能拿來正式編劇。
- 正式庫 validate：valid=true／records=6／confirmed=6；上輪已確認正式角色與審閱提案逐位元組一致，記憶確認未改。
- 這輪未改 Godot scene 或 runtime，不重跑完整遊戲／Web。漫畫與動畫、scene 匯入、Web 觸控證據沿用根目錄 Progress.md 同日各段，不能說是本輪重驗。45 組遊戲測試是較早橫向版的證據。

## 仍未完成與限制

- 完整 CRE、編輯器內 AI Writer／自由聊天、自動記憶檢索、OOC 評分及自動場景生成尚未實作。本次完成製作階段的人格參考與外部 agent 協作流程。
- 網頁不提供人格編輯／人類確認表單，仍以檔案＋CLI 登記真實證據；資料庫是本機協作紀錄，不是身份驗證或簽章。
- 場景試玩不會回放前置背景、角色、音樂或進行中的調查／吐槽狀態；旗標／線索可指定。複雜調查／吐槽步驟仍用 JSON。
- 獨立作品不會自動套用萬事屋人格；目前參考資料源固定為本作 authoring。
- 真人手機、30 節點作者驗收、正式文本與音效仍待作者。完整 L3 測試等作者手動驗收後再跑。
- Web build 不包含此次 Python API／編輯器服務；網頁遊戲本體沿用上次匯出版。前次 Godot 匯出退出有已知資源清理警告。

## 工作區與保留內容

這次只提交 debt-commission 與相關文件、漫畫參考 sinpachi.jpeg，不納入其他原型或刪除的 story-telling-ui2 Large.jpeg。docs/sao 及其他未提交內容保留；禁止 reset、清理或批次還原。提交後以 git status 確認剩餘差異。沒有 push。

重要入口：[README](../README.md)、[編輯器操作](STORY-EDITOR.md)、[人格與確認規則](../authoring/README.md)、[現行完整人格與記憶](../authoring/REVIEW.md)、[session-state](../production/session-state/active.md)、[conversation 歷史核對](../../../docs/story-telling-game/CONVERSATION-AUDIT-2026-10-28.md)。

## 2026-10-30 Web 候選更新

`tools/build_web.sh` 已完成，輸出 `build/web/`；本地封裝 `build/debt-commission-web-candidate-20261030.zip`（79,199,602 bytes），SHA-256 `dbc585c0dcd62840e07349e05be52889be018728e104f2a348097ba5bbc20598`。PCK 452 個檔案，包含 main、investigation_picker 與 investigation_layout 編譯腳本；tests／tools 未入包。IDBFS 修補與 ZIP CRC／必要檔案檢查 PASS。

機器可讀紀錄 `production/qa/web-candidate-2026-10-30.json` 包含來源、ZIP 與 PCK 雜湊。build log `/tmp/debt-web-build-20261030.log` 有 TCP 監聽限制與退出清理訊息，未見 SCRIPT ERROR／Parse Error。此輪僅匯出及靜態驗證，未重跑遊戲測試；沿用上一輪熱區單元／search_cast／Phase3，以及較早幾何／Phase4 證據，具體路徑見 JSON。

沙箱禁止 socket，未啟動伺服器或執行本包 Chromium 互動／IndexedDB 測試；iPhone 真機仍未驗。未上傳、未 commit／push。下一步使用獨立瀏覽器資料驗證調查拖曳、角色移出／移回邊界、離開調查與存讀恢復；作者完整短篇仍待提供構想及核准。
