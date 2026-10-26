# Systems Index：桌面橫向放置RPG

狀態：Draft／研究與規格提案；建立：2026-10-27。來源概念為使用者提供的桌面橫向放置遊戲描述與[截圖／錄影分析](00-reference-analysis.md)，尚無已核定的獨立遊戲Game Brief。

**狀態範圍**：本表記錄本新案的規格／整合狀態，並非整個repo的實作狀態。既有module、prototype與局部能力的逐系統對照、程式位置、差距及7套測試結果，見[既有基礎盤點](reuse-audit.md)。

## Overview

核心是持續作戰供給資源、管理頁轉化資源、編成決定下一輪效率。以下30個系統涵蓋可見功能及製作必需的隱含服務；每個系統都有獨立草案，明列O／I／P／U、最小範圍、資料、Godot責任、例外與驗收。

S01／S02建立資料與時鐘；S03桌面整合依使用者指示延期；S04表演橫向戰鬥；S05～S10建立個體、數值、AI、扣血、技能與事件反應；S11～S15處理隊伍、羈絆、等級、取得及進化；S16～S18處理裝備、容器與收益；S19～S22提供關卡、天賦、工坊與收藏；S23～S24提供安全保存與條件式離線；S25～S30負責操作資訊、引導、偏好、測量、聲音與長時間品質。

原作未證明的保存實作、離線模型、設定細節及效能服務均為I／P，不宣稱它們是原作內部系統。MVP優先級代表最小可玩子集，後續仍會擴充該系統；S24是條件式提案，若產品不採離線，須明確移除並重估。

