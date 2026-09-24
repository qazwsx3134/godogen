# 直式吐槽視覺小說 Roadmap

目前已完成與待辦清單見[進度紀錄](STATUS.md)。

更新：2026-09-25。狀態：V1 功能範圍依 [gintama0923](../gintama-like/new/gintama0923.md)；Godot 4.7 Web 工具鏈、劇本執行器與驗證流程已由 [debt-commission 原型](../../prototypes/debt-commission/README.md) 建立。Phase 0–2 與手動存讀檔通過自動驗收；Phase 3 的「調查 → 裝傻 → 吐槽」技術短循環可在 Web 試玩，已通過自動測試。作者確認的一回合台詞與真人手機試玩仍待完成；證據見[驗證紀錄](../../prototypes/debt-commission/docs/VERIFICATION.md)。

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
| 懸浮按鈕 | 右上選單 (≡) 與存檔 (S)；可拖曳，放開吸附左右邊緣；閒置 3 秒變 40% 透明；自動避開對話框；點 (S) 開啟手動存檔欄位 |
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
- **存讀檔：** 3 頁、每頁 6 個手動欄位，顯示場景縮圖、章節名與時間；自動續讀檔獨立保存，讀檔時也可明確選擇自動檔。標題與遊戲內皆可選欄讀檔。
- **設定：** 文字速度、自動播放速度、BGM／音效音量。

### 劇本指令

至少包含：`bg`、`char`（角色 ID／表情／位置）、`say`、`choice`、`flag`、`goto`、`item`（取得素材）、`investigate`、`boke_round`（`lines`、`listen`、`tsukkomi.options`、`result`、`require`、`timer`、`qte`）、`shake`、`flash`、`cutin`、`freeze`、`bgm`、`se`。

劇本沿用現有 StoryRunner 的節點結構：根資料含 `id`、`version`、`entry`、`initial_flags`、`nodes`，每個節點有 `steps` 與選擇性 `next`；上述指令是 `steps` 內的 op。markdown 中的扁平 `type` 陣列是指令示意，不當成檔案結構。指令名稱採 markdown 版本：`flag`、`se`、`char` 分別承擔現有的 `set_flag`、`sound` 與 `show`／`hide`／`expression`；`condition`、`end` 保留。

### 存檔

旗標、素材、眼鏡耐久、吐槽力、劇本位置都存入本機存檔。自動續讀檔與 18 個手動欄位分開；新遊戲只重設自動續讀進度，手動欄位保留。每次換場景與每個裝傻回合開始時自動存檔。存檔帶劇本版本與穩定節點 ID；讀檔從選定欄位或最近成功的檢查點恢復，台詞可以重讀，選擇與吐槽結果不能重複套用。

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

劇本先依 [STORY_WORKFLOW.md](STORY_WORKFLOW.md) 共同編劇，作者確認文字版後再轉成正式 JSON。[missing-strawberry-milk](../../prototypes/missing-strawberry-milk/README.md) 已有同一事件的文字雛形與詢問對象，可作為素材；台詞依裝傻回合與四種吐槽結果重新編排。Phase 2 的約 10 句 JSON 是技術測試片段，不代表第一章文本已核准。

## 現有基礎

V1 在 `prototypes/debt-commission/` 這個 Godot 專案內改造，開發分支為 `v1-tsukkomi-vn`；改造前的第一場原型保存在 commit `1ec9ffb`。

