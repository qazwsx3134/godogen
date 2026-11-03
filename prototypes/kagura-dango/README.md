# 丸子大胃王：神樂生日快樂

銀魂同人、非商業的節奏遊戲（神樂生日 11/3 紀念）。原作第 66 篇的丸子大胃王比賽：銀時和新八吃不下了，改成用各種方法幫神樂吃。手機橫式網頁（itch.io），Godot 4.7。設計見 [docs/DESIGN.md](docs/DESIGN.md)，進度見 [PROGRESS.md](PROGRESS.md)。

**狀態**：進行中。太鼓達人式節奏遊戲：音符從右往左捲進判定圈，紅／藍／粉三色對應左（銀時）、中（新八）、右（神樂）。裁判開場 → 第 1 回合三人狼吞虎嚥（店主照拍上菜）→ 第 2 回合神樂配飯、新八打包便當、銀時踢開來搶的人 → 最終回合胖銀時與胖新八把丸子當飛鏢射給神樂（3 條命：沒接到打到眼睛，命用完神樂被打倒、躺在地上，`down_seconds` 秒後站起來、命補滿；不會失敗）→ 勝負與慶生結尾。每次命中加分（完美 1000、不錯 700、勉強 300），分數從第 1 回合累計到第 3 回合，HUD 上會跳動往上數；連擊 10 起畫面每拍往前推、背景人物（對手、裁判、解說員）跟著跳，50 連擊最激烈（`RhythmLevel.HYPE_FROM`／`HYPE_FULL`）；三回合平均分數不是「再來一盤」就算贏。第 1、2 回合沒有命。神樂第 1、2 回合維持苗條，第 3 回合開場變圓，吃到一半才變成最胖。音樂是使用者提供的三首歌，每回合只放節奏最明顯的約 60 秒；對話畫面播 `assets/music/bgm.ogg`（循環，進回合時淡出）。

**要驗證的假設**：單鍵、聽聲音抓拍子的短關卡，加上銀魂角色的演出，在手機網頁上就能帶出節奏天國式的手感與笑點；網頁版的音訊時鐘夠準，能做 ±35 ms 的判定。

## 執行

```bash
python3 prototypes/kagura-dango/tools/bake_music.py    # clone 後先烘焙校準節拍器與提示音（需要 numpy）
# 三首歌有版權、不進 git：放進 assets/music/（譜面的 "music" 指向檔名，可在譜面編輯器換歌）
$G --path prototypes/kagura-dango --resolution 1280x720 -s tools/store_art.gd   # itch 封面與截圖 → publishing/itch/（會開視窗）
bash prototypes/kagura-dango/tools/convert_voice.sh    # 台詞錄音（assets/sfx/*.MOV，有版權、不進 git）清洗成 assets/voice/*.wav；沒有也能玩，只是沒有台詞（在專案資料夾內執行）
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --path prototypes/kagura-dango                      # 試玩（設定存在 user://settings.cfg）
$G --path prototypes/kagura-dango -- --settings=/tmp/kd.cfg   # 不碰正式設定
$G --path prototypes/kagura-dango -- --qa --round=3            # 直接進第 3 回合（測試用；網頁版是 ?qa=1&round=3）
# 標題畫面的「第1關／第2關／第3關」也能直接玩某一回合（前面幾關算全部完美）
```

第 1 回合點左／中／右（←↓→、A S D），之後點畫面任何地方（空白鍵、Z、J）。第一次玩建議先「延遲校準」。

## 主要 scene 與可調整的地方

三個回合都是可以直接在 2D 編輯器打開調整的 scene，程式不會在執行時改寫素材的大小與位置（只換貼圖、做動畫）：
- **單一角色在某回合的大小**：在該回合 scene 選 `Gintoki`／`Shinpachi`／`Kagura`／`Shopkeeper`／`Intruder`，調 `scale` 與 `position`。
- **某角色在所有回合的大小**：打開 `actor.tscn`，調 `Sprite` 的 `scale`／`position`（腳底對齊 y = 0）。
- **丸子串大小**：`skewer.tscn` 的 `Sprite`。**音符大小**：`note.tscn` 根節點的 `radius`。
- **背景的對手、裁判、解說員**：`stage.tscn` 的 `RivalA`／`RivalB`／`Referee`／`Commentators`。
- **神樂每回合的胖瘦**：回合 scene 根節點的 `kagura_girth`（x＝開場、y＝吃完這回合；1.14 起第 2 段體型、1.73 起最胖）。

