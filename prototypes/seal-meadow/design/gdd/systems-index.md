# Systems Index: 蓬蓬草原手機版

> **Status**: Draft（規劃草案）
> **Created**: 2026-10-26
> **Last Updated**: 2026-10-26
> **Source Concept**: design/game-brief.md

## Overview

以手機觸控、固定方向／俯角鏡頭與無連招為已確認邊界，保留 Q 版練功、換裝、寵物與回城循環。系統拆成 40 個責任邊界：先驗證單機手機核心，再完成一段可玩的完整循環；多人、擺攤、公會、PvP、營運是後續條件範圍。

本次各 Design Doc 連到 **planning dossier**，其中規則、資料、契約、文件清單與 AC 已列出；不是完整已定案 GDD。Status 一律 In Design，不因舊原型已有部分程式而標 Implemented。正式詳細 GDD 的未建立路徑列在各 dossier。文件進度與功能／真機驗收進度分開。

優先理由：S03/S04 先證明無旋轉的觸控可玩性；S08/S09/S10 讓玩家可打怪；S12/S25 保障每次短遊玩的成長能保存；S13/S15/S17/S18 建立完整切片。UI、音效、效能與保存會從早期做薄切片，不能等所有玩法完成再補。

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | S01 內容定義與資料登錄 (inferred) | Core | MVP | In Design | [S01 內容定義與資料登錄](../planning/systems/s01-content-registry.md) | — |
| 2 | S02 權威狀態、命令與時間 (inferred) | Core | MVP | In Design | [S02 權威狀態、命令與時間](../planning/systems/s02-authority-commands-clock.md) | S01 |
| 3 | S03 觸控輸入與互動優先權 | Core | MVP | In Design | [S03 觸控輸入與互動優先權](../planning/systems/s03-touch-input.md) | S02, S04 |
| 4 | S04 固定鏡頭、構圖與遮擋 | Core | MVP | In Design | [S04 固定鏡頭、構圖與遮擋](../planning/systems/s04-fixed-camera.md) | S01 |
| 5 | S05 世界場景、碰撞與導航 | Core | MVP | In Design | [S05 世界場景、碰撞與導航](../planning/systems/s05-world-navigation.md) | S01 |
| 6 | S06 角色移動、選取與追擊 | Gameplay | MVP | In Design | [S06 角色移動、選取與追擊](../planning/systems/s06-movement-targeting.md) | S02, S03, S05 |
| 7 | S07 屬性、生命、回復與死亡 | Gameplay | MVP | In Design | [S07 屬性、生命、回復與死亡](../planning/systems/s07-stats-vitals-death.md) | S01, S02 |
| 8 | S08 普攻、命中與傷害結算 | Gameplay | MVP | In Design | [S08 普攻、命中與傷害結算](../planning/systems/s08-combat-resolution.md) | S02, S06, S07 |
| 9 | S09 主動技能與狀態效果 | Gameplay | MVP | In Design | [S09 主動技能與狀態效果](../planning/systems/s09-skills-statuses.md) | S01, S02, S07, S08 |
| 10 | S10 怪物 AI、仇恨與生成 | Gameplay | MVP | In Design | [S10 怪物 AI、仇恨與生成](../planning/systems/s10-monster-ai-spawning.md) | S01, S05, S06, S07, S08 |
| 11 | S11 掉落、地上物與拾取 | Economy | MVP | In Design | [S11 掉落、地上物與拾取](../planning/systems/s11-loot-pickup.md) | S01, S02, S05, S08, S12 |
| 12 | S12 物品、背包、貨幣與交易原語 | Economy | MVP | In Design | [S12 物品、背包、貨幣與交易原語](../planning/systems/s12-inventory-transactions.md) | S01, S02 |
| 13 | S13 裝備屬性、紙娃娃與換裝 | Progression | Vertical Slice | In Design | [S13 裝備屬性、紙娃娃與換裝](../planning/systems/s13-equipment-paperdoll.md) | S01, S07, S12, S14, S22 |
| 14 | S14 經驗、職業、技能成長與轉職 | Progression | MVP | In Design | [S14 經驗、職業、技能成長與轉職](../planning/systems/s14-progression-jobs.md) | S01, S02, S07 |
| 15 | S15 NPC、對話與任務 | Narrative | Vertical Slice | In Design | [S15 NPC、對話與任務](../planning/systems/s15-quests-dialogue.md) | S01, S02, S12, S14 |
| 16 | S16 NPC 商店、銀行與城鎮服務 | Economy | Vertical Slice | In Design | [S16 NPC 商店、銀行與城鎮服務](../planning/systems/s16-vendors-bank.md) | S01, S02, S12 |
| 17 | S17 寵物餵食、成長與進化 | Progression | Vertical Slice | In Design | [S17 寵物餵食、成長與進化](../planning/systems/s17-pet-care.md) | S01, S02, S07, S12, S22, S25 |
| 18 | S18 精煉、製作與材料消耗 | Economy | Vertical Slice | In Design | [S18 精煉、製作與材料消耗](../planning/systems/s18-refine-crafting.md) | S01, S02, S12, S13 |
| 19 | S19 聲望、收藏與成就 | Progression | Full Vision | In Design | [S19 聲望、收藏與成就](../planning/systems/s19-fame-collections.md) | S01, S02, S14 |
| 20 | S20 手機 HUD、窗口與提示 | UI | MVP | In Design | [S20 手機 HUD、窗口與提示](../planning/systems/s20-mobile-hud.md) | S01, S03 |
| 21 | S21 小地圖、旅行與區域切換 | UI | Vertical Slice | In Design | [S21 小地圖、旅行與區域切換](../planning/systems/s21-map-travel.md) | S01, S02, S04, S05, S25 |
| 22 | S22 角色美術、方向、動畫與資產管線 | Core | MVP | In Design | [S22 角色美術、方向、動畫與資產管線](../planning/systems/s22-actor-art-animation.md) | S01 |
| 23 | S23 特效、跳字與打擊回饋 | Gameplay | MVP | In Design | [S23 特效、跳字與打擊回饋](../planning/systems/s23-combat-feedback.md) | S04, S08, S22 |
| 24 | S24 音樂、音效與環境音 | Audio | MVP | In Design | [S24 音樂、音效與環境音](../planning/systems/s24-audio.md) | S01, S02 |
| 25 | S25 存檔、設定與手機生命週期 (inferred) | Persistence | MVP | In Design | [S25 存檔、設定與手機生命週期](../planning/systems/s25-persistence-lifecycle.md) | S01, S02 |
| 26 | S26 新手教學、設定、無障礙與文字 | Meta | Vertical Slice | In Design | [S26 新手教學、設定、無障礙與文字](../planning/systems/s26-onboarding-accessibility.md) | S01, S03, S20, S25 |
| 27 | S27 手機效能、測試、工具與匯出 (inferred) | Meta | MVP | In Design | [S27 手機效能、測試、工具與匯出](../planning/systems/s27-performance-build-qa.md) | S01 |
| 28 | S28 帳號、多人權威、AOI 與重連 | Core | Alpha | In Design | [S28 帳號、多人權威、AOI 與重連](../planning/systems/s28-online-authority.md) | S02, S05, S07, S08, S12, S25, S27 |
| 29 | S29 隊伍、聊天與好友 | Meta | Alpha | In Design | [S29 隊伍、聊天與好友](../planning/systems/s29-party-chat-friends.md) | S02, S20, S28 |
| 30 | S30 玩家交易與擺攤 | Economy | Alpha | In Design | [S30 玩家交易與擺攤](../planning/systems/s30-trade-stalls.md) | S12, S16, S28, S29 |
| 31 | S31 公會與公會資源 | Meta | Full Vision | In Design | [S31 公會與公會資源](../planning/systems/s31-guilds.md) | S12, S28, S29 |
| 32 | S32 情侶、雙人互動與表情 | Meta | Full Vision | In Design | [S32 情侶、雙人互動與表情](../planning/systems/s32-relationships-emotes.md) | S07, S22, S28, S29 |
| 33 | S33 釣魚與休閒採集 | Gameplay | Full Vision | In Design | [S33 釣魚與休閒採集](../planning/systems/s33-fishing.md) | S02, S05, S12, S22, S25 |
| 34 | S34 戰鬥寵物、守護者與乘坐 | Gameplay | Full Vision | In Design | [S34 戰鬥寵物、守護者與乘坐](../planning/systems/s34-battle-pets-guarders.md) | S06, S07, S09, S17, S22 |
| 35 | S35 時裝、光環與外觀收藏 | Progression | Full Vision | In Design | [S35 時裝、光環與外觀收藏](../planning/systems/s35-cosmetics-auras.md) | S07, S13, S22, S23 |
| 36 | S36 副本、首領與遭遇導演 | Gameplay | Full Vision | In Design | [S36 副本、首領與遭遇導演](../planning/systems/s36-dungeons-bosses.md) | S05, S09, S10, S11, S15, S28, S29 |
| 37 | S37 決鬥與 PvP 規則 | Gameplay | Full Vision | In Design | [S37 決鬥與 PvP 規則](../planning/systems/s37-duels-pvp.md) | S07, S08, S09, S28, S29 |
| 38 | S38 活動、每日與限時獎勵 | Meta | Full Vision | In Design | [S38 活動、每日與限時獎勵](../planning/systems/s38-events-dailies.md) | S01, S02, S12, S15, S25, S28 |
| 39 | S39 商城、付費與權益 | Economy | Full Vision | In Design | [S39 商城、付費與權益](../planning/systems/s39-commerce.md) | S12, S25, S27, S28, S35 |
| 40 | S40 平衡、遙測、內容工具與營運稽核 (inferred) | Meta | MVP | In Design | [S40 平衡、遙測、內容工具與營運稽核](../planning/systems/s40-balance-telemetry-operations.md) | S01, S02, S27 |

