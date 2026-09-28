# 07 — Loot, Equipment & Economy

## Rarity

MVP 5 階：

```text
Common
Rare
Epic
Legendary
Mythic
```

---

## Item Generation

不要製作數百個獨立 Resource。

使用：

```text
Base Item
+
Item Level
+
Rarity
+
Affix Count
+
Affix Roll
```

例如：

```text
Iron Sword
Lv 18
Epic

Attack +42
Crit +6.2%
Attack Speed +7.1%
```

---

## Affix Count

建議：

| Rarity | Affix |
|---|---:|
| Common | 0 |
| Rare | 1 |
| Epic | 2 |
| Legendary | 3 |
| Mythic | 4 |

---

## Loot Flow

```text
Enemy
 ↓
Chest
 ↓
Loot Table
 ↓
Item / Gold / Material
```

---

## Chest

MVP：

- Normal Chest
- Elite Chest
- Boss Chest

---

## Inventory UX

必須有：

- Sort by rarity
- Sort by power
- Slot filter
- Hero compatibility filter
- Lock
- Salvage
- Multi-select
- Auto salvage

---

## Auto Salvage

Rule：

```text
Common      ON
Rare        OFF
Epic        OFF
Legendary   OFF
Mythic      OFF
```

可由玩家調整。

以上為解鎖後的建議選項；整個 Auto Salvage 預設關閉，玩家確認後才啟用。Locked 與 Equipped item 永不 Salvage 或 Merge。完整的 UID、容量與交易契約見 [16](16_implementation_contract.md)。

---

## Equipment Comparison

UI 必須顯示：

```text
Current
vs
Candidate

Attack       +32
Crit         +1.8%
Attack Speed -2.1%

Estimated Power +2.3%
```

Power 只做輔助。

---

## Cube — Salvage

Item → Material。

例如：

```text
Common → 1 Dust
Rare → 3 Dust
Epic → 10 Dust
```

---

## Cube — Merge

MVP 可以：

```text
5 × Same Rarity
→
1 × Next Rarity
```

不要求相同 base item。

產物 base item 隨機，item level 取素材最低等級；最高 Mythic 不可再升階。必須選五個不同 UID，Locked／Equipped 不可作素材。

---

## Cube — Craft

Material + Progress：

```text
Craft Meter
0 / 100

Salvage item
→
Craft Meter + X

100
→
Guaranteed selected-slot item
```

初版每次 Craft 消耗 100 Dust 與 100 Progress，產出指定 slot 的 Rare 物品；分解同時給予 Dust 與等量 Progress。保證的是指定部位與品質，不保證勝過既有裝備。完整數值見 [16](16_implementation_contract.md)。

---

## Economy Rule

任何垃圾裝都至少有價值：

```text
Bad Item
├─ Salvage
├─ Merge
└─ Craft Progress
```

不能存在完全沒用的掉落。
