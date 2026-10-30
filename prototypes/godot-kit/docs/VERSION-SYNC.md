# 共用模組版本與同步

2026-10-29；現有策略是實體副本，不是套件管理器。

## 同步前

1. 在目標遊戲記錄當前 HEAD、工作區修改及 kit 副本差異；`sync.sh --check <project>` 列出差異分類，不能證明損壞。
2. 將差異分為刻意保留的舊版、遊戲誤改副本、上游修正未採用；逐個模組決定是否採用。未知差異先調查。
3. 確認沒有未保存的人工修改；`sync.sh` 使用 rsync --delete，會整包替換副本。

## 同步與驗收

由 kit 修改共用來源，再對指定遊戲執行同步；不批次更新所有原型。執行受影響模組單元測試與遊戲冒煙測試。scene 資源更動需匯入檢查。失敗時回復本輪同步的差異，保留原有工作區內容。

每次採用在遊戲進度記錄：日期、kit 基準 commit、模組、例外、測試指令與結果。未提交的 kit 來源須附 diff 或雜湊，不能只記 HEAD。

2026-10-29 前次唯讀檢查：debt-commission、hero-horde-idle、seal-meadow 均 drift；未判定各項原因、未同步。各模組採用基準仍待逐項盤點。

## 首次盤點結果（2026-10-29）

可重跑 `python3 prototypes/godot-kit/tools/audit_copies.py debt-commission hero-horde-idle seal-meadow`；加 `--json` 輸出逐檔 SHA-256。工具只讀，不同步。完整快照見 [copy-audit-2026-10-29.json](copy-audit-2026-10-29.json)。數量包含 .uid 與其他實際檔案。

| 遊戲 | 相同 | 共同檔案內容不同 | kit 才有 | 副本才有 |
|---|---:|---:|---:|---:|
| debt-commission | 6 | 2 | 143 | 0 |
| hero-horde-idle | 97 | 1 | 53 | 0 |
| seal-meadow | 106 | 1 | 44 | 0 |

- debt、seal 的 scene_builder 缺上游新增的 open_scene／put，其他內容相同；目前沒有證據是遊戲自行改寫副本。保留現有副本，工具需要新 API 時再採用。
- debt、hero 的 test_kit 缺上游 Logger 腳本錯誤捕捉；直接跑個別測試時不能只看 exit code。使用會檢查 SCRIPT ERROR／Parse Error 的 runner；將來更新 test_kit 時須驗證刻意的腳本錯誤會失敗。
- kit 才有的檔案代表副本未包含那些模組，不代表遊戲缺功能。這份差異只能辨認內容，不能推定歷史採用 commit；不補寫未知版本號。

工具驗證：以 /tmp 四類檔案 fixture 檢查相同、內容變更、來源獨有、副本獨有均可辨識，且副本未變更。三遊戲盤點已重跑；未同步副本。

## 2026-10-30 檢查入口整合

`sync.sh --check` 現在呼叫唯讀 audit_copies，顯示相同、共同檔案內容變更、kit 獨有及副本獨有的數量；同時列出變更／副本獨有的名稱。大量 kit 獨有檔案的完整清單與 SHA-256 用 `python3 tools/audit_copies.py --check --json <project>` 取得（從 kit 根目錄執行）。檢查需要 Python 3。

- 相同時 exit 0；任一目標不同或缺失時 sync.sh exit 1。
- audit_copies 不加 --check 時仍僅輸出盤點，差異本身不改變 exit 0；--check 可與 --json 一起用於自動驗證。
- 支援 prototypes 內名稱及外部遊戲絕對路徑，包含空白。檢查不建立／刪除／覆寫副本。

L2：`python3 prototypes/godot-kit/tools/test_audit_copies.py` 五項隔離 CLI 測試通過；`bash -n prototypes/godot-kit/sync.sh` 通過。涵蓋自動發現、相同、三類差異、JSON／exit code、缺副本、外部含空白路徑、多目標合併失敗及檔案內容／mtime 不變。

實際三專案 `bash prototypes/godot-kit/sync.sh --check debt-commission hero-horde-idle seal-meadow` 仍 exit 1，分類數量與 10-29 盤點一致。log `/tmp/kit-sync-check-20261030.log`。沒有同步遊戲副本，未改遊戲 runtime，沒有重跑 Godot 測試。
