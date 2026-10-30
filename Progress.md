# 進度與 Agent 交接

## 最新 checkpoint：跨專案改善收斂與 seal 復工（2026-10-30）

分支 `master`。使用者要求原改善清單持續完成，並接續 seal；必要可逆實作已執行，未 commit／push／上傳，其他工作區修改保留。以下為目前狀態，下面逐輪紀錄保留歷史證據。

| 專案 | 已完成的程式／文件工作 | 仍待外部驗收／延期 |
|---|---|---|
| debt-commission | 短篇驗收文件、調查選取／版面拆分、離屏觸控修正、Web 候選 | 作者故事內容與完整短篇真人／手機驗收；不再為拆分而全面改寫 main |
| godot-kit | 成熟度／採用與同步文件、唯讀 hash 盤點、sync --check、CLI 回歸 | 各原型副本不同步，既有差異維持可查 |
| hero-horde-idle | 現況文件、48 組收益證據、強敵與前五分鐘離線算法、存檔完整 schema 與輸出保護 | 真人前三層、容許收益差距與手機恢復成本；Web 路線延後 |
| seal-meadow | 出售確認／快照保護、經濟驗收計畫；本輪另完成 S34 單機乘坐薄切片 | iPhone／真人平衡、Web 新包 IndexedDB、長時間發熱；多人 M4 延後 |

hero 最新 L2 `save_protection progression home main recruit` 全 PASS，證據 `/tmp/godot-tests.vW1ukD`；本批未重跑，詳見下方 10-30 schema 紀錄。其他專案驗證沿用各自最後一輪，未將舊證據冒充本輪結果。涉及真人、作者內容、真機及服務部署的項目保持未完成，未宣稱原清單全面驗收。

seal 本輪第 2 階寵物可乘坐（移速 ×1.25），戰鬥／切區／背景／讀檔下坐；同一 entity，數值不重複，schema 仍 v6。PetPanel 已保存固定標題＋捲動內容的可編輯 scene，沿用現有素材。L2 `companions m3 review_interactions` 全 PASS（`/tmp/godot-tests.KN9GPi`），包含兩尺寸大字、44px、scene 編輯保留；headless 匯入仍有沙箱 TCP 錯誤，未見腳本解析錯誤。AC-S34-03 戰鬥 AI 尚未實作。

seal 新手機包 `build/seal-meadow-mobile-web.zip`：15,112,870 bytes；SHA-256 `6c1cc1117d8bc50dea798f576057665fd1ab97d53557a896ca3c8c2dc42b7b8d`。ZIP／PCK 靜態與編譯 PCK 冒煙 PASS；新包 Web／真機未驗（socket 被沙箱禁止）。詳見 [seal checkpoint](prototypes/seal-meadow/production/session-state/active.md)與 [S34 QA](prototypes/seal-meadow/production/qa/systems/battle-pets-guarders.md)。M2 沿用 `/tmp/godot-tests.8mkgik`；L3 待人工驗收，bot 不跑 25 分鐘。

下一步是此候選的真人／iPhone 驗收與內容回饋；不將待驗項標為完成，也不自行開展延期的多人分支。

## 跨專案審查改善（2026-10-29）

