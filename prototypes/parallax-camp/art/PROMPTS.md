# 生圖提示與來源

所有原始圖由 Codex 內建 `image_gen` 直接生成（host image 路徑）。工具沒有回報具體模型名稱或費用估算，故不臆測。原始輸入 PNG 與處理後的角色像素母版封存在 `source-art.zip`。最終素材以 nearest-neighbour 縮放、二值 alpha、每張最多 48 色處理；背景與地面接縫以邊緣像素配對修整。角色母版使用 `generate2dsprite/pixel_look.py`，角色與火堆 sheet 使用 `plan_guide.py` 版面參考。

## 背景

### bg_sky.png

```text
Use case: game-background. Asset type: panoramic parallax sky layer for a 2D side-scrolling camp game. Primary request: original bright daytime sky in crisp 1x pixel art for a 960x270 game layer, ultra-wide seamless horizontal tile, ratio 32:9. Scene: clear blue sky with soft rounded white clouds spaced in small groups, a gentle top-to-bottom sky gradient from deeper blue to pale turquoise near the horizon, a few tiny white twinkles only as subtle texture. Style: cheerful polished 16-bit fantasy pixel art, rounded shapes, tidy hand-placed square pixels, restrained dark-blue pixel outlines only where useful, no blur or antialiasing. Composition: empty open sky, clouds continue naturally across both edges and match at the left/right seam; no ground, mountains, trees, buildings, sun disc, characters, foreground objects, text, frame or watermark. Opaque full canvas, no glow, no dramatic lighting. Designed to be reduced to a 960x270 PNG and palette-quantized.
```

### bg_sky_night.png

```text
Use case: game-background. Asset type: optional night sky variant for a 2D side-scrolling fantasy camp. Input images: Image 1 is only a pixel-treatment reference for chunky clean square pixels and cheerful polish; do not reuse its clouds or composition. Primary request: an original ultra-wide seamless horizontal tile, ratio 3:1, showing a rich twilight-to-night sky with a deep cobalt and violet gradient, tiny sparse gold and pale aqua stars, and one small friendly crescent moon near the upper right. Style: polished 16-bit hand-placed pixel art, bright jewel colors, square 1x-looking pixels, no blur or anti-aliasing. Composition: pure open sky, no land, hills, trees, buildings, characters, foreground, border, text or watermark; clouds not required; the left and right edge patterns must match cleanly. Opaque canvas, no glow or bloom, intended to crop and reduce to 960x270.
```

### bg_far.png

```text
Use case: game-background. Asset type: far parallax forest layer for a 2D side-scrolling camp game. Input images: Image 1 is only a pixel-treatment reference for square pixel clusters and cheerful polish; do not reuse its cloud subject or layout. Primary request: one original ultra-wide seamless conifer forest layer, ratio 3:1, with widely spaced small fir trees, low distant ridges and gentle rounded treetops. Palette: pale blue-green, powder teal and soft periwinkle with subtle lighter foliage facets; airy and low-contrast, clearly the farthest forest depth. Composition: full-width 2D side-view layer, tree trunks and foliage fully inside canvas, bottom tree trunks meet the lower edge, varying canopy heights but open transparent gaps between groups; left/right edges join without a visible break. Transparent background, no sky, ground slab, text, frame or watermark. Polished 16-bit pixel art, square chunky pixels, crisp edges, no blur or anti-aliasing, no dramatic shadows or glow.
```

### bg_mid.png

```text
Use case: game-background. Asset type: middle parallax forest layer for a 2D side-scrolling camp game. Input images: Image 1 is only a pixel-treatment reference for square pixel clusters and cheerful polish; do not reuse its cloud subject or layout. Primary request: one original ultra-wide seamless conifer forest layer, ratio 3:1, with medium-height fir trees and overlapping rounded branch tiers. Palette: clear teal, blue-green and fresh leaf green, more saturated and darker than a far forest, with small mint highlights and hand-painted pixel outlines. Composition: full-width 2D side view, irregular overlapping tree crowns, a few slim visible trunks running to the lower edge, transparent openings between trunks; no horizon slab. Ensure left/right edge forms meet perfectly when tiled. Transparent background, no sky, hills, props, text, frame or watermark. Polished 16-bit pixel art, square chunky pixels, crisp edges, no blur or anti-aliasing, no glow.
```

### bg_near.png