inferred 表示從手機、保存、內容量與後續網路推導出的必要支援責任。UI／特效／資料工具同樣列為系統，但不代表每個系統都需要獨立玩家畫面。

## Categories

| Category | Description | Typical Systems |
|---|---|---|
| Audio | 1 個系統；責任見各工作包 | S24 |
| Core | 7 個系統；責任見各工作包 | S01, S02, S03, S04, S05, S22, S28 |
| Economy | 6 個系統；責任見各工作包 | S11, S12, S16, S18, S30, S39 |
| Gameplay | 10 個系統；責任見各工作包 | S06, S07, S08, S09, S10, S23, S33, S34, S36, S37 |
| Meta | 7 個系統；責任見各工作包 | S26, S27, S29, S31, S32, S38, S40 |
| Narrative | 1 個系統；責任見各工作包 | S15 |
| Persistence | 1 個系統；責任見各工作包 | S25 |
| Progression | 5 個系統；責任見各工作包 | S13, S14, S17, S19, S35 |
| UI | 2 個系統；責任見各工作包 | S20, S21 |

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|---|---|---|---|
| MVP | 手機核心玩法與必要基礎的首版薄切片 | M0–M1 | 先設計前置契約，再做最小可玩 |
| Vertical Slice | 一職業、一草原、一城鎮的完整成長／養成循環 | M2–M3 | 核心可玩後補齊 |
| Alpha | 啟用多人時的權威世界、社交與安全交換 | M4 | M0 定介面；M2 提早技術試驗；M4 完整實作 |
| Full Vision | 後續內容與條件功能集合，不是首發承諾 | M5 | 每分支另決定是否啟動 |

