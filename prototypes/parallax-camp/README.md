# 森林營地 · Parallax Camp

**Ridge Run** 是跑跳試驗道。從平地出發，跳過短缺口、登上階梯，途中有檢查點，最後用二段跳越過高台並跑到終點旗。原森林營地與試驗道共用新版旅人。 [跑跳實機截圖](captures/ridge-run.png)

六層視差、隨距離改變的入夜速度、只照亮營地平面的暖光，能讓一張像素地圖呈現景深與夜晚氣氛。原型有一條五個畫面寬（2,400 像素）的林道、三個營地互動，以及約 60 秒的日夜循環。開場在帳篷和營火之間。

```text
西端林道 ── 營地 ── 煮飯架 ── 林間台階 ── 高台 ── 東端林道
                                        二段跳 ↑
```

## 執行與操作

在本目錄用 Godot 4.7 開啟 `project.godot`，匯入後按 F5 進 Ridge Run。要玩森林營地，開啟 `scenes/camp.tscn` 再按 F6。命令列可用 `godot --path .`，加上 `res://scenes/camp.tscn` 可直接開營地。兩個場景都用 GL Compatibility、480×270 邏輯畫布、Nearest 取樣與整數縮放，預設視窗 960×540。

| 操作 | 效果 |
|---|---|
| A／D 或 ←／→ | 沿林道跑步 |
| Space 或 W | 起跳。空中再按一次可二段跳，落地後恢復；在 Ridge Run 短按可小跳 |
| R | 在 Ridge Run 回起點重跑，跌落則自動回最近檢查點 |
| E | 營地限定。靠近並出現提示時，加柴、查看三件道具或煮飯 |
| T | 營地限定。快轉日夜 |
| Camera zones（開發版左下角） | 顯示或收起鏡頭區域、死區、追蹤錨點與目前生效的區域 |

營火加柴後亮度逐漸回落。道具面板可用 E 收起，離開道具架也會收起。煮飯會短暫冒煙並播放音效。

## 角色分件

旅人站立約 40 像素高，採 64×64 圖格與共用腳底錨點。待機四格保留輕微呼吸，跑步用左右各 20 格。起跳第一刻用上升姿勢，垂直速度接近零時換到頂，再切下落。空中二段跳會直接回上升，落地依移動切回待機或跑步。

