# 09 — Mobile UI / UX

## Orientation

Portrait-first。

設計基準可先用：

```text
390 × 844（預覽視窗）
320 × 568（最小邏輯畫布）
```

再透過 anchors / containers 適配。

兩種尺寸都驗證；stretch canvas_items / expand 使用最小邏輯畫布，避免小螢幕再等比縮小文字與按鈕。1080 × 1920 作美術輸出參考；觸控元件至少 48 邏輯單位。上方內容可捲動，底部戰鬥與主要操作仍可見。Safe Area 在外層套用，不逐一覆寫子 node 的版面；首版桌面比例測試不等於實機瀏海驗證。

---

## Persistent Adventure Strip

所有主要畫面下方都保留：

```text
┌──────────────────────┐
│                      │
│    Current Screen    │
│                      │
├──────────────────────┤
│ 🛡️ 🧙 🏹 → 👹 👹  │
│ Stage 2-4 Wave 7/10  │
└──────────────────────┘
```

這是本作重要識別。

---

## Main Tabs

MVP：

- Adventure
- Heroes
- Gear
- Cube
- Rune
- Map

以上為完整 MVP 導覽；Foundation 只顯示已實作的冒險概況／騎士資料與可用操作。加入功能時才加入對應入口，不先放六個無行為按鈕。

---

## Adventure Screen

顯示：

- Current stage
- Wave
- Boss progress
- Party
- Gold
- EXP
- Chest count
- Fast access to collected rewards

---

## Hero Screen

每 Hero：

- Level
- Mastery（MVP 後才顯示）
- Main stats
- Equipment
- Skills
- Role

---

## Gear Screen

- Equipment slots
- Inventory
- Filters
- Compare
- Equip
- Lock
- Salvage

---

## Cube Screen

3 tabs：

- Merge
- Salvage
- Craft

---

## Rune Screen

可以先做簡單 Graph / Tree。

每 node 顯示：

- Cost
- Effect
- Prerequisite
- Unlocked state

---

## Offline Report Modal

App resume 時第一個出現。

但允許：

- Collect all
- Skip animation

不要強迫長動畫。

---

## Touch Targets

盡量 >= 44pt / 約 48dp。

避免：

- 小 icon
- hover-only interaction
- 太密集裝備格
