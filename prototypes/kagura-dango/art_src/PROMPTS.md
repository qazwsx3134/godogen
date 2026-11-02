# 第一批美術：opt image 提示詞

畫風：**像素漫畫風**，在手機小螢幕上要一眼看懂，動作也一樣。生成好的原圖存到 `art_src/gen/<檔名>.png`（只放本機，不進 git），我再去背、切格、縮到遊戲尺寸，放進 `assets/`。

## 共通規則（每一張都適用，已寫進下面每段 prompt）

- 角色與道具：**純洋紅 `#FF00FF` 背景**，不要透明棋盤格、不要地面影子、不要文字或格線。角色一律**朝右**（神樂在遊戲裡翻面）。
- 像素：16-bit 風，大顆像素清楚可見，色數少（約 24 色），1～2 像素深色粗外框，剪影要清楚。
- 動作圖是**一張橫條**：一列、每格等寬、格與格之間留大片洋紅空白；每格角色一樣大，**腳底在同一條水平線**。動作要誇張，用姿勢說故事，不靠細節。
- **參考圖**：每張都附上角色的現有立繪，鎖住長相與服裝；動作圖再附上已生好的定裝圖。prompt 第一句已註明「參考圖只取長相、髮型、服裝與配色」。
  - 銀時：`prototypes/debt-commission/assets/image/gintoki.png`、`expressions/gintoki_smug.png`
  - 新八：`prototypes/debt-commission/assets/image/shin-pa-chi.png`、`expressions/shinpachi_shout.png`
  - 神樂：`prototypes/debt-commission/assets/image/kagura-chan.png`、`expressions/kagura_smile.png`
- 遊戲尺寸（我縮圖用，生成時不必管）：角色高約 96 px、丸子串長約 40 px（大串 64 px）、背景與標題圖 400×180，畫面上放大 2 倍。

順序：先生 3 張定裝（A1～A3）並確認長相，再把定裝圖當參考生動作。

| 檔名 | 內容 | 格數 |
|---|---|---|
| `gintoki_ref` | 銀時定裝 | 1 |
| `shinpachi_ref` | 新八定裝 | 1 |
| `kagura_ref` | 神樂定裝 | 1 |
| `gintoki_toss` | 銀時拋丸子：蓄力、拋出、收手 | 3 |
| `gintoki_idle` | 銀時待機（端著一盤丸子） | 2 |
| `kagura_ready` | 神樂張大嘴等 | 2 |
| `kagura_chomp` | 神樂咬下、嚼 | 2 |
| `kagura_miss` | 神樂漏接生氣 | 1 |
| `kagura_full` | 神樂吃飽滿足（結算用） | 1 |
| `shinpachi_cheer` | 新八加油 | 2 |
| `shinpachi_shock` | 新八驚嚇（漏接時） | 1 |
| `dango_props` | 丸子道具表：一般串、大串、空竹籤、掉落的單顆丸子 | 4 |
| `bg_contest` | 丸子大胃王比賽會場背景 | — |
| `title_art` | 標題主視覺 | — |

---

## A1 `gintoki_ref`

```
Use the attached images only for the character's face, hair, outfit and colors; output must be pixel art, not a copy of the images.
16-bit pixel art sprite of Sakata Gintoki from Gintama, full body, standing, three-quarter view facing RIGHT. Silver messy naturally-wavy hair, lazy half-closed "dead fish" eyes, white kimono with blue swirl pattern on the hem worn with the left arm out of the sleeve, black shirt and black pants underneath, boots, wooden sword at the waist. Chunky clearly visible pixels, limited palette about 24 colors, 1-2 pixel dark outline, bold readable silhouette, comic expression. Solid flat magenta #FF00FF background, no shadow, no ground, no text, no border.
```

## A2 `shinpachi_ref`

