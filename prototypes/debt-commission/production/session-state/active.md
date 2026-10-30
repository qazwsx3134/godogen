# debt-commission 交接

更新：2026-10-28；分支 `master`。作者要出門，已授權交接並 commit，提交後停止工作，未授權 push。最新提交請用 `git log -1` 查核；遊戲原基準 `21604e3`，本次提交前 HEAD 為其他原型的 `6e9fb85`。

最新狀態見 [系統與編輯器交接](../../docs/HANDOFF.md)：人格／記憶已接入編輯器「編劇參考」，可查看、手選、產生及下載 agent 上下文。正式庫六筆均已確認。本輪人格工具 11 項、API 7 項、既有服務 16 項及最終 Chrome smoke 通過；完整遊戲／Web 測試沿用同日較早證據。內建 AI Writer、自動檢索及 OOC 評分未實作。第一篇極短篇仍等作者提供；不要自行代寫。

以下保留歷次紀錄，舊段落的未提交／待確認描述是當時狀態。

使用者會在本輪開發與測試完成後提供第一篇短篇構想，再共同試用編輯器、編寫故事並完善工作流程。不要先代寫正式故事。

編輯器已能以尚未存檔的內容從選定場景試玩，設定旗標與線索；作品的 catalog／外觀及試玩資料各自隔離。新故事新增分支時會替換預設佔位結尾，結尾後仍有步驟會被編輯器與遊戲驗證指出。背景／立繪／音樂與進行中的互動不從前面場景自動還原。

預設呈現改為 16:9 橫向，閱讀與選單字級縮小，四個閱讀工具按鈕維持原圖比例。舞台與對話框獨立；一般閱讀框固定，長台詞在框內依文字行分頁。調查的話題／回合控制仍可增加面板高度，背景可上下、左右拖曳。Godot 的 `scenes/stage.tscn` 可調左／中／右站位，角色 scene 的 `Art` 可調各自取景；網頁編輯器可拖曳或按鈕選站位。閱讀按鈕及角色回饋支援減少畫面效果。橫向版真人手機手感仍待使用者試玩。

本輪 45 組遊戲測試通過，最後選項版面調整後另重跑相關四組；兩種視窗各檢查 33 個最大字級畫面，四個限時選項完整可見。重新匯出的 Web 已以 Chrome 模擬觸控通過調查、存讀檔及兩種選項；編輯器本機服務 16 項測試通過。細節與紀錄位置見根目錄 `Progress.md`。

2026-10-28 收合按鈕改為精簡深藍銀框；收合列貼底且僅背景降低不透明度，按鈕以外可穿透操作場景。客廳完成全部線索後，展開與收合狀態都提供「繼續」。本次相關遊戲測試、第一章 35 畫面最大字級檢查與 Web 模擬觸控通過；完整 45 組是前次橫向改版的紀錄，這次沒有重跑。

2026-10-28 依新八參考圖改為左右斜切漫畫格、黑白放射線與黑紅氣泡；完美／普通選詞與既有新八吐槽 `cutin` 會播放並可點擊快轉，左右交替、相同台詞不連播兩次。劇本編輯器 `tsukkomi_impact` 可選「出場位置」，兩側場景及光束起點／台詞位置可在 Godot 調整。龜派氣功的光束與上方台詞已分層；故事 JSON 與存檔版本沒有改動。漫畫、超必殺、Phase 3、Phase 4 回合與編輯器左右選擇的相關測試通過；尚待真人手機試玩。本次驗證命令、執行順序與未重跑範圍見根目錄 `Progress.md`。

2026-10-28 角色步驟新增淡入／淡出、左右滑動並淡化、直接切換；「立繪動作」可選抖動或彈跳。連續登場、動作與台詞能接續播放，退場保留當前表情與站位，退場中自動存檔會記成已離場；略讀及減少畫面效果會安全結束動作。編輯器新增從零建立短篇的操作說明，本機服務現於 `http://127.0.0.1:8000/tools/story_editor/`。有獨立動畫、存讀檔與編輯器新建／試玩測試；已重匯 Web 並測 Phase 3，完整測試與真人手機試玩本輪未跑。第一篇短篇構想仍等使用者提供。

操作見 [STORY-EDITOR.md](../../docs/STORY-EDITOR.md)，待辦見 [ROADMAP-COMMERCIAL.md](../../docs/ROADMAP-COMMERCIAL.md)，完整驗證與工作區狀態見[根目錄 Progress.md](../../../../Progress.md)。

2026-10-28 使用者準備和 agent／編輯器合作極短篇，先要求核對 conversation 的全部能力，含人格。報告為根目錄 `docs/story-telling-game/CONVERSATION-AUDIT-2026-10-28.md`：VN 與圖編輯可用；CPC schema／三角色人格資料、特定記憶與檢索、人格 QA、Prompt Assembler、內建 AI Writer／Chat 未實作。已有 carry 旗標不等於完整人物記憶。這輪只核對與修正過時文件，沒有新增人格系統或代寫故事；重跑 choices、ep00（892 checks）、chapter_flow 均通過。下一步建議先補製作階段的人格／記憶最小流程，等待使用者指示。

2026-10-28 後續：使用者授權建立可重複讀取人格／記憶，且必須與人類確認。已建 `authoring/` 三份角色、三條基礎記憶草案與完整 REVIEW.md；正式 confirmations.json 仍為空，尚不能用於正式故事上下文。`tools/persona_context.py` 提供 validate／review／context／confirm，確認綁定完整內容雜湊，修改即需重審；記憶按 known_to 分配。11 項 Python 測試通過，沒有重跑遊戲／Web。下一步請作者審閱六筆草案，明確確認或修改後才可記錄確認證據；不要自行核准。詳見 authoring/README.md。

