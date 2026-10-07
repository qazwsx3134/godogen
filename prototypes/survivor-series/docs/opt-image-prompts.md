# opt image：第一批六份素材提示詞

生成方式已確認：由使用者把下列提示詞貼入 opt image 生成，代理不直接生成圖片。

美術方向以 [art-direction.md](art-direction.md) 與參考圖 [reference/art-direction-night-market.png](reference/art-direction-night-market.png) 為準：高細節像素風、略大頭的 Q 版比例、台灣夜市暖色燈籠夜景。所有圖片共用同一個 2D 斜俯視、近似正交的觀看角度（約 45～55 度）；背景是軸對齊的矩形街區，不用等角菱形格。角色表情可讀，但不採側視。以下配色與外觀由使用者提供的文字與參考圖決定；替換時保持男女主角與敵人之間的輪廓與色相差異。

## 交接清單

| 檔名 | 建議生成畫布 | 背景 | 用途 |
|---|---|---|---|
| `hero_man.png` | 1024×1024 | 透明 | 男主角（厭世西裝）待機／移動／揮擊的基礎圖 |
| `hero_woman.png` | 1024×1024 | 透明 | 女主角（冷酷外套）待機／移動／出掌的基礎圖 |
| `smoker_idle.png` | 1024×1024 | 透明 | 抽菸者：被煙霧吞噬的黑煙團與紅眼 |
| `motorcycle_idle.png` | 1024×1024 | 透明 | 騎士與機車一起呈現 |
| `car_idle.png` | 1024×1024 | 透明 | 汽車與可辨認的駕駛 |
| `street_block.png` | 1200×1680，5:7 | 不透明 | 夜市街區背景（鏡頭跟著主角） |

工具不支援精確尺寸時，選角色 1:1、背景 5:7（或 3:4 再裁切）；原圖保留，匯入前再縮放。每份提示詞生成一張獨立圖，不做拼圖。後續生成時能附參考圖就附 `reference/art-direction-night-market.png` 與已選定的主角圖，保持同一套線條、色彩與視角。

角色與車輛使用單一靜態姿勢，不生成動畫表。背景不包含主角、敵人、煙霧、預警線或 UI；煙霧與打擊效果由遊戲獨立疊加。角色圖不畫地面陰影，避免揍飛時把陰影一起帶上天。

像素風的共同要求：生成後把角色縮到實際像素密度（角色高約 80～100 px），用最近鄰縮放，不用雙線性；專案的預設貼圖過濾已是 Nearest，`Art` 的 scale 要接近整數倍，不然像素邊緣會糊。

## 1. 男主角 — hero_man.png

```text
Create ONE production-ready 2D game character sprite in detailed pixel-art style for a portrait mobile survivor game. A fictional adult man, chibi proportions with a slightly large head, slouched drooping shoulders, black hair slicked straight back, half-lidded tired eyes (world-weary, "too tired to care"), a navy-blue business suit and a bold bright red necktie, black shoes. Idle stance: a slight hunch, arms hanging loose with relaxed fists.

Crisp pixel clusters, dark outline, limited warm palette, strong silhouette readable at about 90 px tall. Elevated three-quarter overhead view, approximately 50 degrees above the ground, nearly orthographic. Full body facing diagonally toward the lower-right, both feet clearly visible.

Square 1024 x 1024 canvas. Exactly one character centered, generous clear padding, no cropped hands or feet. True transparent PNG background. No ground plane, no cast shadow, no background, no text, no UI, no weapon, no smoke, no impact effect, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 2. 女主角 — hero_woman.png

```text
Create ONE production-ready 2D game character sprite in detailed pixel-art style for a portrait mobile survivor game. A fictional adult woman, chibi proportions with a slightly large head, wine-red shoulder-length hair, a short black jacket over a light-blue top and a short light-blue skirt, dark tights, white boots. Upright, composed stance, crisp and decisive; cold, sharp eyes drawn as simple narrow angular lines (NOT large sweet anime eyes, not cute). One hand slightly forward, open palm ready.

Crisp pixel clusters, dark outline, limited warm palette, strong silhouette readable at about 90 px tall. Same camera and scale as the man: elevated three-quarter overhead view, approximately 50 degrees above the ground, nearly orthographic. Full body facing diagonally toward the lower-right, both boots clearly visible.

Square 1024 x 1024 canvas. Exactly one character centered, generous clear padding, no cropped hands or feet. True transparent PNG background. No ground plane, no cast shadow, no background, no text, no UI, no weapon, no smoke, no impact effect, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 3. 抽菸者（煙霧怪）— smoker_idle.png

