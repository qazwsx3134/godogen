# 丸子大胃王：神樂生日快樂

銀魂同人、非商業的節奏遊戲（神樂生日 11/3 紀念）。原作第 66 篇的丸子大胃王比賽：銀時和新八吃不下了，改成用各種方法幫神樂吃。手機橫式網頁（itch.io），Godot 4.7。設計見 [docs/DESIGN.md](docs/DESIGN.md)，進度見 [PROGRESS.md](PROGRESS.md)。

**狀態**：進行中。一場完整比賽可以玩：裁判開場 → 第 1 回合三人齊吃（左中右）→ 第 2 回合銀時拋丸子 → 最終回合全力餵食 → 勝負與慶生結尾。難度與演出逐回合提高，神樂越吃越胖。美術是佔位圖形，音樂是合成的。

**要驗證的假設**：單鍵、聽聲音抓拍子的短關卡，加上銀魂角色的演出，在手機網頁上就能帶出節奏天國式的手感與笑點；網頁版的音訊時鐘夠準，能做 ±35 ms 的判定。

## 執行

```bash
python3 prototypes/kagura-dango/tools/bake_music.py    # clone 後先烘焙曲子（assets/music/*.wav 不進 git；需要 numpy）
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
| `scenes/stage.tscn` | 共用會場：觀眾、燈籠、布幕、對手隊、裁判、集中線、桌子 | 各元件位置、對手與裁判的名稱／顏色、觀眾寬度 |
| `scenes/hud.tscn` | 共用 HUD：判定字、裁判喊話、回合名、記分板、提示 | 位置、字級、顏色 |
| `scenes/three_eat.tscn` | 第 1 回合（左中右） | 三人位置、出餐口 `Hatch`、提示文字（HUD 的 `hint_text`） |
| `scenes/toss_game.tscn` | 第 2、3 回合（`chart_path` 由流程指定） | 三人位置／縮放、竹籤堆位置 |
| `scenes/actor.tscn` | 佔位角色 | `Hand`、`Mouth` 標記點（丸子落在 Mouth）、`girth`（胖瘦）、`fullness`（吃撐） |
| `scenes/title.tscn`、`story.tscn`、`result.tscn`、`calibrate.tscn` | 各畫面 | 文字、字級、間距、按鈕 |

- 回合順序：`data/match.json`。譜面：`data/songs/<id>.json`（`bpm`、`offset`、`intensity`、`rival`、`cues` 的拍數與類型、`land_after`、第 1 回合的 `lanes`）。改譜面後跑 `python3 tools/bake_music.py`，提示音才會跟著移位。
- 台詞與結算評語：`data/story.json`（全部是草稿）。
- `tools/build_scenes.gd` 只建立還不存在的 scene，存好的 scene 才是來源檔；要重建先看 diff，再用 `-- --force=<名稱>`。

## 測試（分層見 repo 根目錄 AGENTS.md）

```bash
cd prototypes/kagura-dango
python3 tools/test_bake.py                       # 提示音落在譜面拍點上（±2 ms）
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash ../godot-kit/tools/run_tests.sh . judge levels calibrate flow font
```

- `judge`：判定窗與評分。`levels`：機器人以注入時鐘玩完三回合（準拍、晚／早、不按、亂按、校準、餵錯人、半拍連拋重疊窗口、神樂變胖、對手串數、重來回合）。`calibrate`：平均偏差與存讀。`flow`：真實點擊走完整場比賽。`font`：字型子集涵蓋所有字。
- 網頁版音訊時鐘（真 Chrome）：`bash ../godot-kit/tools/web/build_web.sh .` 匯出後，`python3 -m http.server 8796 --directory build/web`，再跑
  `node tools/web_clock_probe.mjs --playwright <playwright-core> --chromium <Chrome>`。
- 改了遊戲裡的中文字，要重跑 `python3 ../godot-kit/tools/subset_font.py --project . --source ../hero-horde-idle/fonts/NotoSansCJKtc-Bold.otf --out assets/fonts/NotoSansTC.otf`。

## 發現

- 網頁版（Sample 播放）`play()` 後約 1.1 秒音樂才真的開始；開始後播放位置穩定（抖動約 1 ms），所以判定以音訊播放位置為準，不用牆上時鐘。
