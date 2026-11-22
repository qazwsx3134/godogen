# walker-tps：四足戰甲第三人稱戰鬥原型

**狀態：** 進行中（2026-11-10 起）。Godot 4.7，GL Compatibility，橫向，目標是手機。

2026-11-11：預設「綠鏽戰線」已接入雙勾索、主砲、3 台可擊毀的 scout（含重型）、導航 AI，以及出擊／勝敗／超時／重試流程。按 F5 後點 DEPLOY 或 Enter 開始。規則與可調數值見 [戰鬥切片](design/combat-slice.md)，進度見 [PROGRESS](PROGRESS.md)。手機與手把實機驗收待做。

## 都市出擊場景

按 F5，在簡報下方選擇戰場，再按 **DEPLOY**。結算後可重試當前戰場，或選擇另一張地圖。

| 戰場 | 配置 |
|---|---|
| [廢都街區](scenes/ruined_district.tscn) · RUINED DISTRICT | 4 台偵察機和 1 台重裝偵察機。交錯路障、斷牆與高架鐵道形成可側繞的街區。 |
| [斷城廣場](scenes/shattered_plaza.tscn) · SHATTERED PLAZA | 單一 Boss。中央廣場可供機甲交戰，兩側有廢墟、殘骸和斷裂紀念碑。 |

兩張戰場也能直接開啟後按 F6。要調整配置，可在 `scenes/map_ruined_district.tscn` 或 `scenes/map_shattered_plaza.tscn` 編輯 `Streets`、`Ruins`、`Skyline` 與 `RouteMarkers/PlayerSpawn`。敵機位置在戰場場景的 `Enemies` 或 `Boss`。街區建築是 `scenes/buildings/` 的 item scene（`ruined_block_a/b/c` 三種廢棄大樓，含每格碰撞；`skyline_tower_a/b/c` 遠景塔樓，每開間一個盒子、窗格由 `shaders/tower_windows.gdshader` 畫，無碰撞）與街道道具（`t_wall_roadblock` 可破壞路障、`elevated_rail` 高架鐵道、`street_lamp`、`utility_pole`、`wrecked_car`、`signboard`；細長道具不投影、超過 110 m 不畫），地圖的 `Props` 節點放路燈／電線桿／廢車／看板；路面是 `shaders/asphalt.gdshader`（補丁、裂縫、焦黑彈坑，全程序化），人行道高 0.25 m 有碰撞。在地圖裡移動／旋轉即可；外型由 `tools/build_ruined_buildings.gd` 產生（每棟合併成每種材質一個網格，存在 `assets/buildings/*.res`），重跑會覆蓋這些 scene 與網格。廢都街區修改了碰撞配置時，以 `Map` 為來源重新烘焙戰場的 `Navigation`，可參考 `tools/build_urban_sorties.gd` 的烘焙段落。

## 戰鬥鏡頭與 HUD

- 在 `scenes/walker.tscn` 的 `CameraRig` 調整高度與起始俯角，`Pitch.position.x` 控制肩位偏移，`Arm.spring_length` 控制跟拍距離。一般戰場及 Boss 戰共用此機體場景。
- 開啟 `scenes/combat_hud.tscn` 可直接調整 `Telemetry`、`Heading`、`Hull`、`Radar`、`Readouts` 與 `Crosshair`。青色準星對應操作瞄準點，琥珀環標記主砲實際投射點。中央戰鬥框至少佔畫面三分之一寬與高，內顯示倒數和彈藥／裝填，底部機甲圖示與分段量表顯示耐久，左上顯示目標進度。準星兩側顯示水平速度與瞄準射線的命中距離，左側雷達以鏡頭前方為上，顯示 100 m 內尚存活的敵機。

地圖的斷牆、殘骸、橋墩與工廠結構可分件破壞。主砲可削減其耐久，高速衝撞與 Boss 機身接觸可直接撞碎並觸發空間音效。Boss 由地表支撐，頭部砲骨決定光束砲口位置。

- `Radar.contour_interval` 控制等高線間距，預設 2 公尺。等高線取樣地表碰撞層並隨鏡頭方位旋轉。操作準星可用 `Crosshair.reticle_scale` 單獨調整，外框尺寸仍由場景與原有 `sight_scale` 控制。
- 在支撐於其他構件的掩體上設定 `support`。支撐破壞時，上層以剛體掉落，混凝土與鏽蝕紋理會跟著構件移動。破壞部位用共用碎塊池散出碎片。橋墩與橋面、廠房立柱與橫樑、斷牆和裝甲殘骸已配置。

- `CombatHUD.hud_drift_limit` 與 `hud_follow_speed` 控制轉視角時青色準星、戰鬥框和座艙線框的慣性。橘環會平滑追隨砲管的投射點。
- `scenes/walker.tscn` 的 `Gait.cadence_multiplier` 採 1.3，擺腿時間可由 `step_time` 與 `step_time_run` 調整。落腳點在每一步開始時確定，支撐腳在世界座標保持固定。`step_height` 與 `lead` 控制抬腳及前伸幅度。機體根節點的步行／衝刺速度為 8／12.6 m/s，`speed_blur_strength` 控制 Shift 加速時的環形模糊強度。

## 音效調音

在 Godot 編輯器底部開 **Audio Tuner**。搜 `cannon_shot.ogg` 即可調主角機砲的音高倍率和分貝，可用 **Play** 試聽。改值後會自動套用，也可按 **Apply to game** 立刻存下。**Apply to game** 會顯示已存入 `audio_mix.cfg` 的倍率和分貝。開發中的遊戲在該音效下次播放時讀取設定。可將同一外掛複製到別的專案，接法見 [Audio Tuner 說明](addons/audio_tuner/README.md)。

## Boss／裝甲負載場景

開啟 `scenes/boss_battlefield.tscn` 並按 F6；原戰場仍由 F5 開啟。Boss 是地面敵人，22 隻粗的折刀狀兩節腳蹲伏撐地、腹部離地約 0.8 m（模型在 `boss.tscn` 下移 1.14 m），用 1.6 秒一圈的沉重波浪步態慢慢爬行（`crawl_speed` 2.2、落腳有低沉的 `StepSound`；動畫速度依實際移動速度縮放，`walk_anim_speed`），可被擊毀並計入勝利目標。