```
Use the attached images only for the character's face, hair, outfit and colors; output must be pixel art, not a copy of the images.
16-bit pixel art sprite of Shimura Shinpachi from Gintama, full body, standing, three-quarter view facing RIGHT. Short black hair, round glasses, light blue and white kimono top, dark blue hakama, straight-man earnest expression. Chunky clearly visible pixels, limited palette about 24 colors, 1-2 pixel dark outline, bold readable silhouette. Solid flat magenta #FF00FF background, no shadow, no ground, no text, no border.
```

## A3 `kagura_ref`

```
Use the attached images only for the character's face, hair, outfit and colors; output must be pixel art, not a copy of the images.
16-bit pixel art sprite of Kagura from Gintama, full body, standing, three-quarter view facing RIGHT. Vermilion orange hair in two buns with hair covers, big blue eyes, red Chinese-style dress with yellow trim, cheerful confident grin. Chunky clearly visible pixels, limited palette about 24 colors, 1-2 pixel dark outline, bold readable silhouette. Solid flat magenta #FF00FF background, no shadow, no ground, no text, no border.
```

## B1 `gintoki_toss`（附 `gintoki_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 3 equal-width cells, wide magenta gaps between cells, the same character at the same size in every cell, feet on the same baseline, facing RIGHT. 16-bit pixel art Gintoki throwing a dango skewer underhand toward the right:
cell 1: wind-up, right arm swung far back holding a dango skewer, body leaning back, knees bent;
cell 2: release, arm swung forward and up, the skewer just leaving his hand, body leaning forward;
cell 3: follow-through, arm up high, lazy satisfied face.
Exaggerated, very readable poses. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## B2 `gintoki_idle`（附 `gintoki_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Gintoki holding a plate stacked with dango skewers in his left hand, bored face; cell 2 is the same pose with the shoulders slightly lower (breathing loop). Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## B3 `kagura_ready`（附 `kagura_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Kagura leaning forward with her mouth opened comically wide, sparkling hungry eyes, hands in fists; cell 2 is the same pose bobbing slightly lower (waiting loop). Exaggerated comic expression, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## B4 `kagura_chomp`（附 `kagura_ref`、`kagura_ready`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Kagura eating dango:
cell 1: CHOMP, mouth snapped shut on a dango skewer, cheeks puffed, eyes squeezed shut with joy;
cell 2: chewing, cheeks bulging, happy closed-eye smile, small crumbs.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## B5 `kagura_miss`（附 `kagura_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Single 16-bit pixel art sprite, facing RIGHT, feet at the bottom. Kagura furious after missing a dango: shouting with a huge open mouth, comic anger vein, arms flailing, comic tears. Exaggerated and very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text.
```

## B6 `kagura_full`（附 `kagura_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Single 16-bit pixel art sprite, facing RIGHT, feet at the bottom. Kagura completely satisfied after eating a mountain of dango: round full belly, patting it with one hand, the other hand giving a thumbs up, blissful closed-eye grin, a few empty skewers in her hair. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text.
```

## B7 `shinpachi_cheer`（附 `shinpachi_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Shinpachi cheering: cell 1 both arms raised high, mouth open shouting; cell 2 arms down in fists, small hop. Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## B8 `shinpachi_shock`（附 `shinpachi_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Single 16-bit pixel art sprite, facing RIGHT, feet at the bottom. Shinpachi in comic shock: jumping back, glasses flying off his face, white blank eyes, mouth open in a scream, hands up. Exaggerated and very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text.
```

## C1 `dango_props`

```
16-bit pixel art item sheet, 1 row x 4 equal-width cells with wide magenta gaps, one item per cell, all drawn horizontally:
cell 1: a Japanese tricolor dango skewer (pink, white, green balls on a wooden stick);
cell 2: a giant version of the same skewer, twice as long with bigger balls and a sparkle;
cell 3: an empty wooden skewer stick;
cell 4: a single pink dango ball.
Chunky clearly visible pixels, about 16 colors, 1 pixel dark outline, very readable at small size. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

---

