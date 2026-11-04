# 城鎮路牌技術樣板

2026-11-04 製作、2026-11-05 接入村莊入口；這是驗證既有模型改造與 Godot 匯入的樣板，仍待依選定風格精修。

- **來源**：本機 `model-assets/kenney_survival-kit/Models/GLB format/signpost-single.glb`，Kenney Survival Kit，套件內 `License.txt` 為 CC0，副本保存在 [kenney_survival_kit.txt](../../art_src/licenses/kenney_survival_kit.txt)。原素材庫沒有修改。
- **改造**：以 Blender 5.1.2 匯入複本，合併牌面與立柱、修正交疊，在外露邊緣加單段倒角，按角色比例調整為約寬 0.52、高 1.15、厚 0.11 公尺。沿用原本的色票貼圖，貼圖已嵌入 GLB；沒有生成 AI 貼圖。
- **可編輯來源**：[town_signpost_sample.blend](../../art_src/blender/town_signpost_sample.blend)；[Blender 預覽](../../art_src/blender/town_signpost_sample_preview.png)。
- **Godot 素材**：[town_signpost_sample.glb](../../assets/models/town_signpost_sample.glb)；[可編輯的獨立場景](../../scenes/props/town_signpost_sample.tscn)。Godot 匯入時也將 GLB 色票存為同資料夾的 `town_signpost_sample_colormap.png`，與匯入設定一起保留。場景根節點的 `block_radius` 為 0.2，`Model` 是 GLB 子場景；已放在村莊 `%Props/MeadowSign`，由現有阻擋邏輯讀取。

## 檢查與限制

- Blender 以合併重複頂點後的三角化網格檢查：168 三角面、0 非流形邊、0 零面積面、0 完全重複三角面；排除共頂點鄰面後，BVH 自相交候選為 0。這是自動篩查，不能保證找出所有共面交疊或視覺閃爍；結果見 [JSON](../../production/qa/town-signpost-sample-2026-11-04.json)。
- Godot 4.7 實際讀取 GLB 為 168 三角面且能載入內嵌底色貼圖；scene pack 前後 3 個節點，GLB 子場景關係保留。L1 `bash prototypes/godot-kit/tools/run_tests.sh prototypes/seal-meadow town_signpost_sample` 通過，日誌 `/tmp/godot-tests.LyPFWL`。headless 匯入退出碼為 0，仍有既知的沙箱 TCP 監聽錯誤，沒有腳本解析錯誤。
- 2026-11-05 補測村莊阻擋與 42 度鏡頭的桌面靜態畫面，見[切片規格](../quick-specs/town-slice-2026-11-05.md)；尚未完成移動時的持續閃爍觀察、手機瀏覽器或實機效能。它的底色仍是 Kenney 色票，木紋或法線貼圖等細節留待後續處理。
