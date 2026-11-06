# 美術派工單：男主角 B 跑步循環

接在 `HERO_B_BRIEF.md` 之後。用 Codex 內建的圖片生成（image_gen），圖生圖。

## 輸入圖（已附在這次對話）
1. 男主角 B 三姿勢組：`sprites_raw/raw/hero_b_poses.png`（中間的跑步姿勢）。
2. 循環範本：`../public/sprites/hero_run_strip.png`（女主角 A 的 8 格跑步循環，照它的節奏與格子排法）。
3. 風格：`style_explore/s2_16bit.png`。

## 要做的
一張 **8 格跑步循環** sprite sheet，同一個男主角 B，側面朝右：
- 8 格一橫排、每格同寬同高（例如整張 2048×384，每格 256×384），角色在每格水平置中，**腳底都踩在同一條水平線**，大小完全一致。
- 循環順序：右腳著地 → 下沉 → 交叉 → 騰空 → 左腳著地 → 下沉 → 交叉 → 騰空，第 8 格要接得回第 1 格。外套下擺隨步伐擺動。
- 背景純綠 #00FF00，不要分隔線、陰影、文字。16-bit 像素風、清楚黑色輪廓線。

## 輸出
存成 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/hero_b_run_cycle.png`。只動這個檔案。

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/HERO_B_RUN_REPORT.md`（≤6 行）：尺寸、格數、偏差；失敗或額度不足就直說並停止。