## Dependency Map

下列是初始契約的有向無環圖；重入、事件回饋與後期擴充不是設計順序的反向依賴。S20 消費 view-model、S25 消費保存片段，避免反向依賴所有 gameplay。完整前置與反向消費者已在 dossier／JSON 登記。

```text
內容／建置 → 權威命令／時間 → 觸控／屬性／物品／保存
                     ↓                    ↓
地圖／導航 → 移動／追擊 → 普攻／技能／怪物 → 掉落／成長
                                              ↓
角色／UI／音效 → 換裝／任務／城鎮 → 寵物／精煉 → 完整切片
                                              ↓
                     權威多人 → 隊伍／聊天／交易 → 條件擴充
```

### Foundation Layer 0

- [S01 內容定義與資料登錄](../planning/systems/s01-content-registry.md)：前置 無。

### Contract Layer 1

- [S02 權威狀態、命令與時間](../planning/systems/s02-authority-commands-clock.md)：前置 S01。
- [S04 固定鏡頭、構圖與遮擋](../planning/systems/s04-fixed-camera.md)：前置 S01。
- [S05 世界場景、碰撞與導航](../planning/systems/s05-world-navigation.md)：前置 S01。
- [S22 角色美術、方向、動畫與資產管線](../planning/systems/s22-actor-art-animation.md)：前置 S01。
- [S27 手機效能、測試、工具與匯出](../planning/systems/s27-performance-build-qa.md)：前置 S01。

