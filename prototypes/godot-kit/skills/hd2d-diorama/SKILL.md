---
name: hd2d-diorama
description: Godot 4.7 的 HD-2D／2.5D 立體透視模型場景（八方旅人、仙境傳說 RO 式：像素角色與像素圖卡站在打光的 3D 場景裡）怎麼用 godot-kit 組起來：圖層順序、全遊戲共用一個像素密度、像素角色不受光照改用 sprite_light 染色、霧與景深的外觀預設、固定鏡頭的運鏡、地面預警標示、3D 像素特效，以及放置遊戲的橫向捲軸（行軍畫面）。模組是 hd2d_stage、hd2d_look、pixel_card3d、shot_camera、ground_decal、pixel_vfx3d、march_strip、parallax_layer，加上 sprite3d（角色）。要開新的 HD-2D／2.5D 遊戲、做舞台與道具、調外觀、加運鏡或預警，或做放置遊戲的行軍／遠征橫向畫面時先讀。
---

# HD-2D 場景（diorama）

程式在 godot-kit（godogen repo 的 `prototypes/godot-kit/addons/proto_kit/`），用 `godot-kit/sync.sh <遊戲>` 帶進遊戲。角色圖的規格（billboard、方向、圖集、MultiMesh）在 skill `sprite-actors-3d`，像素特效的規則在 skill `pixel-vfx`；這份講怎麼把它們組成一個場景。

來源：hero-horde-idle（全員推王，直式放置推王）2026-10-23 抽出，原型已改用，改用前後 22 張固定種子截圖逐位元組相同。完整參考實作就是那款：`scenes/stage.tscn`（舞台）、`scenes/main.tscn`（戰場）、`scenes/march_view.tscn`（行軍捲軸），產生器是它的 `tools/build_stage.gd`、`tools/build_fx.gd`、`tools/build_shell.gd`。

## 何時用

- 固定或少量移動的鏡頭看一個場景：放置推王、戰棋、Boss 競技場、城鎮、RO 式地圖。
- 角色是像素圖，場景要有光影、霧、景深、立體感。
- 放置遊戲需要「隊伍自己往前走、遇怪、打、繼續走」的橫向小畫面。

**不要用在**：跟隨玩家跑的存活類鏡頭（madara-survivor、luffy-marineford 各有自己的 `camera_rig.gd`，還沒抽進 kit）、純 2D 遊戲。

## 先定的三件事

1. **一個像素密度**：`m_per_px`（素材的一個像素在世界裡幾公尺）。地面貼圖、道具圖卡、角色格、特效碎塊、預警的格子全部用同一個值，畫面才是同一張像素網格。hero-horde-idle 用 0.025（角色 48 px 格約 1.2 m）。所有 kit 模組都有這個參數，預設 0.025。
2. **鏡頭構圖**：俯角、FOV、離場地多遠。存在 scene 的 Camera3D 上，`shot_camera.gd` 只在事件時暫時移開再回來。道具圖卡往鏡頭仰的角度（`lean_deg` 預設 14°）配合這個俯角，畫在約 45° 俯視的圖才不會被壓扁。
3. **渲染器**：Mobile（手機）或 Forward+。Compatibility 沒有景深，畫面會比較銳利、不像 HD-2D。

## 圖層（由後到前）

```
 WorldEnvironment（hd2d_look：線性色調、輝光、深度霧、微調亮度對比飽和）＋景深（遠景模糊）
   └ 太陽 DirectionalLight3D（%Sun，有陰影）＋點光（火把放在 %FlickerLights 底下會閃）
 地面（自己的 shader：貼圖、區域混合；每款不同，不共用）
 背景懸崖、遠景（大張圖卡或 mesh，被霧吃掉）
 道具 pixel_card3d（樹、石、柱子；投影）
 地面標示 ground_decal（預警、選取圈）→ 衝擊環 pixel_vfx3d ring（畫在預警底下）
 角色 sprite3d（大量用 MultiMesh；少量用 sprite3d_actor）→ 碎塊 pixel_vfx3d burst
 暈影 CanvasLayer（hd2d_vignette）
 HUD
```

## 模組

| 模組 | 做什麼 | 怎麼接 |
|---|---|---|
| `hd2d_stage.gd` | 舞台根節點：`sprite_light(p)` 把角色附近的點光加進角色的色調；`step_lights(dt)` 讓 `%FlickerLights` 閃；`set_region_light(c)` 同時換太陽與角色的色調（同一個舞台換區域） | 舞台 scene 根節點的腳本，或繼承它加遊戲自己的事件光（預警紅光、大招閃光） |
| `hd2d_look.gd` | `environment()`、`camera_attributes()`、`vignette_material()` 三個預設，可傳 `{屬性: 值}` 覆寫 | 在產生器裡呼叫、存成 `.tres`，之後在編輯器調 |
| `pixel_card3d.gd` | 一張立著的像素圖卡：依貼圖大小×`m_per_px` 決定尺寸、往鏡頭仰、alpha scissor 投出圖形狀的影子、不受光（`tint` 調色） | `@tool`；遊戲的 `prop.gd` 繼承時要再寫一次 `@tool` |
| `shot_camera.gd`＋`camera_shot.gd` | 固定構圖的鏡頭：`play(shot, focus)` 推近或小繞一圈再回來，回傳 hit stop；高優先不被低優先打斷；`release()` 立刻回到全場；內建震屏 | Camera3D 的腳本；每個運鏡存一個 `.tres`。想要型別名稱：`class_name CameraShot extends "res://addons/proto_kit/camera_shot.gd"` |
| `ground_decal.gdshader` | 地上的圓或矩形：實心邊、一像素深色外框、預警的斜紋與從中心填滿的倒數、閃動 | 1×1 PlaneMesh＋共用一個材質；每個標示用 instance uniform（`shape`、`color`、`fill`、`pulse`、`inner_alpha`、`texels`） |
| `pixel_vfx3d.gd`＋`pixel_vfx3d_ring.gdshader` | 3D 像素特效：`ring`、`burst`、`drop`、`sweep`；自己的亂數、遊戲時間、碎塊分三段縮小消失 | 需要子節點 `%Chunks`（MultiMesh，用顏色）與 `%Rings`（幾個共用 ring 材質的方片）；每幀 `step(game_delta)` |
| `march_strip.gd`＋`parallax_layer.gdshader` | 放置遊戲的橫向捲軸：走、遇怪、停下來打、怪倒下、繼續走；遠景、道具、地面各自的捲動速度；傷害數字 | 見下節 |
| `hd2d_demo.gd`、`hd2d_gallery.gd` | 只用 kit 模組、程式畫的佔位圖組成的小場景，用來看各部件怎麼配合 | `godot --path prototypes/godot-kit --resolution 720x1280 --script res://addons/proto_kit/hd2d_gallery.gd -- <輸出資料夾>` |