| scene | 內容 | 可在編輯器調整 |
|---|---|---|
| `scenes/main.tscn` | 比賽流程（依 `data/match.json`）、對話 BGM（`Bgm`） | `Bgm` 的音量 |
| `scenes/stage.tscn` | 共用會場：背景（`Background` 加左右兩張鏡像的 `BackgroundLeft`／`BackgroundRight`，手機橫向比 16:9 寬時填滿兩側）、觀眾、燈籠、布幕、對手隊、裁判、集中線 | 各元件位置、觀眾寬度 |
| `scenes/hud.tscn` | 共用 HUD（全部放在 `SafeArea` 底下，手機與網頁版會依瀏海／圓角內縮；`-- --safe-inset=L,T,R,B` 可模擬）：判定圈旁的判定字（`JudgeLabel`）與連擊數（`ComboLabel`）、裁判喊話、回合名、累計分數（`Score`）與加分字（`ScoreGain`）、提示、命中音 | 位置、字級、顏色；`NoteTrack` 的 `fly_target`（命中的音符飛去哪） |
| `scenes/three_eat.tscn` | 第 1 回合（老闆端上桌、左中右分路） | 三人位置、`Shopkeeper` 位置／縮放、`ServeOrigin`、`PlateLeft`／`PlateMiddle`／`PlateRight`、提示文字（HUD 的 `hint_text`）、`kagura_girth` |
| `scenes/feast.tscn` | 第 2 回合（配飯・打包・踢人）：不放回合名與操作說明、後方沒有對手隊，畫面上唯一的對手是衝進來搶的那位 | 三人與店主位置／縮放、`Intruder`／`IntruderTarget`（衝進來的起點／終點）、`ServeOrigin`／`Plate*`、`kagura_girth`（1.0 → 1.1，維持苗條） |
| `scenes/toss_game.tscn` | 第 3 回合（`chart_path` 由流程指定） | 三人位置／縮放（`Gintoki`／`Shinpachi`／`Kagura`）、`SkewerPile`（竹籤堆）、`kagura_girth`、`down_angle_deg`（命用完時神樂倒地的角度）、`down_seconds`（躺多久再站起來） |
| `scenes/actor.tscn` | 角色精靈（不掛名牌） | `Sprite` 的大小與位置（所有回合共用）、`Hand`、`Mouth` 標記點、`girth`（胖瘦，可預覽神樂體型）、`fullness`（吃撐） |
| `scenes/skewer.tscn`、`note.tscn` | 丸子串、音符 | `Sprite` 大小、`radius` |
| `scenes/shopkeeper.tscn` | 第 1 回合端盤子的店主 | `Sprite` 與店主位置／縮放 |
| `scenes/story.tscn` | 劇情對話 | `Cast` 底下每個說話者一張圖（`Gintoki`／`Shinpachi`／`Kagura`／`Referee`／`Shopkeeper`，`speaker` metadata 對應台詞的說話者）：直接拖曳位置、拉大小；`Box` 的 StyleBox（含內距） |
| `scenes/note_track.tscn` | 音符軌道（在 HUD 裡） | `Lane`、`JudgeCircle`（命中時爆光圈）、`BarLines`（每 4 拍一條小節線）、`lead_beats` |
| `scenes/settings.tscn` | 設定：音樂／音效／台詞音量（各一條 audio bus，`default_bus_layout.tres`）與震動開關，存在 settings.cfg | 版面、字級；滑桿的 `bus` metadata |
| `scenes/title.tscn`、`result.tscn`、`calibrate.tscn` | 各畫面 | 文字、字級、間距、按鈕；標題底部的同人聲明（`Credit`） |

- **譜面編輯器**：在編輯器打開 `scenes/chart_maker.tscn` 按 F6。
  - 上方：選回合與歌曲檔；「開始」是從歌曲第幾秒開始播（`music_start`），「長度」是回合秒數（換算成整拍的 `end_beat`）；「BPM」與「第0拍」（`offset`）開著節拍器邊聽邊調。移動「開始」時第 0 拍跟著平移整數拍，音符的拍數不變、跟著一起移。
  - 時間軸：一種音符一列（各列保留自己的類型，第 3 回合的快拋／大串不會變）。左鍵在格線上加音符、拖曳移動（可換列）、右鍵刪除；點上方尺規移游標，空白鍵從游標播放／停止，「◀◀ 從頭」或 Home 從回合開始處（綠線）播放（游標停在歌尾時按播放也會從頭），播放時每個音符響一聲。勾「錄音」後播放中按 A S D F 打進第 1–4 列。滾輪捲動、Ctrl／Cmd＋滾輪縮放、Ctrl／Cmd＋Z 復原。
  - 「儲存」（Ctrl／Cmd＋S）寫回 `data/songs/`，舊的備份成 `.bak.json`；回合範圍外的灰色音符不存。
