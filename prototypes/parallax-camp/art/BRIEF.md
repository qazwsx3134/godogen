# 生圖派工：parallax-camp 像素美術

目標：2D 側捲夜晚森林營地原型（MapleStory 式多層 parallax）的原創像素素材。
風格：**楓之谷（MapleStory）式**——明亮飽和、圓潤可愛、Q 版大頭身角色、手繪感像素描邊、樹木有色彩層次與高光（不是黑色剪影）。原創設計，不要出現楓之谷的角色、怪物、Logo 或地圖。
參考圖 /mnt/d/repo/godot/godogen/docs/parallex/*.png 只用來看「分層結構」（sky/far/mid/near/closest 怎麼疊），不要照它的暗黑剪影畫風。
工具：用 /mnt/d/repo/agent-sprite-forge 的 skills（背景用 generate2dmap / hibit，角色用 pixel looks / generate2dsprite），挑最適合的。

## 規格
- 遊戲解析度 480x270，1x 像素、無抗鋸齒、alpha 只有 0/255，調色盤 ≤48 色/張。
- 背景層寬 960、高 270，**左右可無縫拼接**；除 sky 外背景透明。
- 色調：白天版的明亮色彩（夜晚由 Godot 的 CanvasModulate 調暗）；遠層偏藍偏淡（空氣透視），近層飽和。sky 畫白天藍天白雲，另出一張 bg_sky_night.png 星空。光暈不要畫進圖。

## 產出（放 /mnt/d/repo/godot/godogen/prototypes/parallax-camp/art/）
1. bg_sky.png — 星空漸層（不透明）
2. bg_far.png / bg_mid.png / bg_near.png / bg_closest.png — 針葉林剪影四層，由淡到深、由小到大
3. fg_occluder.png — 前景遮蔽（草叢＋樹幹），寬 480，透明
4. ground_tile.png — 32x32 可拼接泥土帶草頂
5. props/：campfire_sheet.png（6 幀橫排，32x32/幀）、tent.png、item_rack.png（看道具）、cook_pot.png（煮飯）、street_lamp.png
6. hero/：idle、walk、jump 各一張橫排 sheet，角色 Q 版約 32x48，朝右；附 frames.json（每張幀數、幀寬高）

## 驗收
- 每張 PNG 用 Python 檢查：尺寸符合、alpha 只有 0/255、背景層左右邊緣拼接無斷線。
- 做不到某項就在報告寫明，不要硬交。

## 回報
完成後寫 /mnt/d/repo/godot/godogen/prototypes/parallax-camp/art/REPORT.md：每個檔案一行（路徑、尺寸、色數、是否通過檢查），≤30 行。