目前製作共29個系統；S03保留研究，priority為Deferred，不列入M1～M6。S04／S25／S27／S29／S30皆已移除S03硬依賴，採一般Godot視窗。

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|---|---|---|---|---|---|
| S01 | 資料定義與內容登錄 | Core | MVP | 研究／規格草案 | [S01](systems/s01-content-definitions.md) | — |
| S02 | 模擬時鐘與事件排程 | Core | MVP | 研究／規格草案 | [S02](systems/s02-simulation-clock.md) | S01 |
| S03 | 桌面視窗與工作區整合 | Core | Deferred | 延期／目前不製作 | [S03](systems/s03-desktop-shell.md) | — |
| S04 | 橫向戰鬥帶與場景表現 | Gameplay | MVP | 研究／規格草案 | [S04](systems/s04-battle-presentation.md) | S01 |
| S05 | 夢靈個體、職業與性格 | Gameplay | MVP | 研究／規格草案 | [S05](systems/s05-unit-identity.md) | S01 |
| S06 | 屬性計算與加成來源 | Gameplay | MVP | 研究／規格草案 | [S06](systems/s06-stat-modifiers.md) | S01, S05 |
| S07 | 自動選敵、水平移動與AI | Gameplay | MVP | 研究／規格草案 | [S07](systems/s07-targeting-movement.md) | S02, S06 |
| S08 | 傷害、治療、生命與戰敗 | Gameplay | MVP | 研究／規格草案 | [S08](systems/s08-damage-health-defeat.md) | S02, S06, S07 |
| S09 | 技能、冷卻與自動施放 | Gameplay | MVP | 研究／規格草案 | [S09](systems/s09-skills-autocast.md) | S02, S06, S07, S08 |
| S10 | 關鍵詞、狀態與事件連鎖 | Gameplay | Vertical Slice | 研究／規格草案 | [S10](systems/s10-keywords-reactions.md) | S02, S08 |
| S11 | 隊伍編成與上陣格 | Gameplay | MVP | 研究／規格草案 | [S11](systems/s11-formation.md) | S05, S06 |
| S12 | 種族與屬性羈絆 | Gameplay | Vertical Slice | 研究／規格草案 | [S12](systems/s12-race-element-bonds.md) | S06, S11 |
| S13 | 經驗、等級與天生詞綴 | Progression | MVP | 研究／規格草案 | [S13](systems/s13-xp-innate-affixes.md) | S05, S06 |
| S14 | 夢靈取得、保留與管理 | Economy | MVP | 研究／規格草案 | [S14](systems/s14-acquisition-roster.md) | S05, S17, S18 |
| S15 | 重複夢靈、融煉與進化 | Progression | Alpha | 研究／規格草案 | [S15](systems/s15-duplicate-evolution.md) | S05, S11, S13, S17, S18 |
| S16 | 裝備、穿戴與比較 | Gameplay | MVP | 研究／規格草案 | [S16](systems/s16-equipment.md) | S05, S06, S17 |
| S17 | 背包、倉庫與容量 | Economy | MVP | 研究／規格草案 | [S17](systems/s17-inventory-warehouse.md) | S01 |
| S18 | 掉落、金幣與獎勵交易 | Economy | MVP | 研究／規格草案 | [S18](systems/s18-rewards-economy.md) | S01, S08, S17 |
| S19 | 地圖、關卡、刷圖與首領入口 | Progression | MVP | 研究／規格草案 | [S19](systems/s19-stages-bosses.md) | S01, S08, S18 |
| S20 | 天賦星圖與永久能力解鎖 | Progression | Vertical Slice | 研究／規格草案 | [S20](systems/s20-talent-upgrades.md) | S06, S18 |
| S21 | 工坊、製作與熟練度 | Economy | Alpha | 研究／規格草案 | [S21](systems/s21-workshop-crafting.md) | S17, S18 |
| S22 | 圖鑑、分類、閃光與收藏 | Progression | Alpha | 研究／規格草案 | [S22](systems/s22-codex-shiny.md) | S05, S14, S15, S16 |
| S23 | 存檔、版本遷移與復原 | Persistence | MVP | 研究／規格草案 | [S23](systems/s23-save-migration.md) | S01 |
| S24 | 離線收益、睡眠與補算 | Persistence | Vertical Slice | 研究／規格草案 | [S24](systems/s24-offline-catchup.md) | S02, S08, S18, S19, S23 |
| S25 | 管理介面、提示與資訊層級 | UI | MVP | 研究／規格草案 | [S25](systems/s25-management-ui.md) | S11, S17, S23 |
| S26 | 新手引導與漸進解鎖 | Meta | Vertical Slice | 研究／規格草案 | [S26](systems/s26-onboarding-unlocks.md) | S19, S20, S25 |
| S27 | 設定、可讀性與低打擾模式 | Meta | Alpha | 研究／規格草案 | [S27](systems/s27-settings-accessibility.md) | S23 |
| S28 | 戰鬥紀錄、收益統計與平衡工具 | Meta | Vertical Slice | 研究／規格草案 | [S28](systems/s28-logs-balance-harness.md) | S02, S08, S18 |
| S29 | 音訊、通知聲與聲音優先級 | Audio | Alpha | 研究／規格草案 | [S29](systems/s29-audio-feedback.md) | S27 |
| S30 | 背景效能、長時間運作與品質預算 | Core | Alpha | 研究／規格草案 | [S30](systems/s30-background-performance.md) | S02, S04, S28 |

`Depends On`為強制領域／介面前置，不是所有發生互動的關係。例如S11不依賴天賦介面；天賦提供SlotPolicy效果，再由Application組裝給編成。S23透過快照契約收集owner，領域不反向讀寫檔案。

## Categories

| Category | 系統數 |
|---|---:|
| Core | 4 |
| Gameplay | 10 |
| Progression | 5 |
| Economy | 4 |
| Persistence | 2 |
| UI | 1 |
| Meta | 3 |
| Audio | 1 |

## Priority Tiers

| Priority | 數量 | 對應範圍 |
|---|---:|---|
| MVP | 17 | M1基礎風險原型＋M2完整最小循環 |
| Vertical Slice | 6 | M3策略深度與完整一區demo；S24有條件 |
| Alpha | 6 | M4完整養成與管理，S30完整品質交付於M5 |
| Deferred | 1 | S03桌面整合；未排入目前里程碑 |

