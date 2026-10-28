# Conversation 功能核對：開始共同製作極短篇之前

後續更新（同日）：已建立 [人格與記憶檔案流程](../../prototypes/debt-commission/authoring/README.md)、人類確認綁定雜湊與上下文載入；三份人格 revision 2 及三條基礎記憶 revision 1 已獲作者確認。本機編輯器「編劇參考」可查看、手選與匯出給外部 agent；最新範圍及證據見 [HANDOFF.md](../../prototypes/debt-commission/docs/HANDOFF.md)。下文保留建立前的歷史核對基準，完整 CRE、內建 AI Writer、自動檢索及 OOC 評分仍未實作。

日期：2026-10-28。對象：`prototypes/debt-commission` 的目前工作區，基準提交 `21604e3`；包含尚未提交的漫畫與立繪動畫功能。

**結論：沒有全部完成。VN 播放與圖編輯已具備短篇製作能力；conversation 定案的 CPC 人格、CRE、人物記憶與 AI 編劇系統仍停留在設計。** 現在可以由外部 agent 和作者人工共同編劇，再交給編輯器製作；不能宣稱編輯器已具備人格驅動的 AI 協作功能。

## 依據與判定方式

核對七份紀錄：`base/conversation1.md`、`base/conversation2.md`、`base/conversation3.md`，以及 `v2/conversation1.md` 至 `v2/conversation4.md`。依功能彙整重複提案，對照實際程式、資料、編輯器表單與既有測試；本報告不把討論中的範例 JSON 當成實作證據。

- **已實作**：有對應程式與資料流程；是否本次重測另列。
- **部分**：只有部分能力，或缺少討論指定的自動化／語意保障。
- **未實作**：在本遊戲第一方程式與資料中未找到對應流程。
- **延期／方向變更**：早期或未來構想，不作為目前短篇的阻塞項目。

重要來源定位：

| 來源 | 核對範圍 |
|---|---|
| [base/conversation1.md](base/conversation1.md) | 初始地圖、人物、紙娃娃、分支、存讀檔構想 |
| [base/conversation2.md](base/conversation2.md) | 地圖上疊對話、兩套角色 renderer、互動、鏡頭與小地圖 |
| [base/conversation3.md](base/conversation3.md) | 格子點擊移動；後半轉向故事優先、演出與腳本能力 |
| [v2/conversation1.md](v2/conversation1.md) | VN／吐槽演出、編輯器、AI Planner → Writer → QA → 人工採納 |
| [v2/conversation2.md](v2/conversation2.md) | Character Bible、笑點庫、驗證器、POV／Director、跨集狀態 |
| [v2/conversation3.md](v2/conversation3.md) | CBP → CPC／CRE；人格、聲線、關係、特定記憶、知識、檢索與檢查器 |
| [v2/conversation4.md](v2/conversation4.md) | 開頭定案 CPC v0.1；後半明確縮小 Prototype 範圍與 16 項驗收 |

`v2/conversation4.md` 開頭所稱人格「定版」，表示設計方向定版。該檔 Prototype 排除清單也明列完整 CPC Runtime、Memory Vector DB 與 AI Free Chat 暫不實作。因此「Prototype 做完」不代表「人格系統做完」。

## 目前製作與遊戲能力

