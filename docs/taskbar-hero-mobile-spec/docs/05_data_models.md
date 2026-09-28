# 05 — Data Models

以下為建議模型，不要求一模一樣，但概念必須保留。

## HeroData

```gdscript
class_name HeroData
extends Resource

@export var id: StringName
@export var display_name: String
@export var base_hp: float
@export var base_attack: float
@export var base_defense: float
@export var magic_resistance: float
@export var base_attack_speed: float
@export var move_speed: float
@export var attack_range: float
@export var skills: Array[SkillData]
```

---

## HeroState

```gdscript
class_name HeroState

var hero_id: StringName
var level: int
var exp: int
var mastery_level: int
var equipment: Dictionary
var skill_levels: Dictionary
```

---

## EnemyData

```gdscript
class_name EnemyData
extends Resource

@export var id: StringName
@export var base_hp: float
@export var base_attack: float
@export var base_defense: float
@export var magic_resistance: float
@export var attack_speed: float
@export var move_speed: float
@export var exp_reward: int
@export var loot_table_id: StringName
```

---

## SkillData

```gdscript
class_name SkillData
extends Resource

enum TargetType {
    SELF,
    SINGLE_ENEMY,
    ALL_ENEMIES,
    LOWEST_HP_ALLY,
    ALL_ALLIES,
    AREA
}

@export var id: StringName
@export var cooldown: float
@export var power_ratio: float
@export_enum("physical", "magic") var damage_type: String = "physical"
@export var target_type: TargetType
@export var range: float
```

---

## ItemBaseData

```gdscript
class_name ItemBaseData
extends Resource

enum Slot {
    WEAPON,
    ARMOR,
    HELMET,
    GLOVES,
    BOOTS,
    ACCESSORY
}

@export var id: StringName
@export var display_name: String
@export var slot: Slot
@export var base_stats: Dictionary
@export var allowed_heroes: Array[StringName]
```

---

## ItemInstance

```gdscript
class_name ItemInstance

var uid: String
var base_item_id: StringName
var item_level: int
var rarity: int
var affixes: Array
var locked: bool
```

---

## Affix

例：

```text
+12% Attack
+6% Critical Chance
+8% Attack Speed
+10% Skill Damage
+5% Cooldown Reduction
```

資料：

```gdscript
class_name AffixRoll

var affix_id: StringName
var value: float
```

---

## StageData

```gdscript
class_name StageData
extends Resource

@export var id: StringName
@export var act: int
@export var stage_index: int
@export var waves: Array[WaveData]
@export var boss_id: StringName
@export var recommended_power: int
```

---

## WaveData

```gdscript
class_name WaveData
extends Resource

@export var enemy_ids: Array[StringName]
@export var counts: Array[int]
```

---

## RuneNodeData

```gdscript
class_name RuneNodeData
extends Resource

@export var id: StringName
@export var cost: int
@export var prerequisites: Array[StringName]
@export var effect_id: StringName
@export var effect_value: float
```
