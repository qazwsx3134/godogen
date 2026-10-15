# Godogen Game Studios

將 [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
移植成 Godogen 的共用開發工作流程。上游版本固定於
`be8993bbc5a1f016bc770b2846ce06272d284526`（framework 1.1.3），MIT 授權。

包含 49 個專業角色、74 個工作流程、13 組規則、39 個主要文件模板，
以及設定解析器、品質檢查、session 復原、角色紀錄與 skill 測試框架。
完整來源與各檔 SHA-256 記在 [provenance.json](upstream/provenance.json)，
授權全文在 [LICENSE](upstream/LICENSE)。執行不需要 GitHub 或額外 API。

## 本 repo 使用

在 Godogen 根目錄執行：

```bash
python3 scripts/install_studio.py --target . --agent codex --source-repo
```

安裝產生 `studio/runtime/codex/CATALOG.md`，供 Codex 按需讀取工作流程；
49 個角色以原生 TOML 放在 `.codex/agents/`，hooks 放在 `.codex/hooks.json`。
`AGENTS.md` 的 Studio 區塊保留其他既有規則。
本來源 repo 的 workflows 使用 catalog 中的檔案路徑；既有 `.agents/skills/`
屬於較早移植，新工作流程以 catalog 為準。
依 repo 規則，新原生 skill 目錄只產生在目標遊戲 repo。

可直接對 Codex 說：「讀取 Studio catalog，執行 settings 工作流程」，
或指定 `studio/runtime/codex/skills/settings/SKILL.md`。
Godogen 是產生器與多個原型的來源；每款遊戲各自保存設計、版本與生產狀態。
來源 repo 的 SessionStart 提供復原資訊，遊戲缺漏檢查在目標遊戲啟用。

新 session 會讀取角色和模型設定；檔案更新不會切換既有 session 的模型。
Codex project layer 必須受信任，hooks 還需要使用者在 `/hooks` 審閱並信任，
這是 Codex 本身的啟用條件；安裝器不修改信任紀錄。
參考 [Codex roles](https://learn.chatgpt.com/docs/agent-configuration/subagents)、
[skills](https://learn.chatgpt.com/docs/build-skills)、
[hooks](https://learn.chatgpt.com/docs/hooks)。

## 發布新的遊戲 repo

```bash
./publish.sh --engine godot --agent codex --studio --out /tmp/my-game
./publish.sh --engine bevy --agent claude --studio --out /tmp/my-bevy-game
```

`--studio` 輸出 Studio 和 Godogen 的 asset-gen skill。
Codex 使用 `$start`、`$settings`、`$dev-story` 等原生 skills，
Claude 使用 `/start`、`/settings`、`/dev-story`。
設定、輕量工作流程和每款遊戲的設計文件由對應工作流程建立；
預設 `minimal`，需要更多設計與 QA 流程時再用 settings 調整。
不帶 `--studio` 時輸出 Godogen 的精簡 runtime。

## 安裝到既有遊戲 repo

```bash
python3 scripts/install_studio.py --target /path/to/game --agent codex --dry-run
python3 scripts/install_studio.py --target /path/to/game --agent codex
```

目標遊戲應已初始化 Git（hooks 的啟動命令使用 Git 根目錄）。
安裝器合併 manifest、Codex config 和 hooks／Claude settings，
保留既有模型、權限、自訂 hooks、skills、設計文件和 project.yaml。
重複安裝可更新安裝器產生且未被人工修改的檔案；遇到人工修改就停止，
顯示衝突檔案，且在衝突检查完成前不寫入任何檔案。
刪除舊版本檔案由維護者審閱；安裝器不清除目標內容。
`publish.sh --force` 是清空目標後重新發布，更新既有遊戲請使用安裝器。

預設新 Codex 設定為主 session `gpt-6-astra`／`max`，
worker `gpt-5.6-luna`／`max`。設定其他預設可使用
`--commander-model`、`--worker-model` 和 `--reasoning-effort`。
既有 config 中的選擇保留；安裝後可直接修改生成的 config／role TOML，
下次安裝會將修改過的 role 設定視為需要審閱的衝突。
Claude 維持其原生角色模型欄位。
執行 team skill 仍須通過本 repo 的委派成本門檻；
未通過時由主 session 按角色完成工作。AI 圖片仍先由使用者選擇
直接生成或取得 opt image prompts。

## 相容性

- Codex roles 是 `.codex/agents/*.toml`；Claude 的 model/tools/maxTurns 欄位
  不會被當成 Codex 設定。Codex 的權限由主 session 繼承。
- Codex skills 的 inline shell bootstrap 轉成明確的 shell 步驟，
  `$skill` invocation 和 `agents/openai.yaml` 由安裝器產生。
- `apply_patch` 支援多檔新增、修改、刪除與 Move to 的 asset 驗證，
  PostToolUse 驗證結果回傳為模型可見的 additionalContext。
- 上游的 Notification hook 未註冊到 Codex；平台通知行為由 host 控制。
  `log-instructions.sh` 保留在套件，依上游設定未自動註冊。
- 設定解析保留 project.local.yaml → project.yaml → legacy → rigor → default
  的優先序。`paths.code_root` 可指定既有專案的程式目錄；
  Godot 已有 project.godot 與 scripts/ 時自動識別。
- 上游的專用 engine workflows 支援 Godot／Unity／Unreal。
  Godogen 的 Bevy／Babylon 使用發布的 engine guide 和通用角色；
  解析器支援 Bevy／Babylon 的 src/，不將 Godot API 套用到其他引擎。
- 採用專案現有引擎版本、場景編輯要求與授權範圍。
  安裝驗證在 Codex CLI 0.162.1 上進行；舊版 CLI 若不支援原生 roles/hooks，
  可依 catalog 手動使用 workflows，或升級 CLI。

## 維護與驗證

`studio/upstream/` 是由完整上游 checkout 產生的 host-neutral 來源，
`.claude` 與 manifest 路徑以 placeholder 保存。相容性修改集中在
`scripts/install_studio.py` 和 `studio/adapters/`。
`studio/runtime/`、`.studio/` 和 `.codex/` 是可重建的輸出。

更新時先 clone 新的 checkout，再匯入另一個暫存目錄比較 diff：

```bash
python3 scripts/import_studio.py --upstream /tmp/ccgs-checkout --out /tmp/ccgs-next
python3 -m unittest discover -s tests -p test_studio.py -v
```

匯入器不連網、不覆蓋既有輸出；完整 skill testing framework
另保存在 `studio/upstream/testing/`。
測試驗證完整角色／skill 引用、設定保留、衝突前置檢查、symlink 範圍、
Codex 多檔 patch 回饋、staged JSON commit gate，以及六種發布組合。
