# 單機跨區、復活與釣魚交互修正

2026-10-30；既有 S07／S33／S34 交互回修，沒有新死亡成本、內容分支或存檔版本。

## 可重現問題

1. 從村莊存檔開啟後死亡，角色回到草原路牌，但 Main.zone 和移動 bounds 仍是村莊；第一步移動會被推回村莊附近，寵物飽足也沿用錯誤區域政策。
2. 傳送淡出等待期間死亡並復活，舊 travel coroutine 仍會在淡出後傳送並存下目的地。
3. 乘坐中成功開始釣魚仍保留乘坐；跨系統狀態沒有收斂。

回歸先紅：`world_lifecycle` 六項、`fishing` 一項失敗，記錄 `/tmp/godot-tests.fhnDuc`。沒有用測試失敗改變既有重生地點或成本。

## 現行規則與責任

- Player 仍在 scene 初始路牌復活、回滿 HP；金幣、經驗、裝備、背包與寵物養成不扣除。重生點不新增選擇或保存欄位，schema 仍 v6。
- Player 在死亡狀態成立後通知 died；復活位置與生命完成後通知 respawned。重複致命傷由現有 dead guard 拒絕，待結算普攻在死亡時取消。
- Main 在 died 清掉按住移動、待拾物／對話／傳送／釣魚及點地標記，遞增本生命週期編號。travel 在淡出後檢查編號；死亡前開始的等待不會搬動復活後角色，會恢復畫面並退出傳送。
- Main 在 respawned 依位置恢復 zone／bounds，相機立即對齊；PetFollower.reset_follow 重定位原本的 entity，然後 checkpoint。寫入失敗／保護仍經既有 save_game 路徑，不繞過保護。
- 成功開始釣魚才下坐；拒絕（如缺餌）不改乘坐。乘坐中止既有釣魚的規則保留。

## 驗證與範圍

L2：`world_lifecycle fishing companions review_interactions`。測村莊保存／重開／死亡／第一步、重複致命傷、相機／跟隨、復活 checkpoint、淡出中死亡、舊傳送不覆寫新位置、再重開；及釣魚成功／拒絕時乘坐狀態。

最新證據見 [QA](../../production/qa/world-lifecycle-2026-10-30.md)。手機實際淡入淡出與觸控仍待人工驗收，不用 headless 結果代替 Safari 證據。
