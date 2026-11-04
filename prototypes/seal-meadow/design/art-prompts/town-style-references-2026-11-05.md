# 蓬蓬村風格參考圖

2026-11-05。使用者選擇直接生成兩張比較圖，並選定 **A 暖陶瓦**作為後續城鎮的美術方向。圖是設計參考，並非遊戲中已實作的場景；第一間商店仍是低面數可玩樣板。

- [A：暖陶瓦（選定）](../../art_src/concepts/town-style-terracotta-20261105.png)
- [B：青綠屋頂](../../art_src/concepts/town-style-teal-20261105.png)：以 A 為輸入編輯，便於比較同一構圖。
- [商店正／側／背三視圖](../../art_src/concepts/town-shop-turnaround-20261105.png)
- [陶瓦／木材／灰泥材質參考](../../art_src/concepts/town-material-study-20261105.png)

方向要點：柔暖陶瓦、奶油色灰泥、木樑、圓潤適度倒角、開闊廣場、花草與木柵欄；模型與材質要在手機尺寸保持易讀。沿用原創 Q 版比例，避免複製既有遊戲角色及場所。三視圖是造型提案，前側背的屋頂與附屬物需要人工統一尺寸，不能當作精確藍圖。材質圖是外觀參考，不是已驗證無縫的實際貼圖或烘焙法線圖。遊戲目前的色彩、光照與商店幾何尚未達到參考圖的完成度；[正式製作規格](../pipeline/town-shop-production-spec.md)。

## 實際提示詞

### A：文字生成

```text
Use case: stylized-concept. Asset type: a single landscape 16:9 visual-direction reference for the original mobile RPG Seal Meadow, not an in-game asset or UI. Create a warm, nostalgic, cheerful chibi fantasy village that feels practical to build as low-polygon 3D. Match a fixed third-person game camera looking down about 42 degrees with a moderate 40-degree field of view. Compose a small open round stone plaza in the centre, a single welcoming village general store at the far side, an easy-to-read path leading from the near foreground into the plaza, one understated signpost, a few trees, flowers and short wooden fences. A small 2D-looking chibi adventurer and one village elder provide clear scale without obscuring the building. Use an original rounded storybook silhouette, modest bevels and clearly defined door and roof; creamy plaster walls, warm wooden beams and subdued terracotta roof tiles with tasteful hand-painted material detail. Green meadow surrounds the town. Soft natural daytime lighting, gentle readable shadows, restrained saturation, crisp forms readable on a phone. The central route must stay open and the image should look like a representative game view rather than an overhead map. One continuous coherent landscape image. No UI, text, logos, watermarks, panel divisions, orthographic turnarounds, photorealism, heavy depth of field, or recognizable characters and locations from existing games.
```

### B：以 A 編輯

```text
Edit this provided original landscape concept image to create the second candidate in a controlled A/B visual comparison for the original chibi fantasy mobile RPG Seal Meadow. Preserve the composition exactly: same camera angle, framing, shop architecture and proportions, placement of the hero, village elder, plaza, sign, trees, fence, foreground buildings, background and lighting. Preserve the same painterly, softly textured low-poly-friendly art direction and all original material details. Change the terracotta roof tiles on the shop and foreground buildings into a harmonious muted teal / sea-green roof color, while retaining believable tile shading and highlights; adjust only the small warm coral fabric stripes if necessary into matching subdued blue-green. Keep the cream plaster, natural brown timber, meadow, stone path, characters and daylight unchanged. One coherent 16:9 landscape image, with no text, logos, watermarks or added elements.
```

### 商店三視圖：附 A 參考圖

```text
Use case: production-model-reference. Make a single landscape concept sheet for constructing an ORIGINAL low-poly 3D village general store for the chibi mobile RPG Seal Meadow. Use the attached approved warm terracotta town image ONLY as the visual and architectural design reference for the central shop: cozy cream plaster, natural dark wooden beams, a welcoming central wooden door, visible windows and a warm terracotta tiled roof, modest soft bevels, hand-painted storybook fantasy styling. Present the SAME one compact building as exactly three full-building orthographic views, in three evenly spaced columns: FRONT, RIGHT SIDE, and BACK, all with precisely the same scale and floor line, each facing directly toward its respective side, no perspective or isometric angle. Keep roof profile, roof overhang, eaves, ridge, wall height, widths, windows, chimney, material colors and decorative elements logically consistent between the three views; side and rear should follow from the front rather than inventing different buildings. Show complete silhouette including chimney and foundations with ample space around each view. Centered building only against a plain warm-white background with very subtle ground contact shadow. Readable low-poly construction, broad shapes, modest ornament; suitable for a single ordinary building below 4,000 triangles once built. This is a modeling design guide, not final game art. No environment, no people, no sky, no shadows between views, no lettering, no dimension arrows, no logos, no watermarks, no fourth view.
```

### 三種材質參考：附 A 參考圖

```text
Use case: game-material-style-reference. Create ONE clean landscape material study for an ORIGINAL cozy chibi fantasy village in the mobile RPG Seal Meadow, using the attached approved village image as the style reference. Arrange EXACTLY THREE equally sized large square swatches side by side on a plain warm ivory background, with ample margin and no perspective: (1) warm muted terracotta ceramic roof tiles with broad simplified overlapping tile shapes and subtle hand-painted grain; (2) warm medium brown weathered timber planks with restrained hand-painted wood grain and chiseled bevels; (3) creamy warm off-white plaster with a very subtle varied stone-and-lime surface. Each swatch must be a straight-on orthographic view with consistent scale, lighting and a restrained natural color palette; broad shapes need to remain readable at phone size. The swatches are material look references for later UV mapping, not actual baked texture or normal maps; do not pretend they are physically correct normal maps. Cohesive nostalgic storybook look, painterly but practical for low-poly 3D. No isolated objects, characters, text, labels, logos, interface, watermarks or extra swatches.
```
