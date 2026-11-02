# 萬事屋吐槽 ADV · debt-commission：里程碑與歷史

從 PROGRESS.md 移出的較早紀錄與里程碑彙整（2026-11-02 起），新的在上；內容保留原文。目前進度見 [PROGRESS.md](PROGRESS.md)。

## 2026-11-01｜統一本機預覽入口（repo 根目錄 preview/，與 godot-kit 共用）

- 專案／分支：repo 根目錄預覽工作台、debt-commission、godot-kit／master；基準 `fad04133`。使用者要求集中預覽及故事編輯器開啟方式。本輪未 commit／push／公開部署，保留其他專案與前輪 VFX 尚未提交的變更；未新增或改寫故事。
- 已完成：新增 `preview/`，Windows 可雙擊 `start.bat`；或在 repo 根目錄執行 `python3 preview/start.py`，開 `http://127.0.0.1:8000/preview/`。首頁通往故事編輯器與特效試映室，只有一個本機服務；原故事網址 `/tools/story_editor/`、同源草稿空間與 project_server 的存檔／試玩保護保留。首頁會提示找不到 Godot 或特效包未建置，缺包時啟動器會嘗試建置；失敗仍可開故事編輯器。支援 `--godot`、`--port` 與 `--no-open`，連接埠改變時瀏覽器草稿空間也會改變。
- 已更新：根 README、`preview/README.md`、debt 的 README／STORY-EDITOR／session-state、kit showcase README，集中啟動與操作連結。預覽來源仍由各專案維護，不複製一份編輯器或素材。
- 本輪 L2：`python3 preview/test_preview.py -v` **9 tests PASS**；使用記憶體 HTTP handler 驗證真實故事頁／capabilities／實際 VFX HTML、data、PNG 與 Godot HTML；以暫存故事及模擬驗證器檢查存檔／舊 hash 衝突，並檢查無 token、路徑／symlink／Host 保護、缺包及啟動流程。`node --check preview/preview.js`、`sh -n preview/start.sh`、Python 編譯與文件連結檢查 PASS。未修改 Godot scene，未重跑遊戲／VFX suite；前輪結果見下一 checkpoint。
- 未驗範圍：實際 `python3 preview/start.py --no-open` 在沙箱建立 socket 時得到 `Operation not permitted`，服務未常駐，瀏覽器／GPU／Windows 雙擊與實際 Godot 圖形試玩均未驗。本輪 HTTP 測試沒有監聽 socket，存檔測試的 Godot 驗證由測試替身處理；不把它寫成瀏覽器或實際 Godot 驗證 PASS。
- 下一步：在使用者的普通終端機或 Windows 雙擊啟動，檢查故事開啟／場景試玩與特效畫面；若 Godot 不在 PATH，依 `preview/README.md` 用 `--godot` 指定 4.7 執行檔及 Web 範本。當時誤以為短篇構想未提供；現行 HEAD 已包含桂短篇，見上方更正。前輪 Three 版本差異與 GPU 驗收限制不變。

## 跨專案審查改善（2026-10-29～30）

| 專案 | 已完成的程式／文件工作 | 仍待外部驗收／延期 |
|---|---|---|
| debt-commission | 短篇驗收文件、調查選取／版面拆分、離屏觸控修正、Web 候選 | 作者故事內容與完整短篇真人／手機驗收；不再為拆分而全面改寫 main |

