# Godot 共用特效庫

Godot 4.7，無 autoload、外部套件或 class_name。這批是使用者明確要求的共用模組；目前尚無遊戲採用。以 `godot-kit/sync.sh <專案>` 複製，維護來源在 kit，遊戲中的副本不直接修改。

## 目前可用內容

| 場景 | 內容／可編輯項目 |
|---|---|
| `2d/sheet_effect.tscn` | AnimatedSprite2D：SpriteFrames、animation、offset、scale、modulate、speed_scale、play_on_ready、free_on_finish |
| `3d/sheet_effect.tscn` | AnimatedSprite3D：同一份 SpriteFrames、pixel_size（公尺／像素）、billboard、offset、shaded、速度與生命週期 |
| `2d/pixel_effects.tscn` | repo 原有 burst／ring／slash／star／explosion／smoke／gas，API 見 `../pixel_vfx.gd`；pixel、配色與數量上限在 Inspector 調整 |
| `3d/pixel_burst.tscn` | repo 原有立體碎片／落石／橫掃與地面衝擊波；Chunks 是 MultiMesh，Rings 有 12 個可調整的 PlaneMesh；max_chunks、gravity、m_per_px、auto_step 在 Inspector 調整 |
| `preview_2d.tscn` | 可編輯位置、標題、Timer 間隔；F6 顯示原生爆炸與圖集動畫 |
| `preview_3d.tscn` | 可編輯相機、地板、圖卡位置、Timer 間隔；F6 顯示立體碎片、地面環與 billboard 圖集 |

`demo_ring.tres` 是本次以簡單圓環公式製作的校準動畫，方便在編輯器看到代表性物件。不是網站下載素材，也沒有使用 AI 生圖。

已接入使用者提供的 **41 組 Scenario**（各有 2D／3D 場景），另完成 **全部 46 種 00GameDevs 原生效果**，涵蓋投射物、爆炸、光束、法陣、煙霧、草、拖影與後製；[使用與精度說明](../../../docs/vfx/THREE-PORTS.md)，詳見 [來源接入狀態](../../../docs/vfx/SOURCES.md)。[網頁展示頁](../../../showcase/README.md) 提供 Sprite 圖集檢視與真正的 Godot Web 預覽。

## 已接入素材目錄

- `2d/scenario/<id>.tscn`、`3d/scenario/<id>.tscn`：41 組可直接拖入的場景；frame 留代表性預覽，執行自動從第 0 幀開始。pivot 已存進 offset。
- `3d/00gamedevs/<id>.tscn`：46 種原生效果；42 種程序幾何＋原 GLSL、動態武器拖影與 CanvasLayer 後製，另有下列預警。持續型支援 stop／reset，投射物支援 hit，光束支援 set_endpoints。
- `3d/00gamedevs/spell-indicator-circle.tscn`／`spell-indicator-sector.tscn`：原生範圍預警，可調 radius、angle_degrees、warning_duration、color；auto_step=false 時由遊戲時鐘 step(dt)，manual_progress=true 時 set_progress(value)。
- `gallery_2d.tscn`／`gallery_3d.tscn`／`showcase.tscn`：可編輯的選擇、說明、重播與 SubViewport 版面，按 F6 試播。

```gdscript
const Vfx = preload("res://addons/proto_kit/vfx/library.gd")

func show_explosion(at: Vector3) -> void:
    var effect = Vfx.get_scene("cinder-explosion", "3d").instantiate()
    effect.position = at # 相對於父 node
    add_child(effect)
```

使用單一素材時可直接 preload 它的 .tscn；library.gd 會帶入整個可用目錄。未知 ID／不支援的維度回傳 null。來源 metadata 的 placement／depth_hint 不會自行修改遊戲圖層、座標或碰撞規則。

## 不同專案取用

在 repo 根目錄：

```bash
bash prototypes/godot-kit/sync.sh <原型資料夾名或外部專案絕對路徑>
```

同步會更新整份 kit，先確認目標 `addons/proto_kit` 沒有要保留的手改。也可以只複製所需檔案；圖集播放只需要 `vfx/2d`／`vfx/3d/sheet_effect.*` 與自己的 SpriteFrames，原生特效另依賴 kit 原有 `pixel_vfx*` 檔案。未批次同步現有遊戲。

