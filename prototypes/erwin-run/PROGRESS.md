# erwin-run 進度

最後更新：2026-10-14。專案說明、操作與 scene 清單見 `README.md`。

## 狀態

可以從頭玩到結局，網頁版已匯出：`build/web/`，上傳用的 zip 是 `build/erwin-run-web.zip`。還沒 commit，也還沒上傳 itch.io。

## 已完成

### 玩法（`scripts/main.gd`、`scripts/player.gd`）
- 跑酷全程約 2 分 30 秒（`BOSS_TIME = 150`）。速度從 185 漸增到 330；出怪節奏分四段（0–22 秒、22–48 秒、48–92 秒、92 秒以後），後段有「巨人後面緊跟巨石」與「先低後高兩顆石」的組合。
- 三格血。被巨人撞到或被石頭砸到扣一格，之後 1.3 秒無敵。
- 斬擊和彈反共用一個鍵：有效 0.2 秒，之後 0.24 秒不能再砍，砍太早就會扣血。貼近才砍算「完美」，分數加倍；另有連擊加成。
- 巨石飛來前 0.95 秒，右側先閃「!」；低飛的也可以跳過。
- 無垢巨人三種：高瘦、胖、奇行種（快）。第一次遇到時有教學提示，切換區域時有旗幟大字。
- Boss 戰：獸之巨人輪流「伸手抓」（先預警閃爍、快速伸出再慢慢抓）與「丟石頭」（每第 4 招丟兩顆）。斬斷手臂，或把巨石彈回砸他的臉，就進入兵長段：18 下旋轉斬、斬後頸、獸之巨人倒下冒蒸氣，接著是結局。
- 結局畫面：插畫、「HAPPY BIRTHDAY 艾爾文團長，生日快樂！10.14」、統計、彩帶、「再衝一次」。
- Game over 畫面「獻出心臟！」；到過 Boss 戰就多一個「從獸之巨人重來」。暫停（Esc、P、右上 II）、靜音、最高分存檔（`user://erwin_run.cfg`）。
- 打擊感：hit stop、震屏、手機震動（kit 的 haptics），以及像素特效（斬擊弧、彈反星芒、血、蒸氣、爆炸）。

### 手機橫向
- `aspect = expand`：橫拿時畫面填滿整個螢幕、沒有黑邊；HUD 與觸控鈕用 anchor 貼齊邊緣，出怪位置跟著實際的右緣走。
- 點左半邊跳躍、點右半邊斬擊（含黑邊區域）；左右下角有半透明的「跳躍」「斬擊」提示框，按下會亮一下。
- 網頁版第一次按開始時，請求全螢幕並鎖定橫向（Android Chrome 應會生效；iPhone Safari 不支援，維持原樣）。
- 直拿時標題畫面顯示「把手機橫過來玩」。標題上的說明文字是觸控版；桌面版開啟時換成鍵盤說明。

### 美術（Codex 生成，`art_src/`）
- 18 張全部完成（`art_src/GEN-REPORT-1.md`）：艾爾文騎馬 6 格、動作 3 格（跳、斬、受傷）、三種巨人各 4 格、獸之巨人 3 個姿勢加一條可伸長的手臂、兵長 5 格、巨石、徽章圖示、天空、遠景（城牆與山）、中景（丘陵、風車）、廢墟城鎮、開場城門、地面、標題插畫、結局插畫。
- 提示詞在 `art_src/prompts/`。無垢巨人第一次被安全系統擋下，重跑成功。
- `tools/process_art.py`：去背、用連通區塊切格（劍尖跨進下一格也不會切錯）、縮成像素尺寸、限色，背景用鏡像拼成無縫。附 `--self-test`。

### 音訊
- BGM 三首（跑酷、Boss、結局），是原創的晶片音樂，由 `tools/render_music.gd` 產生到 `assets/audio/`。
- 音效 21 種，用 synth 合成（`scripts/sfx.gd`）；在 `assets/sfx/` 放同名的 `.ogg` 就會換掉。

### 工程
- Scene 由 `tools/build_scenes.gd` 用 `PackedScene.pack()` 存出，共 9 個：main、player、titan、rock、warning、beast、levi、hud、screens，加上 `assets/ui/theme.tres`。
- 字型 Cubic 11，裁成最小子集（297 字，0.05 MB）。
- 測試：
  - `tests/test_play.gd`：機器人跑完全程到結局；完全不操作會 game over 並能重來；從 Boss 開局會出現 Boss 重來鈕。
  - `tests/test_font.gd`：每個字都有字形。
  - 兩支都通過：`../godot-kit/tools/run_tests.sh . font play:60`。
- 網頁版：遊戲資料包 1.42 MB。`tools/web_landscape.mjs` 用 headless Chromium 模擬手機橫向（844×390、觸控）打開，點開始、連點斬擊，沒有任何 console 錯誤。
- 截圖工具 `tools/shots.gd`：在虛擬螢幕跑，不開視窗。

## 待辦

1. **Boss 戰與兵長段在寬畫面下的截圖檢查**：改成 `expand` 之後只看過跑酷段。要確認的有：Boss 位置、手臂瞄準、兵長的旋轉路線，以及 Boss 戰在 844×390 的手機畫面裡沒有跑出畫面外。
   `env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 -s res://tools/shots.gd -- <輸出> 1.5,5,6.6,8.2,12,16 --boss`
   截圖工具用的是專案的 16:9 視窗，看不出手機的超寬比例：手機畫面要另外用 `web_landscape.mjs` 加 `--boss` 那類的流程看。
2. **真手機試玩**（Android 與 iPhone 各一台）：觸控反應、全螢幕與鎖定橫向、震動、音樂在第一次點擊後有沒有開始播。手機開網頁要用 HTTPS 或 itch.io 的 Draft 頁面，區網的 http 引擎不會啟動。
3. **手感調校**：真人玩過以後再調斬擊有效時間（0.2 秒）、預警時間（0.95 秒）、後段的出怪間隔。現在的平衡只用「完美機器人」量過（跑完全程滿血、約 40 次討伐、36 次彈反），沒有量過真人的失誤率。
4. **上架 itch.io**（要的話）：建頁面、登入 butler 由使用者做；之後 `butler push build/web <user>/<game>:html5`。頁面要設橫向的 viewport，例如 1280×720，並勾選手機可玩。
5. **commit**：等使用者決定。要 commit 的是 `prototypes/erwin-run/` 整個資料夾（`build/` 與 `art_src/gen/` 要不要進版控，也由使用者決定）。
6. 可選：
   - 結局插畫裡的旗幟是樹的圖案，不是自由之翼（Codex 生成的）。在意的話用 edit 只改旗幟。
   - 遠景出現的獸之巨人目前只是縮小的剪影。
   - 音效都是合成的佔位音，可換成真的 `.ogg`。

## 已知的坑

- Codex 在 Herdr 裡啟動時，`-c` 參數會跳出一個警告框，會擋住它，要按 Esc 關掉。它也會先問「直接生成或只給 prompt」：派工單裡要先寫明使用者選了直接生成。
- 素材更新後要先執行 `godot --headless --path . --editor --quit` 重新匯入，否則截圖或測試還是舊圖。
- `build_scenes.gd --overwrite` 會蓋掉 scene：在編輯器手動改過 scene 之後就不要再重跑，先看 `git diff`。
- 遊戲裡新增了中文字，就要重跑 `subset_font.py --minimal`；字型測試會抓到缺字。
