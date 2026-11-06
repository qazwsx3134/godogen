# 進度總覽

只記最近幾次 commit 做了什麼，以及各專案的入口。細節寫在各專案的 `PROGRESS.md`（只放最近 3 次 commit 期間與尚未 commit 的工作）；更早的紀錄在同目錄的 `MILESTONE.md`。

- **接手**：先讀本檔，再讀該專案的 `PROGRESS.md`、README 與 session-state；要查舊事才翻 `MILESTONE.md`。
- **更新**：每次 commit、出門／下班／暫停／交接前，先把詳細紀錄寫進專案 `PROGRESS.md`（新的在上），把超出最近 3 次 commit 的段落原文移到 `MILESTONE.md`，再更新本檔。本檔只留最近約 5 次 commit，更舊的直接刪（git log 查得到）。
- 最新提交以 `git log -1` 查核。

## 最近的 commit

| commit | 日期 | 做了什麼 |
|---|---|---|
| 最新（`git log -1`） | 2026-11-07 | mortal-city：進度與待辦整理（只有文件）；11-05 段落搬進新的 `MILESTONE.md` |
| `cf9bc101`＋`5090c606` | 2026-11-06 | mortal-city 改成單機文字冒險 roguelike（ADR 0001）：新宿切片（程序地圖、8 種節點、名聲卡牌／道具三選一、救命保單、傳奇檔案）、霓虹 icon 與贓貨黑市、回覆逐則出現、連續進度條、系統訊息分行與自動捲動、任務完成 toast＋結案畫面、戰鬥特效；灣岸 03／06 試讀稿（未接入）；LESSONS 加 2 條 |
| `18c37763` | 2026-11-05 | debt-commission：`main.gd` 拆成外殼＋五個分段檔（G6）、章節選擇「流程圖」（G4）、換背景 shader 轉場（brush／ink／glitch）、手感回饋（震動分級、HUD 與提示跳動、固定音效）、kit 同步；LESSONS 加 2 條 |
| `0b74bd2e` | 2026-11-05 | seal-meadow：town slice 與模型素材索引（另一個 session 提交，細節見其 PROGRESS） |
| `8f7db380` | 2026-11-05 | mortal-city：P01 前兩案試讀稿（資料驅動劇情委託）、自動戰鬥與戰術、排隊打鬥與戰利品、重傷停工與休養／診所／醫院、五項屬性與屬性做法、白蛇的義體診所與換裝；risk-systems §4 神經容量加技術已確認 |

## 專案入口

| 專案 | 現況（一句） | 進度 | 歷史 |
|---|---|---|---|
| debt-commission 萬事屋吐槽 ADV | main.gd 已拆分；流程圖、shader 轉場、手感回饋完成；等作者選第一章轉場、Android 試震動 | [PROGRESS](prototypes/debt-commission/PROGRESS.md) | [MILESTONE](prototypes/debt-commission/MILESTONE.md) |
| godot-kit 共用模組 | SaveSlots 已接入 seal-meadow adapter，保留遊戲恢復保護；只同步該存檔模組，測試暫緩 | [PROGRESS](prototypes/godot-kit/PROGRESS.md) | — |
| seal-meadow 蓬蓬草原 | 暖陶瓦風格與商店三視圖已定方向；可走商店、入口與路牌樣板已接入，正式 2D 紙娃娃及手機真人驗收待做，多人延後 | [PROGRESS](prototypes/seal-meadow/PROGRESS.md) | [MILESTONE](prototypes/seal-meadow/MILESTONE.md) |
| hero-horde-idle 全員推王 | 等真人前三層、手機恢復成本與作者素材 | [PROGRESS](prototypes/hero-horde-idle/docs/PROGRESS.md) | [MILESTONE](prototypes/hero-horde-idle/docs/MILESTONE.md) |
| 魔都傭兵（mortal-city，已改為單機文字冒險 roguelike，ADR 0001） | 新宿→灣岸兩區可玩（灣岸 03／06 試讀稿、第 3／5 階委託、灣岸事件）；全息地圖、新聞跑馬燈、音效、6 張節點背景已接入；等作者試讀與試玩 | [PROGRESS](prototypes/mortal-city/PROGRESS.md)／[設計進度](docs/cyberpunk-text-mmo/PROGRESS.md) | [MILESTONE](prototypes/mortal-city/MILESTONE.md) |
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