- **第一型態**：輪流用光束與柱雨（`scenes/boss_pillar.tscn`，由 `tools/build_boss_pillar.gd` 製作）：Boss 蓄力 0.9 秒後射出 `pillar_count` 16 根鐵灰色細圓柱（半徑 0.3 m、長 8 m），各自先在地上亮紅色脈動圈（穿透草地顯示），錯開 `pillar_stagger` 0.1 秒從天而降；第一根落在玩家前進方向，其他散在 3.5～`pillar_spread` 14 m 內。落在圈內（`hit_radius` 1.5 m＋機身半徑）的玩家受 12 傷害並震屏；柱子插進地面成為障礙物與掩體，24 血可被主砲打爆，30 秒後自行碎裂，場上最多 `max_pillars` 40 根。玩家在背後近處時甩尾。光束是長蓄力招：頭上主砲追瞄玩家、砲口聚集能量（`scenes/boss_charge.tscn`）約 2 秒，最後 0.55 秒鎖定瞄準並顯示紅色瞄準線（此時閃避），然後沿砲管方向發射。時間在 `beam_charge_time`／`beam_lock_time`／`beam_fire_time`。
- **第二型態**（血量 ≤ `phase2_health_ratio`，預設 50%）：背後展開光纖翅膀（`scenes/boss_wings.tscn`），加入兩招。光纖刺擊：三條光纖鎖定玩家與左右各 3.5 m 的位置，0.8 秒淡色預告後刺下。伸翼砸擊：紅圈貼地追蹤玩家，最後 0.48 秒鎖定。預設 1.65 秒蓄力，對應側的整片翅膀先收攏高舉，再向後拉緊並維持片刻，光纖從青色轉為琥珀色。揮下時翅膀展寬並伸長到紅圈中心，砸地後短暫壓住才收翼。落點會炸開地面衝擊環、揚塵與碎屑，伴隨低沉撞擊聲。鏡頭下沉與震動會隨離落點的距離衰減。範圍由 `slam_radius` 及 Boss 尺寸決定，`slam_fold_ratio` 可調起手時的收翼幅度。
- **效能**：每邊翅膀是一個 MultiMesh（16 條十字面片，各 4 個三角面，一次 draw call），共用 `shaders/fiber.gdshader` 與程式產生的 `assets/vfx/fiber.png`，擺動與流光都在 shader 裡；攻擊用的光纖是 4 個同材質的長面片，只在出招時顯示。

`1`／`2`／`3` 立即觸發光束／飛彈／甩尾；`4`／`5`／`6` 切換 10／40／80 台展示機；`7` 切換展示機投影，預設關閉。也可按右上角按鈕，出擊後先按 Esc 釋放滑鼠。左上角原 HUD 顯示 FPS 與 draw call。

預設展示機為 4 台 melee、4 台 tank、2 台 Phido，會在出生點附近巡行；數量不包含 Boss、玩家或原本 3 台 scout。展示機只巡行、沒有碰撞與戰鬥。Boss 速度、血量、攻擊間隔在 `Boss` node 的 export 欄位。

**移動物理**（`walker_player.gd`）：腳能抓地的上限是 `grip_speed` 13 m/s（腿跨步的極限）。低於它時照 `accel` 8 m/s² 加減速並轉向；高於它（衝刺落地、勾索放開）時腳抓不住而打滑：動摩擦 `slide_friction` 5.5 m/s²（約 0.55 g）不管搖桿怎麼按都會減速，搖桿只能用 `slide_steer` 3 m/s² 側向把滑行方向帶彎，腿收起撐著（步態 `skid`），降到 13 m/s 以下才恢復踏步。勾索只會拉、不會推：拖行到錨點前 `release_distance`、超過 `max_drag_time`／`max_swing_deg`、錨點或繩子斷掉、或按 G 剪斷時，都只是放開繩子，速度一點都不變，接著就是打滑。只有回合結束、死亡、出界會立刻歸零（`cancel_hook`）。18 m/s 放開時約滑過錨點 21 m。

玩家機甲：走路 8、Shift 衝刺 12.6 m/s；衝刺與勾索拖行時有全螢幕速度模糊（`scenes/speed_blur.tscn`，畫在 HUD 下層，強度在 Walker 的 `speed_blur_strength`，0 為關閉）。主砲是大口徑加農砲，命中時產生半徑 2.4 m 的爆破特效；開火與爆炸是疊多層一次性 GPU 粒子（見下方「開火與爆炸特效」）；勾索有發射音效。勾索甩尾時砲塔不再受 ±30° 限制，維持瞄準鏡頭目標。空白鍵是衝刺不是高跳：短蹲 0.06 秒後朝搖桿方向（沒按方向時朝鏡頭前方，站在斜坡上則順坡往外）以 `dash_speed` 20 m/s 衝出 `dash_time` 0.22 秒，斜斜往上約 1 m（`jump_velocity` 4.5）；空中只有很小的空氣阻力（`air_drag`），落地時若超過 `grip_speed` 13 m/s 就在腳下打滑（見下方「移動物理」）；冷卻 `dash_cooldown` 0.45 秒。貼著牆按會沿牆面法線彈開衝出（`wall_jump_push`）。場景由 `tools/build_ground_boss.gd -- --overwrite` 製作，正常執行不會重建。

[量測方法、結果和場景截圖](docs/BOSS_LOAD_TEST.md)列出投影開關的差異與實機驗證方式。

## 單位尺寸

以 melee＝1（最長水平邊約 5.5 m）：主角機甲與 tank 2（約 11 m）、scout 0.8（約 4.4 m）、Boss 40（約 218 m）。由 `tools/apply_unit_scales.gd` 寫進各單位 scene 根節點與所有擺放的實例（Walker 1.9、tank 1.67、scout 0.91、Boss 5.45）。

