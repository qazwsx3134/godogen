---
name: story-authoring
description: >
  Write, add or change a story, chapter or interaction in prototypes/debt-commission (the
  Gintama-style tsukkomi visual novel): co-writing a new script with the user (Gintama comedy
  structure), dialogue, choices, flags, character expressions, investigation hotspots, tsukkomi
  rounds (testimony, combo, censor bar, QTE, super), stage effects, the chapter result, and new
  characters, backgrounds or items; also making a story selectable, building it and verifying it.
  Use when the user asks to 寫劇本／新故事／新章節, 改劇情, 換成其他故事, 加調查／吐槽回合／互動,
  加角色／背景／素材, or which character expressions to draw.
---

# 新增故事與互動（debt-commission）

所有路徑相對於 `prototypes/debt-commission/`。指令都在這個資料夾裡跑，headless 一律加
`XDG_DATA_HOME=$PWD/.cache/test-data`。

## 先讀

- `IMPLEMENTATION.md`：StoryRunner 能用的 op 與欄位、劇本建置。
- 文法：`tools/story_build/dm_source.gd` 檔頭（`.dialogue`）、`scripts/tsukkomi_round.gd` 檔頭（v2 回合欄位與規則）。
- 範例：`story_src/phase4.dialogue` + `phase4.blocks.json`（調查、v1 吐槽回合、選項、條件）；
  `story_src/phase4_rounds.dialogue` + `.blocks.json`（v2 證言與連擊、消音條、QTE、超必殺、演出）。
- 劇情：`docs/story-telling-game/`（`STATUS.md`、`stories/` 的草稿）。台詞用使用者核准的稿；
  沒有核准稿時，在 `note` 與開場台詞標明是技術試片。

## 寫新劇本（共同編劇）

使用者要的是新故事或新章節、還沒有核准稿時，先寫稿，不要直接寫 `story_src`。

- **流程**照 `docs/story-telling-game/STORY_WORKFLOW.md` 的 S0.1–S0.6，那裡也有現成的「遊戲編劇 Prompt」。喜劇怎麼寫照 `docs/gintama-like/story-prompt.md`：第 30–110 行是核心創作原則，第 112–453 行是互動流程與最終腳本要求。第 468 行以後的第二版是拍短片用的，只取它的「導演模式」概念，對應到本遊戲的演出與素材需求。
- **你是共同編劇，不是一次寫完的生成器**：視角 → 展開方向 → 失控點 → 角色配置 → 節拍表 → 關鍵對話方案，每一步停下來用 AskUserQuestion 給 2–4 個真正不同的選項，讓使用者選。使用者說「你直接決定」才能跳過。使用者已經決定的，不要再問。
- **結構**：小事放大 → 逐步失控 → 吐槽與反差 → 需要時短暫認真 → 回扣最初的小目標，最後再補一個 Punchline。吐槽要有功能（指出矛盾、打破氣氛、第四面牆），不是只大喊。角色分工清楚（主角、吐槽役、天然、事件製造者、認真角色），不要每個人都在吐槽。跨作品惡搞只借敘事規則與剪影、馬賽克、錯誤名字，不照抄台詞與角色設計。
- **遊戲的要求**（短片 prompt 沒有的）：
  - 一章約 80–100 句。
  - 每個槽點都能從台詞或素材找到吐槽根據。
  - 回合的四種結果、隱藏路線、Game Over 都要寫到。
  - 台詞、表情與演出（cut-in、震動、停格）要交替出笑點，不要全靠長台詞。
- **草稿**寫在 `docs/story-telling-game/stories/<編號>-<名稱>-draft-v<版本>.md`，格式照 `003-strawberry-milk-ch1-draft-v0.2.md`：
  - 台詞編號、演出寫在方括號、表情寫在 `[char: 角色 表情 位置]`。
  - 最後列出待決提案與素材需求，包含第一次用到的表情。
  - 作者核准後才轉成 `story_src`，並把核准紀錄寫回草稿開頭與 `STATUS.md`。

## 表情

- 表情 id 與意思在 `docs/story-telling-game/EXPRESSIONS.md`（生氣 `angry`、慌張 `panic`、緊張 `nervous`、心虛 `sweat`、認真 `serious`……），劇本只能用那張表的 id。
- 角色情緒變了就標出來：`char("kagura", "angry", "right")`，或台詞後面加 `[#angry]`。說話的人會換成那張臉的圖；還沒有圖的就先顯示原本那張，所以照樣可以寫。
- 寫完、建置後跑 `godot --headless --path . --script res://tools/list_expressions.gd`，列出劇本用到、還沒有圖的表情，把它們補進 `EXPRESSIONS.md` 的「各角色要畫的表情」表格，交給使用者安排製作。
- 需要表上沒有的表情時，先跟使用者確認，再同時加進 `EXPRESSIONS.md` 與 `scripts/story_runner.gd` 的 `VALID_EXPRESSIONS`。
- 表情圖用 `EXPRESSIONS.md` 裡的生成 prompt 做（白底）。做好的原圖照該文件「放進遊戲」的步驟處理：放進 `art_src/expressions/`、寫進 `fit.json`、跑 `tools/fit_expressions.gd`，再把印出的 `CATALOG` 貼進 catalog。

