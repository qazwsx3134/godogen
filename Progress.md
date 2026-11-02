# 進度總覽

只放每個專案一行現況與入口；細節（驗證命令、證據路徑、限制、下一步）寫在各專案自己的進度檔。

- **接手**：先讀本檔找到專案，再讀該專案的進度檔、README 與 session-state。
- **更新**：每次 commit、出門／下班／暫停／交接前，先把詳細紀錄寫進專案進度檔（新的放最上面），再回來改本表那一行。不要把詳細段落寫回本檔。
- 本表的日期是該專案最後一次紀錄日；最新提交以 `git log -1` 查核。

| 專案 | 最後紀錄 | 現況（一句） | 下一步 | 進度檔 |
|---|---|---|---|---|
| debt-commission 萬事屋吐槽 ADV | 2026-11-02 | 故事編輯器：立繪退場／明暗獨立、角色身高自動縮放、指定位置插入步驟、節點／步驟類型切換；桂極短篇接上萬事屋背景候選。全部未 commit | 作者重整編輯器試玩；確認新背景與畫外音設定 | [PROGRESS](prototypes/debt-commission/PROGRESS.md) |
| godot-kit 共用模組 | 2026-11-01 | VFX 庫：41 組 Scenario 素材＋46 種 Three.js 原生移植與網頁試映室；未 commit，未同步各遊戲副本 | GPU／瀏覽器／手機外觀驗收 | [PROGRESS](prototypes/godot-kit/PROGRESS.md) |
| seal-meadow 蓬蓬草原 | 2026-10-31 | 單機續作：存檔寫入保護、跨區復活、乘坐；多人 M4 延後 | 最新手機候選的真人／iPhone 驗收 | [PROGRESS](prototypes/seal-meadow/PROGRESS.md) |
| hero-horde-idle 全員推王 | 2026-10-30 | 融合版＋樓層／SAO 介面；離線收益與存檔 schema 保護 | 真人前三層、手機恢復成本、作者素材 | [PROGRESS](prototypes/hero-horde-idle/docs/PROGRESS.md) |
| Cyberpunk 文字 MMO（文件） | 2026-10-29 | 只有規劃文件（React／Cloudflare 架構、UI 規範），無程式 | P01 前兩案試讀、P02 狀態表 | [PROGRESS](docs/cyberpunk-text-mmo/PROGRESS.md) |
| dreamling-idle 夢靈遠行 | 2026-10-27 | 第一個可玩版本完成，依使用者要求暫停 | 等使用者指示續作 | [PROGRESS](prototypes/dreamling-idle/PROGRESS.md) |
| erwin-run | 2026-10-14 | 見專案進度檔 | — | [PROGRESS](prototypes/erwin-run/PROGRESS.md) |

repo 根目錄工具：`preview/` 本機預覽工作台（故事編輯器＋特效試映室），`python3 preview/start.py`，說明見 [preview/README.md](preview/README.md)。

## repo 層級注意事項

- 工作區常有多個 session 的未提交修改：不可 reset、還原、批次加入或順手提交別人的變更。
- 沙箱內 `.git` 唯讀、socket／Chromium／Xvfb 常被擋：是環境限制，不要寫成遊戲壞了，也不要跳過授權。
- post-commit 提示 `git-lfs` 不在 PATH，尚未處理；不要繞過或刪除 hook。
- 此 checkout 沒有 `studio/runtime/codex/`（安裝器產生），未執行安裝器。
- 2026-11-02 前的完整舊版本檔在 git 歷史（`git show 18a2c336:Progress.md`）；當天拆分前的工作樹版本備份於 `~/.claude/backups/2026-11-02-Progress.md.bak`。
