# 蓬蓬草原：角色與怪物圖 prompt（v1，尚未生成）

2026-10-26。依使用者要求**只記錄 prompt，這輪不生成任何圖**。生成時一次貼一份 prompt、產一張圖：手動貼 opt image，或由 agent 用 Scenario skills（`scenario-consistency` 維持同一角色、`scenario-sprite-animation` 做動作幀；會花 Scenario 點數，先跟使用者確認）。

> **2026-10-26 更新**：玩家角色改走「3D 建模 → 渲染成 sprite」，流程見 [3d-to-sprite.md](../pipeline/3d-to-sprite.md)。玩家只需要 01（概念圖）與 [04-modeling-threeview.txt](04-modeling-threeview.txt)（建模用三視圖）；02、03、10～14 逐幀生成玩家圖的 prompt 保留作為備案。怪物的 20～22 仍可用（怪物兩條路都可以，見流程文件「怪物」一節）。

目標：取代目前借用 skybound-blades 的佔位圖（`assets/sprites/`）。風格是懷舊 Q 版 MMORPG（2～2.5 頭身、圓臉大眼、柔和賽璐珞上色），全部原創，**不畫、不提任何現有遊戲的角色或怪物**。

## 規格總表

| 項目 | 玩家角色（紙娃娃） | 怪物 |
|---|---|---|
| 方向 | 8 方向，畫 5 排再鏡像：正面、右前、右、右後、背面（左側三向由右側翻轉） | 4 方向，畫 3 排再鏡像：正面、右、背面（左由右翻轉） |
| 格子 | 512×512 px | 256×256 px（大型怪可用 512） |
| 比例尺 | 全遊戲一致 `meters_per_px = 0.0042` | 同左 |
| 身高 | 約 1.6 m＝站立約 380 px | 一律**比玩家矮**，見下方怪物表 |
| 腳底 | 腳底在格子底往上 8 px（`foot_px = 8`），水平置中 | 同左 |
| 背景 | 透明 alpha；工具不支援時改純 #FF00FF（兩種不可同時寫） | 同左 |

鏡頭：從斜上方約 40 度俯視（遊戲鏡頭 `pitch_deg = -42`）。所有方向都用同一個俯角與同一個比例，只轉角色本身。

### 動作與張數

| 動作 | 玩家幀數 | 怪物幀數 | 每幀停留（1/60 秒） | 說明 |
|---|---|---|---|---|
| idle | 2 | 2 | 30, 30 | 呼吸起伏 |
| walk | 4 | 4 | 9, 9, 9, 9 | 接觸→經過→接觸（另一腳）→經過 |
| attack | 3 | 2 | 8, 6, 14 ／ 10, 14 | 蓄力、揮擊、收招；怪物是蓄力、撲擊 |
| hurt | 1 | 1 | 18 | 受擊後仰 |
| down | 1 | 1 | 60 | 倒地 |

- 玩家每一層：11 幀 × 5 排＝55 張。
- 怪物每隻：10 幀 × 3 排＝30 張。

## 紙娃娃（只有玩家）

每一幀是同一個骨架上疊好幾張對齊的透明圖。換裝就是換掉其中一層。所有層都必須跟「素體」那一幀**同姿勢、同尺寸、同位置**。

| 層 | 內容 | 第一批要畫的款式 |
|---|---|---|
| body | 素體：頭、臉、膚色、貼身內襯（灰白短袖短褲），沒有頭髮 | 1 款 |
| hair | 頭髮（只畫頭髮） | 短刺蝟頭（棕）、雙馬尾（粉金） |
| outfit | 身體服裝（上衣、下身、鞋、手套） | 新手布衣、皮甲戰士服 |
| headgear | 頭飾 | 紅色頭帶（可選） |
| weapon | 右手武器 | 木劍、闊劍 |
| offhand | 左手盾 | 圓木盾（可選） |

疊放順序依方向改變（程式依方向切換 z-order）：

```
正面／右前／右   : offhand → body → outfit → hair → headgear → weapon
右後／背面       : weapon → offhand → body → outfit → hair → headgear
```

