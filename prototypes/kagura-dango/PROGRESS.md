# 丸子大胃王：進度與交接

只保留最近 3 次 commit 期間的工作與尚未 commit 的工作（新的在上）；更早的紀錄移到 MILESTONE.md。每次 commit、出門／下班／暫停前更新本檔，再更新根目錄 `Progress.md`。

## 2026-11-03（傍晚）｜累計分數取代對手計數、第 3 回合體型、對話 BGM（未 commit）

- **補（同日，之五）**：使用者說 MOV 已經剪好，不要再裁。`convert_voice.sh` 改成整段轉檔（新八吃東西 1.16 秒、眼睛被打中 13.83 秒，長度與原檔一致），淡入淡出縮成 10 ms 只防爆音；格式維持 16-bit 單聲道 WAV，Godot 匯入時壓成 QOA（`compress/mode=2`）。headless 匯入無錯誤；遊戲邏輯沒改，沿用 `godot-tests.5M9lZ6` 的全套 PASS。
- **補（同日，之四）**：神樂吃東西改用新八的吃東西聲（三個回合）。使用者新增 `assets/sfx/hit.ogg`（命中）與 `hit-bad.ogg`（不太好的命中）：完美／不錯播 hit、勉強播 hit-bad，放在共用 HUD；原檔峰值約 +2 dB 超過 0 dBFS，播放器 -3 dB 避免破音，開頭沒有空白，直接使用不轉檔。`levels` 加檢查。

- **補（同日，之三）｜台詞音效**：使用者在 `assets/sfx/` 放了 9 支 `.MOV` 錄音（動畫台詞，底下有背景音樂、沒有靜音段）。`tools/convert_voice.sh` 抽出音軌：單聲道、90 Hz 高通、輕度降噪、響度正規化（實測約 -15 LUFS、峰值 ≤ -1 dBFS；歌曲約 -7 LUFS）、頭尾淡入淡出、16-bit WAV（ffmpeg 沒有 libvorbis；MP3 有編碼延遲）。眼睛被打中只取前 3 秒，新八吃東西取 0.7 秒。`RhythmLevel.play_clip`／`say`：檔案不存在就跳過；台詞一次一句、可打斷，講話時 `Conductor.duck` 把歌降 8 dB。原始 MOV 與 `assets/voice/` 加進 `.gitignore`（有版權，比照歌曲）。whisper 環境壞了（numpy／numba 版本衝突），沒有用語音辨識找台詞位置，長片段是照長度裁的，**實際聽感未驗證**。另外修正 `tools/resave_scene.gd`：改用 `GEN_EDIT_STATE_INSTANCE`，原本會把子 scene 實例寫成帶 `type`／`script` 覆寫（已從 `hud`／三個回合 scene 清掉）。

- **補（同日，之二）**：
  - **編輯器拖曳**：拖音符移動（點在音符所在格點上也抓得到）、拖空白處平移時間軸（沒拖動才算點擊新增）、拖尺規移游標（播放中放開才跳）、觸控板兩指捲動與雙指縮放（macOS 觸控板不送滾輪事件）。
  - **素材大小交給 scene**：`actor.gd` 與 `skewer.gd` 不再在 `_ready` 強制 Sprite 的 2 倍大小與位置，值本來就存在 `actor.tscn`／`skewer.tscn`。README 列出各回合可調的節點。
  - **神樂體型改依回合進度**：使用者把第 1 回合排到 138 個音符（71 個給神樂），用累計串數算體型會在第 2 回合就變最胖。改成回合 scene 根節點的 `kagura_girth`（開場→吃完）：第 1 回合 1.0→1.1、第 2 回合 1.15→1.45、第 3 回合 1.5→1.96（吃到一半跨過 1.73 變最胖）。
  - **修正**：`set_rival_table(true)` 會把 `calm` 關掉的 RivalB 打開（第 1 回合出現兩位對手），改成只負責收起，`levels` 加了檢查。
  - **測試**：`levels` 的音符數與每人串數改從譜面讀；機器人上限改用回合長度（第 1 回合變成約 90 秒，原本寫死 90 秒會卡到逾時）；同分路間隔檢查只看同一分路（同拍兩路是和弦）。`chart_maker` 改成不依賴譜面內容。`run_tests.sh . levels flow`（`godot-tests.Lb6Vfj`）、`chart_maker font`（`godot-tests.FWhcXI`）、`judge calibrate`（`godot-tests.BH1HiX`）全 PASS。
  - **使用者的譜面**：`data/songs/eat3.json` 已由使用者用編輯器重排（開始 0 秒、138 個音符、133 拍；第 57 拍有一組紅豆＋醬油同拍的和弦），舊版在 `eat3.bak.json`。

- **補（同日）**：使用者回報編輯器沒辦法從頭播放（游標跟著播放走、停在歌尾時按播放會立刻停）。新增「◀◀ 從頭」按鈕與 Home 鍵，從回合開始處播放；游標在歌尾時按播放也從頭開始。`run_tests.sh . chart_maker font` PASS（`godot-tests.Z8lmMH`）。

