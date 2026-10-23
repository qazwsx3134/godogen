# 派工：養成畫面與推王戰鬥畫面的 UI 設計稿（ui_concepts）

## 背景
手機直式遊戲「全員推王」（Godot 4.7，HD-2D：像素英雄與巨魔立在 3D 舞台上，黃昏古要塞、暖光冷影）。現在的 UI 是程式拼的深藍圓角框，作者要換成正式設計。這一批只做**設計稿**（整張畫面的 mockup），讓作者選風格；選定後我們再拆成元件。
- 現況截圖在 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/refs/`：`battle_now.png`、`battle_telegraph_now.png`、`battle_skill_now.png`（推王戰鬥）、`result_now.png`（結算）、`growth_now.png`（養成）。生圖時把對應截圖當參考圖，**場景、像素英雄、巨魔、旗子的畫風與構圖保留**，重新設計的是上面的 UI 層。
- 已有的團旗：紅底劍盾（近戰團）、藍底弓杖（遠程團）、金底日輪（輔助團）。UI 配色要能和它們共存。

## 規則
- 用 Codex 內建的生圖功能（不是 master_still），每張直式、手機比例，盡量高（例如 1024×1536 或更高的直式）。
- 每張 1 次，不多骰；某張失敗就重生一次，再失敗跳過並寫進回報。額度不夠就停在已完成的風格，依表格順序做。
- 畫面文字用**繁體中文**，照下面清單的字寫（可以小但要可讀；AI 字形歪掉沒關係，版面與風格才是重點）。
- 原創奇幻，不要模仿任何現有遊戲的商標或 UI 原件。
- 做不到就直說並停下。

## 五種風格（每種都要畫兩張：養成、戰鬥，同一套風格）

| 代號 | 風格（英文提示詞重點） |
|---|---|
| A 王城藍金 | regal deep navy and gold filigree frames, polished brass corners, parchment inner panels, elegant serif-like headers — refined version of the current navy UI |
| B 旅人皮革 | Octopath-like JRPG menus: dark walnut wood and worn leather panels, stitched borders, silver rivets, warm candle-lit highlights |
| C 戰旗布幔 | heraldic war-camp look: crimson and gold cloth banners as panels, embroidered trim, shield-shaped tabs, rope and wooden pole details |
| D 像素復古 | fully pixel-art UI matching the sprites: chunky 2-px pixel frames, limited 16-color palette, pixel font look, 9-slice pixel windows |
| E 清爽手遊 | modern mobile RPG: clean semi-transparent glass panels, soft gradients, bold readable icons, large hero portrait art, still fantasy-themed |

## 養成畫面要有的東西（`<代號>_growth.png`）
- 上：標題「養成」、金幣（例：金幣 1,280）、突破素材（例：突破素材 3）。
- 行軍小隊：5 格英雄頭像（名字＋稀有度＋等級），有「行軍」標記。
- 6 個職業分頁：盾、劍、槍、弓、法、補（目前選「劍」）。
- 職業列：「劍 職業等級 14　全職業英雄 ×2.72」＋「升級（272 金）」按鈕。
- 英雄卡格子（4 欄，可捲動）：像素頭像、名字（例：蘿德、伊妮、蒂斯、佩文）、稀有度色（N 灰、R 藍、SR 紫、SSR 金）、等級、突破星數。
- 選中英雄的詳情：「蘿德　SSR 劍」、「Lv 4／10　突破 ★0　招牌技「斷鋼斬」+0%」、經驗條、「突破（1 素材）」、「派去行軍」。
- 底部三顆大按鈕：「行軍 1 小時」、「一鍵養成」、「開始推王」。

## 推王戰鬥畫面要有的東西（`<代號>_battle.png`）
- 保留戰場：左邊三團英雄與團旗、右邊巨魔、地上紅色預警圈。
- 上：「關卡王・棍棒巨魔」、王的血條（例：72%）、「第一階段」、倒數時間（例：118）、「存活 94／100　總輸出 351／秒」。
- 中上：大字提示「落石！ 把旗子拖出紅圈！」。
- 王身上三個部位小按鈕：「角」「持棍手臂」「腿」，各有小血條，「角」是瞄準中（◎）。
- 左側招牌技卡：像素頭像＋「「隕石術」」＋「SSR 法・菲嘉特」＋「隕石砸向瞄準的部位」。
- 下：選取的團「近戰團 52 人（拖旗子，或點地面移動）」、士氣條（士氣）、兩顆大按鈕「全員歸位」「大招」。

## 輸出
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/<代號>_growth.png`、`<代號>_battle.png`（代號 A–E）。
- `ui_concepts/contact-growth.png`、`ui_concepts/contact-battle.png`：五張縮圖並排，每張上方標代號與風格名。

## 回報
寫 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/REPORT.md`，最多 12 行：用的工具、尺寸、偏差、額度、跳過的項目。完成後建立 `ui_concepts/DONE`。
