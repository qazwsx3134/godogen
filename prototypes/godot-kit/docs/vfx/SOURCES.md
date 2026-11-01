# 外部特效接入（2026-11-01）

使用者已提供 repo 根目錄 `vfx-example/`：41 組 Scenario 匯出包、46 份 00GameDevs Three.js。原檔保留。最初網站下載遇到 DNS／網頁工具限制，本次改由本機檔案接入；沒有宣稱本 session 自行下載成功。

| 來源 | 已取得／授權證據 | Godot 狀態 |
|---|---|---|
| [Scenario Pixel VFX Forge](https://www.scenario.com/explorations/pixel-vfx-forge/) | 41 組 PNG／SpriteFrames／atlas／recipe／README；每份 README 明載可用於商用與非商用專案，已逐份保存 | 41 組 2D＋41 組 3D billboard，全部已測試 |
| [00GameDevs](https://00gamedevs.com/zh-TW/) | 46 份 JS，每份內嵌匯出程式 MIT 與 Three.js MIT 通知；共用通知保留於 `vfx/licenses/00gamedevs-MIT.txt` | **46 份均已原生移植**；42 種幾何／GLSL、武器拖影、全畫面打擊與兩個預警，清單見 `vfx/three_sources.json` |

## Scenario 轉換

程式來源 `tools/vfx/import_examples.py`：驗證檔案、授權字句、PNG header、atlas 範圍／trim／旋轉與幀數／速度／循環。只複製 runtime PNG、原始 atlas／recipe／README；原始 GIF 與單幀仍留在 `vfx-example`。PNG 不縮放、不去背、不重編碼。

上游 `.tres` 使用 `res://<效果>.png`，修成 kit 中的實際路徑。SpriteFrames 動畫名稱、幀序、fps、loop 不變。`assets/scenario/index.json` 保存所有上游原檔 SHA-256，scene 另保存 placement／depth_hint metadata。

`tools/vfx/build_library.gd` 以 Godot pack／save／reload 製作場景；一個效果各有 2D／3D scene，與共用 script、SpriteFrames、貼圖形成實際依賴。因保存的是獨立根 scene，子物件引用驗證不要求不存在的「根繼承 instance」。後續以編輯器維護，不自動重建、不覆寫已存在 scene。

Pivot：Sprite2D 的 offset=(0.5-pivot)×frame_size；Sprite3D 的 Y offset=(pivot.y-0.5)×height。已用 Godot `generate_triangle_mesh()` 驗證 3D 實際底邊與左邊，不只比對數值公式。`place`／`depth` 是接入提示，遊戲自行選父節點、圖層、方向與施法／命中位置。

使用者另提供 `tools/vfx/pixle_vfx_forge.md` 的 Static Impact recipe，尚未執行渲染、不計入上述 41 組。bundled Scenario renderer 未複製進可分發模組／網站，其程式授權不由幀素材 README 推論。

## 00GameDevs 轉換

`3d/00gamedevs/spell_indicator.gd` 與 `spatial_spell_indicator.gdshader` 保留原警示區域方程、+Y up／XZ ground／+X 扇形中心、HSL edge 色彩、2 秒自動蓄滿、完成 0.15 秒（flash 0.06＋fade 0.09）與取消 0.12 秒。支援 manual_progress／set_progress、auto_step／step、reset／stop、每個實例獨立材質。shader 為 Compatibility spatial，沒有使用外部貼圖。

本輪其餘 44 份也已完成原生 scene；42 種程序效果保留原幾何、GLSL 方程、自訂屬性與 30 Hz JS 動畫通道，另為武器拖影與全畫面後製實作專用控制器。包括矩陣／varying 介面、三角形 CW 換序、混色、剔除、深度寫入、draw range、時間與停止別名，均有處理；不以 generic 近似效果替代原方程。

原始碼、預設參數與 SHA-256 均保留。程式／資源與數值測試已完成，**GPU／瀏覽器外觀仍待驗收**。Three authoring 使用本機 cache 的 0.185.1，原檔標示 target 0.187.0；30 Hz 通道、固定 variation、transmission screen capture 與原生動態參數介面的範圍，詳見 [完整移植說明](THREE-PORTS.md)。

## 共用取用與預覽

- `vfx/library.gd` 的 get_scene(id, "2d"／"3d") 回傳已驗證可用的 PackedScene；preload 讓依賴也能進 selected-scene 匯出。3D 共 87 種（46 原生＋41 billboard），未知 ID 不會回傳假場景。
- `vfx/gallery_2d.tscn`／`gallery_3d.tscn` 在編輯器可見版面與代表性效果，可 F6；`vfx/showcase.tscn` 組成兩個分頁。
- HTML Sprite 檢視器與真正的 Godot Web 匯出見 [網頁展示頁](../../showcase/README.md)。測試證據見 [VALIDATION](VALIDATION.md)。
- 沿用 kit `sync.sh <指定專案>` 複製，未批次更新既有遊戲。Godot 3D圖集是 billboard 平面；原生體積碎片仍可用上一輪 `3d/pixel_burst.tscn`。
