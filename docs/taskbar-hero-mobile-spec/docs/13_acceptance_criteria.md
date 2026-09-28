# 13 — Acceptance Criteria

這是完整 MVP 清單，首個可玩檢查點只驗收 [16](16_implementation_contract.md) 的 A。每項完成需指向實際命令、測試或錄影；headless 模擬不算實機效能證據。

## Editor authoring

- [x] Main、AdventureStrip、Unit 與重複 UI 元件交付完整 `.tscn` 節點樹
- [x] 編輯器未執行前可見主要版面與代表性遊戲物件
- [x] UI spacing／靜態文字在 Inspector 修改後，執行不被腳本覆蓋
- [x] 一般啟動、匯入與測試不重建 scene
- [x] 測試實例化實際交付 scene，驗證 unique name、子 scene 與必要節點
- [x] README 列出 scene 入口、資料 resource、共用模組與調整方式

## App

- [ ] Portrait mode 正常
- [ ] 主畫面 60 FPS 目標
- [ ] 不因 100+ inventory item 明顯卡頓
- [ ] Android 可 export

---

## Combat

- [ ] Hero 自動尋敵
- [ ] Hero 自動移動
- [ ] Hero 自動攻擊
- [ ] Hero 自動施放技能
- [ ] Enemy 可以死亡
- [ ] Party 可以 wipe
- [ ] Boss 可挑戰
- [ ] Buff / debuff 至少支援基礎效果

---

## Party

- [ ] 最多 3 Hero
- [ ] Hero 有 level
- [ ] Hero 有 EXP
- [ ] Hero 有 equipment
- [ ] Hero stats 會因裝備更新

---

## Stage

- [ ] 15 stages
- [ ] Wave progression
- [ ] Stage unlock
- [ ] Boss stage
- [ ] Retry
- [ ] Farm previous stage

---

## Loot

- [ ] Chest system
- [ ] 5 rarities
- [ ] Random affix
- [ ] 30 base items
- [ ] Loot table
- [ ] Equipment comparison

---

## Inventory

- [ ] Sort
- [ ] Filter
- [ ] Lock
- [ ] Equip
- [ ] Salvage
- [ ] Auto salvage

---

## Cube

- [ ] Salvage
- [ ] Merge
- [ ] Craft meter
- [ ] Guaranteed craft

---

## Rune

- [ ] 25 nodes
- [ ] prerequisites
- [ ] combat modifiers
- [ ] offline modifiers
- [ ] QoL unlocks

---

## Offline

- [ ] Elapsed time calculation
- [ ] Offline cap
- [ ] EXP reward
- [ ] Gold reward
- [ ] Chest reward
- [ ] Material reward
- [ ] Adventure report
- [ ] 同一 report 領取、退出、重開不重複發獎
- [ ] 無有效農關樣本不虛構離線收益；離線不解鎖新關或新 Boss
- [ ] 0／負數／10 分鐘／12 小時／超過 24 小時邊界有測試

---

## Save

- [ ] versioned save
- [ ] autosave
- [ ] backup save
- [ ] load recovery
- [ ] item UID preserved
- [ ] 損壞主檔不覆蓋有效 backup；未知新版不被自動存檔覆寫
- [ ] 寫入失敗不顯示領取成功、不扣掉待領報告

---

## MVP Definition of Done

一個全新玩家可以：

```text
Start Game
↓
Play with 3 Heroes（B 階段起初始隊伍全數可用）
↓
Auto Battle
↓
Get Chests
↓
Equip Loot
↓
Salvage Bad Loot
↓
Unlock Runes
↓
Close App
↓
Come Back
↓
Receive Offline Loot
↓
Beat Final MVP Boss
```

以上流程不可依賴 debug command。
