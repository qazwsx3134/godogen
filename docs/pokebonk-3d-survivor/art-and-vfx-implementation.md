# PokeBonk 美術與特效實作對照（Godot 4）

本文件記 bundle 可觀察到的美術與即時特效，並對照 Godot 4 的場景與資源做法。數值以 bundle 預設為準；線上 /api/config 可能覆寫戰鬥平衡參數，不會因此改變這裡列出的 shader、模型與畫面參數。截圖是靜態證據，不能證明動畫持續時間；動態數值以 main 行號為準。來源程式為 /Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/raw/pretty/main-B44dxb_5.js。

## UI 視覺語言

**PokeBonk：** CSS 根色票包含黃色 #ffcb05／#f5a700、藍 #2a75bb、海軍藍 #0c1733、紅 #e3350d、墨色 #0a1024、紙色 #f4f0e6、進化粉 #ff4fd8。顯示字型 Chakra Petch，像素字 Silkscreen；另使用 Lilita One、Nunito。裁切角 16px；條紋為 135 度半透明重複線，網點為 7px radial dots。按鈕 3px 深色邊、18px 字、黃色底、紅色 5×5px 硬陰影並 skew(-8deg)；卡片寬 262、高 392、hover 上移 12px 並放大 1.05；選角卡紙底網點、黃邊與紅硬陰影。卡列間距 26px。波次橫幅置中約 top 21%，Boss 橫幅約 top 22%，一般 banner 約 top 26%、字級 50px，使用深色斜切面板（css::root、css:.btn、css:.cards、css:.card、css:.char-card、css:.banner、css:.wavein、css:.bossin、css:.tchip）。

HUD 由左上玩家 portrait、HP／XP／Mega 條，中央計時與波次提示、右上小地圖、左下招式槽、右下道具／能力槽構成；DOM 結構可參考 main:23972-23980，完整版面以截圖為準。

**Godot 4 對應：** 建立 UI Theme 與字型 Theme resource，將背景、邊框、硬陰影做成可編輯的 Control scene／StyleBoxFlat；斜切面以 Polygon2D 或 CanvasItem shader 畫面板，文字與互動按鈕仍保留獨立 Control。卡片用固定尺寸 item scene、GridContainer／HBoxContainer 排列；HUD 分成 anchors 定位的 portrait、bars、wave banner、minimap、move slots 與 item slots。網點與斜紋做成重複 Texture2D 或 shader uniform，顏色放 Theme/resource，避免在 GDScript 建整個版面。

**截圖對照：** [05-runsetup.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/05-runsetup.png) 顯示開局設定；[12-levelup.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/12-levelup.png) 顯示三選卡排版；[bs3.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/bs3.png) 可對照預設新卡 .c2；[09-ingame-0s.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/09-ingame-0s.png) 顯示實際 HUD 位置。

## 3D 著色、描邊與 Mega／Gmax

**PokeBonk：** 樹木與岩石使用 MeshToonMaterial 並共享 gradient map（main:8566、8645）；葉片材質以 MeshToonMaterial、alphaTest 0.45 加 onBeforeCompile 貼圖混色，三階 gradient 值為 90／170／255，採 nearest filtering（main:8035-8054）。全畫面描邊是深度紋理後處理：厚度 1px、色 #140c1c、強度 0.9，以深度 Laplacian 抽邊（main:31955-31998）。Always see my Pokémon 預設開啟；獨立重繪玩家 silhouette，再以 12 個方向擴張成暗色 2.6px 外圈與 4.2px 淡色輪廓，讓角色壓在草、特效與閃光之上（main:5387-5400、5642-5648、32175-32275、34490-34493）。Mega 時用 xm(charId) 取代模型 root，結束時切回；模型目錄含特定 Mega 與 Gmax（Gengar、Snorlax）變體（main:16250-16435、27381-27392）。

**Godot 4 對應：** 角色與環境 MeshInstance3D 使用 ShaderMaterial 的 ramp/gradient lookup 做 toon 光照；alpha clip 以 shader discard 或透明遮罩重現。一般描邊可用 SubViewport 深度邊緣 shader；Always visible 模式另用角色專用 viewport／render layer，呈現角色 silhouette 與輪廓 pass。Mega／Gmax 各做可編輯 PackedScene 子模型，以角色資料映射切換 MeshInstance3D 或替換模型根節點；不要在每次進化時重建整個 UI／角色樹。

