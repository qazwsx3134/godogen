# 美術派工單：主角 A 跑步循環（第三步）

使用者確認（2026-11-05）：請 Codex 用主角 A 圖生圖、綠色底，做法和正式 sprite 一樣。

## 輸入圖（當參考圖輸入）
- 主角 A 跑步姿勢（已核准的那張）：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/hero_a_poses.png （中間那個跑步姿勢）
- 風格：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/s2_16bit.png

## 要做的
一張 **8 格跑步循環** sprite sheet：
- 側面朝右、同一個角色 A（黑髮馬尾洋紅挑染、黑外套洋紅滾邊、「特務」臂章、工裝褲、厚底靴），S2 16-bit 像素風、清楚黑色輪廓線。
- 8 格**一橫排、每格同寬同高**（例如整張 2048×384，每格 256×384），角色在每格水平置中，**腳底都踩在同一條水平線**，大小完全一致。
- 循環順序：右腳著地 → 下沉 → 交叉 → 騰空 → 左腳著地 → 下沉 → 交叉 → 騰空，第 8 格要能接回第 1 格。馬尾和外套下擺隨步伐擺動。
- 背景純綠 #00FF00，格子之間不要畫分隔線、不要陰影、不要文字。

## 輸出
- /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/hero_run_cycle.png
- 只動這個檔案。

## 完成訊號
完成或停止時寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/RUN_REPORT.md：尺寸、格數、是否用了參考圖、失敗原因（額度不足就直說並停止）。≤6 行。不用做縮放或去背，後製由主 session 處理。