- 專案／分支：debt-commission、godot-kit、hero-horde-idle、seal-meadow；master。使用者授權照改善清單開始修；本段為文件與首項風險修正，其他章節歷史狀態保留。
- 已完成：八份改善文件建立／補寫；debt 的完整短篇驗收與漸進拆分邊界；kit 成熟度／採用資訊與同步規範；hero 目前循環與前三層／離線收益驗收；seal 材料出售規格及經濟實測計畫。
- 程式：seal 一鍵出售先列品項、數量、總額，明示包含養成材料；確認時核對背包快照，變動即拒絕；取消／換窗不出售。可編輯視窗 `ui/sell_confirmation.tscn`。沿用售價與保存流程。
- L2 驗證：隔離 XDG 執行 `TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow m2 m3`：M3 PASS（`/tmp/godot-tests.M1gwyv`）；M2 首次因出售按鈕未捲入可點範圍失敗，補測試捲動後單獨重跑 M2 PASS（`/tmp/godot-tests.Fciz7c`）。scene headless 匯入未見解析／資源錯誤，但有沙箱 TCP listen ERR_CANT_CREATE（`/tmp/seal-fix-import.log`），不宣稱無錯匯入。
- 部分／未完成：debt 已抽出熱區選取，完整調查呈現控制仍待後續功能需求；故事內容等作者提供；三款真人／真機驗收及 hero 在線離線差距與容許值待測。未改平衡數字，未同步 kit 副本。seal Web 候選已於 2026-10-30 重建，匯出及靜態驗證完成，瀏覽器待驗。
- 重要入口：各專案 README；debt `docs/SHORT-STORY-ACCEPTANCE.md`、kit `docs/VERSION-SYNC.md`、hero `docs/FIRST-THREE-FLOORS-ACCEPTANCE.md`、seal `design/quick-specs/material-sale-2026-10-29.md`。
- 續作完成：kit 唯讀逐檔盤點工具 `tools/audit_copies.py` 與 SHA-256 快照；三專案共同檔案差異已分類於 `godot-kit/docs/VERSION-SYNC.md`，未同步。四類暫存 fixture 驗證 PASS。seal 確認改 HUD Control／捲動清單，M2 實際取消／確認與 844×390、1280×720 安全範圍及 44px 高度 PASS（`/tmp/godot-tests.yEAs8b`）；headless 匯入仍有沙箱 TCP listen 錯誤，未見解析／資源錯誤（`/tmp/seal-modal-import.log`）。本輪未重跑 M3，沿用上一批通過證據。
- hero 續作：新增 `tools/compare_march_rewards.gd` 與前後 JSON 證據；修正離線漏算強敵三倍獎勵，實際擊殺數不加權。第一層 seed 73 四組 domain 對照差距從 -14%～-24% 縮至 -8%～+3%；L2 march／progression PASS（`/tmp/godot-tests.VzEGYo`）。初次 scene 嘗試缺匯入快取失敗的數據作廢；最終 domain logs 無 SCRIPT ERROR／Parse Error。重新匯入完成但有沙箱 TCP listen 錯誤。低等成長的固定速率誤差仍待決策；未做真人／真機或全面平衡驗收，未重建 Web。
- debt 續作：新增 investigation_picker，集中熱區命中／優先序；main 保留遮擋與生命週期。L2 investigation_picker／investigation／phase3_ui PASS（`/tmp/godot-tests.ooX4GH`）。Phase4 舊測試寫死 12 個故事，因現有第 13 個故事失敗；已允許擴充並保留基線順序／標記檢查，Phase4 單獨重跑 PASS（`/tmp/godot-tests.UGlECn`）。匯入及測試仍有 MCP TCP／資源清理訊息；未見 SCRIPT ERROR／Parse Error。Web 與真人手機未重驗。
- debt 第二步：新增 investigation_layout，集中背景覆蓋、anchor／offset 與兩軸拖曳邊界；原 pan 保存／還原及角色生命週期保留。L2 investigation_layout／phase3_ui／phase4_ui 全部 PASS（`/tmp/godot-tests.fIuGGD`）；未見 SCRIPT ERROR／Parse Error，仍有 MCP TCP／匯入 RID 清理訊息。未修改 scene／schema，Web 與真人手機未重驗。
- 2026-10-30 seal 手機候選已重建：ZIP／PCK 靜態檢查 PASS，出售確認場景／腳本已入包；ZIP SHA-256 `dbb467521f52a1e971cc367f2b464fad0f0cb59cd1552741c5e712805124246f`。滿包 12 格／大字／兩尺寸捲動與取消 M2 PASS（`/tmp/godot-tests.8mkgik`）。詳見 `seal-meadow/production/qa/mobile-candidate-2026-10-30.json`；沙箱禁止 socket 建立，本包 Chromium／IndexedDB 未驗證，不能套用舊包瀏覽器證據。未上傳。
- 2026-10-30 hero：完成 48 組收益矩陣與工具回歸（`compare_march_rewards --matrix`）；前三層差距 -14.50%～+7.84%，第八層五分鐘退關邊界高估 11.42%～35.07%。完整結果 `hero-horde-idle/docs/march-rewards-matrix-2026-10-30.json`；矩陣完整性／fixture／無錯誤 log 及預設四組結果回歸 PASS。本輪未改 runtime 或重跑 suite，沿用 10-29 march／progression 證據。固定速率容許差距與分段算法仍待決策。
- 2026-10-30 hero 修正：前五分鐘執行戰鬥／升級／退關恢復，再估算剩餘時間；第八層五分鐘高估由 +11%～+35% 改為 -7%～0%，長時間誤差仍在。L2 march／progression／home／main 全 PASS（`/tmp/godot-tests.GbS3oh`）；48 組分段結果及桌面單次結算成本見 hero 驗收文件。未改 schema／單怪獎勵，未重建 Web；手機恢復效能待驗。
- 2026-10-30 kit：sync.sh --check 已整合唯讀差異分類；保留 exit code、外部含空白路徑，audit 新增 --check／JSON 組合。L2 五項隔離 CLI 測試與 bash -n PASS；實際三專案盤點 exit 1（既有差異），數量不變（`/tmp/kit-sync-check-20261030.log`）。副本未同步，Godot 測試未重跑。
- 2026-10-30 debt 邊界修正：第一章嘴角 art_region 完全離開畫面仍能被觸控擴張選取，新增回歸先重現兩項 FAIL（`/tmp/godot-tests.FvVWlR`）；修正為完全不相交時隱藏並略過隱藏熱區，移回可恢復。L2 search_cast／phase3_ui PASS（`/tmp/godot-tests.8FaZ2e`）；單元初次因 _init 視窗未顯示而失敗，改第一幀後執行，單獨重跑 investigation_picker PASS（`/tmp/debt-picker-visibility-final.log`）。最終 log 無 SCRIPT ERROR／Parse Error；未改 scene／schema，Web 與真機未重驗。
- 2026-10-30 debt Web：已重建 build/web 並封裝 `build/debt-commission-web-candidate-20261030.zip`（79,199,602 bytes；SHA-256 `dbc585c0dcd62840e07349e05be52889be018728e104f2a348097ba5bbc20598`）。兩個調查模組／main 已入包，tests／tools 排除、IDBFS 及 ZIP 檢查 PASS；來源／產物雜湊見 `production/qa/web-candidate-2026-10-30.json`。本輪未重跑源碼測試，沿用上一輪證據；本包 Chromium／IndexedDB／真機未驗（沙箱禁止 socket），未上傳。
- 2026-10-30 hero 文件收斂：README 改為現行六頁、種族、18 天賦、原生手機與五分鐘離線算法入口；原 README 全文移存 `docs/history/README-2026-10-30.md`，保留沿革與製作流程並換算相對連結。FUSION 標為歷史決策，PROGRESS 加目前 checkpoint。36 個現況文件連結與來源碼交叉核對通過（`docs/readme-validation-2026-10-30.json`）；僅文件，未重跑遊戲測試，沿用 `/tmp/godot-tests.GbS3oh`。
- 2026-10-30 hero 存檔保護：先重現較新版本／破損 JSON／空檔被覆寫三項 FAIL（`/tmp/hero-save-before.log`）；載入與寫入前現在檢查 JSON 根型別與版本，不相容時阻止覆寫並顯示主畫面提示。L2 save_protection／progression／home／main 全 PASS（`/tmp/godot-tests.zMQXlQ`），提示字型檢查 PASS。範圍限制與重現見 `hero-horde-idle/docs/SAVE-PROTECTION.md`；尚未全面驗證內部欄位 schema，未改存檔版本或輸出安裝包。
- 2026-10-30 hero schema：已完成英雄／隊伍／裝備／詞綴／UID／容量與舊格式驗證，並防止輸出非法快照。20 種異常加 v1／舊 v2 相容案例；初輪 float 版本判斷失敗已修正，最終 L2 save_protection／progression／home／main／recruit 全 PASS（`/tmp/godot-tests.vW1ukD`）。規則／限制見 SAVE-PROTECTION.md；未改 schema 版本。接續使用者指定的 seal 單機開發。
- 下一步：真機確認出售清單可讀及按鈕觸控；按各驗收文件收集實測，再決定架構與數值調整。所有本輪改動未 commit／push；保留其他既有修改。

---


## 蓬蓬草原 · seal-meadow（2026-10-29，持續開發）