# 第三批（2026-11-03：第 1 回合上菜店主）

## G1 `store_owner_serve`（附 `referee_ref`、`rival_team_0`；只參考像素畫風）

```
Create one standalone 16-bit pixel art game sprite of a generic Edo-period Japanese wagashi shop owner serving dango. Use the attached sprites only as style references; do not copy their characters. Full-body, three-quarter view facing RIGHT, one static pose, clearly readable at a target height of 96 pixels. A friendly middle-aged male shopkeeper with a short dark topknot, white headband, cream-and-indigo striped happi coat, burgundy sash, and muted brown waist apron. Lean forward slightly and extend both hands toward the RIGHT, holding a small flat wooden serving tray with three colorful dango skewers (pink, white, green) visible on it. Make the tray and hands large enough to read on a phone screen; keep the full body and tray inside the frame. Chunky visible 16-bit pixels, limited palette around 24 colors, 1-2 pixel dark outline, bold silhouette, cheerful energetic expression. Solid flat magenta #FF00FF background, no transparency grid, no ground shadow, no floor, no text, no border, no extra character.
```

## D1 `bg_contest`

```
16-bit pixel art background, wide 20:9 landscape. Interior of a Japanese Edo-style sweet shop hosting a dango eating contest: wooden walls, red noren curtains and paper lanterns along the top, a long low wooden table across the bottom fifth, a small crowd of simple silhouetted spectators in the far back. Keep the middle band of the picture plain and uncluttered (characters stand there). Top 12% and bottom 10% may be darker (UI bars go there). Warm cream and wood palette, chunky visible pixels, about 32 colors. No characters in front, no text, no signs with letters.
```

## E1 `title_art`

```
Use the attached images only for the character's look.
16-bit pixel art title illustration, wide 20:9 landscape. Kagura from Gintama in the lower middle third, hugging a giant tricolor dango skewer bigger than she is, huge happy grin, confetti and dango flying around, a birthday cake with candles beside her; Gintoki and Shinpachi small at the sides cheering. Leave the top quarter as plain warm sky-colored space for the title. Chunky visible pixels, about 32 colors, bold readable shapes. No text, no letters, no logo.
```

---

# 第三批追加（v3 劇情玩法：2026-11-03）

接續本檔既有的 `store_owner_serve` 素材。新圖沿用 16-bit 像素漫畫風、大像素、粗深色外框；角色／道具以純洋紅 `#FF00FF` 為去背底，不要字幕、水印或格線。原作截圖只作構圖與姿勢參考，重畫為全新像素圖，不直接貼圖或照搬字幕、標誌。動作橫條一律一列、等寬、每格留寬洋紅空隙，腳底對齊。

| 檔名 | 內容 | 格數／輸出尺寸 |
|---|---|---|
| `kagura_rice` | 神樂左手捧飯碗、右手拿丸子串 | 1 格，角色高 96 px |
| `rice_bowl` | 獨立飯碗提示圖示 | 1 格，32×32 px |
| `shinpachi_bento` | 新八逐串裝盒、蓋上、便當完成 | 3 格，角色高 96 px |
| `gintoki_kick` | 銀時蓄力、踢開、收腳 | 3 格，角色高 96 px |
| `gintoki_dart` | 胖銀時瞄準、把丸子串像飛鏢投出 | 2 格，角色高 96 px |
| `shinpachi_dart` | 胖新八瞄準、把丸子串像飛鏢投出 | 2 格，角色高 96 px |
| `kagura_eye_hit` | 神樂被丸子擊中眼睛的搞笑受擊 | 1 格，角色高 96 px |
| `life_dango` | 生命值圖示 | 1 格，32×32 px |
| `scoreboard_panel` | 綠隊／粉隊、疊盤區、空白電子計時器 | 1 張，400×120 px |
| `commentator_pair` | 兩位全新風格的比賽實況解說 | 1 格，角色高 96 px |
| `bg_torii_park` | 鳥居、藍天、公園樹林與戶外大胃王會場 | 1 張，640×360 px |

