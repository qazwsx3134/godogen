# 素材生成 prompt

目標是讓遊戲畫面和 `docs/Ann-the-last-sugercane-Forsaken/` 的三張概念圖一模一樣。
每一張都**附上指定的概念圖當參考圖**再貼 prompt：參考圖比文字更能鎖住畫風。

## 怎麼用

```
生成圖 ──存成──→ art_src/<檔名>.png ──tools/process_art.gd──→ assets/<檔名>.png ──→ scene 裡的 Sprite2D
         （檔名照下表）     去背（#FF00FF）、裁切、切格、縮到遊戲尺寸
```

1. 用 ChatGPT／Gemini 生成，附上「參考圖」欄的概念圖。
2. 存成下表的檔名放進這個資料夾（`png`、`webp`、`jpg` 都可以）。
3. 在 `prototypes/sugarcane-tanks` 執行：
   ```bash
   godot --headless --path . --script res://tools/process_art.gd
   ```
   它會列出還沒生成的檔案。

**規則**
- 背景一律是**純洋紅色 #FF00FF**，不要綠色，因為坦克、甘蔗、葉子都是綠的。不要要求「透明背景」：生成器常把棋盤格畫進圖裡。如果工具真的輸出了帶透明的 PNG，也可以直接用，工具會保留原本的 alpha。
- 角色一律**面朝右**。遊戲裡會左右翻轉。
- 角色不要畫地面影子，遊戲裡的 scene 有自己的影子。
- 圖上不要有文字、UI、格線。
- 背景要夠大：「改概念圖」的 prompt 常會輸出和參考圖一樣的 720×1280，放大到 1080×1920 會糊。有「Large」縮圖之前的原始概念圖就附原圖，並選工具能給的最大輸出尺寸。
- `boss_tank` 要拿生成好的 `tank` 當參考，所以先做 `tank`。
- 組合圖（kit）要照指定的格數排，每格一個物件、置中，格與格之間留大片空白。工具會照格子切。

| 檔名 | 內容 | 參考圖 | 比例 | 遊戲內尺寸（最長邊） |
|---|---|---|---|---|
| `bg_square` | 天安門廣場場地（第 4–7 間） | ann1 | 9:16 | 1080×1920 |
| `bg_memorial` | 中正紀念堂廣場（第 8–9 間） | ann2 | 9:16 | 1080×1920 |
| `bg_hall` | 紀念堂內的 Boss 場地（第 10 間） | ann3 | 9:16 | 1080×1920 |
| `bg_temple` | 宮廟前庭（第 1–3 間），概念圖沒有，照同畫風新畫 | ann1＋ann3 | 9:16 | 1080×1920 |
| `hero` | 主角 | ann1 | 1:1 | 120 px |
| `rat` | 老鼠 | ann1 | 1:1 | 110 px |
| `tank` | 坦克 | ann1 | 1:1 | 210 px |
| `chef` | 廚師（取代餐盤怪，一樣丟三色豆） | ann2 | 1:1 | 140 px |
| `boss_tank` | 重型坦克 Boss（第 5 間） | 生成好的 `tank` | 1:1 | 320 px |
| `chiang` | 最終 Boss | ann3 | 1:1 | 300 px |
| `items` | 4×3：甘蔗彈、砲彈、豌豆、玉米、紅蘿蔔、經驗寶石、愛心、手槍、金幣 | ann1 | 4:3 | 30–80 px |
| `obstacles` | 2×2：木箱、沙包牆、拒馬、石塊 | ann1＋ann3 | 1:1 | 110／250 px |
| `abilities` | 4×4：15 個能力圖示 | ann1 | 1:1 | 96 px |
| `portraits` | 2×2：主角、最終 Boss、重型坦克的圓形頭像 | ann1＋ann3 | 1:1 | 150 px |

生成後先用眼睛檢查，特別是 kit 的**順序**：工具是照格子位置命名的，順序錯了圖示就會對錯能力。

---

## 場地背景

場地背景要是**空的**。箱子、沙包、拒馬在遊戲裡是會擋子彈的障礙物，另外放；畫在背景上會誤導玩家。
上方的門（建築物正中間）是清房後要走進去的出口，要保留。

### `bg_square`（附 ann1）

```
Edit the attached game screenshot into a clean, empty level background. Remove every character and enemy (the boy, all rats, the big rats with barrels, all tanks), every projectile, muzzle flash, explosion, smoke, rubble and debris, every health bar, and all UI (joystick, round button, skill icons, portrait, level and HP bar, stage label, coin and ticket counters, pause button). Also remove every obstacle standing on the plaza floor: sandbags, wooden crates, wooden X barricades, barrels. Keep everything else exactly as it is: the red palace gate building at the top with its dark door in the middle, the red walls, the white stone balustrades, lamp posts, trees and potted plants along the left, right and bottom borders, and the grey stone tile floor. Fill every removed area with the same continuous stone floor tiles. Same pixel art style, same palette, same camera angle, same framing. Portrait 9:16, highest resolution available. No text.
```