- **狀態與決定**：使用者返家要求繼續，之後指定完成一階段就停下並開另一個 Sol medium 審查。S35 單機衣櫥階段與獨立審查已完成，目前暫停；多人 M4 延後。`master` 最新提交與本輪基準 `180149a9`；本輪程式、scene、測試及文件未 commit／push，保留其他專案現有修改。
- **本輪完成**：`REVIEW.md` 第 8～10 項：背包精煉、技能命中後選怪、傳送門高亮；存檔過量背包回復備份或拒絕覆寫、寵物餓到時顯示實際損失。S35 衣櫥可預覽／取消、以已領成就解鎖布衣與裝飾光環，套用不改戰鬥屬性；存檔升 v6，有舊檔遷移與無效資格檢查。
- **規格**：補齊 S17 寵物、S18 精煉、S19 圖鑑、S33 釣魚與 S35 衣櫥的 GDD／TDD／QA，以及 [經濟分析](prototypes/seal-meadow/production/qa/m3-economy.md)；精煉 +0→+6 以商店價理論期望 935.24 金／件，非真人平衡。
- **驗證**：最新 L2 `wardrobe`／`m0`／`m3`／`m3_hardening`／`collection`／`content`／`review_interactions` 七組通過（`/tmp/godot-tests.wtxsbV/`），匯入無錯；審查後改測試名稱並單獨重跑 `test_wardrobe.gd` 通過。先前 `m1`／`m1_loot`／`fishing` 也通過；11 個隔離變異均被測試抓到。844×390 Chromium 12 項載入、v4／v5→v6、精煉與衣櫥預覽／保存通過、0 瀏覽器錯誤（`/tmp/seal-web-wardrobe-20261029/report.json`）。均非 iPhone 真機證據。
- **Web 候選**：`tools/build_mobile_web.sh` 已成功執行，PCK 35.07 MB、WASM 約 39.5 MB；`build/seal-meadow-mobile-web.zip` SHA-256 `a8150f3138aa02062f7abbd855ea6d87a7de0fba8cb16a7d4bacefb73efb91c4`。`build/web/` 仍是 2026-10-27 舊版；本輪本地測試伺服器 8795 已停止，未上傳。
- **獨立審查與待辦**：另開 GPT-6 Sol／medium 做唯讀審查，未發現可重現的本輪功能缺陷；指出「v5 讀取器拒絕 v6」測試本身不等於舊版整個遊戲實測不覆寫，已修正測試描述與 QA，舊版執行端對端仍未驗。報告 `prototypes/seal-meadow/production/qa/reviews/2026-10-29-sol-medium.md`。iPhone 17 Safari、FPS、20～30 分鐘發熱與真人試玩仍待驗收；bot 不跑 25 分鐘。使用者要求目前先停下，無授權不 commit／push、上傳 itch 或同步其他原型 kit。

---
## 全員推王 · hero-horde-idle（2026-10-28）

- **目前工作**：`prototypes/hero-horde-idle`，分支 `master`。第三～六輪回饋（作者的 `REVIEW.md` 與後續對話）已 commit 到 master（未 push；最新提交以 `git log -1` 查核）。詳細交接在 [docs/PROGRESS.md](prototypes/hero-horde-idle/docs/PROGRESS.md)。
- **已完成**：刀劍神域風介面（選單白色＋戰鬥 HUD 深色玻璃；規範 `docs/SAO_UI_SPEC.md`、元件庫 `scenes/ui_kit/`）、樓層與樓層王、天賦 18 節點、英雄詳情改版（換裝、升級、數值明細視窗）、三級經驗藥水、英雄改人類／獸人／精靈、道具圖示去背、版面留白、推王英雄被壓扁的修正、士氣改成出手頻率（被打會扣）。
- **驗證**：`test_progression／home／main／march／report／skills／recruit／balance／stages` PASSED（2026-10-28）。
- **等作者**：生精靈／獸人英雄圖（`docs/race-art-prompts.md`）與背景圖層（`docs/bg-layer-prompts.md`）；手機實機試玩。
- **工作區**：debt-commission 的未提交修改保留未動，沒有夾帶進 hero-horde 的 commit。

## 萬事屋吐槽 ADV · debt-commission（2026-10-27）

- **目前工作／交接**：`prototypes/debt-commission`，分支 `master`；2026-10-28 作者要出門，要求交接並 commit。已完成本輪人格協作與編輯器整合；本次提交前 HEAD 為其他原型的 `6e9fb85`，先前遊戲基準為 `21604e3`。提交包含此段落對應程式、測試、資料及文件，完成後停止；最新提交以 `git log -1` 查核，沒有 push。完整交接見 [HANDOFF.md](prototypes/debt-commission/docs/HANDOFF.md)。第一篇極短篇仍等作者提供，沒有代寫。
- **已完成**：節點編輯器可從選定場景試玩當下的未存稿或唯讀故事，調整旗標與線索；使用作品自己的素材／外觀及獨立暫存遊戲資料。新場景加入分支時會替換預設佔位結尾，編輯器與遊戲驗證會拒絕終止步驟之後不會執行的內容。
- **本次 UI／手感**：預設改為 16:9 橫向，閱讀與選單字級縮小；LOG／AUTO／SKIP／MENU 按鈕依原圖比例呈現。舞台站位獨立於閱讀框，對話可遮住立繪；一般閱讀框固定，長台詞在框內依文字行分頁，調查或回合控制可依內容增加面板高度。橫向調查可上下及左右拖背景，並保存垂直取景。標題、選項、目錄與案件檔已調整橫向版面。
- **編輯器與手感**：`scenes/stage.tscn` 的左／中／右站位有實際角色預覽，角色 `Art` 可單獨調整；網頁編輯器的 `char` 可拖曳或按按鈕選左／中／右。閱讀工具列有不影響觸控範圍的按壓回饋；減少畫面效果設定同時作用於按鈕、角色動作及舞台淡入淡出。
- **本次橫向驗證**：45 組 headless 測試通過（遊戲目錄下 `env GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot TEST_TIMEOUT=120 python3 tools/story_editor/run_coordinated.py bash ../godot-kit/tools/run_tests.sh .`，紀錄 `godot-tests.pqtoNJ/`）；最後收緊選項版面後重跑 `choices`、`phase3_ui`、`phase4_rounds_ui`、`landscape_reading`，均通過（`godot-tests.9QRYjq/`）。`tools/text_fit_audit.gd` 以實際視窗及最大字級，在 1136×640 和 1024×768 各檢查 33 個畫面，均無裁字；已確認限時四選項真的進入選擇畫面且完整落在捲動區（`/private/tmp/debt-landscape-fit-small-final2/`、`/private/tmp/debt-landscape-fit-4x3-final2/`）。長台詞兩頁與固定立繪的實際畫面在 `/private/tmp/debt-landscape-reading-v3/`。本機編輯器服務 16 項測試通過。
- **Web 驗證**：重新匯出後，Chrome 模擬觸控的 Phase 3 調查、四個限時選項、選單暫停與存讀檔共 6 組通過；POV 與導演選項在 800×450、640×360 各 5 組通過，並檢查選項完整落在可見範圍。報告為 `test-results/phase3-report.json`、`test-results/choices-browser-report.json`，兩者均無瀏覽器或遊戲 runtime error。
- **前次直式 UI 驗證（歷史紀錄）**：44 組 headless 測試通過（`godot-tests.Yzn9Hx/`）；末次按鈕調整後 `reading_feel`、`stage_scene` 通過（`godot-tests.HdatEK/`）。320×568、390×844 各檢查 33 個最大字體畫面，均 0 項截字（`/private/tmp/debt-text-fit-320/`、`/private/tmp/debt-text-fit-390/`）；瀏覽器站位拖曳、未存稿試玩與三結局通過（`/private/tmp/debt-preview-position-final/`）。這些是橫向改版以前的證據。
- **前一輪驗證**：同日遊戲本體先前 43 組測試、本機服務 16 項、編輯器核心、原有瀏覽器 smoke 與作品包 smoke 通過；橫向改版後只重跑了其中的本機服務測試，編輯器核心與原有 smoke 未重跑。Godot headless 匯入／匯出在離開編輯器時仍報資源／RID 清理警告，匯出成功並通過瀏覽器測試。
- **已知限制**：場景試玩不會還原前面場景的背景、角色、音樂，或進行中的調查／吐槽回合；必要時從較早場景試玩。複雜的調查、吐槽與結算步驟仍有 JSON 編輯區；複製子圖、30 節點作者驗收、橫向版真人手機試玩與正式音效／文本仍未完成，依第一篇故事實際需求再安排。
- **重要文件**：[專案 README](prototypes/debt-commission/README.md)、[編輯器操作](prototypes/debt-commission/docs/STORY-EDITOR.md)、[商業級待辦](prototypes/debt-commission/docs/ROADMAP-COMMERCIAL.md)、[此專案 session-state](prototypes/debt-commission/production/session-state/active.md)。
- **工作區**：保留原有其他修改（根目錄 `AGENTS.md`、`CLAUDE.md` 與 taskbar-hero 相關 AGENTS）；本輪另有 debt-commission 程式、測試與文件變更。`godot-kit/sync.sh --check debt-commission` 報既有 drift，本輪未改共用模組副本。
- **下一步**：等使用者分享短篇構想，一起拆出場景／分支，再以編輯器寫作、存檔和試玩；依實際卡點調整工具與流程。