## V3-A `kagura_rice`（附 `kagura_ref`，姿勢參考 `assets/example/螢幕擷取畫面 2026-11-03 010127.jpg`）

```
Use Image 1 only for Kagura's pixel-art character identity and outfit; Image 2 only for the idea of holding rice while eating dango. Redraw a new game sprite; do not reproduce the anime frame, subtitles, watermark, or background.
One standalone full-body 16-bit pixel-art sprite of Kagura, three-quarter view facing RIGHT, vermilion-orange hair buns and red Chinese-style dress with yellow trim. She holds a small blue-and-white rice bowl in her LEFT hand and a tricolor dango skewer in her RIGHT hand, glancing eagerly between them as if alternating bites. Make both bowl and skewer unmistakable at 96-pixel character height. Chunky visible pixels, limited palette about 24 colors, bold 1-2 pixel dark outline, clear readable silhouette. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-B `rice_bowl`

```
One standalone 16-bit pixel-art game item icon: a small blue-and-white Japanese rice bowl filled with a neat mound of white rice, three-quarter view, centered, large and unmistakable at 32 by 32 pixels. Chunky visible pixels, limited palette about 12 colors, bold 1-pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no chopsticks, no extra objects.
```

## V3-C `shinpachi_bento`（附 `shinpachi_ref`，姿勢參考 `assets/example/螢幕擷取畫面 2026-11-03 010210.jpg`）

```
Use Image 1 only for Shinpachi's pixel-art identity, glasses and blue-white outfit; Image 2 only as broad reference for the bento-packing action. Redraw a new sprite strip; do not reproduce the anime frame, subtitles, watermark, or background.
Horizontal sprite strip, 1 row x 3 equal-width cells, wide magenta gaps, same full-body size in every cell, feet on one baseline, facing RIGHT. 16-bit pixel-art Shinpachi with round glasses packs dango skewers into a rectangular lacquer bento box on a low table: cell 1 carefully places one skewer into the open box, cell 2 places the next skewer and folds the lid down, cell 3 proudly presents the closed filled bento. Keep face, glasses, box and hand action clearly separated and readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-D `gintoki_kick`（附 `gintoki_ref`，姿勢參考 `assets/example/螢幕擷取畫面 2026-11-03 010047.jpg`）

```
Use Image 1 only for Gintoki's pixel-art identity, silver hair and white kimono; Image 2 only for the dynamic kick silhouette. Redraw a new sprite strip; do not reproduce the anime frame, other character, subtitles, watermark, or background.
Horizontal sprite strip, 1 row x 3 equal-width cells, wide magenta gaps, same full-body size in every cell, feet on one baseline, facing RIGHT. 16-bit pixel-art Gintoki kicks an unseen intruder away from the contest: cell 1 plants his feet and winds up with one knee raised, cell 2 snaps a strong side kick toward the RIGHT with a small impact burst at the boot, cell 3 lowers his leg and returns to his bored stance. Keep the whole body in each cell. Chunky visible pixels, limited palette about 24 colors, bold 1-2 pixel dark outline, very readable poses. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-E `gintoki_dart`（附 `gintoki_ref` 與 `assets/example/螢幕擷取畫面 2026-11-03 010240.jpg`；後者只參考圓胖身形）

```
Use Image 1 only for Gintoki's pixel-art identity and costume; Image 2 only for a broad comically round body silhouette. Redraw a new character; do not copy any person or anime frame.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same full-body size and baseline. 16-bit pixel-art Gintoki, unmistakable silver messy hair and white kimono with blue swirl hem, now comically round and belly-heavy but still mobile. Facing RIGHT, he throws a dango skewer like a dart toward the RIGHT: cell 1 squints and aims the skewer back beside his shoulder, cell 2 leans forward and releases the skewer with a clean follow-through. Keep his hands, skewer and belly silhouette clear at 96-pixel character height. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-F `shinpachi_dart`（附 `shinpachi_ref` 與 `assets/example/螢幕擷取畫面 2026-11-03 010240.jpg`；後者只參考圓胖身形）

