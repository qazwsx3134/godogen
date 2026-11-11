# 萬事屋吐槽 ADV · debt-commission：進度與交接

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 [MILESTONE.md](MILESTONE.md)。每次 commit、出門／下班／暫停前更新本檔，根目錄 `Progress.md` 只更新一行摘要。接手順序：本檔 → [README](README.md) → [session-state](production/session-state/active.md) → [HANDOFF](docs/HANDOFF.md)。

## 2026-11-11｜選定介面素材接入（未提交，待作者看畫面）

- **出門交接**：本輪停在 21 張選圖接入完成。獨立驗收 PASS（21/21 雜湊一致、未發現可重現缺陷），原報告在 `/private/tmp/debt-ui-verification/INDEPENDENT-REVIEW.md`。下一台先讀本段，再在 Godot 查看新版畫面；尚未做視覺／手機驗收或 Web 重匯。沙箱 `.git` 唯讀，無法代為 commit，未 push。提交範圍為本次 debt-commission 素材、介面、測試與交接文件及根目錄 Progress.md；工作區另有其他 session 的制度／skills 修改，請勿混入。`.claude/tasks/debt-ui-assets/REPORT.md` 被 gitignore，主要交接資訊已記在本檔。

- 專案／分支：debt-commission／master，接手基準 `6333a892`。作者將 21 張選圖放進 `art_src/ui/gen-20261110/pick/`；沿用先前直接生圖的同意，將選定的標題 A 修成「糖事屋」與「糖」印章，App 圖示 A、開機圖 B 也為「糖」字版。原圖、修訂輸出與提示詞保留在原素材目錄。
- 完成：21 張圖複製到 `assets/ui/selected/`（對照及雜湊見 `SOURCE.md`）；深藍／和紙按鈕、分頁與吐槽三態接入 scene 與 `ui_styles.gd`，保留閱讀列專用圖；標題圖、評價印章、未解鎖封條、結局卷軸及碎眼鏡接入現有 scene。`project.godot` 指定開機圖與圖示，Web 匯出排除 `art_src/`。場景由 Godot pack／save，核對節點數與子場景實例；可調整節點見 README。
- 驗證：Godot `--headless --editor --recovery-mode --quit` 匯入 exit 0，無場景／腳本解析錯誤；沙箱仍拒絕系統憑證與編輯器設定寫入，退出有資源清理訊息。為避免碰真實存檔，在 `/private/tmp/debt-ui-verification/project` 複本把 `user://` 轉到副本的 `res://.test-user/`，停用 MCP autoload／編輯器外掛，逐一執行 `Godot --headless --path <副本> --script res://tests/test_<名稱>.gd`：`ui_styles`、`gallery`、`skin`、`settings`、`chapter_flow`、`phase4_rounds_ui` 均 PASS；後續版面／結局調整後重跑 `ui_styles`、`gallery`、`chapter_flow` PASS。`gallery` 的壞檔測試預期會輸出 ConfigFile parse error；`skin` 退出有資源清理訊息。
- 另外在副本驗證 UI 間距存檔後執行仍保留、執行時狀態不寫回 scene；1920×1080 headless 版面座標檢查涵蓋標題、結算、Game Over、鑑賞、結局及吐槽。42 張候選的四角 alpha 與外緣綠邊重掃通過；App 圖示 48 px 預覽可辨，筆畫較細。完整測試、Web 匯出與手機未重跑。
- 限制／下一步：沙箱啟動 Godot 視窗 exit 134，無法擷取新版實際畫面；請作者在編輯器及遊戲中看標題、按鈕、結算等版面。作者選定的吐槽按下 A 中央有模糊紋，停用 B 仍偏紅，實際手感與辨識待確認。原有 `pick/` 移動及本次素材、scene、腳本和文件均未提交；未 push。

## 2026-11-10｜介面素材盤點、展示頁、第一批介面候選圖（候選圖與 TODO 已在 `b944de53`，等作者挑圖）