### 2026-10-28：出門交接與編輯器人格參考（最新）

- **已完成**：編輯器「編劇參考」串接正式人格／記憶庫；可唯讀查看、手選角色與記憶、產生／下載與 CLI 相同的 agent 上下文。未確認與內容變更阻擋，按 known_to 隔離記憶，owner 必須在選角中；版本更新要求重開檢閱；面板不改故事、不自動核准。三角色 revision 2／三記憶 revision 1 皆已確認；舊版與原提案存檔。
- **本輪 L2 證據**：遊戲目錄 `python3 tools/test_persona_context.py` 11項、`python3 tools/story_editor/test_persona_service.py` 7項、`python3 tools/story_editor/test_project_server.py` 16項及 `node --check tools/story_editor/editor.js` 通過。最終 `node tools/story_editor/persona_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --out /private/tmp/debt-persona-editor-handoff-final` 通過，涵蓋實際勾選、知情隔離、CLI對照、下載、版本衝突、窄視窗及故事保持。報告與截圖在該暫存目錄，測試確認僅在fixture。正式 validate=6筆／6確認。
- **未驗證／未實作**：本輪未改 Godot scene／runtime；既有漫畫、動畫、Web及完整45組遊戲測試沿用下文同日較早證據，未本輪重跑。完整 CRE、內建 AI Writer、自動記憶檢索、OOC評分、真人手機與作者短篇試作仍未完成；不宣稱 conversation 所有能力完成。
- **交接／提交範圍**：作者已要求 commit，範圍為 debt-commission 的現有漫畫／立繪動畫、人格／記憶及編輯器整合、測試、相關文件與新八參考圖。現有第一章圖編輯副本僅 id／generated_from 與原章不同，作可編輯副本保存，不是新故事。docs/sao 與舊參考圖刪除等不屬本次變更保留。Progress.md／README／active／HANDOFF 已同步。完成 commit 後停下等續作，不 push。
- **下次接手**：先讀 HANDOFF、README與session-state，重啟本機 Python 服務才有新增 API，再打開「編劇參考」。等待作者提供故事；後續新增人格或記憶仍請人類確認。本機服務是否存活未查核，不把舊網址當成仍可用。

### 2026-10-28：調查收合列

- **已完成**：「收起」改為與閱讀工具列相同尺寸的精簡深藍銀框按鈕，保留獨立觸控範圍及減少動作設定。收合後的細列貼齊底部，背景透明度為 25%；非按鈕區域可穿透拖曳與點擊。集齊線索後，客廳的展開畫面顯示可用的「繼續」，再次收合時底部也提供「繼續」。實作與版面分別在 `scripts/investigate_bar.gd`、`main.gd`、`scenes/ui/investigate_bar.tscn`、`scenes/ui/gintama_investigate_toggle.tscn` 和 `scenes/ui/dialogue_box_gintama.tscn`。
- **本次驗證**：`phase3_ui`、`phase4_ui`、`ui_styles`、`landscape_reading`、`reading_feel` 通過（`godot-tests.qdM7fL/`）；補上新按鈕減少動作檢查後重跑 `reading_feel` 通過（`godot-tests.NRPka0/`）；補上透明列點擊穿透後重跑 `phase3_ui` 通過（`godot-tests.UKwBO9/`）。以 1136×640 Godot 視窗跑第一章與最大字級檢查，35 個畫面無裁字；其中確認客廳集齊四條線索後收合及展開都有可用的繼續鈕（`/private/tmp/debt-investigate-textfit/`）。Web 重新匯出後，Chrome 模擬觸控的 Phase 3 收合、展開、穿透拖曳、集齊線索後從收合列繼續、選項與存讀檔通過，報告在 `test-results/phase3-report.json`。本次未重跑上面記載的完整 45 組或其他編輯器瀏覽器流程；橫向真人手機實機試玩仍待使用者驗收。
- **工作區／後續**：本 session 沒有執行 commit 或 push；目前基準 `21604e3` 已包含場景及收合功能，後續 QA、測試和文件仍有未提交修改。保留其他專案的修改；等使用者提供第一篇短篇構想，再一起試寫並完善工作流程。

### 2026-10-28：漫畫吐槽與龜派氣功

