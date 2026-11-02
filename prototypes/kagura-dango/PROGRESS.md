# 丸子大胃王：進度與交接

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 MILESTONE.md。每次 commit、出門／下班／暫停前更新本檔，再更新根目錄 `Progress.md`。

## 2026-11-03｜改成太鼓式音符軌道、新三回合劇情、真實音樂、第三批美術（未 commit）

- **使用者要求**：依截圖與三首歌改劇情：第 1 回合三人狼吞虎嚥；第 2 回合神樂配飯、新八打包便當、銀時踢人；第 3 回合銀時新八變胖、把丸子當飛鏢射給神樂，沒對到拍打到眼睛；只有第 3 回合有命。音樂只用精華段。玩法改成太鼓達人式，選「3 種音符（每人一色）」。
- **分工**：Luna（Codex，`gpt-6-luna` max，Herdr pane `wJ:p17`）只生素材；BPM、譜面、程式、scene、測試、文件由 Claude 主 session 做（使用者指示）。
- **已完成**：
  - 音樂：Pray 178 BPM（遊戲半拍 89）、Beautiful Days 160.56（遊戲 80.28）、Wo ai ni 132；各取拍點最強的 60 秒（10／66／96 秒起）。`conductor.gd` 新增 `music_start`、結束淡出；提示音改為遊戲即時播放 `assets/sfx/cue_<type>.wav`（`bake_music.py` 產生），合成曲只剩校準節拍器；`test_bake.py` 移除。原曲與截圖加進 `.gitignore`。
  - 音符軌道：`scenes/note_track.tscn`＋`note.tscn`（HUD 內），音符在「點擊時刻減校準」抵達判定圈。
  - 第 2 回合：`scenes/feast.tscn`＋`scripts/feast_game.gd`、`data/songs/feast2.json`（67 個提示：飯 23、丸子 23、便當 14、來搶 7）。飯與踢人不算串數；漏踢＝對手偷 1 串。
  - 第 3 回合：胖銀時／胖新八輪流射飛鏢、鳥居戶外背景、3 命（`lives`），失誤播眼睛被打中，命歸零提前結束、結算只能重來。
  - 素材接上：踢人、打包、胖子飛鏢、眼睛被打中、配飯、命圖示、解說員兩人（會場右上）、鳥居背景。計分板圖（`scoreboard_panel.png`）尚未使用。
  - 店主移到左側，不再擋裁判。台詞草稿（`data/story.json`）改成新劇情。
- **使用者回饋第二輪（同日）**：
  - 旁白：說話的人顯示立繪（神樂在右、其他人在左），背景改成淡化的鳥居戶外圖（`scenes/story.tscn`、`scripts/story.gd`）。
  - 拿掉低中高提示音（`cue_*.wav` 與產生程式刪除）：只靠音樂拍點與音符軌道。
  - 第 1 回合照截圖改成戶外：鳥居背景、`calm` 關掉觀眾、燈籠、第二位對手、解說員與裁判；三人縮小，店主移到新八與神樂之間。
  - 第 2 回合歌曲從 0:00 播（`music_start` 0、`offset` 0.357）。
  - 第 3 回合三人縮小，神樂改面向左（`flip_sprite_h`）。
  - 結尾加神樂慶生圖（Luna 生成 `assets/sprites/kagura_birthday.png`），放在 `ending_win`／`ending_lose` 的最後一句。
  - 譜面製作工具 `scenes/chart_maker.tscn`（錄節奏→分配顏色→儲存），測試 `tests/test_chart_maker.gd`；`run_tests.sh . chart_maker judge levels calibrate flow font` 全 PASS（`/tmp/godot-tests.mWe8q1`）。
  - 驗證：`run_tests.sh . judge levels calibrate flow font` 全 PASS（`/tmp/godot-tests.Gp5rwg`），headless 匯入無錯誤，截圖 `v3-*.png` 已逐張看過。