### `bg_memorial`（附 ann2）

```
Edit the attached game screenshot into a clean, empty level background. Remove every character (the boy, all rats, the rat king, the chefs), every projectile and dust puff, and all UI (joystick, round button, portrait, HP bar, level bar, skill icons, stage and wave label, pause button). Also remove the small hedge planters that sit inside the open plaza floor. Keep everything else exactly as it is: the white memorial hall with the blue octagonal roof and its door at the top, the stairs, the two stone lions, the blue flags on poles, the gardens, hedges, trees and white stone railings along the borders, and the patterned stone plaza floor with its diamond inlays. Fill every removed area with the same continuous plaza floor. Same pixel art style, same palette, same camera angle, same framing. Portrait 9:16, highest resolution available. No text.
```

### `bg_hall`（附 ann3）

```
Edit the attached game screenshot into a clean, empty level background. Remove the bald boss and his red slash effect, every rat, the hero, all red target circles and their explosions, every projectile, all loose rocks and rubble, and all UI (boss portrait and boss bar, stage label, pause button, joystick, round buttons, the hero portrait with the green bar and ammo). Also remove the grey stone blocks and wooden crates standing on the floor. Keep everything else exactly as it is: the stairs and dark stone wall at the top, the two red banners, the fire braziers, the dark stone floor tiles with small grass tufts, and the large compass-rose emblem in the floor. Fill every removed area with the same continuous stone floor. Same pixel art style, same palette, same camera angle, same framing. Portrait 9:16, highest resolution available. No text.
```

### `bg_temple`（附 ann1 與 ann3）

```
Create a new level background in exactly the same pixel art style, palette, outline weight, camera angle and framing as the attached game screenshots: the courtyard in front of a Taiwanese folk temple, seen from the same 3/4 top-down angle. Top 12% of the image: the temple front with a red-and-gold swallowtail roof ridge, red pillars and a big red wooden door in the exact horizontal center (this is the exit). Left and right borders: low grey stone walls with hanging red lanterns, a bronze incense burner, and trees outside the walls. Bottom border: a low stone wall with trees behind it. Everything between the borders is an open, empty courtyard of worn grey-beige stone tiles with a few cracks and small grass tufts. No characters, no objects or obstacles on the courtyard floor, no text, no UI. Portrait 9:16, highest resolution available.
```

---

## 角色

每張 prompt 後面都接這段（下面已經附上）：

> Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.

### `hero`（附 ann1）

```
Redraw only the main character from the attached game screenshot: the boy with messy black hair, black suit, white shirt and red tie, holding the green sugarcane launcher level at his side like a bazooka. Show him alone, full body, standing, facing right, from the same 3/4 top-down camera angle, in exactly the same pixel art style, palette and outline, large and centered in a square image. No projectiles, no glow trails. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

### `rat`（附 ann1）

```
Redraw only one of the small rat enemies from the attached game screenshot: black-grey fur, glowing red eyes, pink ears, nose, feet and tail, a small brown satchel on its back. Show it alone, full body, running, facing right, from the same 3/4 top-down camera angle, in exactly the same pixel art style, palette and outline, large and centered in a square image. No health bar. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

### `tank`（附 ann1）

```
Redraw only one of the green army tanks from the attached game screenshot: olive-green hull and turret, dark treads, the cute cat-face emblem on the side and on the turret. Show it alone, facing right with the cannon pointing right, from the same 3/4 top-down camera angle, in exactly the same pixel art style, palette and outline, large and centered in a square image. No muzzle flash, no smoke, no shells, no health bar. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

### `boss_tank`（附剛生成的 `tank`）

```
Using the attached tank sprite, draw a much bigger and heavier boss version of the same tank in exactly the same pixel art style, palette and outline: thicker dark-olive armor plates with rivets, a wide steel dozer blade on the front, a larger turret with two cannons, a bigger angry cat-face emblem, and a few scratches and dents. Same facing (right), same 3/4 top-down camera angle, large and centered in a square image. No muzzle flash, no smoke. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

### `chef`（附 ann2）

