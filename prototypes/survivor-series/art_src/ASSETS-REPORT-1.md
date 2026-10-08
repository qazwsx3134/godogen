# 階段一候選報告（第二輪，2026-10-08）
實際生成：route_media 回報 local:codex-cli，provider=openai，model=codex-image_gen；使用 Codex 登入額度，未呼叫 API。
以下路徑均相對 art_src；每項 candidate-{01,02,03}.png 為三张候選，candidates-contact.png 為並排圖。
smoker：enemies/smoker/candidate-{01,02,03}.png；比較 enemies/smoker/candidates-contact.png；key=green。
fatty：enemies/fatty/candidate-{01,02,03}.png；比較 enemies/fatty/candidates-contact.png；key=magenta。
motorcycle：vehicles/motorcycle/candidate-{01,02,03}.png；比較 vehicles/motorcycle/candidates-contact.png；key=green。
car：vehicles/car/candidate-{01,02,03}.png；比較 vehicles/car/candidates-contact.png；key=magenta。
street_block：background/street_block/candidate-{01,02,03}.png；比較 background/street_block/candidates-contact.png；不透明，key=不適用。
原始 generated.png、prompt.txt、job.json、run.json 與 pad.json 保留於各素材 r2/ 子目錄；舊失敗紀錄保留。
背景真實尺寸依序 948×1659、948×1659、979×1606，未達指定 5:7；原圖完整保留，未裁切或強行變形。
背景三張 alpha 均全不透明，中央無角色／障礙；01 鋪磚呈斜格，03 中央橫街與主地面材質差異較弱，均有暖光反射。
fatty 三張均多出未指定的香菸；保留候選供挑選，不宣稱完全符合外觀提示詞。
驗收：15 張候選與 5 張比較圖齊全；12 張 sprite 均 1024×1024 真透明 RGBA、單主體、四周有留白、朝右下／斜俯視、無地面陰影與文字；未鏡像。
交通工具與騎士／駕駛同圖，車輪／後照鏡／安全帽完整；12 次 pad 均無警告。
僅生成候選，未 approve、未做動畫或車輛其他方向；階段一發布報告後直接開始階段二。
