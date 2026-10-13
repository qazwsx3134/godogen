---
name: pixel-vfx
description: Godot 4.7 像素風打擊特效的做法與共用模組（godot-kit 的 pixel_vfx.gd＋shader 特效）：PokéSurvivor 式方塊粒子、像素光圈／揮擊弧／命中星芒／字幕，以及硬邊像素爆炸與煙霧 shader。要做或改 2D 像素遊戲的命中、爆炸、煙霧、拖尾、受擊閃白，要新增一種特效，或特效「看起來像破圖、太醜、跟像素圖不搭」時先讀。
---

# 像素特效（godot-kit `pixel_vfx`）

來源：survivor-series 2026-10-14 的特效重做。參考過 PokéSurvivor 的前端程式（只借做法）、VFX 2D Free、GODOT-VFX-LIBRARY、VFEZ，比較結果在最後一節。程式在 `prototypes/godot-kit/addons/proto_kit/`，用 `godot-kit/sync.sh <原型>` 帶進專案。

## 何時用

- 2D 像素圖遊戲要命中、擊倒、爆炸、煙霧、投射物拖尾、揮擊特效。
- 要新增一種特效（形狀或 shader）。
- 特效跟角色畫風不搭：平滑漸層、半透明柔邊、抖動點（dither）在像素圖旁邊都會像破圖。

**不要用在**：高解析平滑畫風（直接用 `GPUParticles2D` 或 VFEZ 那類材質）、3D。

## 看起來對的規則（PokéSurvivor 的做法）

1. **一個像素格**：特效、角色、投射物的一個素材像素在畫面上一樣大。`pixel` = 每個素材像素的世界 px（鏡頭 zoom z、素材 2 倍顯示時是 `2 / z`）。位置對齊格子，角度只轉 22.5° 的倍數。
2. **硬邊**：沒有半透明柔邊、沒有抖動點。淡出分三段跳（100% → 66% → 33%）；shader 特效用「形狀碎開」代替淡出。
3. **5 色配色**：外框、暗、中、亮、白。每種武器或屬性一組，同一組用在命中、拖尾、爆炸，一眼看得出是誰打的。
4. **一像素深色外框**：形狀類（爆炸、煙霧、揮擊弧）都有，粒子不用。
5. **頻繁的用便宜的**：命中火花、拖尾一秒幾百顆，用同一個節點的 `_draw` 畫方塊；爆炸、煙霧這種少量大型的才用 shader 節點。

## 怎麼接

```gdscript
# street.tscn 放一個 Node2D「Fx」，掛 res://addons/proto_kit/pixel_vfx.gd，z_index 蓋過角色
# Inspector：pixel（2 / 鏡頭 zoom）、font（遊戲的像素字型）、palettes（遊戲自己的配色）
@onready var fx: Node2D = %Fx

fx.spark(enemy_chest, hit_direction, &"hit")            # 一般命中
fx.burst(enemy_chest, &"hit", 9, 70.0)                   # 擊倒：方塊炸開（速度單位：素材 px/秒）
fx.slash(hero_chest, aim.angle(), 70.0, 1.7, &"heavy", true)
fx.ring(feet, 10.0, 110.0, &"ice", 0.32, 2)              # 地上擴散圈（已壓扁成橢圓）
fx.caption(spot, "砰！", &"hit")                          # 像素字幕
fx.trail(shot_position, &"fire", &"ember")               # 投射物每幀呼叫：ember 上飄、drip 下滴、其他四散
fx.effect(&"explosion", at, Vector2.ONE * 180, 0.7, &"fire")                    # shader 爆炸
fx.effect(&"smoke", feet, Vector2(170, 140), 3.8, &"smoke", {}, Vector2(0.5, 1)) # 持續的煙，pivot 在底部中間
fx.clear()                                                # 重開一局
```

- 特效用自己的 `rng`（`seed` 固定 7），**不會動到遊戲的全域 `randf()`**，固定種子的測試與平衡量測不受影響。
- 上限：`max_particles`、`max_shapes`、`max_shader_effects`，超過就略過新的（敵人很多時不卡）。
- 受擊閃白不在模組裡：在敵人的 Sprite2D 掛一個 shader，把 modulate 三個通道都超過 1 的部分畫成白色（survivor-series `assets/fx/hit_flash.gdshader`），再用 tween 把 modulate 從 (2,2,2) 拉回 1。

## 新增一種特效

**形狀**（便宜、短命、數量多）：