### Contract Layer 2

- [S03 觸控輸入與互動優先權](../planning/systems/s03-touch-input.md)：前置 S02, S04。
- [S07 屬性、生命、回復與死亡](../planning/systems/s07-stats-vitals-death.md)：前置 S01, S02。
- [S12 物品、背包、貨幣與交易原語](../planning/systems/s12-inventory-transactions.md)：前置 S01, S02。
- [S24 音樂、音效與環境音](../planning/systems/s24-audio.md)：前置 S01, S02。
- [S25 存檔、設定與手機生命週期](../planning/systems/s25-persistence-lifecycle.md)：前置 S01, S02。
- [S40 平衡、遙測、內容工具與營運稽核](../planning/systems/s40-balance-telemetry-operations.md)：前置 S01, S02, S27。

### Contract Layer 3

- [S06 角色移動、選取與追擊](../planning/systems/s06-movement-targeting.md)：前置 S02, S03, S05。
- [S14 經驗、職業、技能成長與轉職](../planning/systems/s14-progression-jobs.md)：前置 S01, S02, S07。
- [S16 NPC 商店、銀行與城鎮服務](../planning/systems/s16-vendors-bank.md)：前置 S01, S02, S12。
- [S17 寵物餵食、成長與進化](../planning/systems/s17-pet-care.md)：前置 S01, S02, S07, S12, S22, S25。
- [S20 手機 HUD、窗口與提示](../planning/systems/s20-mobile-hud.md)：前置 S01, S03。
- [S21 小地圖、旅行與區域切換](../planning/systems/s21-map-travel.md)：前置 S01, S02, S04, S05, S25。
- [S33 釣魚與休閒採集](../planning/systems/s33-fishing.md)：前置 S02, S05, S12, S22, S25。

### Contract Layer 4

- [S08 普攻、命中與傷害結算](../planning/systems/s08-combat-resolution.md)：前置 S02, S06, S07。
- [S13 裝備屬性、紙娃娃與換裝](../planning/systems/s13-equipment-paperdoll.md)：前置 S01, S07, S12, S14, S22。
- [S15 NPC、對話與任務](../planning/systems/s15-quests-dialogue.md)：前置 S01, S02, S12, S14。
- [S19 聲望、收藏與成就](../planning/systems/s19-fame-collections.md)：前置 S01, S02, S14。
- [S26 新手教學、設定、無障礙與文字](../planning/systems/s26-onboarding-accessibility.md)：前置 S01, S03, S20, S25。

### Contract Layer 5

- [S09 主動技能與狀態效果](../planning/systems/s09-skills-statuses.md)：前置 S01, S02, S07, S08。
- [S10 怪物 AI、仇恨與生成](../planning/systems/s10-monster-ai-spawning.md)：前置 S01, S05, S06, S07, S08。
- [S11 掉落、地上物與拾取](../planning/systems/s11-loot-pickup.md)：前置 S01, S02, S05, S08, S12。
- [S18 精煉、製作與材料消耗](../planning/systems/s18-refine-crafting.md)：前置 S01, S02, S12, S13。
- [S23 特效、跳字與打擊回饋](../planning/systems/s23-combat-feedback.md)：前置 S04, S08, S22。
- [S28 帳號、多人權威、AOI 與重連](../planning/systems/s28-online-authority.md)：前置 S02, S05, S07, S08, S12, S25, S27。

### Contract Layer 6

- [S29 隊伍、聊天與好友](../planning/systems/s29-party-chat-friends.md)：前置 S02, S20, S28。
- [S34 戰鬥寵物、守護者與乘坐](../planning/systems/s34-battle-pets-guarders.md)：前置 S06, S07, S09, S17, S22。
- [S35 時裝、光環與外觀收藏](../planning/systems/s35-cosmetics-auras.md)：前置 S07, S13, S22, S23。
- [S38 活動、每日與限時獎勵](../planning/systems/s38-events-dailies.md)：前置 S01, S02, S12, S15, S25, S28。

### Contract Layer 7