- 已完成（debt 部分）：debt 的完整短篇驗收與漸進拆分邊界。重要入口 `docs/SHORT-STORY-ACCEPTANCE.md`。
- 部分／未完成（debt 部分）：debt 已抽出熱區選取，完整調查呈現控制仍待後續功能需求；故事內容等作者提供；真人／真機驗收待測。
- debt 續作：新增 investigation_picker，集中熱區命中／優先序；main 保留遮擋與生命週期。L2 investigation_picker／investigation／phase3_ui PASS（`/tmp/godot-tests.ooX4GH`）。Phase4 舊測試寫死 12 個故事，因現有第 13 個故事失敗；已允許擴充並保留基線順序／標記檢查，Phase4 單獨重跑 PASS（`/tmp/godot-tests.UGlECn`）。匯入及測試仍有 MCP TCP／資源清理訊息；未見 SCRIPT ERROR／Parse Error。Web 與真人手機未重驗。
- debt 第二步：新增 investigation_layout，集中背景覆蓋、anchor／offset 與兩軸拖曳邊界；原 pan 保存／還原及角色生命週期保留。L2 investigation_layout／phase3_ui／phase4_ui 全部 PASS（`/tmp/godot-tests.fIuGGD`）；未見 SCRIPT ERROR／Parse Error，仍有 MCP TCP／匯入 RID 清理訊息。未修改 scene／schema，Web 與真人手機未重驗。
- 2026-10-30 debt 邊界修正：第一章嘴角 art_region 完全離開畫面仍能被觸控擴張選取，新增回歸先重現兩項 FAIL（`/tmp/godot-tests.FvVWlR`）；修正為完全不相交時隱藏並略過隱藏熱區，移回可恢復。L2 search_cast／phase3_ui PASS（`/tmp/godot-tests.8FaZ2e`）；單元初次因 _init 視窗未顯示而失敗，改第一幀後執行，單獨重跑 investigation_picker PASS（`/tmp/debt-picker-visibility-final.log`）。最終 log 無 SCRIPT ERROR／Parse Error；未改 scene／schema，Web 與真機未重驗。
- 2026-10-30 debt Web：已重建 build/web 並封裝 `build/debt-commission-web-candidate-20261030.zip`（79,199,602 bytes；SHA-256 `dbc585c0dcd62840e07349e05be52889be018728e104f2a348097ba5bbc20598`）。兩個調查模組／main 已入包，tests／tools 排除、IDBFS 及 ZIP 檢查 PASS；來源／產物雜湊見 `production/qa/web-candidate-2026-10-30.json`。本輪未重跑源碼測試，沿用上一輪證據；本包 Chromium／IndexedDB／真機未驗（沙箱禁止 socket），未上傳。

## 2026-10-27～10-29（歷史）

### 2026-10-29：依作者 prompt 重繪桂與去背

- **需求／結果**：作者提供另一故事使用的 MS Paint 鼠繪、粗糙像素風提示詞，要求依此生成並去背。使用 imagegen 以既有桂姿勢圖、遊戲銀時／神樂立繪及桂 normal 參考重繪，保留雙手舉在頭側與認真表情。`stories/katsura_dog_ears/art/katsura_dog_ears_mouse_v2.png` 為 941×1672 RGBA 透明背景，SHA-256 `4c55ae6b9e4820e29182aa8dbc08008fcb8f917f96d81699c53e108423b2d743`，與生成原圖一致，沒有額外影像後處理；舊圖 `katsura_dog_ears.png` 保留。用圖像工具直接輸出透明背景，角色上的白色筆觸保留。
- **接入／驗證**：故事包 catalog 基礎及 serious 圖改用新版；以 Godot 保存 `scenes/katsura.tscn` 的 Art 預覽，維持既有取景、節點數和 owner。遊戲目錄用 `python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import --quit` 完成匯入；以同協作工具執行非headless `--resolution 1280x720 --script res://tests/test_katsura_dog_ears.gd -- --shots=/private/tmp/debt-katsura-mouse-v2` PASSED，檢查兩句停頓、QTE早／晚／成功、牌子、新八漫畫與立繪載入；人工查看 opening／timing 截圖確認透明背景可見場景。匯入退出仍有既有 RID 資源清理警告。
- **待辦**：作者試看新版風格；真人手機／手感與重新Web匯出未執行。只改本作品圖片及取景，不改 story JSON 版號、人格或記憶。未commit／push，保留其他專案未提交修改。


### 2026-10-29：桂的手繪立繪候選