2026-10-28 人類回覆「這幾項 可以」，已確認所展示六筆 revision 1 人格／基礎記憶；確認證據與完整內容雜湊已逐筆寫入 authoring/confirmations.json。三角色＋三記憶 context 載入成功。只核准這六筆；後續擴充與修改仍需人類確認。

2026-10-28 人格深度補充：`authoring/proposals/character-depth-v2/REVIEW.md` 已展示銀時／新八／神樂四項新增內容與完整人格雜湊；三份 revision 2 為待確認提案，未升入正式資料、未新增記憶。提案 validate=3筆／0確認且 context 確實拒絕；正式資料 validate=6筆／6確認，三人＋三記憶 context 仍成功，base hash 一致。本次未改工具或遊戲，未重跑 Godot／Web；下一步等作者檢閱、確認或修改新提案，不能沿用 revision 1 證據自行核准。

2026-10-28 作者回覆「可以 採用」：三角色 revision 2 已原樣升入正式 characters，新增確認證據已記錄，舊版完整資料與證據留於 authoring/archive/character-depth-v1。三條記憶及確認未改；validate=6筆／6確認，正式三角色＋三記憶 context 成功；已比對提案與正式角色逐位元組一致。README／REVIEW 已同步，proposal_meta 只保留提案建立時歷史。未改程式或重跑遊戲測試，未 commit／push。下一步等待作者提供極短篇構想，一起編劇與使用編輯器。

## 2026-10-29 審查改善

已補完整短篇驗收計畫及 IMPLEMENTATION 維護邊界。未拆分程式、未代寫故事，人工驗收等作者構想與核准文本。本輪僅文件，未重跑遊戲測試。

## 2026-10-29 調查熱區呈現拆分

使用者授權繼續審查改善。新增 `scripts/investigation_picker.gd`：集中最小觸控矩形、重疊優先序與已查熱區的重複台詞資格。main 保留遮擋／忙碌判斷、背景拖曳、角色與存檔生命週期，選到 ID 後仍走原有 Runner／素材流程。未新增故事或修改規則數值。

L2 首輪 investigation_picker／investigation／phase3_ui PASS（`/tmp/godot-tests.ooX4GH`）；phase4_ui 僅失敗於寫死 12 個故事的舊斷言，目錄現有額外 strawberry_chapter1_graph。已改為允許新增故事並保留基線順序、數量對應、標題及試玩標記檢查。Phase4 單獨重跑 PASS（`/tmp/godot-tests.UGlECn`）。匯入與測試有 MCP TCP 監聽受沙箱限制及離開時 RID／ObjectDB 清理訊息，不宣稱零錯誤。Web／真人手機未重驗。

## 2026-10-29 調查背景幾何拆分

新增 `scripts/investigation_layout.gd` 與 `test_investigation_layout.gd`：集中覆蓋取景、anchor／offset 與兩軸拖曳邊界。main 保留 node 套用、角色位置、各地點 pan 保存及離開時還原。L2 investigation_layout／phase3_ui／phase4_ui 全部 PASS（`/tmp/godot-tests.fIuGGD`），log 未見 SCRIPT ERROR／Parse Error；仍有 MCP TCP 監聽限制與匯入退出的 RID 清理訊息。沒有 scene／schema 變更，Web 與真人手機未重驗。

## 2026-10-30 螢幕外角色熱區修正

重現第一章嘴角 art_region 完全移出左緣，觸控擴張仍能選取的問題；修正前 search_cast 有兩項對應 FAIL（`/tmp/godot-tests.FvVWlR`）。現在完全不相交即隱藏，選取器跳過隱藏節點；移回畫面會恢復熱區。未修改素材取得、found 狀態或 scene。L2 search_cast／phase3_ui PASS（`/tmp/godot-tests.8FaZ2e`）；單元首輪因 _init 時 Window 尚未顯示而失敗，改為第一幀後執行，再單獨重跑 investigation_picker PASS（`/tmp/debt-picker-visibility-final.log`）。最終三組 log 未見 SCRIPT ERROR／Parse Error；仍有 MCP TCP 沙箱訊息。Web 與真人手機未重驗。

## 2026-10-30 Web 候選更新

`tools/build_web.sh` 已完成，輸出 `build/web/`；本地封裝 `build/debt-commission-web-candidate-20261030.zip`（79,199,602 bytes），SHA-256 `dbc585c0dcd62840e07349e05be52889be018728e104f2a348097ba5bbc20598`。PCK 452 個檔案，包含 main、investigation_picker 與 investigation_layout 編譯腳本；tests／tools 未入包。IDBFS 修補與 ZIP CRC／必要檔案檢查 PASS。

機器可讀紀錄 `production/qa/web-candidate-2026-10-30.json` 包含來源、ZIP 與 PCK 雜湊。build log `/tmp/debt-web-build-20261030.log` 有 TCP 監聽限制與退出清理訊息，未見 SCRIPT ERROR／Parse Error。此輪僅匯出及靜態驗證，未重跑遊戲測試；沿用上一輪熱區單元／search_cast／Phase3，以及較早幾何／Phase4 證據，具體路徑見 JSON。

沙箱禁止 socket，未啟動伺服器或執行本包 Chromium 互動／IndexedDB 測試；iPhone 真機仍未驗。未上傳、未 commit／push。下一步使用獨立瀏覽器資料驗證調查拖曳、角色移出／移回邊界、離開調查與存讀恢復；作者完整短篇仍待提供構想及核准。