鏡像的限制：左側三向是翻轉右側，所以面朝左時武器會換到左手。懷舊 MMO 普遍接受這個取捨；如果之後要真正的左右手，就改畫 8 排（張數變 1.6 倍）。

### 生成順序（每一步核准後才做下一步）

```
 01 素體定稿（正面，一張）
   ↓
 02 素體五方向轉身圖（一張圖裡並排 5 向，求比例一致）
   ↓
 03 素體動作幀：5 方向 × 11 幀，每張附 02 當參考
   ↓
 10～15 各裝備層：每張附「同方向同幀的素體」當姿勢參考，
         只畫該層、透明背景、與素體對齊
```

**風險**：AI 很難讓單獨一層精準對齊素體。若對不齊，退路是直接生成「穿好整套」的角色圖，再手動切出 hair／headgear／weapon 層；outfit 則每套整身各畫一份（不拆層）。

## 怪物

| 檔名 | 名稱 | 高度（相對玩家） | 站立高度 | 性格 |
|---|---|---|---|---|
| puffbun | 蓬蓬兔 | 0.40 | 約 150 px | 被動 |
| mosscap | 苔菇仔 | 0.45 | 約 170 px | 被動 |
| tusklet | 小獠豬 | 0.50 | 約 190 px | 被動，被打會反擊 |
| pebblet | 石頭仔 | 0.60 | 約 230 px | 主動攻擊 |

生成順序：20 定稿 → 21 三方向轉身圖 → 22 動作幀（3 方向 × 10 幀）。

## 檔案

| Prompt | 用途 | 附圖 |
|---|---|---|
| [00-common.txt](00-common.txt) | 所有 prompt 共用的風格與輸出段落（已嵌入下面每份，留著方便統一修改） | — |
| [01-body-master.txt](01-body-master.txt) | 素體定稿 | 無 |
| [02-body-turnaround.txt](02-body-turnaround.txt) | 素體五方向 | 01 定稿 |
| [03-body-frame.txt](03-body-frame.txt) | 素體單幀（套方向與動作） | 01 定稿＋02 轉身圖 |
| [10-layer-hair.txt](10-layer-hair.txt) | 頭髮層 | 同方向同幀素體 |
| [11-layer-outfit.txt](11-layer-outfit.txt) | 服裝層 | 同方向同幀素體 |
| [12-layer-headgear.txt](12-layer-headgear.txt) | 頭飾層 | 同方向同幀素體（＋hair） |
| [13-layer-weapon.txt](13-layer-weapon.txt) | 武器層 | 同方向同幀素體 |
| [14-layer-offhand.txt](14-layer-offhand.txt) | 盾牌層 | 同方向同幀素體 |
| [20-monster-master.txt](20-monster-master.txt) | 怪物定稿（4 隻的外觀描述都在裡面） | 可附玩家素體定稿作比例參考 |
| [21-monster-turnaround.txt](21-monster-turnaround.txt) | 怪物三方向 | 該怪定稿 |
| [22-monster-frame.txt](22-monster-frame.txt) | 怪物單幀 | 該怪定稿＋轉身圖 |
| [directions-and-poses.md](directions-and-poses.md) | 方向與動作的英文填空字串 | — |

帶 `{DIRECTION}`、`{POSE}`、`{MONSTER}` 的 prompt，從 [directions-and-poses.md](directions-and-poses.md) 複製對應字串填入。

## 原圖放哪、怎麼接進遊戲

```
art_src/chars/<名稱>/master/         定稿
art_src/chars/<名稱>/<方向>/<動作>_<幀>.png   例：body/front_right/walk_2.png
```

方向資料夾名：`front`、`front_right`、`right`、`back_right`、`back`。

接入：用 `godot-kit/tools/sprite_atlas.py` 打包。玩家設 `directions: 8, mirror: true`，怪物設 `directions: 4, mirror: true`。打包後每層一張圖集、一個 sheet。紙娃娃的 actor（多層 sprite 同步播放、依方向換 z-order）還沒實作，等第一批圖核准後再做。
