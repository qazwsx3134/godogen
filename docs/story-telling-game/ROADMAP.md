# 直式吐槽視覺小說 Roadmap

更新：2026-09-23。狀態：V1 規格依 [gintama0923](../gintama-like/new/gintama0923.md) 定案；Godot 4.7 Web 工具鏈、劇本執行器與驗證流程已由 [debt-commission 原型](../../prototypes/debt-commission/README.md) 建立，V1 從 Phase 0 開始。

目標：用 Godot 做一款手機直立式的銀魂同人視覺小說，先提供瀏覽器試玩。核心玩法改編自逆轉裁判的詰問：把「找矛盾、出示證物」換成「找槽點、吐槽」。玩家扮演新八，在一群裝傻的人之中負責吐槽，劇情才能往下走。

依據：[gintama0923](../gintama-like/new/gintama0923.md)。前半（第 1–278 行）是逆轉裁判式通用規格：畫面分層、對話框、懸浮按鈕、選單、調查、存讀檔；第 280 行起改為銀魂吐槽版，未提到的部分沿用前半。V1 以第 432 行「給遊戲 AI 的 Prompt（銀魂吐槽版）」為主規格，開發順序改寫自第 257 行的分階段 Prompt。故事產出沿用 [STORY_WORKFLOW.md](STORY_WORKFLOW.md) 的共同編劇與試讀方法。

## V1 規格

| 項目 | V1 基準 |
| --- | --- |
| 平台與交付 | Godot 4.7 stable、GDScript、Compatibility renderer、單執行緒 Web 匯出；手機瀏覽器直立試玩，桌機保留直式遊戲區 |
| 畫面 | 9:16 直立，基準 1080×1920，依裝置等比縮放；處理瀏海、底部手勢列等 Safe Area |
| 分層（下到上） | 全螢幕背景 → 人物立繪（左／中／右）→ 特效 → 對話框 → 懸浮按鈕 → 彈出視窗 |
| 對話框 | 底部約佔 28%；左上名牌依角色換色；逐字顯示、最多三行、速度可調；右下閃爍 ▼；下方快捷列 LOG／AUTO／SKIP／素材 |
| 操作 | 點任一處：打字中補完整句，打完進下一句；上滑開對話紀錄；長按隱藏全部 UI，再點恢復 |
| 懸浮按鈕 | 右上選單 (≡) 與存檔 (S)；可拖曳，放開吸附左右邊緣；閒置 3 秒變 40% 透明；自動避開對話框；長按 (S) 快速存檔並冒出「已存檔」 |
| 選單 | 點 (≡) 背景變暗模糊，展開存檔、讀檔、吐槽素材、人物檔案、對話紀錄、設定、回標題；點背景關閉 |
| 角色 | 玩家：新八（吐槽役）。裝傻：銀時、神樂。定春只會汪；登勢主持「家庭會議」。台詞原創，符合角色個性，不照抄原作 |
| 核心循環 | 劇情 → 調查（收集吐槽素材）→ 裝傻回合（聽下去／吐槽）→ 章節結算 |
| 劇本 | JSON，與程式分離；新增章節不改程式 |
| 美術 | 先用 placeholder：漸層背景＋地點名，剪影立繪＋角色名＋表情文字；素材路徑集中在一個設定檔，之後直接換圖 |

### 吐槽系統

