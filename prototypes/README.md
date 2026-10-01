# Prototypes

此目錄收錄獨立的設計驗證原型。各原型維護自己的工具鏈、README 與驗證資料，repo 邊界見 [ADR 0001](docs/adr/0001-prototypes-live-in-godogen.md)。Godot 原型之間共用的程式（合成音、原子存檔、headless 測試基底）只在 [godot-kit](godot-kit/README.md) 維護一份，再同步進各原型的 `addons/proto_kit/`。

## 素材生成（Scenario skills）

角色立繪、背景、sprite、UI 圖、音效與 BGM 用已安裝的 Scenario skill 生成，AI 會在需要時自動調用；也可以直接要求，例如「用 scenario-identity-library 幫神樂建一套角色與表情」。這些 skill 由 `npx skills add scenario-labs/skills` 安裝，記在 repo 根目錄的 `skills-lock.json`，Claude（`.claude/skills/`）與 Codex（`.agents/skills/`）都能用。

| 要做的事 | Skill |
|---|---|
| 連線、選模型、查 credits、處理錯誤 | `scenario` |
| sprite、圖示、道具、tileset、UI 按鈕、透明背景 PNG | `scenario-game-assets` |
| 同一角色在不同表情、姿勢、場景保持一致（VN 立繪、怪物進化階段） | `scenario-identity-library`、`scenario-consistency` |
| 走路、待機、攻擊動畫與 sprite sheet | `scenario-sprite-animation` |
| 生圖、改圖、放大、去背 | `scenario-image`、`scenario-image-editing` |
| 音效、BGM、配音 | `scenario-audio` |
| 產出後檢查品質、不合格就重做 | `scenario-quality-gate`、`scenario-refine-loop` |

**使用前要先做一次：**連上 Scenario 的 MCP server。在 Claude Code 執行下面這行，再輸入 `/mcp` 用瀏覽器登入 Scenario 帳號（OAuth，不用貼 API key）：

```bash
claude mcp add --transport http scenario https://mcp.scenario.com/mcp
```

**費用：**每次生成都會用掉 Scenario 帳號的 credits（Creative Units），和 repo 內 `asset-gen`（Gemini／Grok／Tripo3D 另外計費）是不同帳戶。AI 會在第一次付費生成前先問你。宣傳圖、商店頁、預告片等用得到時，再另外挑 skill 安裝（`npx skills add scenario-labs/skills -l` 可列出全部 65 個）。

## 第一人稱互動小說規劃

[Prototype Roadmap](../docs/interactive-fiction/ROADMAP.md)：以現有《消失的草莓牛奶》與銀魂概念為起點，先測試文字雛形，再做 2D 主觀視角改編。和朋友完成短篇後，再根據反覆需要的功能整理製作工具。

## 既有原型

- [Taskbar Hero：遠征紀事](taskbar-hero/README.md)：手機直式 Idle RPG，從可編輯 scene／node 的騎士自動戰鬥開始；[規格與開發狀態](../docs/taskbar-hero-mobile-spec/README.md)。
- [口袋怪獸日記](pixel-monster/README.md)：iOS 優先的直式像素養成遊戲，包含照顧、模擬步行孵化、訓練、NPC 對戰、分歧進化與本機收藏；[iOS CI/CD](pixel-monster/docs/IOS-CICD.md)。
- [消失的草莓牛奶](missing-strawberry-milk/README.md)：本輪互動小說原型；[功能基線](missing-strawberry-milk/QA-BASELINE.md)與[真人試玩計畫](missing-strawberry-milk/PLAYTEST.md)。相關題材詞彙見 [CONTEXT.md](CONTEXT.md)。
- [Anime Card Roguelite](anime-card-roguelite/README.md)：卡牌戰鬥原型，範圍與執行方式見該目錄文件。
- [安](sugarcane-tanks/README.md)：弓箭傳說式的直式房間射擊，丟甘蔗打老鼠、坦克、餐盤怪，從宮廟打到中正紀念堂。《宇智波斑 Survivors》（[PROJECT.md](../docs/survivors/PROJECT.md)）取得版權前的替身，用來驗證自動攻擊、升級疊加與打擊回饋。
- [聖地展望台](seichi-pov/README.md)：手機第一人稱站在展望台上看動畫經典場景，第一站火影岩；驗證程序生成的「粗模型＋烘焙貼圖」浮雕在手機上的辨識度與效能。
- [軌道連珠 Pachinko](pachinko/README.md)：Godot 直式柏青哥機台，驗證「純抽象的幾何演出能不能撐起期待感」；階段見 [ROADMAP.md](pachinko/ROADMAP.md)，詞彙見 [CONTEXT.md](pachinko/CONTEXT.md)。獨立於互動小說路線。