- **L2 驗證（第一輪）**：`run_tests.sh . judge levels calibrate flow font` 全 PASS（`/tmp/godot-tests.OGyUwY`）。新增測試：第 3 回合三次失誤失敗並提前結束、兩次失誤仍存活、第 1／2 回合不失敗、第 2 回合計數與漏踢偷串。headless 匯入無錯誤。Xvfb 截圖 `.claude/tasks/kagura-dango/shots/v3-*.png`。
- **未驗證**：聽感（拍點對不對拍，尤其 Beautiful Days 偵測分數偏低）、網頁版 mp3 從中段播放的時鐘、手機實機、真人手感。
- **下一步**：使用者試玩三回合確認拍點與難度；再匯出網頁版用真瀏覽器量時鐘。

## 2026-11-03（凌晨）｜美術接入＋第 1 回合上菜＋驗收畫面修正（未 commit）

- **專案／分支**：`prototypes/kagura-dango`，master。工作區未提交；依本次要求沒有 commit、沒有 push。
- **已完成**：依 `art_src/PROMPTS.md` 生成 25 張圖，原圖留在 git 忽略的 `art_src/gen/`；`tools/process_art.gd` 去背、切格與 nearest 縮放到 `assets/sprites/`。角色腳本依體型、吃撐與動作換圖；標題、會場、裁判、對手、丸子口味與空竹籤都接上貼圖。標題加深色底板、名牌加深底金框，最終回合拋物線避開中央標題。
- **第 1 回合**：以桌面背景取代出餐口；新增端盤店主 scene，提示拍時前傾，再由 `ServeOrigin` 把丸子滑到 `PlateLeft`／`PlateMiddle`／`PlateRight`，先落桌、再於原判定拍吃掉，口味與左中右分路不變。`tests/test_levels.gd` 驗證店主可見、三路上菜與落桌時序。
- **文件／場景**：更新 README 與場景樹。scene 以 Godot `PackedScene.pack`／`ResourceSaver.save` 儲存；節點數存檔前後一致。
- **驗證**：`PYTHONPATH=/home/ronghao/.cache/uv/environments-v2/cli-cf148656915d4cee/lib/python3.12/site-packages python3 tools/test_bake.py` PASS（每張譜面共 100 個 cue）；`GODOT_BIN=/home/ronghao/.local/bin/godot bash ../godot-kit/tools/run_tests.sh . judge levels calibrate flow font` 五組全 PASS；Godot headless import exit 0，沒有 script／parse／resource load error。編輯器只印出 sandbox 本機 socket 無法建立的警告。
- **截圖**：用 Xvfb（未開桌面視窗）覆寫標題、第 1 回合與最終回合於 `.claude/tasks/kagura-dango/shots/`，皆為 1280×720，已確認四項驗收修正。
- **未驗證／限制**：真人手感、手機實機與網頁匯出尚未驗收；原始生成圖按專案忽略規則留在本機，不進 git；店主立繪與上菜動作已接入。預設 `python3` 環境沒有 numpy，音訊測試使用快取中的 Python 3.12 套件路徑。
- **下一步**：作者試玩三回合並做手機橫式驗收；若採用這批原圖，提交前需確認是否要納入 git 忽略的原圖來源。

## 2026-11-02（傍晚）｜第一次 commit

- 使用者要求 commit 並忽略不必要的檔案。遊戲本體以一筆 commit 進 master（hash 以 `git log -1 -- prototypes/kagura-dango` 查核）；沒有 push。
- `.gitignore` 新增兩類：
  - kit 副本的 `addons/proto_kit/vfx/`（14 MB，遊戲沒用到，其他原型也不追蹤）。
  - 烘焙出的 `assets/music/*.wav`（14 MB）。clone 後要先跑 `python3 tools/bake_music.py`；`assets/sfx/` 的小音效被 scene 引用，仍然進 git。
- 沿用上一段的驗證證據，本次沒有改程式、沒有重跑測試。
- **使用者回饋待辦**（`REVIEW.md`）：第 1 回合要有桌子，老闆照節奏把丸子端上來，再照節奏吃掉（取代目前出餐口拋過來的做法）。尚未實作。