- **已完成**：參考 `docs/gintama-like/new/sinpachi.jpeg`，沿用既有新八表情做左右斜切漫畫格、黑白放射線和黑紅爆炸氣泡；完美／普通吐槽選詞與既有的新八吐槽 `cutin` 會播放，左右交替，點一下可快轉後接回故事，相同台詞不連播兩次，放棄及冷場不顯示口語漫畫格。光束必殺及連擊提示保留各自演出；既有故事及存檔版本沒有改動。先隱藏舊通知以免遮擋氣泡；集滿力量的提示在漫畫格後顯示。減少畫面效果時停止舞台放大。
- **可編輯／光束**：`scenes/comedy/tsukkomi_impact.tscn`、`tsukkomi_impact_right.tscn` 可在 Godot 各自調整構圖；劇本編輯器新增「出場位置」，`.dialogue` 的 `do comedy(...)` 可附 `left`／`right`，未指定預設左側。`scenes/ui/beam.tscn` 將光束改為起點光暈及向前擴散的光束；`scenes/ui/cutin.tscn` 的 `BeamCaptionArea` 讓同時出現的台詞留在上方。畫面與資源均以現有素材及保存 scene 製作，沒有生成圖片。
- **本次 L2 驗證**：在遊戲目錄用 `python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/<測試>.gd` 依序執行 `test_comedy`、`test_super_effects`、`test_phase3_ui`、`test_phase4_rounds_ui` 均通過，含既有吐槽與選詞去重及光束流程；補上修改漫畫格位置、儲存副本後播放仍保留位置的檢查，重跑 `test_comedy` 通過。`node tools/story_editor/comedy_side_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'` 通過選位置、切換 preset、存檔驗證與重新載入。Godot headless 匯入完成；以隔離 HOME 重新匯出 Web 後，`node tools/browser_check.mjs --phase3 ... --url http://127.0.0.1:5198/` 的橫向觸控、漫畫格快轉與通知不遮擋通過（`test-results/phase3-report.json`、`phase3-manga-retort.png`）。編輯器瀏覽器測試在最後加上既有 `cutin` 漫畫顯示前執行；沒有重跑完整測試。桌面 Godot 實際截圖檢視左右漫畫格與光束（`/private/tmp/debt-effects-after/`），超必殺實際流程由 headless 測試驗證，尚未做真人手機手感驗收。
- **限制與後續**：Web 匯出成功，但隔離環境仍有既有 macOS CA／MCP port 與編輯器退出時資源清理訊息。第一篇短篇仍等使用者提供，沒有代寫；之後一起以編輯器試寫與調整流程。本次沒有 commit／push，`21604e3` 是現有實作基準，以上程式、scene、測試與文件仍在未提交工作區，保留其他專案既有修改。

### 2026-10-28：立繪動畫與故事編輯

- **已完成**：角色 `char` 步驟可選淡入／淡出、從左／右滑動並淡化、直接切換；新增 `portrait_effect`，能讓已登場立繪抖動或彈跳。編輯器的「角色狀態」「進退場動畫」「立繪動作」都有表單；純文字來源支援 `enter(..., "slide_left")`、`hide(id, "fade")`、`portrait_effect(id, "shake"|"bounce")`。登場後馬上接立繪動作與台詞時，動作會在登場後播放；切換表情、略讀、減少動作和連續台詞不會留下偏移或過期的退場回呼。退場維持當前表情與站位，即使動畫尚未結束，下句自動存檔也記錄角色已離場。既有故事資料未改寫。
- **本次 L2 驗證**：在遊戲目錄用 `python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/<測試>.gd` 依序執行 `test_portrait_motion`、`test_reading_feel`、`test_search_cast`、`test_phase3_ui` 通過；`test_story`、`test_story_build`、`test_stage_scene` 在最後的略讀／自動存檔修正前通過。動畫測試涵蓋進退場方向、特效、變表情、略讀／減少動作、退場時自動存檔與重讀；故意把抖動位移歸零後確實失敗，恢復後重跑通過。`node tools/story_editor/portrait_motion_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'` 通過角色動作選擇、存檔重開、建立新故事與未存稿試玩（此瀏覽器測試在最後的略讀／自動存檔修正前執行）；編輯器 fallback 枚舉與 runner 一致。本機 Godot 視窗截圖檢視淡化、滑動、抖動、彈跳（`/private/tmp/debt-portrait-audit/`）。重新匯出 Web 後，Chrome 模擬觸控的 `--phase3` 六組通過，報告 `test-results/phase3-report.json`；本機編輯器實際載入專案、存檔入口與新增立繪動作選項已確認。
- **使用與限制**：編輯器現於 `http://127.0.0.1:8000/tools/story_editor/`，從零寫作步驟在 `prototypes/debt-commission/docs/STORY-EDITOR.md`。未存稿可從選定場景試玩；本機存檔後桌面遊戲重新開啟可選故事，Web 需重新匯出才包含新故事。既有 `.dialogue` 故事在圖編輯器唯讀，可轉成獨立副本；增刪既有故事的步驟可能使舊遊戲存檔版本不符。本輪沒有重跑完整測試或真人手機驗收。Web 匯出仍有既有 macOS CA／MCP port 與編輯器退出時資源清理訊息；本次沒有 commit／push，保留工作區既有修改，等待使用者提供第一篇短篇構想。

### 2026-10-28：conversation 功能與人格系統核對

- **需求／結果**：使用者準備和 agent、編輯器合作一篇極短篇，先要求驗證 `docs/story-telling-game` conversation 中的能力。核對 base 三份與 v2 四份紀錄，對照第一方資料、runtime、編輯器與寫作指引，產出 [核對報告](docs/story-telling-game/CONVERSATION-AUDIT-2026-10-28.md)。結論不是全部完成：短篇播放、分支、演出與編輯器可用；CPC 人格 schema／三角色完整資料、記憶／知識／關係模型與檢索、人格一致性 QA、Prompt Assembler、內建 AI Writer／Chat 未落實。現有角色 profile、tone、history 與章節 carry 不能等同完整人格／記憶系統。
- **文件修正**：STATUS 加入最新核對入口及人格缺口；STORY_WORKFLOW 的現行契約／編劇 prompt 改為 16:9 橫向，說明人工 prompt 與已整合系統的差異。早期格子地圖、紙娃娃等列作後續方向，非目前極短篇前置。
- **本次驗證**：遊戲目錄依序用 `python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/<測試>.gd` 跑 `test_choices`、`test_ep00`（892 checks）、`test_chapter_flow`，均 PASSED。Godot 退出有既有資源／RID 清理訊息；本次未跑 Web、編輯器 browser smoke、完整測試與真人試讀，其他能力沿用本檔前次證據並做靜態核對。知識圖 MCP 回覆 Transport closed，改用第一方檔案搜尋。
- **下一步／工作區**：建議先補製作階段 CPC 最小資料、特定記憶與 agent 寫作／檢查／作者採納流程，再合作短篇；本次未實作缺漏功能、未代寫故事。分支 master、基準 `21604e3`，沒有 commit／push，保留前次遊戲與其他專案未提交修改。

### 2026-10-28：可重讀人格／記憶與人類確認

- **使用者要求**：建立可重複讀取人格與記憶資料，必須和協作人類確認。已完成最小製作階段檔案／CLI 流程：`authoring/characters/` 三人草案、`authoring/memories/` 三條萬事屋基礎背景記憶、空的 `confirmations.json`、`REVIEW.md`（完整內容與雜湊），以及 README／AGENTS 規則。所有六筆仍待作者確認，沒有把使用者同意建立工具誤當成內容核准；例句新擬且非原作引文，不包含虛構的玩家歷史。
- **工具**：`tools/persona_context.py` 提供 validate／review／context／confirm。每份人格、每條記憶分別綁定人類確認證據及 SHA-256，內容變更即失效；context 遇到未確認／未知資料會整體拒絕，明確選取記憶並按 known_to 分配。這是本機確認紀錄，不是登入／簽章或身分驗證；agent 不得自行填入確認證據。尚無網頁人格編輯器、完整 CRE、OOC 自動 QA 或自動記憶檢索。
- **L1 驗證**：遊戲目錄 `python3 tools/test_persona_context.py` 11 項通過，涵蓋草稿阻擋、改動失效、記憶確認／知情範圍、未知 owner、重複 id、缺證據、過期確認 hash；確認 fixture 只在臨時目錄。記憶 gate 的變異檢查（在獨立 Python 程序中讓 confirmed 永遠 true）確實使阻擋測試失敗，正式程式無修改；恢復正常程序後 11 項通過。`python3 tools/persona_context.py validate` 顯示 valid=true／records=6／confirmed=0；真實 context 命令確認被阻擋。本輪未改遊戲 runtime，未跑 Godot／Web 測試。
- **下一步／工作區**：向作者展示 REVIEW.md 內六筆具體內容，請逐筆確認／修改，取得明確答覆與內容範圍後才登記確認並開始寫故事。STORY_WORKFLOW／README／核對報告已加最新入口，active.md 已交接。master 基準 `21604e3`，沒有 commit／push；保留其他專案及前輪修改。