- **使用者決定／生成**：先前提供 opt image 提示詞，作者後續明確回覆「好 那就開始生成」，已依 normal／現有新八畫風／手勢照片／ego 四張參考用 imagegen 生成一張桂的手繪姿勢立繪。`stories/katsura_dog_ears/art/katsura_dog_ears.png` 為原圖 RGBA 941×1672、透明背景，SHA-256 `8fb9d47ddf1794fbe9354c65bfcaa4cfbb09a0ec64d1fe039281247ca2224f6f`，與生成輸出一致。角色外觀、手勢與最終畫風待作者試看。
- **接入**：本作品 catalog 基礎圖與 serious 表情使用候選；scenes/katsura.tscn 的 Art 顯示圖並保留可編輯取景，PosePlaceholder 隱藏。實測QTE圓環曾遮住桂的臉，已將 Art 左移160本地單位，重新檢視；不改全域舞台。移除故事中過時的「立繪待匯入」提示，check_story重算版本 `s-d2fd832e6028`；已存在該原型的舊存檔可能因版本變動需重開始。
- **本輪 L2 驗證**：`python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import --quit` 通過；`python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/story_editor/check_story.gd -- stories/katsura_dog_ears/dog_ears_story.json --write` OK；同工具執行非headless `--resolution 1280x720 --script res://tests/test_katsura_dog_ears.gd -- --shots=/private/tmp/debt-katsura-generated-final` PASSED，涵蓋過早／過晚／未按／成功、表情、真實QTE點擊、漫畫吐槽及新立繪實際載入。已人工檢視 opening／timing／retort 截圖。`node /private/tmp/debt-katsura-editor-smoke.mjs` 以Chrome通過編輯器graph及立繪預覽載入。scene以Godot保存，pack前後節點數與owner一致。Godot匯入退出仍有既有RID／資源清理訊息。
- **尚待／工作區**：等待作者對候選圖及節奏的回饋；真人手機手感、正式美術驗收及重新Web匯出尚未執行。未改完整角色人格與記憶；未commit／push，保留其他專案的修改。


### 2026-10-29：首篇極短篇「不是頭痛，是桂」

- **使用者已決定**：桂雙手如參考圖放在頭兩側；伊莉莎白舉牌「頭痛？」、神樂「狗勾？」；阿銀改成「你腦袋被撞到嗎」。桂不能一次說完，先「頭痛賈奈。」→ 停頓 → 一本正經、理直氣壯且認真地說「咖紫拉打。」；之後玩家抓時機接新八「到底是怎樣啦！！那你手舉個屁啊！！！」。作者選擇 opt image 提示詞，未授權直接生成圖片。
- **完成／部分完成**：新增獨立 `stories/katsura_dog_ears/` graph故事包（7節點、1結尾，version `s-4dcbc3f6be27`），編輯器可選及編輯，不覆寫舊第一章。兩句間 freeze=0.55 秒，第二句顯示完啟動現有 QTE（重疊0.75秒、誤差±0.18秒、未按1.3秒），過早／過晚可重試，成功播放新八漫畫吐槽。回合及單句可指定合法 expression，保持 serious，不再固定 annoyed。桂與本篇伊莉莎白取景都存成可編輯 scene；伊莉莎白牌子已調整至完整可見。
- **美術／內容界線**：桂姿勢圖尚缺，以 PosePlaceholder 明示待補，不能稱為視覺成品。已提供 `stories/katsura_dog_ears/OPT-IMAGE-PROMPT.md`，要求雙手完整、一張認真姿勢、無真狗耳／賣萌；等作者交圖再檢查取景、隱藏佔位。操作失敗提示及具體時限是原型提案，尚未真人手感驗收。未建立桂／伊莉莎白完整人格、未新增記憶。v0.1／v0.2 場景稿及原始姿勢參考在 docs/story-telling-game/stories。
- **本次 L2 驗證**：遊戲目錄用 `python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/story_editor/check_story.gd -- stories/katsura_dog_ears/dog_ears_story.json --write` 通過；依同方式執行 `test_katsura_dog_ears.gd`、`test_phase4_rounds_ui.gd` 均 PASSED。涵蓋早按、晚按、未按、成功至結尾、表情覆寫與非法值拒絕、實際shell保留牌子／serious及實際QTE點擊。新scene皆用Godot保存並通過headless匯入；初次新測試曾有繼承方法簽章及漫畫首幀斷言問題，修正後通過。
- **畫面／編輯器證據**：最終用非headless `--resolution 1280x720 --script res://tests/test_katsura_dog_ears.gd -- --shots=/private/tmp/debt-katsura-story-evidence/game-final` 再跑通過，已檢視opening與retort截圖，牌子及漫畫字完整可讀。`node /private/tmp/debt-katsura-editor-smoke.mjs` 通過pack選取、graph可編輯、零結構問題、修訂台詞／分句、catalog、試玩入口與原檔不變；報告及editor截圖在 `/private/tmp/debt-katsura-story-evidence/`。瀏覽器檢查早於最後僅本篇伊莉莎白取景調整；未重新測Web遊戲或完整suite。Godot有既有CA、MCP占埠及退出資源清理警告，未見最終script/parse error。
- **工作區／下一步**：master，記錄時最新HEAD `1677ee8`（可能包含其他session提交，以git log查核）；本次未commit／push。保留其他原型修改。等待作者opt image產圖，完成桂手勢視覺、實際試讀停頓與玩家手感；不擅自擴成長篇或加入新分支台詞。README／STORY-EDITOR／IMPLEMENTATION／HANDOFF／active／STATUS已同步。