- 根節點有縮放，所以程式裡當「方向」用的 `global_basis.z` 一律 `.normalized()`（scout、勾索、刀片、Boss 的 `_facing()`）。
- Boss 的距離數值（停止追擊、甩尾觸發、砸地半徑、光束射程、死亡爆炸大小）按 `scale / TUNED_SCALE(1.35)` 放大。
- Walker 的步態距離（`step_distance`、`step_height` 等）與鏡頭（`CameraRig.height` 6.3、`Arm.spring_length` 14，rig 是 top_level 不吃縮放）已按 1.9 倍設在 `walker.tscn`。移動速度沒改。
- 地圖只有約 240×220 m，Boss 幾乎和地圖一樣長：放在 `boss_battlefield.tscn` 的 z=55 面向玩家，尾巴伸出地圖外。地圖大小待定。

## 主砲手感（gun juice）

主砲是按住連射的機砲（每秒約 2.4 發、每發直擊 55 傷害並在落點爆開：`blast_radius` 4 m 的爆炸特效、`splash_radius` 5.5 m 內其他敵人與可破壞掩體受 `splash_damage` 30（中心 100%、邊緣 40%）並被往外推、曳光與彈頭光點寬度是一般彈的兩倍；彈匣 `magazine_size` 8 發，打空或按 R／手把 X 換彈 `magazine_reload_time` 2.2 秒，換彈中不能開火，HUD 顯示 `AMMO n / 8` 或 `RELOADING`），照 [gun-juice 標準](../godot-kit/skills/gun-juice/SKILL.md) 7 項做，驗收在 `tests/test_gun_juice.gd`：

1. **扳機那一幀**：`walker_combat.gd` 的 `try_fire()` 同時做砲口閃光、砲管後座（`barrel_kick`，自己快速回位，不綁裝填）、鏡頭上跳（`camera_kick_deg`）與小震、把機身往後推（`recoil_push`）、退出彈殼、播槍聲。
2. **子彈**：錐內均勻散佈（`spread_deg`，瞄準時 `aim_spread_deg`）、速度 `bullet_speed_min`～`max`（110～135 m/s）、曳光尾隨速度拉長，但只延伸到已飛過的距離（不會從砲管後方穿出）；打牆的火花沿表面法線噴。
3. **被打中**：命中點噴出裝甲火花、碎屑、火球與煙，打下 2～3 塊零件；目標的 `HitReact`（kit `hit_react3d.gd`）蓋一層半透明橘色 0.12 秒並淡出（保留原貼圖，白色機身不會過曝）、擠壓、模型後退；槍彈另外呼叫 `knockback()` 真的推開 scout（重型推得少；刀片不推，否則會把目標推出刀片範圍）。
4. **後座**：見 1。鏡頭震動在 `orbit_camera.gd` 的 `gun_kick()`／`shake()`，`shake_scale` 設 0 可關（無障礙）。
5. **彈殼與殘骸**：`walker_combat.tscn` 的 `Shells`／`Parts`／`Stains` 是 kit `debris3d.gd` 的 MultiMesh 池（各一次 draw call，滿了重用最舊的），彈殼、零件、油漬留在地上。
6. **聲音**：每發槍聲（三個變體、隨機低音高、最多 4 個重疊）、子彈上的呼嘯、打到身體的悶響、打到牆的叮聲（後兩個沒有素材，用 kit `synth.gd` 合成）。
敵方：scout 子彈 72 m/s，瞄準點加 `aim_spread` 1.3 m 的隨機偏移、預判 `lead_accuracy` 0.6（`battlefield.tscn` 的覆寫值）；Boss 飛彈 36 m/s。

7. **擊殺**：Boss 有 `death_time` 3.2 秒的死亡表演：先停頓，背上每 `death_blast_interval` 秒一處爆炸並噴零件、機身下沉傾斜、翅膀萎縮，期間隱藏玩家準心，最後一次最大的爆炸與停頓後才判定任務完成；死亡時光束、蓄能與光纖瞄準線全部收掉。勾索是深色鋼纜加四角帶刺鉤頭（`walker_combat.tscn` 的 Cable0/1、Pin0/1 材質，`tools/build_combat_slice.gd` 已不反映此外觀，不要重跑）。

`kill_feedback()` 停頓（`TimeControl`，牆鐘計時）＋大震屏，scout 殘骸被拋飛翻滾後留在地上，噴 6 個零件、留一大灘油；Boss 死亡是 3 倍。

製作工具 `tools/build_gun_juice.gd` 把上述節點加進 scene（之後以 scene 為準）。已知限制：追尾鏡頭在砲塔正後方，曳光彈多半是正對鏡頭的亮點，要看到長尾巴需要偏肩鏡頭。

## 開火與爆炸特效

照 GODOT VFX 兩支教學（Muzzle Flash、Hits and Impacts）的做法：每層是 additive、unshaded 的一次性 `GPUParticles3D`，各自有壽命、縮放曲線與透明度淡出，火花沿速度方向拉長。

- `scenes/muzzle_flash.tscn`：Planes（十字交叉面片、樞紐在砲口、沿 +Z 長出）、Flash、Sparks、Smoke、Light。砲口在追尾鏡頭裡常被砲塔擋住，所以加 0.08 s 的閃光燈照亮機身與地面。
- `scenes/combat_impact.tscn` 的 `Fx`：Flash、Flare、Sparks、Smoke 是所有命中都有的；半徑 ≥ 2（加農砲、飛彈）再加 Fireball、地面 Shockwave 環、Debris、Light。整組依 `radius` 縮放，所有命中（玩家砲彈、Boss、飛彈、scout、刀片）共用這個 scene。
- 貼圖 `assets/vfx/*.png` 由 `tools/build_vfx.gd -- textures` 用程式產生；粒子數值直接在編輯器改各 GPUParticles3D 的 process material。
- 目前沒有開 WorldEnvironment glow：教學的亮度靠 glow，但這會改變整個戰場的畫面與負載量測數字，要不要開由作者決定。

## 要驗證的假設

1. 剛體零件組成的四足模型（`docs/86/walker/new/walker.glb`）不用骨架，只靠程式 IK，就能走得像有重量，腳不打滑。
2. 鍵盤、手把、觸控共用同一套移動模型；手機上用雙指（左手搖桿、右手轉鏡頭）就能順手操作第三人稱。
3. 一台 15.8k 三角面的機體加上簡單場景，在手機上有餘裕。實機還沒驗證。