| 逆轉裁判 | V1 | 規則 |
| --- | --- | --- |
| 證言 | 裝傻發言 | 角色輪流說多句發言，橘色字，◀ ▶ 切換上一句／下一句；每句選「聽下去」或「吐槽！」 |
| 追問 | 聽下去 | 對方補充內容，可能揭露新槽點或解鎖新素材 |
| 出示證物 | 吐槽選擇 | 3–4 個吐槽選項，限時 8 秒；部分選項需要特定素材才出現；可打開素材清單當根據 |
| 抓到矛盾 | perfect | 全螢幕震動＋集中線＋大字泡泡「你在說什麼啊！！」cut-in，吐槽力大量增加 |
| — | weak | 小型泡泡，吐槽力少量增加 |
| — | fail（冷場） | 畫面變灰停格、烏鴉叫聲、「……」，眼鏡耐久 −1 |
| — | hidden | 選「……（放棄吐槽）」，解鎖隱藏劇情 |
| 生命值 | 眼鏡耐久 | 5 格；歸零 Game Over，畫面為碎掉的眼鏡與「新八的本體已損毀」，從最近檢查點重來 |
| — | 吐槽力 | 集滿可發動「超必殺吐槽」，一次戳破整段發言的所有槽點 |
| — | QTE 槽點 | 發言結束後出現縮圈，縮到剛好時點擊為 perfect，太早或太晚為 fail |
| — | 連續裝傻 | 多個角色接連裝傻；每成功一次時限縮短，全部接住觸發「吐槽連擊」演出 |
| — | 第四面牆 | 槽點是 UI 本身，例如角色抱怨懸浮按鈕擋臉、對話框錯字、敏感字被消音條蓋住；玩家點該 UI 元素吐槽 |
| 助手提示 | 神樂提示 | 同一槽點失敗 3 次，神樂給出毒舌提示 |
| 判決 | 章節結算 | 吐槽成功數、PERFECT 數、最高連擊、冷場次數、隱藏裝傻數 → 評價 S／A／B／C |

### 必要畫面

標題（新遊戲、繼續、章節選擇、設定）、主對話、選單展開、選項分支（2–4 個大按鈕，可設定需要某素材才出現）、調查模式、裝傻發言、吐槽選擇、吐槽成功演出、冷場、Game Over、吐槽素材／人物檔案、存讀檔、對話紀錄、設定、章節結算。版面以 [gintama0923](../gintama-like/new/gintama0923.md) 的 ASCII 草圖為準：通用畫面取前半「二、畫面設計」，裝傻發言、吐槽選擇、成功演出、冷場、吐槽素材與章節結算取第 280 行後的銀魂版，取代對應的法庭與證物畫面。

- **調查模式：** 場景上有可點擊熱區，查過的打勾，取得吐槽素材；底部為調查／移動／對話／素材。「移動」列出可前往地點，「對話」列出在場角色可詢問的話題。
- **素材／人物檔案：** 4 欄格狀清單，下方顯示所選項目的大圖與說明；「拿來吐槽」只在可以使用的時機出現。
- **存讀檔：** 3 頁、每頁 6 格，顯示截圖縮圖、章節名與時間；另有自動存檔與快速存檔欄位。
- **設定：** 文字速度、自動播放速度、BGM／音效音量。

### 劇本指令

至少包含：`bg`、`char`（角色 ID／表情／位置）、`say`、`choice`、`flag`、`goto`、`item`（取得素材）、`investigate`、`boke_round`（`lines`、`listen`、`tsukkomi.options`、`result`、`require`、`timer`、`qte`）、`shake`、`flash`、`cutin`、`freeze`、`bgm`、`se`。

劇本沿用現有 StoryRunner 的節點結構：根資料含 `id`、`version`、`entry`、`initial_flags`、`nodes`，每個節點有 `steps` 與選擇性 `next`；上述指令是 `steps` 內的 op。markdown 中的扁平 `type` 陣列是指令示意，不當成檔案結構。指令名稱採 markdown 版本：`flag`、`se`、`char` 分別承擔現有的 `set_flag`、`sound` 與 `show`／`hide`／`expression`；`condition`、`end` 保留。

### 存檔

旗標、素材、眼鏡耐久、吐槽力、劇本位置都存入本機存檔。每次換場景與每個裝傻回合開始時自動存檔。存檔帶劇本版本與穩定節點 ID；讀檔從最近成功的檢查點恢復，台詞可以重讀，選擇與吐槽結果不能重複套用。

## V1 Demo：第一章「萬事屋冰箱草莓牛奶失竊事件」