**截圖對照：** [09-ingame-0s.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/09-ingame-0s.png) 可見草叢遮擋情境下的角色亮邊；[p00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p00.png) 與 [p05.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p05.png) 可對照場景輪廓。[c0.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/c0.png) 拍到 Mega 觸發瞬間：「MEGA PIKACHU GIGANTAMAX」橫幅（線上值 +80%）、放大的 Gmax 模型、暖色閃光與「+2.6s Mega」浮字；[m3.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/m3.png) 左下是變身中的模型。模型切換的過程（逐格）仍無影格。

## 光照、霧、天空與後處理

**PokeBonk：** 半球光天空色 #d6ecff、地面色 #6a8f4a、強度 1.5；方向光色 #fff1dc、強度 2.3，陰影圖 2048²、相機範圍 ±40、near 1／far 160、bias -0.0005、normalBias 0.04（main:8801-8817）。天空 shader 由 top #3d8ef0、mid #9fd8ff、bottom #e9f7ff 漸層；另有 26 組雲團放在高度 45–60（main:8819-8860）。模式 theme 會變更霧色與環境色（main:8762-8800）。影片預設 grade 0.4、tiltShift 0.1、bloom 1（main:5387-5408）。

後處理鏈順序是 Scene render → depth outline → tilt-shift → bloom → finish → OutputPass（色調映射／輸出色彩空間）；Bloom 初始 strength 0.55、radius 0.3、threshold 2.4（main:32139-32165）。Outline uniforms：厚度 1、#140c1c、強度 0.9（main:31955-31998）。Tilt-shift uniforms：focus 由相機距離傳入，radius = amount × 14 × height/1080，水平與垂直各 blur 一次（main:32001-32074）。Finish uniforms 預設 aberration 0、vignette 0.35、edgeAmount 0、brightness 1、saturation 1、tint (1,1,1)、grade 0；動態套入環境 tint、grade、色差、暗角與高光壓縮（main:32090-32124、32301-32314）。


各段的材質 uniform／動態輸入如下；初始化值與 runtime 覆寫分開判讀：

| Pass | uniform／參數與來源 |
|---|---|
| Scene render | scene、camera；半浮點 render target、samples=4，保留 depthTexture 供後續兩段使用（main:32139-32159）。 |
| Outline | tDiffuse、tDepth、resolution；cameraNear=0.1、cameraFar=400 為模板值，執行時依相機更新；thickness=1、color=#140c1c、strength=0.9×outline 設定（main:31955-31998、32311）。 |
| Tilt-shift | tDiffuse、tDepth、dir；cameraNear／cameraFar、focus；radius=amount×14×height/1080；dir 分別為 (1/width,0)、(0,1/height)（main:32001-32074）。 |
| Bloom 高光擷取 | tDiffuse、luminosityThreshold=2.4、smoothWidth=0.01、defaultColor=黑、defaultOpacity=0（main:31567-31575、31638-31645、32155）。 |
| Bloom 五級模糊 | colorTexture、invSize、direction、gaussianCoefficients；五級 kernel radius 3／5／7／9／11，逐級縮半並各做 X/Y blur（main:31648-31653、31751-31761）。 |
| Bloom 合成／加回 | blurTexture1…5、bloomStrength、bloomRadius=0.3、bloomFactors=[1,0.8,0.6,0.4,0.2]、bloomTintColors=五組白色；內部 additive blend 以 tDiffuse／opacity 複製。runtime strength=(alwaysVisible ? 0.4 : 0.55)×bloom 設定（main:31304-31306、31655-31677、31735-31747、32312）。 |
| Finish | tDiffuse、aberration=累積衝擊、vignette=0.35×設定、edgeColor／edgeAmount、brightness、saturation、tint、grade。模板 edgeColor=黑、edgeAmount=0、brightness/saturation=1、tint=(1,1,1)、grade=0；grade 的使用者預設為 0.4（main:32090-32124、32301-32306）。 |
| OutputPass | tDiffuse、toneMappingExposure（模板 1，執行時取 renderer 值）；依 renderer 設定選 tone-mapping define 與 SRGB_TRANSFER，執行輸出轉換（main:31837-31949）。 |

