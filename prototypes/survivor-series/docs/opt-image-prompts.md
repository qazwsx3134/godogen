# opt image：第一批五份素材提示詞

生成方式已確認：由使用者把下列提示詞貼入 opt image 生成，代理不直接生成圖片。

畫風提案：誇張漫畫、粗輪廓、清楚色塊、帶街頭喜劇感。所有圖片共用同一個 2D 斜俯視、近似正交的觀看角度；角色表情可讀，但不採側視或立體等角菱形格。以下主角外觀與配色是首批提案，可自由替換；替換時保持輪廓與主角／敵人的辨識差異。

## 交接清單

| 檔名 | 建議生成畫布 | 背景 | 用途 |
|---|---|---|---|
| `hero_idle.png` | 1024×1024 | 透明 | 主角待機／移動／拳擊動畫的基礎圖 |
| `smoker_idle.png` | 1024×1024 | 透明 | 抽菸者 |
| `motorcycle_idle.png` | 1024×1024 | 透明 | 騎士與機車一起呈現 |
| `car_idle.png` | 1024×1024 | 透明 | 汽車與可辨認的駕駛 |
| `street_block.png` | 1200×1680，5:7 | 不透明 | 封閉街區背景（2026-10-07 起街區放大，鏡頭跟著主角） |

工具不支援精確尺寸時，選角色 1:1、背景 5:7（或 3:4 再裁切）；原圖保留，匯入前再縮放。每份提示詞生成一張獨立圖，不做五張拼圖。後續生成時能附參考圖就附已選定的主角圖，保持同一套線條、色彩與視角。

角色與車輛使用單一靜態姿勢，不生成動畫表。背景不包含主角、敵人、煙霧、預警線或 UI；煙霧與打擊效果由遊戲獨立疊加。角色圖不畫地面陰影，避免揍飛時把陰影一起帶上天。

## 1. 行人主角 — hero_idle.png

```text
Create ONE production-ready 2D game character sprite for a portrait mobile street-survivor game. A fictional adult pedestrian hero with short dark hair, a teal casual jacket, cream T-shirt, dark navy trousers, and orange sneakers. Friendly but determined, exaggerated expressive eyebrows, oversized readable fists, compact athletic proportions, street-comedy attitude.

Style: original bold comic-book game art, thick clean dark outlines, simple cel shading, strong silhouette, crisp flat colors, readable at a small gameplay size. Elevated three-quarter overhead view, approximately 55 degrees above the ground, nearly orthographic projection. The face and upper body remain visible. Full body facing diagonally toward the lower-right, fists raised in a relaxed ready-to-punch pose, both feet clearly visible.

Square 1024 x 1024 canvas. Exactly one character centered, generous clear padding around every limb, no cropped hands or feet. True transparent PNG background. No ground plane, no cast shadow, no background, no text, no UI, no weapon, no smoke, no impact effect, no duplicate poses, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 2. 抽菸者 — smoker_idle.png

```text
Create ONE production-ready 2D enemy sprite matching an original bold comic-book street-survivor game. A fictional adult smoker pedestrian wearing a dusty purple jacket, faded mustard shirt, dark trousers, and gray shoes. Slouched shoulders, smug annoyed expression, one hand holding a clearly visible cigarette away from the torso. Exaggerated readable eyebrows and hands; instantly distinguishable from the teal-jacket pedestrian hero.

Thick clean dark outlines, simple cel shading, crisp flat colors, compact proportions, strong silhouette, street-comedy tone. Match the hero's elevated three-quarter overhead view, approximately 55 degrees above the ground, nearly orthographic projection. Full body faces diagonally toward the lower-right. Both feet visible. A static idle pose. The cigarette is present, but there is NO rendered smoke; gameplay creates the smoke hazard separately.

Square 1024 x 1024 canvas. Exactly one character centered with generous padding. True transparent PNG background. No ground plane, no cast shadow, no background, no text, no UI, no impact effect, no duplicate poses, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 3. 機車與騎士 — motorcycle_idle.png

```text
Create ONE production-ready 2D enemy sprite: a fictional adult rider seated on a compact red-orange urban motor scooter. Rider wears a white helmet, dark jacket, and dark trousers, with an impatient comic expression visible through an open visor. The rider and the entire scooter form ONE connected sprite, including both wheels, handlebars, mirrors, and the whole rider. Clear recognizable scooter silhouette, exaggerated proportions, no real manufacturer branding.

Original bold comic-book game art matching the pedestrian characters: thick clean dark outlines, simple cel shading, crisp flat colors, strong small-size readability. Elevated three-quarter overhead view, approximately 55 degrees above the ground, nearly orthographic projection. Scooter points diagonally toward the lower-right. Stationary pose, rider holds handlebars, both wheels clearly visible. Do not use a side profile or a low-angle camera.

Square 1024 x 1024 canvas. Exactly one rider-and-scooter unit centered with generous padding; no cropped wheels or helmet. True transparent PNG background. No ground plane, no cast shadow, no road, no exhaust, no motion trails, no warning arrows, no text, no UI, no duplicate poses, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 4. 汽車與駕駛 — car_idle.png

```text
Create ONE production-ready 2D enemy sprite: a chunky mustard-yellow compact city car with an annoyed fictional adult driver clearly visible behind a light windshield. Exaggerated heavy bumper, large readable wheels, rounded sturdy body. The car should feel substantially heavier than a motor scooter. Driver remains inside the car; car and driver are ONE sprite. No real brand logos, no readable license-plate text.