| 段落 | 內容 |
| --- | --- |
| 開場 | 新八發現冰箱裡他買的草莓牛奶不見了 |
| 調查萬事屋 | 取得素材：空牛奶瓶、銀時嘴角的白色痕跡、神樂的醋昆布包裝、定春的腳印 |
| 家庭會議 第一回合 | 銀時裝傻 4 句，其中 2 句可吐槽 |
| 家庭會議 第二回合 | 神樂裝傻 3 句，並試圖把罪推給定春 |
| 家庭會議 第三回合 | 銀時＋神樂連續裝傻（連擊關卡） |
| 必備槽點 | 至少一個第四面牆槽點、一個 QTE 槽點、一個隱藏「放棄吐槽」路線 |
| 結局 | 真相大白，最後再出現一個讓新八崩潰的反轉 |
| 篇幅 | 約 80–100 句，節奏快，每 3–5 句一個笑點 |

劇本先依 [STORY_WORKFLOW.md](STORY_WORKFLOW.md) 共同編劇，作者確認文字版後再轉成 JSON。[missing-strawberry-milk](../../prototypes/missing-strawberry-milk/README.md) 已有同一事件的文字雛形與詢問對象，可作為素材；台詞依裝傻回合與四種吐槽結果重新編排。

## 現有基礎

V1 在 `prototypes/debt-commission/` 這個 Godot 專案內改造。改造前先 commit 目前的第一場原型，作為可回溯的基準。

| 類別 | 現有內容 | V1 做法 |
| --- | --- | --- |
| Web 工具鏈 | 4.7 stable、相符官方單執行緒 Web 範本、`fetch_web_templates.py`／`build_web.sh`／`serve_web.sh`、中文字型 | 沿用；匯出排除 MCP addon |
| StoryRunner | JSON 節點、資料與引用檢查、flags／condition／goto、跳轉循環保護、snapshot／restore 與版本檢查 | 沿用並擴充 V1 指令；故事 `version` 升版 |
| 閱讀 UI | 逐字補完／前進、回顧、音效開關、`user://` 閱讀點自動存檔與續讀 | 改為 VN 分層版面；存檔擴充為多槽與縮圖 |
| 驗證 | `tests/test_story.gd`、`tests/test_stage.gd`、`?qa=1` 唯讀 `window.__debtQA`、Playwright `browser_check.mjs` | 沿用；QA 欄位加入吐槽狀態，瀏覽器路線改為 V1 章節 |
| 舞台演出 | `story_stage.gd` 萬事屋俯視室內與繞桌走位；`actor_doll.gd` 地圖 SD 與說話立繪 | 俯視舞台與走位不帶入 V1；立繪模式可暫代 placeholder，最終依 V1 規格改為剪影＋名字＋表情文字 |
| 故事 | 《請幫我向你老闆討債》第一場 51 句核准稿、兩選項分支與後段回扣（[核准文本](stories/002-debt-commission-draft-v0.1.md)） | 保留為後續章節候選，改寫成含裝傻回合的版本 |

設計尺寸由 720×1280 改為 1080×1920，同為 9:16，於 Phase 1 調整；現有 UI 數值需要同步放大。

## 開發階段

每個 Phase 都保留可在瀏覽器開啟的 Web 匯出版本，並通過引擎測試與 `browser_check`。