```
Redraw only one of the chef enemies from the attached game screenshot: white chef hat, white double-breasted jacket, red neckerchief, thick black mustache, angry face, holding a black frying pan raised in one hand. Show him alone, full body, facing right, from the same 3/4 top-down camera angle, in exactly the same pixel art style, palette and outline, large and centered in a square image. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

### `chiang`（附 ann3）

```
Redraw only the bald boss from the attached game screenshot: bald head, stern frowning face, black military coat with gold trim, gold epaulettes, gold buttons and chains, red cape, black boots. Show him alone, full body, standing with both arms lowered at his sides and empty hands (no baton, no reaching hand), body turned slightly to the right, from the same 3/4 top-down camera angle, in exactly the same pixel art style, palette and outline, large and centered in a square image. No red slash effect, no rocks. Flat solid pure magenta background (#FF00FF) filling the whole image, no gradient, no floor, no ground shadow, no scenery, no text, no UI. Do not use magenta or purple anywhere on the subject.
```

---

## 組合圖（kit）

### `items`：4 欄 × 3 列（附 ann1）

```
A sprite sheet of 9 separate small game items in exactly the same pixel art style, palette and outline as the attached game screenshot, arranged in a grid of 4 columns and 3 rows. Each item is centered in its own equal-sized cell, with lots of empty background between items; no item touches its cell edge. Row 1, left to right: (1) the glowing sugarcane projectile from the screenshot: a short bright green sugarcane segment with joints and two small leaves, yellow-green glow, lying horizontally and pointing right; (2) an orange glowing tank shell with a short flame trail, pointing right; (3) a single round green pea; (4) a short yellow corn cob piece. Row 2, left to right: (5) a small orange carrot; (6) a glowing cyan-blue experience crystal gem; (7) a shiny red heart pickup; (8) a black pistol pointing right. Row 3: (9) in the leftmost cell, a shiny gold coin like the coin icon in the top-right corner of the screenshot; the other three cells of row 3 stay completely empty background. Flat solid pure magenta background (#FF00FF) everywhere, no grid lines, no labels, no text, no shadows. Do not use magenta or purple on any item. Landscape 4:3.
```

### `obstacles`：2 × 2（附 ann1 與 ann3）

```
A sprite sheet of 4 separate obstacle props in exactly the same pixel art style, palette, outline and 3/4 top-down camera angle as the attached game screenshots, arranged in a grid of 2 columns and 2 rows. Each prop is centered in its own equal-sized cell, with lots of empty background between props; no prop touches its cell edge. Top left: a stack of two wooden supply crates with metal corners. Top right: a long low wall of stacked beige sandbags, about three times as wide as it is tall. Bottom left: a wooden Czech hedgehog barricade made of crossed beams. Bottom right: a square grey carved stone block like the ones in the dark courtyard screenshot. Flat solid pure magenta background (#FF00FF) everywhere, no ground shadows, no grid lines, no labels, no text. Do not use magenta or purple on any prop. Square image.
```

### `abilities`：4 × 4（附 ann1，對照下方那三個技能圖示）

```
A sheet of 16 square skill icons in exactly the same style as the three skill icons at the bottom of the attached game screenshot: rounded-square tile, dark background inside the tile, thin light border, bright glowing green sugarcane motifs, chunky pixel art. Arrange them in a grid of 4 columns and 4 rows, equal cells, each icon centered with a clear gap of background around it. In reading order (left to right, top to bottom): 1 two sugarcanes flying forward side by side; 2 three sugarcanes flying in a quick line one after another; 3 two sugarcanes flying diagonally up-left and up-right; 4 two sugarcanes flying straight left and right; 5 one sugarcane flying backward (downward); 6 a sugarcane piercing straight through a target; 7 a sugarcane bouncing between enemies with a zigzag trail; 8 a sugarcane bouncing off a brick wall; 9 a flaming sugarcane in orange and red fire; 10 an icy blue frozen sugarcane with snowflakes; 11 a sugarcane with a big red upward arrow; 12 a sugarcane with speed lines and a yellow lightning bolt; 13 a sugarcane hitting a target with a yellow critical-hit starburst; 14 a green heart with a plus sign; 15 a red heart with a green healing cross and sparkles; 16 an empty dark tile with no symbol. Flat solid pure magenta background (#FF00FF) outside the tiles, no text, no numbers, no grid lines. Do not use magenta or purple inside the tiles. Square image.
```

### `portraits`：2 × 2（附 ann1 與 ann3，對照左上角的圓形頭像）

```
A sheet of 4 round character portrait icons in exactly the same style as the circular portraits in the top-left corner of the attached game screenshots: head and shoulders filling a circle, dark navy background inside the circle, thin gold ring around it, chunky pixel art. Arrange them in a grid of 2 columns and 2 rows, equal cells, each portrait centered with a clear gap around it. Top left: the hero boy (messy black hair, black suit, white shirt, red tie, determined smile). Top right: the bald boss (stern frowning face, black collar with gold trim and epaulettes). Bottom left: the front of a heavy olive-green tank with an angry cat-face emblem and two cannons. Bottom right: an empty navy circle with a gold ring. Flat solid pure magenta background (#FF00FF) outside the circles, no text. Do not use magenta or purple inside the circles. Square image.
```
