# 10 — Save & Persistence

## Local First

MVP 使用：

```text
user://save.json
```

或 Godot Resource / binary。

但 schema 必須有 version。

原子寫入沿用 `godot-kit/atomic_file.gd`；讀檔驗證、備份、遷移由遊戲負責。只備份已驗證的舊主檔，禁止用壞主檔覆蓋好 backup。未知較新版本停止覆寫並顯示錯誤；兩份皆損壞須保留檔案並提示，不靜默清空。

---

## SaveData

概念：

```json
{
  "version": 1,
  "last_active_timestamp": 0,
  "currency": {},
  "heroes": {},
  "inventory": [],
  "equipped_items": {},
  "stage_progress": {},
  "runes": {},
  "cube": {},
  "settings": {}
}
```

---

## Autosave

觸發：

- Equip
- Salvage
- Craft
- Rune unlock
- Stage clear
- App background / quit
- 每 60 秒

---

## Migration

SaveManager：

```text
version 1
↓
migration
↓
version 2
```

不要假設 schema 永遠不改。

首版 schema 只實作 timestamp、gold、kills、current stage。加入 inventory／offline 時正式新增版本與遷移測試；上面的 JSON 是完整目標模型，不代表現況已支援。

離線階段另保存 `settled_at`、有效農關快照與 `pending_report`（唯一 ID、時間區間、seed、固定收益）。Collect 的所有增額與消除待領狀態原子提交；詳見 [16](16_implementation_contract.md)。

---

## Item UID

每 ItemInstance 都要有唯一 `uid`。

不能只靠 index。

---

## Recovery

MVP 可保留：

```text
save.json
save_backup.json
```

載入主 save 失敗：

→ 嘗試 backup。

---

## Time Abuse

純單機遊戲不需要做重 anti-cheat。

最多：

- 偵測負 elapsed
- 避免 timestamp overflow
- clamp offline reward

不要把大量時間花在阻止玩家改手機時間。
