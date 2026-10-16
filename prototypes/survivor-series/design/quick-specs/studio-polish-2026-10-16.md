# Studio 效能改善規格

**Type**: Tweak
**Date**: 2026-10-16
**GDD Reference**: [既有遊戲摘要](../game-brief.md) 與 README 連結的正式規格。

## 問題與設計

Grid.nearest 先產生 query 陣列，再做第二輪距離計算；readability 也建立完整結果只為判斷是否達門檻。固定 48px 的搜尋 padding 會遺漏半徑更大的 actor。

- query 保留原生距離判斷；nearest 用距離平方，在既有 cell 迭代順序中直接保留最近 actor，不建立結果陣列。
- has_at_least 達到密度門檻即返回，用在主角輪廓判斷。
- rebuild 記住實際最大半徑，保留至少 48px padding；大體型 actor 也能正確查詢。

## 驗收條件

- [x] 140 actors／固定 seed／100 個位置，query、nearest 與密度和暴力掃描一致。
- [x] 正負座標、0 半徑、相切、大 hitbox、同距離順序、死亡／排隊回收與清空均覆蓋。
- [x] 固定 4096 個查詢位置，改善前後 checksum 一致並保留 CPU 微基準。
- [x] 既有成長、戰鬥、英雄、融合、視角及滿載配額測試仍通過。
- [x] 原生畫面可觀察主角、敵人與 HUD；真機 GPU 效能維持未評估。

## 驗證與界線

Godot 4.7 原生測試與固定輸入 CPU 微基準，使用隔離的測試存檔。沒有已提交的裝置幀時間／記憶體預算，因此預算達標狀態為 NOT ASSESSED。

結果寫入 `production/polish/studio-polish-2026-10-16.md` 與 `production/qa/smoke-2026-10-16.md`。