- 專案／分支：debt-commission／master。使用者要求：檢視介面（不含故事）缺什麼素材、做功能展示頁；接著用 Herdr 開 Codex（GPT-6 Luna max）產生圖片，並把需要的音效列進 TODO。使用者 17:52 自行提交 `b944de53`（TODO 音效清單＋42 張候選圖與提示詞）。現在暫停，**作者回家挑圖**。
- **盤點與展示頁**：寫臨時巡覽腳本，開視窗跑 Godot 4.7（1280×720），自動走完整段功能展示：四段、調查、5 次冷場到 Game Over、重試後完美吐槽、結局；標題覆蓋頁、目錄、存讀檔、覆寫確認、案件檔、QTE、結算則直接呼叫開啟。挑 28 張截圖做成展示頁：每個畫面標出正式圖／純色樣式／程式繪製／合成音／缺，附規格；另有音效表、「故事側但介面會顯示」（8 個線索沒圖）與「上架前要換」（萃取 UI 圖、原聲帶 BGM 授權未明）。頁面：<https://claude.ai/artifact/5PWktqSHkHipZ7YKbFxQpa>（私人）；本機檔在 `build/ui_assets_page/`（gitignore，未提交）。巡覽腳本放在 job 暫存資料夾，會被清掉；要重拍得另存成 `tools/shots_ui_tour.gd`。
- **主要缺口**：(1) 通用按鈕只有閱讀列 LOG／AUTO／SKIP／MENU 有圖，其他十幾個畫面的按鈕是 `ui_styles.gd` 的 StyleBoxFlat 平塗；現有 `gintama_extracted_menu.png` 只有 195×62、齒輪烤在圖上，不能當通用 9-slice。(2) 19 個 catalog 音效全是 `stage_effects.gd` 合成，`tsukkomi_weak` 沒登記 catalog，介面點擊／開關面板／翻頁完全沒聲音。(3) 標題是文字、`project.godot` 沒設 `boot_splash`（Web 開啟會先顯示 Godot 預設圖）。(4) 結算評價是文字「【C】」。(5) 結局只有兩顆按鈕、鑑賞未解鎖格是深藍方塊。
- **TODO**：新增「音效待辦（2026-11-10 盤點）」勾選列表 33 項，分優先、玩法系統、超必殺、介面音（要新增 `ui_click` 等 5 個 id 並接程式）、劇情、系統 BGM、選用。
- **候選圖**：派工單 `.claude/tasks/debt-ui-assets/BRIEF.md`，Herdr pane `wT:pZ`（名稱 `uiart`，Codex `gpt-6-luna`、`model_reasoning_effort=max`、workspace-write）。報告 `.claude/tasks/debt-ui-assets/REPORT.md`（`STATUS: DONE`）。產出在 `art_src/ui/gen-20261110/`：11 項拆成 21 個檔名 × A／B＝42 張、`raw/` 52 張、`PROMPTS.md`、`contact_sheet.png`、8 張 `ninepatch_check_*.png`（按鈕邊距 48 px，分頁標籤下邊 8 px）。項目：深藍／和紙按鈕各三態、分頁標籤兩態、「吐槽！」按鈕三態、標題題字、開機畫面、App 圖示、S／A／B／C 印章、結局卷軸卡、鑑賞封條卡、Game Over 碎眼鏡。Codex 開工時週額度剩 16%。
- **驗證（本次實跑）**：自己用 PIL 重掃 42 張：尺寸全符合；透明圖四角 alpha 皆 0、開機畫面不透明；沒有綠色去背殘邊。看過總覽圖與深藍按鈕的 9-slice 拉伸圖，四角與銀框不變形。截圖前備份 `~/Library/Application Support/debt-commission` 到 `~/.claude/backups/2026-11-10-debt-commission-userdata`；跑完 `diff -rq` 只多了 `ui_tour*` 暫存檔，已刪除，真實存檔沒動。沒跑遊戲測試（沒改程式）。
- **已知問題**：`btn_tsukkomi_pressed_A` 中央有模糊污點；`btn_tsukkomi_disabled_A／B` 仍是紅色，不像停用，要重做；深藍按鈕比遊戲現在的深藍更暗，接上後要並排確認。功能展示「立牌」那句畫面上沒出現牌子，原因未查。巡覽沒拍到消音條、伊莉莎白的牌子、連擊、吐槽之力全滿氣焰、調查的對話／移動話題、「聽下去」（在 `phase4_rounds` 夾具）；沒在手機實機看。
- **建議選擇（作者決定）**：深藍按鈕 B、和紙按鈕 A、分頁 A、「吐槽！」一般 B／按下 B（停用重做）、標題 B、開機畫面 A、App 圖示 B、印章 A 組、結局卡 B、未解鎖卡 A、碎眼鏡 B。
- **下一步**：作者挑好 → 把選中的圖放進 `assets/ui/` 並登記授權；`ui_styles.gd` 的按鈕改成 StyleBoxTexture（邊距 48）；標題、結算印章、結局卡、鑑賞未解鎖卡、Game Over 換新圖；`project.godot` 設 `boot_splash` 與 icon；重拍截圖對照；改 `.tscn` 後 headless 匯入檢查，再跑受影響測試（L2）。「吐槽！」停用態可派給還開著的 `uiart` pane 重做。音效照 TODO 清單另外準備。
- 未提交：本檔、`MILESTONE.md`（11-08 以前的段落原文移過去）、根目錄 `Progress.md`。

