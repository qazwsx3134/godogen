# 3D 遊戲打磨流程（Godot 4.7，Forward+）

讓原型從「灰盒」變成「像遊戲」的一輪固定流程。照順序做，每做一項就看畫面、看 FPS。
所有示範都在 `addons/proto_kit/polish3d/demo.tscn`（產生器 `tools/build_polish3d_demo.gd`，存好後直接在編輯器改）。
SDFGI、SSIL、景深只在 **Forward+** 有效；kit 專案本身是 Compatibility，看示範要用 `--rendering-method forward_plus` 或在自己的 Forward+ 專案打開。

```
光（1 太陽）→ 天（2 天空雲＋環境光）→ 曝光（3 AgX）→ 陰影細節（4 SSAO＋SSIL）
→ 反彈光（5 SDFGI）→ 空氣（6 霧）→ 植物（7 樹葉、8 草與地面、9 大量草）
→ 角色可讀性（10 補光）→ 鏡頭（11 FOV、景深）→ 邊緣（12 AA）→ 質感（13 後製、灰塵）
→ 量測（14 FPS，逐項關掉找最貴的）
```

| # | 項目 | 設定值 | 設在哪 |
|---|---|---|---|
| 1 | 太陽 | 斜射（例 x −38°、y −35°）讓物件有明暗面；偏暖 `light_color (1, .92, .8)`；`shadow_enabled`、`light_angular_distance 1.1`（柔邊）、`directional_shadow_max_distance 60` | DirectionalLight3D |
| 1 | 陰影品質 | `rendering/lights_and_shadows/directional_shadow/size 8192`、`soft_shadow_filter_quality` = High（4） | 專案設定；最貴的一項，見 14 |
| 2 | 天空與雲 | `polish3d/sky.gdshader`：漸層＋太陽圓盤＋noise 雲（`cloud_cover`、`cloud_speed`）。ProceduralSkyMaterial 沒有雲 | Environment.sky |
| 2 | 環境光 | `ambient_light_source = SKY`，energy 1.0 | Environment |
| 3 | 色調 | `tonemap_mode = AGX`、`tonemap_exposure 1.12`、`tonemap_agx_contrast 1.32`（受光面更亮、暗部更沉） | Environment |
| 4 | AO | `ssao_radius 1.4`、`ssao_intensity 2.4`；`ssil_enabled`、`ssil_radius 6.0` | Environment |
| 5 | 反彈光 | `sdfgi_enabled`、`sdfgi_energy 1.3`（鏡頭附近的間接光） | Environment |
| 6 | 霧 | `fog_density 0.0016`、`fog_aerial_perspective 0.5`；地面薄霧 `fog_height`≈0.6、`fog_height_density` 0.035（濃）～0.007（淡） | Environment |
| 7 | 樹葉 | `polish3d/foliage.gdshader`：`NORMAL` 從樹冠中心往外（`canopy_center`，模型空間），整團像一顆受光的球；越高擺越多的 sway；`BACKLIGHT` 逆光透光 | 樹冠材質 |
| 8 | 草 | `polish3d/grass.gdshader`：頂點色 R＝高度（根 0、尖 1），根暗尖亮；`bend × R²`＋移動的 noise 貼圖，根不動尖端彎 | 草材質 |
| 8 | 地面 | `polish3d/ground.gdshader`：兩種綠用 noise 混；mask 貼圖 **R＝踩禿泥土**、**G＝樹下** | 地面材質 |
| 9 | 大量草 | `polish3d/grass_field.gd`：22000 根＝MultiMeshInstance3D 分 17×17＝289 chunk（不是 22000 個 node）；每 chunk `visibility_range_end 65`、`cast_shadow off`；chunk 色差放 MultiMesh custom data | Node3D 掛腳本，勾 `rebuild` |
| 10 | 角色補光 | OmniLight3D energy 0.7，`light_cull_mask` 只含角色的層（角色 `layers` 加那一層），只照亮角色；場景另加燈籠／窗戶等暖色 local light | OmniLight3D |
| 11 | 鏡頭 | FOV 75 → 55；`CameraAttributesPractical.dof_blur_far_enabled`（遠景模糊） | Camera3D／WorldEnvironment.camera_attributes |
| 12 | 抗鋸齒 | `rendering/anti_aliasing/quality/msaa_3d` = 2x、`use_taa = true` | 專案設定 |
| 13 | 後製 | `polish3d/post.gdshader`：`vignette 0.3`、`grain 0.014`，CanvasLayer 裡全螢幕 ColorRect（mouse_filter IGNORE）；GPUParticles3D 灰塵（小、慢、半透明、billboard） | CanvasLayer |
| 14 | 量測 | `polish3d/perf_hud.gd`：FPS、ms、draw calls、三角形數；F1–F9 逐項開關（陰影、SSAO、SSIL、SDFGI、霧、草、MSAA、TAA、後製），F10 隱藏 | 掛在場景下的 CanvasLayer |

## 14：怎麼找最花效能的

1. 在目標裝置上跑，HUD 記下 FPS／ms。
2. 一次關一項（F1–F9），記下 ms 下降多少，最大的先調。通常的順序：太陽陰影 ＞ SDFGI ＞ SSIL ＞ 草 ＞ SSAO ＞ MSAA。
3. 調低而不是直接關：
   - 太陽：shadow atlas 8192 → 4096／2048、soft shadow High → Low、`directional_shadow_max_distance` 60 → 40、`light_angular_distance` 調小。
   - 草：`total` 減少、`visibility_end` 65 → 40、`chunks_per_side` 調整（chunk 太小 draw call 多，太大剔除不掉）。
   - AA：MSAA 2x＋TAA → 只留 TAA，或改 FXAA。
   - SDFGI：`sdfgi_cascades` 減少、或改用烘焙的 LightmapGI／VoxelGI。
4. 改完回到第 1 步確認，畫面差異截圖比對。

## 坑

- 幾百個 MultiMeshInstance3D 都設 `instance uniform` 會出現 `Too many instances using shader instance variables`（全域緩衝 4096）→ chunk 色差改放 MultiMesh `use_custom_data`／`INSTANCE_CUSTOM`。
- MultiMesh 的 `use_colors` 會乘進 `COLOR`，會破壞「頂點色 R＝高度」，所以不用它。
- headless 存 MultiMesh 會遺失 buffer → 產生器用 `xvfb-run -a godot --path . -s …`（不加 `--headless`）。
