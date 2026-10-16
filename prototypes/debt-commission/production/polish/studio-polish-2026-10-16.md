# Debt Studio 改善 — 2026-10-16

## 完成內容

- StoryRunner 建立獨立驗證狀態，共用載入後只讀的故事／資產定義；shell 重用驗證器，重新載入故事時失效。每筆 payload 仍驗證版本、旗標、互動與倒數；live runner 不受影響。
- inline markup RegEx 編譯一次，呼叫結果仍獨立。
- 既有 `main.tscn` PopupLayer 與 `save_slots_panel.tscn` 的 z_index 設為 2，解決姓名牌穿透存檔面板；和紙 PNG 與可編輯場景維持既有來源。
- 修正 Dialogue Manager 4.1.0 對 Godot 4.7 EditorSettings 字級 key 的相容性，見 [套件補丁](../../docs/DEPENDENCY-PATCHES.md)。

## CPU 量測

同機、同一第一章 payload，預熱 3 次、量測 60 次 `_validate_save_payload`，程序逐一執行。before 使用 baseline commit `eb8622d` 的遊戲程式。

| 每次驗證 | Before | After |
| --- | ---: | ---: |
| 中位時間 | 122.126 ms | 0.032 ms |
| P95 | 141.861 ms | 0.042 ms |
| 接受筆數（含預熱） | 63/63 | 63/63 |
| live snapshot 不變 | true | true |

原始數據：[before](../qa/evidence/studio-polish-2026-10-16/before-debt-bench.log)、[after](../qa/evidence/studio-polish-2026-10-16/after-debt-bench.log)。這是已載入劇本的 CPU 驗證成本，未量測首載與手機 FPS。

```bash
godot --headless --path . --fixed-fps 60 --script res://tools/studio_bench.gd
```

## 驗收

30 組 native suites 通過。新增測試覆蓋來源檔移除仍可存檔、無效 payload、故事／版本不符、valid-invalid-valid 隔離與重新載入失效。既有第一章路線、存讀檔、所有 UI 風格與文字演出通過；圖層修改後另重跑 reading scenes、save slots、UI styles。

390×844、Xvfb 腳本化截圖已檢視：[閱讀畫面](../qa/evidence/studio-polish-2026-10-16/debt-reading.png)、[存檔面板](../qa/evidence/studio-polish-2026-10-16/debt-save-slots.png)。姓名牌不再蓋住面板。

[完整 smoke 結果](../qa/smoke-2026-10-16.md)。Parley editor teardown 仍有既存資源釋放警告。真機觸控、音效、GPU、記憶體與幀時間預算均未重新驗證。

## Claude 協作

Claude 負責共用 Studio helper 的子專案 catalog 路徑修正與 regression test，11 組 Studio 測試通過；Codex 負責遊戲端與最終整合。見[交接記錄](../qa/evidence/studio-polish-2026-10-16/claude-handoff.md)、[本遊戲 artifact 掃描](../qa/evidence/studio-polish-2026-10-16/studio-artifacts.txt)。
