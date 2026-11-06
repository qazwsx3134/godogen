# 美術派工單：灣岸的 6 張節點場景背景（第四步）

使用者確認（2026-11-06）：用 Codex 直接生成，規格和上一批（`NODE_BRIEF.md`）完全一樣，只是場景換成**灣岸**（新木場冷鏈物流帶、港務部、封鎖線、海邊）。這 6 張是 mortal-city 地圖節點畫面上方橫幅的**整張背景**，主角 A 的站立 sprite 會另外疊上去，所以畫面裡**不要有任何人**。

## 輸入圖（每張都當參考圖輸入）
- 風格：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/s2_16bit.png
- 上一批同系列（色調、密度、地面高度要一致）：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/node_elite.png
- 任務場景構圖：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_51-2 Large.jpeg

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
| node_wangan_job.png | 委託 | 新木場冷鏈堆場的貨櫃巷道：兩側堆高的冷藏貨櫃、門縫冒出的白色霜氣、頭頂的貨櫃起重機、濕地面 |
| node_wangan_elite.png | 精英委託 | 海岸高架下的港務部武裝檢查站：探照燈、拒馬與黃黑封鎖線、「港務部」招牌、遠處外骨骼的剪影（不是人） |
| node_wangan_event.png | 事件 | 封鎖線的鐵絲網邊：高高的鐵絲網與紅色警示燈、網外遠處的起重機群、海面上的霓虹倒影 |
| node_wangan_market.png | 黑市 | 碼頭邊改裝走私船的水上黑市：甲板上的攤位與帆布、繩索、燈籠串、成堆的義體零件 |
| node_wangan_clinic.png | 診所 | 漁港倉庫改成的走私醫生診所：冷凍櫃當藥櫃、手術燈、空的手術台、掛著的漁網與管線 |
| node_wangan_rest.png | 休息 | 貨櫃改裝的膠囊旅館：疊起來的貨櫃艙房、艙門小螢幕的光、鐵梯、走道盡頭的網咖招牌 |

只動 `art_src/sprites_raw/raw/` 與本目錄的報告檔。不要縮放、不要後製（主 session 會統一縮成 384×160 並接進遊戲）。

## 完成訊號
全部完成或中途停止時，寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/NODE_WANGAN_REPORT.md：每張檔名、原圖尺寸、成功／失敗、輸入了哪些參考圖、失敗原因（額度不足就直說並停止）。≤10 行。