| 功能 | 判定 | 實際能力／缺口與證據 |
|---|---|---|
| JSON 故事載入、逐步播放 | 已實作 | `scripts/story_runner.gd`；`main.gd::_drive_story` |
| Episode → Scene → Event | 部分 | 故事清單／作品包、node 與 step 已有；並非討論範例中完整的三層 metadata 模型 |
| 穩定事件 ID | 部分 | node、option 有 ID；存檔位置仍用 `node_id + step_index`，插入事件會改結構版本。尚非每個事件都有獨立穩定 ID |
| 一般 VN、旁白、心聲、逐字與文字節奏 | 已實作 | `scripts/dialogue_text.gd`、`dialogue_box.gd`；可停頓、變速、文字演出與長句分頁 |
| 閱讀紀錄、AUTO／SKIP、隱藏 UI、快速存讀檔 | 已實作 | `main.gd`；閱讀便利功能與手勢已有 |
| 角色站位、表情、說話焦點 | 已實作 | `scenes/stage.tscn`、`scenes/characters/*.tscn`；非說話者變暗 |
| 進退場、立繪動作 | 已實作 | `scripts/stage_motion.gd`；淡化、左右滑動、直接切換、抖動、彈跳；編輯器可選 |
| 背景／轉場／鏡頭 | 部分 | 換背景、crossfade、fade、shake、漫畫 zoom 已有；通用 wipe、任意鏡頭運鏡尚缺。舊 `move`／`face`／`camera` 雖被資料層接受，VN 外殼直接略過，不能算已做 |
| BGM／SE／Voice | 部分 | 音樂音效控制、音量與靜音已有；缺音檔時仍可能使用合成佔位音，部分語音可選載入；不是完整正式配音交付 |
| A 一般 VN + B 漫畫疊加 | 已實作 | `scripts/comedy_layer.gd`、`scenes/comedy/*.tscn`；不重建底下舞台；大字、顏藝、放射線、震動、快轉與還原 |
| 所有提議的漫畫 preset | 部分 | 四個通用 preset、消音條與舉牌等已有；fake commercial 等其他提案尚非通用現成功能 |
| POV／Director 兩種選項與真分支 | 已實作 | 不同 UI、`perspective`、`pov`、`note`、分支與合流；`tests/test_choices.gd` |
| POV 選項必須符合人格 | 未實作語意保障 | 現在僅驗證角色 id 與 `tone=loud/calm/tired` 等格式，不能判斷台詞是否 OOC；內容由作者／agent 人工把關 |
| 點擊角色／物件、連點反應、調查 | 已實作 | `investigate`、hotspot、`lines`、計次、`set`、話題、地點與 `keep_cast` |
| 旗標、條件、道具與可見後果 | 已實作 | 指派／加減、複合條件、線索門檻、分支跳轉 |
| Global／Episode／Scene 三層 State | 部分 | 現在主要是故事內單一 flags map；沒有完整三層作用域、scene 自動清除與 promote 模型 |
| 跨 Episode 保存狀態 | 部分 | `carry_out/in`、`story_library.gd::previous_carry` 可帶指定旗標到下一章，另有通關、結局與鑑賞進度；不是任意跨集人物記憶／關係服務 |
| 結局與章節流轉 | 已實作 | 多結局、結局收集、章節解鎖、結算與下一章；EP00 串連示範已有 |
| 選擇歷史 | 部分 | 閱讀／選項文字入 history 並存檔；不是討論中的獨立 choice_id／option_id／timestamp 跨集事件帳本，也沒有供 AI 檢索的記憶視圖 |
| 關係、好感與角色弧線 | 部分／未系統化 | 可用數值旗標人工編排；未見獨立 relationship、character arc、emotion 狀態模型及其自動更新 |
| 存讀檔與錯誤保護 | 已實作 | `save_slots.gd`、`save_transfer.gd`；自動／手動欄位、版本驗證、原子寫入與備份；不含雲端存檔 |
| 通用 MiniGameBridge | 未實作 | 吐槽回合、QTE、超必殺已有，但不是可任意註冊外部遊戲、回傳 result 並恢復故事的通用橋接 |
| Web 圖編輯器 | 已實作 | 新故事、節點／連線、表單、JSON、搜尋、undo／redo、草稿、驗證存回、素材與作品包；`tools/story_editor/` |
| 所有事件免 JSON 編輯 | 部分 | 普通台詞、選項、人物與常用效果有表單；大型調查／吐槽回合等仍需 JSON。沒有完整的所見即所得演出 timeline |
| 從選定場景試玩 | 部分 | 未存稿、旗標／線索與獨立遊戲資料可用；不自動還原前面場景的舞台、音樂與互動狀態；不是網頁內同步嵌入式預覽 |
| Google Sheet／CSV 匯入 | 未實作／替代流程 | 目前用 `.dialogue`／Parley `.ds`／圖編輯 JSON，未見討論中指定的試算表匯入器 |
| 故事資料驗證 | 部分 | 素材 id、合法指令、分支目標、結尾、不可執行步驟、可達性等有檢查；不等於所有條件組合可達／必能結束、人格一致或笑點有效 |
| 無限 goto／事件 ID／知識矛盾檢查 | 部分 | runtime 有內部跳轉上限；不等於完整靜態循環分析。沒有獨立事件 ID 全域唯一性與人物知識洩漏分析 |
| agent 共同編劇 | 部分：外部人工流程可行 | `STORY_WORKFLOW.md` 與 authoring 指引能給 agent 使用；需明確交付文本與資料。尚無編輯器內 agent writer、人格載入、逐場生成與採納／拒絕流程 |
| AI Planner／Writer／角色 QA／Comedy Pass | 未自動化 | 討論與一般 prompt 有描述；未見專案專用的上下文組裝器、階段產物契約、候選驗證與迭代記錄工具 |
| Comedy Pattern Library | 未實作 | 漫畫視覺 preset 不是 CP001 等笑點因果／節奏資料庫 |
| 真人體驗、角色還原度與喜劇品質 | 待驗證 | 技術測試不能替代作者試讀、20～30 組人物情境評估或真人手機試玩 |

## CPC 人格系統逐項核對

主要依據：`v2/conversation3.md` 的 CharacterProfile／CPC／CRE，以及 `v2/conversation4.md` 開頭定案清單。

