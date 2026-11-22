# 派工：風格選項（使用者否決了目前的 art/*.png，覺得太醜）

不要再修改現有 art/*.png。這次只做「風格選項」，讓使用者選一個，選定後才做整套圖。

## 參考
- /mnt/d/repo/godot/godogen/prototypes/erwin-run/assets/（bg/sky, far, mid, ground, ruins；sprites/）：使用者喜歡這個專案的素材。看它的畫風、色調、描邊與細節密度，以及 art_src/BRIEF-gen-1.md、GEN-REPORT-1.md、prompts/ 是怎麼生成的，照它的生成路線做。
- 遊戲目標：楓之谷式多層 parallax 橫向場景（sky/far/mid/near/closest/前景遮蔽），森林、夜晚星空、營地（營火、看道具處、煮飯處、路燈）。
- erwin-run 的背景（sky/far/mid/ground）**可以直接重用**（複製進 parallax-camp，不要搬動原檔），不夠的層再補生成。不要用進擊的巨人角色。

## 產出
至少 3 個選項，放 style-options/<代號>/：
- preview.png：480x270 一張合成示意（天空＋至少 3 層森林＋地面＋營火＋主角站姿），同一個構圖讓使用者好比較。
- preview_night.png：同構圖的夜晚版（可用調暗＋星空示意）。
- NOTES.md：3 行內說明這個風格的特徵、主角大小、用了哪些 erwin-run 素材。
其中**選項 A 必須直接重用 erwin-run 背景**，補上配套的營地物件與主角；B、C（以上）是不同方向（例如更 Q 版明亮的楓之谷感、更有氣氛的手繪像素等），由你提案。

## 回報
寫 style-options/REPORT.md：每個選項一行（代號、一句話特色、預覽路徑）。≤10 行。做不到直說。