```
Use Image 1 only for Shinpachi's pixel-art identity, glasses and blue-white outfit; Image 2 only for a broad comically round body silhouette. Redraw a new character; do not copy any person or anime frame.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same full-body size and baseline. 16-bit pixel-art Shinpachi, short black hair and unmistakable round glasses, drawn VERY fat for a slapstick transformation: dramatically spherical torso, huge protruding belly wider than his shoulders, robe stretched over the belly, fuller cheeks and short sturdy legs; do not make him average-sized or merely broad. The large belly silhouette must be obvious in BOTH cells. Facing RIGHT, he throws a dango skewer like a dart toward the RIGHT: cell 1 looks nervous and aims the skewer beside his shoulder, cell 2 thrusts forward and releases it, glasses firmly on his face. Keep hands, skewer, glasses and belly silhouette clear at 96-pixel character height. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-G `kagura_eye_hit`（附 `kagura_ref`，姿勢參考 `assets/example/螢幕擷取畫面 2026-11-03 010401.jpg`）

```
Use Image 1 only for Kagura's pixel-art identity and outfit; Image 2 only for the slapstick idea of dango briefly covering her eyes. Redraw a new sprite; do not reproduce the anime frame, subtitles, watermark, or background.
One standalone full-body 16-bit pixel-art game sprite of Kagura facing RIGHT. A dango skewer has comically bounced across her eyes like a soft harmless bonk; eyes squeezed shut, surprised crooked mouth, tiny impact star and a few crumbs. Keep it lighthearted, nonviolent, no injury or blood. Vermilion-orange hair buns, red Chinese-style dress, bold readable silhouette at 96-pixel character height. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no border, no extra characters.
```

## V3-H `life_dango`

```
One standalone 16-bit pixel-art life icon for a small game HUD: a plump pink heart-shaped dango with a tiny wooden skewer, friendly and instantly readable as one remaining life. Centered square composition, bold silhouette, chunky pixels, limited palette about 8 colors, dark 1-pixel outline; readable at 32 by 32 pixels. Solid flat magenta #FF00FF background, no shadow, no text, no border, no extra objects.
```

## V3-I `scoreboard_panel`（參考 `assets/example/螢幕擷取畫面 2026-11-03 010001.jpg` 的版面）

```
Redraw a new 16-bit pixel-art game HUD scoreboard inspired only by the broad layout of Image 1; do not reproduce its lettering, logos, or exact screen. Front-on wide horizontal rectangular panel with a solid deep-navy outer fill. Two clear side-by-side team zones, left deep green and right warm pink, each with an empty area where dynamic plate stacks and score numbers will be drawn later. Across the top center, a dark electronic timer window with blank seven-segment display cells (no digits or text). Wood-and-lacquer frame, thick pixel borders, strong light-dark contrast, chunky pixels, about 24 colors. No words, no letters, no numerals, no people, no screenshot UI, no watermark.
```

## V3-J `commentator_pair`（姿勢／服裝色塊參考 `assets/example/螢幕擷取畫面 2026-11-03 005854.jpg`）

```
Use Image 1 only as broad reference for an Edo tournament commentator pair and their contrasting blue / warm colors. Redraw two new generic commentators; do not copy exact faces, anime line art, subtitles, watermark, microphones from the screenshot, or background.
One standalone 16-bit pixel-art cutout showing two full-body Edo-period food-contest commentators standing side by side, both facing RIGHT: a tall confident announcer in a slate-blue haori and white headband holding a simple microphone, plus a shorter elderly gourmet in a muted orange cap and brown coat holding one dango skewer. Different silhouettes and expressions, friendly live-broadcast energy, sized to read together at 96-pixel character height. Chunky pixels, limited palette about 24 colors, bold 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no floor, no text, no logo, no border, no extra characters.
```

## V3-K `bg_torii_park`（參考 `assets/example/螢幕擷取畫面 2026-11-03 005707.jpg`、`005818.jpg`）

```
Create an original 16-bit pixel-art 16:9 landscape game background, using Images 1 and 2 only for the broad torii / park contest layout. Do not reproduce the anime frames, exact buildings, subtitles, watermark, logos, or any recognizable character.
An outdoor Edo-era dango eating contest in a Japanese park: clear bright blue sky and soft clouds, a large vermilion torii gate framing the far side of the grounds, deep green trees around the edges, a broad sandy contest field, and small distant green-team and pink-team tables. Keep the center middle band open and uncluttered for the player characters; keep the upper 12% and lower 10% visually quiet for HUD. Warm, cheerful birthday-daylight mood, chunky visible pixels, about 32 colors, crisp bold shapes, landscape 16:9 composition. No foreground characters, no words, no readable signs, no watermark.
```

---

# 第二批（2026-11-02 追加：三回合、裁判、對手隊、神樂變胖）

第一批的檔名和 prompt 都不變。現有的 `kagura_ready`＋`kagura_chomp` 就是神樂的**第 1 體型**；下面追加第 2、3 體型，版面相同。裁判與對手隊在原作裡具體是誰還沒確定，先用通用造型。之後指定人物時，只要改這兩段的外觀描述。

| 檔名 | 內容 | 格數 |
|---|---|---|
| `kagura_tier2` | 神樂第 2 體型（明顯變圓）：張嘴等、張嘴等（低一點）、咬下、嚼 | 4 |
| `kagura_tier3` | 神樂第 3 體型（圓滾滾）：同上 4 格 | 4 |
| `gintoki_eat` | 第 1 回合的銀時：張嘴等、咬下 | 2 |
| `shinpachi_eat` | 第 1 回合的新八：張嘴等、咬下 | 2 |
| `gintoki_full` | 銀時吃撐：臉色發青、冒汗、摸肚子 | 1 |
| `shinpachi_full` | 新八吃撐：眼鏡起霧、癱軟 | 1 |
| `referee_ref` | 裁判定裝 | 1 |
| `referee_call` | 裁判：舉旗喊開始、指向前方喊停 | 2 |
| `rival_team` | 對手隊兩人：各自的待機與大口吃 | 4 |
| `dango_flavors` | 紅豆丸子串、醬油丸子串 | 2 |

## F1 `kagura_tier2`（附 `kagura_ref`、`kagura_ready`、`kagura_chomp`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size, head size and colors as the attached pixel sprites.
Horizontal sprite strip, 1 row x 4 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Kagura who has eaten a lot of dango: her body and belly are clearly rounder and wider (about 1.4x as wide), same head and face, dress stretched.
cell 1: leaning forward with mouth opened comically wide, hungry sparkling eyes;
cell 2: same pose bobbing slightly lower;
cell 3: CHOMP, mouth snapped shut on a skewer, cheeks puffed;
cell 4: chewing happily, cheeks bulging.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## F2 `kagura_tier3`（附 `kagura_ref`、`kagura_tier2`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size, head size and colors as the attached pixel sprites.
Horizontal sprite strip, 1 row x 4 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art Kagura after eating a mountain of dango: her body is almost a ball (about 1.9x as wide as normal), tiny feet, same head and face, still determined.
cell 1: mouth opened comically wide, fierce determined eyes;
cell 2: same pose bobbing slightly lower;
cell 3: CHOMP, mouth snapped shut on a skewer, cheeks puffed, the whole body bouncing;
cell 4: chewing, sweat drops, still grinning.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## F3 `gintoki_eat`（附 `gintoki_ref`）／F4 `shinpachi_eat`（附 `shinpachi_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art [Gintoki / Shinpachi] at an eating contest:
cell 1: leaning forward, mouth open, waiting for a dango skewer;
cell 2: CHOMP, biting a skewer, cheeks puffed.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## F5 `gintoki_full`（附 `gintoki_ref`）／F6 `shinpachi_full`（附 `shinpachi_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Single 16-bit pixel art sprite, facing RIGHT, feet at the bottom. [Gintoki: completely stuffed with sweets, face turning pale blue, cold sweat, one hand on his stomach, the other raised in surrender / Shinpachi: stuffed and limp, glasses fogged white, slumping, sweat drops]. Exaggerated comic expression, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text.
```

## F7 `referee_ref`

```
16-bit pixel art sprite of an eating-contest referee in an Edo-period comedy setting, full body, standing, facing RIGHT. A middle-aged man with a headband, a striped happi coat, holding a small red flag, loud excited expression. Chunky clearly visible pixels, about 24 colors, 1-2 pixel dark outline, bold readable silhouette. Solid flat magenta #FF00FF background, no shadow, no ground, no text, no border.
```

## F8 `referee_call`（附 `referee_ref`）

```
Use the attached images only for the character's look; keep exactly the same pixel art style, size and colors as the attached pixel sprite.
Horizontal sprite strip, 1 row x 2 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art referee:
cell 1: "START!" flag thrust high into the air, shouting;
cell 2: "STOP!" arm pointing straight forward, flag down, shouting.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## F9 `rival_team`

