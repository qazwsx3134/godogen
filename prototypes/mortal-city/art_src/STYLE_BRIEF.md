# 美術派工單：像素風格探索（第一步）

使用者選擇：用 Codex pane 直接生成；先從使用者的參考圖生成不同風格，讓使用者選風格與主角，之後再圖生圖做正式 sprite（2026-11-04）。

## 參考圖（請當作輸入圖做圖生圖；工具不支援輸入圖時，先看過圖再照描述生成，並在報告註明）
- 公寓：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_48-1 Large.jpeg
- 任務：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_51-2 Large.jpeg

這是東京風格的 cyberpunk 城市「魔都」。色調：深紫、洋紅霓虹、少量青色。

## 共同規則
- 全部是**像素藝術（pixel art）**，像素邊緣清楚，不要模糊或照片質感。
- 不要真人、不要 Cyberpunk 2077 原作角色與商標（Night City、NCPD、Trauma Team、Arasaka 等）。招牌可以有「新宿」「渋谷」「秋葉原」「東京」「ラーメン」這類地名與日文。
- 構圖都是橫向側視（不是等距視角）。

## 清單（檔名固定，輸出到 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/）
| 檔名 | 內容 | 尺寸 |
|---|---|---|
| s1_hd_pixel.png | 公寓參考圖的同一構圖，**細緻高解析像素**（類似 Katana ZERO、The Last Night） | 橫向約 1536×640 |
| s2_16bit.png | 同一構圖，**16-bit 復古**（SNES 時代、有限調色盤、清楚黑色輪廓線） | 同上 |
| s3_lowres.png | 同一構圖，**低解析粗像素**（看起來像 320×136 放大、大色塊、強烈霓虹） | 同上 |
| s4_hd2d.png | 同一構圖，**HD-2D**（像素角色與物件＋柔和光暈與景深，類似《八方旅人》） | 同上 |
| c1_heroes.png | 主角候選 4 人並排、全身站姿、側面朝右、純色洋紅背景 #FF00FF、像素風（用 s1 的風格）：A 照參考圖（黑髮馬尾、洋紅挑染、黑外套洋紅滾邊、「特務」臂章、工裝褲、厚底靴）；B 同服裝的男性版；C 銀色短髮＋一隻機械手臂；D 兜帽＋發光面罩。每人下方留空白，不要文字 | 橫向約 1536×768 |

原始大圖若和輸出不同，放 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/raw/。只動這兩個資料夾。

## 完成訊號
全部完成或中途停止時，寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/STYLE_REPORT.md：每張檔名、尺寸、成功／失敗、是否有用參考圖做輸入、失敗原因（額度不足就直說並停止，不要用別的方式湊圖）。≤10 行。
