# PokeBonk 研究：3D survivor 參考

來源：https://pokebonk.solais.cloud/ ，巴西開發者 @touchzada 做的非營利寶可夢 fan game，名稱與系統（神殿、微波爐、tome 式被動）都和 Megabonk 相符。技術是 Three.js r170 加 Vite，沒有物理引擎。研究日期：2026-10-16。

分工：

| 部分 | 負責 | 做法 | 產出 |
|---|---|---|---|
| 實玩 | Claude | 用 Playwright 驅動 Chromium 玩兩局 | [live-play-notes.md](live-play-notes.md) |
| 靜態拆解 | Codex（GPT-6 Luna） | 拆解排版後的 JS bundle | [codex-bundle-analysis.md](codex-bundle-analysis.md)，以及 [data/](data/) 底下的角色、招式、敵人、升級四張資料表 |

原始 bundle、截圖、圖鑑文字與網路記錄都放在 `.claude/tasks/pokebonk/`，這個資料夾已 gitignore，第三方美術不進版控。

## 一句話

這是一款 **9 分鐘、6 隻 Boss 的 3D survivor**，核心循環如下：

- 招式自動攻擊。
- 升級時 3 選 1 卡，選項分招式、維他命、特性三類。
- 招式升到 Lv5 並持有指定維他命後可以進化。
- 打開寶貝球可得道具。
- Mega 是限時變身。

吸引人的地方不在數值，在**打擊感與資訊呈現**：

- 後處理堆疊：卡通描邊、bloom、移軸模糊、調色。
- 五種衝擊回饋，各有獨立滑桿。
- 波次、天氣、Boss 倒數三條節拍常駐 HUD。
- 結算頁拆解各招式造成的傷害。

## 一局的骨架

```
0s ──── 90s ──── 180s ──── 270s ──── 360s ──── 450s ──── 540s
 │  Boss1   Boss2    Boss3     Boss4     Boss5     最終 Boss → 結算
 │
 ├ 生怪率   min(1.4 + 0.024t, 13)/s；同屏上限 min(70 + 0.85t, 420)，硬上限 650
 ├ 每 60s  一波包圍群：floor(22 + 0.14t) 隻，出現在玩家周圍 26 m
 ├ 天氣    50s 第一次，每次 45s、間隔 20s 晴天、提前 7s 預告；對屬性加減成
 ├ Alpha   菁英事件，擊倒掉寶貝球
 └ 升級    XP 需求 floor(5 + 3(L-1) + (L-1)^1.6) × xpCurve
           約 1 分 20 秒到 Lv9（實測）
```

## 成長系統

```
升級卡（3 選 1；Reroll 3／Banish 2／Skip 3 換金幣）
 ├─ 招式    4 格 ─┐
 ├─ 維他命  4 格 ─┼→ 招式 Lv5 + 指定維他命 = 進化卡保證出現
 └─ 特性    3 格  │
寶貝球（地圖上的要付金幣開；Alpha／Boss 掉的免費）
 └─ 道具    32 種，依稀有度分層，同稀有度有持有上限
Mega 碎片（每片 0.14 條）／Mega 石（0.5 條）→ 滿條自動變身 20s
          變身中再充能：每整條 +12s，所以一片碎片約 +1.7s（實測看到 +2.6s，應該有加成），上限 40s
Combo     不改數值，build 湊齊 2–3 件時跳橫幅，升級卡上也顯示「2/3」
局外      PB 幣與 22 個任務，用來解鎖角色和招式（沒有永久屬性樹）
```

## 特效與手感重點

| 項目 | PokeBonk 的做法 | 證據 |
|---|---|---|
| 後處理 | 依序疊：場景 → 描邊 → 移軸 → bloom（strength 0.55、radius 0.3、threshold 2.4）→ 調色收尾。每層都有設定滑桿 | main:32155 |
| 打擊感 | 受擊無敵 0.4 秒、hit-stop 0.05 秒、震屏、閃屏、色差扭曲；Mega 觸發時另加 FOV punch | main:27470、main:30745 |
| 粒子 | 依名稱延遲建立、重複使用的固定容量池，加色混合 1,600 顆、一般 900 顆。貼圖檔名與 Kenney Particle Pack（CC0）一致 | main:5810、runtime-net.log |
| 傷害數字 | 預先建好 90 個 DOM 元件輪流使用；字級隨傷害放大，爆擊是金色加大字。可設定成只顯示爆擊 | main:6289 |
| 大量物件 | 敵人用 InstancedMesh，每種 640 隻；XP 寶石 900、金幣 300 | main:26194、main:26936 |
| 碰撞 | 自寫空間雜湊（世界格 6 m、敵群格 3 m），碰撞只算水平圓形加高度 | main:4943、main:8869 |
| 移動 | 加速度與慣性；衝刺約 3.2 倍移速；有滑行和多段跳 | main:27559 |
| Boss | 預告 → 延遲 → 命中 → 收招，地面標出危險區。Boss 行為分四類：砸地、鬼影、衝撞、蛇形 | main:26700 |
| 可讀性 | 「Always see my Pokémon」：主角描邊永遠畫在最上層。天空打光柱標示寶物位置 | 設定選單、截圖 |
| 效能 | 自動降解析度、地面特效數量上限、可關高草，載入時讓玩家三選一畫質 | 設定選單 |
| 天氣 | 6 種天氣（Sol Forte、沙暴、暴風雪、詭霧、強風等）。每種有：對哪些屬性加成或削弱、畫面色調、霧的顏色與距離、粒子參數（數量、形狀、速度、擺動） | main:6382–6440、main:6442 |
| 音效 | 沒有任何音檔請求，`main` 裡也沒有 `AudioContext`／`createOscillator`／`new Audio`，**確定沒有音效** | grep 結果為 0 |
| 平衡工具 | 選單有 F2「Balanceamento」與 F4「Laboratório」：每個係數一條滑桿，附公式說明，可給自己加 buff。測試局不進排行榜 | main:23967、main:7485、main:26081 |

