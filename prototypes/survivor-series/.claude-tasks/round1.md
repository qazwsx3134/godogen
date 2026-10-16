結論：完成煙霧與套圈圈外觀調整，玩法數值未變。
煙霧：`scenes/smoke.tscn:3-35` 移除圓形節點；`scripts/smoke.gd:2-23` 保留 lifetime/radius/damage/step；新 shader：`assets/fx/smoker_smoke.gdshader:1-46`。
套圈圈：`scenes/ring.tscn:3-19` 改用 Sprite2D；`assets/pixel/fx/ring.png`（43×24）；生成器 `tools/make_fx_sprites.py:53-104`、`tools/add_weapons.gd:72-80`。
融合「珍珠圈」在 `data/items/pearl_ring.tres:3` 共用 `ring.tscn`，已同步換圖；沒有其他套圈圈場景變體。
`arsenal.gd`、`projectile.gd`、兩個 item 定義與煙霧數值未改；`projectile.gd:148` 的影子保留。
產圖：`UV_CACHE_DIR=/tmp/codex-smoke-ring-uv uv run --no-project --with pillow python tools/make_fx_sprites.py`（新增 ring.png；Godot 產生 `.import`／shader `.uid`）。
驗證：headless `--import` 成功、無 ERROR；fx_demo 成功、無退出警告；兩個目標 scene 無 Polygon2D／Line2D；未跑 `run_tests.sh`。
截圖：`/tmp/codex-fx-a.png`、`/tmp/codex-fx-b.png`、`/tmp/codex-fx-c.png`，三張均可見濃煙與像素圈。
編輯器重新載入 `scenes/smoke.tscn`、`scenes/ring.tscn`；未解決：demo 保留既有藍色踢擊特效圈（非套圈圈）；並行的 player 檔案改動未碰。
