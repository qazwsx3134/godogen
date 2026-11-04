# 美術派工單：正式 sprite（第二步）

使用者選擇（2026-11-04）：風格 **S2 16-bit**、主角 **A**（B/C/D 保留給其他角色）。用 Codex 直接生成，圖生圖。

## 輸入圖（每張都當參考圖輸入）
- 風格：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/s2_16bit.png
- 主角 A（c1 最左邊那位）：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/style_explore/c1_heroes.png
- 任務場景構圖：/Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/ref/ChatGPT 圖像 2026年11月4日 下午04_20_51-2 Large.jpeg

## 共同規則（重要）
- 和 s2 完全同一種 16-bit 像素風格：清楚黑色輪廓線、有限調色盤、深紫＋洋紅霓虹＋少量青色。
- **像素密度一致**：所有圖的一個像素格都約等於 4×4 畫面像素（我會縮小 4 倍拼成 384×160 的場景）。
- **去背底色一律純綠 #00FF00**（不要洋紅，主角衣服有洋紅滾邊）。物件之間至少留 32px 空白，不要互相重疊、不要陰影落在綠底上。
- 不要真人、不要 Cyberpunk 2077 原作商標。招牌可用日文地名。物件上不要多餘文字。
- 全部側視、光源一致（左上暖燈、窗外紫色霓虹）。

## 清單（輸出到 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/）
| 檔名 | 內容 | 尺寸 |
|---|---|---|
| room_bg.png | s2 的公寓，但**沒有人、沒有沙發和家具、沒有桌上小物**：只有牆、地板、天花板燈、管線、海報，以及窗框；**窗框裡面整塊塗 #00FF00** | 1536×640 |
| window_city.png | 窗外的東京夜景（和 s2 窗外一致）：東京鐵塔、新宿／渋谷／秋葉原／東京霓虹、全息女性看板、高架軌道（不要列車）、櫻花、鳥居、雨 | 960×352 |
| furniture_kit.png | 綠底上分開排：長沙發（同 s2，空的、不含毯子）、床、矮桌（桌面空）、筆電（螢幕人體圖）、狐狸螢幕、右側邊櫃／電腦主機 | 1536×1024 |
| props_kit.png | 綠底上分開排：睡覺的三花貓（單獨）、紅色青海波毛毯（單獨）、泡麵杯＋筷子、罐裝飲料、菸灰缸、手機、遊戲機、馬克杯、牆上的槍、紅色「侍」旗幟、垂掛藤蔓、小公仔 | 1536×1024 |
| hero_a_poses.png | 主角 A 三個姿勢、綠底、分開排：①躺姿（同 s2：雙手枕頭、一腳屈膝，**不含沙發**，背面直接是綠色）②側面朝右跑步中段（一腳在前一腳在後）③側面朝右站立 | 1536×768 |
| city_far.png | 任務用遠景：紫色雨夜天空、東京鐵塔、遠方大樓與霓虹、無人機光束；**左右邊緣可以無縫接起來** | 3072×640 |
| city_mid.png | 中景：大樓與直式霓虹招牌、天橋（欄杆、紅色警示燈、兩名武裝警衛剪影）、企業大樓「神坂バイオテック」招牌；**大樓上方的天空塗 #00FF00**；左右可無縫接 | 3072×480 |
| city_front.png | 前中景：櫻花樹、紅色鳥居、直式「ラーメン」招牌、居酒屋紅提燈；**背景全部 #00FF00**；左右可無縫接 | 3072×640 |
| vehicles_roof.png | 綠底上分開排：高架列車（5 節，側面朝右）、無人機、屋頂邊緣條（冷氣機、水管、積水洋紅反光，**左右可無縫接**、約 3072×160 的橫條可另存 roof_strip.png） | 1536×768（另加 roof_strip.png 3072×160） |

原始大圖放 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/sprites_raw/raw/。只動這兩個資料夾。

## 完成訊號
全部完成或中途停止時，寫 /Users/peter/repo/godot/godogen/prototypes/mortal-city/art_src/SPRITE_REPORT.md：每張檔名、尺寸、成功／失敗、輸入了哪些參考圖、失敗原因（額度不足就直說並停止）。≤12 行。