```text
Create ONE production-ready 2D enemy sprite in detailed pixel-art style matching a night-market survivor game. A small ominous mass of black-purple smoke shaped like a lumpy cloud with stubby wisps for limbs, two glowing angry red eyes and a faint cigarette ember glowing inside the smoke. It reads as a fictional smoker swallowed by his own smoke. Soft grey smoke wisps at the edges, readable as a swarm member at about 60 px.

Crisp pixel clusters, dark outline, strong silhouette, clearly different from the navy-suit man and the wine-red-hair woman. Elevated three-quarter overhead view about 50 degrees, nearly orthographic. A static idle pose.

Square 1024 x 1024 canvas. Exactly one creature centered with generous padding. True transparent PNG background. No ground plane, no cast shadow, no background, no text, no UI, no impact effect, no duplicate poses, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 4. 機車與騎士 — motorcycle_idle.png

```text
Create ONE production-ready 2D enemy sprite in detailed pixel-art style: a fictional adult rider seated on a compact dark navy urban motor scooter with a glowing red tail light. Rider wears a white helmet, dark jacket and dark trousers, with an impatient expression visible through an open visor. The rider and the entire scooter form ONE connected sprite, including both wheels, handlebars, mirrors and the whole rider. Clear recognizable Taiwanese scooter silhouette, no real manufacturer branding, no readable license-plate text.

Crisp pixel clusters, dark outline, limited warm palette, strong small-size readability, matching the pedestrian heroes. Elevated three-quarter overhead view, approximately 50 degrees above the ground, nearly orthographic. Scooter points diagonally toward the lower-right. Stationary pose, both wheels clearly visible. Do not use a side profile or a low-angle camera.

Square 1024 x 1024 canvas. Exactly one rider-and-scooter unit centered with generous padding; no cropped wheels or helmet. True transparent PNG background. No ground plane, no cast shadow, no road, no exhaust, no motion trails, no warning arrows, no text, no UI, no duplicate poses, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 5. 汽車與駕駛 — car_idle.png

```text
Create ONE production-ready 2D enemy sprite in detailed pixel-art style: a chunky mustard-yellow compact city car with an annoyed fictional adult driver clearly visible behind a light windshield. Exaggerated heavy bumper, large readable wheels, rounded sturdy body. The car should feel substantially heavier than a motor scooter. Driver remains inside the car; car and driver are ONE sprite. No real brand logos, no readable license-plate text.

Crisp pixel clusters, dark outline, limited warm palette, humorous proportions, strong small-size readability, matching the pedestrian heroes and the scooter. Elevated three-quarter overhead view, approximately 50 degrees above the ground, nearly orthographic. The entire car points diagonally toward the lower-right; roof, windshield, front bumper and visible side wheels are readable. Do not use a side profile, realistic photography, or a low-angle camera.

Square 1024 x 1024 canvas. Exactly one complete vehicle centered with generous transparent padding, no cropped bumper or wheels. True transparent PNG background. No ground plane, no cast shadow, no road, no exhaust, no speed lines, no impact effects, no text, no UI, no duplicate angles, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 6. 夜市街區 — street_block.png

背景是一整塊比畫面大的地圖，鏡頭會在上面移動。遊戲裡的尺寸是 1200×1680；中間有一條橫向的十字路口（y≈840）。地面維持軸對齊的矩形，不畫成等角菱形。

```text
Create ONE portrait 5:7 map background in detailed pixel-art style for a 2D mobile survivor game, ideally 1200 x 1680 pixels (larger is fine if the ratio stays 5:7). A fictional Taiwan night market street block at night, seen from an elevated three-quarter overhead view, approximately 50 degrees above the ground, nearly orthographic. The ground is a flat axis-aligned playable rectangle of warm grey-brown pavement tiles with wet reflective highlights from warm lantern light, NOT a tilted isometric diamond and NOT a perspective road vanishing into the distance.

Fill almost the whole image with a large open pavement play area. Along the perimeter only: striped red-and-white shop awnings over arcade (騎樓) stalls with fruit and snack displays, glowing red paper lanterns and string lights, potted plants in concrete planters, orange traffic cones, yellow-black striped bollards, and rows of parked dark scooters. Upper facades stay shallow so they cannot hide gameplay. ONE horizontal cross street through the middle (y about 840) with a small crosswalk and a few manhole covers. Keep the center quiet, low contrast and free of obstacles so enemies, smoke zones and warning lanes read clearly when added by the game.

