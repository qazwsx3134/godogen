# 浮空劍域：接續狀態

2026-10-24。M0 [RO 戰鬥切片](../../design/ro-slice.md)與 M1 [單層閉環](../../design/m1-loop.md)已完成並提交；下一步是技能串聯（研究中）。

## 分工

- **Claude Code 主導**：規劃、派工、整合、驗收，並負責 `design/` 文件的最終版本。
- **Codex（Herdr pane wT:pH）協作**：只做 Claude 指派的任務，在指定的檔案邊界內工作，交付可 review 的結果。不主動擴充範圍。

## 已確認（使用者）

- 單機、隊長＋兩名 AI；角色永久死亡＋帳號部分傳承（完整版）；Web 桌機與手機橫向。
- 爬塔、任務、農怪、等級與技能熟練度。
- 呈現：RO 式 HD 2.5D（3D 地圖＋HD billboard 角色）。
- 操作：點敵人鎖定並追打、點地移動、WASD、自動狩獵是持續意圖；盾衛和補師不論是否自動都會參戰。
- 順序：先做 RO 戰鬥切片，再依 mechanism-plan 接上機制閉環。
- 切片中隊長倒下只結束本輪，不寫存檔；永久死亡、紀念碑與傳承在 M3 做。

## 主導決定（Claude）

- 模擬步進改為 50 ms，計時器保留餘數（tuning `simulation.step_ms`）。
- 戰鬥規則與數字放在 `domain/`，從 tuning-draft.json 讀取；scene 只負責呈現。
- `.tscn` 不內嵌圖片；角色圖 import 成外部資源後再引用。

## 程式現況（2026-10-24）

- M0 切片可玩：`domain/`（純模擬）＋`game/`／`ui/`（呈現），scene 由 `tools/build_slice.gd` 產生後成為可編輯來源。結構與可調欄位見 README。
- 本作原創 HD 角色 6 名（隊長、盾衛、援護、史萊姆、野豬、獵犬）：原畫與姿勢由 Codex 用 codex-cli 生成、Claude 挑選核准，`art_src/chars/selection.json` 記錄選用的 take，`tools/pack_sprites.py` 打包成 `assets/sprites/*.png`。不使用 hero-horde-idle 的任何圖（使用者：「這個遊戲不是 hero-horde-idle」）。
- 測試：`battle`（15 項規則）、`field:60`（真實輸入與生命週期）、`text`（字型缺字）全數通過。
- 網頁版：3.8 MB，桌機與手機橫向載入無錯誤；直向自動暫停並提示轉向。
- 驗收結果見 `design/ro-slice.md` 末節；未完成：編輯器內手動改值實測、實機 FPS。

## Review 與派工

- 文件 review：`production/reviews/claude-doc-review.md`。C1 節奏試算已採用。
- C2（Codex）：切片交叉 review → `production/reviews/codex-slice-review.md`。R1–R6 全部成立、已修並補回歸測試（同 tick 傷害共同快照、Q 不換鎖定目標、同伴略過不可達目標、暫停時拒收戰鬥指令、重開還原名牌、藥水拒絕原因）；R7 改以實際按鍵狀態清除拖曳；R8 觸控目標全部 ≥104 設計 px（約 44 pt）。Codex 之後額度用完，暫不派工。
- 使用者 2026-10-24：畫面滿意；動作偏僵 → 已加程序化呼吸／彈步／突進／受擊；接下來重心放在功能開發。

## M1（2026-10-24 完成）

- 本機存檔（AtomicFile＋IndexedDB）、Run／Profile 分離、kill receipt、營地（商店／出售／倉庫／委託／換裝）、撤退、守門者、世代交替。驗收見 m1-loop.md 末節。
- 使用者決定：M1 起做本機存檔；版控直接在目前分支 commit（含其他未提交檔案），不開新分支。
- 守門者是低多邊形石像暫代，HD 美術等 Codex 額度恢復。

## 技能串聯（進行中）

- 使用者要求：研究 pokesurvivor.com 的技能聯動，加入本作——學到的技能可以串起來，但不能隨意串聯。
- 研究派給 Herdr pane `psresearch`（Sonnet，max effort），派工單 `.claude/tasks/skybound-blades/r1-pokesurvivor-links.md`，報告寫到 `research/pokesurvivor/2026-10-24-skill-links.md`。
- 報告交回後：Claude 寫 `design/skill-links.md`（本作規則），再實作。

## 下一步

1. 收研究報告 → 設計並實作技能串聯。
2. 使用者手機實機試玩（手感、FPS、按鈕大小）。
3. 第二層與更多技能（implementation-plan M2）。