- [S30 玩家交易與擺攤](../planning/systems/s30-trade-stalls.md)：前置 S12, S16, S28, S29。
- [S31 公會與公會資源](../planning/systems/s31-guilds.md)：前置 S12, S28, S29。
- [S32 情侶、雙人互動與表情](../planning/systems/s32-relationships-emotes.md)：前置 S07, S22, S28, S29。
- [S36 副本、首領與遭遇導演](../planning/systems/s36-dungeons-bosses.md)：前置 S05, S09, S10, S11, S15, S28, S29。
- [S37 決鬥與 PvP 規則](../planning/systems/s37-duels-pvp.md)：前置 S07, S08, S09, S28, S29。
- [S39 商城、付費與權益](../planning/systems/s39-commerce.md)：前置 S12, S25, S27, S28, S35。

## Recommended Design Order

順序先遵守前置，再優先本階段；可在已定介面下交錯設計。角色欄是責任帽，不表示已派代理。S/M/L/XL 是相對複雜度，不換算成天數或 session 承諾。

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|---|---|---|---|---|---|
| 1 | [S01 內容定義與資料登錄](../planning/systems/s01-content-registry.md) | MVP | Contract 0 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 2 | [S02 權威狀態、命令與時間](../planning/systems/s02-authority-commands-clock.md) | MVP | Contract 1 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 3 | [S03 觸控輸入與互動優先權](../planning/systems/s03-touch-input.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 4 | [S04 固定鏡頭、構圖與遮擋](../planning/systems/s04-fixed-camera.md) | MVP | Contract 1 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 5 | [S05 世界場景、碰撞與導航](../planning/systems/s05-world-navigation.md) | MVP | Contract 1 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 6 | [S12 物品、背包、貨幣與交易原語](../planning/systems/s12-inventory-transactions.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 7 | [S20 手機 HUD、窗口與提示](../planning/systems/s20-mobile-hud.md) | MVP | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 8 | [S22 角色美術、方向、動畫與資產管線](../planning/systems/s22-actor-art-animation.md) | MVP | Contract 1 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 9 | [S25 存檔、設定與手機生命週期](../planning/systems/s25-persistence-lifecycle.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 10 | [S27 手機效能、測試、工具與匯出](../planning/systems/s27-performance-build-qa.md) | MVP | Contract 1 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 11 | [S40 平衡、遙測、內容工具與營運稽核](../planning/systems/s40-balance-telemetry-operations.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 12 | [S06 角色移動、選取與追擊](../planning/systems/s06-movement-targeting.md) | MVP | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 13 | [S07 屬性、生命、回復與死亡](../planning/systems/s07-stats-vitals-death.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 14 | [S08 普攻、命中與傷害結算](../planning/systems/s08-combat-resolution.md) | MVP | Contract 4 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 15 | [S09 主動技能與狀態效果](../planning/systems/s09-skills-statuses.md) | MVP | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 16 | [S10 怪物 AI、仇恨與生成](../planning/systems/s10-monster-ai-spawning.md) | MVP | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 17 | [S11 掉落、地上物與拾取](../planning/systems/s11-loot-pickup.md) | MVP | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 18 | [S14 經驗、職業、技能成長與轉職](../planning/systems/s14-progression-jobs.md) | MVP | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 19 | [S23 特效、跳字與打擊回饋](../planning/systems/s23-combat-feedback.md) | MVP | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 20 | [S24 音樂、音效與環境音](../planning/systems/s24-audio.md) | MVP | Contract 2 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 21 | [S13 裝備屬性、紙娃娃與換裝](../planning/systems/s13-equipment-paperdoll.md) | Vertical Slice | Contract 4 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 22 | [S15 NPC、對話與任務](../planning/systems/s15-quests-dialogue.md) | Vertical Slice | Contract 4 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 23 | [S16 NPC 商店、銀行與城鎮服務](../planning/systems/s16-vendors-bank.md) | Vertical Slice | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 24 | [S21 小地圖、旅行與區域切換](../planning/systems/s21-map-travel.md) | Vertical Slice | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 25 | [S26 新手教學、設定、無障礙與文字](../planning/systems/s26-onboarding-accessibility.md) | Vertical Slice | Contract 4 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 26 | [S17 寵物餵食、成長與進化](../planning/systems/s17-pet-care.md) | Vertical Slice | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 27 | [S18 精煉、製作與材料消耗](../planning/systems/s18-refine-crafting.md) | Vertical Slice | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 28 | [S28 帳號、多人權威、AOI 與重連](../planning/systems/s28-online-authority.md) | Alpha | Contract 5 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | XL |
| 29 | [S29 隊伍、聊天與好友](../planning/systems/s29-party-chat-friends.md) | Alpha | Contract 6 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 30 | [S30 玩家交易與擺攤](../planning/systems/s30-trade-stalls.md) | Alpha | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | XL |
| 31 | [S19 聲望、收藏與成就](../planning/systems/s19-fame-collections.md) | Full Vision | Contract 4 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 32 | [S31 公會與公會資源](../planning/systems/s31-guilds.md) | Full Vision | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 33 | [S32 情侶、雙人互動與表情](../planning/systems/s32-relationships-emotes.md) | Full Vision | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 34 | [S33 釣魚與休閒採集](../planning/systems/s33-fishing.md) | Full Vision | Contract 3 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 35 | [S34 戰鬥寵物、守護者與乘坐](../planning/systems/s34-battle-pets-guarders.md) | Full Vision | Contract 6 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 36 | [S35 時裝、光環與外觀收藏](../planning/systems/s35-cosmetics-auras.md) | Full Vision | Contract 6 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | M |
| 37 | [S36 副本、首領與遭遇導演](../planning/systems/s36-dungeons-bosses.md) | Full Vision | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | XL |
| 38 | [S37 決鬥與 PvP 規則](../planning/systems/s37-duels-pvp.md) | Full Vision | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 39 | [S38 活動、每日與限時獎勵](../planning/systems/s38-events-dailies.md) | Full Vision | Contract 6 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | L |
| 40 | [S39 商城、付費與權益](../planning/systems/s39-commerce.md) | Full Vision | Contract 7 | Lead Game Designer／Lead Systems Designer／Godot Specialist／Lead Programmer（本 session） | XL |

## Circular Dependencies

初始前置圖經程式拓樸排序，40／40 可排序，未發現循環。已處理的常見潛在循環：

- 戰鬥／AI：AI 發命令，CombatService 回事件，不互相直接扣血。
- 背包／任務：任務讀查詢與消費事件，發獎走 transaction，不讓背包硬依賴任務。
- 裝備／角色：domain 裝備解析結果交 ActorView，ActorView 不反算屬性。
- feature／保存：feature 提供有版本片段，repository 保存 envelope，避免 S25 直接依賴所有 feature。
- feature／HUD：UI 消費 state/event，不成為遊戲規則的前置權威。

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|---|---|---|---|
| S03/S04/S05 | UX／關卡 | 固定鏡頭遮擋、點選誤觸 | M0 灰盒真機，改場景與輸入 |
| S12/S25 | 資料 | 物品複製、半套提交與手機背景保存 | 先定交易／保存契約，失敗與終止測試 |
| S13/S22 | 美術／效能 | 紙娃娃方向、換裝 atlas 與 overdraw | M2 前比較兩裝備，先驗後量產 |
| S28/S30 | 架構 | 權威多人與原子交換返工 | M0 邊界；M2 雙 client 試驗；M4 完整結算 |
| S27 | 平台 | 目標機／原生 Web 未定，效能無基準 | 在依賴它的開工前選平台／機型 |
| S31–S39 | 範圍 | 參考遊戲所有功能被當首發要求 | M5 每分支單獨啟動，維持條件範圍 |

## Progress Tracker

| Metric | Count |
|---|---|
| Total systems identified | 40 |
| Planning dossiers written | 40 |
| Full detailed system GDDs authored in this task | 0 |
| Design docs reviewed by independent role | 0 |
| Design docs approved | 0 |
| Mobile system acceptance completed in this task | 0 |
| Runtime implementation changes in this task | 0 |

TD-SYSTEM-BOUNDARY、PR-SCOPE、CD-SYSTEMS：依 solo 模式與成本規則未派代理；本次僅在主 session 做依賴與文件一致性檢查，不冒充獨立評審。

## Next Steps

1. 依[roadmap](../../production/roadmap.md)先補 M0 的平台決策與可實作契約。
2. 依[文件契約](../planning/document-contracts.md)把要開工的系統從 Planning Draft 補到 Ready。
3. 先完成固定鏡頭／觸控／權威與物品／保存的薄切片，再進 M1。
4. 每階段以證據更新狀態，未有真機就保留未驗證。