## 另一台電腦開啟

使用 Godot 4.7；Git 內含可直接使用的 GLB、貼圖、Ogg、材質、保存場景、腳本與 proto_kit 副本，不需另外複製 `docs/86`、安裝 FFmpeg 或重跑場景產生器。首次開啟 `project.godot` 等待編輯器匯入，再按 F5。命令列先執行 `godot --headless --path prototypes/walker-tps --editor --quit`，再執行遊戲／測試。

`.godot/` 快取、Python 快取、log、captures／build／dist／exports 與原始音效不提交。遊戲使用 `assets/sound/runtime/` 的處理後音效，原始錄音僅在重新轉檔時才需要。`.import` 匯入設定與 `.uid` 識別檔保留在 Git，由每台電腦自行產生快取；這個原型的執行素材不使用 Git LFS。

## 怎麼跑

```bash
cd prototypes/walker-tps
godot --headless --fixed-fps 60 --path . --script res://tests/test_combat.gd    # 戰鬥整合測試
godot --headless --fixed-fps 60 --path . --script res://tests/test_battlefield.gd    # 地圖回歸
godot --headless --fixed-fps 60 --path . --script res://tests/test_scout_ai.gd    # scout AI：預判、遲滯、警覺、換位、視角錐、協同
godot --headless --fixed-fps 60 --path . --script res://tests/test_gait_terrain.gd    # 步態：衝刺、只踩地形、坡面傾斜、拖行不踏步
godot --headless --fixed-fps 60 --path . --script res://tests/test_grapple_inertia.gd    # 勾索慣性與甩尾
godot --headless --fixed-fps 60 --path . --script res://tests/test_mobility.gd    # 牆跳、斜坡跳、衝刺模糊、甩尾時砲塔瞄準
godot --headless --fixed-fps 60 --path . --script res://tests/test_gun_juice.gd    # 主砲手感 7 項標準
godot --path .                                   # 開遊戲（或用編輯器開 project.godot，按 F5）
godot --headless --fixed-fps 60 --path . --script res://tests/test_walker.gd    # 展示場移動、步態與落地
godot --headless --fixed-fps 60 --path . --script res://tests/test_scouts.gd    # 展示場敵機回歸
xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/perf_scouts.gd   # 敵機的 draw call 量測
xvfb-run -a godot --path . --resolution 1280x720 --fixed-fps 60 --script res://tools/capture.gd -- <輸出資料夾>  # 螢幕外截圖
```

| 操作 | 鍵盤滑鼠 | 手把 | 觸控 |
|---|---|---|---|
| 前後左右（相對鏡頭，可以橫移） | WASD／方向鍵 | 左搖桿 | 左半邊任意處按下，就地出現浮動搖桿 |
| 轉鏡頭 | 點一下鎖定滑鼠後移動，Esc 釋放 | 右搖桿 | 右半邊拖曳 |
| 衝刺（按住） | Shift | RB／按下左搖桿 | 右下角 BOOST |
| 跳躍 | Space | A | 右下角 JUMP |
| 主砲開火 | 左鍵（鎖定滑鼠後） | RT | FIRE（可拖曳瞄準） |
| 瞄準／拉近視野 | 按住右鍵，或 Q 切換 | LT，或 Y 切換 | AIM 切換 |
| 雙勾索／拖行中再按＝剪斷繩索（保留速度） | G | LB | HOOK |
| 出擊／重試 | Enter 出擊；結算 R 重試 | 介面按鈕 | DEPLOY／RETRY |

- **車身朝向：** 移動時以每秒 90° 轉向鏡頭方向，主砲會朝鏡頭目標旋轉，砲塔限制 ±30°。瞄準或開火時超出砲塔角度會帶動車身原地轉向；未瞄準時可自由環視。
- **速度：** 走路 6.0 m/s，衝刺 9.0 m/s（2026-11-12 從 4／6.5 調快）。越快步伐越密，車身也壓得越低，鏡頭 FOV 跟著放寬 10°。在 `walker.tscn` 根節點的 max_speed／sprint_speed 調，步態的 `Gait` 節點 run_speed 要跟著改成同一個衝刺速度。
- **跳躍：** 先蹲 0.12 秒再彈起，最高約 2.5 m，1.4 m 高的掩體跳得過去。空中轉向只有 30%。
  - 腳的姿勢：上升時收起，下墜時往下伸。
  - 落地：四腳重新踩地、車身下沉再回彈，揚起四團塵、鏡頭重震，配上低沉的落地聲。

## 從參考遊戲借了什麼

