# Checkpoint A 驗收記錄

2026-09-27；Godot 4.7 stable / GDScript / Compatibility。這是 Foundation + 一英雄 Combat Slice，完整 MVP 範圍見 [規格狀態](../../../../docs/taskbar-hero-mobile-spec/docs/DEV_STATUS.md)。

## 實際畫面

| 尺寸 | 遠征 | 隊伍 | 暫停 | 小螢幕捲動 |
|---|---|---|---|---|
| 390 × 844 | [畫面](390x844-overview.png) | [畫面](390x844-party.png) | [畫面](390x844-paused.png) | 上方使用 ScrollContainer |
| 320 × 568 | [畫面](320x568-overview.png) | [畫面](320x568-party.png) | [畫面](320x568-paused.png) | [捲動後](320x568-party_scrolled.png) |

[18 秒操作錄影](gameplay.webm)：自動戰鬥、切換隊伍資料、暫停／繼續與手動存檔。使用隔離 QA 存檔，所以畫面已有累積擊倒與金幣，不是新玩家的初始數值。

畫面由 `tools/capture_review.gd` 實例化正式 `main.tscn`，透過實際輸入點擊按鈕、滾輪捲動；不是獨立 HTML mockup。已檢查最終錄影解碼後的 1／7／13／17 秒畫面。渲染環境為 Xvfb + Mesa llvmpipe 軟體 OpenGL；不能作為手機 60 FPS 或耗電證據。Godot 的 V-Sync driver warning 屬於此擷取環境。

## 自動檢查

五組測試全部通過：

- `test_save_recovery.gd`：有效 JSON roundtrip、損壞主檔回復、兩份損壞保留、新版與擴充 schema 停寫。
- `test_playable.gd`：索敵／範圍／時序、不同戰場隔離、死亡只結算一次、重生、切頁續戰、暫停文案、Gold 同步、48 單位按鈕、320×568 實際捲動與存檔。
- `test_scene_persistence.gd`：實際 scene 參照與編輯器角色外觀；沒有執行 script 才生成的假場景樹。
- `test_editor_contract.gd`：另存修改過的 GameTitle 與 SafeMargin，重新載入執行後文字與間距仍在。
- `test_soak.gd`：600 秒／36,000 次模擬更新，兩個單位持續戰鬥，沒有累積新的單位。

[測試輸出](test-results.txt)。正常啟動另驗證 `.tscn`／`.tres` 雜湊不變；啟動不呼叫 builder。Kit 同步副本 `sync.sh --check taskbar-hero` 通過。

Android／iOS 匯出、Safe Area 實機及長時間效能尚未驗證；無音訊，使用幾何佔位美術。

## 重現

一般遊玩與測試命令見 [專案 README](../../README.md)。截圖可在有顯示器的桌面執行以下命令；Linux 無桌面時在前面加 `xvfb-run -a`：

```bash
XDG_DATA_HOME=/tmp/taskbar-review-data TASKBAR_CAPTURE_WIDTH=390 TASKBAR_CAPTURE_HEIGHT=844 TASKBAR_CAPTURE_MOVIE=1 godot --path prototypes/taskbar-hero --audio-driver Dummy --fixed-fps 20 --script res://tools/capture_review.gd
```

輸出為 `/tmp/taskbar-acceptance/` 下的 PNG 與 360 張 JPEG 錄影影格（20 fps），再用支援 MJPEG 輸入與 VP8 輸出的 ffmpeg 組成 WebM。此工具不參與遊戲的一般啟動。