- **後續人類確認**：作者回覆「這幾項 可以 請問人格跟記憶要列多一點比較好嗎？」；比對 REVIEW 中六筆雜湊與目前內容一致後，逐筆記錄三角色＋三條基礎記憶 revision 1 的確認及原話證據。context 成功載入六筆；README／REVIEW／active 已同步，後續新增與修改仍需重審。本次僅更新資料確認狀態，未改程式，未重跑遊戲測試。

本次暫時啟動本機遊戲 `http://127.0.0.1:5198/?sample=phase3` 與編輯器 `http://127.0.0.1:8000/tools/story_editor/`；程序是否仍存活需自行確認。Web 產物在 `build/web/`，可由 `tools/build_web.sh` 重建；隔離 HOME 匯出時需讓 Godot 4.7 的現有匯出範本可見。

編輯器回歸在 `prototypes/debt-commission` 執行；本機服務和 Chrome 需能綁定 localhost、啟動本機瀏覽器。輸出保存在各 `--out` 的暫存資料夾：

```bash
python3 tools/story_editor/test_project_server.py
python3 tools/story_editor/run_coordinated.py node tools/story_editor/test_core.mjs --godot /Applications/Godot.app/Contents/MacOS/Godot --out /private/tmp/debt-story-core-test
node tools/story_editor/preview_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --out /private/tmp/debt-preview-smoke
node tools/story_editor/pack_smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --out /private/tmp/debt-pack-smoke
python3 tools/story_editor/run_coordinated.py node tools/story_editor/smoke.mjs --playwright /Users/peter/.npm/_npx/e41f203b7505f1fb/node_modules/playwright-core --chromium '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' --godot /Applications/Godot.app/Contents/MacOS/Godot --out /private/tmp/debt-story-browser-smoke
```

此 checkout 未見 `studio/runtime/codex/`；`studio/README.md` 說明安裝器會產生該目錄並修改 `.codex/`／manifest，本輪沒有執行安裝器。Herdr 環境變數指定的工作區無法解析，本輪由主 session 自行完成。

---


### 2026-10-28：三角色人格深度補充提案

- **完成／待確認**：依作者要求補上銀時、新八、神樂的情境反應（被質問、受委屈、同伴遇險）、三組語氣正反例、認真觸發／行為界線，以及面對不同人的同意圖口吻。存於 `authoring/proposals/character-depth-v2/`，含三份完整 revision 2 JSON、REVIEW 與空確認紀錄。官方人物頁支持基礎特徵；細節與台詞明確標為本次寫作解讀與原創例句，不導入電影事件或新增記憶。三筆尚未經人類確認，保留正式 revision 1 與六筆既有確認。
- **資料驗證**：遊戲目錄執行 `python3 tools/persona_context.py --root authoring/proposals/character-depth-v2 validate` → valid=true／records=3／confirmed=0；主目錄 `validate` → records=6／confirmed=6。另以 Python subprocess 實際確認提案 context 被拒絕、正式三角色＋三記憶 context 成功，並逐筆比對提案 based_on_sha256 與正式角色一致。未改 runtime／scene／工具，未重跑 Godot、Web 或完整測試。
- **下一步／工作區**：作者檢閱 REVIEW 中的具體內容，確認全部或指定修改後，再升入正式角色並登記新版本確認。第一篇故事仍等作者提供。分支 master，未 commit／push；保留所有既有及其他原型未提交變更。


### 2026-10-28：第二版人格經作者採用

- **已完成**：作者明確回覆「可以 採用」，已將審閱的銀時／新八／神樂三份完整 revision 2 原樣升入正式 `authoring/characters/`，透過 confirm 命令將本次原話、範圍與內容雜湊登記至正式 confirmations.json。升版前人格／審閱稿／確認證據保存在 `authoring/archive/character-depth-v1/`；三條既有記憶與其確認紀錄維持 revision 1。README／REVIEW／提案快照說明已同步；proposal_meta 保留提案建立時資料，不作目前確認狀態判定。
- **本次資料驗證**：遊戲目錄 `python3 tools/persona_context.py validate` → valid=true／records=6／confirmed=6；以 Python subprocess 執行三角色＋三記憶的正式 context 成功，另 assert 正式三份角色與已審提案逐位元組相同、三筆記憶確認與升版前紀錄相同。只變更資料／文件，未重跑工具單元測試、Godot 或 Web；11 項工具測試仍沿用前次建置證據。
- **下一步／工作區**：可用已確認人格與記憶共同編寫作者即將提供的極短篇。後續新內容仍逐次送人類確認。本次沒有 commit／push，保留其他專案與既有遊戲未提交變更。


## 全員推王融合版 · hero-horde-idle（2026-10-27）

