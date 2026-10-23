# 派工：底部導覽圖示、遺物、素材、招募券、招募背景（ui_icons2）

## 背景
「全員推王」的道具頁與招募頁正在遊戲裡實作（Claude 做）。目前導覽列只有字、遺物借用飾品的圖、素材是裁來的暫時圖。
這一批只生圖，**不要改遊戲的任何檔案**（scenes、scripts、assets、tests、tools），接進遊戲由 Claude 做。
使用者已同意這一批直接生成。

參考圖（只借風格，不要照抄構圖）：
- 介面：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/round3/A_items.png`（墨綠、暖白、古銅細框；裡面的盾、劍、戒指等道具圖示就是要對齊的畫風）
- 招募頁版面：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_concepts/round3/B_recruit.png`（背景要像它的酒館）
- 上一批圖示：`/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons/contact.png`

## 規則
- 用 Codex 內建 image_gen（同 ui_icons）。每張只生 1 張，不多骰；失敗重跑一次，再失敗就跳過並寫進回報。每張設時限約 6 分鐘，卡住就停掉該張重跑一次。額度不夠就停在已完成的項目，依下表順序做。
- 圖裡不能有任何文字、字母、數字。
- 做不到就直說並停下，不要用程式繪圖代替。

## 共同風格（英文，每個 prompt 都套用）
```text
detailed HD-2D pixel art in the style of Octopath Traveler: hand-placed pixel shading, crisp dark outlines, limited
palette, warm light from the upper-left; colours sit well on a dark forest-green UI with warm white text and thin
bronze lines. No text, no letters, no numbers, no watermark.
```

## 1. 道具圖示 ×7（`items/<id>.png`，正方形，背景純洋紅 #FF00FF，之後由 Claude 去背）
每張：`a single game item icon, the object centred and filling about 80 percent of the square, fully visible with
margin, a crisp dark outline around the object, on a perfectly flat pure magenta #FF00FF background, no shadow on the
background, no frame, no border, readable at 64 px`，加上下表內容。物件本身不要用洋紅或粉紫色。

| 檔名 | 名稱 | 內容（英文） |
|---|---|---|
| `r_sun` | 日輪聖印 | a round golden sun seal medallion with radiating rays and an engraved sun face |
| `r_frost` | 霜晶護符 | an icy pale-blue crystal amulet set in a silver frame on a short chain |
| `r_flame` | 炎心墜飾 | a pendant holding a glowing orange-red ember heart inside a dark iron cage |
| `r_leaf` | 森語花冠 | a small circlet woven from green leaves and tiny white flowers |
| `m_stone` | 強化石 | a pale blue-white faceted crystal shard, like a whetstone gem |
| `m_shard` | 突破素材 | a small cluster of glowing amber hero-soul crystals |
| `m_ticket` | 招募券 | a worn parchment recruit ticket with a wax seal and a ribbon, slightly curled |

## 2. 導覽圖示 ×5（`nav/<id>.png`，正方形，背景純洋紅 #FF00FF）
每張：`a small simple navigation symbol, a single silhouette-like object in pale warm cream with darker bronze
shading, bold and simple so it reads at 40 px, centred with margin, on a perfectly flat pure magenta #FF00FF
background, no shadow, no frame`。五張要像同一套：同樣的線條粗細、配色、大小。

| 檔名 | 分頁 | 圖案（英文） |
|---|---|---|
| `camp` | 營地 | a small campfire with a tent behind it |
| `growth` | 養成 | an upward arrow over a sword |
| `recruit` | 招募 | a rolled recruit scroll with a wax seal |
| `items` | 道具 | a leather backpack |
| `stages` | 關卡 | a pennant flag on a hill |

## 3. 招募頁背景 ×1（`bg/recruit.png`，直式約 1024×1792，不透明）
`the inside of a candle-lit medieval tavern recruiting hall at night: wooden beams, an iron chandelier with candles at
the upper right, crossed-swords banners and a notice board on the back wall, wooden tables and chairs at the sides,
a rug on the floor in the lower middle where a hero would stand; warm amber candlelight on deep green-brown shadows,
low contrast, the centre is empty open space, the bottom 30 percent fades to near-black green so UI can sit on it,
no characters, no creatures, no text`

## 輸出
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons2/items/<id>.png`
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons2/nav/<id>.png`
- `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons2/bg/recruit.png`
- 一張 `ui_icons2/contact.png`：13 張縮小並排。
- 完整 prompt 寫進 `ui_icons2/inputs/prompts.md`。

## 驗收
- 4 個遺物彼此、也跟 A_items.png 裡的飾品一眼分得出；96 px 看得出是什麼。
- 5 個導覽圖示同一套，40 px 看得出。
- 洋紅背景是平的，沒有陰影或漸層。
- 招募背景中間空著、下方夠暗、沒有人物與文字。

## 回報
寫 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons2/REPORT.md`，最多 10 行：工具、重試／跳過、偏差、額度。完成後建立 `/Users/peter/repo/godot/godogen/prototypes/hero-horde-idle/art_src/ui_icons2/DONE`。