Original bold comic-book game art matching pedestrian and scooter sprites: thick clean dark outlines, simple cel shading, crisp flat colors, humorous proportions, strong small-size readability. Elevated three-quarter overhead view, approximately 55 degrees above the ground, nearly orthographic projection. The entire car points diagonally toward the lower-right; roof, windshield, front bumper, and visible side wheels are readable. Do not use a side profile, realistic photography, or a low-angle camera.

Square 1024 x 1024 canvas. Exactly one complete vehicle centered with generous transparent padding, no cropped bumper or wheels. True transparent PNG background. No ground plane, no cast shadow, no road, no exhaust, no speed lines, no impact effects, no text, no UI, no duplicate angles, no sprite sheet, no watermark, no checkerboard drawn into the image.
```

## 5. 封閉街區 — street_block.png

街區放大後，背景是一整塊比畫面大的地圖，鏡頭會在上面移動。遊戲裡的尺寸是 1200×1680；中間有一條橫向的十字路口（y≈840）。

```text
Create ONE portrait 5:7 top-down-ish map background for a 2D mobile street-survivor game, ideally 1200 x 1680 pixels (larger is fine if the ratio stays 5:7). It is a scrolling arena larger than the phone screen. A fictional contemporary Taiwan-inspired neighborhood street block with ONE horizontal cross street through the middle, seen from an elevated three-quarter overhead view, approximately 55 degrees above the ground, nearly orthographic. Match bold comic-book game sprites: clean dark outlines, simple cel shading, crisp shapes, muted asphalt and warm concrete colors. The ground must feel like a flat playable rectangle, not a tilted isometric diamond or a perspective road vanishing into the distance.

Design a large continuous open asphalt play area filling almost the whole image, with a thin sidewalk border of about 3 percent on every side. Surround it with low curbs and shallow sidewalks that communicate an enclosed street block. A few low storefront edges, planters, bollards, and utility details may appear ONLY around the perimeter. Upper facades must be shallow so they cannot hide gameplay. Add subtle worn road markings, a small pedestrian crossing near one edge, and a few surface cracks. Keep the center quiet, low contrast, spacious, and free of obstacles, so smoke zones, warning lanes, pedestrians, scooters, and cars will read clearly when added by the game.

One complete opaque background image. No characters, no pedestrians, no moving or parked vehicles, no smoke, no fire, no attack effects, no warning lines, no arrows, no UI, no title, no text, no readable signs, no watermark. Do not draw a joystick or HUD. Spread small low details (manholes, parking lines, crosswalks at the intersection) evenly so movement reads when the camera scrolls. No cinematic lighting, no strong depth of field, no photorealism.
```

## 到圖後的接入

將五張原圖放在 `assets/source/`，保留上述檔名。原圖與遊戲縮圖分開保存；素材規格未通過前不自動覆寫既有貼圖。接入時另做人物腳底／車輪接地點、透明留白、執行尺寸與碰撞區設定，保留 scene 可編輯。

圖像檢查：角色是否單一且完整、透明底是否真的有 alpha、五張是否同視角與畫風、機車汽車是否連同人一起、背景中央是否留空。若透明底輸出成實心底或棋盤格，先重新輸出真正透明 PNG；不要把棋盤當成可直接用的素材。

第一批圖片不包含拳擊動作逐格圖、背向角色或不同車向；現階段以移動、翻轉與 scene 動畫驗證玩法。若試玩需要更多方向與逐格動作，再依已選定的參考圖建立第二批提示詞。

## 第二批（2026-10-07 割草版）

第一批選定的主角圖要當參考圖附上，保持線條、配色與 55 度視角一致。共同規格：1024×1024、真透明 PNG、一張圖一個物件、不畫陰影、不要文字。

### 交通工具 5 方向：motorcycle_{s,se,e,ne,n}.png、car_{s,se,e,ne,n}.png

遊戲用 5 張圖加左右鏡像，組成 8 個方向。順序與意思：s＝車頭朝畫面下方、se＝朝右下、e＝朝右、ne＝朝右上、n＝朝畫面上方（看到車尾）。在第一批的提示詞後面加一句即可，例如：

```text
Same rider-and-scooter as the reference image, same style, scale and 55-degree overhead camera. The scooter now points straight toward the TOP of the image (we see the rear of the scooter and the rider's back). Keep proportions identical to the reference so five headings can be swapped in-game.
```

五張的車身長度與接地點要一致；用工具裁切時，車輪底部對齊同一條水平線。角度對不起來時的退路：做一個簡單的 3D 模型，離線輸出 8 張 PNG，遊戲執行時仍然用 sprite。

### 臭臭胖子：fatty_idle.png

```text
Create ONE production-ready 2D enemy sprite matching the reference street-survivor style: a fictional, chubby adult man in a stained olive tank top and shorts, flip-flops, sweaty and smug, with three small cartoon green stink wavy lines rising from his shoulders. Comedic, not disgusting: no bodily fluids, no realistic grime. Thick clean outlines, simple cel shading, elevated three-quarter overhead view about 55 degrees, facing diagonally toward the lower-right, both feet visible. Square 1024 x 1024, single character centered with generous padding, true transparent background, no shadow, no text, no green cloud (the game draws the aura).
```

### 武器與掉落物：icon_{slipper,pearl,firecracker,incense,lantern,cane,gem,coin,rice,vacuum,chest}.png

每張一個物件，置中，粗輪廓，和角色同畫風。遊戲裡大約 24～40 px，輪廓要比細節重要。

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
