# 美術派工單：男女主角的節點站姿（跟新休息圖一致）

使用者決定（2026-11-07）：直接生成。節點畫面主角站在場景中間，現在的站姿是舊版，要跟新的休息圖（更 cyberpunk）一致。用 Codex 內建的圖片生成（image_gen），圖生圖。

## 輸入圖（已附在這次對話，依序）
1. `sprites_raw/sofa_rest_a.png`：女主角 A 的新造型（青光神經插槽、額頭洋紅護目鏡、義體手臂、外套洋紅 LED 滾邊）。
2. `sprites_raw/sofa_rest_b.png`：男主角 B 的新造型（同樣的插槽、護目鏡、LED 滾邊）。
3. `sprites_raw/hero_a_poses_fix.png`：舊三姿勢組，最右邊是站姿（照它的站姿角度：側面朝右、自然站立）。
4. `style_explore/s2_16bit.png`：風格。

## 要做的（兩張，各一個人）
- `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/stand_a.png`：女主角 A 全身站姿，側面朝右，造型照圖 1。
- `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/stand_b.png`：男主角 B 全身站姿，側面朝右，造型照圖 2。
- 每張 1536×768、純綠 #00FF00 背景，人物置中、全身完整（頭到靴底），身高約 600px；頭身比自然成人。
- 16-bit 像素風、清楚黑色輪廓線，一個像素格約 4×4 畫面像素；發光細節小而清楚。不要陰影、文字、其他物件；不要真人或原作角色。

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/STAND_REPORT.md`（≤6 行）：每張尺寸、偏差；失敗或額度不足就直說並停止。只動上面兩個檔案與報告。
