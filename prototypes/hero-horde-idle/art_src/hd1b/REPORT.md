# hd1b 回報
- route：三張均 master_still.py edit --route codex-cli --finish pixel --class hero --key magenta --facing left，實際 local:codex-cli。
- FIRST／--still：../hd1/boss/candidate-01.png；三張皆引用同一原圖，未改動原圖。
- 交付：windup/candidate-01.png、slam/candidate-01.png、stunned/candidate-01.png，均 1024×1024 RGBA。
- 比較圖：poses-contact.png，依序待命、蓄力、重擊、暈眩，共四張並排。
- 後製：原始 1254×1254 依整張畫布統一縮至 1024×1024，以 forge 去背；不依姿勢外框個別縮放身體。
- 對齊：腳底基準 y=926；蓄力／重擊／暈眩分別垂直平移 -35／+65／+9 px；重擊以右側腳底取基準，保留更低的碎石。
- 檢查：均朝左、全身與狼牙棒完整且留邊、透明背景；相同角、獠牙、配色及裝備。偏差：暈眩眼神失焦較不明顯，保留琥珀亮眼；未額外重骰。
- 額度／時限：3 次 edit 各 1 張成功，無 generate 備援、無重試、未回報額度不足；每筆 --timeout 360，耗時 97.365／62.536／103.418 秒；剩餘額度未知。
- 追溯：inputs/ 保留原始輸出、prompt、run.json、完整命令及 delivery-qc.json；run_generation.py 與 prepare_delivery.py 為本批製作工具。