## 2026-11-02（下午）｜完整比賽：裁判、三回合、對手隊、越來越激烈、神樂變胖

- **使用者要求**：
  - 要更完整：裁判開場介紹、背景有另一隊在比賽、關卡越來越難、演出越來越激烈、神樂越來越胖。
  - 一開始三個人一起吃：不同口味的丸子要給左、中、右不同的人吃。
- **已完成**：
  - **比賽流程**：`data/match.json` 排出三回合：第 1 回合三人齊吃（112 BPM，30 串）、第 2 回合銀時拋丸子（124 BPM，28 串）、最終回合全力餵食（136 BPM，42 串）。前後有裁判開場、作戰變更、勝負宣布與慶生結尾，每回合後有結算，可以重來單一回合。
  - **第 1 回合**（`three_eat`）：口味和音高對應三個人。點畫面左／中／右三分之一，或 ←↓→／A S D。點錯人算「餵錯人」。
  - **共用會場與 HUD**：`stage.tscn`、`hud.tscn`。觀眾、燈籠、布幕顏色、震屏、集中線依回合強度加強；對手隊照節奏吃，盤子疊高；記分板顯示雙方串數；裁判喊「預備／開始／停」。
  - **音樂**：一回合比一回合多層次。
  - **體型**：`MatchState` 跨回合累積，神樂寬度 1 → 1.9 倍，嘴的位置不變；銀時、新八吃 8～9 串後臉紅冒汗。
  - **判定**：改成配給「窗口內最早的未判定提示」，136 BPM 半拍連拋的重疊窗口不會被搶。
  - **QA 參數**：`?qa=1&round=N`（原生 `-- --qa --round=N`）可以直接跳到某一回合。
  - **文件**：台詞（`data/story.json`，草稿）、設計文件、README 都已更新；`art_src/PROMPTS.md` 追加第二批（神樂第 2、3 體型、銀時與新八的吃／吃撐、裁判、對手隊、紅豆／醬油丸子），舊檔名不變。
- **scene**：8 個舊 scene 從產生後都沒有人工修改（修改時間仍是 16:03），所以用產生器重建 actor、toss_game、result、stage，並新增 stage、hud、three_eat。使用者的 Godot 編輯器正開著這個專案，要重新載入，不要存舊版。
- **L2 驗證（本輪）**：
  - `python3 tools/test_bake.py`：PASS，三張譜面 100 個提示音都在 ±2 ms 內。
  - `run_tests.sh . judge levels calibrate flow font`：5 組全 PASS（最終 `godot-tests.nECpVq`）。`levels` 取代原本的 `toss`。
  - 變異檢查：配對改回最近者、忽略分路、神樂不變胖，三項都 FAIL，還原後 PASS。
  - 修正：測試誤把左路算成中路、校準偏移加了兩次、連拋案例受每幀取樣誤差影響（改成在精確時刻點擊，並把偏晚設成 0.115 秒，讓最近者和最早者的結果不同）；遊戲裡連續兩段劇情的畫面撞名（舊畫面釋放前先改名）。
- **網頁版**：
  - 匯出 pck 6.63 MB。
  - 真 Chrome 探針 3 次 PASS，第 1 回合開頭延遲約 1.12 秒，之後抖動 0.1～1.1 ms。
  - 截圖檢查了第 1 回合與最終回合（QA 跳轉），發現對手盤子疊在新八頭上，已移到兩個對手中間並重拍確認。
  - 第 2、3 回合開頭也應該有同樣約 1 秒的延遲（每首 WAV 都要先載入），沒有實測。
- **未驗證**：真人手感、手機實機、實際聽感、三種口味音高在手機喇叭上是否分得清楚。
- **待作者**：
  1. 原作第 66 篇的裁判和對手隊是誰。
  2. 台詞定稿。
  3. 依 PROMPTS.md 生第一、二批圖。