**Godot 4 對應：** 用 WorldEnvironment 設 ProceduralSkyMaterial、Fog、色調與 Glow；DirectionalLight3D 搭配 WorldEnvironment ambient light。Godot 的 Glow 對應 bloom；深度描邊、tilt-shift、色差及 finish grade 可做 CompositorEffect 或 SubViewport shader，逐段暴露 uniform，保留與原鏈相同的順序。陰影 map 與相機範圍按品質資源切換。主場景和環境值放在 Environment/Resource，模式只替換 preset。

**截圖對照：** [08-settings.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/08-settings.png) 顯示影像與品質控制；[09-ingame-0s.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/09-ingame-0s.png) 顯示實際天空、霧與光照。

## 地形、草、水與 Props

**PokeBonk：** Fields 約 300 樹、260 灌木、150 岩石、45,000 草、1,600 花；Vale 約 240／200／130／38,000／500；Quarry 約 70／90／420／14,000／150（main:8234-8308）。草以七頂點 blade 批次實例化，位置經地形／坡度雜訊篩選；頂點以 sin(uTime×1.8 + x×0.18 + z×0.11)×0.5 和第二項 sin(uTime×3.1 + x×0.7)×0.18 搖擺，並依高度加權位移（main:8665-8735）。未找到草 blade 受角色碰撞或被腳步壓倒的互動；可確認的是草顯示開關（main:5400、5515）。地形用 noise／palette 生成；樹以最多 6,000 次候選位置嘗試、岩石最多 3,000 次嘗試有效擺點，再以 InstancedMesh 批次呈現；岩石採位移低多邊形造型並提供碰撞（main:8370-8379、8554-8580、8635-8663）。水 shader 混合淺／深水、雜訊與 foam，透明度 0.7–0.92（main:8452-8502）。

**Godot 4 對應：** 將地表做成可編輯地形 scene/resource，依模式載入地形高度、材質與 prop 擺放資料。大量草用 MultiMeshInstance3D 或 GPUParticles3D，shader 以 INSTANCE_CUSTOM/位置和 TIME 做同類 sway，先用 density/resource 控制數量；若要踩草互動，另實作角色周邊低密度碰撞或 shader 壓伏區，這是移植設計，不是 bundle 已有行為。樹與花用 MultiMesh；可互動岩石用獨立 prop scene 與 CollisionShape3D。水面用 ShaderMaterial 控制深淺色、foam、alpha。

**截圖對照：** [09-ingame-0s.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/09-ingame-0s.png)、[p00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p00.png)、[p05.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p05.png) 可比對草、樹、岩石密度；靜態截圖無法驗證草擺動與碰撞互動。

## 逐招特效

**共用做法：** 貼圖由 /vfx/{name}.png 載入並設 color space（main:5653-5658）。每個貼圖系統以 pool 重用，additive 粒子容量 1,600、一般混合容量 900；粒子記錄位置、速度、生命期等資料（main:5785-5824）。Decal plane depthWrite 關閉且預設 additive；ring、telegraph、pillar 與 beam 各由平面或幾何建立（main:6086-6255）。以下寫的是代表招，不表示所有招共用同一資產。

**投射物與持續射線：** Flamethrower 基礎火球以半徑 0.35×size、壽命 0.55×duration、pierce 99；進化火球壽命 1.6、半徑 0.6×size、傷害×2，命中後爆裂並留 2.5 秒燃燒池、每 0.35 秒 tick（main:13371-13504）。槍口為 muzzle_02（壽命 0.1）；進化爆炸用 star_09、圓環與煙粒子，燃燒池以非 additive 的 scorch_01 地面 decal 表示，decal 與池均留 2.5 秒（main:13405-13413、13464-13488）。Hydro Pump 進化是長 34m 的 billboard beam，每第三輪射擊追加此 beam；m=1.6×size，外層 trace_06 寬 3.2×m、壽命 0.35，內層 trace_01 寬 1.5×m、壽命 0.3，再噴 14 個 smoke_05；演出觸發 shake 0.25、post kick 0.3（main:13506-13575）。Godot 可用 Sprite3D／QuadMesh billboard，加粒子 pool；火焰地池用可回收 decal scene。

