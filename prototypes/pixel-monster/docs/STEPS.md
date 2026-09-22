# 步行孵化與存檔契約

本文件是 Stage A 的步數 domain 實作說明。所有時間欄位都是整數 UTC 秒；`StepService`、`HatchService`、`SaveService` 不讀取牆上時鐘，呼叫端必須傳入 `now`。

## Provider 介面

檔案：`domain/step_provider.gd`

```gdscript
capabilities() -> Dictionary
permission() -> String
query(state: Dictionary, from_utc: int, to_utc: int) -> Dictionary
```

`query` 的回傳形狀固定包含：

```text
{
  source: String,       # 例如 "mock"、"native"
  status: String,       # ok / partial / denied / unavailable / delayed / error
  coverage: {
    from_utc: int,
    to_utc: int,
    complete: bool,
    known: bool
  },
  buckets: Array[Dictionary],
  today_steps: int | null,
  message: String
}
```

每個 bucket 是一段來源區間的觀測值，不是要直接相加的「本次差值」：

```text
{
  id: String,              # 同一來源的持久識別；重查時必須保持不變
  from_utc: int,
  to_utc: int,
  steps: int,              # 該區間截至本次查詢的權威觀測值，不能為負
  complete: bool
}
```

`StepProvider` 基類的 `source` 是 `native`、`status` 是 `unavailable`，不會捏造 0 步。原生外掛尚未接上時可以直接使用它；UI 必須把 `today_steps == null` 顯示為「無法取得」，不能顯示成確定的 0。

## MockStepProvider

檔案：`domain/mock_step_provider.gd`

```gdscript
add_steps(state: Dictionary, count: int, now: int) -> void
set_mode(state: Dictionary, mode: String, now: int) -> void
```

事件會持久化在 `state.step_debug.events`，而非放在 provider instance，因此存檔、重新建立 provider、模擬重啟後仍得到相同結果。每顆事件含 `at_utc`、`steps` 與 `sensor_epoch`。

支援模式：

| 模式 | 行為 |
| --- | --- |
| `normal` | 完整回傳可查區間的 mock buckets。零步是已知的 0。 |
| `denied` | 回傳 `denied`、無 bucket、`today_steps: null`。 |
| `unavailable` | 回傳 `unavailable`、無 bucket、`today_steps: null`。 |
| `delayed` | 第一次查詢回傳 `delayed`；下一次重查才放出同一份持久事件資料。 |
| `duplicate` | 將每個 bucket 重複回傳一次，驗證消費端不重複入帳。 |
| `reboot` | 增加持久 `sensor_epoch`。重啟前後 bucket ID 不同，後續步數從新 epoch 建立基準，不產生負數或暴增。 |

Mock 的 `today_steps` 是裝置當地日的來源總量，與蛋的進度查詢區間分開；蛋只會從 `started_at` 之後的 bucket 入帳。時區使用 `state.settings.timezone_offset_minutes`，但 bucket 的識別仍以 UTC 日與 sensor epoch 保存。

## StepService 差額與來源規則

檔案：`domain/step_service.gd`

```gdscript
synchronize(state: Dictionary, provider: StepProvider, now: int) -> Dictionary
```

每顆蛋都在 `state.step_ledger` 建立獨立 ledger，核心欄位如下：

```text
{
  version: 1,
  egg_id: String,
  source: String,              # 第一次已知同步後鎖定
  status: String,
  last_source_status: String,
  last_sync: int,
  query_from: int,             # 蛋的 started_at
  query_to: int,
  coverage: Dictionary,
  observed_steps: int,
  buckets: {
    bucket_id: {
      from_utc: int,
      to_utc: int,
      observed_steps: int,     # high-water mark
      credited_steps: int,
      last_seen_at: int,
      complete: bool,
      aliases: Array[String],  # provider 改 ID 後仍指向同一邏輯區間
      sensor_epoch?: int
    }
  }
}
```

同步流程的保證：

