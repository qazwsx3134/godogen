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

## Scene 與可調整的地方

| Scene | 內容 | 在編輯器裡可以調 |
|---|---|---|
| `scenes/main.tscn` | 整局：背景圖層（Sky／Far／Mid／Ruins／Ground 都是 `Parallax2D`）、開場城門 `WallGate`、遠方的獸之巨人 `BeastFar`、`World`（玩家、障礙物、Boss、兵長）、特效 `Fx`、相機、HUD、畫面 | 各圖層的 Sprite 高度、城門起始位置、`Fx` 的 `pixel`／字型／上限、三首 BGM（`run_track`、`boss_track`、`end_track`） |
| `scenes/player.tscn` | 艾爾文：`%Gallop`（6 格奔跑）、`%Action`（跳、斬、受傷） | 圖的 offset（腳底對地面） |
| `scenes/titan.tscn` | 無垢巨人（tall／fat／runner 三種，`titan.gd` 的 `KINDS` 定圖、速度、判定大小） | Sprite offset |
| `scenes/rock.tscn`、`warning.tscn` | 巨石、預警「!」 | 圖格、z_index |
| `scenes/beast.tscn` | 獸之巨人：`%Body`（站、舉石、倒下）、`%ArmPivot/%Arm`（伸長的手臂）、`%Face`（彈回石頭的落點）、`%HandRock`（丟石頭的出手點） | 手臂肩膀位置、臉與出手點 |
| `scenes/levi.tscn` | 兵長（5 格：飛、旋轉 ×3、落地） | |
| `scenes/hud.tscn` | 血量、到 Boss 的進度條、分數、連擊、提示、旗幟大字、受傷閃紅、觸控提示、暫停鈕 | 全部位置、字級、顏色 |
| `scenes/screens.tscn` | 標題、暫停、game over、結局（含彩帶特效 `%Confetti`）、淡入淡出 | 全部文字、按鈕、位置 |
| `assets/ui/theme.tres` | 字型（Cubic 11）、按鈕與面板樣式 | |

驗證過：改 `hud.tscn` 的提示字位置或 `screens.tscn` 的標題文字後執行仍保留；執行時的血量、Boss 狀態不會寫回 scene（scene 不在執行時存檔）。

難度曲線、出怪表、Boss 招式節奏在 `scripts/main.gd` 的 `_direct()`、`_boss_step()`；手感數值（跳躍、斬擊有效時間、無敵時間）在 `scripts/player.gd` 的常數。

## 素材來源

- 圖：Codex（使用者自己的 Codex 登入，`agent-sprite-forge` 的 `cli_media.py image --route codex-cli`）依 `art_src/prompts/*.txt` 生成，原圖與收據在 `art_src/gen/`，派工單 `art_src/BRIEF-gen-1.md`，報告 `art_src/GEN-REPORT-1.md`。`tools/process_art.py` 去背、切格、縮成像素尺寸、限色，輸出到 `assets/`。
- 音樂：`tools/render_music.gd` 原創的 4 聲道晶片音樂（騎馬節奏的低音），預先算好存成 `assets/audio/*`。
- 音效：`scripts/sfx.gd` 用 godot-kit 的 `synth.gd` 合成；在 `assets/sfx/` 放同名 `.ogg` 就會換掉。
- 字型：Cubic 11（俐方體 11 號，OFL），`tools/subset_font.py` 裁成子集。
- 特效：godot-kit 的 `pixel_vfx.gd`（斬擊弧、彈反星芒、方塊粒子、蒸氣 shader）。

非官方粉絲作品，角色屬於原作者。

## 發現

- 單一按鍵兼斬擊與彈反、加上「砍太早會揮空」的硬直，比分開兩個鍵好懂，時機也有份量。
- 預警用固定秒數（不是距離），速度變快之後仍然公平。
- AI 生圖的多格動作條會跨格（劍尖伸進下一格），切格要用連通區塊而不是空白欄。