- **下一步**：試玩三回合，調整譜面密度與勝負門檻。接著接上美術、改成像素顯示；之後可以把第 2 或第 3 回合換成新八報數、按住→放開的關卡。

## 2026-11-02｜開專案：第 1 關可玩、網頁音訊時鐘驗證

- **專案／分支**：`prototypes/kagura-dango`，master，未 commit。使用者決定：晚幾天上沒關係（做 3 關＋終局）、手機橫式網頁、音樂先用程式合成、美術新生成一批：使用者選「給 opt image prompt」、畫風「像素漫畫風，小螢幕上也要很容易看懂，動作也是」。第一批 14 張的提示詞在 `art_src/PROMPTS.md`，等使用者生成後放到 `art_src/gen/`。
- **已完成**：
  - 專案骨架與 kit 同步。共用的節奏關卡基底 `scripts/rhythm_level.gd`：讀譜面、算拍點、判定、結算。
  - 判定 `judge.gd`：±35／75／120 ms，平均分，80／60 分兩條線。
  - 拍點時鐘 `conductor.gd`：以音訊播放位置為準、只增不減，可注入測試時鐘。
  - 延遲校準畫面，設定可用 `--settings=` 指定路徑。
  - 第 1 關「銀時拋丸子」：一般拋兩拍落、快拋一拍、半拍連拋、最後大串，共 25 個提示。
  - 標題、劇情、結算畫面。台詞與評語是草稿（`data/story.json`）。
  - 8 個 scene 都由 `tools/build_scenes.gd` 用 Godot 存檔，美術是色塊佔位。
  - 參考 RhythmSheriff（無授權檔）與 PolyrhythmMania（GPLv3）只取做法、不複製程式碼，見 `docs/DESIGN.md`。
- **音樂**：`tools/bake_music.py` 離線合成 WAV，和遊戲讀同一份譜面，提示音直接混進音軌，網頁版不會有逐幀抖動。
- **L2 驗證（本輪）**：
  - `python3 tools/test_bake.py`：PASS，25 個提示音都在拍點 ±2 ms 內。
  - `run_tests.sh . judge toss calibrate flow font`：5 組全 PASS（`$TMPDIR/godot-tests.ROaMWH`；變異還原後重跑 `godot-tests.uOBQN4` 亦全 PASS）。
  - 變異檢查：判定窗、校準減法、校準正負號、提示音位移各弄壞一處，四項都 FAIL，還原後 PASS。
  - 修過的 bug：結算時沒判定到的提示會讓分數算不出來，現在一律算漏掉。
- **網頁版**：
  - `build_web.sh` 匯出，pck 5.10 MB。排除了 kit 的 `vfx/`（原本 16.1 MB），zip 14 MB。
  - 真 Chrome 跑 `tools/web_clock_probe.mjs` 連續 3 次 PASS：開始延遲約 1.11 秒，之後速率 1.000、抖動 0.25～1.2 ms、最大倒退 1.4 ms（遊戲時鐘會擋住）、沒有 console 錯誤。
  - 最早幾次 FAIL 是探針本身把開頭延遲算進去，以及把 1 ms 的倒退當成失敗，已修正探針。
  - 截圖確認佔位畫面、中文字與掉落動畫正常。
- **未驗證**：真人手感、手機實機（觸控延遲、校準）、iPhone Safari、實際聽感（headless 測不到聲音）。佔位美術與音樂不是成品。
- **下一步**：
  1. 使用者依 `art_src/PROMPTS.md` 生圖（先 3 張定裝），放進 `art_src/gen/` 後，我去背、切格並接進遊戲（改成像素顯示：nearest 濾鏡、2 倍整數縮放）。
  2. 試玩第 1 關，調整判定窗與譜面。
  3. 做第 2 關「新八報數」（一問一答）、第 3 關（按住→放開）、終局混合關與慶生結尾。
  4. 縮字型子集（`--minimal`）、上 itch 草稿頁做手機實測。
