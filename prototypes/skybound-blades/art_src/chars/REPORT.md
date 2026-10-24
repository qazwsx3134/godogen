# 浮空劍域角色原畫候選交付
route_media：local:codex-cli；job.provider=openai；回報 model=codex-image_gen（CLI 工具識別，未揭露底層生圖模型 ID）。
先完成 captain 三張並目視驗證，再啟動其他五角色；下列路徑相對於本 REPORT，{01,02,03} 代表三個獨立檔案。
captain：`captain/r1/takes/take-{01,02,03}/generated.png`；比較圖：`captain/candidates-contact.png`。
guardian：`guardian/r1/takes/take-{01,02,03}/generated.png`；比較圖：`guardian/candidates-contact.png`。
medic：`medic/r1/takes/take-{01,02,03}/generated.png`；比較圖：`medic/candidates-contact.png`。
meadow_slime：`meadow_slime/r1/takes/take-{01,02,03}/generated.png`；比較圖：`meadow_slime/candidates-contact.png`。
briar_boar：`briar_boar/r1/takes/take-{01,02,03}/generated.png`；比較圖：`briar_boar/candidates-contact.png`。
ruin_hound：`ruin_hound/r1/takes/take-{01,02,03}/generated.png`；比較圖：`ruin_hound/candidates-contact.png`。
captain 外觀差異：#1/#3 肩甲在持劍側，#1 另側亦似有肩甲，與僅左肩不符；#2 髮色偏藍黑；頭身略高於三頭身。
guardian 外觀差異：三張皆比三頭身修長；翼徽偏雙翼鳥徽，靴子較偏鋼製護脛；#2 槌垂得較低，未完全符合髖側備戰。
medic 外觀差異：三張皆偏修長，未達三頭身；#1/#3 外套下襬較長；其餘眼鏡、兜帽、繃帶與草藥可見，未見宗教／紅十字符號。
meadow_slime 外觀差異：#1 僅兩片芽葉、沒有三葉草冠；#2/#3 有三葉草與小葉，並多了腳狀膠體凸起。
briar_boar 外觀差異：#1 頭略高、衝刺壓低姿勢較弱；三張荊棘白花、獠牙與苔蹄均可辨識。
ruin_hound 外觀差異：石面具偏完整頭甲、毛較長，並非僅上半臉石面罩與短毛；#2 額外有石腳環，前爪抬起感較弱。
目視 QC：18 張皆為單一角色、HD 插畫而非像素、朝右下，手腳／武器／尾巴完整，未見角色本體洋紅／粉紅配色、文字或地面投影；無需水平鏡像。
檔案 QC：18 張 PNG 皆 1254×1254、可解碼；排除洋紅背景後輪廓最小邊距 24 px，無觸邊；6 張並排比較圖均存在，與各 r1/takes.png 相同。
問題紀錄：captain 首次沙箱 CLI 無法初始化，失敗紀錄保留於 captain/r1-sandbox-failed/；提權重跑後 18/18 成功，未發生超時；每張外層 timeout=360 秒、內層 340 秒。
PROMPTS 共同規格及各角色描述照用，未附任何參考圖、未讀取／沿用 hero-horde-idle 圖；原始檔與 run.json、spec.json、prompt.txt、job.json 均保留；未 approve、未做姿勢／動畫、未修改邊界外檔案。