## 流程

1. **素材 id**：故事用到的背景、角色、素材、音效、音樂都要先在 `data/asset_catalog.json`。缺的照下方「新增素材」補。
2. **原始檔** `story_src/<name>.dialogue`。`<name>` 用英文小寫加底線。使用者在 Parley 畫的是 `.ds`，文法相同。同一個故事只用一種格式。
3. **參數檔** `story_src/<name>.blocks.json`：
   - `story`：`id`、`title`、`note`、`initial_flags`（每個會 `set` 的 flag 都在這裡給初值；沒給的話，判斷它的條件一律走 `else`）。
   - `titles`：每個 `~ title` 的中文名稱，存檔欄位會顯示。
   - `blocks`：`investigate`／`boke_round` 的參數。
4. **建置**：
   `godot --headless --path . --script res://tools/story_build/build_story.gd -- story_src/<name>.dialogue`
   會輸出 `data/<name>_story.json`。錯誤訊息會指出哪個 title 的第幾步，照著改到通過為止。
5. **放進章節選擇**：在 `data/stories.json` 依順序加一行 `{"id": "<name>", "kind": "chapter", "path": "res://data/<name>_story.json", "save": "user://<name>.save"}`（技術試片用 `"kind": "sample"`）。本篇依順序開放，前一章結算過才能玩。Web 用 `?sample=<name>` 直接開。沒登記的故事也能在編輯器用「專案 → 工具 → 劇本：建置並試玩」試玩。
6. **驗證**（見下方），並更新 `docs/AUTHORING.md` 的「目前可以用的代號」。不要 commit，使用者自己 commit。

## 編譯器不會提醒的事

- **一個 `~ title` 就是一個存檔位置。**
  - 發布後不要改 title 名稱。
  - 增刪步驟、改分支會讓版本改變，這個故事的舊存檔就會失效。只改台詞文字，版本不變。
- **站位是通用的，不綁角色。**
  - `left`／`center`／`right` 是位置，站在哪裡由 `scenes/stage.tscn` 決定；每個角色多大、圖怎麼擺，由各自的 `scenes/characters/<id>.tscn` 決定。
  - 主角（視角角色，負責吐槽的人）站 `left`。
  - **角色開口才登場**：`char()` 只設定站位和表情，不會讓人出現。說過話的人留在畫面上（變暗），說話的人在最前面；換到不同背景（新場景）或開始調查時全部退場，要提早退場用 `hide()`。所以要讓某人出現，就讓他說一句話（只會「汪」的定春也一樣）。
  - 同一場景會說話的人超過一個時，每個 `char()` 都寫明第三個參數（位置）。catalog 的 `slot` 只在沒寫位置時當預設，而且好幾個角色的預設都是 `right`，不寫會疊在一起。
- **對話與選項：**
  - 說話者寫 catalog id 或中文名；旁白就不寫名字。
  - 內心話加 `[#thought]`，表情用 `[#smile]` 這類 tag，可用值見 `story_runner.gd` 的 `VALID_EXPRESSIONS`。
  - 台詞裡不能有 `[` 或 `{{`。
  - 選項的前一句必須是旁白（它就是題目）。每個選項都要 `[ID:英文代號]`，且至少要有一個不需素材的選項。
- **條件**只能寫 `if flag == 值` 加 `else`，每一支各接一個 `=> title`。
- **收尾：**
  - 本篇章節用 `do result("block")` 結尾，顯示章節結算：blocks 裡寫 `"op": "result"`、`title`（「～ 第一章 完 ～」）、`lines`（S／A／B／C 各一句 `{speaker, text}`）、`hidden_total`。評價由程式依剩下的眼鏡與 Game Over 次數算，不用寫。
  - 技術試片或非章節的故事用 `do end("…")` 結尾。
  - `do boke_round(...)` 是它那個 title 的最後一行，回合靠 blocks 裡的 goto 離開。
  - v2 回合的反應節點，最後要 `=> <回合所在的 title>` 回到回合。
- **調查點**是背景圖上的東西，不是按鈕：`pos` 是它在背景圖上的中心、`size` 是大小，都是圖寬、圖高的比例（0～1）。先打開背景圖找到那樣東西（垃圾桶、沙發、桌子……）再量座標，放完用截圖確認框有蓋在物件上。玩家可以左右拖曳背景，所以圖的任何位置都能用；調查時角色不在畫面上，跟角色有關的線索（例如嘴角的痕跡）要改用對話取得。
- **v2 回合的聽下去／空揮／提示**：用 `listen`、`whiff`、`hint` 寫成反應節點，不用開新 op。