**環形擴散與落點光柱：** Surf 以 circle_05 粒子形成 annulus，最大範圍 11×size，擴散速度 17×speed，持續到波緣到達；進化後反向回波並有終段光柱／衝擊（main:14256-14330）。Judgment 落點半徑 2.6×size，預告 0.45 秒；trace_06／trace_01 從高度 +22 落下，搭配星光與圓環；進化會生成三道旋轉 trace_07 光束（main:13880-13957）。telegraph 使用 circle_02、circle_05，選配 magic_02；pillar 為 additive cylinder 加 scorch decal（main:6139-6207）。Godot 對應用 MeshInstance3D 圓環／圓柱、透明 additive ShaderMaterial、Timer 控制 warning 與落下節點。

**環繞與龍捲風：** Twister 效果物件壽命 3×duration，每 0.25 秒造成一輪攻擊；周圍生成 5 個 twirl_01–03 quad，每片壽命 0.12、角速度 14，進化招另吸引敵人（main:13780-13878）。Godot 用環繞 Node3D + billboard quad scene，固定 effect pool，粒子 shader 控制旋轉及淡出。

**近戰弧與斬擊：** 斬擊素材族為 slash_01–04，搭配 trace_01／trace_07 平面射線；代表使用位置 main:9444、9895、10181、10931、13272。Bundle 中招式專屬的弧面多邊形頂點、統一斬擊持續時間未找到；不可從貼圖名字推定所有近戰招都使用同一幾何。Godot 可用 ArrayMesh 製作弧帶／扇形 MeshInstance3D，或使用 billboard texture，讓各招 scene 明確指定弧長、材質與壽命。

**連鎖閃電：** Thunderbolt 先以 lightning 折線連敵，再用 spark_06 beam（寬 2.2、壽命 0.18）與半徑 2.2、壽命 0.3 的 ring；進化招每 max(0.8, 2.2/角色 attackSpeed) 秒對目標落垂直 beam，使用 spark_06、trace_01、magic_04 decal 和非 additive scorch_02（壽命 1.5 秒）（main:13312-13368）。Godot 可由多段 ImmediateMesh／ArrayMesh 畫閃電折線並以 Tween 淡出，命中節點再播放共用 ring/decal scene。

**截圖對照：** [p00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p00.png) 與 [p05.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p05.png) 顯示實戰場景和拾取物，但不是逐招特效驗收影格；提供截圖中未找到可逐一確認上述 beam、ring、melee arc 生命週期的畫面。

## Boss 預告與危險區

**PokeBonk：** Slam 在地面標半徑 7.5m 紅圈，預告 1.15 秒後落下，落地再做半徑 8m 衝擊（main:26693-26725）。Charge 先畫長 30m、寬約 Boss 半徑×2 的方向線，預告 0.9 秒後以 40m/s 衝刺 0.75 秒，結束觸發落點圈（main:26727-26774）。Ghost 會傳送並標多個雷擊區；不同 Boss 顏色取其招式色（main:26727-26774）。圈／線由 circle_02、circle_05 或 beam 平面實作；可見共通 decal/pillar 實作（main:6139-6207）。共用 strike 在倒數 t≤0 時判定一次傷害後從 strikes 陣列移除；不能把地面 decal 的可見時間當成連續傷害區（main:26840-26857）。所有 Boss 共用的額外殘留傷害時間與完整色表未找到。

**Godot 4 對應：** Telegraph 做成獨立 PackedScene，含地面 Mesh、alpha 材質與 Timer；先鎖定位置／方向，倒數後才呼叫傷害判定。危險地面 decal 設明確 expire timer，不要依賴粒子壽命暗示仍有傷害。不同招式 scene export radius、warning_time、color、dash_speed、dash_time。

**截圖對照：** [boss00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/boss00.png) 與 [boss01.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/boss01.png) 是 Boss 結果／倒下畫面，未找到正在顯示 slam circle 或 charge line 的截圖。預告參數以程式為證。

## 命中、受擊、死亡、拾取、升級與 Mega 時間軸

**PokeBonk：**

