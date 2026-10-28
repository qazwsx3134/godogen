# S19 QA 與證據

2026-10-28；[GDD](../../../design/gdd/fame-collections.md) 是本機試調規則。

| AC | 案例／證據 | 狀態 |
|---|---|---|
| AC-S19-01 | `tests/test_collection.gd`：領獎去重、重啟後不重領、滿包不提交物品／聲望 | 本次 headless PASS |
| AC-S19-02 | `test_collection.gd`：未發現怪物提示、成就條件／進度顯示 | 本次 headless PASS；真機可讀性未驗 |
| AC-S19-03 | `test_collection.gd`：舊檔不推測擊殺，現有任務／寵物狀態可算，未知 id 保留 | 本次 headless PASS |

尚需 iPhone 觸控、長內容捲動、背景恢復及真實遊玩節奏；沒有宣稱帳號／多人領獎安全。