Alpha項目不表示到M4才開始想。例如S27在M1就要有退出／還原，S30從M1就量測；優先級標的是完整功能主要交付點。

## Dependency Map

```text
S01資料 ─→ S05個體 ─→ S06屬性 ─→ S07選敵 ─→ S08結算
   │                     │                       │
   ├→ S02時鐘 ───────────┼───────────────────────┤
   │                     └→ S11編成 → S12羈絆    ├→ S09技能
   │                                             └→ S10反應
   ├→ S17背包 ───────────────────────────────→ S18收益
   │               │                              │
   │               ├→ S16裝備                     ├→ S14取得
   │               ├→ S21工坊                     ├→ S19地圖
   │               └→ S15進化                     └→ S20天賦
   └→ S23存檔 ─→ S24離線（也依賴時鐘／結算／收益／地圖）

一般視窗 → S04戰鬥表現／S25管理UI → S26引導
S23 → S27設定 → S29聲音
S02＋S08＋S18 → S28統計 → S30背景品質
取得＋進化＋裝備 → S22圖鑑
```

圖是閱讀摘要，完整依賴以表格／[systems.json](systems.json)為準。完整表已以拓撲排序檢查無環；UI與事件投影可先用契約fixture製作，不能因此改變領域權威。

層次：Foundation（S01；S03延期）、Infrastructure（S02／S05／S17／S23）、Core（數值／作戰／隊伍／收益）、Feature（進階養成）、Presentation（畫面／資訊／聲音）、Operations（長時間品質）。層名方便分工，不表示Presentation必須等所有Feature完成才開始。

## Recommended Design Order

下表是領域契約的無環設計順序，與roadmap的分階段最小實作配合使用。S／M／L為文件與規則相對複雜度，不代表一份文件完成就等於一個系統完成；實際人日以roadmap的工作包粗估為準。

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | S01 資料定義與內容登錄 | MVP | Foundation | Godot Specialist＋Lead Programmer | M |
| 2 | S02 模擬時鐘與事件排程 | MVP | Infrastructure | Godot Specialist＋Lead Programmer | L |
| 3 | S04 橫向戰鬥帶與場景表現 | MVP | Presentation | Godot Specialist＋Lead Programmer | M |
| 4 | S05 夢靈個體、職業與性格 | MVP | Infrastructure | Lead／Systems Designer＋Lead Programmer | M |
| 5 | S06 屬性計算與加成來源 | MVP | Core | Lead／Systems Designer＋Lead Programmer | M |
| 6 | S07 自動選敵、水平移動與AI | MVP | Core | Lead／Systems Designer＋Lead Programmer | M |
| 7 | S08 傷害、治療、生命與戰敗 | MVP | Core | Lead／Systems Designer＋Lead Programmer | L |
| 8 | S09 技能、冷卻與自動施放 | MVP | Core | Lead／Systems Designer＋Lead Programmer | M |
| 9 | S11 隊伍編成與上陣格 | MVP | Core | Lead／Systems Designer＋Lead Programmer | M |
| 10 | S13 經驗、等級與天生詞綴 | MVP | Core | Lead／Systems Designer＋Lead Programmer | M |
| 11 | S17 背包、倉庫與容量 | MVP | Infrastructure | Godot Specialist＋Lead Programmer | M |
| 12 | S16 裝備、穿戴與比較 | MVP | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 13 | S18 掉落、金幣與獎勵交易 | MVP | Core | Lead／Systems Designer＋Lead Programmer | L |
| 14 | S14 夢靈取得、保留與管理 | MVP | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 15 | S19 地圖、關卡、刷圖與首領入口 | MVP | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 16 | S23 存檔、版本遷移與復原 | MVP | Infrastructure | Godot Specialist＋Lead Programmer | L |
| 17 | S25 管理介面、提示與資訊層級 | MVP | Presentation | Godot Specialist＋Lead Programmer | M |
| 18 | S10 關鍵詞、狀態與事件連鎖 | Vertical Slice | Feature | Lead／Systems Designer＋Lead Programmer | L |
| 19 | S12 種族與屬性羈絆 | Vertical Slice | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 20 | S20 天賦星圖與永久能力解鎖 | Vertical Slice | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 21 | S24 離線收益、睡眠與補算 | Vertical Slice | Feature | Lead／Systems Designer＋Lead Programmer | L |
| 22 | S26 新手引導與漸進解鎖 | Vertical Slice | Presentation | Lead／Systems Designer＋Lead Programmer | M |
| 23 | S28 戰鬥紀錄、收益統計與平衡工具 | Vertical Slice | Presentation | Godot Specialist＋Lead Programmer | M |
| 24 | S15 重複夢靈、融煉與進化 | Alpha | Feature | Lead／Systems Designer＋Lead Programmer | L |
| 25 | S21 工坊、製作與熟練度 | Alpha | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 26 | S22 圖鑑、分類、閃光與收藏 | Alpha | Feature | Lead／Systems Designer＋Lead Programmer | M |
| 27 | S27 設定、可讀性與低打擾模式 | Alpha | Presentation | Godot Specialist＋Lead Programmer | M |
| 28 | S29 音訊、通知聲與聲音優先級 | Alpha | Presentation | Godot Specialist＋Lead Programmer | M |
| 29 | S30 背景效能、長時間運作與品質預算 | Alpha | Operations | Godot Specialist＋Lead Programmer | L |

