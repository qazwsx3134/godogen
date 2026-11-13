# Phido 模型減面

`base_basic_pbr_optimized.glb` 是 `D:\repo\godot\model-assets\phido\base_basic_pbr.glb` 的減面副本。原檔未修改；模型保持原比例、地面原點、單一網格與 PBR 材質，沒有骨架或動畫。本機也另存到原資料夾的 `base_basic_pbr_optimized.glb`。

| | 原始 | 減面副本 |
|---|---:|---:|
| 三角面 | 930,148 | 279,044（減少 70.0%） |
| 檔案大小 | 39,075,460 bytes | 14,695,712 bytes（減少 62.4%） |
| 貼圖 | 3 張 2048 × 2048 | 3 張 1024 × 1024 |

貼圖為 albedo、normal 和 metallic/roughness，均嵌入 GLB。兩張同機位的 Blender PBR 圖：[原始](phido_original_pbr.png)、[減面](phido_optimized_pbr.png)。結果仍有約 28 萬三角面，是否適合大量同屏需要依實際遊戲及目標裝置量測。

## 驗證

2026-11-13：Blender MCP 先比較 15%、30%、45% 幾何保留比例，15% 的裝甲陰影折痕明顯，選用 30%。原始／減面兩方向各隨機取 12,000 個頂點量最近表面距離，p99 分別 0.143／0.137 mm；此為抽樣，不是完整最大誤差保證。

Godot 4.7 headless 在臨時專案匯入原始與減面 GLB，確認各一個 mesh／surface、頂點與法線／UV 數量一致、三張 PBR 貼圖及解析度正確、模型尺寸差小於 5 mm；兩者皆載入成功。沒有測手機效能或實際遊戲畫面。沙箱中的 Godot editor 建立偵錯監聽埠時有 socket 權限錯誤，匯入及獨立驗證腳本退出碼均為 0。

## 低面數重新建模

另有依原始輪廓重新建立的 [2,904 面版本](lowpoly/README.md)，包含可編輯 `.blend`、單網格 GLB 和前後對照圖。該版使用簡化色盤，沒有原始貼圖的細節。

2026-11-14 再完成 [2,940 面細化版](lowpoly_v2/README.md)，補上側甲框線、前板接縫及腳底造型；2,904 面版本保留。
