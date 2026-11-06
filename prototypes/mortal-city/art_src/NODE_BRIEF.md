# 美術派工單：6 張節點場景背景（第三步）

使用者確認（2026-11-06）：用 Codex 直接生成。沿用已選定的 **S2 16-bit** 風格。這 6 張是 mortal-city 地圖節點畫面上方橫幅的**整張背景**，主角 A 的站立 sprite 會另外疊上去，所以畫面裡**不要有任何人**。

## 輸入圖（每張都當參考圖輸入）
- 風格：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/s2_16bit.png
- 任務場景構圖：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_51-2 Large.jpeg
- 已完成的街景（色調要接得上）：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/city_mid.png

## 共同規則（重要）
- 和 s2 同一種 16-bit 像素風：清楚的深色輪廓線、有限調色盤、深紫＋洋紅霓虹＋少量青色、下雨的夜晚。
- **尺寸 1536×640（橫向）**，像素密度一致：一個像素格約 4×4 畫面像素（之後會縮成 384×160）。
- **整張不透明**，不要綠幕、不要透明。
- **地面高度一致**：人物站立的地面在 y≈600（從上往下量，畫面高 640）。畫面中間偏左（x 450～800）的地面附近留空，不要放大型物件擋住，主角會站在那裡。
- 側視、略帶景深；光源一致（霓虹從左上、地面有積水倒影）。
- 不要真人、不要 Cyberpunk 2077 或任何原作商標。招牌可以用日文地名或虛構店名（例：神坂バイオテック、港務部）。招牌以外不要多餘文字。

## 清單（原圖存到 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/）
| 檔名 | 節點 | 畫面 |
|---|---|---|
| node_job.png | 委託 | 歌舞伎町後巷：濕地面、紅提燈、一排自販機、牆上的監視器、後門與冷氣室外機 |
| node_elite.png | 精英委託 | 灣岸企業倉庫入口：紅色旋轉警報燈、黃黑封鎖線、捲門半開、遠處外骨骼的剪影（不是人） |
| node_event.png | 事件 | 雨中高架橋下的十字路口：巨大的全息廣告看板、霓虹倒影、斑馬線、遠處的計程車燈 |
| node_market.png | 黑市 | 高架橋下的地攤：帆布推車、成堆疑似贓貨的義體零件與槍、手寫價牌、掛燈泡串 |
| node_clinic.png | 診所 | 地下診所內部：手術燈、手術台（空的）、藥櫃、霓虹十字招牌、管線與舊螢幕 |
| node_rest.png | 休息 | 膠囊旅館走廊：兩側一格一格的膠囊艙、艙門的小螢幕光、走廊盡頭的網咖招牌 |

只動 `art_src/sprites_raw/raw/` 與本目錄的報告檔。不要縮放、不要後製（主 session 會統一縮成 384×160 並接進遊戲）。

## 完成訊號
全部完成或中途停止時，寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/NODE_REPORT.md：每張檔名、原圖尺寸、成功／失敗、輸入了哪些參考圖、失敗原因（額度不足就直說並停止）。≤10 行。