- **使用者要求**：拿掉第 2 回合的回合名與對手計數，改成第 1 到第 3 回合累計的分數，加分要有跳動感；第 3 回合神樂的圖被拉寬變形，開場要是第 2 回合的樣子，之後才變更胖；對話時播 BGM。
- **已完成**：
  - **分數**：`Judge.SCORE`（完美 1000／不錯 700／勉強 300）加進 `MatchState.score`，跨回合累計，重來回合會還原。`MatchState.rival` 移除。HUD 右上的 `Score` 快速往上數並彈一下，`ScoreGain` 飄出「+1000」（完美判定較大、金色）。回合結算多一行「本回合＋／總分」，最終結算總分從 0 數上來。勝負改看三回合平均是否高於「再來一盤」（`MatchState.won()`）。背景對手隊仍照 `rival` 次數吃東西，但不計數；第 2 回合漏踢只是漏掉、沒有分。
  - **第 2 回合**：`feast2.json` 加 `show_title: false`，不顯示回合名。
  - **神樂體型**：`actor.tier()` 的門檻改成 1.14／1.73，完美進度下第 3 回合開場是第 2 段體型，吃到第 21 串才換最胖的圖，並彈一下、震一下；`kagura_full`（苗條小肚子）不再因吃飽自動換上。變形的原因是 `tools/process_art.gd` 把一條圖的每格都硬縮成同一個寬高，已改成整條等比縮放；**原圖不在這台機器（`art_src/gen` 被忽略），現有的 `kagura_tier3_*.png` 還沒重新處理**。
  - **BGM**：`main.tscn` 新增 `Bgm`（`bgm.ogg`，import 設成循環），對話畫面淡入、連續對話不中斷，其他畫面淡出。
- **驗證（L2）**：`run_tests.sh . levels flow chart_maker judge calibrate font` 六組全 PASS（`godot-tests.54nhjr`）。新增檢查：每回合分數與 HUD 顯示、三回合累計、第 2 回合無回合名、第 3 回合體型 2 → 3、漏踢不得分、重來回合還原分數、BGM 在對話中播放且進回合後停止。截圖看過第 2 回合（加分彈跳）、第 3 回合開場、回合結算。
- **未驗證**：實際聽 BGM 與回合音樂的銜接、加分動畫在真機上的手感。
- **待確認**：`bgm.ogg` 沒被 `.gitignore` 忽略，若有版權要加進忽略清單。

## 2026-11-03（下午）｜譜面編輯器重寫、接上新歌、第 2 回合精簡（未 commit）

- **使用者要求**：譜面編輯器要能調整音樂時長、編輯譜面；三首歌放在 `assets/music/`。中途追加：第 2 回合畫面太雜亂，讓畫面自己說話；使用者在 `actor.tscn` 刪了 NamePlate／NameLabel 後，所有角色都變成銀時。
- **已完成**：
  - **角色都變銀時**：`actor.gd`（`@tool`）的 `_apply()` 第一行設 `%NameLabel` 的文字，label 刪掉後在換圖前就出錯，每個角色停在 scene 預設的銀時貼圖。已移除名牌程式碼與 `display_name`（`actor.gd` 與 4 個 scene），截圖確認角色正確。
  - **歌**：三張譜面的 `music` 指向使用者的檔名（`first-…Pray.mp3`、`second-Anata MAGIC.mp3`、`last-wo ai ni….mp3`），headless 載入三首都成功。第 2 回合換成〈Anata MAGIC〉：量到 158 BPM（各 30 秒段相位穩定），遊戲半拍 `bpm 79`、`offset 0.436`。第 1、3 回合沿用原值（量測與舊值一致）。**第 2 回合的 67 個音符是照舊歌排的，要用編輯器重排。**
  - **譜面編輯器**（`scenes/chart_maker.tscn`、`scripts/chart_maker.gd`、新 `scripts/chart_timeline.gd`）：選歌、開始秒數（`music_start`）、長度（換成整拍 `end_beat`）、BPM、第 0 拍＋節拍器；時間軸一種音符一列，可新增、拖曳、刪除、復原，從游標播放，勾「錄音」後按 A S D F 打進各列；儲存時捨棄範圍外的音符。移動開始秒數時 `offset` 只平移整數拍。舊版會把第 3 回合的快拋／大串存成一般拋，已修正。`Conductor.play(from)` 可從任意秒數播放，並修掉 stop 淡出中又 play 時被靜音的問題。
  - **第 2 回合精簡**：`feast2.json` 加 `calm`（關掉觀眾、燈籠、裁判、解說員）與新的 `rival_table: false`（`stage.set_rival_table`，收起後方對手隊與盤子）；拿掉底部操作說明（`hint_text`）。畫面只剩三人、店主、衝進來搶的對手與音符軌道。
  - 新工具 `tools/resave_scene.gd`：手改的 `.tscn` 用 Godot 存回去並比對節點數（`chart_maker.tscn` 29 → 29）。
- **驗證（L2）**：`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash ../godot-kit/tools/run_tests.sh . chart_maker judge levels calibrate flow font` 六組全 PASS（`godot-tests.kXrAFf`）；headless 匯入無錯誤；截圖看過第 2 回合（`.claude/tasks/kagura-dango/shots/v3-round-2.png`）與編輯器三個回合的版面。
- **未驗證**：編輯器的真人操作（拖曳手感、播放時音符聲與節拍器的對齊）、第 2 回合新歌的實際聽感與 `offset` 是否要微調。
- **注意**：使用者的 Godot 編輯器開著這個專案，需要重新載入 `actor.tscn`、`chart_maker.tscn`、`feast.tscn` 等，不要存舊版。`assets/music/bgm.ogg`（126 秒）目前沒有接上，用途待確認。`tools/build_scenes.gd` 是舊產生器（仍寫 `display_name`、`body_color`），不要再跑。
- **下一步**：用編輯器重排第 2 回合，確認三回合的開始與長度。

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
