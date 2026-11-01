# 存檔載入、備份恢復與寫入保護

2026-10-31；schema 仍為 v6，既有 v1～v5 遷移不變。此輪處理載入與寫入的信任邊界，不調整養成數值。

## 已修正的路徑

遊戲已開啟後，主檔可能被另一版本或外部操作替換。既有只在啟動時判斷版本的做法，會讓背景／進度存檔覆寫新檔，甚至把它旋轉進備份後再覆蓋。另一條路徑是啟動已選定有效備份，寫入前主檔又被替換，舊恢復流程仍會直接把主檔換回去。

現在每次保存先檢查待寫入快照，再核對現有主檔與備份版本；備份恢復還會核對當時主檔／備份的完整 bytes。拒絕時主檔及備份保持原樣，訊息欄顯示停止寫入，`save_blocked_reason` 保留原因；本次遊戲不再嘗試覆寫。需確認外部檔案或修正資料後重開，不自動解除保護。

```text
載入 → envelope／遷移／payload 驗證 → 主檔或有效備份
保存 → 驗證快照 → 核對檔案 → 必要時恢復備份 → 原子保存
                         └ 異常／版本不相容 → 保留兩檔、停止寫入
```

## 責任與相容

- `scripts/save_store.gd`：本遊戲的版本外層讀取與驗證、逐版遷移、payload 驗證及備份選擇。JSON 的數值版本可為整數型或整數值 float；字串、bool、缺少版本及非整數不強制轉成可讀版本。大於 v6 的值（包含 6.5）拒絕為 newer，不藉由讀舊備份降版。
- `scripts/save_validation.gd`：沿用現有欄位／背包容量／裝備 UID／外觀資格等檢查；主檔／備份遷移後和待寫入快照共用此檢查。
- `Main`：擁有保護狀態；保存前檢查新版本備份、有效主檔；恢復時只使用啟動選定且仍未變更的 bytes。先驗快照，才允許恢復或旋轉備份。
- kit `save_slots.gd`／`atomic_file.gd`：保留原有 JSON 封裝、備份旋轉與原子檔案寫入。沒有修改 kit 來源或副本，也沒有同步其他原型。
- 主檔有效時，既有壞備份可照常由有效主檔取代；較新版本的備份會阻止旋轉。啟動主檔有效時仍優先讀主檔，但保存前會核對備份版本。

## 最低充分驗證

修正前 `save_protection` 已重現覆寫與非法版本路徑（`/tmp/godot-tests.ELMiQg`）。修正後 L2 `save_protection m3_hardening world_lifecycle` 三組全部 PASS（`/tmp/godot-tests.ClMJR5`）。包含有效初存／備份、外部替換較新版本／破損 JSON／空檔／異常 payload、備份恢復競態、較新備份、非法待寫入快照，以及既有舊版遷移／有效備份恢復／精煉與跨區復活。

命令（repo 根目錄）：

```bash
env XDG_DATA_HOME=/tmp/seal-saveguard-data XDG_CONFIG_HOME=/tmp/seal-saveguard-config TEST_TIMEOUT=120 bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow save_protection m3_hardening world_lifecycle
```

沒有修改 scene。editor 匯入仍有沙箱 TCP 監聽錯誤；未見 SCRIPT ERROR／Parse Error。完整 L3 仍等使用者手動驗收。

## 實際限制

這是本機同步存取前的檢查，沒有 OS 檔案鎖；不保證另一程序恰好在檢查後、原子提交前寫入的競態。既有 payload validator 不等於全部遊戲規則的完整 schema 或防作弊；同版本、通過驗證的外部替換沒有衝突合併。沒有新增 Web 多分頁協調或存檔加密。

最新手機候選與匯出證據見 [10-31 產物報告](../production/qa/mobile-candidate-2026-10-31.json)；桌面 PCK 冒煙不等於 Web／IndexedDB 或 iPhone 真機驗證。

最後補查舊版相容：同一 save_protection suite 加入 v1～v6 逐版成功載入／保存、非法外層從有效備份恢復，以及恢復期間同版本備份被替換時兩檔保留，單獨重跑 PASS（`/tmp/seal-saveguard-final-positive.log`）。命令：`env XDG_DATA_HOME=/tmp/seal-saveguard-data XDG_CONFIG_HOME=/tmp/seal-saveguard-config timeout 120 godot --headless --path prototypes/seal-meadow --script res://tests/test_save_protection.gd`。只補測試，runtime／候選未改；其他兩組沿用本輪 ClMJR5 通過證據。
