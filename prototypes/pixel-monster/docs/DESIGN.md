# Care / time / evolution 設計

本文件描述階段 A 的照顧、時間與成長規則。所有服務都是 `RefCounted`，狀態是可存檔的 `Dictionary`；呼叫端必須傳入 UTC 秒數 `now`。服務不讀取系統時鐘，因此可以在 headless 測試、快轉模式與正常前景恢復共用同一套規則。

本文件的進化門檻是目前已實作行為。下一版已決定改為放置型成長：自然時間可完成所有階段，步數與 Apple 健康 workout 只加速，三次訓練不再是成熟硬門檻。目標規格與遷移方式見 [IDLE-GROWTH.md](IDLE-GROWTH.md)；程式完成前，兩套規則不可混寫成已驗證狀態。

## 範圍與資料

`PetModel.create_state(now)` 建立根狀態；`PetModel.create_pet(now)` 建立幼年芽芽。必備欄位見 `CONTRACT.md`，另有幾個可重算／可顯示欄位：

- `care_timers`：`heal_injury`／`heal_sickness` 到期 UTC 秒數。開始療護不立即移除狀態，倒數完成後才清除受傷或生病。
- `need_events`：`hunger`／`cleanliness` 的未處理事件、累積清醒秒數與 `mistake_recorded`。同一事件只會增加一次 `care_mistakes`。
- `sleep_reason`：`schedule`、`fatigue`、`protective`，區分作息睡眠、疲勞與保護性休眠；保留讀取舊狀態 `manual` 的能力。
- `age_seconds`、`evolution_modifiers`：顯示與存檔快照用；真正的年齡仍由 `born_at` 與傳入時間重算。`history` 會留下 `poop` 與 `sick_start`，讓離線事件順序可觀測。

`last_tick` 是照顧已結算到的 UTC 時間。GameSession 在照顧操作前先呼叫 TimeService；`now <= last_tick` 時不重複結算需求。EvolutionService 依傳入的時間判定進化，不修改這個標記。

## Care API

### `CareService.can_act(state, action, now) -> String`

允許時回傳空字串；拒絕時回傳繁體中文原因。`meal`、`snack`、`clean`、`lights`、`heal_injury`、`heal_sickness`、`train`、`battle`、`wake` 都有明確前置條件。休眠或保護性休眠不會靜默接受一般操作。

### `CareService.perform(state, action, now) -> Dictionary`

回傳 `{ok, message, animation}`，動畫只使用 `eat`、`happy`、`sleep`、`idle`、`heal`。拒絕時完全不修改 state。食物會排入未來排泄事件；清潔清除目前便便；開燈會回到 idle。

「關燈」不是立即睡眠命令：白天且精力高於 `time.fatigue_sleep_threshold` 時只會關燈、保持 `behavior = idle`；符合本地作息或精力低於疲勞門檻才會寫入 `behavior = sleeping`，並以 `sleep_reason = schedule`／`fatigue` 供 UI 觀測。TimeService 同樣只把 `behavior` 的睡眠與作息／疲勞狀態計入睡眠，不會把黑暗房間直接當成睡眠。

Meal 與 clean 只有在數值跨過 `hunger_threshold`／`cleanliness_threshold` 後才清除 `need_events`。例如點心後仍低於飢餓門檻，原本事件與已累積寬限時間會保留，不會重新送一個免費寬限期。

療護流程為：

1. `heal_injury` 或 `heal_sickness` 開始倒數並保留 condition。
2. `TimeService.advance` 按最多 `time.settlement_step_seconds` 的短段，並在 `care_timers[action]` 到期邊界完成療護；也可由同一時間點再次呼叫相同操作完成。
3. 完成會恢復有限健康、移除 timer/cooldown，並留下 `care_complete` history。

### `CareService.train(state, kind, quality, now) -> Dictionary`

`kind` 為 `power`／`guard`／`swift`，`quality` 為 1～3。訓練消耗精力、降低少量體重、留下 history、增加 `training_count`，並依 `balance.json` 的階段上限 clamp 成長值。達上限的訓練仍是一次已完成的訓練，`gain` 會是 0，這讓「成長體完成三次訓練」條件不會被數值上限卡死。

