# 派工單：抽菸者煙霧變濃、拿掉醜圓圈（套圈圈、煙霧）

專案：`/Users/peter/repo/godot/godogen/prototypes/survivor-series`（Godot 4.7，像素風夜市割草遊戲）。先讀該資料夾的 `README.md` 像素風段落與 `CONTEXT.md` 用語。

## 使用者原話
「抽煙的壞人的煙的特效太稀薄了，然後有圓圈都很醜，比如套圈圈的跟抽煙的煙霧。我覺得遊玩的感覺已經很不錯了。」
→ 只改外觀，不改玩法數值（半徑、傷害、持續時間、判定都不動）。

## 工作 1：抽菸者煙霧（`scenes/smoke.tscn`、`scripts/smoke.gd`）
現況：`Footprint/DangerArea`（Polygon2D 圓）＋`DangerBoundary`（Line2D 圓框）＋`Cloud`（ColorRect，shader `addons/proto_kit/pixel_vfx_smoke.gdshader`，alpha 只有 0.38/0.6，四團小雲）。截圖上就是一個灰色圓框、裡面幾乎看不到煙。
要做：
- 拿掉 DangerArea 與 DangerBoundary 兩個圓形節點。危險範圍改由「煙本身」表達：一團濃密、邊緣不規則（不是正圓）的像素煙，大致蓋滿判定半徑 42（隨 `radius` 縮放），看起來就知道「站進去會痛」。
- 煙要濃：不透明度明顯提高、團塊更多、有明暗兩到三階、緩慢翻滾。抽菸者是「黑煙團紅眼」，煙用偏深灰／灰紫，可加極少量暗紅餘燼點綴（可選）。結束時淡出。
- `addons/proto_kit/` 是 godot-kit 同步來的副本，**不能改**。新 shader 放在本專案，例如 `assets/fx/smoker_smoke.gdshader`（可以 `#include` kit 的 `pixel_vfx.gdshaderinc`）。
- 維持 `smoke.gd` 的介面：`lifetime`、`radius`、`damage`、`age`、`step(delta)`、到期 `queue_free`；進度由 `step` 推進，不用 shader 的 `TIME`。`%Footprint`／`%Cloud` 若改名或刪除，記得同步改 `smoke.gd`。
- 場上可能同時有很多團煙：不要加 Polygon2D／Line2D，一團煙維持一次 draw call 等級。

## 工作 2：套圈圈（`scenes/ring.tscn`，邏輯在 `scripts/arsenal.gd` 的 `_ring`／`_zone`、`scripts/projectile.gd`）
現況：`Visual/Outer`、`Visual/Inner`（Line2D 正圓）＋`Fill`（Polygon2D），看起來是平滑的大橘圈，跟像素圖不搭。
要做：
- 換成像素風的「夜市套圈圈的塑膠圈」：用 Python 程序化畫一張（或兩三張）小的像素圖 hoop（斜看的橢圓、粗像素、深色描邊、亮橘＋高光，像 `assets/pixel/fx/` 其他圖的風格；每素材像素 = 畫面 2 px），放 `assets/pixel/fx/`，用 Sprite2D 顯示。可以參考 `tools/make_fx_sprites.py` 的做法並把產圖程式加進去或另開一支。**不要用 AI 生圖。**
- 不要畫出判定範圍的大圓框。可以有：圈落地的小彈跳／旋轉、落點的幾顆像素閃光或星點。範圍感由圈本身的位置與命中特效表達就好。
- 查一下有沒有其他也用 ring.tscn 或同樣圓框外觀的融合／進化版本（`data/` 的 item 定義、`tools/add_weapons.gd`），一併處理。
- 注意 `projectile.gd:148` 有 `draw_circle` 畫影子，那個是影子可以保留。

## 限制
- 使用者的 Godot **編輯器正開著這個專案**。直接改 `.tscn` 文字可以，但改完在報告裡列出改了哪些 scene，我會提醒使用者重新載入。
- 我（Claude）同時在改 `scripts/player.gd`、`scenes/player.tscn`（拳頭），你不要動這兩個檔。
- **不要跑 `run_tests.sh` 全套測試**（測試共用 user:// 存檔，同時跑會互相干擾）；測試由我跑。你可以跑：
  - headless 匯入檢查：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/peter/repo/godot/godogen/prototypes/survivor-series --import`
  - 截圖：`/Applications/Godot.app/Contents/MacOS/Godot --path /Users/peter/repo/godot/godogen/prototypes/survivor-series --fixed-fps 60 --resolution 540x960 -s res://tools/fx_demo.gd -- /tmp/codex-fx`（會短暫開視窗，正常）。`tools/fx_demo.gd` 目前沒放套圈圈，請加一個套圈圈落點進去（例如用 `street.arsenal._ring(...)` 或直接 instantiate ring.tscn），讓截圖看得到。
- 自己看截圖判斷好不好看，至少迭代到：煙一眼看得出是濃煙團、畫面上沒有煙與套圈圈的正圓框。

## 驗收條件
1. `smoke.tscn`、`ring.tscn`（及相關變體）沒有 Polygon2D／Line2D 圓形；headless `--import` 沒有新的 ERROR。
2. fx_demo 截圖（a、b、c 三張）裡煙霧明顯比原本濃、範圍清楚但不是圓框；套圈圈是像素圈圖。
3. 玩法數值沒變。

## 回報
完成後把報告寫到 `/Users/peter/repo/godot/godogen/prototypes/survivor-series/.claude-tasks/codex-smoke-ring-report.md`：改了哪些檔（file:line）、新增的素材與產圖指令、截圖路徑、還沒解決或不確定的地方。結論 ≤10 行，不貼大段原文。做不到就直說並停止。
