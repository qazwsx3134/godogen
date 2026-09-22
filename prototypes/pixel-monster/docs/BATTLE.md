# 戰鬥規則與 BattleService

Stage A 的戰鬥是本機單人 NPC 對戰。戰鬥服務不依賴場景或節點，所有輸入與結果都是可 JSON 存檔的 `Dictionary`；UI 只負責播放 `pending_battle.rounds`，不在播放期間重新計算。

## 固定 NPC

資料來源是 `res://data/opponents.json`，`BattleService.opponents()` 每次回傳深拷貝，呼叫端修改回傳值不會污染資料。

| ID | 名稱 | 攻擊 | 防禦 | 敏捷 | HP | 定位 |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `moss_scout` | 苔苔練習生 | 10 | 10 | 9 | 42 | baby 均衡入門 |
| `ember_rival` | 焰尾挑戰者 | 18 | 16 | 17 | 64 | growing 強攻 |
| `bloom_guardian` | 花冠守衛 | 23 | 26 | 21 | 88 | mature 防禦 |

每名 NPC 只有一個代表技能。`skill_chance_percent` 是每名 NPC 每場第一次技能判定的機率，`skill_bonus_percent` 是該次技能對攻擊值的加成；每個角色每場最多使用一次技能，避免隨機技能失控。

## 方針取捨

`begin(state, npc_id, stance, now)` 只接受三種方針，並將修改後的能力寫入玩家快照：

| 方針 | 攻擊 | 防禦 | 敏捷 |
| --- | --- | --- | --- |
| `balanced` 均衡 | ×1.00 | ×1.00 | 不變 |
| `assault` 強攻 | `ceil(×1.15)` | `floor(×0.85)` | +1 |
| `defend` 防守 | `floor(×0.85)` | `ceil(×1.15)` | -1 |

乘算後的攻擊、防禦、敏捷至少為 1；`max_hp` 不受方針改動。方針只作用於這場的快照，不會永久改寫 PetModel 的訓練值。

## 回合解析

服務使用 `seed` 初始化 `RandomNumberGenerator`。seed 在 `begin` 依寵物 ID、NPC、方針、呼叫端 `now` 與 per-state sequence 產生，並連同完整結果立即寫入 `pending_battle`；它不是在載入或 `finish` 時重新產生。

每一筆 `rounds` 是一個行動（最多 12 筆，不是兩個角色各一筆的 UI frame）：

1. 每兩筆行動為一回合。雙方以 `agility + 0..4` 決定該回合的先後手；平手由玩家先動。雙方各出手一次，除非一方先被擊倒；敏捷高不會剝奪對方的所有回合。
2. 命中率以有限閃避計算：`miss_chance = clamp(10 + defender_agility - attacker_agility, 5, 20)`。
3. 命中傷害：`clamp(attack + random(-2..3) + skill_bonus - round(defense × 0.55), 1, 60)`。
4. HP 歸零立即結束；12 筆仍未分勝負時比較雙方剩餘 HP 比例，比例相同為平手。

技能只在該角色尚未使用技能且通過資料中的機率時觸發。落空的技能仍會消耗這場唯一的技能使用次數；`skill` 與 `miss` 會照實記錄。

## API

```gdscript
BattleService.opponents() -> Array
BattleService.begin(state: Dictionary, npc_id: String, stance: String, now: int) -> Dictionary
BattleService.finish(state: Dictionary, now: int) -> Dictionary
BattleService.resolve_battle(player: Dictionary, enemy: Dictionary, stance: String, seed: int) -> Dictionary
```

`begin` 的必要檢查順序包含：玩家有寵物、方針有效、沒有未結算戰鬥、精力至少 12、沒有受傷、生病、睡眠或保護性休眠，以及 NPC ID 存在。這些 battle gate 與 `CareService.can_act(state, "battle", now)` 的條件與繁中 denial copy 保持一致；BattleService 不另造一套可繞過照顧規則的入口。失敗回傳 `ok: false` 且不修改任何 state；成功消耗 12 點精力，遞增 `state.battle_sequence`，並回傳：

```text
{ok: true, message: String, battle: Dictionary}
```

Battle ID 為 `<pet_id>-<四位 sequence>`，例如 `pet-0001`。`pending_battle` 至少固定包含下列欄位：

```text
id: String
seed: int
npc_id: String
npc_name: String
stance: String
player: Dictionary
enemy: Dictionary
rounds: Array
outcome: "win" | "loss" | "draw"
settled: bool
started_at: int
```

`player` 與 `enemy` 是本場快照，不再讀取即時 PetModel。BattleService 唯一以明確 preload 呼叫 `PetModel.stats(pet)`，再做有限值域 sanitization；不讀取 `pet.stats`、`battle_stats` 或自行重算 training，確保 UI 與戰鬥使用同一套能力來源。`balanced` 快照的四個能力欄位會與 `PetModel.stats(pet)` 逐欄相等。

每筆 `rounds` 必須維持此 shape，不以另一種 combat event 取代：

```text
{
  round: int,
  actor: "player" | "enemy",
  damage: int,
  skill: bool,
  miss: bool,
  player_hp: int,
  enemy_hp: int,
  text: String
}
```

`finish` 第一次呼叫會：

- 以已存在的 outcome 更新 `wins`、`losses`、`draws`、`battles` 各一次；
- 將完整 settled battle 放入 `state.battle_history`，並在 `pet.history` 留下摘要；
- 勝負只提供小幅心情回饋，不增加永久攻防，戰敗不會殺死寵物；
- 戰敗且當場 HP 歸零會記錄可療護的受傷狀態；養成健康不會按戰鬥傷害扣除。繃帶療護 30 分鐘可恢復；
- 將 `pending_battle.settled` 設為 `true`，保留整場資料供重播或重開續接。

重複呼叫會回傳 `already_settled: true`，不再增加計數、心情或歷史。新戰鬥只有在上一場已 settled 後才可覆寫 pending；因此呼叫端應在 `begin` 成功後立即保存。

## 驗證

```sh
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path prototypes/pixel-monster \
  --script res://tests/test_battle.gd
```

測試涵蓋三名 NPC schema、seed 同值重算、12 行動上限、rounds shape、方針快照、精力消耗、所有 begin 失敗不變異、重開後 timeline/outcome 不重擲，以及 finish 不重複發獎。