先將對應 `.tscn` 拖進主 scene，在 Inspector 替換 SpriteFrames。預設 demo 為循環；遊戲一次性素材須將動畫的 Loop 關閉。播放完成發出 `finished` 後自動刪除。循環特效由遊戲在狀態結束時 `queue_free()`；若要重用，設 `free_on_finish = false` 後自行 `play()`。隨 SceneTree 暫停與時間縮放，無獨立牆上時鐘。

依事件產生一次性動畫（不要在每次播放時修改共用 SpriteFrames）：

```gdscript
const HitScene = preload("res://addons/proto_kit/vfx/2d/sheet_effect.tscn")
const HitFrames = preload("res://assets/vfx/hit.tres")

func show_hit(at: Vector2) -> void:
    var fx = HitScene.instantiate()
    fx.sprite_frames = HitFrames
    fx.position = at # 相對於掛入的父 node
    add_child(fx)
```

3D 以 `3d/sheet_effect.tscn` 和 Vector3 取代；這是平面圖卡，不是體積粒子。真的有深度的效果用 `3d/pixel_burst.tscn`：

```gdscript
# $PixelBurst3D 為 scene 中已放好的實例，座標是世界座標。
$PixelBurst3D.burst(global_position, 24, &"gold")
$PixelBurst3D.ring(global_position, 2.0, &"cyan")
```

原生 3D 碎片會落在 y=0，ring 也固定在 y=0.03，適用平地；有高度差的地形需先擴充接地規則。預設每幀自動 step；使用遊戲自有時鐘時設 `auto_step=false`，每幀只呼叫一次 `step(game_delta)`。碎片有數量上限、環有 12 個槽，滿了就略過；圖集實例的同場數量由呼叫端限制。

## 外部 PNG 圖集匯入

Scenario 網頁有 `Effect only` 和 `Game-ready pack`，後者包含 Godot SpriteFrames。優先使用上游 pack 的 SpriteFrames 與貼圖，保留相對路徑與 atlas／recipe，先用 Godot 匯入並檢查 texture 引用，再交給上述場景播放。本次已驗證使用者解壓後提供的 41 組檔案，修正貼圖引用並保留原動畫名稱；原始 ZIP 本體未驗證。

只有 PNG 時，本工具支援**等寬、單排、無間距／裁切**的 strip；JSON atlas 的多排、不等長幀、trim、pivot、impact frame 不會自動解析。若素材需要它們，使用上游 SpriteFrames，或在編輯器依 atlas 設定，不要猜格數與錨點。

將 PNG 放到專案 `assets/vfx/`，在 **kit 根目錄** 執行（工具也可以複製到遊戲 `tools/vfx/`，同時帶入 `sheet_frames.gd`）：

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tools/vfx/import_strip.gd -- \
  res://assets/vfx/fire.png res://assets/vfx/fire.tres 18 15 once \
  'https://www.scenario.com/explorations/pixel-vfx-forge/' 'unverified'
```

`18 15 once` 僅為參數範例，依該素材實際幀數／fps 修改；循環用 `loop`。不覆寫既有 `.tres` 或來源紀錄。輸出 `.source.json` 保存來源、授權備註、PNG SHA-256、幀數、fps 與循環；`unverified` 是待核對狀態，不代表授權。正式收錄時保留授權條款證據。不要把含角色／背景的宣傳動畫當透明特效。

## 驗證與維護

```bash
# kit 根目錄；L2：新模組測試 + 真實 preview scene 冒煙
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_vfx.gd
godot --headless --path . --script res://tests/test_vfx_library.gd
godot --headless --path . --script res://tests/test_three_ports.gd
# 互動外觀驗收：Godot 編輯器開啟 preview_2d.tscn / preview_3d.tscn，F6
```

測試涵蓋切格的實際像素、非法尺寸／fps、2D／3D 一次性／循環／手動播放、完成 signal／清理、獨立 MultiMesh、原生 3D 過期回收、preview 場景與編輯位置保留、執行不回寫來源。測試不下載素材。

`tools/vfx/build_scenes.gd` 是已套用的製作工具；存在的輸出一律略過。正常匯入、測試與遊戲不會呼叫它。scene 已由 Godot PackedScene 儲存並重載比對 node 數與子 scene 引用；後續直接在編輯器維護，不靠重建來覆蓋手改。
