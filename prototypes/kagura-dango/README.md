# 丸子大胃王：神樂生日快樂

銀魂同人、非商業的節奏遊戲（神樂生日 11/3 紀念）。原作第 66 篇的丸子大胃王比賽：銀時和新八吃不下了，改成用各種方法幫神樂吃。手機橫式網頁（itch.io），Godot 4.7。設計見 [docs/DESIGN.md](docs/DESIGN.md)，進度見 [PROGRESS.md](PROGRESS.md)。

**狀態**：進行中。太鼓達人式節奏遊戲：音符從右往左捲進判定圈，紅／藍／粉三色對應左（銀時）、中（新八）、右（神樂）。裁判開場 → 第 1 回合三人狼吞虎嚥（店主照拍上菜）→ 第 2 回合神樂配飯、新八打包便當、銀時踢開來搶的人 → 最終回合胖銀時與胖新八把丸子當飛鏢射給神樂（3 條命，沒接到打到眼睛）→ 勝負與慶生結尾。第 1、2 回合只計分。音樂是使用者提供的三首歌，每回合只放節奏最明顯的約 60 秒。

**要驗證的假設**：單鍵、聽聲音抓拍子的短關卡，加上銀魂角色的演出，在手機網頁上就能帶出節奏天國式的手感與笑點；網頁版的音訊時鐘夠準，能做 ±35 ms 的判定。

## 執行

```bash
python3 prototypes/kagura-dango/tools/bake_music.py    # clone 後先烘焙校準節拍器與提示音（需要 numpy）
# 三首歌有版權、不進 git：把 assets/example/ 的 mp3 依序複製成 assets/music/r1.mp3、r2.mp3、r3.mp3
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --path prototypes/kagura-dango                      # 試玩（設定存在 user://settings.cfg）
$G --path prototypes/kagura-dango -- --settings=/tmp/kd.cfg   # 不碰正式設定
$G --path prototypes/kagura-dango -- --qa --round=3            # 直接進第 3 回合（測試用；網頁版是 ?qa=1&round=3）
```

第 1 回合點左／中／右（←↓→、A S D），之後點畫面任何地方（空白鍵、Z、J）。第一次玩建議先「延遲校準」。

## 主要 scene 與可調整的地方

| scene | 內容 | 可在編輯器調整 |
|---|---|---|
| `scenes/main.tscn` | 比賽流程（依 `data/match.json`） | — |
| `scenes/stage.tscn` | 共用會場：生成背景、觀眾、燈籠、布幕、對手隊、裁判、集中線 | 各元件位置、對手與裁判的名稱、觀眾寬度 |
| `scenes/hud.tscn` | 共用 HUD：判定字、裁判喊話、回合名、記分板、提示 | 位置、字級、顏色 |
| `scenes/three_eat.tscn` | 第 1 回合（老闆端上桌、左中右分路） | 三人位置、`Shopkeeper` 位置／縮放、`ServeOrigin`、`PlateLeft`／`PlateMiddle`／`PlateRight`、提示文字（HUD 的 `hint_text`） |
| `scenes/toss_game.tscn` | 第 2、3 回合（`chart_path` 由流程指定） | 三人位置／縮放、竹籤堆位置 |
| `scenes/actor.tscn` | 角色精靈與名牌 | `NamePlate`、`Sprite`、`Hand`、`Mouth` 標記點、`girth`（胖瘦）、`fullness`（吃撐） |
| `scenes/shopkeeper.tscn` | 第 1 回合端盤子的店主 | `Sprite` 與店主位置／縮放 |
| `scenes/title.tscn`、`story.tscn`、`result.tscn`、`calibrate.tscn` | 各畫面 | 文字、字級、間距、按鈕 |

- **自己做譜面**：在編輯器打開 `scenes/chart_maker.tscn` 按 F6。① 選回合、按「錄節奏」，跟著歌按空白鍵；② 按「分配顏色」，音符進圈時按 A／S／D；③ 按「儲存」寫回 `data/songs/`（舊的備份成 `.bak.json`）。第 3 回合只有一種顏色，儲存後原本的快拋／大串會變成一般拋。
- 回合順序：`data/match.json`。譜面：`data/songs/<id>.json`（`bpm`、`offset`、`intensity`、`rival`、`cues` 的拍數與類型、`land_after`、第 1 回合的 `lanes`）。`music_start` 是從歌曲第幾秒開始播，`offset` 是第 0 拍在歌曲檔中的秒數（都用歌曲檔的秒數）；提示音由遊戲在每個提示即時播放。
- 台詞與結算評語：`data/story.json`（全部是草稿）。
- `tools/build_scenes.gd` 只建立還不存在的 scene，存好的 scene 才是來源檔；要重建先看 diff，再用 `-- --force=<名稱>`。
- `tools/process_art.gd` 從 git 忽略的 `art_src/gen/` 去背、切格並以 nearest 縮放輸出 `assets/sprites/`；這些輸出貼圖是遊戲執行時使用的來源。

## 測試（分層見 repo 根目錄 AGENTS.md）

```bash
cd prototypes/kagura-dango
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash ../godot-kit/tools/run_tests.sh . judge levels calibrate flow font
```

- `judge`：判定窗與評分。`levels`：機器人以注入時鐘玩完三回合（準拍、晚／早、不按、亂按、校準、餵錯人、半拍連拋重疊窗口、神樂變胖、對手串數、重來回合）。`calibrate`：平均偏差與存讀。`flow`：真實點擊走完整場比賽。`font`：字型子集涵蓋所有字。
- 網頁版音訊時鐘（真 Chrome）：`bash ../godot-kit/tools/web/build_web.sh .` 匯出後，`python3 -m http.server 8796 --directory build/web`，再跑
  `node tools/web_clock_probe.mjs --playwright <playwright-core> --chromium <Chrome>`。
- 改了遊戲裡的中文字，要重跑 `python3 ../godot-kit/tools/subset_font.py --project . --source ../hero-horde-idle/fonts/NotoSansCJKtc-Bold.otf --out assets/fonts/NotoSansTC.otf`。

## 發現

- 網頁版（Sample 播放）`play()` 後約 1.1 秒音樂才真的開始；開始後播放位置穩定（抖動約 1 ms），所以判定以音訊播放位置為準，不用牆上時鐘。
