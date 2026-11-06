# 美術派工單：女主角 A 躺姿補右腳

使用者回報（2026-11-06）：休息畫面女主角的右腳不見了（伸直那條腿畫到褲管就沒了）。直接生成，用 Codex 內建的圖片生成（image_gen）做圖片編輯。

## 輸入圖（已附在這次對話）
- `sprites_raw/hero_a_poses.png`：女主角 A 三姿勢組，最左邊是躺姿。

## 要做的（THE ONLY CHANGE）
只改最左邊的躺姿：伸直的那條腿（往右下延伸、比較低的那條）在褲管末端補上一隻**厚底靴**，跟屈膝那條腿的靴子同款、同大小、同像素風，鞋底朝右。其他全部保持不變：角色、姿勢、顏色、像素密度、另外兩個姿勢、純綠 #00FF00 背景與整張尺寸 1536×768。

## 輸出
存成 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/hero_a_poses_fix.png`。只動這個檔案。

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/HERO_A_FIX_REPORT.md`（≤6 行）：尺寸、是否只改了腳、偏差；失敗或額度不足就直說並停止。