## 2026-11-09｜依評審建議改善 #1、#3、#5、#6、#7（`18e03b97`）

- 專案／分支：debt-commission／master（HEAD `996c51d5`）。使用者要求「根據昨天 commit 的 PROGRESS 跟 TODO 改善」。只做不需要作者決定、不需要真人或實機的項目。測試前把真實存檔資料夾 `~/Library/Application Support/debt-commission` 備份到 `~/.claude/backups/2026-11-09-debt-commission-userdata`。
- **#5 perfect 有價值**：`StoryRunner.grade_for` 多兩個參數（perfect、caught）：剩 5 副眼鏡也要抓到的槽點至少 60%（`S_PERFECT_RATIO`）是 PERFECT 才給 S，否則 A；Game Over 降級照舊疊加。`test_chapter1` 的 weak 路線改期望 A，`test_chapter_flow` 加 5 組評價樣本。README 結算說明同步。
- **#3 機器人玩家**：`tools/bot_players.gd`（只用 StoryRunner，不進出貨；`tools/*` 已在匯出排除）。五種策略：idle、random（不重複選錯）、repeat（會重複選錯）、weak（全選普通吐槽）、know（知道答案）。第一章夾具各 1000 局（約 50 秒）：idle 1000 局卡在第一回合（證言回合不按就不前進）；random 放棄 895（3 次 Game Over 後）、B 11、C 94，每局冷場 13.71；repeat 放棄 935、B 4、C 61，冷場 15.01；weak 1000 局 A；know 1000 局 S。隨便選幾乎都撐不完，主因是沒槽點的句子按吐槽也扣眼鏡——難度要不要放寬給作者看。
- **#6 回饋空格**：(a) 調查點到空處 toast「這裡沒什麼特別的」，連續 3 次改成「提示：還有 N 個地方沒查過」（`main_investigation.gd`）；(b) 普通吐槽有自己的音效 `tsukkomi_weak`（合成佔位）＋短震動；(c) 冷場 toast 帶原因：時間到／這個選項不對／這句沒有槽點／時機沒抓到（runner 的回合結果多回傳 `action`，`main_round.gd` 的 `MISS_CAUSE`）；(d) `data/tutorials.json` 新增「reading」教學（長按隱藏介面、往上滑看紀錄），第一次不快轉讀到台詞時出現，快轉時不打斷。新增斷言在 `test_phase4_ui`、`test_phase4_rounds_ui`、`test_game_feel`、`test_tutorial`。
- **#7 過時文件**：桂短篇 README 與草稿的 QTE 參數改成現在的三選一；README 範例 `?story=chapter1` → `katsura_dog_ears`；README「驗證」的 30 條 XDG 指令換成 `run_tests.sh`（含 macOS 的 GODOT_BIN、依序跑）、bot 指令與 L1／L2 對照；`docs/story-telling-game/ROADMAP.md`、`design/game-brief.md` 的 9:16 直式改 16:9 橫向；`ROADMAP-COMMERCIAL.md` C4；`TODO.md` 的 `?sample=transitions`；`docs/VERIFICATION.md` 標過時。
- **#1 玩法假設**：README 新增「要驗證的玩法假設（草稿，待作者確認）」：假設、機器人與真人的通過條件、結論待填；`project.yaml` 的 `stage` 改 Pre-Production（Studio 的階段名稱沒有 Prototype）。
- 驗證（本次實跑）：先跑受影響的幾組（chapter_flow、chapter1、game_feel、phase4_rounds_ui、phase3_ui、phase4_ui、tutorial）全過；完整 `GODOT_BIN=… bash ../godot-kit/tools/run_tests.sh .` 57/57 PASS（macOS，Godot 4.7）。跑完發現 `test_save_transfer` 動到真實資料夾裡桂短篇存檔的備份（`.bak` 改名成 `.before_import`，存檔內容與備份相同）：已從備份還原 `.bak`，兩個 `.before_import` 移到備份資料夾的 `_moved_after_tests/`；這是既有測試的問題，沒修，記進 `prototypes/LESSONS.md`。匯入時 Parley 外掛往 `project.godot` 加了兩個 `.ds` 翻譯檔，非本次改動，已還原。
- 延後：#2 把第一章放回正式內容（與 11-08「只留 dog ear」的指示衝突，待使用者決定）、#4 真人試玩、#8 選錯的思考成本、#9 重匯 Web、#10 實機 QTE、#11 桂短篇收尾、#12 效能預算。
- 未提交：上述程式、測試、`tools/bot_players.gd`（含 `.gd.uid`）、`data/tutorials.json`、文件、本檔與 `TODO.md`；連同上一段的 `reviews/`。

