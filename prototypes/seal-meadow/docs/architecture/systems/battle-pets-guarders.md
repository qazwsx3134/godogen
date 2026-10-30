# S34 乘坐實作邊界

2026-10-30；實作規格。

- Player 擁有 ephemeral mounted 狀態、乘坐資格、有效移速與 Actor 高度。倍率只在移動計算讀取，不改寫 move_speed；開始／停止以同一 setter 完成，發出 mounted_changed。
- PetFollower 沿用 main scene 的唯一 Pet 實例；乘坐時貼著角色並放大，下坐恢復 scene 的 Actor 比例。它仍不參與傷害或屬性計算。
- HUD 的 PetPanel 是保存的 scene：固定 Header，ScrollContainer 管內容，乘坐按鈕與資格提示留在 scene；腳本只更新資料及連接 signal。餵食重用既有 84px RefineRow 動作列。
- Main 在 travel／background 強制下坐；Player 在選怪、成功施法、受傷、死亡及 load_data 下坐。拒絕技能不改狀態。
- 乘坐狀態不進 save_data，不升版 schema；S17 PetCare 的 stage 是解鎖依據，既有 pet stats 只套用一次。

主要可編輯位置：player 的 ride_speed_multiplier／ride_height；PetFollower 的 mounted_scale；HUD `Root/PetPanel/Contents/Head` 與 `Contents/Scroll/Box` 與乘坐提示。正常啟動不重建場景。
