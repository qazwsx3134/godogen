# Survivor Studio 改善 — 2026-10-16

## 完成內容

- Grid.nearest 直接掃描候選 cell 並比較距離平方，保留相同遍歷／同距離優先順序，省去 query 陣列與第二次完整掃描。
- 新增 has_at_least，在達到密度門檻時返回；主角輪廓讀取此判斷。
- rebuild 記住 actor 最大半徑，修正大於 48px 的 hitbox 查詢遺漏。
- query 保留原生 distance_to；實測全面改成腳本距離平方沒有改善，已採用較快版本。

## CPU 量測

固定 seed 20261015、140 actors、4096 個位置；每項 1 輪預熱、5 輪取中位數。依序執行同一負載；clustered before 使用原始 grid.gd 備份，對應 baseline commit `eb8622d`。

| 分布／每次呼叫 | Before μs | After μs | 差異 |
| --- | ---: | ---: | ---: |
| 均勻／最近目標 | 14.624 | 10.960 | -25.1% |
| 均勻／密度判斷 | 5.305 | 4.748 | -10.5% |
| 均勻／完整 query | 5.188 | 5.248 | +1.2% |
| 密集／最近目標 | 48.256 | 23.494 | -51.3% |
| 密集／密度判斷 | 34.452 | 2.792 | -91.9% |
| 密集／完整 query | 34.667 | 33.553 | -3.2% |

均勻 actors 範圍 ±552×792，密集 ±90×90（查詢 ±40×40）。最近目標半徑 260，query／門檻半徑 120、門檻 8。每項 before/after checksum 一致：均勻 query 21073、nearest 293700、density 567；密集 566999、337758、4096。完整 query 沒有一致加速；本次收益在最近目標與密度檢查。

原始 log：[均勻 before](../qa/evidence/studio-polish-2026-10-16/before-grid-bench.log)、[均勻 after](../qa/evidence/studio-polish-2026-10-16/grid-uniform-final.log)、[密集 before](../qa/evidence/studio-polish-2026-10-16/grid-clustered-before.log)、[密集 after](../qa/evidence/studio-polish-2026-10-16/grid-clustered-final.log)。數字是 CPU 函式微基準，不是整場戰鬥 FPS。

```bash
godot --headless --path . --fixed-fps 60 --script res://tools/studio_bench.gd
godot --headless --path . --fixed-fps 60 --script res://tools/studio_bench.gd -- --clustered
```

## 驗收

8 組 native suites 通過；Grid 新增 611 項斷言，包含暴力掃描 oracle、140 actors／100 個查詢點、正負座標、相切、大 hitbox、死亡／回收、同距離順序與清空。最終微調另重跑 Grid 611、playable 219、combat regressions 38 項檢查。

[390×844 原生密集敵群畫面](../qa/evidence/studio-polish-2026-10-16/survivor-combat.png)已檢視，保留既有像素夜市與 HUD。[完整 smoke 結果](../qa/smoke-2026-10-16.md)。真機 GPU／記憶體、觸控手感、音效與 Web 全流程未重新驗證；效能預算合規為 NOT ASSESSED。

## Claude 協作

Claude 負責共用 Studio helper 的子專案 catalog 路徑修正與 regression test，11 組 Studio 測試通過；Codex 負責遊戲端與最終整合。見[交接記錄](../qa/evidence/studio-polish-2026-10-16/claude-handoff.md)、[本遊戲 artifact 掃描](../qa/evidence/studio-polish-2026-10-16/studio-artifacts.txt)。