| 類別 | 現有內容 | V1 做法 |
| --- | --- | --- |
| Web 工具鏈 | 4.7 stable、相符官方單執行緒 Web 範本、`fetch_web_templates.py`／`build_web.sh`／`serve_web.sh`、中文字型 | 沿用；匯出排除 MCP addon |
| StoryRunner | JSON 節點、資料與引用檢查、flags／condition／goto、跳轉循環保護、snapshot／restore 與版本檢查 | 已支援 Phase 2 的素材門檻及 Phase 3 的調查、吐槽四結果、眼鏡／力量、檢查點與狀態還原 |
| 閱讀 UI | 逐字補完／前進、回顧、音效開關、`user://` 閱讀點自動存檔與續讀 | VN 分層版面、獨立自動檔與 18 個可選手動欄位已完成；Phase 3 技術畫面可操作 |
| 驗證 | `tests/test_story.gd`、`?qa=1` 唯讀 `window.__debtQA`、Playwright `browser_check.mjs` | Phase 1–3、存讀檔 headless 測試，以及既有路線、手動欄位、Phase 3 觸控短循環的瀏覽器檢查均通過 |
| 舞台演出 | `story_stage.gd` 萬事屋俯視室內與繞桌走位；`actor_doll.gd` 地圖 SD 與說話立繪 | 已移除（保留在 `1ec9ffb`）；V1 立繪改用 `placeholder_sprite.gd` 的剪影＋名字＋表情文字 |
| 故事 | 《請幫我向你老闆討債》第一場 51 句核准稿、兩選項分支與後段回扣（[核准文本](stories/002-debt-commission-draft-v0.1.md)） | 保留為後續章節候選，改寫成含裝傻回合的版本 |

設計尺寸已在 Phase 1 由 720×1280 改為 1080×1920，同為 9:16。

## 開發階段

每個 Phase 都保留可在瀏覽器開啟的 Web 匯出版本，並通過相應的引擎測試與瀏覽器檢查。進度：Phase 0–2 ✅；手動存讀檔 ✅；Phase 3 技術短循環通過自動驗收，整體關卡尚待作者台詞與真人手機試玩；Phase 4–5 未開始。證據見[驗證紀錄](../../prototypes/debt-commission/docs/VERIFICATION.md)。Phase 1 的 Safe Area 僅驗過瀏覽器避開系統安全區的行為；Android／iOS 實機與全螢幕模式另列驗收。

| 階段 | 玩家或作者拿到的成果 | 系統工作 | 通過條件 |
| --- | --- | --- | --- |
| **Phase 0：專案轉換與工具** | 可連上 Godot MCP 的開發環境；舊原型已保存 | commit 目前原型；在 Project Settings 啟用 Godot MCP Toolkit，產生 `.mcp.json` 並從專案根連線；Web 匯出 `exclude_filter` 加入 `addons/godot_mcp_toolkit/*`；準備有畫面的編輯器（WSLg 或 Windows 版 Godot） | MCP 可讀場景樹並截圖；Web 匯出不含 addon 檔案；既有測試與 `browser_check` 仍通過 |
| **Phase 1：直立框架與懸浮按鈕** | 1080×1920 直立畫面，placeholder 背景與立繪，可點擊讀完一段對話 | 六層結構、Safe Area、對話框（28%、名牌、逐字、▼）、點擊補完／前進；懸浮按鈕拖曳、吸邊、閒置透明、避開對話框；長按隱藏 UI；上滑開紀錄 | 390×844、320×568 與更長手機比例都不遮擋文字與按鈕；按鈕操作不誤觸推進劇情；觸控與滑鼠皆可玩 |
| **Phase 2：劇本與素材資料** | 作者改 JSON 即可換背景、立繪、台詞與分支；有一段可在瀏覽器試玩的約 10 句技術片段 | `bg`、`char`、`say`、`choice`、`flag`、`goto`、`item`；選項 `require`；集中素材設定；存入素材與畫面狀態 | 兩個背景、角色站位／表情、素材取得與分支都能在畫面看到；兩路到結尾。缺角色、缺素材、缺節點、未知指令在啟動前指出節點與步序；未持有素材時選項不出現；headless 與瀏覽器各有實際驗收 |
| **Phase 3：核心短循環** | 玩到一段萬事屋調查、取得一個素材，再用它完成銀時的一回合裝傻與吐槽 | 最小 `investigate` 熱區；`boke_round` 的發言切換、聽下去、吐槽選項與四種結果；8 秒預設計時、眼鏡耐久、吐槽力；回合前檢查點與重試；基本成功／冷場演出 | 玩家用真實觸控走完「調查 → 素材 → 裝傻 → 吐槽」；缺素材時依然能選普通吐槽；perfect／weak／fail／hidden、逾時與重試均可驗證；讀檔不重複給素材或套用結果；真人試玩回饋計時與笑點 |
| **Phase 4：第一章玩法擴充** | 完整調查萬事屋，接住三回合裝傻與特殊槽點 | 先完成 4 個熱區、移動／對話話題、素材／人物檔案，再擴充超必殺、QTE、連擊、第四面牆 UI 槽點、3 次失敗提示與 `shake`／`flash`／`cutin`／`freeze`／`bgm`／`se`；把繼續膨脹的 `main.gd` 拆出調查與吐槽控制器 | 4 項素材可取得、查過不重複給；調查 ↔ 對話狀態與存檔一致；三回合都可結束，QTE／連擊／第四面牆／超必殺各有一個可玩實例；cut-in 不吞下一次點擊，數值與提示有測試 |
| **Phase 5：設定與第一章** | 作者核准的完整第一章，從標題玩到章節結算 | 沿用已完成的手動欄位與自動續讀；設定、章節選擇、章節結算；放入約 80–100 句經試讀的第一章 | 主線、隱藏路線、Game Over 重來都能到結尾或回到檢查點；存讀檔後旗標、素材、眼鏡、吐槽力一致且不重複套用；同一瀏覽器重開可繼續；真人手機試玩一次 |