```gdscript
fx.register(&"cross", func(e: Dictionary, left: float) -> void:   # left 從 1 跑到 0
	for k in range(-e.size, e.size + 1):
		fx.cell(e.at + Vector2(k, 0) * fx.pixel, Color(e.pal[3], fx.fade(left)))
		fx.cell(e.at + Vector2(0, k) * fx.pixel, Color(e.pal[3], fx.fade(left))))
fx.add_shape(&"cross", at, &"gold", 0.3, {"size": 4})
```

`e` 裡有 `at`、`pal`（5 色）、`life`、`t`，加上 `add_shape` 傳的額外鍵。只用 `fx.cell()`、`fx.snap()`、`fx.fade()` 畫，就會自動守住規則 1、2。

**shader**（大型、少量、形狀複雜）：複製 `pixel_vfx_smoke.gdshader`，只改兩個函式，再加進 `shaders`：

```glsl
shader_type canvas_item;
#include "res://addons/proto_kit/pixel_vfx.gdshaderinc"
float density(vec2 p) { ... }  // >= 0.5 算在形狀裡；p 是 -1..1（高度方向），用 progress、seed
float heat(vec2 p) { ... }     // 0 暗 → 1 白，決定用哪個色階
#include "res://addons/proto_kit/pixel_vfx_shade.gdshaderinc"
void fragment() { COLOR = pv_shade(UV); }
```

```gdscript
fx.shaders[&"shockwave"] = preload("res://fx/shockwave.gdshader")
fx.effect(&"shockwave", at, Vector2(200, 150), 0.4, &"ice")
```

`pv_shade` 自己做格子化、色階與一像素外框；可用 `pv_noise`、`pv_fbm`、`pv_hash`。淡出要寫成「`density` 隨 `progress` 變小或碎掉」，不要調透明度。

## 看效果（不跳視窗）

```bash
# 每種特效排成 3×3，存四個時間點並排的一張圖
env -u WAYLAND_DISPLAY xvfb-run -a -s "-screen 0 1600x1600x24" godot --path prototypes/godot-kit \
  --fixed-fps 60 --resolution 480x480 -s res://addons/proto_kit/vfx_gallery.gd -- /tmp/vfx.png [名稱=res://路徑.gdshader]
```

遊戲裡實際大小另外寫一支類似 survivor-series `tools/fx_demo.gd` 的腳本：開一局、在主角旁邊把每種特效放一次、存兩三張圖。任何會開視窗的 Godot 指令都要套 `xvfb-run`（使用者不要桌面跳出視窗）。

## 坑

- **抖動點像破圖**：VFX 2D 的像素模式用 Bayer 抖動做半透明邊緣，在像素角色旁邊看起來像壞掉的圖，煙霧最明顯。所以 kit 的 shader 一律硬邊。
- **煙霧要活很久**：一次性特效的時間軸（0.8 秒炸完）拿來撐 3.8 秒的煙，會一直很小或很快散掉。煙的 shader 自己分段：前 10% 長滿、中間翻滾、最後 20% 碎掉。
- **`CPUParticles2D` 會吃全域亂數**：只要建立就會改變 `randf()` 的序列（2026-10-03 的教訓）。GODOT-VFX-LIBRARY 全是 `CPUParticles2D`，接進有固定種子測試的遊戲要小心；kit 用自己的 `rng` 畫方塊就沒這問題。
- **shader 節點一個一個材質**：每個 `effect()` 是一個節點加一個 `ShaderMaterial`，大量用會變慢，所以有 `max_shader_effects`；命中這種每秒幾十次的用形狀。
- **字型缺字**：`caption()` 用 `font`，記得設成遊戲的像素字型（含補字）；字型子集工具要能掃到字幕文字。
- **burst 的速度單位**是素材 px／秒，`pixel` 改了不用改呼叫。

## 參考過的庫（2026-10-14）

| 庫 | 結論 |
|---|---|
| PokéSurvivor（網頁遊戲，讀前端程式） | 規則 1–5 的來源：方塊粒子＋拖曳、格子拼的光圈與揮擊弧、8 道星芒、5 色屬性配色、受擊閃白、投射物拖尾。只借做法。 |
| VFX 2D Free（godot asset store，CC BY 4.0） | 一個節點一個 shader、`progress` 0→1 驅動的架構很好，kit 的 shader 特效沿用這個介面。像素模式的抖動邊緣不適合像素角色，沒有用它的 shader。完整版（16 種）付費。 |
| GODOT-VFX-LIBRARY（MIT） | 35 個 `CPUParticles2D` 場景＋全域管理器；風格是一般方塊粒子，管理器會改 `Engine.time_scale`，會跟遊戲自己的頓幀衝突。 |
| VFEZ（MIT） | 貼在 sprite 上的材質特效（溶解、發光、扭曲），平滑高解析風格；要做角色狀態特效時可以參考。 |
