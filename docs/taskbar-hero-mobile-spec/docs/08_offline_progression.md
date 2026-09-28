# 08 — Offline Progression

## Principle

手機版不依賴真正 background combat。

使用 deterministic / statistical offline simulation。

MVP 僅農已通關且已建立有效速率快照的關卡，不解鎖新關、不處理新 Boss 首殺。使用實測各資源速率；不是用單一 Power 猜勝率。可重現抽樣、快照失效與領取原子性以 [16](16_implementation_contract.md) 為準。

---

## Save Snapshot

App 離開前記錄：

```text
last_active_timestamp
current_stage
party_power_snapshot
estimated_kill_rate
loot_modifiers
offline_capacity
```

---

## Reopen

```text
elapsed =
current_timestamp
-
last_active_timestamp
```

Clamp：

```text
effective_elapsed =
min(elapsed, offline_capacity)
```

實際須同時夾住下限 0。時間戳表示已結算邊界；pending report 與邊界一起存檔。領取把收益入帳與移除 pending report 一次提交，存檔失敗不發獎，重啟不得重算同一期間。

---

## Base Capacity

MVP：

```text
12 hours
```

Rune 可提升：

```text
+2h
+2h
+4h
+4h

max 24h
```

---

## Efficiency

初版：

| Reward | Offline Efficiency |
|---|---:|
| EXP | 80% |
| Gold | 80% |
| Material | 70% |
| Chest | 70% |
| New stage / Boss first clear | 0%（線上挑戰） |

數值之後再調。

---

## Simulation

不要：

```text
模擬 8 小時 × 60 FPS
```

要：

```text
kills_per_second
×
effective_seconds
```

例如：

```text
estimated_kills =
floor(kill_rate * seconds)
```

再由 Loot table 批次抽樣。

---

## Offline Report

玩家登入時顯示：

```text
WELCOME BACK

Offline: 7h 42m

Enemies defeated: 1,284
Gold: +38,420
EXP: +128,230

Normal Chest: 42
Elite Chest: 7
Boss Chest: 0

Rare Finds:
- Epic Iron Sword
- Legendary Boots

[Collect]
```

---

## Adventure Narrative

不是只有數字。

可以產生簡短摘要：

```text
Your party farmed your cleared Stage 1-4.
Rewards were calculated from your recorded clear rate.
```

統計式結算沒有模擬角色傷害排名或新 Boss 戰，不生成這類敘述。Rare Finds 只有預先持久化的實際物品才能顯示；尚未開箱時只列寶箱數。

這會讓離線系統有「角色真的去冒險」的感覺。