Phase 2 的 `bg`／`char`／素材條件同時影響 StoryRunner 與畫面，兩者須一起驗收。Phase 3 依賴 Phase 2 的 `item` 與 `require`，並建立 Phase 4 Game Over 所需的最小檢查點；Phase 4 的調查擴充與特殊吐槽依賴 Phase 3 的完整短循環。Phase 3 技術樣本可驗證狀態與操作；8 秒時限與笑點節奏的關卡須用作者確認的一回合文字和真人手機試玩判定。

這個順序把核心玩法驗證提前：原先 Phase 3 只做調查、Phase 4 一次包含所有吐槽變體，會在完成大量 UI 後才知道「找槽點」是否成立。Phase 3 先用一個熱區與一個素材驗證因果和手感；Phase 4 再把已驗證的循環擴為四素材、三回合與特殊槽點。手動欄位與獨立自動檔在 Phase 3 前完成；素材、數值與回合檢查點隨玩法接入，讓 Game Over 可回到穩定狀態。

## 驗證

- **引擎測試：** headless 執行 `tests/`。Phase 2 檢查 JSON／素材驗證、分支門檻與還原；Phase 3 起加入吐槽判定、眼鏡與吐槽力、檢查點；Phase 4 加入連擊和特殊槽點。
- **瀏覽器：** `browser_check.mjs` 以真實 canvas 點擊與觸控走完既有試玩路線，另走 Phase 2 的短篇 JSON。Phase 3 起走調查到吐槽的短循環；桌機、390×844 觸控模擬與 320×568 窄畫面各跑一次。
- **Godot MCP：** 在編輯器內快速調版面、拖曳按鈕、cut-in 時機與錯誤輸出，是開發輔助；Web 匯出版的驗收仍以瀏覽器檢查為準。
- **真人試玩：** Android Chrome、iOS Safari 實機；確認笑點、吐槽時限是否太緊、懸浮按鈕是否擋畫面。未測到的平台如實標示。

## 開發工具：Godot MCP Toolkit

現況：`prototypes/debt-commission/addons/godot_mcp_toolkit/` 為 v1.0.2（支援 Godot 4.2+，測到 4.7.0），已在 Windows 版 Godot 編輯器啟用。plugin 在編輯器內開 WebSocket（6550 起），再由 `@npgamedev/godot-mcp-server` 橋接給 Claude Code。V1 大量是 UI 版面與觸控手感，MCP 可以直接開遊戲、截圖與讀 console，縮短調整迴圈。

WSL 裡的 Claude Code 連 Windows 編輯器已實測可用：bridge 必須以 Windows 程序執行，才讀得到 Windows 端的登記檔；專案路徑用環境變數指定，並透過 `WSLENV` 傳給 Windows。在 repo 根目錄執行一次，重開 Claude Code 後生效：