- **目前工作／交接**：`prototypes/debt-commission`，分支 `master`；2026-10-28 作者要出門，要求交接並 commit。已完成本輪人格協作與編輯器整合；本次提交前 HEAD 為其他原型的 `6e9fb85`，先前遊戲基準為 `21604e3`。提交包含此段落對應程式、測試、資料及文件，完成後停止；最新提交以 `git log -1` 查核，沒有 push。完整交接見 [HANDOFF.md](docs/HANDOFF.md)。第一篇極短篇仍等作者提供，沒有代寫。
- **已完成**：節點編輯器可從選定場景試玩當下的未存稿或唯讀故事，調整旗標與線索；使用作品自己的素材／外觀及獨立暫存遊戲資料。新場景加入分支時會替換預設佔位結尾，編輯器與遊戲驗證會拒絕終止步驟之後不會執行的內容。
- **本次 UI／手感**：預設改為 16:9 橫向，閱讀與選單字級縮小；LOG／AUTO／SKIP／MENU 按鈕依原圖比例呈現。舞台站位獨立於閱讀框，對話可遮住立繪；一般閱讀框固定，長台詞在框內依文字行分頁，調查或回合控制可依內容增加面板高度。橫向調查可上下及左右拖背景，並保存垂直取景。標題、選項、目錄與案件檔已調整橫向版面。
- **編輯器與手感**：`scenes/stage.tscn` 的左／中／右站位有實際角色預覽，角色 `Art` 可單獨調整；網頁編輯器的 `char` 可拖曳或按按鈕選左／中／右。閱讀工具列有不影響觸控範圍的按壓回饋；減少畫面效果設定同時作用於按鈕、角色動作及舞台淡入淡出。
- **本次橫向驗證**：45 組 headless 測試通過（遊戲目錄下 `env GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot TEST_TIMEOUT=120 python3 tools/story_editor/run_coordinated.py bash ../godot-kit/tools/run_tests.sh .`，紀錄 `godot-tests.pqtoNJ/`）；最後收緊選項版面後重跑 `choices`、`phase3_ui`、`phase4_rounds_ui`、`landscape_reading`，均通過（`godot-tests.9QRYjq/`）。`tools/text_fit_audit.gd` 以實際視窗及最大字級，在 1136×640 和 1024×768 各檢查 33 個畫面，均無裁字；已確認限時四選項真的進入選擇畫面且完整落在捲動區（`/private/tmp/debt-landscape-fit-small-final2/`、`/private/tmp/debt-landscape-fit-4x3-final2/`）。長台詞兩頁與固定立繪的實際畫面在 `/private/tmp/debt-landscape-reading-v3/`。本機編輯器服務 16 項測試通過。
- **Web 驗證**：重新匯出後，Chrome 模擬觸控的 Phase 3 調查、四個限時選項、選單暫停與存讀檔共 6 組通過；POV 與導演選項在 800×450、640×360 各 5 組通過，並檢查選項完整落在可見範圍。報告為 `test-results/phase3-report.json`、`test-results/choices-browser-report.json`，兩者均無瀏覽器或遊戲 runtime error。
- **前次直式 UI 驗證（歷史紀錄）**：44 組 headless 測試通過（`godot-tests.Yzn9Hx/`）；末次按鈕調整後 `reading_feel`、`stage_scene` 通過（`godot-tests.HdatEK/`）。320×568、390×844 各檢查 33 個最大字體畫面，均 0 項截字（`/private/tmp/debt-text-fit-320/`、`/private/tmp/debt-text-fit-390/`）；瀏覽器站位拖曳、未存稿試玩與三結局通過（`/private/tmp/debt-preview-position-final/`）。這些是橫向改版以前的證據。
- **前一輪驗證**：同日遊戲本體先前 43 組測試、本機服務 16 項、編輯器核心、原有瀏覽器 smoke 與作品包 smoke 通過；橫向改版後只重跑了其中的本機服務測試，編輯器核心與原有 smoke 未重跑。Godot headless 匯入／匯出在離開編輯器時仍報資源／RID 清理警告，匯出成功並通過瀏覽器測試。
- **已知限制**：場景試玩不會還原前面場景的背景、角色、音樂，或進行中的調查／吐槽回合；必要時從較早場景試玩。複雜的調查、吐槽與結算步驟仍有 JSON 編輯區；複製子圖、30 節點作者驗收、橫向版真人手機試玩與正式音效／文本仍未完成，依第一篇故事實際需求再安排。
- **重要文件**：[專案 README](README.md)、[編輯器操作](docs/STORY-EDITOR.md)、[商業級待辦](docs/ROADMAP-COMMERCIAL.md)、[此專案 session-state](production/session-state/active.md)。
- **工作區**：保留原有其他修改（根目錄 `AGENTS.md`、`CLAUDE.md` 與 taskbar-hero 相關 AGENTS）；本輪另有 debt-commission 程式、測試與文件變更。`godot-kit/sync.sh --check debt-commission` 報既有 drift，本輪未改共用模組副本。
- **下一步**：等使用者分享短篇構想，一起拆出場景／分支，再以編輯器寫作、存檔和試玩；依實際卡點調整工具與流程。