| 時間／事件 | 實作與參數 |
|---|---|
| 強命中／暴擊，0–0.22s | 暴擊、單次傷害 >敵 maxHp 30% 或 Boss 命中，可觸發 hit/spark 和半徑 1.8／暴擊 2.6 的 ring（life 0.22）；microStop 普通 0.03s、暴擊 0.045s；shake 0.07／0.14、post kick 0.12／0.3、暴擊 FOV punch 1.6。這組較重效果每 update 最多 14 次，microStop 預設間隔 0.09s（main:30338-30342、30378-30413）。 |
| 敵人受擊變形／閃色 | 普通 flash 0.12s、強命中 0.16s；以 flash/flashMax 的平方做受擊抬升、旋轉和 XZ 放大／Y 壓縮，再由批次模型 n.set 呼叫每個 mesh 的 setColorAt 更新 instance color；有 slowT 時改慢速色（main:30378-30379、26880-26897；assets:32160-32171）。 |
| 玩家受擊 | 一般受擊 iframes 0.4s、hurtT 0.25s、紅色數字／8 個紅粒子（life 0.2–0.35）、shake 0.2、hitStop 0.05s，呼叫 model.hurt。Focus Sash 救命後 HP=1、iframes=2s，另有粉紅閃屏／圓環／光柱（main:27473-27504）。 |
| 一般擊殺 | poof；microStop 0.022s、shake 0.035；0.25s 內連殺到第 6／14 隻時 FOV punch 2.2／4、post kick 0.25、shake 0.18（main:30505-30520）。 |
| 菁英／Boss 死亡 | 菁英 hit stop 0.12、shake 0.3、post kick 0.3；Boss 大型星爆 60 粒、半徑 16、壽命 0.4–1.3s，光柱半徑 3、高 40、壽命 1.2s，hit stop 0.4、flash 0.7，並大量掉落（main:30454-30473）。 |
| XP 拾取 | 四級 XP 門檻 ≥30／≥10／≥3／其餘，色 #ffca28／#ab47bc／#66bb6a／#4fc3f7，size 0.42／0.36／0.30／0.24；render 的 y=基準+sin(t×4+spin)×0.08、旋轉 3rad/s。吸附速率 max(10, 累積速度)，累積速度每秒 +45、距離 <0.9 收取；落地前重力 20、碰地 vy 歸零（main:26915-26920、27137-27168、27253-27265）。 |
| 升級 | 預設新卡 .c2：c2in 0.45s，三卡延遲 0.05／0.18／0.31s；hover transition 0.1s。舊卡 .card-inner：flip 0.7s，延遲 0.12／0.28／0.44s；.card transform transition 0.12s（main:25119-25122、25135-25139；css:.c2、css:.card-inner、css:.card）。 |
| Mega 開始 | hit stop 0.7s、FOV +14、post kick 1.5、白閃 0.9；60 顆 star_04／magic_05 粒子壽命 0.45，地面 magic_03 decal 的 size 由 4 擴至 26、壽命 0.9，light_03 為 size 6→22 的發光粒子、壽命 0.6，另有 5 個圓環與半徑 2.2、高 40、壽命 1 的光柱；範圍傷害半徑 14（main:30745-30837）。 |
| Mega 持續／結束 | 每秒脈衝；基礎持續 20s，額外充能 e 延長 e×12s、剩餘時間上限 40s；bundle 碎片延長 1.68s、Classic/Normal 線上碎片延長 2.64s；到期切回模型並 poof（main:3389-3397、30745-30760、30970-31004）。 |

拾取物材質顏色依 XP 價值分四級；獨立特殊拾取物以 sin(t×3)×0.1 上下漂浮、旋轉 2rad/s；寶箱 y=基準+abs(sin(t×2+bob))×0.15、光柱 opacity=0.18+sin(t×3+bob)×0.07（main:27170-27195）。這些數值與 XP 的 MultiMesh 式 render 不同。寶箱價格和錢包付款規則見 [Pokébola升級資料](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/upgrades.md) 與 bundle 分析。

**Godot 4 對應：** 將 hit、poof、XP、chest、level-up、Mega 分成 scene/resource，使用 AnimationPlayer/Tween 管理時間軸；命中事件傳入暴擊與傷害類型，由共用 FX 池生成 Ring/Label3D/Spark。XP 可用 MultiMesh + attraction shader 或逐顆 scene pool；Mega 用動畫軌切換模型、相機、閃白與環境效果，結束時將場景狀態還原。保留數值為 export 欄位，便於在編輯器調整。

**截圖對照：** [12-levelup.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/12-levelup.png) 可對照升級卡；[p00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p00.png) 與 [p05.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p05.png) 可見掉落物。未找到可驗證 hit-stop、死亡粒子或 Mega 各階段時長的連續影格。

## 天氣粒子

