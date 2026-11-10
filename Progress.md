# 進度總覽

只記最近幾次 commit 做了什麼，以及各專案的入口。細節寫在各專案的 `PROGRESS.md`（只放最近 3 次 commit 期間與尚未 commit 的工作）；更早的紀錄在同目錄的 `MILESTONE.md`。

- **接手**：先讀本檔，再讀該專案的 `PROGRESS.md`、README 與 session-state；要查舊事才翻 `MILESTONE.md`。
- **更新**：每次 commit、出門／下班／暫停／交接前，先把詳細紀錄寫進專案 `PROGRESS.md`（新的在上），把超出最近 3 次 commit 的段落原文移到 `MILESTONE.md`，再更新本檔。本檔只留最近約 5 次 commit，更舊的直接刪（git log 查得到）。
- 最新提交以 `git log -1` 查核。

## 最近的 commit

| commit | 日期 | 做了什麼 |
|---|---|---|
| 最新（`git log -1`） | 2026-11-10 | mortal-city：救命保單最多一張、分廉價／標準／白金三級（決定救回來的下場）；地圖最後一關不再被上緣漸淡遮住；做法選單拿掉風險與裝備的百分比；換區換一批中間人與神機醫（阿凜、潮伯、海鷗，頭像待畫）；名聲：6 則事件的「亮出名號」選項，名聲每 3 級通緝 +1、精英對手依名聲加強 |
| `18e03b97` | 2026-11-09 | 依 game-critic 評審改善兩個原型。debt-commission：S 評價要 60% PERFECT、`tools/bot_players.gd` 五種機器人玩家、冷場原因／調查落空提示／普通吐槽音效／長按上滑教學、過時文件、README 玩法假設草稿、stage 改 Pre-Production。mortal-city：致命機率上畫面、掉寶與路線脫鉤、地圖「下一步」資訊、回饋與二次確認、`pnpm smoke`；危險節點取捨（起始三選一、安全選項付代價、重傷生還與舊傷、風險 ×1.5）、義體不限數量＋神經錯亂＋裝備屬性門檻、流派卡權重與保底、漲價＋訂製與升級義體 |
| `996c51d5` | 2026-11-09 | game-critic 評審報告：debt-commission 與 mortal-city 各一份（`reviews/2026-11-09-game-critic.md`），建議列進兩邊 TODO |
| `db3ec71a` | 2026-11-09 | debt-commission：故事只留功能展示與桂短篇，舊故事搬進 `tests/fixtures/`；`prototypes/GAME_DEV_FLOW.md` |
| `dfd57afb` | 2026-11-07 | 合併 origin/master：mortal-city 以 Mac 的 roguelike（ADR 0001）為準，WSL 舊架構的 `c8fb8afd` 只留下不衝突的圖與新檔 |

## 專案入口

| 專案 | 現況（一句） | 進度 | 歷史 |
|---|---|---|---|
| debt-commission 萬事屋吐槽 ADV | 故事只剩功能展示（預設）與桂的極短篇；評審建議 #1、#3、#5–#7 已做（`18e03b97`），#2「第一章放回正式內容」與 11-08「只留 dog ear」衝突、待作者決定；下一步是真人試玩 | [PROGRESS](prototypes/debt-commission/PROGRESS.md) | [MILESTONE](prototypes/debt-commission/MILESTONE.md) |
| godot-kit 共用模組 | SaveSlots 已接入 seal-meadow adapter，保留遊戲恢復保護；只同步該存檔模組，測試暫緩 | [PROGRESS](prototypes/godot-kit/PROGRESS.md) | — |
| seal-meadow 蓬蓬草原 | 暖陶瓦風格與商店三視圖已定方向；可走商店、入口與路牌樣板已接入，正式 2D 紙娃娃及手機真人驗收待做，多人延後 | [PROGRESS](prototypes/seal-meadow/PROGRESS.md) | [MILESTONE](prototypes/seal-meadow/MILESTONE.md) |
| hero-horde-idle 全員推王 | 等真人前三層、手機恢復成本與作者素材 | [PROGRESS](prototypes/hero-horde-idle/docs/PROGRESS.md) | [MILESTONE](prototypes/hero-horde-idle/docs/MILESTONE.md) |
| 魔都傭兵（mortal-city，單機文字冒險 roguelike，ADR 0001） | 新宿→灣岸兩區可玩；評審 R1、R2、R4（大部分）–R8、R10 已做，加上神經錯亂、保單分級、名聲的用處與代價；`pnpm test`＋`pnpm smoke` 自動驗證；下一步是 3～5 人真人試玩，新美術與秋葉原等試玩後再說 | [PROGRESS](prototypes/mortal-city/PROGRESS.md)／[設計進度](docs/cyberpunk-text-mmo/PROGRESS.md) | [MILESTONE](prototypes/mortal-city/MILESTONE.md) |
| dreamling-idle 夢靈遠行 | 第一個可玩版本完成，暫停 | [PROGRESS](prototypes/dreamling-idle/PROGRESS.md) | — |
| kagura-dango 丸子大胃王（神樂生日） | 完整比賽可玩：裁判開場、三回合（三人齊吃→拋丸子→全力餵食）、對手隊、神樂變胖；佔位美術；待做第 1 回合「老闆端上桌」回饋 | [PROGRESS](prototypes/kagura-dango/PROGRESS.md) | — |
| erwin-run | 可玩到結局，未上傳 itch | [PROGRESS](prototypes/erwin-run/PROGRESS.md) | — |

開發流程與評審：[prototypes/GAME_DEV_FLOW.md](prototypes/GAME_DEV_FLOW.md)（從點子到上架的階段、關卡與工具）；skill `game-critic`（`prototypes/godot-kit/skills/game-critic/`，2026-11-09 新增後又改成引用 Studio 角色標準，最新修改未 commit）。

repo 根目錄工具：`preview/` 本機預覽工作台（故事編輯器＋特效試映室），`python3 preview/start.py`，說明見 [preview/README.md](preview/README.md)。

## repo 層級注意事項

- 工作區常有多個 session 的未提交修改：不可 reset、還原、批次加入或順手提交別人的變更。
- 沙箱內 `.git` 唯讀、socket／Chromium／Xvfb 常被擋：是環境限制，不要寫成遊戲壞了，也不要跳過授權。
- post-commit 提示 `git-lfs` 不在 PATH，尚未處理；不要繞過或刪除 hook。
- 此 checkout 沒有 `studio/runtime/codex/`（安裝器產生），未執行安裝器。
- 2026-11-02 拆分前的完整舊版在 `git show 18a2c336:Progress.md`。