| 人格需求 | 判定 | 現況 |
|---|---|---|
| 可驗證、可版本化的 CPC Schema | 未實作 | 未見本遊戲專用 schema、版本規則或人格驗證器 |
| 銀時／新八／神樂三份 CPC | 未實作 | `data/asset_catalog.json` 有 name、短 profile、表情路徑、slot、voice_pitch；未見完整 CPC 人格資料 |
| Identity／世界觀／價值觀／動機／矛盾 | 僅短介紹 | 人物檔案不是結構化核心人格與推導規則 |
| Behavior Policy／Decision Rules／Boundaries | 未實作 | 沒有 would_do／would_not_do、情境決策與禁止行為資料 |
| 情緒基線、觸發與反應狀態 | 未實作 | `expression` 是畫面表情，不是心理狀態模型 |
| 語氣、節奏、口癖、正反台詞示例 | 未實作 | `voice_pitch` 只是打字音高；未見角色聲線模型與對話 few-shot 資料 |
| Comedy Model | 未實作 | 未見各角色 boke／tsukkomi 職能、升級邏輯、認真模式觸發與固定笑點資料 |
| Relationship Model | 未實作 | 人物間表面／深層關係、衝突模式、信任等尚無專屬資料／工具 |
| Knowledge／Lore／真相與角色認知分離 | 未實作 | 旗標可以人工模擬，但未見獨立人物已知資訊、錯誤信念、知情範圍機制 |
| Canon／Story／Relationship／Conversation 記憶 | 未實作 | 遊戲 save/history 不能取代 owner、來源、重要性、visibility、持續性等記憶資料 |
| 記憶／Lore 檢索 | 未實作 | 沒有按角色、話題、時間、知情權選出相關記憶的流程；不是只缺向量資料庫 |
| Scenario／User Persona | 未實作 | 場景背景與 POV id 不等於編劇／聊天情境與使用者扮演身份模型 |
| Persona Compiler／Prompt Assembler | 未實作 | 未見把人格、關係、場景、知識與特定記憶編成有限上下文的工具 |
| 人格／連貫性／記憶 QA | 未實作 | 無獨立 OOC 檢查報告、修稿依據或 20～30 組情境基準 |
| VN／Chat 共用同一人格與記憶 | 未實作、後續項目 | 沒有 CRE 或自由聊天服務；不阻塞先製作固定文本的極短篇 |

## 早期構想與目前範圍

`base/` 提到的格子地圖、AStar、自動靠近 NPC、Y-sort、小地圖、玩家創角、紙娃娃換裝與地圖／立繪共用外觀，在目前 debt-commission VN 中未形成完整功能。後續 v2 改採 VN + Clickable Scene；因此記為早期／後續方向，不列為這篇極短篇開工前必補。

9:16 直式也已被使用者較新的指示改成 16:9 橫向，屬方向變更。雲端存檔、完整自由聊天、向量記憶資料庫、通用小遊戲橋接及正式配音均非目前極短篇必要前置。

## 建議的極短篇開工門檻

先補「製作階段的人格協作最小流程」，不用等整個 CRE 上線：

1. 建立一份有必填欄位與版本的 CPC schema；先為實際出場角色填人格、語氣示例、行為界線、角色關係及本篇已知資訊，新增設定由作者採納。
2. 支援手動指定特定記憶；每條至少帶角色 owner、來源、內容、知情角色與可否改寫。先用檔案與明確選取即可。
3. 讓 agent 每次讀同一份角色／場景上下文，輸出短節拍、台詞候選及 OOC／知識矛盾自查；保留作者採用與修改紀錄。
4. 作者採納後轉成圖編輯故事；用選項／旗標、立繪與漫畫演出完成可玩版本，再實際改稿一次。

```text
人格與特定記憶 → agent 節拍／台詞 → 人格與知識自查
                                      ↓
作者採納／修改 ←───────────────────────┘
       ↓
圖編輯器 → 場景試玩 → 存檔 → 再改稿
```

這是下一輪建議，**本次尚未建立 CPC 或代寫第一篇故事**。現有 agent 可以人工遵循上述步驟，但不能把人工閱讀 prompt 算成已建立自動人格系統。

## 本次驗證證據與限制

本次靜態核對範圍：第一方 `scripts/`、`main.gd`、`data/`、`story_src/`、`tools/story_editor/`、編寫指引及測試。人格缺項判定結合資料清單、表單、server endpoint、runtime 與內容流程，未以 MCP addon 或通用 Studio 範本當成遊戲已整合的人格系統。

本次重跑（依序、隔離 HOME；遊戲目錄）：

```bash
python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_choices.gd
python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_ep00.gd
python3 tools/story_editor/run_coordinated.py /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_chapter_flow.gd
```

三組均 PASSED；EP00 本次輸出 892 checks。Godot 結束時仍有既有資源／RID 清理訊息，未見本次測試的 script error。先前的編輯器新建／存回／未存稿試玩與立繪動畫測試沿用同日 `Progress.md` 證據，本次未重跑 Web、編輯器瀏覽器流程或完整遊戲測試。未做真人閱讀品質與人格相似度驗收；不存在的 CPC／CRE 也沒有可執行測試。

知識圖 MCP 本次回覆 Transport closed，因此依專案規則改用第一方檔案搜尋。未更動遊戲行為、未 commit／push。