**PokeBonk：** 每種天氣以 n、shape、size、vel、color、alpha、sway 設定粒子；雨 2,400 顆往下 42、雪 1,500 顆、沙塵 2,000 顆、風 700 顆。每個粒子由位置加 velocity×time 和 sin sway 更新，在相機附近 70×34×70 空間回繞；shape 0 圓片、1 斜雨線、2 橫向風沙條。天氣 tint 與 fog 漸變，buff/nerf 依 type id 影響屬性；參數清單見 [天氣資料](/Users/peter/repo/godot/godogen/docs/pokebonk-3d-survivor/data/weather.md)（main:6380-6442、6461-6529、6540-6688）。

**Godot 4 對應：** 以 GPUParticles3D／粒子 shader 做相機中心粒子場，粒子 shader 讀速度、尺寸、alpha、sway、shape atlas；wrap 時重定位到視野另一側。Environment 的 fog 與 tint 用 tween 交叉淡入，天氣 modifier 只改遊戲資料，不將戰鬥規則硬寫進視覺 shader。

**截圖對照：** [m1.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/m1.png) 顯示不同遊戲時間的場景色調；[09-ingame-0s.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/09-ingame-0s.png) 有 HUD 天氣區。靜態畫面無法確認粒子速度與密度。

## 相機效果

**PokeBonk：** 基礎 FOV 65°，FOV punch 以指數平滑係數 6 回零；shake 累積上限 1.2、每秒衰減 2.5（main:4901、30024-30090、6304-6306、6368）。hitStop 時間乘以 impact 設定值（main:30338-30354）。通用閃屏是 DOM overlay，CSS 動畫 0.55s、600ms 後移除；強度=(alwaysVisible ? a×0.45 : a)×flash 設定（main:24976-24983；css:.flash），供 Mega、致命保護等事件使用。一般玩家受擊另有 model.hurt、紅粒子和短無敵，不能一律算成這個閃屏。post kick 每次加 e×aberration 設定、累積硬上限 1.5，並每秒衰減 3；finish shader 以取樣紅藍通道 offset 做色差（main:32109-32119、32172-32174、32300-32302）。

**Godot 4 對應：** Camera3D FOV 與位置由 Tween/AnimationPlayer 驅動 punch/shake；hit stop 以遊戲時間 scale 或專用 simulation delta 管理，保留 UI 時鐘；閃屏放 CanvasLayer ColorRect；色差與 vignette 做 CompositorEffect shader，將設定值當 uniform，效果結束後插值回零。

**截圖對照：** [p00.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p00.png) 與 [p05.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/p05.png) 是靜態實戰畫面，沒有可量測鏡頭位移或色差的連續影格；相機時序以 main 行號為準。

## 效能分級

**PokeBonk：** 初始設定為陰影 high、resolution 1、草開、autoRes 開、FX normal；低／普通／高 FX cap 分別是 decal/beam 120/90、300/220、700/500；off 不設上限（main:5387-5408、5507-5528、5650）。陰影選項 off/low/high；解析度 0.75／1／1.5；低陰影使用 1024、高用 2048 shadow map。FX cap 限制地面 decal 和 beam 系統（main:5497-5525、34477-34487）。Auto-resolution 在持續 frame time 高於約 29ms 時下降解析度並裁掉部分 render feature；outline/bloom 也依 cut 層級停用（main:33725-33727、34501-34505、32311-32314）。無設定檔的行動裝置 fallback 為 low shadows、0.75 resolution、grass off、FX low、tiltShift 0、aberration 0、ambient off、bloom 0（main:5439-5448）。

**Godot 4 對應：** 用 QualitySettings resource 對映 shadow atlas、viewport scale、MultiMesh 草密度、粒子上限、Glow、outline 與後處理；autoRes 依 frame time hysteresis 逐級改設定，避免每幀震盪。低階 preset 將陰影 atlas 降至 1024、viewport scale 0.75、關閉草與環境粒子，並限制 decal/beam pool；所有設定可在選項 scene 直接編輯。

**截圖對照：** [08-settings.png](/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk/shots/08-settings.png) 顯示影像、陰影、解析度、草與效果上限控制；截圖只能證明控制項，實際降級條件由程式參數證明。

## 已標示未找到

- 草 blade 的角色碰撞／踩踏互動：未找到。
- 通用 Boss 危險區殘留時間與統一顏色表：未找到。
- 所有近戰招式共用的弧面幾何與固定生命週期：未找到。
- 能逐格驗證命中、受擊、死亡、Boss telegraph、Mega 和模型切換時序的截圖／錄影：未找到。
