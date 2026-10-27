# Godogen Source Repo

This repository is not a published game repo. It is the source that `publish.sh` renders into a runtime game repo for a chosen engine and host agent.

## 進度紀錄與交接

- 接手工作先讀 repo 根目錄的 `Progress.md`，再讀目前遊戲的 README 與 session-state；以使用者最新指示決定是否恢復開發。
- **每次 commit 前**，更新 `Progress.md`，將此次相關的進度紀錄一併提交。使用者說「要出門」「出門」「下班」、暫停或交接時，也先更新此檔，記錄目前可安全停下的狀態，再暫停工作；這些話本身不額外授權 commit、push 或繼續開發。
- 紀錄至少包含：日期、專案與分支、已完成／部分完成／未完成、使用者延期事項、驗證命令與結果／未驗證範圍、重要檔案、已知限制或阻礙、下一步及工作區未提交狀態。測試未重跑就註明沿用哪次證據，不能把舊結果寫成本次新驗證。
- 將遊戲實作基準 commit 與交接文件分開描述，避免為了在文件寫入它自己的 commit hash 而反覆提交；最新提交以 `git log -1` 查核。多專案並行時保留其他專案章節，不用自己的進度覆蓋別人的紀錄。
- 同步修正相關 README／session-state 的過時狀態，並保留不屬於本次工作的修改。沒有明確授權時不自動 push。

## 踩過的坑

- 所有原型踩過的坑統一列在 `prototypes/LESSONS.md`，依主題分類、每條附做法與來源。開工前，以及遇到不合理的失敗（測試連環失敗、匯出版行為不同、工具卡住）時，先搜尋這份檔案。
- 新的坑寫進 `prototypes/LESSONS.md` 對應主題的最後一行，格式與重複時的標記方式見該檔開頭；只屬於單一原型的調校寫在該原型的文件，再到「各原型專屬」表登記。

## Codex model preferences

- The main Codex session uses **GPT-6 Sol** (`gpt-6-sol`) with **max** reasoning effort. It owns planning, shared design decisions, integration, review, and final acceptance.
- Delegated Codex workers, including Herdr sibling sessions, preferentially use **GPT-6 Luna** (`gpt-6-luna`) with **max** reasoning effort. Pass both the model and effort explicitly when starting a worker; an explicit user override takes precedence.
- Updating this file does not switch a session that is already running. Apply these settings when starting the next session or worker.

## 子代理的成本門檻

- 開啟 subagent 前，先估算由主 session 自行完成與委派的 API 總成本。委派成本包含子代理的輸入／輸出、重複載入上下文，以及主 session 的派工、協調、審查與整合；使用各自模型的費率，不能只比較 token 數。
- 若自行完成的預估成本 **小於委派總成本的 1.2 倍**，就在自己的 session 完成，不特別開子代理。子代理的目的是節省成本；達到門檻才考慮委派，不因為能平行或任務較大就自動開啟。
- 無法合理判斷能達到門檻時，預設自行完成。決定委派時，簡短說明成本估算與預期節省，勿把估算當成實際帳單。
- 此門檻適用於內建 subagent、Herdr sibling session 與其他委派方式，優先於一般性的委派／平行工作偏好；使用者當次明確要求開子代理時，以該要求為準。

## KISS 與分層測試驗收

- **KISS（保持簡單）**：選能解決問題的最簡單做法。不預先抽象、不加用不到的參數／設定／層級，不順手擴大範圍；真的出現重複再抽共用。
- **最低充分證據（minimum sufficient proof）**：只跑足以證明這次改動的那一層測試，不多跑也不少跑。分層只決定跑哪些測試，不免除「完成要有證據」：回報寫明層級、指令與結果。

| 層級 | 情境 | 跑什麼 |
|---|---|---|
| 規劃 | 只寫規劃、設計、文件 | 不測試 |
| L1 | 寫新功能（不碰其他系統） | 只跑該功能的單元測試 |
| L2 | 與其他系統有交互的功能、回修 bug | 單元測試＋簡易回歸（受影響路徑的少量冒煙測試） |
| L3 | 大型任務（跨多系統、里程碑） | 過程中照 L1／L2；使用者手動驗收完成後，才跑完整測試 |

