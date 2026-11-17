---
name: gun-juice
description: 槍砲手感（gun juice）的 7 項標準與 Godot 4.7 做法：開火同幀的槍口閃光與槍管後座、隨機散佈與速度＋曳光尾、落點火花、命中閃白／擠壓／擊退、後座推人與鏡頭上跳、彈殼與血／零件留在地上、每發的槍聲／子彈呼嘯／打肉悶響／打牆叮聲、擊殺停頓後拋飛（最後一擊最大）。附 godot-kit 的 hit_react3d.gd、debris3d.gd 與一個可照抄的測試。做或改任何射擊武器（TPS、FPS、俯視射擊、載具砲塔），或使用者說「開槍沒感覺」「打不出打擊感」「看不出有沒有打中」「槍很假」時先讀。2D 像素遊戲的特效另見 pixel-vfx。
---

# 槍砲手感（gun juice）

來源：walker-tps 2026-11-17 的加農砲重做，使用者給的 7 項標準。參考實作在 `prototypes/walker-tps/`（`scripts/walker_combat.gd` 的 `try_fire()`、`combat_projectile.gd`、`combat_impact.gd`、`scout.gd`），驗收測試 `tests/test_gun_juice.gd`。共用模組在 `prototypes/godot-kit/addons/proto_kit/`。

## 7 項標準（逐項做完、逐項有測試）

| # | 標準 | 判準 |
|---|---|---|
| 1 | 扣扳機那一幀：槍口閃光＋槍管後座 | 同一個函式、同一幀完成；測試在 `try_fire()` 回傳後立刻檢查，不等一幀 |
| 2 | 隨機散佈＋隨機彈速＋曳光尾；落點有火花；可連射 | 方向在錐內均勻分布；速度有範圍；尾巴長度＝速度×時間；牆面火花沿法線噴 |
| 3 | 被打中的目標閃白、擠壓、被推開 | 沒有這三樣就看不出有沒有打中；閃光用半透明暖色再淡出：整片塗白太假，疊加（ADD）在白色機身上會整隻過曝 |
| 4 | 後座：推主角、踢鏡頭 | 鏡頭上跳後彈回；機身被推離射擊方向 |
| 5 | 彈殼噴出並留在地上；目標留下血或零件 | 有上限的池，滿了回收最舊的 |
| 6 | 聲音：每發槍聲、子彈呼嘯、打到身體悶響、打到牆叮聲 | 依命中表面選聲音；槍聲隨機音高、允許重疊 |
| 7 | 擊殺：先停頓再把屍體拋飛；最後一擊最大 | 擊殺的停頓、震屏、爆炸、聲音都比一般命中大一級 |

## 做法

### 1 + 4 + 5 + 6：全部塞進 `try_fire()`

```gdscript
func try_fire() -> bool:
	if reload_left > 0: return false
	# ...生成子彈：方向 _spread(forward, deg)、speed = randf_range(min, max)...
	$MuzzleFlash.play()                        # 1 閃光（一次性 GPU 粒子，restart）
	_barrel = barrel_kick                      # 1 槍管後座：這一幀就擺到最後面
	cannon.position = rest + Vector3(0, 0, -_barrel)
	rig.gun_kick(deg_to_rad(0.7))              # 4 鏡頭上跳，之後指數回彈
	rig.shake(0.12, 0.3)                       # 4 小震：ceiling 讓連射不疊成大震
	body.velocity += back * recoil_push        # 4 推主角（移動程式用 move_toward 自然吃掉）
	shells.spawn(breech, side * 4 + up * 4)    # 5 彈殼
	$ShotSound.stream = SHOTS.pick_random(); $ShotSound.pitch_scale = randf_range(...)  # 6
	$ShotSound.play()
```

- 槍管回位用自己的衰減值（`_barrel = lerp(_barrel, 0, 1 - exp(-30 * dt))`），**不要綁裝填進度**：連射時裝填很短，綁了就看不到後座。
- 散佈要在圓盤上均勻：半徑取 `sqrt(randf())`，不然會集中在中心。
- `AudioStreamPlayer3D.max_polyphony = 4`，連射時尾音疊加而不是被下一發切掉。

### 2：子彈

