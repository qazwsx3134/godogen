# Studio 效能改善規格

**Type**: Tweak
**Date**: 2026-10-16
**GDD Reference**: [既有遊戲摘要](../game-brief.md) 與 README 連結的正式規格。

## 問題與設計

`_validate_save_payload` 每次建立新 StoryRunner、重讀劇本與資產清單，並重新驗證全部內容。驗證應使用正在遊玩的已驗證故事，且不能影響 live state。

- StoryRunner 建立獨立可變狀態的 probe，共用載入後只讀的故事定義與 catalog。
- shell 重用 probe；重新載入／切換故事時釋放。每筆 payload 仍完整 restore 與驗證版本、旗標、回合和倒數。
- inline markup 共用已編譯 RegEx；每次呼叫的文字、速度堆疊與 pause state 仍獨立。

- 存檔面板與 PopupLayer 的 z_index 設為 2，蓋住 z_index 為 1 的姓名牌；靜態屬性保存在既有 scene。

## 驗收條件

- [x] 已載入後移除來源檔，存檔驗證與自動存檔仍成功。
- [x] 無效 payload、不同故事與版本仍被拒絕；live runner 的狀態不變。
- [x] 修改來源版本並重新載入後，新版本可存，舊版本拒絕。
- [x] 同一 payload 的 60 次驗證有 before/after 數據，並保留存讀檔與第一章路線測試。
- [x] 載入既有場景觀察畫面，保留和紙素材與場景來源。

- [x] 存檔面板顯示時，姓名牌不再浮在其上；390×844 原生截圖確認。

## 驗證與界線

Godot 4.7 原生測試與固定輸入 CPU 微基準，使用隔離的測試存檔。沒有已提交的裝置幀時間／記憶體預算，因此預算達標狀態為 NOT ASSESSED。

結果寫入 `production/polish/studio-polish-2026-10-16.md` 與 `production/qa/smoke-2026-10-16.md`。
