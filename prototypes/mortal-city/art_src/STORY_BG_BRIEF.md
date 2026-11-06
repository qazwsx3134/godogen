# 美術派工單：4 張劇情委託場景背景（第五步）

使用者確認（2026-11-06「先繼續生成」）：用 Codex 直接生成，規格和節點背景（`NODE_BRIEF.md`）完全一樣。這 4 張是劇情委託畫面上方橫幅的**整張背景**，主角 A 的站立 sprite 會另外疊上去，所以畫面裡**不要有任何人**。每張對應一案劇情，要看得出是那一案的關鍵地點。

## 輸入圖（每張都當參考圖輸入）
- 風格：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/s2_16bit.png
- 同系列（色調、密度、地面高度要一致）：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/node_event.png
- 任務場景構圖：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_51-2 Large.jpeg

## 共同規則（重要）
- 和 s2 同一種 16-bit 像素風：清楚的深色輪廓線、有限調色盤、深紫＋洋紅霓虹＋少量青色、下雨的夜晚。
- **尺寸 1536×640（橫向）**，像素密度一致：一個像素格約 4×4 畫面像素（之後會縮成 384×160）。
- **整張不透明**，不要綠幕、不要透明。
- **地面高度一致**：人物站立的地面在 y≈600（從上往下量，畫面高 640）。畫面中間偏左（x 450～800）的地面附近留空，不要放大型物件擋住，主角會站在那裡。
- 側視、略帶景深；光源一致（霓虹從左上、地面有積水倒影）。
- 不要真人、不要 Cyberpunk 2077 或任何原作商標。招牌可以用日文地名或虛構店名（例：神坂バイオテック、港務部）。招牌以外不要多餘文字。

## 清單（原圖存到 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/）
| 檔名 | 劇情 | 畫面 |
|---|---|---|
| story_P01-01.png | 終電包裹 | 地下鐵月台（環狀線新宿駅 B2）：停著的末班電車、月台的第三根柱子、長椅上一只亮黃燈的保冷箱、站名牌「新宿 B2」、天花板滴水 |
| story_P01-02.png | 診所不收現金 | 企業診療所的地下病歷庫：停電，只有紅色應急燈；一排排金屬檔案櫃、正在跑進度條的終端主機、牆上的「神坂バイオテック」標誌 |
| story_P01-03.png | 不存在的保戶 | 新木場冷鏈堆場 C 區第七排：一個門縫冒出白煙的冷藏貨櫃（門上有手動洩壓閥）、探照燈的光柱、堆疊的貨櫃、雨 |
| story_P01-06.png | 午夜轉運線 | 貨運支線的月台：一節門開著的冷藏車廂、遠處亮黃燈的封鎖閘口與「港務部」標示、軌道、外骨骼的剪影（不是人）、雨 |

只動 `art_src/sprites_raw/raw/` 與本目錄的報告檔。不要縮放、不要後製（主 session 會統一縮成 384×160 並接進遊戲）。

## 完成訊號
全部完成或中途停止時，寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/STORY_BG_REPORT.md：每張檔名、原圖尺寸、成功／失敗、輸入了哪些參考圖、失敗原因（額度不足就直說並停止）。≤8 行。