- 層級判不準時取高一層。改 `.tscn`／`.tres` 後的 headless 匯入檢查成本很低，任何層級都照做。
- 各原型的單元測試、簡易回歸與完整測試對應哪些指令，寫在該原型的 README 或 AGENTS.md。

## Source Layout

- `prompts/runtime.md` — the engine-agnostic runtime manifest text
- `asset-gen/` — the asset-generation skill (CLI tools + docs), the one skill every published repo carries
- `engines/babylon.md`, `engines/godot.md`, `engines/bevy.md` — per-engine guides (stack, project sketch, capture recipe, silent-failure traps)
- `publish.sh` — renders a runtime repo with `--engine {godot,bevy,babylon}`, `--agent {claude,codex}`
- `scripts/` — render helpers: `render_dir.py` (token substitution), `generate_codex_metadata.py` (Codex `openai.yaml`)

## Editing Rules

- **debt-commission 的介面基準**：新增或修改對話框與按鈕時，沿用作者已驗收的「銀魂和紙」透明 PNG 與場景元件（`dialogue_box_gintama.tscn`、`gintama_reading_*.tscn`）；它是遊戲唯一的介面外觀，沒有執行時切換。紙框、波紋與櫻花使用整張透明底圖，保留四角與裁切，不重新手繪。文字與功能保持獨立 node；新面板與按鈕也沿用和紙／深藍銀框的處理。

- Do not create or maintain `.claude/skills/` or `.agents/skills/` in this source repo.
- Don't give obvious guidance. The agent is a highly capable LLM, and the deliverable (a recorded video, or a live URL the user watches) surfaces its own mistakes — so keep the guides to what the model can't infer or discover fast.
- When you change or remove a feature, describe the new state on its own terms. Name the new thing as if it were always the design.

## Godot 開發：畫面用 scene 與 node 組成

`prototypes/` 裡的 Godot 專案，畫面與遊戲物件做成 `.tscn` scene，node 放在 scene 裡，讓人能在 2D 編輯器打開、直接拖曳調整位置、大小、文字與顏色。不要在程式裡用 `.new()` 一個個建立整個畫面。

