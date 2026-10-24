# 動作姿勢候選交付
完成 27/27 姿勢、54 張 PNG、6 張總覽；生成失敗 0、跳過 0、超時 0、超時重試 0；僅交候選，未 approve、未製作動畫。
route=local:codex-cli，provider=openai，回報 model=codex-image_gen（CLI 識別，未揭露底層生圖模型 ID）。
每姿勢 takes=2、整筆外部時限 360 秒、單張外層 175 秒／內層 165 秒；最多同時 6 筆，最久單張 90.452 秒。
captain 總覽：`captain/poses-contact.png`（master＋walk_a／walk_b／attack／down／skill 各兩張）。
guardian 總覽：`guardian/poses-contact.png`（master＋walk_a／walk_b／attack／down／skill 各兩張）。
medic 總覽：`medic/poses-contact.png`（master＋walk_a／walk_b／attack／down／skill 各兩張）。
meadow_slime 總覽：`meadow_slime/poses-contact.png`（master＋walk_a／walk_b／attack／down 各兩張）。
briar_boar 總覽：`briar_boar/poses-contact.png`（master＋walk_a／walk_b／attack／down 各兩張）。
ruin_hound 總覽：`ruin_hound/poses-contact.png`（master＋walk_a／walk_b／attack／down 各兩張）。
候選路徑一律 `<角色>/poses/<pose>/takes/take-{01,02}/generated.png`；每姿勢另保留 run.json、spec.json、prompt.txt、job.json 及 takes.png。
captain 偏差：walk_b #1/#2 與 walk_a 的前伸腿相近，對側步未充分區分；attack #2 肩甲移到持劍臂，與 master 不符；down #2 頭腳方位旋轉較大。
guardian 偏差：walk_b #1/#2 與 walk_a 多仍同側腿前伸，對側步不明顯；attack 兩張較像下揮收招，動作幅度偏小；身分配色仍可辨識。
medic 偏差：walk_b #1/#2 與 walk_a 的腳步仍很接近；down #2 身體方向旋轉較大，眼鏡歪斜不明顯；skill 保留繃帶與草藥，但手勢非每張都明確雙手拋出。
meadow_slime：未見明顯身分或朝向跑掉；壓扁、拉長、衝撞、融化與旋渦眼可辨識；內部草葉／石塊位置隨形變略變。
briar_boar：未見明顯身分或朝向跑掉；walk_a／walk_b 對側步差異較小，攻擊與側倒可辨識，花葉數量／位置略有漂移。
ruin_hound：未見明顯身分或朝向跑掉；walk_a #2 抬得較高、近小跳；石紋形狀稍有漂移；down 眼縫已熄暗但項圈符文仍青色，符合僅要求眼縫變暗。
QC：已目視 6 張總覽；54 張 PNG 可解碼、排除洋紅後輪廓未觸邊，最小邊距 11 px（captain attack #2 劍尖，較緊但未裁切）；未見整體朝左候選。
逐筆核對 POSES 的 change／keep 原文、唯一參考圖 master 的 SHA；6 個 master 目錄所有原檔 SHA 保持不變。啟動前 keep 擷取檢查曾中止一次，修正後才送出生圖；未改邊界外檔案。
