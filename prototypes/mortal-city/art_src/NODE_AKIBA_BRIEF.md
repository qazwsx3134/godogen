# 美術派工單：秋葉原 6 張節點背景

使用者決定（2026-11-07）：直接生成。下一個街區秋葉原的節點橫幅背景，規格同 `NODE_BRIEF.md`。用 Codex 內建的圖片生成（image_gen）。

## 輸入圖（已附在這次對話，依序；每張都參考）
1. `style_explore/s2_16bit.png`：風格。
2. `../public/sprites/node_job.png`、3. `../public/sprites/node_wangan_job.png`：新宿與灣岸的節點背景（色調、像素密度、地面高度要接得上）。

## 共同規則
- 每張 1536×640、整張不透明；一個像素格約 4×4 畫面像素。
- 畫面裡**不要有人**（主角會疊上去）。地面在 y≈600；x 450～800 的地面附近留空。
- 秋葉原的調性：電器街、層層疊疊的直式霓虹招牌、巨大的全息偶像看板、電子零件攤、伺服器與纜線；顏色比新宿多一點青與黃。**不要畫雨絲**（地面可以有積水倒影）。招牌只用虛構店名或日文一般名詞（電器、ジャンク、ゲーム），不要真實品牌或原作商標。

## 清單（存到 /mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/）
| 檔名 | 節點 | 畫面 |
|---|---|---|
| node_akihabara_job.png | 委託 | 電玩中心後巷：一排機台的背面、散熱風扇、纜線、後門與霓虹 |
| node_akihabara_elite.png | 精英委託 | 企業資料中心入口：玻璃門後成排的伺服器藍光、紅色警報燈、無人保全機器人的剪影 |
| node_akihabara_event.png | 事件 | 電器街十字路口：巨大全息偶像看板、斑馬線、層疊霓虹招牌 |
| node_akihabara_market.png | 黑市 | 高架下的ジャンク電子零件攤：成箱的晶片、舊義眼、拆開的駭客終端、手寫價牌 |
| node_akihabara_clinic.png | 診所 | 電器行後面的地下義體改造店：機械臂工作台、零件抽屜牆、手術燈 |
| node_akihabara_rest.png | 休息 | 漫畫網咖的包廂走廊：一格格包廂、螢幕光、飲料機 |

## 完成訊號
寫 `/mnt/d/repo/godot/godogen/prototypes/mortal-city/art_src/NODE_AKIBA_REPORT.md`（≤9 行）：每張尺寸、成功／失敗；額度不足就直說並停在已完成的那幾張。
