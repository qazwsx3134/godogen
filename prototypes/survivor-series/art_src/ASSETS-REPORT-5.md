# ASSETS-REPORT-5

## A — 地磚與燈籠反光
- 更新 `map/ground/pavement.png`（512×512）；3×3 重複檢視未見行列空隙，左右及上下接縫均通過嚴格 QC。
- 地磚 QC：contrast 0.071717（門檻 0.035）、border delta 0、wrap x 1.013484 / y 1.007589（門檻 1.25）、warnings 0；像素完全相等未被證明。
- 對照與檢視圖：`map/preview/pavement-comparison-r7.png`、`ground-repeat-3x3.png`、`ground-seam-y512-3x.png`、`ground-seam-x512-3x.png`。
- 反光改為低透明度暖紅橘色直向軟光帶，從燈座接觸點往畫面下方延伸；地磚紋理仍透出。alpha bbox `(207,260,304,464)`。
- 反光 QC：contrast 0.101742（門檻 0.035）、visible fraction 0.047455、warnings 0；同燈位對照在 `map/preview/wet-reflection-comparison-r7.png`，完整圖在 `map/preview/ground-layered-hero90.png`。
- 首次綠幕色鍵抽取 contrast 0.022260（低於 0.035）已淘汰；改原生 alpha 處理後嚴格 QC 通過，未放寬門檻。生圖原檔、prompt、job、run 保存在 `map/ground/raw-wet-reflection-r7/`；路由 `codex-cli`，一張成功輸出。
- 地圖 manifests 與 bundle 雜湊已同步；`map_bundle.py validate --require-sha256` 通過，errors 0、warnings 0。
- Godot 匯出已更新至 `map/godot/`；Mac Godot 4.7 實際 editor import 與一幀 headless scene load 均 exit 0，16 張 PNG 匯入，無診斷；結果記於 `map/godot/root-validation.json`。
- 其他 ground 貼圖與 `map/props` 未修改。B 尚未執行。

## B — 抽菸者改台灣流氓
- 未執行（2026-10-12 使用者出門，依指示停止）。

BLOCKED：A 已收尾；依指示停止，B 尚未執行。