## 離線時間

`TimeService.advance` 的順序固定為（每一短段重複；排泄與療護到期會提早切段）：

1. 先結算短段起點已到期的療護。
2. 依作息／手動睡眠分出睡眠秒與清醒秒；睡眠恢復精力並暫停需求衰減與寬限期。
3. 扣除飽食度與心情，更新 hunger 事件。
4. 將該短段到期的 `poop_queue` 移到 `poop`，再扣清潔度並更新 cleanliness 事件；排泄會留下 `poop` history，不會被整段線性攤平。
5. 事件清醒時間超過 2 小時只記一次照顧失誤；寬限期後未處理需求依 `untreated_health_loss_per_hour` 持續扣健康，低於 `sickness_health_threshold` 時只進入一次 `sick` 狀態並留下 `sick_start` history。
6. 短段結束才結算該邊界到期的療護，確保療護完成時間不會被推到整段 `process_end`。

一般需求最多結算 12 小時。若實際 elapsed 超過 12 小時，12 小時的需求先結算，寵物進入 `conditions.hibernating = true` 的保護性休眠，之後不再自動追扣。年齡與進化不吃這個 cap：`EvolutionService.check` 直接使用傳入的實際 UTC 時間，所以 26 小時的檢查可以一次完成幼年 2 小時與成長 24 小時兩段轉換。

作息用 `settings.sleep_hour`、`wake_hour` 與 `timezone_offset_minutes` 判斷本地小時；預設為 UTC+8 的 22:00～07:00。`sleep_hour == wake_hour` 明確代表關閉排程睡眠，CareService 與 TimeService 共用此規則。`auto_lights` 只控制作息切換時的燈光顯示，不改變作息需求凍結規則。

## 進化與收藏

- 幼年在 `born_at + 7200` 轉成成長體 `bloom`。
- 成長體在 `stage_started_at + 86400` 且 `training_count >= 3` 時具備成熟資格；成熟 transition timestamp 為成長邊界與 history 中第三次有效訓練時間的較晚者。舊存檔缺少足夠 train history 時回退成長邊界，避免捏造時間。
- 成熟分支取最大訓練值；同分固定為 `power > guard > swift`，分別對應 `ember`、`moss`、`breeze`。
- 每次 transition 只寫一筆 `evolutions` 與 history。`EvolutionService.check` 可在一次呼叫中依 deterministic transition timestamp 完成兩段進化，重複呼叫不會追加。
- `PetModel.stats` 將物種、階段、訓練與有限的照顧／睡眠／戰鬥修正合成整數攻擊、防禦、敏捷、最大 HP；修正都有上下界。
- `EvolutionService.archive` 只接受 mature 且沒有未結算戰鬥的個體，深拷貝完整個體與 history 放進 `collection`，清空 `pet` 與 `egg`。GameSession 接著呼叫 `HatchService.start_egg`，在同一筆存檔保存收藏與新蛋。

## Balance schema

`data/balance.json` 是唯一 Care 數值入口，分成 `settings_defaults`、`pet`、`care`、`battle`、`time`、`training`、`evolution` 段。`pet` 也集中初始狀態、stage base stats、species bonus、理想體重與 weight floor；`time` 集中短段秒數、未處理需求健康衰減與生病門檻；`evolution` 集中 branch modifier 與照顧／睡眠／戰鬥 finite modifier。UI 應讀取這份資料顯示 cooldown、stage cap 與提示，不重複寫死數字。fallback 只為檔案缺失時保護 headless domain，不改變公開 API。時間與上限數值可由測試或 debug 設定調整，但 schema/API 名稱不可改動。

## 測試

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --log-file /tmp/pixel-monster-care.log \
  --path prototypes/pixel-monster \
  --script res://tests/test_care.gd
```

`tests/test_care.gd` 覆蓋 schema、拒絕 no-op、療護倒數、訓練上限、12 小時保護、時間倒退、睡眠凍結、短段與小步結算一致性、排泄／療護／疾病順序、持續需求生病與療護恢復、一次需求一次失誤、pending battle 阻擋收藏、兩段一次進化與深拷貝收藏。測試只使用記憶體 state，不會寫入使用者存檔。