```text
Use case: game-background. Asset type: near parallax forest layer for an original cheerful 2D side-scrolling fantasy camp. Input images: Image 1 is only a palette and pixel-treatment guide for clear square pixels; Image 2 is only a forest motif/style guide. Do not duplicate either composition. Primary request: ultra-wide seamless 3:1 canvas of closer, taller evergreen trees, full side view, layered rounded fir boughs with crisp pixel outlines, rich emerald, jade and blue-green foliage, bright mint leaf facets, warm chestnut trunks, noticeably more saturated and detailed than the distant woods. Keep a few transparent gaps between tree clusters; trunks meet the lower canvas edge. Match the left and right edges for seamless horizontal tiling. Transparent background, no sky, ground slab, camp props, text, frame or watermark. Polished cute 16-bit pixel art, no blur, no anti-aliasing, no glow.
```

### bg_closest.png

```text
Use case: game-background. Asset type: closest parallax forest layer for an original cheerful 2D side-scrolling fantasy camp. Input images: Image 1 is only a palette and pixel-treatment guide; Image 2 is only a forest motif/style guide. Do not duplicate either composition. Primary request: ultra-wide seamless 3:1 foreground woodland layer, huge rounded evergreen boughs and a few thick brown trunks framing the outer left and right, with a wide open gap through the center for a campsite; dense colorful bushes and fern tips along the bottom edge. Palette: deepest teal-green and forest green with crisp turquoise, lime and warm leaf highlights, hand-placed pixel outlines. Forms are closest and largest. Transparent background with open gaps, no sky, no solid ground, no props, people, text, frame or watermark. Ensure the far left and right edges tile smoothly. Polished cute 16-bit pixel art, no blur, no anti-aliasing, no glow.
```

### fg_occluder.png

```text
Use case: game-foreground. Asset type: 480x270 transparent occluder overlay for an original cheerful 2D side-scrolling camp. Input images: Image 1 is a pixel-treatment reference only; Image 2 is a forest-shape reference only. Primary request: a sparse foreground framing overlay with one wide warm-brown conifer trunk cropped by the left edge, a shorter trunk section near the right edge, and cute thick grass, ferns, tiny flowers and rounded shrubs along only the bottom corners. Leave the center 60 percent mostly transparent so a character and campfire remain visible. Bright saturated emerald and mint foliage with readable pixel outlines. Transparent background, no sky, no backdrop, no text, frame or watermark. Crisp chunky 16-bit pixel art, no glow, blur or anti-aliasing.
```

## 地面與道具

### ground_tile.png

```text
Use case: game-asset. Asset type: 32x32 repeatable side-view platform tile for an original cute 2D fantasy camp. Input image: Image 1 is only a pixel-style reference. Primary request: a seamless square tile with a bright spring-green grass cap across the top 8 pixels, tiny leafy tufts, and rich warm ochre-brown soil beneath with a few small pebble pixels. Both left and right edges must match exactly for horizontal repetition; top edge stays grass, bottom edge soil. Crisp 16-bit pixel art with square pixels and a dark warm outline; no blur, anti-aliasing, shadow, text, frame, or watermark. Transparent background above or outside the tile is not needed; fill the 32x32 tile.
```

### props/campfire_sheet.png

```text
Use case: game-asset. Asset type: six-frame campfire animation sheet for a 2D fantasy camp. Input images: Image 1 is only a pixel-treatment reference; Image 2 is a layout guide, follow its six equal cells and do not reproduce any guide lines, labels or colors. Primary request: six distinct sequential flicker poses of the same compact friendly campfire, two short brown logs crossed on a small ring of gray stones with a golden-orange flame that changes silhouette frame to frame. Each cell contains one complete fire centered on transparency with generous clear margin. Style: crisp polished 16-bit pixel art, warm bright colors, small dark outlines; no large glow, no smoke covering adjacent cells, no background, text or watermark. The final runtime sheet will be arranged as six 32x32 frames in one horizontal row.
```

### props/tent.png

```text
Use case: game-asset. Asset type: isolated transparent prop sprite for a cute 2D fantasy camp. Input image: Image 1 is only a pixel-treatment reference. Primary request: a small cozy mustard-yellow and leaf-green canvas tent viewed from the side at slight three-quarter angle, open front flap, rolled teal bedroll beside it, one tiny pennant, clear chunky silhouette. Bright cheerful colors, hand-placed square 16-bit pixels and tasteful dark outlines. Centered with margin on a fully transparent background, no cast shadow, ground plane, other objects, text, logo or watermark; no blur or anti-aliasing.
```

### props/item_rack.png

```text
Use case: game-asset. Asset type: isolated transparent item rack prop for a cute 2D fantasy camp. Input image: Image 1 is only a pixel-treatment reference. Primary request: a compact chestnut wooden two-shelf gear rack with a coil of rope, rolled blanket, small backpack and two colorful potion bottles arranged neatly; original fantasy camping items, readable silhouettes. Bright warm brown wood with mint, coral and gold accents, polished 16-bit pixels, crisp dark outlines. Front three-quarter view, centered with margin, fully transparent background, no floor or cast shadow, no people, text, logo or watermark, no blur or anti-aliasing.
```