## 2026-11-09｜game-critic 評審（只有文件，`996c51d5`）

- 做了什麼：用新 skill `game-critic`（`prototypes/godot-kit/skills/game-critic/`）評審本原型，Herdr Sonnet 子 agent 執行，報告 [reviews/2026-11-09-game-critic.md](reviews/2026-11-09-game-critic.md)（385 行）。
- 總評：引擎與工具鏈紮實，但玩家玩不到完整的「調查→吐槽」loop。分數：心流 4、隨機 6、Loop 3、回饋 6、八角 5、前期驗證 4、設計文件 5、QA 6。
- 最大的三個問題：(1) 正式內容只有功能展示和 5 句台詞的桂短篇，第一章只在 `tests/fixtures/`；(2) 全選 weak 也拿 S（`tests/test_chapter1.gd:93`），高手和亂點差別小；(3) 沒有任何真人試玩紀錄，`project.yaml` 卻標 `stage: Production`。
- 測試（子 agent 本次實跑）：`project.yaml` 的 `commands.test`，57/57 headless 通過。
- 待辦：12 條建議已列進 `TODO.md` 最上方「評審建議」。
- 驗證：子 agent 在 Linux 暫存複本或暫存資料夾跑測試，沒有寫入工作樹；主 session 抽查報告引用的 `file:line` 與原始碼一致，並確認 `git status` 只多了 `reviews/`。
- 未提交：`reviews/`（報告與 `.done` 完成標記）、本檔、`TODO.md`。建議都還沒動手改，等使用者決定先做哪幾條。
