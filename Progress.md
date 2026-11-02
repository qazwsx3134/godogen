# 進度總覽

只記最近幾次 commit 做了什麼，以及各專案的入口。細節寫在各專案的 `PROGRESS.md`（只放最近 3 次 commit 期間與尚未 commit 的工作）；更早的紀錄在同目錄的 `MILESTONE.md`。

- **接手**：先讀本檔，再讀該專案的 `PROGRESS.md`、README 與 session-state；要查舊事才翻 `MILESTONE.md`。
- **更新**：每次 commit、出門／下班／暫停／交接前，先把詳細紀錄寫進專案 `PROGRESS.md`（新的在上），把超出最近 3 次 commit 的段落原文移到 `MILESTONE.md`，再更新本檔。本檔只留最近約 5 次 commit，更舊的直接刪（git log 查得到）。
- 最新提交以 `git log -1` 查核。

## 最近的 commit

| commit | 日期 | 做了什麼 |
|---|---|---|
| 最新（`git log -1`） | 2026-11-02 | 新原型 kagura-dango「丸子大胃王」：完整比賽（裁判、三回合、對手隊、神樂變胖）、網頁音訊時鐘驗證；LESSONS 加 3 條 |
| `dd246e43` | 2026-11-02 | 進度檔改成「根目錄總覽＋各專案 PROGRESS／MILESTONE」，AGENTS.md 規則同步 |
| `99f3dccc` | 2026-11-02 | debt 故事編輯器：立繪退場／明暗獨立、角色身高自動縮放、指定位置插入步驟與新測試；`Progress.md` 拆成各專案進度檔 |
| `18a2c336` | 2026-11-02 | debt 故事編輯器原型與桂極短篇《不是頭痛，是桂》內容、萬事屋背景候選 |
| `0f52e45a` | 2026-11-02 | 合併遠端 master：Cyberpunk 文字 MMO 規劃文件、hero-horde-idle 素材與 debt 故事稿 |

## 專案入口

| 專案 | 現況（一句） | 進度 | 歷史 |
|---|---|---|---|
| debt-commission 萬事屋吐槽 ADV | 故事編輯器持續擴充；等作者試玩桂短篇與新背景 | [PROGRESS](prototypes/debt-commission/PROGRESS.md) | [MILESTONE](prototypes/debt-commission/MILESTONE.md) |
| godot-kit 共用模組 | VFX 庫完成，等 GPU／瀏覽器／手機外觀驗收；未同步各遊戲副本 | [PROGRESS](prototypes/godot-kit/PROGRESS.md) | — |
| seal-meadow 蓬蓬草原 | 單機續作；等最新手機候選的真人／iPhone 驗收，多人延後 | [PROGRESS](prototypes/seal-meadow/PROGRESS.md) | [MILESTONE](prototypes/seal-meadow/MILESTONE.md) |
| hero-horde-idle 全員推王 | 等真人前三層、手機恢復成本與作者素材 | [PROGRESS](prototypes/hero-horde-idle/docs/PROGRESS.md) | [MILESTONE](prototypes/hero-horde-idle/docs/MILESTONE.md) |
| Cyberpunk 文字 MMO（文件） | 只有規劃文件，無程式 | [PROGRESS](docs/cyberpunk-text-mmo/PROGRESS.md) | — |
| dreamling-idle 夢靈遠行 | 第一個可玩版本完成，暫停 | [PROGRESS](prototypes/dreamling-idle/PROGRESS.md) | — |
| kagura-dango 丸子大胃王（神樂生日） | 完整比賽可玩：裁判開場、三回合（三人齊吃→拋丸子→全力餵食）、對手隊、神樂變胖；佔位美術；待做第 1 回合「老闆端上桌」回饋 | [PROGRESS](prototypes/kagura-dango/PROGRESS.md) | — |
| erwin-run | 可玩到結局，未上傳 itch | [PROGRESS](prototypes/erwin-run/PROGRESS.md) | — |

repo 根目錄工具：`preview/` 本機預覽工作台（故事編輯器＋特效試映室），`python3 preview/start.py`，說明見 [preview/README.md](preview/README.md)。

## repo 層級注意事項

- 工作區常有多個 session 的未提交修改：不可 reset、還原、批次加入或順手提交別人的變更。
- 沙箱內 `.git` 唯讀、socket／Chromium／Xvfb 常被擋：是環境限制，不要寫成遊戲壞了，也不要跳過授權。
- post-commit 提示 `git-lfs` 不在 PATH，尚未處理；不要繞過或刪除 hook。
- 此 checkout 沒有 `studio/runtime/codex/`（安裝器產生），未執行安裝器。
- 2026-11-02 拆分前的完整舊版在 `git show 18a2c336:Progress.md`。
