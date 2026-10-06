# Godogen Source Repo

This repository is not a published game repo. It is the source that `publish.sh` renders into a runtime game repo for a chosen engine and host agent.

## Codex model preferences

- The main Codex session uses **GPT-6 Sol** (`gpt-6-sol`) with **max** reasoning effort. It owns planning, shared design decisions, integration, review, and final acceptance.
- Delegated Codex workers, including Herdr sibling sessions, preferentially use **GPT-6 Luna** (`gpt-6-luna`) with **max** reasoning effort. Pass both the model and effort explicitly when starting a worker; an explicit user override takes precedence.
- Updating this file does not switch a session that is already running. Apply these settings when starting the next session or worker.

## 子代理的成本門檻

- 開啟 subagent 前，先估算由主 session 自行完成與委派的 API 總成本。委派成本包含子代理的輸入／輸出、重複載入上下文，以及主 session 的派工、協調、審查與整合；使用各自模型的費率，不能只比較 token 數。
- 若自行完成的預估成本 **小於委派總成本的 1.2 倍**，就在自己的 session 完成，不特別開子代理。子代理的目的是節省成本；達到門檻才考慮委派，不因為能平行或任務較大就自動開啟。
- 無法合理判斷能達到門檻時，預設自行完成。決定委派時，簡短說明成本估算與預期節省，勿把估算當成實際帳單。
- 此門檻適用於內建 subagent、Herdr sibling session 與其他委派方式，優先於一般性的委派／平行工作偏好；使用者當次明確要求開子代理時，以該要求為準。

## Source Layout

- `prompts/runtime.md` — the engine-agnostic runtime manifest text
- `asset-gen/` — the asset-generation skill (CLI tools + docs), the one skill every published repo carries
- `engines/babylon.md`, `engines/godot.md`, `engines/bevy.md` — per-engine guides (stack, project sketch, capture recipe, silent-failure traps)
- `publish.sh` — renders a runtime repo with `--engine {godot,bevy,babylon}`, `--agent {claude,codex}`
- `scripts/` — render helpers: `render_dir.py` (token substitution), `generate_codex_metadata.py` (Codex `openai.yaml`)

## Editing Rules

- **debt-commission 的介面基準**：新增或修改對話框與按鈕時，沿用作者已驗收的「銀魂和紙」透明 PNG 與場景元件（`dialogue_box_gintama.tscn`、`gintama_reading_*.tscn`）；它是新安裝的預設風格。紙框、波紋與櫻花使用整張透明底圖，保留四角與裁切，不重新手繪。文字與功能保持獨立 node；新面板與按鈕也沿用和紙／深藍銀框的處理。

- Do not create or maintain `.claude/skills/` or `.agents/skills/` in this source repo.
- Don't give obvious guidance. The agent is a highly capable LLM, and the deliverable (a recorded video, or a live URL the user watches) surfaces its own mistakes — so keep the guides to what the model can't infer or discover fast.
- When you change or remove a feature, describe the new state on its own terms. Name the new thing as if it were always the design.

## Godot 開發：畫面用 scene 與 node 組成

`prototypes/` 裡的 Godot 專案，畫面與遊戲物件做成 `.tscn` scene，node 放在 scene 裡，讓人能在 2D 編輯器打開、直接拖曳調整位置、大小、文字與顏色。不要在程式裡用 `.new()` 一個個建立整個畫面。

- **版面交給 node**：位置與大小用 anchor、offset 和 Container（VBox／HBox／Grid／Margin）表達，程式不要每幀或每次縮放時改寫 `position`／`size`；否則編輯器裡的調整一執行就被蓋掉。
- **行為交給腳本**：scene 的根 node 掛腳本，用 `%唯一名稱`（Scene Unique Name）取得子 node，在 `_ready` 連接 signal。
- **重複的東西做成小 scene 再實例化**：選項按鈕、素材卡片、熱區、存檔欄位各做一個 item scene，程式依資料 `instantiate()`。
- **只有必須在執行時決定的才留在程式**：依劇本資料換的內容（哪個角色、哪張背景）、依畫面比例與 Safe Area 的整體縮放、執行時切換的 UI 風格（`ui_styles.gd` 依 node 的 `ui_style_role` metadata 套色）、特效與動畫。
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