| 階段 | 玩家或作者拿到的成果 | 系統工作 | 通過條件 |
| --- | --- | --- | --- |
| **Phase 0：專案轉換與工具** | 可連上 Godot MCP 的開發環境；舊原型已保存 | commit 目前原型；在 Project Settings 啟用 Godot MCP Toolkit，產生 `.mcp.json` 並從專案根連線；Web 匯出 `exclude_filter` 加入 `addons/godot_mcp_toolkit/*`；準備有畫面的編輯器（WSLg 或 Windows 版 Godot） | MCP 可讀場景樹並截圖；Web 匯出不含 addon 檔案；既有測試與 `browser_check` 仍通過 |
| **Phase 1：直立框架與懸浮按鈕** | 1080×1920 直立畫面，placeholder 背景與立繪，可點擊讀完一段對話 | 六層結構、Safe Area、對話框（28%、名牌、逐字、▼）、點擊補完／前進；懸浮按鈕拖曳、吸邊、閒置透明、避開對話框、長按 (S) 提示；長按隱藏 UI；上滑開紀錄 | 390×844、320×568 與更長手機比例都不遮擋文字與按鈕；按鈕操作不誤觸推進劇情；觸控與滑鼠皆可玩 |
| **Phase 2：劇本引擎** | 作者改 JSON 即可換背景、立繪、台詞與分支 | `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item`；選項 `require`；素材路徑設定檔；用 10 句測試劇本驗證 | 缺角色、缺素材、跳到不存在節點、未知指令在啟動前指出節點位置；未持有素材時需要它的選項不出現 |
| **Phase 3：調查與檔案** | 可以在萬事屋點熱區、找到素材、查看素材與人物檔案 | `investigate` 熱區、查過打勾、移動地點、對話話題；素材／人物檔案 4 欄清單與大圖說明 | 取得 4 項素材；查過的熱區不重複給素材；調查 → 對話 → 調查能來回切換，讀檔後狀態一致 |
| **Phase 4：吐槽系統** | 能玩一整個裝傻回合，感受 perfect／weak／冷場／隱藏路線 | `boke_round`：裝傻發言切換、聽下去、8 秒吐槽選擇、素材條件；四種結果；眼鏡耐久與 Game Over；吐槽力與超必殺；QTE 縮圈；連續裝傻與連擊；第四面牆 UI 槽點；3 次失敗提示；`shake`、`flash`、`cutin`、`freeze`、`bgm`、`se` 演出 | 四種結果與 QTE、連擊、第四面牆、超必殺各自可觸發；眼鏡歸零回到最近檢查點；cut-in 約 0.8 秒且不吞掉下一次點擊；引擎測試涵蓋結果判定與數值 |
| **Phase 5：存讀檔、設定與第一章** | 完整第一章，從標題玩到章節結算 | 3 頁 × 6 格存讀檔與截圖縮圖、自動存檔、快速存檔；對話紀錄；設定；標題與章節選擇；章節結算；放入 80–100 句第一章 | 主線、隱藏路線、Game Over 重來都能到結尾或回到檢查點；存讀檔後旗標、素材、眼鏡、吐槽力一致且不重複套用；同一瀏覽器重開可繼續；真人手機試玩一次 |

Phase 1 與 Phase 2 可並行，兩者只在對話框顯示介面交會。Phase 3 與 Phase 4 都依賴 Phase 2 的指令執行。第一章文字稿可在 Phase 1 起同步共同編劇，Phase 4 前需要定稿第一回合，才能用真實台詞調整計時與笑點節奏。

## 驗證

- **引擎測試：** headless 執行 `tests/`，涵蓋劇本驗證、分支、吐槽結果、眼鏡與吐槽力數值、連擊、存讀檔還原。
- **瀏覽器：** `browser_check.mjs` 以真實 canvas 點擊與觸控走完各路線；Phase 1 起補上拖曳、長按、上滑手勢；桌機、390×844 觸控模擬與 320×568 窄畫面各跑一次。
- **Godot MCP：** 在編輯器內快速調版面、拖曳按鈕、cut-in 時機與錯誤輸出，是開發輔助；Web 匯出版的驗收仍以瀏覽器檢查為準。
- **真人試玩：** Android Chrome、iOS Safari 實機；確認笑點、吐槽時限是否太緊、懸浮按鈕是否擋畫面。未測到的平台如實標示。

## 開發工具：Godot MCP Toolkit

現況：`prototypes/debt-commission/addons/godot_mcp_toolkit/` 已放入 v1.0.2（支援 Godot 4.2+，測到 4.7.0）；`project.godot` 尚未啟用此 plugin，專案根沒有 `.mcp.json`，Claude Code 目前也沒有註冊 Godot 相關 MCP server。本機 Node 24 符合 bridge 需要的 Node 22 以上。`godot --help`（4.7）未列出 MCP 選項，只有 LSP 與 DAP 連接埠；目前找到的 MCP 是這個 toolkit：plugin 在編輯器內開 WebSocket，再由 `npx -y @npgamedev/godot-mcp-server` 橋接給 Claude Code。

結論：值得加入，放在 Phase 0 設定。V1 大量是 UI 版面與觸控手感，MCP 可以直接開遊戲、模擬輸入、截圖與讀 console，縮短調整迴圈。