## 光：像素角色不受光

角色與道具圖卡用 unshaded：畫好的像素圖本來就有明暗，受光的平面看起來像紙板。要讓火把、魔法、預警的光照到角色，每幀用 `stage.sprite_light(角色腳底位置)` 乘上角色的色調（sprite3d 的 instance color）。地面是 lit 的，所以太陽影子、點光會落在地上。點光只在 `_ready` 收集一次：燈要放在 scene 裡，不要執行時才新增。

## 鏡頭

- 固定構圖是休息狀態，運鏡只是暫時的。玩家需要看全場時（有預警），先 `release()` 再開始倒數；有人站在紅圈裡時不要開新的運鏡。
- 運鏡的 yaw 保持很小（±8° 以內）：場上的角色圖只畫了一個方向，轉太多會看出是紙片。
- hit stop 交給 `time_control.gd`：`time.hit_stop(camera.play(shot, focus))`。

## 預警與特效的可讀性

- 預警（`ground_decal`）不受光、不吃霧、畫在角色底下：任何距離、任何地面都一樣清楚。顏色之外要有花紋（斜紋），色弱的人也分得出來。
- 衝擊環的材質 `render_priority` 要比預警低，紅圈永遠在上面。
- 特效硬邊、不半透明淡出（pixel-vfx 規則），格子大小用同一個 `m_per_px`。

## 放置的橫向捲軸（march_strip）

```gdscript
extends "res://addons/proto_kit/march_strip.gd"     # 遊戲的行軍畫面
func _damage_base() -> float: return 100.0 * power
func fell() -> void:                                 # 怪倒下：計數、跳出獎勵
	%KillLabel.text = "擊倒 %d" % kills
	popup("+%d 金幣" % gold, Color("e9cf8f"), enemy_rect().position)
func _show_frames() -> void: ...                     # walking 時播跑步格，否則播攻擊格；_t 是畫面的時鐘
```

scene 要有這些唯一名稱：`%Far`、`%Ground`（TextureRect，材質用 `parallax_layer.gdshader`，`tex` 設圖；遠景開 `mirror`）、`%Props`（會往左漂、繞回右邊的 TextureRect）、`%Heroes`（隊伍，最右邊是隊首）、`%Enemy`、`%EnemyHp`、`%Popups`（幾個重複使用的 Label）。速度、命中間隔、暴擊、出怪間隔都是 export。它只是「看起來在打」：收益由遊戲按時間算（例如每小時結算），不要讓畫面上的擊倒數決定收益，否則畫面沒開就沒收益。只在看得見時跑，自己的亂數（`rng_seed`）。

`parallax_layer.gdshader` 的 `depth_far`／`depth_near` 讓同一張圖上下以不同速度捲動（往遠方退去的地面，taskbar-hero 的做法）；兩個相等時整張一起動。

## 驗證

- **截圖要能重現才有意義**：`--fixed-fps 60` 跑，連跑兩次逐位元組比對；行軍畫面在 `add_child` **之後**才 `set_process(false)`（`_ready` 會把 `_process` 打開），再用 `step(1/60)` 推進。
- 改共用模組後，用改之前拍的固定種子截圖逐位元組比對；hero-horde-idle 的 `tools/capture_shots.gd`、`capture_regions.gd` 就是這樣用的。
- 手機：戰場 3D 用 `scaling_3d_scale`（hero-horde-idle 設定的「畫質」，預設 0.8），介面照原生解析度畫。

## 坑

- **`CPUParticles` 會吃全域亂數**，固定種子的測試與平衡量測會位移：特效用 kit 模組（自己的 `rng`）。
- **繼承 `@tool` 腳本要再寫 `@tool`**，否則編輯器裡不會重建圖卡。
- **kit 模組沒有 `class_name`**：要型別名稱就在遊戲裡寫一個繼承它的小腳本。
- **換 shader 不改 scene**：遊戲原本的 `.gdshader` 改成 `shader_type …; render_mode …;` 加 `#include "res://addons/proto_kit/xxx.gdshaderinc"`，材質與 scene 都不用動。
- **instance uniform** 要用 `set_instance_shader_parameter`，材質共用一個；用 `material.set_shader_parameter` 會改到所有標示。
- 地面 shader 每款不同（沙漠、草地、競技場），不要硬做成共用模組。