1. 以 `max(0, new_observed - old_observed)` 計算每個 bucket 的差額；同一回應內重複的 bucket ID 只取較大的觀測值。
2. 觀測值下降視為來源修正或感測器重置，不回扣已入帳步數，也不因之後重查而製造負數／重複獎勵。
3. `egg.credited_steps` 以 `target_steps` 封頂；超過門檻的差額丟棄，不寫入下一顆蛋。`HatchService.start_egg` 會重置 egg ID 與 ledger。
4. 已鎖定來源後，另一個 source 回傳 `source_conflict`，不把兩來源相加。`unavailable`／`denied`／`delayed` 不會鎖定新來源，也不會改成 0。
5. 每次重查仍從同一顆蛋的 `started_at` 查到傳入的 `now`，所以延遲資料晚到時會以 bucket 差額補入；跨 UTC 日的 buckets 保留在同一顆蛋的 ledger，不會跨日歸零。
6. `status: partial` 可以保存已知 bucket，但回傳 `ok: false`、`today_steps: null`，並保留 coverage 缺口給 UI 顯示；不得宣稱整段已同步。
7. 每個 bucket 都必須滿足 `from_utc >= egg.started_at`、`to_utc <= now`、非負整數步數及完整欄位；越界資料回 `invalid` 且不入帳。
8. 同一 source 的不同 bucket ID 若區間相同或重疊，會合併為一個邏輯區間並保留 `aliases`，以免 provider 改 ID 時雙算。相鄰的不重疊區間仍分開累計。若兩個 bucket 都帶 `sensor_epoch`，只有 epoch 相同才合併；因此 Mock 的手機重啟 epoch 不會被錯誤去重。
9. `coverage` 必須明確提供 `from_utc`、`to_utc`、`complete`、`known`。即使 provider 宣稱 `complete: true`，只要 coverage 沒有涵蓋整個 `[query_from, now]`，有效狀態仍是 `partial`，不會回 `ok`。

成功或部分成功回傳至少包含 `ok`、`message`、`status`、`source`、`coverage`、`today_steps`、`credited_steps`、`credited_delta`、`last_sync`、`egg_id`。`today_steps` 只在 provider 回傳完整且已知的值時為整數。呼叫端可將整份回傳字典拷貝到 `state.step_sync` 供 UI 使用；StepService 本身不擁有 UI snapshot 欄位。

## HatchService

檔案：`domain/hatch_service.gd`

```gdscript
start_egg(state: Dictionary, now: int, kind: String = "starter") -> Dictionary
check(state: Dictionary, now: int) -> Dictionary
use_time_mode(state: Dictionary, now: int) -> Dictionary
```

門檻為 `starter: 500`、`regular: 2000`、`special: 5000`。蛋欄位至少有：

```text
id / kind / started_at / target_steps / credited_steps /
mode (steps | time) / hatched / hatched_at /
time_started_at / time_required_seconds /
step_source / step_coverage / last_sync / step_buckets / step_ledger
```

`start_egg` 在已有 pet 或 egg 時拒絕，不靜默覆寫。`check` 達標時呼叫 `PetModel.create_pet(now)`，先成功建立 pet 才寫入 `hatched: true` 與 `hatched_at`；因此 PetModel 尚未載入時不會留下半孵化狀態。成功 transition 回傳 `hatched: true`，之後再呼叫只回 `hatched: false`。

`use_time_mode` 的規則是「從蛋 `started_at` 起算 24 小時」，不是按下替代模式的時間重算。切換後會清空步數 ledger；時間完成也只建立一次 pet。已孵化蛋會保留為可重播紀錄，必須由 archive 流程清除後才能開始新蛋。

## SaveService

檔案：`domain/save_service.gd`

```gdscript
save(state: Dictionary, path: String = "user://pocket_diary.json") -> Error
load_state(path: String = "user://pocket_diary.json") -> Dictionary
validate_state(state: Dictionary) -> bool
```

`save` 要求 `schema_version == 1`，以及 contract 的完整頂層 state keys。寫入順序是：

1. 驗證純 Dictionary/Array schema，JSON 序列化到 `path.tmp`。
2. `flush()` 並關閉暫存檔。
3. 只有目前 primary 是有效 save 時，才以它更新 `path.bak`；壞 primary 不得覆蓋有效 backup。
4. 使用同一檔案系統的 rename 取代 primary；平台拒絕 replace-by-rename 時才使用有 backup 保護的 fallback。

`load_state` 先讀 primary、解析並驗證；primary 壞掉或 schema 不可用時回復 `.bak`，同時嘗試修復 primary，但永遠保留有效 `.bak`。找不到兩份可用資料時回傳 `{}`。

## 驗證

在 repository root 執行：

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path prototypes/pixel-monster \
  --script res://tests/test_steps_save.gd
```

測試只使用 `/tmp/pixel-monster-steps-save-<pid>.json` 及其 `.bak`／`.tmp`，不會讀寫玩家的 `user://pocket_diary.json`。涵蓋 base provider unavailable、差額與重複回傳、延遲重查、跨日、來源衝突、新蛋基準、超額不轉蛋、模擬重啟、未知不等於 0、蛋前 bucket invalid、same-source 重疊／改 ID 去重、coverage 假 complete 的 partial、一次孵化，以及壞 primary 的 backup recovery。

整合驗收執行完整測試，包含孵化與時間替代模式，不使用 `--skip-hatch`。

原生 iOS CMPedometer、Android Health Connect／感測器外掛仍屬 Stage B；本階段只能宣稱 Mock 核心流程已驗證。