S03不列入上述29個系統的設計順序，沒有自動恢復里程碑。

Agent(s)是角色責任標籤，本次由主session履行，沒有啟動worker或subagent。

## Circular Dependencies

目前硬依賴無環。需要主動保持的邊界：

- 屬性與羈絆：S12產modifier，Application交S06計算；S06不反過來呼叫羈絆。
- 反應與治療：S08產標準事件，S10產新的EffectRequest，由S02排程；禁止互相同步遞迴。
- 隊伍與天賦：共同SlotPolicy傳遞格數，兩個系統不互相查內部state。
- 戰鬥、掉落、升級：標準結果→Application交易協調→下一場build，避免戰鬥直接改Roster或UI。
- 存檔與全部owner：快照介面，save adapter持有序列化責任，領域不依賴實體檔案。

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| S03 | Deferred | 使用者指定先不製作 | 不列入目前技術風險Gate |
| S02／S24 | Technical／Design | 背景與休眠重複或遺失時間 | 單一時鐘、互斥收益區間、模型校準 |
| S08／S10 | Design／Technical | 治療反應無限循環或造成永動隊 | 有界trace、過量治療規則、build矩陣 |
| S17／S18／S23 | Technical | 扣料、發獎、receipt不同步 | 交易與單revision原子快照、故障注入 |
| S14／S15／S21 | Economy | 重複物塞包、成本太高或沒有sink | 資源流／期望成本表、少量配方先測 |
| S22／內容量 | Scope | 從原圖378推成自己也要378隻 | 小內容包，先驗證代表性動作與進化線 |
| S30 | Technical | 長駐耗能與記憶體持續成長 | M1開始量、有限buffer、M5 soak |

## Progress Tracker

| Metric | Count |
|---|---:|
| Total systems identified | 30 |
| 目前製作範圍的研究／規格草案 | 29 |
| 延期研究紀錄 | 1 |
| 正式遊戲GDD核定 | 0 |
| Design docs approved | 0 |
| 本新案已整合並驗收的系統 | 0 |
| MVP正式規格／功能驗收 | 0/17 |
| Vertical Slice正式規格／功能驗收 | 0/6 |

Studio director dispatch本次未執行（solo，且未進入正式核定流程）；沒有第三方或子代理簽核。文件連結、ID與依賴檢查不等於遊戲功能驗收。

## Next Steps

以[roadmap M0／M1](roadmap.md)開始：核定Game Brief與時間政策；先完善S01／S02／S06／S08的實作規格與fixture，在一般視窗整合最小戰鬥。後續每次只補下一里程碑需要的GDD、UX、公式與QA，不要求先完成所有正式文件。