### props/cook_pot.png

```text
Use case: game-asset. Asset type: isolated transparent cooking pot prop for a cute 2D fantasy camp. Input image: Image 1 is only a pixel-treatment reference. Primary request: a squat dark-bronze round cooking pot with two tiny side handles, a visible bright stew surface and one mint-green herb leaf, resting on a simple small wooden tripod. Friendly readable silhouette, polished colorful 16-bit pixel art with tidy dark outline. Centered with margin, transparent background, no smoke or glow, floor plane, other objects, text or watermark, no blur or anti-aliasing.
```

### props/street_lamp.png

```text
Use case: game-asset. Asset type: isolated transparent street lamp prop for a cute 2D fantasy camp. Input image: Image 1 is only a pixel-treatment reference. Primary request: a whimsical chestnut wooden post lamp with a small golden glass lantern, simple carved cap and little teal ribbon, tall narrow side-view silhouette. Bright warm accents with a dark outline, polished 16-bit square pixel clusters. Centered with margin on fully transparent background, no visible glow or bloom, floor, characters, text, logo or watermark, no blur or anti-aliasing.
```

## 角色

### hero master（原始母版；處理後像素母版用於鎖定角色）

```text
Use case: game-character. Asset type: master reference for a 32x48 pixel-game hero, viewed at native sprite scale. Input image: Image 1 is only a pixel-treatment reference for crisp square pixels and bright colors; do not reuse its clouds or composition. Primary request: one original cute chibi adventurer, about 1.5 heads tall, full body visible, facing right in a clear three-quarter side view. Short indigo-blue hair, large amber eye, mint-green tunic, coral scarf, tan shorts, little brown boots and a small orange backpack; empty hands, no weapon. Warm friendly face, strong readable outline, handful of clear color groups; original fantasy design with no borrowed game characters, monsters or logos. Centered, fully visible, on a perfectly flat solid magenta #FF00FF background with no shadow, ground, prop, vignette, texture, text or watermark. Crisp pixel-like square clusters, no blur or anti-aliasing.
```

### hero/idle.png

```text
Use case: game-character. Asset type: four-frame idle sprite sheet for the same original 2D platform hero. Input images: Image 1 is the exact character identity and pixel-grid reference: preserve the indigo hair, amber eye, coral scarf, mint tunic, tan shorts, orange backpack, brown boots, outline, proportions and facing; Image 2 is only an equal-cell layout guide, do not copy its lines, labels or colors. Primary request: four readable idle keyframes of that same full-body chibi adventurer facing right, in order: relaxed stand, gentle inhale, gentle exhale, one blink returning to the first pose. Body stays grounded, feet align on the same baseline and the silhouette remains fully inside each cell. Use 2 rows by 2 columns, row-major order, clear margin around every pose. Transparent background, no floor, extra items, text or watermark. Crisp 1x-looking hand-placed 16-bit pixels, bright cute colors, binary hard edges, no blur, anti-aliasing or glow.
```

### hero/walk.png

```text
Use case: game-character. Asset type: six-frame looping walk sprite sheet for the same original 2D platform hero. Input images: Image 1 is the exact character identity and pixel-grid reference: preserve the indigo hair, amber eye, coral scarf, mint tunic, tan shorts, orange backpack, brown boots, outline, proportions and facing; Image 2 is only an equal-cell layout and alternating-leg guide, do not copy its lines, labels or colors. Primary request: six sequential walk poses of the same full-body chibi adventurer moving toward the right, alternating near and far legs and arms, feet making clear contact on a shared ground line; scarf and backpack bounce slightly. First and last poses form a natural loop. Use 2 rows by 3 columns, row-major order, one complete pose per cell with clear margin. Transparent background, no floor, text, props or watermark. Crisp bright 16-bit square pixels, solid dark outline, exact identity across frames, no blur, anti-aliasing or glow.
```

### hero/jump.png

```text
Use case: game-character. Asset type: four-frame one-shot jump sprite sheet for the same original 2D platform hero. Input images: Image 1 is the exact character identity and pixel-grid reference: preserve the indigo hair, amber eye, coral scarf, mint tunic, tan shorts, orange backpack, brown boots, outline, proportions and right-facing profile; Image 2 is only an equal-cell layout guide, do not copy its lines, labels or colors. Primary request: four jump key poses of the same full-body chibi adventurer in order: slight crouch and anticipation, clear rising pose, compact apex pose, descending landing-ready pose. The feet may rise within each cell; keep consistent body size and silhouette. Use 2 rows by 2 columns, row-major order, clear margin around each pose. Transparent background, no floor, text, props or watermark. Crisp bright 16-bit square pixels, dark outline, exact same identity, no blur, anti-aliasing or glow.
```
