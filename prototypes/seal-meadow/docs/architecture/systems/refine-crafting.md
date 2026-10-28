# S18 精煉 TDD：M3 原型

狀態：2026-10-28，描述現行單機 Godot 4.7 Compatibility；數值與流程以 [GDD](../../../design/gdd/refine-crafting.md) 為準。

## 場景與責任

- `ui/hud.tscn` 的 `BagPanel/BagBox` 保存分頁、可捲動物品與精煉內容；`ItemsTab`、`RefineTab`、`RefineScroll`、`RefineRows` 可直接在編輯器調整。`ui/refine_row.tscn` 為可重複列，保留名稱、材料／機率與確認按鈕。
- `scripts/refine.gd` 擁有本作階梯表、槽位每級加成及 `attempt(player, slot, rng, result, request_seq)`；kit `refine_ladder.gd` 僅依輸入做一次隨機階梯判定。`player.gd` 擁有 `gear`、`bag`、最近請求序號及結果；UI 不自行改裝備或扣料。
- `scripts/inventory.gd` 的 equipment record 使用 `{id,count:1,uid,refine}`。穿脫時先在背包副本試交換，再提交；相同種類的實例各自保留 uid 與精煉值。

## 命令與狀態

首次點擊只記下裝備 uid；二次點擊先確認同一裝備仍穿著，再執行規則。關閉面板／切換分頁清除確認。`attempt` 檢查重送／舊序號、槽位、上限和材料；成功或失敗才記錄 `{ok,level,stone,uid}` 與序號並重算角色屬性。重送最近序號回相同結果，較舊序號回 `stale`；未指定序號使用目前序號 +1。跨進程只有已成功保存的最近結果可重送。

## 保存與遷移

v5 開始在背包及穿戴欄保存各自 uid／refine，另存最近結果與序號；現行 v6 沿用這些欄位。v4 以前每種物品共用的加成遷移到已有的每一件副本，新分配互異 uid；無法驗證的資料不覆蓋，優先讀取有效備份。超過 12 格的背包也視為無效，避免載入時截斷物品。HUD 經 `Main.town_action` 提交整份快照；若寫入失敗會警告，但單機快照與伺服器 durable transaction 的保證不同。

## 驗證與限制

`test_m3.gd` 測階梯、兩次確認、分頁及場景可編輯；`test_m3_hardening.gd` 測多件同款、v4 遷移、重送與備份。經濟工具 `tools/m3_economy.gd` 可注入 seed；[QA](../../../production/qa/systems/refine-crafting.md) 區分模擬與真機證據。沒有多人鎖、伺服器 RPC 或製作系統。