| 來源 | 借的優點 | 在這裡怎麼做 |
|---|---|---|
| [Midway](https://ihca.cn/midway/) | 手機雙指操作：左手浮動搖桿放開就回中，右手滑動微調方向；觸控和滑鼠靈敏度分開 | `touch_input.gd`：左右半邊各追蹤一根手指（用手指 index，哪根先按都行）；`walker_player.gd` 的 `mouse_sensitivity`、`touch_sensitivity`、`pad_look_speed` 三個 export 分開調 |
| [ASCII District](https://ascii-district.vercel.app/) | 點擊鎖定滑鼠、Esc 釋放；用顏色區分場景用途，一眼看出路線 | 場景配色：米色是掩體，青色是能走上去的坡道和平台，珊瑚色是遠方的地標塔，灰色是牆和門 |
| [Canyon Overdrive](https://canyonoverdrive.ai-created.com/) | 滑鼠、觸控、手把共用同一套操控模型；畫面品質會依硬體調整 | 三種輸入都進同一個 `wish` 向量；HUD 左上角顯示 FPS 和 draw call，在手機上一眼看出效能 |
| 共通 | 每個動作都有回饋 | 每次落腳：圓形揚塵、鏡頭往下一震、低頻「咚」聲（`synth.gd` 合成，音高略有變化） |

尚未實作：陀螺儀與完整設定畫面。

## 主要 scene 與可調整的地方

scene 由 `tools/build_scenes.gd` 產生一次，之後 `.tscn` 就是原始檔，直接在編輯器改。重跑產生器會跳過已存在的檔案；加 `-- --overwrite` 會覆蓋手動修改，跑之前先看 `git diff scenes/`。

| scene | 內容 | 可以在編輯器調的 |
|---|---|---|
| `scenes/main.tscn` | 環境光、太陽、Arena、Walker、HUD、Enemies（12 台 scout） | `WorldEnvironment` 的霧與環境光、`Sun` 的角度與陰影距離；Enemies 底下每台 scout 的位置與朝向（`tools/add_scouts.gd` 用 `open_scene`＋`put` 加進去的，重跑只換掉 Enemies） |
| `scenes/boss_battlefield.tscn` | 既有戰場、Boss、10 台已儲存的展示機與負載控制 | `Boss` 和 `Armor` 底下各機體的位置及方向；每台展示機的 `animation_phase`、`shadows_enabled`；額外展示機在執行時按需求實例化 |
| `scenes/boss.tscn`、`melee_display.tscn`、`tank_display.tscn`、`phido_display.tscn` | Boss／各展示機的可重用場景與模型 | Boss 根節點的 `initial_animation`；展示機的 `animation_phase`、`shadows_enabled` |
| `scenes/arena.tscn` | 160 m 網格地面、外牆、坡道與平台、掩體、木箱、門、地標塔 | 每個方塊是 StaticBody3D，拖曳就能改位置；網格的格寬與顏色在 `shaders/grid_ground.gdshader` 的 uniform |
| `scenes/walker.tscn` | CharacterBody3D、膠囊碰撞、`Model`（walker.glb）、`Gait`、4 個揚塵粒子、腳步聲、`CameraRig` → `Pitch` → `Arm`（SpringArm3D）→ `Camera` | Walker 的 `max_speed`、`sprint_speed`、`accel`、`air_control`、`turn_speed_deg`、`grip_speed`／`slide_friction`／`slide_steer`／`air_drag`、`dash_speed`、`dash_time`、`dash_cooldown`、`jump_velocity`（衝刺離地的小跳）、`jump_squat_time`／`_depth`、三種靈敏度、`step_kick`、`sprint_fov_add`；Gait 的 `step_distance`、`step_time`／`step_time_run`、`run_speed`、`run_crouch`、`step_height`、`lead`、`bob`；CameraRig 的 `height`、`pitch_*`；Arm 的 `spring_length` |
| `scenes/scout.tscn` | CharacterBody3D、膠囊碰撞、`Model`（scout.glb：1 個蒙皮 mesh、AnimationPlayer 的 `walk`／`idle`） | `speed`、`turn_speed_deg`、`wander_radius`、`pause_min`／`pause_max`；模型與動畫的細節見 `docs/86/enemy/scout/README.md` |
| `scenes/hud.tscn` | TouchInput（搖桿底座和搖桿頭）、Stats、Hint、Buttons（JUMP、BOOST 兩個 TouchScreenButton，只在觸控裝置顯示） | 搖桿的大小與樣式、`radius`、`dead_zone`；按鈕位置；文字位置。按鈕是 `tools/add_action_buttons.gd` 用 `open_scene`＋`put` 加進去的，不會動到 scene 其他部分 |

`walker.glb` 裡的零件（`Hull`、`Leg_*_Thigh/Shin/Foot`）是匯入的子 scene，不能設成 `%唯一名稱`，所以 `walker_gait.gd` 在執行時用 `find_child` 找。

## 步態怎麼運作

```
每個 physics frame（Walker 先 move_and_slide，接著跑 Gait）
  │
  ├ 每隻腳的 home：模型空間的靜止腳底位置 → 世界座標
  │   ＋速度 × step_time × lead（落在前面）→ 往下 raycast 找地面
  │
  ├ 決定抬哪一組（對角一組：FL+BR、FR+BL）
  │   ├ 另一組還在空中 → 不抬
  │   ├ 這組裡最遠的腳離 home 超過 step_distance → 整組抬
  │   └ 安全規則：著地的腳快被拉超過可及範圍 → 整組立刻抬
  │
  ├ 空中的腳：從起點弧線移到「目前的」home（轉彎時會跟著修正），落地發出 stepped
  │   swing 時間依速度內插：step_time（走）→ step_time_run（6.5 m/s）
  │
  ├ 離地（跳躍、走下平台）超過 0.08 s → airborne：腳跟著身體，收或伸取決於垂直速度
  │   著地 → 四腳重新落在 home、車身下沉、發出 landed(impact)
  │
  └ 兩段 IK（Hull 空間）
      膝角：用牛頓法求 phi，讓 |髖→踝| 等於目標距離
      大腿：最短旋轉，把髖→踝轉向目標
      腳掌：保持和車身水平
  車身高度 = 靜止高度 + bob（抬腳時）− run_crouch × 速度比例 − 下沉量（起跳前蹲、落地）
```

## 驗證紀錄

2026-11-10（加衝刺、跳躍之後重跑），L2：

- **`tests/test_walker.gd`：** `WALKER PASSED`。
  - 往前走沿鏡頭方向前進超過 5 m、不往旁邊偏，車身轉向鏡頭方向。
  - 往前走和轉 90° 後往左橫移時，著地腳底和落腳點的誤差都小於 3 cm。
  - 走路時至少踩 6 步。
  - 雙指觸控：鏡頭手指先按、搖桿手指後按，兩邊都能動，放開搖桿就停。
  - 上坡：從青色坡道前往上走 330 幀，能走上 3 m 高的平台，著地腳的誤差小於 1 mm。390 幀裡有 15 幀兩組腳同時在空中，因為坡道上下的交界處會觸發緊急抬腳。
  - 衝刺：最高 6.50 m/s，著地腳的誤差小於 1 mm。240 幀裡只有 1 幀兩組腳同時在空中，維持對角小跑。
  - 跳躍：最高 2.56 m，最高點時最低的腳離地 2.76 m（腳有收起來）。只落地一次，落地速度 6.9 m/s，之後四腳都踩回地面。
  - 觸控：按在右下角按鈕區不會變成轉鏡頭的手指。
- **步態節奏：** 往前走 300 幀，兩組每 16 幀輪流抬腳，只有起步那 3 幀兩組同時在空中。
- **headless 匯入：** 沒有錯誤。
- **編輯器驗收：**
  - 跑完整套測試前後，四個 `.tscn` 的 md5 相同，執行時不會寫回 scene。
  - 直接把 `hud.tscn` 裡 Hint 的 `offset_left` 從 16 改成 48，執行時讀到的是 48，手動修改會保留。驗完已改回 16。
- **xvfb 截圖：** 站立、走路、跨步中、轉鏡頭後橫移、衝刺、跳到最高點、落地都正常，揚塵和陰影也都在。
  - 畫面上的 FPS 27～34 是 xvfb 軟體繪圖的數字，不代表手機表現。
  - draw call 是 70～76：機體 15 個零件、場景約 17 個方塊，加上陰影 pass。

**敵機（2026-11-10，L2）：**

- **`tests/test_scouts.gd`：** `SCOUTS PASSED`。
  - main 裡有 12 台，跑 10 秒後至少 8 台離開出生點。
  - 每台都待在家附近 12.5 m 以內，也都在地面上。
  - 走路動畫的 `speed_scale` 等於移動速度 ÷ 1.6。
  - 每台只有 1 個 surface。
- **`test_walker.gd` 重跑：** 仍然 `WALKER PASSED`，各項數字和加入敵機前一樣。
- **`tools/perf_scouts.gd`：** 起始鏡頭，全部 scout 都在畫面內。

  | 情況 | draw call | 繪製的三角面 |
  |---|---|---|
  | 沒有 scout | 70 | 45k |
  | 12 台 | 96 | 79k |
  | 48 台 | 167 | 172k |
  | 48 台，關掉 scout 的投影 | 118 | 108k |

  - **每台的成本：** 主畫面 1 次 draw call，開投影時陰影 pass 再多約 1 次，每台 1,304 個三角面（2026-11-10 機砲細化後重量）。
  - **手機的建議：** 中階機的預算大約一兩百次 draw call，所以超過二三十台時，遠處的 scout 可以關掉投影，或改用腳下的圓形影子貼花。
  - xvfb 上的 FPS（13～30）是軟體繪圖，不能當手機的參考。
- **截圖：** 12 台各自遊蕩，朝向不同、步伐錯開，紅色鏡頭看得到。

**沒驗證：** 實機手機上的幀率、雙指觸控和按鈕的手感（只在 headless 模擬過事件）、手把。

## 已知的坑

- **跳躍能越過測試場外牆（待修）：** 本次審閱量到跳高 2.56 m，外牆只有 2 m；跳出牆再走出 160 m 地板後會持續下墜。需要按跳躍能力設計邊界，並補越界恢復／失敗規則，重現見 [評審報告](reviews/2026-11-10-game-critic.md#本次驗證與限制)。
- **只轉髖關節（FK）會讓腳打滑：** 腳在對角線上，轉髖時腳是沿切線移動。改用落腳點加 IK。
- **腳的可及範圍很有限：** 髖到踝在靜止時是 2.11 m，最多只能伸到 2.69 m，所以支撐期的行程大約只有 ±0.4 m。
  - 要跑快，就讓步伐更密（`step_time_run` 0.17 s），同時壓低車身（`run_crouch` 0.3 m）。髖關節離地近了，腳就能往前後伸更遠。
  - `lead` 維持 0.5，讓支撐期前後對稱。
  - 調了速度或步伐之後要跑測試，看所有「planted feet do not slide」都有過，再看 `sprint:` 那行兩組腳同時在空中的幀數有沒有暴增。暴增代表一直在觸發緊急抬腳。
- **站在平台旁邊時，靠近平台那側的腳可能踩到平台上：** home 的 raycast 從腳上方 3 m 往下打。可及範圍內不會出錯，但看起來像蜘蛛攀牆。
- **緊急抬腳要整組一起抬：** 只抬一隻腳會打亂對角交替，下一輪換另一組被拉長，每一輪都要插隊。
- **headless 觸控測試要用 `root.push_input(e, true)`：** 不加 true，座標會被當成視窗座標再換算，左右半邊會判斷錯。
- **`TouchScreenButton` 設成只在觸控裝置顯示時，只會藏它自己的圖：** 子節點的 Label 照樣畫出來，所以 `hud.gd` 在沒有觸控螢幕時把整個 Buttons 藏起來。
- **在坡道上走，`velocity.y` 會大於 1：** 如果判斷離地只看「`velocity.y` > 1」，在坡上就會誤判成跳起來，所以還要加上不在地面（`not is_on_floor()`）。
- **`touch_input` group 存在 `hud.tscn` 裡：** 如果在 `_ready` 才加入 group，Walker 的 `_ready` 比 HUD 早執行，會拿到 null。
- **貼圖格式：** 貼圖設成 VRAM 壓縮（ETC2/ASTC），原生 Android／iOS 沒問題。如果要出網頁版給手機瀏覽器，見 `LESSONS.md`「手機 WebGL 上角色全不見」：可能要改成 Lossless，或在網頁匯出設定開啟 For Mobile。

## 待辦

見 [TODO.md](TODO.md)。

## 發現

（原型結束時填寫）

## 首張地圖：編輯與驗證

- 預設場景：`scenes/battlefield.tscn`；`Map` 引用 `map_01_green_rust.tscn`。原 `main.tscn`／`arena.tscn` 保留為移動測試場，可從編輯器開啟按 F6。
- 地圖場景內 `Terrain` 是已儲存網格與承重碰撞；`Ruins`、`Wrecks`、`BrokenViaduct`、`Factory` 可直接移動、縮放及調色；`Vegetation` 是 30 區靜態草叢網格，沒有碰撞。殘骸子場景的 `HullOvergrowth` 是車殼上的草。
- `RouteMarkers` 提供出生點與三條路線的定位；移動 `PlayerSpawn` 就能調整越界返回位置。`battlefield.gd` 的 `playable_half_extents`／`fall_limit` 控制恢復界線。
- `ruined_wall.tscn`、`armored_wreck.tscn` 是可重用道具；新地圖在編輯器未執行時就能看到完整布局。
- 製作工具 `tools/build_battlefield.gd` 已於 2026-11-10 執行。正常匯入／執行不重建；重跑預設略過已有 scene。`-- --overwrite` 會覆蓋這五個新場景，需先檢查並保留人工修改。

| 層級 | 本次相關指令（專案根目錄） |
|---|---|
| L1 地形與恢復 | `godot --headless --fixed-fps 60 --path . --script res://tests/test_battlefield.gd` |
| L2 戰鬥／地圖回歸 | `test_combat.gd` 加 `test_battlefield.gd`；用上面的 headless 指令替換 script 路徑 |
| AI／步態／勾索 | `test_scout_ai.gd`、`test_gait_terrain.gd`、`test_grapple_inertia.gd`（含甩尾）、`test_auto_blades.gd` |
| 場景匯入 | `godot --headless --path . --editor --quit` |
| L3 | 真人驗收後再擴大完整平台測試；本次未跑完整 suite |

2026-11-10 的地形驗證見 PROGRESS；2026-11-11 戰鬥與導航已接入，驗證見下節。正式素材細化與手機效能仍待驗收。

## 地圖材質（2026-11-10）

採低面數幾何＋原創程序貼圖，沒有使用 AI 或外部素材。`assets/environment/` 的三張 1024 × 512 PNG 共用同一組 8 格圖集：albedo、normal、ORM（R 遮蔽、G 粗糙度、B 金屬度）。地表混合泥土／碎柏油／草地，斷牆與橋柱使用混凝土，殘骸與鋼架使用鏽鐵／焦黑鋼；朝上的表面有苔色斑塊。

- `materials/battlefield_ground.tres`：`tile_meters` 調重複尺寸、`road_half_width` 調道路材質寬度；只影響外觀，不改碰撞。
- `materials/weathered_concrete.tres`、`rusted_armor.tres`、`burnt_steel.tres`：`tile_meters`、`moss_amount`、`atlas_cell` 可於 Inspector 調整；都是 scene 引用的共用外部資源。
- Shader 使用世界座標投影，無需為方塊道具另外展 UV。地表及道具各 6 次貼圖讀取，使用兩種尺寸／方向混合降低重複；重複座標以顯式梯度取樣，避免圖集邊界產生 mip 格線。草仍採原本不透明幾何，未改成透明卡片。
- 製作來源 `python3 tools/make_environment_atlas.py`（只用 Python 標準庫，固定 seed）。重建貼圖後需重新匯入。`tools/apply_battlefield_materials.gd` 是手動材質製作工具，正常開啟與執行不呼叫；重跑會取代這批共用材質與場景上的材質指定，請先檢查人工修改。地形產生器重建後也需重新套用材質。
- 模型、碰撞與節點數維持原值；新增貼圖與 shader 會增加材質運算，這次沒有證明手機 FPS 提升。物件的方塊輪廓、重複貼圖及幾何草仍屬初版。

本次材質驗證：headless 匯入、`test_battlefield.gd` 通過；xvfb 渲染產生出生點、全景、廢墟及兩個道具近景，檢視出生點／殘骸／斷牆，無 shader 編譯錯誤。截圖在 `/tmp/walker-material-shots/`，不是手機效能證據。

2026-11-10 材質去重複：每個物件以位置產生固定取樣偏移與方向，混合兩種不同尺寸的同一圖集；牆面使用大片污損遮罩，鏽鐵加入殘漆區與垂直流痕，苔色改為不規則聚集；地表改用不規則草土斑塊、破碎路緣與局部積土。這些只改 shader，沒有改道具排列、模型、貼圖來源或碰撞。局部仍可能辨認重複紋樣，最終效果需真人確認；貼圖讀取比上一版增加，手機效能未測。

## 雙勾索與戰鬥（2026-11-11）

**甩尾（2026-11-12）**：拖行改成繩索。繩長從勾住時的距離開始，只會縮短、不會推人。往錨點的速度照舊加速；橫向速度保留，所以邊跑邊勾旁邊的地面，機體會繞錨點甩出去。拖行中按左右鍵可以加大或反推擺盪，機身會轉向錨點，與滑行方向分開，形成甩尾。放開時保留速度滑行再剎車。中途失去錨點、繩子被擋、撞牆或視窗失焦時都改成剎車；只有越界、機體毀損、回合結束才立即停下。參數在 `walker_combat.tscn` 的 `Combat/Grapple`（Swing 群組）：`steer_acceleration`、`swing_max_speed`、`drag_turn_speed_deg`、`max_drag_time`、`max_swing_deg`。從靜止直線勾正前方時，行為與數字和下段描述相同。

G 從前方兩個發射點射出索釘，最多 45 m；命中地形／重型 scout 時向前拉動玩家，兩索命中同一輕型 scout 時將敵人拉近。玩家衝刺以 45 m/s² 漸進加速，離錨點 4 m 時鬆索，靠慣性越過錨點約 2 m 才開始以 24 m/s² 剎車；開放平地實測完全停下時越位約 8.9 m。拉動中再次按 G 是提早剎車；發射途中按 G 則取消。遮擋、錨點失效、越界、失焦或結束回合會安全斷索；牆面和敵人本體仍會阻擋滑行，冷卻 3 秒。勾索是受碰撞限制的衝刺／拖曳，不是擺盪繩索模擬；錨點上限與速度在 Combat export 調整。

主砲每發 40 傷害，裝填 1.2 秒；白色中心準星是鏡頭目標，綠圈是砲管實際射線。砲彈從 Muzzle 發射，每個物理步掃掠；發射前檢查砲座到砲口的遮擋，防止砲管穿牆後從另一側射出。受擊會有短閃白／畫面紅閃，擊毀有爆炸、倒伏模型與計數。

單局為 300 秒殲滅 3 台 scout：兩台輕型（80 HP／質量 3）、一台重型（120 HP／質量 12）；玩家 100 HP／質量 8。敵人透過保存導航網格巡邏／追擊，確認視線與朝向後預警 0.8 秒再開火，失去視線時搜索最後位置；結算後停止交戰，重試重新載入場景。原 main.tscn 的 12 台仍使用展示用遊蕩模式。

| 編輯入口 | 可調整項目 |
|---|---|
| `scenes/walker_combat.tscn` | 根 Combat 的生命、質量、裝填、砲塔速度、砲口光與音效；`Grapple` 子節點（`scripts/grapple.gd`）的勾索射程／索釘速度／拉動速度／冷卻、pull_acceleration／release_distance、Swing 群組，以及其下的 Launch0／1 發射點、Cable0／1 索線、Pin0／1 索釘 |
| `scenes/combat_projectile.tscn` | 砲彈速度／傷害與可見 tracer；玩家／敵方可覆寫實例數值 |
| `scenes/combat_impact.tscn` | 命中光、音效、半徑與持續時間 |
| `scenes/scout.tscn` | HP、質量；Senses（視野、視角錐、近距察覺、搜索時間、回應隊友）、Weapon（射程、遲滯、預判、散布、傷害、彈速、前搖、連發、冷卻、背面加成）、Movement（速度、換位）；Status、Warning、HitFlash、NavigationAgent（avoidance 半徑 1.4）；battlefield 的 Scout2 實例覆寫成重型數值（`tools/tune_scouts.gd`）。行為見 `scripts/scout.gd` 開頭註解 |
| `scenes/combat_hud.tscn` | Status／Weapon、雙準星、觸控按鈕、DamageFlash、Modal 內任務文字與按鈕版面；全部為保存 Control 節點 |
| `scenes/battlefield.tscn` | Enemies 的位置／朝向、Navigation 的烘焙資源、Projectiles 容器；根 script 的回合秒數與邊界 |

`tools/build_combat_slice.gd` 已執行；既有 CombatHUD 存在時預設停止，正常啟動不生成畫面或烘焙導航。明確以 `-- --overwrite` 重跑會覆寫此批場景與敵人配置，先檢查並保留人工編輯。地圖大改後需重新烘焙 `materials/battlefield_navigation.tres`；製作時只解析 Map 的固定碰撞，不把草與機體算進去。

驗證：`test_combat.gd` 覆蓋雙索輕／重／地形／天空落空／取消、索線粗細、砲彈高速掃掠／牆面／砲管穿牆保護、裝填、導航追擊、視線遮擋、AI 傷害、勝敗超時與實際重載重試；`test_battlefield.gd` 為地圖與邊界回歸。渲染工具：`xvfb-run -a godot --path . --resolution 1280x720 --fixed-fps 60 --script res://tools/capture_combat.gd -- /tmp/walker-combat-shots`。

原移動測試場 main.tscn 的 Arena 仍保留作者編輯的位移；舊 test_walker／test_scouts 的基線問題見 TODO，不能把新戰鬥通過視為那兩組已修復。尚未驗收：手機／手把手感與效能、音效實聽；尚未製作：裝甲穿深／部位損傷、專用轉向／射擊／死亡骨架動畫、多人及手動大幅近戰迴旋。自動近戰見下段。戰鬥圖有重試流程；Esc 目前只釋放滑鼠，沒有暫停。

## 自動刀片與慣性驗證（2026-11-11）

前方約 140°、3.6 m 內且高差不超過 1.8 m 的敵人會觸發自動斬擊；每次前搖 0.12 秒、傷害 30、間隔 0.9 秒，命中時重新檢查範圍與實體遮擋，敵人能趁前搖離開。輕敵被拉進來後會自動銜接刀片，回合結束／玩家死亡時停用。HUD 顯示 BLADES AUTO 或冷卻秒數。

可在 `scenes/auto_blades.tscn` 調 reach／damage／attack_interval／windup_time，Sweeps/LeftSweep／RightSweep 是可編輯的刀光網格，Sound 為合成音效。原模型刀刃與 Hull 合併，現在以機體短幅左右扭身（7°）與刀光表達斬擊，沒有拆分刀片骨架。`tools/add_auto_blades.gd` 已執行，執行遊戲不會重建場景。

慣性與自動近戰採固定物理步；角色在拉動／滑行／剎車期間不套一般移動減速，剎車完成後恢復移動輸入。G 可以提早剎車，越界／失焦／死亡／回合結束仍直接清除危險動量。

- L1：`godot --headless --fixed-fps 60 --path . --script res://tests/test_grapple_inertia.gd`，驗加速、鬆索、越位、漸進停止、G 提早剎車、硬安全取消與牆面碰撞。
- L1：相同指令改用 `res://tests/test_auto_blades.gd`，驗傷害與攻擊間隔、勾索銜接、擊毀計數、牆／背後／高差／前搖離開與結算停用。
- L2：上述兩組加既有 `test_combat.gd` 與 `test_battlefield.gd`。
- 畫面：`tools/capture_dash_blades.gd`（xvfb 與 capture_combat 相同用法），輸出 `/tmp/walker-dash-blades-shots/`。測試與軟體渲染不代替真人手感與手機效能驗收。

## 音效整理（2026-11-11）

使用者提供的素材已裁切、去直流偏移、調整增益與淡入淡出，輸出為 14 個 mono／44.1 kHz Vorbis，合計 200,988 bytes（原始 10,104,955 bytes，減少 98.01%）。啟動／通訊、scout 機槍、命中／爆炸、IK 落腳、移動起始及落地聲已接入；原始檔留在本機，由 Git 與 Godot 忽略。授權署名見 [CREDITS](assets/sound/CREDITS.md)，事件對應、重建與 Git 收錄範圍見 [音效 README](assets/sound/README.md)。

編輯 `default_bus_layout.tres` 的 Movement／Weapons／Impacts／Voice 調整混音；主場景 Radio、walker 的 StepSound／MovementSound、scout 的 GunSound 與 combat_impact 的 Sound 都是保存節點。若明確重建遊戲場景，需再執行 `godot --headless --path . --script res://tools/apply_audio.gd` 補回音效節點，先保留人工編輯。

L2：`python3 tools/verify_audio.py` 驗 Ogg 標頭、時長、雜湊與忽略規則；`godot --headless --fixed-fps 60 --path . --script res://tests/test_audio.gd` 驗匯入、bus、啟動／通訊節流、腳步合併、落地、爆炸尾音及回合結算清理；受影響回歸為 `test_combat.gd`、`test_battlefield.gd`。本次全部通過。尚未實聽或量測手機音效效能。
