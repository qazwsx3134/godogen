# 美術派工單：安全屋背景

使用者決定（2026-11-07）：直接生成。走完一個街區後的安全屋（選退休或繼續）專屬背景。用 Codex 內建的圖片生成（image_gen）。

## 輸入圖（已附在這次對話，依序）
1. `style_explore/s2_16bit.png`：風格。
2. `../public/sprites/node_rest.png`、3. `../public/sprites/node_clinic.png`：已完成的節點背景（色調與像素密度要接得上）。

## 要做的
`/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/safehouse.png`：1536×640、整張不透明。拉麵店樓上的隱密安全屋：鐵捲窗半拉下、牆上釘著魔都街區地圖與照片（用線連起來）、武器架與彈藥箱、三台舊螢幕亮著監視畫面、行軍床與毛毯、一扇有密碼鎖的鐵門、霓虹招牌的光從窗縫透進來。
- 畫面裡**不要有人**（主角會疊上去）。地面在 y≈600；x 450～800 的地面附近留空。
- 和 s2 同一種 16-bit 像素風、深紫＋洋紅霓虹＋少量青色；一個像素格約 4×4 畫面像素。**不要畫雨絲**。不要文字（招牌可用虛構店名）、不要原作商標。

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/SAFEHOUSE_REPORT.md`（≤5 行）：尺寸、偏差；失敗或額度不足就直說並停止。