One complete opaque background image. No characters, no pedestrians, no moving vehicles, no smoke, no fire, no attack effects, no warning lines, no arrows, no UI, no health bar, no joystick, no title, no text, no readable signs, no watermark. Spread small low details (manholes, tile seams, puddle highlights) evenly so movement reads when the camera scrolls. No strong depth of field, no photorealism.
```

## 到圖後的接入

將六張原圖放在 `assets/source/`，保留上述檔名。原圖與遊戲縮圖分開保存；素材規格未通過前不自動覆寫既有貼圖。接入時另做人物腳底／車輪接地點、透明留白、執行尺寸與碰撞區設定，保留 scene 可編輯：男主角圖指定給 `player.tscn` 的 `BodyMan`、女主角圖指定給 `BodyWoman`（各自加一個 Sprite2D 再隱藏該 Body 的幾何佔位）。

圖像檢查：角色是否單一且完整、透明底是否真的有 alpha、六張是否同視角與畫風、男女主角輪廓是否一眼分得出（男：垂肩、紅領帶；女：直挺、酒紅髮、白靴）、機車汽車是否連同人一起、背景中央是否留空。若透明底輸出成實心底或棋盤格，先重新輸出真正透明 PNG；不要把棋盤當成可直接用的素材。

第一批圖片不包含揮拳與出掌的逐格圖、背向角色或不同車向；現階段以移動、翻轉與 scene 動畫驗證玩法。若試玩需要更多方向與逐格動作，再依已選定的參考圖建立第二批提示詞。

## 第二批（2026-10-07 割草版）

第一批選定的男女主角圖與參考圖要一起附上，保持像素風、配色與 50 度視角一致。共同規格：1024×1024、真透明 PNG、一張圖一個物件、不畫陰影、不要文字。

### 交通工具 5 方向：motorcycle_{s,se,e,ne,n}.png、car_{s,se,e,ne,n}.png

遊戲用 5 張圖加左右鏡像，組成 8 個方向。順序與意思：s＝車頭朝畫面下方、se＝朝右下、e＝朝右、ne＝朝右上、n＝朝畫面上方（看到車尾）。在第一批的提示詞後面加一句即可，例如：

```text
Same rider-and-scooter as the reference image, same pixel-art style, scale and 50-degree overhead camera. The scooter now points straight toward the TOP of the image (we see the rear of the scooter and the rider's back). Keep proportions identical to the reference so five headings can be swapped in-game.
```

五張的車身長度與接地點要一致；用工具裁切時，車輪底部對齊同一條水平線。角度對不起來時的退路：做一個簡單的 3D 模型，離線輸出 8 張 PNG，遊戲執行時仍然用 sprite。

### 臭臭胖子：fatty_idle.png

```text
Create ONE production-ready 2D enemy sprite in detailed pixel-art style matching the reference night-market survivor style: a fictional, chubby adult man in a stained olive tank top and shorts, flip-flops, sweaty and smug, with three small cartoon green stink wavy lines rising from his shoulders. Comedic, not disgusting: no bodily fluids, no realistic grime. Crisp pixel clusters, dark outline, elevated three-quarter overhead view about 50 degrees, facing diagonally toward the lower-right, both feet visible. Square 1024 x 1024, single character centered with generous padding, true transparent background, no shadow, no text, no green cloud (the game draws the aura).
```

### 武器與掉落物：icon_{slipper,pearl,firecracker,incense,lantern,cane,gem,coin,rice,vacuum,chest}.png

每張一個物件，置中，像素風、深色輪廓，和角色同畫風。遊戲裡大約 24～40 px，輪廓要比細節重要。

| 檔名 | 內容 |
|---|---|
| icon_slipper | 一隻藍白拖鞋（白底藍帶），斜放 |
| icon_pearl | 一顆深褐色珍珠，帶一點高光 |
| icon_firecracker | 一小串紅色鞭炮，引信冒火花 |
| icon_incense | 一支點燃的香，紅色火頭與一縷白煙 |
| icon_lantern | 一盞發光的天燈，紙面米黃、底部火光 |
| icon_cane | 一支塑膠「愛的小手」（手掌造型的打手板） |
| icon_gem | 一顆藍色菱形寶石 |
| icon_coin | 一枚金幣 |
| icon_rice | 一碗滷肉飯 |
| icon_vacuum | 一台小吸塵器 |
| icon_chest | 一個紅色便當盒造型的寶箱，綁金色帶子 |

接入方式：把圖片指定給各 projectile scene 的 `Visual` 底下新增的 Sprite2D，或指定給 `pickup.tscn` 的對應 Looks 子節點，再隱藏原本的幾何佔位。
