# S24｜音樂、音效與環境音

狀態：**Planning Draft（文件與工作包草案）**；2026-10-26。首次交付：M1；優先層：MVP；相對複雜度：M（不是工期）。

## 玩家價值與責任

用區域音樂與清楚事件聲建立氣氛和打擊辨識。

**規則與邊界**：Master/Music/SFX/UI/Ambience bus；同事件最小間隔、voice cap、換軌淡入淡出；背景／靜音行為明定。

## 文件交付清單

- **玩法／系統規格 GDD**：預定 `design/gdd/audio.md`。需將上方規則展開成正常流程、狀態轉移、拒絕原因、取消／重入／死亡／離線處理；有數值時附變數、單位、安全範圍與算例。
- **Godot 技術規格 TDD**：預定 `docs/architecture/systems/audio.md`。需寫 scene tree、模組責任、資料所有權、命令／事件、更新時機、存讀／網路邊界與現有程式遷移方式。
- **此系統專屬內容**：音訊方向、事件清單、混音與 loudness 記錄；背景／Web 手勢啟動行為；QA：喇叭／耳機。
- **QA 與證據規格**：預定 `production/qa/systems/audio.md`。以本頁 AC 編號追溯測試／手測／真機證據，附內容版本與未驗證項；測試不能僅檢查檔案存在。

## 資料、介面與 Godot 實作邊界

**資料與狀態**：AudioEventDefinition；ZoneMusicProfile；voice priority；saved volume settings。

**對外契約**：AudioService.play_event(id,position,importance)；只接語意事件，不讀全世界怪物樹。

**scene／模組**：scenes/audio/audio_root.tscn；AudioStreamPlayer/3D；kit music／sfx_bank 候選；原創／授權音源。

## 相依與整合

共通開工條件與附件規則見[文件契約](../document-contracts.md)。

- 初始契約／首版必要前置：[S01 內容定義與資料登錄](s01-content-registry.md)、[S02 權威狀態、命令與時間](s02-authority-commands-clock.md)。
- 直接下游：無。

## 分階段 roadmap

M1 基本事件與一背景曲；M2 兩區切換；M3 手機混音與背景中斷；後續拓曲庫。

## 可驗收條件

- **AC-S24-01**：設定靜音後重開仍保留且背景返回不自行解除。
- **AC-S24-02**：同時多怪受擊不突破 voice cap 或爆音。
- **AC-S24-03**：區域切換不重播同曲，失敗載入不留下雙重 BGM。

## 風險與開工條件

本機 67 MP3 只是研究數量，不是可直接分發的音源。