- **目前工作**：使用者要求把 taskbar-hero、hero-horde-idle、dreamling-idle 融合；確認後的決定見 `prototypes/hero-horde-idle/docs/FUSION.md`。分支 `fusion-idle`（從 `hero-horde-squads` 的 `0486a1f` 開出），融合版提交為 `40355fb`，2026-10-27 依使用者指示合併進 master（`7b6964a`，未 push）；原本的獨立 worktree 已移除。合併衝突在 hero-horde-idle 採融合版（master 的 `1b119d0`／`0a65639` 建在舊六區架構上），godot-kit README 與 art_src/.gitignore 兩邊都留；合併後 `test_march`／`test_home`／`test_main` 與 kit 的 `test_proto_kit`／`test_genre_modules`／`test_m0_modules` 通過。
- **已完成**：遠征紀事七頁主畫面＋常駐行軍戰場；行軍真戰鬥（`domain/march_sim.gd`，固定 tick、打輸退關、離線依實測速率）；100 名英雄分人類 40／怪獸 30／夢靈 30 與形態被動（推王與行軍）；行軍小隊羈絆；訓練取代職業等級；上陣格 3→5；圖鑑；裝備詞綴與自動分解；存檔 v2（v1 轉換）；金幣經濟 ×10；怪獸／夢靈暫用美術（Skybound 動作圖換色）。
- **驗證（2026-10-27，L2，沿用本輪）**：`test_march`、`test_progression`、`test_stages`（十關全過；good 在 3-4 的推薦戰力閘門放寬到 1.25 倍，理由寫在測試裡）、`test_home`、`test_recruit`、`test_balance`、`test_report`、`test_skills`、`test_main` 全部 PASSED（之後修了推王字型缺字、回前景補算離線、戰報形態頭像，重跑 `test_home`／`test_march`／`test_main`／`test_report`／`test_skills` 通過）；`tools/capture_home.gd`、`tools/capture_shots.gd` 截圖逐頁看過。完整測試等作者手動驗收後再跑一輪。
- **已知問題**：試跑時誤用作者的真實存檔（macOS 的 user:// 不看 `XDG_DATA_HOME`），v1 存檔已被轉成 v2 並補發 8 小時離線收益，原始 v1 無備份（APFS 本機快照沒有；Time Machine 若有可能還在）；轉換後快照 `~/.claude/backups/20261027-hero-horde-idle-progress-v2-migrated.json`。舊分支遊戲讀不懂 v2。之後試玩用 `-- --save=<名稱>`。
- **第二輪（2026-10-27 下午，合併後在 master 工作區，全部未 commit）**：使用者回饋「畫面太小、推王 UI 風格要對齊放置畫面、訓練改點亮天賦、所有英雄都能裝備＋一鍵裝備、總覽改放設定鈕左邊」。已做：天賦星圖（9 節點含 3 個團專精，`scenes/components/talent_node.tscn`、`scripts/talent_links.gd`）；裝備頁飾品持有者用 ◀▶ 切換全部英雄、一鍵裝備；英雄頁「裝備」鈕；頂欄「總覽」鈕；主畫面字級放大與單行省略號；長螢幕時頁面貼底、上方補天空（`home.gd _fit`）；預覽視窗 430×932；推王主題 `ui/theme.tres` 換成紙色／藍金按鈕（`tools/theme_taskbar.gd`）並把淺色文字覆寫改墨色。工具：`tools/build_fusion_ui_v2.gd`（已套用）。另刪除 95 個 `art_src` 殘留 `.import`。
- **第二輪驗證**：專精調到每級 ×1.02、最多 10 級、起價 10 萬後 `test_stages` 與 `test_progression` 通過；主畫面與推王截圖看過（`/tmp/fusion_shots2`、`/tmp/fusion_push2`，暫存）。出門時 `test_home`／`test_main`／`test_march`／`test_progression` 的 L2 回歸正在背景跑，結果見下一行。
- **下一步**：確認那四支測試結果；重拍七頁截圖（加上天空後的版面與天賦星圖名稱還沒重拍）；作者試玩看字級夠不夠大（目前每頁仍照寬度縮放，細長手機只多出天空）；決定是否 commit（master 工作區另有 debt-commission session 未提交修改，`Progress.md` 不可夾帶提交）。`art_src` 有 84 張 PNG 因 LFS 規則顯示已修改，要 `git add --renormalize` 才會消失，尚未處理。交接細節在 `prototypes/hero-horde-idle/docs/PROGRESS.md`。

## 夢靈遠行 · Dreamling Trails

更新日期：2026-10-27（Asia/Taipei）。本章專案：**夢靈遠行 · Dreamling Trails**，位置 `prototypes/dreamling-idle`。分支 `master`；遊戲實作基準 commit **`57d79ac`**（`feat(dreamling-idle): add first playable idle RPG and system research`）。最新提交另以 `git log -1 --oneline` 確認。

**目前狀態：第一個可玩版本已完成，本段落依使用者要求暫停。** 本次只補交接紀錄與持續維護規則，沒有恢復遊戲功能開發。完整研究的 30 個系統尚未全部實作，也未完成正式發行驗收。

## 使用者決定與交接規則

- 先做可玩的橫向放置 RPG，使用一般 Godot 單一視窗。
- **桌面置頂、透明、特殊焦點／桌面殼處理先不製作**，不作為目前驗收門檻。
- 已要求做到段落後暫停，將本次進度 commit 到 master；沒有要求 push。
- 往後每次 commit 前，或使用者說出門／下班／暫停／交接時，更新本檔；接手 Agent 先讀這裡。出門／下班的通知不單獨構成 commit 或 push 授權。
- AI 美術生成前，要先描述素材並讓使用者選擇直接生成或提供 opt image prompts。本輪沒有生成 AI 圖片。

## 已完成

| 區域 | 已實作內容 |
|---|---|
| 研究與規劃 | 分析 9 張截圖、6.59 秒錄影／194 幀；39 份 Markdown、30 系統草案、依賴、架構提案、數值模型、roadmap、既有模組盤點 |
| 專案底座 | 獨立 Godot 4.7 專案、Compatibility renderer、1280×900 設計尺寸、960×675 視窗檢查、繁中 Noto 字集 |
| 戰鬥 | 單一 0.05 秒固定 tick、水平移動／選敵、普攻、護甲、死亡、有效治療、單次治療傷害反應、波次推進 |
| 關卡 | 6 關、每關 3 波、兩場首領、自動推進／重刷、首通獎勵、戰敗恢復並回到已通關地圖 |
| 角色與編隊 | 6 種唯一夢靈、起始持有 3 種、條件招募、2～3 上陣格、EXP／等級／付費培養、森靈與獸靈羈絆 |
| 裝備與容量 | 武器／防具、穿脫／轉移／鎖定／出售、36 格背包、64 格待領；皆滿時停止新增裝備，金幣／EXP 繼續 |
| 管理介面 | 夢靈／裝備／地圖／天賦／圖鑑／戰報六頁、6 項永久天賦、提示、暫停、聲音切換（預設靜音） |
| 存檔 | 原子寫入、有效舊檔備份、壞檔回退、較新 schema 保護、JSON 整數正規化、20 秒自動／手動／正常退出存檔 |
| 可編輯場景 | 主畫面、六面板、四種卡片、actor／血條／戰鬥帶／飄字皆為保存的 `.tscn`；Theme 與版面可在編輯器調整 |
| 交付 | 原生專案可執行；Web 匯出及本機 ZIP 已產生；真實瀏覽器操作與 IndexedDB 重開測試完成；README、素材來源與證據已記錄 |

## 部分完成與刻意限制

- 六種角色共用三套既有動作圖，使用 tint 區分；背景沿用 Erwin Run。是內部切片暫用素材，專屬美術及外部發行授權清單仍待整理。
- 目前是每種角色一個唯一個體，沒有重複個體、個體詞綴或重複角色處理。
- 羈絆只有森靈生命與獸靈攻擊；治療反應為一條受限事件鏈，尚未製作完整關鍵詞／反應系統。
- 六頁管理功能可用，仍需真人實玩確認戰鬥辨識、操作與前 15 分鐘節奏。
- 修改編隊／裝備／天賦會在下一波生效；本波使用開始時凍結的 build。
- 關閉後沒有收益；重開由目前關卡第一波開始，不還原戰鬥中 HP。貢獻報表為本次遊玩統計。

