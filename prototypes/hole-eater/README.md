# hole-eater

會移動的洞，把地上的東西吃進去（Godot 4.7，3D）。滑鼠移到哪，洞就跟到哪；比洞小的東西會掉進去，比洞大的會卡在洞緣。

開 `project.godot` 按 F5。

## 做法

```
Floor (StaticBody3D, 第 1 層)          地板：stencil ≠ 1 的地方才畫
Hole  (RigidBody3D, 第 5 層 hole, mask 0, 重力 0, kinematic freeze, 摩擦 0)
 ├ HoleMask (CSGCylinder3D h=0.1)      只寫 stencil=1，不畫顏色 → 地板在這裡「被挖掉」
 ├ Pit      (CSGCylinder3D h=4)        cull front：看得到洞的內壁與底（黃色調）
 ├ Lip      (TorusMesh＋hole_rim shader) 洞口旋轉光環
 ├ LipShape0..31 (ConvexPolygon)       帶洞地面：圓形洞口到方形開口之間的 multiple convex
 ├ GroundN/S/E/W (Box)                 帶洞地面：方形開口外的四塊
 ├ Catch (Area3D, mask 2, 球 0.9R)     進來的 RigidBody：collision_mask → hole_flags
 └ Kill  (Area3D, mask 2, 洞底)        碰到就刪掉並計分
Props/* (RigidBody3D, 第 2 層, mask 1+2)
```

- **兩層地面**：平時道具 mask＝地板＋道具；進入洞的範圍改成「帶洞地面＋道具」，不再碰地板，洞口沒有東西撐住就掉下去。不切割物理網格。
- **材質**（`scenes/*_mat.tres`）
  - 洞口：Transparency Alpha、albedo alpha 0（手機上 transparency 不生效時仍不可見）、No Depth Test、Stencil Custom／Write／Always／ref 1、`render_priority -128`、不投影。
  - 地板：Transparency Alpha、Depth Draw Always、Stencil Custom／Read／Not Equal／ref 1、`render_priority -127`。
  - **順序**：透明佇列依 `render_priority` 由小到大畫，洞口必須比地板早，否則 stencil 還沒寫、洞不會出現。原本規劃「地板 -128、洞口 -1」順序是反的，所以改成洞口 -128、地板 -127（地板仍在其他透明物前面，不會吃掉編輯器輔助線）。
  - 洞壁：Cull Front、黃色調。
- **兩個物理調整**（都由 `tests/test_hole.gd` 驗證）
  - 洞本體摩擦 0：洞在移動時，有摩擦會把停在洞緣上的大物體一起拖走。
  - **全域刪除區** `Abyss`（main.tscn，y=-8，160×160）：洞滑開後還留在地底的東西，掉到這裡一樣刪除並計分。
  - **變大**：每吃一個，`size` 加 `grow_per_eat`（彈一下的 tween），等比縮放洞底下每個子 node 的位置與大小。RigidBody 本身的 `scale` 會被物理每幀重設，所以不能直接縮它。
  - 已知：洞長大後，移動中的洞緣會把接近洞口大小的木箱往前推，而不是讓它掉進去；洞停在木箱底下就吞得下。
  - 洞限速 `max_speed`（預設 8 m/s），帶洞地面低於地板 3cm：洞移動太快時，洞緣碰撞形狀之間的接縫會把上面的大木箱鏟起彈飛。

## 可調

| 位置 | 欄位 |
|---|---|
| `Hole`（`scripts/hole_body.gd`） | `normal_flags`、`hole_flags`、`follow_speed`、`max_speed`、`arena_half`、`grow_per_eat`、`max_scale`、`eat_sound`、`grow_sound`、`grow_every` |
| `Main`（`scripts/main.gd`） | `follow_mouse`（測試時關掉） |
| `shaders/hole_rim.gdshader` | `color_a`、`color_b`、`stripes`、`speed` |
| `scenes/prop_*.tscn` | 道具大小、顏色、質量 |

洞半徑、洞深、碰撞形狀由 `tools/build_scenes.gd` 產生（常數 `R`、`LIP`、`PIT_DEPTH`、`GROUND_TOP`）；它是製作工具，重跑會覆蓋 `scenes/`，先看 diff。

## 測試

```bash
timeout 120 godot --headless --path . -s tests/test_hole.gd </dev/null   # 印 ALL PASS
```

涵蓋：洞上方的小東西被吃掉、遠處的東西停在地板、比洞大的木箱停在洞緣且不被拖走、洞離開後木箱回到地板 flags、移動中的洞吃掉靜止的球。

## 還沒做

計時與關卡目標、手機觸控、鏡頭隨洞變大拉遠。

## 音效

`assets/sfx/`：`eat.ogg`＝Kenney Impact Sounds `impactSoft_heavy_000`（每吃一個；洞越大音調越低），`grow.ogg`＝Kenney Interface Sounds `maximize_008`（每吃 5 個）。都是 CC0，授權檔在同一資料夾。