- 掃掠射線（每個物理步驟從上一點射到下一點），高速彈不會穿過薄牆。
- 曳光：一個 1 m 長的盒子放在子彈後方，`scale.z = speed * tail_seconds`。第三人稱從後面看是端面，**要夠粗**（walker-tps 用 0.15 m）才讀得到。
- 曳光尾長度取 `min(speed * tail_seconds, 已飛距離)`，剛出膛時隱藏；否則尾巴一出膛就往後穿過槍管、砲塔，看起來像破圖。
- 射擊者在 `add_child` 之後才設定方向和速度，所以定向放在 `call_deferred` 的 setup 裡（仍在這一幀畫出之前）。
- 命中時把 `hit.normal` 傳給命中特效，火花層的 basis Y 轉到法線。
- 打到機械目標＝火花＋小火球與煙＋打下零件，**不要放白色光球或光圈**：使用者會把它讀成「打到護盾」而不是打到身體。
- 彈匣：打空自動換彈、換彈期間鎖扳機，出彈匣／入彈匣各一聲；HUD 顯示剩餘彈數。

### 3：命中反應 — `hit_react3d.gd`

目標底下放一個 node，`visual` 指向模型（不是物理 body）：

```gdscript
$HitReact.react(bullet_direction)   # 半透明橘色閃光後淡出（共用 4 階 alpha material_overlay）＋擠壓＋視覺後退，同一幀
$HitReact.throw(away * 9 + Vector3.UP * 8)   # 擊殺：模型拋飛、翻滾、落地停住
```

- 真的把身體推開（擊退）只給槍彈：做成獨立的 `knockback(dir)`，由子彈呼叫。近戰也推的話，會把目標推出自己的攻擊範圍（walker-tps 的自動刀片就因此殺不死）。重的單位推少一點（除以質量）。
- 擊退用一個會衰減的速度，在 AI 移動前套用；一次性的 `move_and_collide` 會被 AI 下一幀的移動蓋掉。

### 5：留在地上的東西 — `debris3d.gd`

`MultiMeshInstance3D` 池：彈殼、零件、地上油漬（`stamp()`）各一個池，**各一次 draw call**，滿了重用最舊的。生成時打一條往下的射線找地板，落地彈跳後靜止；靜止的不再耗 CPU。MultiMesh 在 `_ready` 建立（headless 存檔會丟掉 MultiMesh buffer）。

### 6：聲音

| 事件 | 素材 |
|---|---|
| 每發槍聲 | 幾個變體輪流＋隨機音高；重武器把步槍聲降到 0.5–0.6 倍音高 |
| 子彈呼嘯 | 子彈上的 `AudioStreamPlayer3D`，`unit_size` 小，只有靠近的人聽得到；沒有素材時 `Synth.ramp(2100, 520, 0.26, ...)` |
| 打到身體 | 低沉悶響（hit_heavy 降音高）。命中特效依 `surface = "body"` 選 |
| 打到牆 | 金屬叮聲（沒有素材時 `Synth.ramp(2600, 2300, 0.32, 0.3, 0, 0.45)`），`surface = "wall"` |

### 7：擊殺

- 擊殺時呼叫 `get_tree().call_group("combat_feedback", "kill_feedback", strength)`：hit stop（kit `time_control.gd`，`hit_stop(0.08 * strength, true)`，強制略過冷卻）＋大震屏。一般命中不停頓（連射每發都停會卡）。
- Boss 級敵人要有死亡表演（數秒）：先收掉所有攻擊預告與瞄準線，連環小爆炸、下沉傾斜，期間藏玩家準心，最後一次最大的爆炸後才判定勝利。
- 屍體：`HitReact.throw()`；同時噴 6 個零件、留一大灘油漬、出大爆炸。Boss 用 strength 3。

## 坑

- **hit stop 用牆鐘**：headless 測試跑得極快，幾百幀可能都落在停頓裡（`Engine.time_scale = 0.05`），之後計時就全錯。擊殺後要數幀的測試，先 `OS.delay_msec(300)`。
- **additive 特效在亮底（白機體、淡天空）前看不見**：沒開 glow 時改 alpha 混合＋飽和色。
- **鏡頭震動不要動 camera 的位置**：Camera3D 用 `h_offset`／`v_offset`，瞄準射線不受影響；用兩個不相干頻率的 sin，不要每幀 `randf()`（會嗡嗡抖）。

## 驗收

照 `prototypes/walker-tps/tests/test_gun_juice.gd`：

1. **扳機幀**：`try_fire()` 回傳後立即檢查閃光粒子在發射、槍管已後移、鏡頭 recoil 與 trauma 大於 0、機身速度朝後、彈殼數＋1、槍聲在播。
2. **一秒連射**：發數符合射速、方向不全相同且都在錐內、速度有差。
3. **命中、擊殺、打牆**：命中後目標縮放與位置改變；擊殺後 `Engine.time_scale < 1`、零件增加、停頓結束後屍體被拋起；打牆的命中特效 `surface == "wall"`，火花 basis Y 朝向法線。

最後用 xvfb 截開火後第 0／1／5 幀與擊殺畫面，人眼確認；手感本身仍要實玩。
