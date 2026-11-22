# 像素水族箱｜手機介面概念

三張直式概念圖使用內建 ImageGen。每張都呈現背包展開並選中一件道具的狀態。可玩版採用 B 的奶油底、暖棕框、琥珀選取狀態與像素控制元件，魚缸畫面沿用原有的 2.5D 場景。

| 方案 | 道具操作 | 畫面取捨 |
|---|---|---|
| [A．深青魚缸](a-aquascape-dock.png) | 右下角小格窗，使用／賣出排在選取格的上方 | 收合後介面最集中，缸中央與左側空間大 |
| [B．養魚手帳](b-aquarist-notebook.png) | 淺色橫列一次攤開，選中道具的正上方出現操作 | 道具最容易一眼掃完，展開時占用整排缸底 |
| [C．水玻璃側欄](c-glass-rail.png) | 右側直列展開，選中格旁顯示兩個動作 | 保留大部分缸底，手指需往上移動選道具 |

參考 [Tiny Aquarium 官方商店頁](https://store.steampowered.com/app/2581950/Tiny_Aquarium_Social_Fishkeeping/) 的背景陪伴感與 [Stardew Valley 官方畫面](https://www.stardewvalley.net/media/) 的像素介面質感。概念圖用於比較操作位置與視覺風格。遊戲內的布置與魚種依目前的 2.5D 場景實作。

## 生成提示詞

三張圖各用同一份共用描述，再加入相對應的段落。

> Use case: high-fidelity UI mockup for an original mobile idle fishkeeping game, portrait 9:19.5 vertically. Render ONE complete edge-to-edge in-game portrait screenshot filling the image, no phone hardware, no presentation board, no footer annotations, no exterior room or tank glass box, no titles, logos or watermarks. The scene fills the entire phone: a side-on, slightly elevated view into a richly layered, cozy HD pixel art planted aquarium with clear blue-green water, light entering at the top, mossy stones, original broad-leaf grasses, driftwood and substrate at the bottom. An expressive orange longtail betta is the large focal fish around the middle left and three small red-and-blue cardinal tetras swim in the middle right. One tiny food-pellet hunger icon next to the betta. A few pale translucent eggs in a shallow dish near the substrate; an egg-shaped alert at the upper right with a small "1", no breeding button. One compact top-left icon for the shop and one for the journal. A compact count "86" next to a tiny gold coin near top right. A small pair of clear zoom buttons "+", "−" at bottom left. The backpack toggle is always clearly visible at bottom right. Show the backpack open above its toggle and an item selected. Include actual original pixel art icons for egg, pellet food (with small "5"), driftwood, grass and a small lamp. The only two verbatim Chinese labels, in readable Traditional Chinese, are "使用" and "賣出" in the contextual action strip; no other words or random lettering. Use a warm amber icon for sell and an unambiguous use icon, with generous thumb-friendly touch targets. Show the UI in its real usable proportions so the background and fish dominate and the whole layout is implementable. Restrained Asian cozy indie game warmth, tactile pixel icons with readable silhouette, plenty of open peaceful water. Use original aquarium composition, original assets and visual structure, no existing game UI, characters or sprites reproduced.

**A**

> Variant A — aquascape edge dock. Deep petroleum teal compact square controls with a stepped 1px seafoam border, pale aqua icons, sand-gold selection ring. Bottom right compact floating tray with the 5 slots in a 3-column small grid, 2 rows, with a detached compact two-action horizontal strip JUST above that tray. Use distinct pixel frame and lightly translucent dark backing. Dock occupies the right 58% of width and bottom quarter, left has only zoom. Top chrome is extremely small and sparse. Use gently sunlit cyan upper water, luminous amber-orange betta. A clear impression of looking through the aquarium glass with generous unobstructed center.

**B**

> Variant B — cozy aquarist field notebook. Large pixelated honey-colored cork and cream label surfaces, restrained terracotta trim, navy pixel icons and botanical green accent, warm teatime warmth. The bag opens an inventory that rests at the bottom like a shallow, reusable aquarist's sorting box, low full-width or almost full-width rectangular card above the bottom controls, 5 thumb-sized cells in one row. Small overlaid context strip directly above the highlighted egg cell, pale amber for use, cream with terracotta coin for sell. A stitched two-pixel corner motif subtly suggests a field notebook, compact shop and journal tabs also in warm colors. Cozy handcrafted 16-bit utility with naturally familiar grid, clean and modern, keep box shallow and no explanatory text. Sheltered warm sunlight in blue-green water.

**C**

> Variant C — slim frosted glass rail. Original cool turquoise smoked glass controls with fine pale green bevels, subdued translucent dark teal backgrounds, simple geometric pixel outlines, one lavender accent on selected grass. Backpack opens into a narrow right-edge single-column rail of five large item tiles along the lower right. On selecting the grass, a tight vertical two-action popover opens just to its LEFT, aligned close to the selected tile, keeping the tank center and main betta clear. Subtle sea-green caustics show through rails. Upper HUD composed as a few separate crisp short buttons, no broad strips. Deep jewel-toned aquarium with bright mint plants and internally lit pale pebbles, calm atmosphere with contrast. Cohesive pixel-art UI and water, no glossy app aesthetic.