## 互動對照

| 想做的事 | 寫法 | 範例 |
|---|---|---|
| 台詞、內心話 | `新八: …`、`[#thought]` | phase4 `phase4_open` |
| 選項、記住選擇 | 旁白題目 + `- 選項 [ID:x]`，下面 `set k = "v"`，再 `=> title` | phase4 `ask_first` |
| 依選擇分支 | `if asked == "kagura"` / `else` | phase4 `perfect` |
| 取得素材、解鎖人物檔案 | `do item("id")`、`do profile("角色")`（catalog 角色要有 `profile` 文字） | phase4 |
| 調查畫面找線索 | `do investigate("block")`；blocks 裡寫 `hotspots` | phase4 `living_room_search` |
| 吐槽回合（v1：幾句發言 + 一次選詞） | `do boke_round("block")`；blocks 不寫 `mode` | phase4 `gintoki_four_clues` |
| 證言回合（逐句找破綻） | blocks 裡 `mode: "testimony"` | phase4_rounds `r1_testimony` |
| 連擊回合（依序、時限越來越短） | `mode: "combo"`，`rules.combo_timers` | phase4_rounds `r2_combo` |
| 需要先戳中別句才出現的選項 | 選項加 `require_caught: [...]` | `r1_testimony` l4 d |
| 第四面牆消音條 | 台詞用 `▇` 蓋住字，slot 加 `censor` | `r1_testimony` l3 |
| QTE（縮圈點擊） | slot 加 `qte` | `r2_combo` c4 |
| 超必殺、連擊獎勵與中斷 | `rules.super`、`combo_bonus`、`combo_break` | `r2_combo` |
| 眼鏡耗盡 | block 的 `game_over` 指向一個 title | 兩個範例都有 |
| 章節結算 | `do result("block")`；blocks 裡 `"op": "result"` | `tests/fixtures/chapter_a_story.json` 的 `done` |
| 演出 | `do shake()`、`flash()`、`cutin("字", "角色")`、`freeze()`、`bgm("id")`、`se("id")` | phase4_rounds |

## 新增素材

- **背景**：
  - 在 catalog 的 `backgrounds` 加 id（`label`、漸層色 `top`／`bottom`、`path`），圖放 `assets/image/`，再跑一次 headless `--import`。
  - 需要自己的取景時，在 `scenes/stage.tscn` 的 `Backgrounds` 下加一個同名的框。用 Godot 存檔，保留使用者已經做的調整，不要重新產生整個 scene。沒有同名框的背景會用 `Default`。
- **角色**：
  - 在 `characters` 加 `name`、`color`、`slot`、`path`，要有人物檔案就加 `profile`。立繪必須是透明背景的 PNG。
  - 接著跑 `godot --headless --path . --script res://tools/story_build/make_parley_stores.gd`，把角色加進 Parley 的角色清單。
  - 再跑 `godot --headless --path . --script res://tools/make_character_scenes.gd`，替新角色建 `scenes/characters/<id>.tscn`（已經有的不會動）。建好後截圖檢查大小；要調整就改那個 scene 裡 `Art` 的 offset，不要重建。
- **素材、音效、音樂**：
  - 素材加在 `items`（`name`、`description`）。
  - 音效和音樂加在 `sounds`／`music`，先只寫 `label`；沒有 `path` 時會播合成的佔位音。
- **生成新圖或新音效**：用 Scenario 系列 skill。它會花使用者的 credits，第一次生成前先問使用者。

## 現有 op 做不到的互動

先跟使用者確認設計，再一起做完這些：
- `scripts/story_runner.gd`：資料驗證，以及 snapshot／restore（存檔）。
- `tools/story_build/dm_source.gd` 與 `parley_source.gd`：解析新語法。
- `main.gd`：畫面呈現。畫面做成 `.tscn`，照 repo 根目錄 `AGENTS.md` 的 scene 規則。
- QA 快照欄位（`_write_qa_state`）。
- `tests/`：新增測試。
- `IMPLEMENTATION.md`：更新契約。

## 驗證

- `build_story.gd -- story_src/<name>.dialogue --check`：確認資料沒有過期。
- 全部 headless 測試：`for t in tests/test_*.gd; do godot --headless --path . --script res://$t; done`，每個都要 PASSED。
- **實跑截圖**：在 scratchpad 寫一個 SceneTree 腳本，裡面 `instantiate()` `main.tscn`、設好 `story_path`／`save_path`，一路推進劇情並存截圖。用
  `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 390x844 --script <腳本>`
  跑，每種互動至少看一張圖。
- 改到畫面或手勢時，另跑 `tools/browser_check.mjs`（用法見 `README.md` 的「驗證」）。
- 回報時列出建置輸出的版本、測試結果和截圖；沒跑的項目要直接說沒跑。
