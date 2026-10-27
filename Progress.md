# 進度與 Agent 交接

## 萬事屋吐槽 ADV · debt-commission（2026-10-27）

- **目前工作**：`prototypes/debt-commission`，分支 `master`；實作基準為 `0a65639`，目前最新提交是合併其他專案的 `7b6964a`。本輪修改尚未 commit 或 push。使用者已想到第一篇短篇，會在開發與測試後提供，再一起試寫並完善協作流程；目前沒有替作者編寫新故事。
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
