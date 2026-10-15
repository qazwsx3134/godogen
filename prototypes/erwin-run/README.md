# 艾爾文衝鋒（erwin-run）

艾爾文團長生日（10/14）紀念的橫向跑酷，Chrome 恐龍式玩法。騎白馬從城牆與廢墟出發，一路斬無垢巨人、彈反飛來的巨石。約 2 分 30 秒後獸之巨人出現，伸手攻擊；斬斷手臂或把巨石彈回他臉上，兵長就會趕到，旋轉斬收拾他，迎來生日快樂結局。

- 假說：Dino 式的單鍵節奏，加上「斬擊／彈反」的時機判定，能撐起 2～3 分鐘並收在一場 Boss 戰。
- 狀態：完成，可遊玩（桌面鍵盤、手柄、觸控）。
- 引擎：Godot 4.7，GL Compatibility，640×360 像素畫面，整數比例放大。

## 玩法

| 操作 | 鍵盤 | 觸控 | 手柄 |
|---|---|---|---|
| 跳躍 | 空白鍵、↑、W | 點左半邊 | A |
| 斬擊・彈反 | J、X、K、→ | 點右半邊 | X |
| 暫停 | Esc、P | 右上角 II | Back |

- 三格血（自由之翼徽章）。被巨人撞到或被石頭砸到扣一格，之後 1.3 秒無敵。
- 斬擊有效 0.2 秒，之後 0.24 秒不能再砍：砍太早就會在巨人到面前時揮不出刀。
- 巨人：在他靠近時斬擊。貼很近才砍是「完美討伐」，分數加倍。
- 巨石：右側先閃「!」預警 0.95 秒。斬擊彈反；低飛的也可以跳過。
- 連續成功累積連擊，每一擊加 10% 分數；被打中歸零。
- 死在 Boss 戰可以「從獸之巨人重來」。最高分存在 `user://erwin_run.cfg`。
- 開場艾爾文大喊「ススメ——！！」（原音），接著士兵吶喊；跑的時候一直有馬蹄聲。兵長收尾時說「嘖…又多活了一年啊，艾爾文。」
- 手機只能橫拿：直拿時整個畫面被「請把手機橫過來」擋住，點不到開始；玩到一半轉直會自動暫停，轉回橫向後從暫停選單繼續（兵長收尾動畫則是停住、轉回來接著播）。

## 執行

```bash
godot --path prototypes/erwin-run                         # 遊戲
godot --path prototypes/erwin-run -- --boss               # 直接打 Boss
godot --path prototypes/erwin-run -- --bot                # 自動遊玩（展示用）
prototypes/godot-kit/tools/run_tests.sh prototypes/erwin-run play:60   # 測試（機器人全程＋game over＋Boss 重來）
prototypes/godot-kit/tools/web/build_web.sh prototypes/erwin-run       # 網頁版 → build/web/、erwin-run-web.zip
```

截圖（虛擬螢幕，不開視窗）：
`env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 -s res://tools/shots.gd -- <輸出資料夾> 6,40,120 [--boss] [--title]`
macOS 沒有 xvfb，直接開視窗截（`--resolution 1688x780` 是手機橫向比例）：
`/Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --resolution 1688x780 -s res://tools/shots.gd -- <輸出資料夾> 6,40,120 [--boss] [--title]`

頁面用的截圖（1920×1080）在 `publishing/screenshots/`。

## Scene 與可調整的地方

| Scene | 內容 | 在編輯器裡可以調 |
|---|---|---|
| `scenes/main.tscn` | 整局：背景圖層（Sky／Far／Mid／Ruins／Ground 都是 `Parallax2D`）、開場城門 `WallGate`、遠方的獸之巨人 `BeastFar`、`World`（玩家、障礙物、Boss、兵長）、特效 `Fx`、相機、HUD、畫面 | 各圖層的 Sprite 高度、城門起始位置、`Fx` 的 `pixel`／字型／上限、BGM（`run_track` 與 `boss_track` 是同一首，Boss 戰不切歌；`end_track`）、馬蹄聲 `%Hooves` 的音量 |
| `scenes/player.tscn` | 艾爾文：`%Gallop`（6 格奔跑）、`%Action`（跳、斬、受傷）、`%Shout`（開場喊聲） | 圖的 offset（腳底對地面）、喊聲的位置與字級 |
| `scenes/titan.tscn` | 無垢巨人（tall／fat／runner 三種，`titan.gd` 的 `KINDS` 定圖、速度、判定大小） | Sprite offset |
| `scenes/rock.tscn`、`warning.tscn` | 巨石、預警「!」 | 圖格、z_index |
| `scenes/beast.tscn` | 獸之巨人：`%Body`（站、舉石、倒下）、`%ArmPivot/%Arm`（伸長的手臂）、`%Face`（彈回石頭的落點）、`%HandRock`（丟石頭的出手點） | 手臂肩膀位置、臉與出手點 |
| `scenes/levi.tscn` | 兵長（5 格：飛、旋轉 ×3、落地） | |
| `scenes/hud.tscn` | 血量、到 Boss 的進度條、分數、連擊、提示、旗幟大字、受傷閃紅、觸控提示、暫停鈕 | 全部位置、字級、顏色 |
| `scenes/screens.tscn` | 標題、暫停、game over、結局（含彩帶特效 `%Confetti`）、淡入淡出、直拿遮罩 `%Portrait` | 全部文字、按鈕、位置 |
| `assets/ui/theme.tres` | 字型（Cubic 11）、按鈕與面板樣式 | |

