# S17 寵物照護 TDD：M3 原型

狀態：2026-10-28，描述現行單機 Godot 4.7 Compatibility；玩法規則與試調值以 [GDD](../../../design/gdd/pet-care.md) 為準。

## 場景與責任

- `scenes/main.tscn` 擁有玩家、`%GameClock`、`%HUD` 與 `scenes/pet_follower.tscn` 的 `%Pet`。跟隨者可在 scene 調整 `follow_distance`、`speed`；`pet_follower.gd` 只更新位置、動畫方向和名稱。
- `scripts/pet_rules.gd` 是本作只讀配置；kit `pet_care.gd` 實作飽足、經驗及進化，不修改 kit 副本。`player.gd` 持有寵物狀態、背包、寵物 RNG 與屬性，對外提供 `feed_pet(id, result)`、`evolve_pet(result)`。
- `ui/hud.tscn` 的 `PetPanel`、`PetInfo`、`FeedRows`、`EvolveButton` 是可編輯節點；`hud.gd` 將規則狀態顯示成食物列並控制二次確認，重複列實例化 `ui/item_row.tscn`。

## 命令、時間與交易

`feed_pet` 先驗證食物與扣一個，再呼叫 `pet.feed`，重新計算屬性並發 `stats_changed`；目前寵物固定存活，無獨立的重送 id。`evolve_pet` 先檢查 `can_evolve()`，在複製的背包移除所有材料，任何不足都不提交；提交後抽取結果並重新計算屬性。HUD 完成動作後 `Main.town_action` 做存檔與回饋。

`Main._process(delta)` 將當前區域交給 `pet.tick`；GameClock 背景時暫停遊戲樹，恢復前延遲幀排除背景大 delta。餓到底的 HUD 訊息以結算前後經驗差顯示實際損失。跟隨呈現不是資料權威，不決定餵食與加成。

## 資料生命週期

`player.save_data()` 把 `pet.to_dict()` 包進現行 v6 快照。v1～v3 缺寵物時用預設；載入驗證型別並約束支援的階級、等級、類型與食物。主檔無效時回退有效備份；無有效檔或較新 schema 時停止覆寫。寵物 RNG 狀態未跨進程保存，網路重送、分散式權威及伺服器持久化不在此單機契約。

## 驗證與限制

`test_m3.gd` 覆蓋餵食、飢餓、城鎮／背景、進化及存讀；`test_m3_hardening.gd` 覆蓋進化二次確認與背景操作。對應案例和當前證據見 [QA](../../../production/qa/systems/pet-care.md)。專屬動畫／音效、手機長測與真機切背景仍待驗證。