| 用途 | 工具 |
| --- | --- |
| 看場景與節點 | `scene_get_tree`、`script_read`、`asset_list` |
| 建 UI 分層與調屬性 | `scene_create_node`、`node_set_property`（有 UndoRedo） |
| 實跑與操作 | `game_start` 後啟用 runtime 工具群，`input_simulate` 模擬點擊、拖曳 |
| 看畫面與錯誤 | `editor_screenshot`、`editor_get_console`、`script_check` |

限制：

- `game_start` 與截圖在 `--headless` 編輯器回傳 `HEADLESS_UNSUPPORTED`，需要有畫面的編輯器（WSLg 或 Windows 版 Godot）。
- MCP 操作的是編輯器與桌面執行，不是 Web 匯出版；觸控、音效啟動與瀏覽器存檔仍需 `browser_check` 與實機確認。
- `input_simulate` 只有 `mouse_button`／`mouse_motion` 等滑鼠與按鍵事件，沒有 `InputEventScreenTouch`／`ScreenDrag`；長按、上滑、拖曳若以觸控事件實作，要靠 `browser_check` 的觸控模擬驗證。
- 目前 `script_export_mode=2` 會把 addon 腳本編成 `.gdc` 帶進 Web 匯出（不會執行，但增加檔案），所以 `exclude_filter` 要排除 `addons/godot_mcp_toolkit/*`。
- 啟用與停用 plugin 透過 Project Settings → Plugins，不直接手改 `project.godot`；需要只讀時用 dock 開關或 `GODOT_MCP_READ_ONLY=1`。
- 專案內附的 `CompanionSkills/godot-mcp-toolkit` 說明工具選擇與流程，連線後可參考。

## Godot 瀏覽器交付

- 以「點擊開始」作為音效啟動入口；測試切到其他分頁再回來後，BGM 與演出狀態。
- 瀏覽器存檔受網站儲存政策影響，受限模式可能無法持久保存；無法儲存時要讓玩家看到實際狀態。18 格存檔縮圖要控制尺寸。[Godot Web 匯出限制](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#limitations)
- 目前匯出約 48.3 MiB（引擎 WASM、中文字型），Phase 5 記錄手機首次載入時間，再決定字型子集化或壓縮。
- 開發用本機 HTTP 伺服器，對外試玩用 HTTPS；部署位置在交付前確認。

## V1 之後

- **正式美術：** 依 [gintama0923](../gintama-like/new/gintama0923.md) 第 263 行的美術 Prompt 製作背景、立繪與 UI。每個角色先定稿一張，4–6 個表情都以它為參考圖；替換只改素材設定檔。
- **更多章節：** 討債委託改寫成第二章候選；每章先統計場景、素材與可達分支，完成後量測實際遊玩時間，再估算後續工作量。
- **後續評估：** 俯視地圖探索與格子尋路、紙娃娃換裝、配音、雲端存檔、圖形化劇情編輯器，依實際內容需要再決定。

## 待確認

1. weak 的吐槽力：[gintama0923](../gintama-like/new/gintama0923.md) 第 430 行寫「扣少量吐槽力」，第 453 行寫「少量增加」。V1 暫依第 453 行。
2. 吐槽 8 秒逾時的結果，markdown 未定義；V1 暫定為 fail。
3. 專案目錄與遊戲名稱：`debt-commission` 與 `config/name` 仍是討債委託，第一章改為草莓牛奶；改名時機與正式標題。
4. 文件同步：[prototypes/CONTEXT.md](../../prototypes/CONTEXT.md) 定義吐槽為 2 秒普通吐槽；[ADR 0002](../../prototypes/docs/adr/0002-tsukkomi-types-deferred.md) 延後 Narrative Break，V1 的第四面牆屬此類；[STORY_WORKFLOW.md](STORY_WORKFLOW.md) 寫試讀先採無限時選擇，並沿用舊的 M0／M1 里程碑名稱。三者需依 V1 更新。
5. 美術風格與素材製作方式，在 Phase 5 後確認。
6. 對外公開試玩前，確認同人作品的分享範圍。
7. [conversation1](base/conversation1.md)–[conversation3](base/conversation3.md) 定下的俯視格子地圖、紙娃娃與共用外觀 ID，是否仍是 V1 之後的目標，或改由 VN 調查模式取代。
