# Godot Kit 第三方 addon

依目標專案的功能從下表選套件。在 `prototypes/godot-kit/` 執行 `./sync.sh --addon <ID> <原型名稱>`，之後可用 `./sync.sh --check --addon <ID> <原型名稱>` 核對副本。各套件固定上游版本，來源在 `third_party/`。由目標專案產生圖示的 `.import`。

| ID | 套件與版本 | 選用情境 |
|---|---|---|
| `conductor` | Conductor 0.1.4，MIT | 音樂拍點驅動動畫或事件。[接線指南](CONDUCTOR.md) |
| `phantom-camera` | Phantom Camera 0.12，MIT，Godot 4.4+ | 2D／3D 跟隨、死區、群組取景與鏡頭轉場。[接入指南](PHANTOM-CAMERA.md) |
| `debug-draw-3d` | Debug Draw 3D 1.7.3，MIT，Godot 4.4.1+ | 顯示 3D 射線、路徑、碰撞／感知範圍與除錯文字。[Asset Library](https://godotengine.org/asset-library/asset/1766) |
| `raytraced-audio` | Raytraced Audio 1.0，MIT，Godot 4.4+ | 選用。需要牆壁悶音、混響或室內外聲場時再接入。[Asset Library](https://godotengine.org/asset-library/asset/4202) |
| `ambientcg` | AmbientCG 0.1.2（AzPepoze），CC0，Godot 4.4+ | 從編輯器搜尋 PBR 材質及 HDRI，自動產生 Godot 資源。[Asset Library](https://godotengine.org/asset-library/asset/5152) |
| `ambientcg-material-downloader` | AmbientCG Material Downloader（Venit Studios），CC0，Godot 4.4+ | 另一套材質與 HDRI 匯入器。Asset Library 標示 2.0.0，所連快照的 `plugin.cfg` 寫 0.1.0。[Asset Library](https://godotengine.org/asset-library/asset/3657) |
| `sunshine-clouds-2` | Sunshine Clouds 2 2.7，MIT，Godot 4.5+ | 需要可穿行的 3D 體積雲或可繪製雲層時使用。以 Forward+ 驗收。[Asset Library](https://godotengine.org/asset-library/asset/4079) |

## 接入後如何使用

- **Debug Draw 3D** 是原生 GDExtension。複製後重啟編輯器。在需要觀察的 debug 路徑呼叫 `DebugDraw3D.draw_line(origin, hit_position, Color.YELLOW)`。上游發行包有平台與匯出模式對應的二進位。部署前用目標平台驗證擴充載入與打包。
- **Raytraced Audio** 在 Project Settings → Plugins 啟用。將 `RaytracedAudioListener` 放在玩家聽音位置。需要牆壁遮蔽的音源才換成 `RaytracedAudioPlayer3D`。確認音訊 bus layout 裡的 `RaytracedReverb`、`RaytracedAmbient`。此套件以射線加入空間聲效，有 CPU 成本。用實際場景量測效果和效能。
- **AmbientCG 匯入器** 在 Project Settings → Plugins 啟用所選版本，用編輯器的 AmbientCG 介面選擇解析度並下載。材質用產出的 `StandardMaterial3D`，HDRI 用產出的 Environment。生成路徑見 Project Settings 的 `ambientcg/`。兩套都寫入 `res://addons/ambientcg/`，同個專案擇一，切換版本時先停用目前插件，再移除舊 addon 資料夾後重新同步。
- **Sunshine Clouds 2** 在 Project Settings → Plugins 啟用。場景加入 `SunshineCloudsDriverGD`、`WorldEnvironment` 與方向光，從 Driver 產生雲資源並加入 Tracked Directional Lights。需要支援的 GPU 和 RenderingDevice，採 GL Compatibility／Web 的專案用其他雲方案。手機先以實機量測採樣設定和渲染成本。

## 上游快照

- [Debug Draw 3D 1.7.3 release](https://github.com/DmitriySalnikov/godot_debug_draw_3d/releases/tag/1.7.3) 的 addon 與各平台編譯檔。
- [Raytraced Audio 895a33f](https://github.com/WhoStoleMyCoffee/raytraced-audio/tree/895a33fbf3c53b64bc63f20103eea3402b626262/addons/raytraced_audio)。
- [AzPepoze AmbientCG v0.1.2 release](https://github.com/AzPepoze/godot-ambientcg/releases/tag/v0.1.2)。
- [Venit Studios AmbientCG 3ed2ef0](https://github.com/VenitStudios/AmbientCG/tree/3ed2ef04137aaf9a9d6c866493d0ece9ffb5bc3e/addons/ambientcg)。
- [Sunshine Clouds 2 e4ecc2d](https://github.com/Bonkahe/SunshineClouds2/tree/e4ecc2da53f0b675f5998a08eb7225fb83712054/addons/SunshineClouds2)。範例遮罩放進 addon 目錄，範例 `.tres` 隨之調整路徑。上游的示範程式執行檔放在上游下載。

各套件的授權檔在 `third_party/<ID>/LICENSE`。AmbientCG 的下載素材另見 [ambientCG 授權](https://docs.ambientcg.com/license/)。