```
Horizontal sprite strip, 1 row x 4 equal-width cells, wide magenta gaps, same size, feet on the same baseline, facing RIGHT. 16-bit pixel art rival team of two big-eater champions at a dango eating contest in an Edo-period comedy setting (a huge muscular man with a topknot, and a lean woman with a confident smirk), matching purple happi coats:
cell 1: the man waiting, arms crossed; cell 2: the man stuffing three skewers into his mouth at once;
cell 3: the woman waiting, chopsticks ready; cell 4: the woman slurping a skewer in one bite.
Exaggerated, very readable. Chunky pixels, about 24 colors, 1-2 pixel dark outline. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

## F10 `dango_flavors`（附 `dango_props`）

```
Use the attached image only for the style; keep exactly the same pixel art style and size.
16-bit pixel art item sheet, 1 row x 2 equal-width cells with wide magenta gaps, one item per cell, drawn horizontally:
cell 1: a skewer of three dango covered in dark red bean paste (anko);
cell 2: a skewer of three grilled dango glazed with shiny amber sweet soy sauce (mitarashi).
Chunky clearly visible pixels, about 16 colors, 1 pixel dark outline, very readable at small size. Solid flat magenta #FF00FF background, no shadow, no text, no grid lines.
```

---

# 第四批（2026-11-03：神樂生日結尾插圖）

## K1 `kagura_birthday`

```
Create a full-bleed, opaque 16-bit pixel-comic illustration for a 16:9 game ending screen, composed for a final 640x360 display. Kagura is the joyful center: unmistakable orange-red hair buns, red Chinese-style dress with yellow trim, smiling while hugging an enormous skewer of pink, white, and green dango beside a birthday cake with candles. Gintoki, with messy silver hair and a white kimono, stands at one side; Shinpachi, with short dark hair, round glasses, and a blue-and-white outfit, stands at the other. They are laughing and pulling colorful party poppers, with streamers and confetti arcing around the side edges. Keep the upper 22% of the image, especially the upper center, as calm uncluttered blue-sky / soft festival-light negative space so the game can overlay the exact title 「神樂生日快樂」 there. Keep all three faces and the cake visible in the lower 78%; warm, affectionate birthday celebration, lively but clear composition. Use the same chunky, high-contrast 16-bit pixel-comic style as the game's existing art, deliberate visible pixel clusters, bold dark outlines, limited harmonious palette. Draw a new illustration, not a screenshot or copied anime frame. No text or lettering of any kind, no logo, no watermark, no border, no transparent or magenta background.
```
