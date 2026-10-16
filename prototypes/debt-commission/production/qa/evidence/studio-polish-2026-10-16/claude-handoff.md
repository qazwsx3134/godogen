# Claude 交接：source-repo Studio 的 artifact-check 支援獨立 game root

日期：2026-10-16　根目錄：/mnt/d/repo/godot/godogen　未 commit／push

## 原因

source-repo 安裝產生的 `studio/runtime/codex/scripts/artifact-check.sh` 可以傳入 project-root，但 `CATALOG` 用 `$ROOT/studio/runtime/codex/docs/workflow-catalog.yaml` 找，所以會到 game root 底下找 runtime。共用的 Studio 因此檢查不了獨立的 prototype。修正前實際跑出的錯誤：

```
artifact-check: catalog not found at /mnt/d/repo/godot/godogen/prototypes/debt-commission/studio/runtime/codex/docs/workflow-catalog.yaml
```

## 改了哪兩個檔

1. `scripts/install_studio.py`（+8 行）
   - 只在 `source_repo` 且檔案是 `scripts/artifact-check.sh` 時改寫，一般 published-game 的行為不變。
   - 在 `if [ -n "$ROOT_ARG" ]` 之前加一行 `CATALOG_DIR="$(cd "$(dirname "$0")/../docs" && { pwd -W 2>/dev/null || pwd; })"`。
   - `CATALOG` 改成 `"$CATALOG_DIR/workflow-catalog.yaml"`，用 helper 自己的位置找 catalog。
   - `ROOT` 照舊：有給 game root 就用給的 root。
   - 和 Codex 參考 patch 不同的地方：
     - catalog 位置在 `cd` 之前就先算好。原 patch 在不給 root 時，`cd` 到 repo root 之後才算，從子目錄用相對路徑呼叫 helper 就會找錯 catalog。
     - 保留 `pwd -W`，讓 Windows Git Bash 也能用。
2. `tests/test_studio.py`（+19 行）
   - 新增 `test_source_artifact_scan_accepts_an_explicit_game_root`：
     - source install 之後，傳入一個路徑含空格的 game root（`nested game`）跑 helper。
     - 確認 `ROOT` 正確，`engine-setup` 和 `game-brief` 都是 PRESENT，遊戲資料夾裡沒有被複製出 `studio/`。
     - 另外測：不給 root、從子目錄用相對路徑 `../studio/runtime/codex/scripts/artifact-check.sh` 呼叫，`ROOT` 也要正確。
   - 改完之後的 sha256：
     - `install_studio.py` `0486fa8cd52d774bb263e1f22f7ccd43fecd709b8867e9da3a177290a33d40d7`
     - `test_studio.py` `d1c1537a550dee7fca748708c4a0b647ed477e52f7f3e0d11700c07a9ea05c77`

## 測試結果

`python3 -m unittest tests.test_studio -v`：跑了 11 個，全部 OK（107.5 秒），包含新增的 regression test。

## 重新產生 source runtime

- 先跑 `python3 scripts/install_studio.py --target . --agent codex --source-repo --dry-run`：572 個檔案，沒有觸發 ownership guard。
- 正式寫入前另外比對過，installer 合併後的 `AGENTS.md` 和 `.codex/config.toml` 都和現況完全一樣。
- 正式重新產生之後，`git status` 前後沒有差別，只有被 ignore 的 `studio/runtime/` 變了。

## 兩個 game root 的實際 helper 輸出

指令：在各遊戲資料夾執行 `bash ../../studio/runtime/codex/scripts/artifact-check.sh --path minimal "$PWD"`

debt-commission（exit=0）：
```
CATALOG: ../../studio/runtime/codex/docs/workflow-catalog.yaml
ROOT: /mnt/d/repo/godot/godogen/prototypes/debt-commission
STEPS: 5
  STEP: engine-setup required=true repeatable=false check=any_of status=PRESENT alt=1 match=project.yaml
  STEP: game-brief required=true repeatable=false check=glob status=PRESENT count=1
  STEP: create-stories required=true repeatable=false check=glob status=ABSENT glob=production/epics/*/story-*.md
  STEP: implement required=true repeatable=true check=none status=NO_CHECK
  STEP: story-done required=true repeatable=true check=none status=NO_CHECK
```

survivor-series（exit=0）：
```
CATALOG: ../../studio/runtime/codex/docs/workflow-catalog.yaml
ROOT: /mnt/d/repo/godot/godogen/prototypes/survivor-series
STEPS: 5
  STEP: engine-setup required=true repeatable=false check=any_of status=PRESENT alt=1 match=project.yaml
  STEP: game-brief required=true repeatable=false check=glob status=PRESENT count=1
  STEP: create-stories required=true repeatable=false check=glob status=ABSENT glob=production/epics/*/story-*.md
  STEP: implement required=true repeatable=true check=none status=NO_CHECK
  STEP: story-done required=true repeatable=true check=none status=NO_CHECK
```

（`implement` 那一列原本後面還有 note，這裡省略。）兩個遊戲資料夾底下都沒有出現 `studio/`。

## 殘留問題

- `create-stories` 是 ABSENT：兩個遊戲都還沒有 `production/epics/*/story-*.md`，這是工作流程本來的待辦，不是這次的 bug。
- `baseline.json` 記的是改之前的雜湊，以上面的 sha256 為準。
- 照指示沒跑耗時的 Godot 測試。