跑步曾出現腳底往前滑。舊版全速每格前進約 12.5 像素，著地腳在貼圖裡退得更少。現在讀 `move_and_slide()` 的實際水平位移，每 2 像素取一格，踩地腳同步往回畫 2 像素，再補償影格之間不足 2 像素的位移。加速、煞車與反向時，步頻會跟著實際跑速。 [Footskate Cleanup 研究](https://research.cs.wisc.edu/graphics/Papers/Gleicher/Mocap/cleanup.pdf)

[分層 OpenRaster 原稿](art/traveler/traveler.ora) 可在支援 OpenRaster 的像素／影像編輯器打開。八層分開頭髮與頭部、圍巾、背包、外套、前後手臂、前後褲腿與靴子。 [LPC 分件做法](https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/) · [OpenRaster 格式](https://www.openraster.org/)

遊戲使用 [角色圖集](art/traveler/traveler.png)。前五列是 40 格奔跑，最後一列是四格待機與上升、到頂、下落。要修改分件輪廓或關節座標，編輯 [繪圖程式](tools/draw_traveler.py)，在專案目錄執行 `python3 tools/draw_traveler.py` 會重出圖集與分層原稿。直接畫在 OpenRaster 原稿上時，從編輯器輸出合併 PNG 到相同路徑。

## 編輯場景

| 場景 | 可調整項目 |
|---|---|
| [ridge_run.tscn](scenes/ridge_run.tscn) | 試驗道平台、旗幟、出生點、鏡頭邊界。場景內 Player 實例有加速、煞車、小跳、離地寬限與跳躍緩衝設定 |
| [trail_platform.tscn](scenes/trail_platform.tscn) | `Surface` 的區域裁切和 `CollisionShape2D` 的尺寸。懸空平台可開 one-way collision |
| [camp.tscn](scenes/camp.tscn) | `cycle_seconds`、各層 `scroll_scale`／`scroll_offset`、`CampPlane/Ground` 地表、`CampPlane/Terrain` 碰撞、`FireLight` 光色與範圍、`StokeTimer` 時長、`Hud/Overlay` 控制提示文字及樣式 |
| [player.tscn](scenes/player.tscn) | `run_speed`、`jump_speed`、`air_jump_speed`、`gravity`、`GroundRay` 長度、`Shadow` 外觀 |
| [interaction_point.tscn](scenes/interaction_point.tscn) | 每個實例的 `prompt_text`、`Reach` 碰撞尺寸、`Prompt` 樣式與位置 |
| [street_lamp.tscn](scenes/street_lamp.tscn) | 燈具 `Art`、`Light` 光色與範圍。由營地主場景控制日夜亮度 |
| [camera_rig.tscn](scenes/camera_rig.tscn) | 取景偏移、跟隨速度、水平／垂直死區、前視、落地回中、世界邊界、落地震動 |
| [camera_zone.tscn](scenes/camera_zone.tscn) | 在主場景 `CameraZones` 選取實例，調整優先權與各項覆寫；展開 `Bounds` 可調觸發範圍 |

背景與角色引用現有正式素材。營火與路燈共用營地平面的燈光位元，各視差層有自己的位元。 [美術報告](art/final/REPORT.md) · [Godot Light2D 文件](https://docs.godotengine.org/en/stable/classes/class_light2d.html)

## 鏡頭取景

獨立 rig 用 `1.0 - exp(-speed * delta)` 平滑取景。微調留在水平死區內時畫面保持穩定，持續奔跑推過死區後才慢慢帶出前方。一般跳躍留在垂直死區內，落地後才回到目前地面的構圖，離開高台下墜時則往下預留空間。重落地的震動走 `Camera2D.offset`，方向性後座也有可接的 `play_recoil()`。

營地和帳篷使用預設跟隨構圖。開場腳底約在畫面 y=185。要調整角色在畫面中的高度，改 `framing_offset.y` 與鏡頭下限。 [共用移植與調校指南](../godot-2d-camera/README.md)

鏡頭上下移動時，天空到最近背景的垂直視差逐層從 0.15 增至 0.85。兩側遮蔽樹的垂直倍率為 1.0，樹根與地面同速移動。天空預留上緣畫面，鏡頭升到上限仍會填滿視口。

| Zone | 目前設定 |
|---|---|
| EastTrail | 加長前視，提高跟隨速度 |
| Ridge | 往上取景，縮短前視。與 EastTrail 重疊時優先 |

每次由最高優先權的 zone 套用個別覆寫。其餘欄位沿用 rig 預設。可調縮放、限框、水平鎖定、固定目標、前視與跟隨速度。開發版疊圖用金色標示生效的 zone，綠框代表死區。 [鏡頭疊圖](captures/camera-zones.png)

## 驗證

從本目錄執行。

```bash
godot --headless --import
godot --headless --quit-after 12
godot --headless --fixed-fps 60 --script res://tests/test_camp.gd
godot --headless --fixed-fps 144 --script res://tests/test_camp.gd
godot --headless --fixed-fps 60 --script res://tests/test_ridge_run.gd
xvfb-run -a godot --audio-driver Dummy --fixed-fps 60 --script res://tests/test_ridge_run.gd -- --capture
xvfb-run -a godot --audio-driver Dummy --script res://tests/capture_camp.gd
```

L2 測試用鍵盤事件驗證跑速、跳躍次數、翻越高台往返、三個互動、日夜循環、陰影、燈光遮罩及兩端遮蔽。離屏擷取檢查近景在煮飯架前後及其餘取樣位置的像素覆蓋，也驗證營火的燈光範圍。 [白天](captures/day.png) · [深夜](captures/night.png) · [東側林道](captures/trail.png)

跑跳手感待真人試玩。音效使用 Godot Kit 合成佔位，自動驗證涵蓋音效事件及音源。
