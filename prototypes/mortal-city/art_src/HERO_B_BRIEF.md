# 美術派工單：男主角 B 三姿勢組

使用者決定（2026-11-06）：加一個男主角，直接生成。用 Codex 內建的圖片生成（image_gen），圖生圖。

## 輸入圖（已附在這次對話）
1. 男主角 B 的外觀：`style_explore/c1_heroes.png` 左數第二位（黑色短亂髮、黑外套洋紅滾邊、戰術背心、工裝褲、厚底靴，男性）。
2. 姿勢與版面範本：`sprites_raw/hero_a_poses.png`（女主角 A 的三姿勢組）。照它的三個姿勢、排列、大小與像素密度畫男主角 B。
3. 風格：`style_explore/s2_16bit.png`。

## 要做的
一張 1536×768 的圖，純綠 #00FF00 背景，男主角 B 三個姿勢左右分開排（彼此至少 64px 空白）：
1. 躺姿：仰躺、雙手枕在頭後、一腳屈膝、另一腳伸直。**兩隻腳都要畫完整，靴子都看得到**。不含沙發，背面直接是綠色。
2. 側面朝右跑步中段（一腳在前一腳在後）。
3. 側面朝右站立。

規則：和 s2 同一種 16-bit 像素風、清楚黑色輪廓線；一個像素格約 4×4 畫面像素（和範本一致）；角色大小和範本的女主角相同；不要陰影、不要文字、不要分隔線；不要真人、不要任何原作角色或商標。

## 輸出
存成 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/hero_b_poses.png`。只動這個檔案。

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/HERO_B_REPORT.md`（≤6 行）：尺寸、用了哪些參考圖、偏差；失敗或額度不足就直說並停止。
