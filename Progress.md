# 進度與 Agent 交接

更新日期：2026-10-27（Asia/Taipei）。目前專案：**夢靈遠行 · Dreamling Trails**，位置 `prototypes/dreamling-idle`。分支 `master`；遊戲實作基準 commit **`57d79ac`**（`feat(dreamling-idle): add first playable idle RPG and system research`）。最新提交另以 `git log -1 --oneline` 確認。

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
