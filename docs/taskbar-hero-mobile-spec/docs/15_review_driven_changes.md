# 15 — Review-Driven Design Changes

這份文件記錄「為什麼不是照原作原封不動做」。

## 2026-09-27 — 實作前 review

| 問題 | 影響 | 裁定／對應文件 |
|---|---|---|
| 架構列 folder，未要求實際 scene 內容 | AI 容易把整頁寫在 `_ready()`，編輯器無法製作 | 根與本規格 AGENTS、04、13、16 加入 scene 編輯契約 |
| 第一階段與完整 MVP 混用 | 一次引入 15 關、25 符文，未先驗證戰鬥骨架 | 12／14／16 以 A～E 檢查點拆開，A 僅一英雄 |
| timestamp + Collect 沒有交易語意 | 重開可能重領，寫入失敗可能丟獎 | 08／10／16 持久化 pending report、原子 claim |
| offline kill rate、Boss progress 未定義 | Power 無法可靠推算戰鬥，報告可能虛構推王 | 08／16 只農已通關、有實測速率的關卡 |
| +2h +2h +4h 與 24h 上限不一致 | 實作最多只能到 20h | 08／16 補第四個 +4h 節點 |
| Mastery／Formation／Challenge 的範圍不一致 | 後續實作越界 | 11 明確列為 MVP 外；三英雄初始可用 |
| Iron Guardian 的低魔防沒有公式 | 魔法輸出優勢不可實現 | 06／16 補 damage type 與 magic_resistance |
| Auto salvage、Merge 沒保護已穿裝備 | UID 引用可能失效，裝備可能被誤消耗 | 07／16 鎖定和已穿物品都排除 |
| Craft 保底未定義，文案暗示一定變強 | 玩家期待與 RNG 結果不一致 | 07／16 確定成本、部位與 Rare 品質，不承諾屬性升級 |
| UI 基準像素與手指尺寸混用 | 小手機易擠壓底部戰鬥 | 09／16 使用 320×568 最小邏輯畫布，預覽 390×844，兩者實際驗證 |

首版直接使用 repo 的 godot-kit 原子存檔與測試模組；目前無外部下載需求。完整決策和邊界案例集中在 [16](16_implementation_contract.md)。

## 1. Progression Stall

問題：

玩家後期如果只靠極低機率裝備升級，可能長時間看不到進展。

本作調整：

- Hero Level
- Mastery
- Rune
- Cube
- Craft Meter
- Equipment

多條成長軸平行。

---

## 2. Pure RNG

問題：

如果強度完全綁掉寶機率，Bad Luck 等於沒有 Progress。

本作調整：

```text
Random Drop
+
Salvage
+
Merge
+
Craft Meter
```

Loot RNG 提供驚喜。

Craft 提供保底。

---

## 3. Offline Weakness

問題：

手機玩家不會長時間保持 App 在前景。

本作調整：

Offline reward 包含：

- EXP
- Gold
- Materials
- Chests

而不是只提供少量資源。

---

## 4. Inventory Friction

問題：

Idle RPG 掉寶量高，如果逐件處理會很痛苦。

本作調整：

- Sort
- Filter
- Lock
- Multi salvage
- Auto salvage
- Compare

---

## 5. Marketplace Dependency

問題：

多人市場會帶來：

- 經濟平衡問題
- Bot
- Server cost
- Anti-cheat
- Inventory authority

本作為單機，因此全部移除。

---

## 6. Too Little Active Play

問題：

純 Idle 可能缺乏主動遊玩的理由。

本作保留少量 Active layer：

- Boss
- Formation
- Build
- Challenge

但不改變 Auto Battle 核心。

---

## 7. Hard Level Cap

問題：

達到 cap 後 EXP 失去價值。

本作規劃：

```text
Level 1–100
↓
Mastery
```

Mastery 提供低幅度永久成長。

Mastery 屬於 MVP 後，資料結構保留擴充性；MVP 的可持續成長先由 Level、Rune、Cube 與裝備提供。