- 回合順序：`data/match.json`。譜面：`data/songs/<id>.json`（`bpm`、`offset`、`intensity`、`rival`、`cues` 的拍數與類型、`land_after`、第 1 回合的 `lanes`、`calm` 關掉觀眾燈籠裁判解說、`rival_table: false` 收起後方對手隊、`show_title: false` 不顯示回合名；`rival` 只決定背景對手吃東西的次數，不計分）。`music_start` 是從歌曲第幾秒開始播，`offset` 是第 0 拍在歌曲檔中的秒數（都用歌曲檔的秒數）；提示音由遊戲在每個提示即時播放。
- **角色台詞與吃東西聲**（`assets/voice/`，由 `tools/convert_voice.sh` 產生，表格在腳本開頭）：
  - 每回合開始：`start_voice`（回合 scene 根節點；第 1、2 回合裁判「能吃就盡量吃」，第 3 回合阿銀精神喊話）。
  - 吃東西：第 1 回合 `eat_clips`（左阿銀、中新八、右神樂；神樂借用新八的吃東西聲），第 2 回合神樂吃飯／丸子、第 3 回合神樂（`eat_clip`）也用同一個。
  - 命中音（`hud.tscn` 的 `Hit`／`HitBad`，檔案在 `assets/sfx/`，進 git）：完美、不錯播 `hit.ogg`，勉強播 `hit-bad.ogg`；原檔峰值超過 0 dBFS，播放器設在 -3 dB。
  - 第 2 回合：踢人「阿銀家餐桌不許有外人」、打包便當、「再一碗白飯」。
  - 第 3 回合：眼睛被打中（整段 13.8 秒，會打斷其他台詞）、神樂變最胖時「現在才開始」。
  - 台詞一次只播一句（正在講就跳過），講話時歌曲降 8 dB。
- 台詞與結算評語：`data/story.json`（全部是草稿）。
- `tools/build_scenes.gd` 只建立還不存在的 scene，存好的 scene 才是來源檔；要重建先看 diff，再用 `-- --force=<名稱>`。
- `tools/process_art.gd` 從 git 忽略的 `art_src/gen/` 去背、切格並以 nearest 縮放輸出 `assets/sprites/`；這些輸出貼圖是遊戲執行時使用的來源。

## 測試（分層見 repo 根目錄 AGENTS.md）

```bash
cd prototypes/kagura-dango
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash ../godot-kit/tools/run_tests.sh . judge levels calibrate flow font
```

- `soak`：整個第 3 回合亂按（隨機分路、一幀多下、預備拍與結束後也按）、重複開始／結束、重開 6 次不洩漏節點、手機震動（命中一下、失誤、倒地）。
- `judge`：判定窗與評分。`levels`：機器人以注入時鐘玩完三回合（準拍、晚／早、不按、亂按、校準、餵錯人、半拍連拋重疊窗口、神樂變胖與第 3 回合的體型、累計分數與 HUD、重來回合）。`calibrate`：平均偏差與存讀。`flow`：真實點擊走完整場比賽（含對話 BGM 淡入淡出）。`font`：字型子集涵蓋所有字。
- 網頁版音訊時鐘（真 Chrome）：`bash ../godot-kit/tools/web/build_web.sh .` 匯出後，`python3 -m http.server 8796 --directory build/web`，再跑
  `node tools/web_clock_probe.mjs --playwright <playwright-core> --chromium <Chrome>`。
- 改了遊戲裡的中文字，要重跑 `python3 ../godot-kit/tools/subset_font.py --project . --source ../hero-horde-idle/fonts/NotoSansCJKtc-Bold.otf --out assets/fonts/NotoSansTC.otf`。

## 發現

- 網頁版（Sample 播放）回報的播放位置比實際聽到的晚約 1 秒，且每首歌第一次 `play()` 會卡 0.8～0.9 秒；網頁版以 `play()` 返回後起算的牆上時鐘減輸出延遲為準（手機實聽三關對上，2026-11-03），桌機原生版仍用音訊播放位置。`web_clock_probe.mjs` 只檢查內部一致，聽不到實際出聲，不能證明同步。
- 手機直拿時 kit 的 `orientation_guard.tscn`（`main.tscn` 的 OrientationGuard）蓋住畫面請玩家轉橫向（只在觸控裝置）；玩到一半轉直不會暫停。
