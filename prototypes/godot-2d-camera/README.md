# Godot 2D Camera

Godot 4.7 橫向卷軸鏡頭的移植指南與調校筆記。營地原型的實作已接入跑跳、台階、視差與區域重疊。 [營地原型](../parallax-camp/README.md) · [開發版鏡頭疊圖](../parallax-camp/captures/camera-zones.png)

## 接到其他專案

將下列檔案從 `prototypes/parallax-camp/` 複製到新專案，維持 `scenes/`、`scripts/` 路徑，並帶上同名的 `.gd.uid`。這些檔案可獨立使用，跟隨目標是 `CharacterBody2D`。

| 檔案 | 用途 |
|---|---|
| [camera_rig.tscn](../parallax-camp/scenes/camera_rig.tscn) | 獨立 rig 場景，內含 `Camera2D` |
| [camera_rig.gd](../parallax-camp/scripts/camera_rig.gd) | 錨點、前視、地圖限位、區域優先權與偏移效果 |
| [camera_zone.gd](../parallax-camp/scripts/camera_zone.gd) | rig 引用的區域設定型別 |
| [camera_zone.tscn](../parallax-camp/scenes/camera_zone.tscn) | 可選用的 `Area2D` 實例，含 `Bounds` 碰撞框 |
| [camera_zone_debug.gd](../parallax-camp/scripts/camera_zone_debug.gd) | 可選用的開發疊圖 |

1. 在關卡的世界座標下實例化 rig。角色與 rig 各有自己的節點，兩者的父節點使用同一座標系。在關卡根節點的 `_ready()` 呼叫 `%CameraRig.follow(%Player)`，並在 Inspector 設 `limits`、`framing_offset`。角色傳送或重生後可呼叫 `reset_to_target()` 對齊錨點。
2. 每個取景區使用一個 zone 實例。將碰撞遮罩對到角色圖層（營地使用 Layer 2），接 `body_entered`／`body_exited`。進出的 body 若是正在追蹤的角色，就呼叫 `push_zone(zone)`／`pop_zone(zone)`。可覆寫前視、跟隨速度、縮放、構圖偏移及邊界，也可用固定目標或鎖定水平。
3. 要開發疊圖，就將 debug 腳本掛在世界原點的 `Node2D`，提供 `rig`、`zones`。HUD 以 `OS.is_debug_build()` 控制 toggle 按鈕可見性，並用 `active_zone_changed` 更新目前取景區。 [營地接線範例](../parallax-camp/scripts/camp.gd)
4. 要接落地效果，在 `move_and_slide()` 前記錄下墜速度，從空中變成著地時送給 `on_landed()`。方向性後座可接 `play_recoil(direction)`。 [角色接地範例](../parallax-camp/scripts/player.gd)

```text
角色物理 → 追蹤錨點與死區 → 前視／下墜視野 → 生效區域
                                                ↓
                                        平滑與限框
                                                ↓
                                        Camera2D 取景
                                                +
                                          offset 效果
```

## 調整方式

| 想改善的畫面 | 優先調整 |
|---|---|
| 角色太貼畫面底部 | 增加 `framing_offset.y`，讓負值向 0 靠近。鏡頭看得更往下，角色在畫面裡會往上。 |
| 改偏移，畫面還是卡住 | 檢查 `limits.end.y`。鏡頭中心最下只能到 `limits.end.y - viewport_height / (2 * zoom)`。往下放寬的範圍要有地面美術。 |
| 只有某段路要不同構圖 | 用 zone 的 `vertical_bias`、縮放、限框或固定目標。一般地標沿用預設跟隨。 |
| 小碎步讓畫面抖動 | `dead_zone_x` 是從錨點到邊緣的半寬。可增加死區、降低前視速度，並檢查 Camera2D 的 smoothing 和 drag 是否關閉。 |
| 障礙太晚進到畫面 | 調 `look_ahead_distance`，再調 `look_ahead_speed`。確認 `look_ahead_commit_speed` 低於有效跑速。 |
| 跳躍拉動畫面，登高後回中太慢 | 讓 `vertical_dead_zone` 高於想穩住畫面的跳躍高度，再調 `ground_recenter_speed`。 |

營地角色的原點在腳底。將 `framing_offset.y` 從 -93 調到 -50 後，腳底在 270 像素高的畫面約落在 y=185，下方多出約 43 像素。舊地圖下限 y=270 會把鏡頭中心卡在 y=135，因此也將下限放寬到 y=320，並延伸高台下方的地面貼圖。角色原點繼續代表腳底的物理位置。

## 踩過的坑

- **一套平滑就夠。** 用 `1.0 - exp(-speed * delta)` 當 `lerp` 權重。固定權重讓幀率改變時收斂速度也跟著變。rig 接手後關閉 Camera2D 的 position smoothing、horizontal drag 和 vertical drag。
- **死區改錨點，取景偏移改構圖。** 角色超過死區邊緣才推動錨點。前視、下墜預視和 zone 修正的是取景目標，最後才讓鏡頭追過去。鏡頭在角色物理更新後讀取 `get_real_velocity()` 與 `is_on_floor()`。
- **短跳、登高、下墜分開測。** 一般跳躍下降但仍在起跳基準上方時維持畫面。越過基準並持續下墜才開始下看，站穩後才進行地面回中。
- **重疊區用最高優先權。** 同優先權以最後進入者為準。離開後回到下一個 zone，生效區未覆寫的欄位取 rig 預設。傳送時留一個物理更新給 Area2D 重算重疊。
- **限位針對整個可視範圍。** 用視口尺寸和當前縮放計算鏡頭中心可移動的範圍。取景移動或縮小倍率後，從地圖兩端、高台靠近處與高台下方檢查美術是否填滿畫面。
- **震動放在 Camera2D.offset。** 依實際接地速度縮放方向性震動，輕落地維持穩定。偏移也要受地圖限位，追蹤錨點一直留在原位。
- **視差跟著取景一起驗收。** 水平平鋪貼圖從子節點 x=0 填滿一格，構圖用 `scroll_offset`。測原有接點和縮小倍率，確認兩層最近景都夠寬。 [Godot 視差教學](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html)
- **鏡頭垂直移動時，同步設定背景和前景。** `scroll_scale.y = 0` 會把該層固定在畫面高度。由遠到近增加垂直倍率，與地面接觸的遮蔽層用 `1.0`。到鏡頭上限確認天空仍填滿上緣，並在不同高度跑過水平接點。

只需要一般死區、前視或切換虛擬鏡頭時，可先評估 Godot Kit 的 Phantom Camera。需要落地回中、下墜預視及逐項 zone 覆寫時，可直接沿用本頁的 rig。 [Godot Kit 的 Phantom Camera 指南](../godot-kit/docs/PHANTOM-CAMERA.md)

## 驗收

- 固定同一個目標，以 60 和 144 個 delta 步進各跑一秒，比較收斂位置。
- 跑完整關卡，測小步微調、反向、跳躍、登高、下墜、傳送、邊界及區域重疊。
- 用開發疊圖核對區域與錨點，再用實際畫面確認腳下留白和視差接點。 [營地測試指令](../parallax-camp/README.md#驗證)
