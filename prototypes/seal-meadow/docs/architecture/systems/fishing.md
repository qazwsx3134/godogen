# S33 釣魚 TDD：單機原型

狀態：2026-10-28，Godot 4.7；玩家規則見 [GDD](../../../design/gdd/fishing.md)。

`scenes/fishing_spot.tscn` 是可編輯釣點，`ui/fishing_window.tscn` 保存開始／停止及提示節點。`Main` 負責點選、到達距離、開始時區域檢查、取消與 UI；`scripts/fishing.gd` 持有 `active` 和 `ends_at`，不讀牆上時間。`GameClock.now` 只累加前景遊戲時間，主場景每幀呼叫 `poll`；背景事件及玩家受擊會取消，移動、施法或有目標也取消。

`start(now, player)` 僅確認餌與生命並設定結束時間，不保留物品；`poll(now, player, rng)` 結算一次，在背包副本移除餌、抽結果並試加入，全部可行才提交。失敗、停止與重送舊 poll 不變更正式背包；成功後 `Main` 存檔。隨機來源目前共用單機 `combat.rng`，不是安全的多人服務端決定，也不跨進程保存隨機序列。

未完成的釣魚不入存檔；重啟後從未開始狀態恢復。保存成功後餌與產物屬同一快照，若寫入失敗或在 checkpoint 前終止，恢復上次成功保存的狀態。案例與證據見 [QA](../../../production/qa/systems/fishing.md)。
