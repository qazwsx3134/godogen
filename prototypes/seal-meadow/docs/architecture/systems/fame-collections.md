# S19 圖鑑與成就 TDD：單機原型

狀態：2026-10-28，Godot 4.7；玩家規則見 [GDD](../../../design/gdd/fame-collections.md)。

`collection_book.gd` 擁有怪物、成就、稱號表和每個玩家的擊殺／已領狀態。`Main` 將怪物死亡的 scene basename 傳給 `record_kill`；任務、寵物成就分別查 `quests.index`、`pet.stage`。聲望從本版已領成就的定義加總，UI 不自行維護一份可重複加的數值。

`ui/collection_window.tscn` 為可編輯畫面，`achievement_row.tscn` 是重複列。`collection_window.gd` 顯示提示／進度並傳送 `claim(id)`；資料未變時不重建列，避免手指下的按鈕被刪除。`claim` 在背包副本中驗證物品獎勵，再一起提交背包、金幣及已領 id，通知 UI，主場景進行 checkpoint。

`player.save_data` 的 `collection` 記錄 `kills` 與 `claimed`；現行 v6 載入時保留未知 id，沒有 collection 的舊檔以空擊殺／未領開始。任務／寵物以現況判斷。主檔錯誤時沿用保存系統的備份與禁止覆寫政策；此實作不是跨裝置唯一領獎服務。案例與證據見 [QA](../../../production/qa/systems/fame-collections.md)。
