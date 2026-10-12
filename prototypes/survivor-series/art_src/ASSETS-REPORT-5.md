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
- `local:codex-cli`，未呼叫 API；只附男主角作風格參考，未附真人照／identity-ref。`--class mob`、pixel、朝右下、50°俯視；每張限時 360 秒，`run-02` 三張耗時 55.729／56.530／53.772 秒。`run-01` 三筆因唯讀沙盒啟動失敗，保留紀錄後重跑一次成功。
- 輸出 `art_src/enemies/smoker-gangster/candidate-{01,02,03}.png`（1024×1024 RGBA）；`candidates-contact.png` 含 90 px 主體高度預覽；`comparison-old-vs-new.png` 以同樣 90 px 高度並排三張舊煙霧怪與三張新候選。
- 原始 `generated.png`、`prompt.txt`、`job.json`、`run.json` 保存在 `smoker-gangster/run-02/`（每張各自一份）；三份 pad JSON 與 alpha 輸出在 `pad-{01,02,03}/`。僅候選，未 approve／動畫。
- Pad QC：三張皆單一主體、主體高 471 px／頂端 y=406／基線 y=877；warnings 0、opaque key pixels 0、外圈 spill 0、key-hued pixels 0、ignored parts 0；visible pixels 243201／280444／286230。
- 視看均符合高漸層平頂、刺青手臂、嘴角香菸與右下朝向；90 px 清楚可辨，硬規格偏差無，候選姿勢相近。

DONE