- **版面交給 node**：位置與大小用 anchor、offset 和 Container（VBox／HBox／Grid／Margin）表達，程式不要每幀或每次縮放時改寫 `position`／`size`；否則編輯器裡的調整一執行就被蓋掉。
- **行為交給腳本**：scene 的根 node 掛腳本，用 `%唯一名稱`（Scene Unique Name）取得子 node，在 `_ready` 連接 signal。
- **重複的東西做成小 scene 再實例化**：選項按鈕、素材卡片、熱區、存檔欄位各做一個 item scene，程式依資料 `instantiate()`。
- **只有必須在執行時決定的才留在程式**：依劇本資料換的內容（哪個角色、哪張背景）、依畫面比例與 Safe Area 的整體縮放、`ui_styles.gd` 依 node 的 `ui_style_role` metadata 套上的和紙配色、特效與動畫。
- **新建或大改 scene 時**，用 Godot 存檔（編輯器，或 headless 腳本以 `PackedScene.pack()` + `ResourceSaver.save()`），不要手寫大型 `.tscn` 文字；存完用 headless 匯入確認沒有錯誤。
- **測試**直接 `instantiate()` scene，用 node 名稱找元件，與執行時的樹一致。
- **交付物包含可編輯的場景樹**：每個主要畫面、戰鬥區與重複物件都有實際的 `.tscn`，不能只交付空的根 node，再由 `_ready()` 建出所有內容。主要 scene 在編輯器未執行時就能看到版面與代表性物件；Theme、StyleBox、靜態文字、顏色與間距留在 scene／resource。
- **產生器只作為製作工具**：scene 儲存後就是可維護的來源檔。正常開啟、執行、匯入與測試不得自動重建它；重新產生前先檢查 diff，保留人工編輯。序列化時驗證 owner、子 scene instance 關係與 pack 前後 node 數量。
- **編輯器驗收**：README 列出主要 scene、可調整的 node／export 欄位。驗證直接修改一個 UI 間距或靜態文字後執行仍然保留，且戰鬥移動、生命值等執行狀態不會反向污染原始 scene。
- **共用模組優先**：新增功能先查 `prototypes/godot-kit/README.md`。適用時用 `sync.sh <project>` 同步並引用現成模組，副本不可直接改；外部套件只在確有需要時引入，記錄來源、版本、授權與匯出限制。
- 現有原型大多仍在程式裡建畫面。改到哪個畫面，就順手把它轉成 scene；debt-commission 的轉換進度記在它的 README「Scene 轉換進度」。
# 全域偏好

  ## 能用圖就用圖

  回答時若內容有「流程、步驟、分支、先後順序、多方關係、架構層次」，
  就在對話中直接畫出文字圖，不要只用文字段落描述。

  怎麼畫：

  1. 用 ASCII／框線字元（`┌ ─ ┐ │ └ ┘ → ↓ ├ ┤`），**不要用 mermaid**
     —— 終端機不會渲染 mermaid，只會變一坨原始碼。
  2. 圖放進 ``` 圍欄（code fence）裡，等寬字才對得齊。
  3. 寬度控制在 80 欄以內。
  4. 畫在對話裡就好，不要為了畫圖去開 Artifact。
  5. 圖是輔助：結論先行那一句不能省，圖擺在結論後面。
  6. 一句話就能答完的問題不用硬畫圖。

<!-- GODOGEN-STUDIO:BEGIN -->
## Game Studios

Read `studio/runtime/codex/CATALOG.md` for the 74 workflows and 49 roles.
Read `studio/runtime/codex/docs/config-resolution.md` before resolving Studio settings.
`project.yaml` controls rigor and automation; start at minimal unless the user specifies otherwise.
Use `studio/runtime/codex/docs/workflow-catalog.yaml` to choose the next workflow.
Read `studio/runtime/codex/rules/*.md` only for the paths in each rule's frontmatter.
Resume from `production/session-state/active.md` when it exists.

## Godogen Studio integration policy

The user's current request and existing project instructions govern this workflow.
Authorization persists across phases: an instruction to implement, fix, or port
authorizes necessary reversible file edits. Resolve routine choices and finish
authorized work before requesting approval for an external or irreversible action.
Apply the project's delegation cost gate before any Agent/team/review dispatch;
when the gate does not justify a worker, perform that role in the main session.
An engine/version/code-root pinned by this project takes precedence over template
examples. Game screens and reusable objects in this repo use editable saved scenes.
Before AI image generation, describe the batch and wait for the user's choice of
direct generation or ready-to-use prompts for opt image. An approved batch needs
no repeated approval. Keep session instructions and final responses in the user's
language. These integration rules take precedence over upstream workflow defaults.

## Codex execution mapping

Use Codex's available file, shell and user-input tools for upstream Read/Glob/Grep/
Write/Edit/Bash/AskUserQuestion steps. Use native custom agents only after the
delegation cost gate; otherwise perform the role locally. Claude tool allowlists,
`@file` imports, model names and `!` inline shell substitutions are not executed
by Codex. Read referenced files explicitly. Run each configuration bootstrap
explicitly with the shell before following the workflow. Use `$skill-name` to
invoke a discovered Codex skill, or read its SKILL.md when using the source catalog.
No workflow changes the active model by editing a rules file.

This is the Godogen generator source. Studio workflow sources live in
`studio/upstream/`; `studio/runtime/` is generated. Source workflows are
loaded by their paths in the catalog. Native skill directories are generated
only for destination game repos. Run game-specific workflows from that game's
root; do not treat all prototypes as one game or pin one engine for this source repo.
For Studio workflows, the catalog is authoritative over legacy `.agents/` copies.
<!-- GODOGEN-STUDIO:END -->