驗證過：改 `hud.tscn` 的提示字位置或 `screens.tscn` 的標題文字後執行仍保留；執行時的血量、Boss 狀態不會寫回 scene（scene 不在執行時存檔）。

難度曲線、出怪表、Boss 招式節奏在 `scripts/main.gd` 的 `_direct()`、`_boss_step()`；手感數值（跳躍、斬擊有效時間、無敵時間）在 `scripts/player.gd` 的常數。

## 素材來源

- 獸之巨人（`beast_body`、`beast_arm`）與開場城牆（`wall_gate`）是第二輪：用 `--reference` 附上 `docs/erwin-dino-game/` 的參考圖重生（`art_src/prompts/*_r2.txt`，結果在 `art_src/gen/*-r2/`）。
- 標題封面只用遊戲自己生成的圖拼成：`art_src/cover/compose.py` 把天空、遠景、城牆、地面、艾爾文（斬擊格放大 2 倍）、獸之巨人、兵長疊起來，輸出 `assets/ui/title_art.png`。
- 廢墟捲出畫面時的崩塌收尾 `assets/bg/ruins_end.png` 由 `process_art.py bg_ruins` 一起產生（切點 `RUINS_CUT` 與 `main.gd` 相同）。
- 圖：Codex（使用者自己的 Codex 登入，`agent-sprite-forge` 的 `cli_media.py image --route codex-cli`）依 `art_src/prompts/*.txt` 生成，原圖與收據在 `art_src/gen/`，派工單 `art_src/BRIEF-gen-1.md`，報告 `art_src/GEN-REPORT-1.md`。`tools/process_art.py` 去背、切格、縮成像素尺寸、限色，輸出到 `assets/`。
- 音樂：跑酷與 Boss 是使用者提供的「Stroke of Destiny」（RockCapers），轉成 112 kbps 存為 `assets/audio/bgm_main.mp3`；結局仍是 `tools/render_music.gd` 產生的晶片音樂 `bgm_end.wav`。
- 音效：使用者提供的檔案（原檔在 `docs/erwin-dino-game/`）用 ffmpeg 截段、淡出、調音量後存成 `assets/sfx/<事件>.wav`：`susume`（`erwin-susume.mp4` 的喊聲）、`battle_cry`、`jump`、`shatter`（`hit_rock`）、`fall`（馬嘶，倒下時）、`gallop`（馬蹄聲循環，由 `%Hooves` 播）。其餘事件仍是 `scripts/sfx.gd` 用 godot-kit 的 `synth.gd` 合成的佔位音；在 `assets/sfx/` 放同名 `.ogg`／`.wav` 就會換掉。這台 Mac 的 ffmpeg 沒有 Vorbis 編碼器，所以存 `.wav`（Godot 匯入時會壓縮）。
- 字型：Cubic 11（俐方體 11 號，OFL），`tools/subset_font.py` 裁成子集。
- 特效：godot-kit 的 `pixel_vfx.gd`（斬擊弧、彈反星芒、方塊粒子、蒸氣 shader）。

非官方粉絲作品，角色屬於原作者。

## 發現

- 單一按鍵兼斬擊與彈反、加上「砍太早會揮空」的硬直，比分開兩個鍵好懂，時機也有份量。
- 預警用固定秒數（不是距離），速度變快之後仍然公平。
- AI 生圖的多格動作條會跨格（劍尖伸進下一格），切格要用連通區塊而不是空白欄。
- 「不像原作」的角色，只靠文字描述改不好；附上原作截圖或模型照片當 `--reference`，並寫明只取臉、比例與服裝，就能維持像素畫風又像原作（獸之巨人、城牆、結局插畫都是這樣重做的）。
- 背景切換用「捲走」比淡出自然：讓重複的廢墟圖層停止重複，最後一份換成崩塌斜坡收尾的圖再捲出畫面。
- 只能橫玩的網頁遊戲，直拿時要整個擋住並暫停，比只在標題放「請橫過來」提示可靠。
- 生成的插畫要在遊戲裡截圖驗收：結局圖原圖很好，但上下文字帶剛好蓋住蛋糕和斷手。
