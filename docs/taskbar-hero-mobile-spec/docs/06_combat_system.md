# 06 — Combat System

## Goal

Combat 的重點是：

- 好看
- 容易理解
- 自動執行
- Build 差異可被觀察

不是高複雜 AI。

---

## Unit State Machine

```text
IDLE
 ↓
SEARCH_TARGET
 ↓
MOVE
 ↓
ATTACK
 ↓
CAST_SKILL
 ↓
SEARCH_TARGET
```

Dead：

```text
ANY STATE → DEAD
```

---

## Targeting

MVP target priority：

1. 最近敵人
2. Skill 指定 target type
3. Support skill 優先最低 HP ally

---

## Damage Formula

MVP 先簡單：

```text
raw_damage = attack * skill_ratio

mitigation = 100 / (100 + defense)

final_damage = raw_damage * mitigation
```

首版普攻使用 physical 與非負 defense。加入 Mage 技能時，DamageType 分 physical／magic，magic 對應 magic_resistance 並使用同一公式；否則 Iron Guardian 的低魔防設計無法成立。attack_speed 下限 0.1，target 死亡或離開範圍時不可結算攻擊，死亡獎勵只發一次。

Crit：

```text
if random < crit_chance:
    final_damage *= crit_multiplier
```

---

## Attack Speed

```text
attack_interval = 1.0 / attack_speed
```

---

## Cooldown

每個 SkillRuntimeState：

- remaining_cooldown
- skill level
- enabled

---

## Buff / Debuff

MVP 可先支援：

- Attack %
- Defense %
- Attack Speed %
- Damage Taken %
- Heal over Time

資料結構：

```text
effect_id
duration
magnitude
stack_rule
source_id
```

---

## Boss Design

Boss 不是單純高 HP。

MVP 兩隻：

### Boss A — Iron Guardian

目的：

- 測 Physical DPS
- 高 defense
- 低 magic resistance

### Boss B — Grave Summoner

目的：

- 週期召喚小怪
- 測 AoE
- 測後排輸出

---

## Failure

隊伍全滅：

- Stage fail
- 不扣永久資源
- 回到上一個可穩定 farm stage
- Boss challenge 可以 Retry