- **同日美術提示詞修訂**：作者提供 `stories/katsura_dog_ears/art/reference/katsura/normal.jpeg`、`ego.jpeg`、`happy.jpeg`，已實際檢視並與本作銀時／新八立繪對照。OPT-IMAGE-PROMPT 改為四圖分工：normal固定角色與灰羽織／藍和服／黃褐腰帶，現有新八指定粗黑線乾筆筆觸及帶留白色塊，照片固定雙手姿勢，ego指定認真發言神態；happy的閉眼紅暈本輪不用。補上可直接複製的完整提示詞、局部修正詞及混角時兩階段生成做法。僅文件，未生成圖／未改遊戲，驗證附圖連結存在，不跑runtime測試；未commit／push。

### 2026-10-28：出門交接與編輯器人格參考

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

- **需求／結果**：使用者準備和 agent、編輯器合作一篇極短篇，先要求驗證 `docs/story-telling-game` conversation 中的能力。核對 base 三份與 v2 四份紀錄，對照第一方資料、runtime、編輯器與寫作指引，產出 [核對報告](../../docs/story-telling-game/CONVERSATION-AUDIT-2026-10-28.md)。結論不是全部完成：短篇播放、分支、演出與編輯器可用；CPC 人格 schema／三角色完整資料、記憶／知識／關係模型與檢索、人格一致性 QA、Prompt Assembler、內建 AI Writer／Chat 未落實。現有角色 profile、tone、history 與章節 carry 不能等同完整人格／記憶系統。
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