## Pressure 與 Adaptive（動態難度）

```
Pressure（Light／Normal／Strong，120s 後每 2s 判斷一次）
  看最近 40 次擊殺的平均距離 d，以及近 20s 的平均血量比例 hp
  d > 14 m 且 hp > 70%  → 敵群倍率 ×(1 + creep)，最多到 hordeCap
  d < 9 m  或 hp < 50%  → 敵群倍率 ×(1 − 1.5·creep)
  Normal／Strong 另外看 8 m 內的敵人數（EMA）；少於 2／4 隻時把敵群放大
  hordeCap：Light 1.6、Normal 2.5、Strong 4
Adaptive（Run Setup 開關，+25% PB）
  300s 後，平均擊殺距離 > 9 m → 威脅值上升，最高 30
  敵人 HP 跟著放大，傷害 × 威脅^0.35，並多出 Alpha
```

用意：只懲罰「站在遠處無腦清場」的 build，不懲罰正在苦戰的玩家。（main:3722–3742、main:4075–4105、main:3812、main:30151）

## 搬到 Godot 3D survivor 的做法

依「投入小、效果大」排序：

1. **節拍先行**：Boss 每 90 秒一隻、共 6 隻，加上每 60 秒一波包圍群。這兩條公式直接搬，先讓一局有起伏，再談內容量。
2. **大量敵人分兩層做**：
   - 每種敵人的外觀與參數做成可在編輯器調整的 `.tscn`／Resource，符合 AGENTS.md 的規則。
   - 執行時由管理器讀這些資料，用 MultiMeshInstance3D 批次畫出，再配合自寫的格子空間雜湊做分離與命中判定，不要每隻都掛 `CharacterBody3D`。
   - Boss 與菁英數量少，可以用一般 scene instance。
   - 全域上限 650。
3. **粒子池**：每種特效各一個預先建好的 `GPUParticles3D`，用 `emit_particle()` 或 one-shot 重複觸發；貼圖可用 Kenney Particle Pack（CC0）。依本 repo 的教訓：粒子節點會改動全域亂數，平衡測試的基準線要在加完粒子節點之後再拍。
4. **打擊感五件套**做成一個 autoload：hit-stop 用 `Engine.time_scale` 或遊戲時間暫停、Camera3D 震動、CanvasLayer 閃屏、色差 shader、FOV punch。每項都要有強度設定。
5. **後處理**：用 WorldEnvironment 的 Glow 和 tonemap 做 bloom 與調色；卡通描邊用 inverted hull 或螢幕空間法線／深度描邊，移軸模糊與暗角做成一個全螢幕 shader。主角另畫一層永遠在最上面的描邊（`no_depth_test` 的 next_pass）。
6. **升級卡 UI**：3 選 1，卡片上顯示數值前後對照、稀有度色帶與組合進度；提供 Reroll、Banish、Skip 換金幣、自動選。資料驅動，依照 `data/upgrades.md` 的權重表。
7. **進化規則**：「招式 Lv5 加指定被動」出現時保證給卡。這條規則簡單，玩家也容易理解。
8. **Combo 只做橫幅不改數值**：成本最低的 build 回饋，在圖鑑和卡片上引導玩家。
9. **結算頁**：各招式的傷害占比長條、每隻 Boss 的擊殺用時、評級。實作便宜，又能讓玩家回頭調整 build。
10. **內建平衡面板**：做一個 debug-only 的 CanvasLayer，把生怪率、Boss 節拍、XP 曲線、Pressure 等常數接成滑桿，測試局不寫存檔。PokeBonk 用 F2／F4 叫出這個面板，調手感很快。
11. **效能保底**：動態調整解析度（`Viewport.scaling_3d_scale`）、地面貼花數量上限、可關的草地 MultiMesh，開局讓玩家選畫質。

不建議照搬的部分：

- **寶可夢 IP 與模型**：fan game 素材不能拿來用。
- **8 人連線**：host 權威、12 Hz 二進位敵人快照，成本高，先做單人。
- **6 種模式**：先把 Classic 做到好玩。

## 已校正的前提

- 「44 隻角色、5 個模式」：bundle 裡主角色名單有 44 筆，加上舊名單共 73 筆（圖鑑顯示 14/73）。模式 ID 有 6 個，其中 arena 是 Lucario 動作原型。
- 「cannon 物理」：bundle 裡命中的 `cannon` 只是招式名稱「水砲」，沒有任何物理引擎呼叫。碰撞全部是自己寫的。