```bash
claude mcp add godot-mcp-toolkit \
  -e 'GODOT_MCP_PROJECT_PATH=D:\repo\godot\godogen\prototypes\debt-commission' \
  -e GODOT_MCP_CONFIG_VERSION=1 \
  -e WSLENV=GODOT_MCP_PROJECT_PATH:GODOT_MCP_CONFIG_VERSION \
  -- cmd.exe /c npx -y @npgamedev/godot-mcp-server
```

專案內的 `.mcp.json` 由編輯器產生，指令是 `cmd`，只適用於從 Windows 啟動的客戶端。

另評估過 [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)：透過 Godot 命令列建場景、執行專案與讀輸出，不需 plugin，但沒有輸入模擬、執行中截圖與節點檢查；它能做的事，目前的 toolkit 與直接呼叫 `godot --headless` 都已涵蓋，兩個 MCP 同時啟動 Godot 也容易互相干擾，所以不加入。

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
- WSL 的 headless 匯出與 Windows 編輯器共用專案的 `.godot/`；兩邊同時掃描檔案時，編輯器 console 可能出現 progress dialog 錯誤，屬於編輯器本身，與遊戲無關。

## Godot 瀏覽器交付

- 以「點擊開始」作為音效啟動入口；測試切到其他分頁再回來後，BGM 與演出狀態。
- 瀏覽器存檔受網站儲存政策影響，受限模式可能無法持久保存；無法儲存時要讓玩家看到實際狀態。18 格存檔縮圖要控制尺寸。[Godot Web 匯出限制](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#limitations)
- 目前匯出約 48.3 MiB（引擎 WASM、中文字型），Phase 5 記錄手機首次載入時間，再決定字型子集化或壓縮。
- 開發用本機 HTTP 伺服器，對外試玩用 HTTPS；部署位置在交付前確認。

## V1 之後

- **正式美術：** 依 [gintama0923](../gintama-like/new/gintama0923.md) 第 263 行的美術 Prompt 製作背景、立繪與 UI。每個角色先定稿一張，4–6 個表情都以它為參考圖；替換只改素材設定檔。
- **更多章節：** 討債委託改寫成第二章候選；每章先統計場景、素材與可達分支，完成後量測實際遊玩時間，再估算後續工作量。
- **俯視地圖（V1 之後）：** 沿用 [conversation1](base/conversation1.md)–[conversation3](base/conversation3.md) 的方向，做成 Pokémon 式的俯視地圖：格子移動、四方向行走、面向 NPC／物件互動，對話直接疊在地圖上。紙娃娃換裝與地圖、立繪共用外觀 ID 一併延後。
- **後續評估：** 配音、雲端存檔、圖形化劇情編輯器，依實際內容需要再決定。

## 實作基準與待確認

- 原始文件的 weak 數值互相矛盾：[gintama0923](../gintama-like/new/gintama0923.md) 第 430 行寫扣少量，第 453 行寫少量增加。V1 以較後面的 Prompt 為實作基準；真人試玩時觀察它是否讓普通吐槽過於安全。
- 8 秒是初始測試值，逾時暫按 fail；文字試讀仍不限時。Phase 3 的手機試玩記錄反應時間、誤觸與是否理解素材提示，再調整預設值。
- [prototypes/CONTEXT.md](../../prototypes/CONTEXT.md) 的 2 秒普通吐槽與 [ADR 0002](../../prototypes/docs/adr/0002-tsukkomi-types-deferred.md) 描述的是 `missing-strawberry-milk` 的早期試作。V1 的第四面牆是點 UI 元素的槽點，按本 Roadmap 的玩法驗證，無須引入該 ADR 所說的戰鬥／Boss 系統。[STORY_WORKFLOW.md](STORY_WORKFLOW.md) 已改為 V1 直式 VN 的內容流程。
- 正式標題與專案目錄名稱仍待作者定案；`debt-commission` 是開發目錄，第一章試玩入口會清楚標示草莓牛奶。美術風格與素材製作方式在 placeholder 驗證後決定。
- 對外公開試玩前，確認同人作品的分享範圍。