## 尚未製作／尚未驗收

- 重複角色與進化、工坊／製作、完整詞綴、完整倉庫與批次管理。
- 離線收益模型、時間區間去重、離線摘要及模型校準。
- 大量角色／關卡內容、專屬角色美術與完整音樂／音效、完整教學與無障礙／設定。
- 真人樂趣測試、完整經濟與長期養成平衡、8 小時 soak、實機背景 CPU／GPU／記憶體量測。
- 跨 OS 原生匯出、安裝／升級流程、正式發行／商店上架；未 push 或部署到外部服務。
- 桌面置頂／透明／焦點等依使用者決定延期，恢復前需有新的使用者指示。

## 驗證結果與重現

以下為 **2026-10-27 第一個可玩版本**的既有驗證，本次補交接文件沒有重跑遊戲測試。

| 驗證 | 結果與證據 |
|---|---|
| Domain | 67 項 PASS；600 秒模擬、15／30／60／120 FPS 同 tick 一致性、滿包、反應、交易、首通不重領、壞檔／schema 等；`evidence/domain-test.log` |
| UI／編輯器契約 | 32 項 PASS；真實 node 滑鼠操作、六頁、編隊／培養、天賦／選關、存檔、scene 文字／間距保留；`evidence/ui-test.log` |
| 字型／kit | 繁中缺字檢查及 `sync.sh --check dreamling-idle` PASS；`evidence/font-test.log` |
| Web | PASS；真實 canvas 滑鼠操作、編隊／培養、頁籤、IndexedDB 重啟恢復，1280×900／960×675；`evidence/web/report.json` |
| 文件 | 39 篇、30 系統、依賴 DAG、316 個本地連結、取樣索引通過；`docs/research/idle-game/evidence/document-check.json`，不是全系統功能驗收 |

遊戲測試從 repo 根目錄執行；建議獨立測試儲存位置：

```bash
env XDG_DATA_HOME=/tmp/dreamling-handoff-domain godot --headless --path prototypes/dreamling-idle --script res://tests/test_domain.gd
env XDG_DATA_HOME=/tmp/dreamling-handoff-ui godot --headless --path prototypes/dreamling-idle --script res://tests/test_ui.gd -- --qa
env XDG_DATA_HOME=/tmp/dreamling-handoff-font godot --headless --path prototypes/dreamling-idle --script res://tests/test_font.gd
bash prototypes/godot-kit/sync.sh --check dreamling-idle
```

瀏覽器驗證腳本 `tools/browser_check.mjs` 需本機 Playwright 與 Chromium，參數見檔頭。使用 `?qa=1` 重設獨立 QA 檔，`?qa=1&resume=1` 讀取該 QA 檔；一般遊玩不帶這些參數。上述測試不代表實機效能、長時間運作或真人樂趣通過。

## 重要檔案與啟動

| 路徑 | 用途 |
|---|---|
| [遊戲 README](prototypes/dreamling-idle/README.md) | 操作、建置、測試與可調整節點 |
| [Game Brief](prototypes/dreamling-idle/design/game-brief.md) | 本次切片範圍與驗證目標 |
| [主 scene](prototypes/dreamling-idle/scenes/main.tscn) | 直接在 Godot 編輯器開啟 |
| [資料表](prototypes/dreamling-idle/data/catalog.json) | 角色／關卡／裝備／天賦數值 |
| [模擬核心](prototypes/dreamling-idle/domain/game_model.gd) | 唯一戰鬥、獎勵與狀態權威 |
| [存檔](prototypes/dreamling-idle/domain/save_repository.gd) | Schema、驗證、備份與回復 |
| [驗證彙整](prototypes/dreamling-idle/evidence/validation.json) | 邏輯／介面／Web 測試證據 |
| [研究入口](docs/research/idle-game/README.md) | 原作證據、系統草案、完整 roadmap |
| [Session State](prototypes/dreamling-idle/production/session-state/active.md) | 此遊戲的簡短工作段落紀錄 |

```bash
godot --path prototypes/dreamling-idle
godot --editor --path prototypes/dreamling-idle
bash prototypes/godot-kit/tools/web/build_web.sh prototypes/dreamling-idle --zip-name dreamling-trails-playable
python3 -m http.server 8797 --bind 127.0.0.1 --directory prototypes/dreamling-idle/build/web
```

Web 遊玩網址：<http://127.0.0.1:8797/>（先確認伺服器有啟動；不要假設上一個 Agent 的程序仍存活）。`build/web/` 與 `build/dreamling-trails-playable.zip` 是本機可重建產物，沒有進 Git。

## 接手注意與下一步

1. 保持暫停，等使用者指示續作；先閱讀本檔、遊戲 README 與最新 `git log`／相關路徑狀態。
2. 續作後先實玩，確認前 15 分鐘養成節奏與畫面方向，再修戰鬥辨識及平衡。
3. 接著處理專屬素材；進化、工坊與離線應先選優先級，再定規格，不一次擴張全部系統。
4. Scene 是維護來源。`tools/build_scenes.gd` 只作一次性製作，正常啟動／匯入／測試不得重建；重產前保留人工修改。血條尺寸須等待 Theme minimum-size 更新後再保存，產生器已處理。
5. 使用 `addons/proto_kit/` 的同步副本，不直接修改副本。不要把其他 prototype 的整個 runtime 匯入成第二個模擬權威。

## Git 與環境交接

- `57d79ac` 已在 master 提交本次遊戲、研究及原型索引，共 275 檔；當時本次範圍乾淨。此後本次交接新增根目錄 `Progress.md`、修改 `AGENTS.md` 與交接入口，另作文件提交；實際是否尚有修改，以 `git status --short -- AGENTS.md Progress.md prototypes/dreamling-idle` 為準。
- 工作區仍有大量其他 prototype／美術／工具的未提交變更，不屬於本任務；不可 reset、還原、批次加入或順手提交。
- 原始參考 PNG／MP4 及衍生研究圖片由研究資料夾 `.gitignore` 排除，留在本機；另一台機器需另取得原始素材才能重現錄影抽幀。
- 前次 commit 成功，但 post-commit 提示 `git-lfs` 不在 PATH；尚未處理，沒有繞過或刪除 hook。
- Repo 為多引擎 generator source，提交自動檢查曾因無單一 code root 跳過 hardcoded-value／TODO-owner 掃描；沒有因此設定整個 repo 的 engine。遊戲自身測試結果如上。
- 沙箱內 `.git` 為唯讀，Git 寫入需工具權限；Xvfb／Chromium 圖形測試也曾需沙箱外執行。不要把環境限制寫成遊戲已失效，也不要跳過必要授權。
