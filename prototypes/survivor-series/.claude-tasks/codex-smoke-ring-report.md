第二輪
本輪修改：`assets/fx/smoker_smoke.gdshader:7`、`scenes/smoke.tscn:11`，以及本報告；已驗收的圈圖與套圈圈場景保留。
煙體由六個微動的圓潤 lobe 疊合，依每團局部高度分三階色，上亮下暗；雜訊僅輕微擾動透明輪廓，內部無顆粒與餘燼。
透明度分 0.80／0.50／0.22 三階；主體仍約覆蓋 radius 42，矩形上方增加 20 world px 容納細煙，沒有放大主體判定。
頂部兩縷彎曲細煙隨 progress 上升、變細、淡去；主團慢慢翻滾，末段整體消散，仍維持單一 ColorRect draw call。
煙霧介面、半徑、傷害、壽命與判定均未改；本輪未修改 `scripts/arsenal.gd`、`scripts/street.gd`、kit 或套圈圈素材。
驗證：最終 headless import 與 fx_demo 均 exit 0、無 ERROR；git diff --check 通過；未跑 run_tests.sh。
重拍：`/tmp/codex-fx-a.png`、`/tmp/codex-fx-b.png`、`/tmp/codex-fx-c.png`；5 倍最近鄰放大：`/tmp/codex-smoke-round2-a.png`、`/tmp/codex-smoke-round2-b.png`、`/tmp/codex-smoke-round2-c.png`，已逐圖檢視。
另用 /tmp 的 demo 副本觀察較晚時刻與末段淡出：`/tmp/codex-fx-late-{a,b,c}.png`、`/tmp/codex-smoke-late-zoom-{a,b,c}.png`；未改專案 demo 腳本。
未知阻礙：無；Godot 編輯器請重新載入 `scenes/smoke.tscn` 與 shader。放大後主體呈雲團分層與透光邊緣，細煙較主體淡。
