

六、電影鏡頭切換：不要直接把 Camera3D.current 改掉就結束
Godot 同一個 Viewport 只有一台 Camera3D 能成為目前的活動攝影機，make_current() 可以切換活動攝影機，但不會自動提供我們所需的電影式過渡。

Godot Engine (stable) documentation in English




所以在多 Camera Rig 的架構中，需要一台 BlendCamera。
鏡頭切換流程
探索模式
   │
   │ Cinematic Request
   ▼
保存目前探索鏡頭狀態
   │
   ▼
BlendCamera 接管輸出
   │
   ├── Position Interpolation
   ├── Rotation Interpolation
   └── FOV Interpolation
   │
   ▼
CinematicCamera 接管
   │
   │ 演出結束
   ▼
BlendCamera 再次接管
   │
   ▼
返回 ExploreCamera


這有一個特別重要的優點：

探索相機可以在電影演出期間保留自己的 Yaw、Pitch 和 Zoom。

例如原本玩家將攝影機轉到角色背後 135°，並縮放到距離 6。

電影演出結束後，玩家應該可以自然回到原本的探索角度，而不是每次都被重設成世界北方、固定距離 8。
Godot 的 BlendCamera 原型
以下程式是簡化的平滑切換控制器，可放在 CameraDirector 節點上。

extends Node

@export var blend_camera: Camera3D

var target_camera: Camera3D
var from_transform: Transform3D
var from_fov: float

var elapsed: float = 0.0
var duration: float = 0.5

func blend_to(
    next_camera: Camera3D,
    seconds: float = 0.5
) -> void:
    var active := get_viewport().get_camera_3d()

    if active == null or next_camera == null:
        return

    from_transform = active.global_transform
    from_fov = active.fov

    target_camera = next_camera
    duration = maxf(seconds, 0.001)
    elapsed = 0.0

    blend_camera.global_transform = from_transform
    blend_camera.fov = from_fov

    blend_camera.make_current()

func _process(delta: float) -> void:
    if target_camera == null:
        return

    elapsed += delta

    var t := clampf(elapsed / duration, 0.0, 1.0)
    var eased := t * t * (3.0 - 2.0 * t)

    # 內含旋轉插值
    blend_camera.global_transform = \
        from_transform.interpolate_with(
            target_camera.global_transform,
            eased
        )

    blend_camera.fov = lerpf(
        from_fov,
        target_camera.fov,
        eased
    )

    if t >= 1.0:
        target_camera.make_current()
        target_camera = null



這段原型有幾個設計特點。

Transform3D.interpolate_with() 讓位置與旋轉一起過渡，避免單純對 Euler 角度插值造成不自然的旋轉。來源姿態在開始切換時保存，而目標攝影機的位置則在過渡期間持續讀取，因此可以追蹤仍在移動的角色。

但它尚未處理碰撞、焦點距離、投影類型不同、鏡頭優先權與時間軸中斷等情況。因此比較適合先用於兩台同為 Perspective Projection 的攝影機。

真正整合時，我會再增加 CameraTransitionData、中斷處理，以及 Transition 過程的遮擋檢測。
鏡頭切換時，8 方向 Sprite 怎麼辦？
這裡不需要手動通知每個角色「電影鏡頭開始了」。

只要 Direction Controller 每次依照目前真正啟用的 Camera3D 計算觀看方向，就能自然配合 BlendCamera。

因此整個畫面更新的概念是：
CameraDirector
    │
    ▼
更新目前畫面使用的 Camera
    │
    ▼
DirectionController
    │
    ▼
選擇正確方向的 Sprite
    │
    ▼
Rendering


這裡要避免物理更新與渲染更新造成的一幀差異。特別是角色使用 _physics_process() 移動，而相機在 _process() 更新時，需要一致的插值策略。

Godot 提供 Physics Interpolation，用來解決物理更新頻率和畫面更新頻率不同造成的抖動，但使用時需要避免在錯誤的更新階段混合修改可插值的 Transform。

Godot Engine (stable) documentation in English




七、比較完整的場景樹
如果把角色、鏡頭、環境與遮擋系統放在一起，我會用下面的結構作為研究用場景樹。

不是要你直接照這個架構開發，而是先把各個系統的責任邊界整理清楚。
GameWorld (Node3D)
│
├── Environment
│   ├── Terrain
│   ├── Buildings
│   │   └── House01
│   │       ├── SolidGeometry
│   │       ├── Roof
│   │       └── CameraOccluder
│   ├── Vegetation
│   └── WorldEnvironment
│
├── Characters
│   ├── Player (CharacterBody3D)
│   │   ├── CollisionShape3D
│   │   ├── VisualRoot
│   │   │   ├── SpritePivot
│   │   │   │   ├── BodySprite3D
│   │   │   │   ├── HairSprite3D
│   │   │   │   └── WeaponSprite3D
│   │   │   └── GroundShadow
│   │   ├── DirectionController
│   │   └── CameraFocus (Marker3D)
│   └── NPCs
│
├── CameraSystem
│   ├── CameraDirector
│   ├── ExplorationRig
│   │   └── YawPivot
│   │       └── PitchPivot
│   │           └── SpringArm3D
│   │               └── ExploreCamera
│   ├── CinematicRig
│   │   └── CinematicCamera
│   ├── BlendCamera
│   ├── OcclusionController
│   └── CameraEffects
│
└── UI (CanvasLayer)


這個設計有幾個值得保留的原則：
系統	只需要知道	不應直接管理
Character	自己的位置、邏輯朝向、目前動作	相機模式
DirectionController	世界朝向、目前相機方向	CameraDirector 的狀態
CameraDirector	目標、Camera Rig、鏡頭請求	角色的 SpriteFrames
OcclusionController	相機、目標和遮擋物件	角色動畫
Environment	幾何、材質、碰撞與遮擋標記	鏡頭切換流程
對長期開發而言，這種切分可以減少很多循環依賴。

八、我會如何驗證整套架構？
我們先不用製作戰鬥，只要做一個 3D 測試場景即可。
Camera + Sprite 技術驗證
下列項目可用於檢查整體方案是否適合進一步開發。
驗證進度

0 / 8



[ ] 角色在固定位置，相機水平旋轉 360°
[ ] 相機縮放時，Pixel Sprite 保持清晰
[ ] 8 方向 Sprite 切換不會導致動畫重播
[ ] 人物經過樹木與建築後方，遮擋物件正確淡出
[ ] 相機靠近牆壁時，不穿透地形
[ ] 電影鏡頭切換時，Sprite 方向持續正確
[ ] 電影鏡頭結束後，恢復探索角度與縮放
[ ] 手機上旋轉相機與大量透明物件時，沒有明顯掉幀
這是測試規劃清單，勾選只代表你的驗證紀錄，不表示已自動執行 Godot 測試。
最值得注意的三個風險
第一個是大幅度 Pitch。 8 方向 Sprite 解決的是水平方位，不是從頭頂俯看或從地面仰拍的人物變形。未來可能需要補充俯仰角素材或設計專用電影鏡頭素材。

第二個是鏡頭穿越遮擋物。 探索相機可透過 SpringArm 處理，但電影相機不一定會使用相同的碰撞策略。不能假設電影演出時的相機路徑永遠安全。

第三個是 Pixel Sprite 與高解析度場景的融合。 當相機縮得很近時，背景可能依然精緻，但角色像素會明顯放大。這不一定是缺點，但需要提早決定角色在特寫時應該呈現什麼效果。

九、目前的技術判斷
到這裡，我認為我們已經有一個相當清楚的比較基準。
技術問題	最值得先驗證的候選方式
探索自由旋轉	Orbit Camera + SpringArm3D
8 方向人物	AnimatedSprite3D + Direction Controller
人物紙娃娃	共用方向與動畫時間的多 Sprite 圖層
建築與地形遮擋	Camera Collision + Occlusion Fade
電影鏡頭切換	CameraDirector + BlendCamera
大量運鏡需求	和單輸出 Virtual Camera 架構對照測試
我目前不會建議直接投入完整地圖製作，而是先用一個小場景比較 B、C 兩種 CameraDirector 架構，因為這會直接影響之後所有場景、角色和動畫的設計。
下一個值得深入的技術分歧
探索鏡頭的「自由旋轉與縮放」，是否還需要自由改變俯仰角，甚至貼近地面觀看角色？

這會決定我們只需要 RO 式的 8 方向 Sprite，還是必須研究更複雜的 Directional Sprite + Pitch Variants。

深入 360° Yaw + 大範圍 Pitch 的 Sprite 與相機技術

深入建築、樹木、室內屋頂的遮擋與 Shader

比較多鏡頭 CameraDirector 與單輸出 Virtual Camera 的完整 Godot 實作

設計可直接交給 Codex 實作的 Camera + Sprite 技術原型規格

深入下一項技術
這樣我們就能持續把 RO 的成熟渲染概念延伸到現代 HD-2D，而不是一開始就把角色、美術、相機與戰鬥全部綁在一起。
















深入 360° Yaw + 大範圍 Pitch 的 Sprite 與相機技術

深入建築、樹木、室內屋頂的遮擋與 Shader












處理時間為 3m 59s


規劃技術方案



這一輪我會分成兩條技術線：第一條是 360° Yaw 與大幅 Pitch 時，如何避免 Sprite 變成紙片、方向跳幀或穿模；第二條是相機穿越建築、樹冠和室內屋頂時，如何用遮擋偵測、材質淡出與 Shader 保持角色可見。我會用 Godot 4 的實際節點、座標計算和程式範例來拆解。








核對實作細節


整合相機視角與穩定遮蔽系統


已搜尋 2 個網站













Godot 4.6 技術研究：360° Yaw × 大範圍 Pitch × 建築與樹木遮擋
延續《The Severed Gods》HD-2D 美術與《仙境傳說 Online》Sprite-in-3D 技術研究

我們現在要解決的其實是兩個相互關聯的問題：
1. Camera / Sprite： 攝影機可以 360° 繞著角色旋轉，也能大幅仰拍、俯拍，但像素角色不能看起來只是一張薄紙。
2. Occlusion / Visibility： 攝影機轉到建築、樹木或屋頂後方時，既要保留 3D 世界的空間感，也不能讓玩家失去角色、敵人與戰鬥目標的視線。
我認為應該建立一個共同的研究架構：
Camera Director
Yaw、Pitch、Distance、FOV、電影鏡頭
Sprite View Resolver
方向、俯仰、動畫與 Billboard

Occlusion Resolver
射線、遮擋物、屋頂、淡出


Unified 3D Rendering
3D 場景 + 2D Sprite + 光影 + VFX

這裡先確認一個對手機開發非常重要的限制：Godot 的 GeometryInstance3D.transparency 雖然能快速讓物件淡出，但官方文件指出，這個屬性只在 Forward+ 有效，Mobile 和 Compatibility 渲染器會忽略它。

Godot Engine (4.x) documentation in English




因此屋頂或樹冠淡出不能單純依賴這個屬性。若以手機為目標，就需要考慮材質 Shader、Alpha Scissor、Alpha Hash 或直接切換可見性。

一、360° Yaw 與大範圍 Pitch：先拆開兩種旋轉









Yaw：水平環繞
攝影機可以繞角色旋轉一整圈，看到正面、側面與背面。









Pitch：垂直俯仰
攝影機可以從低角度仰拍，逐漸升到接近角色頭頂的俯視鏡頭。

這兩種運鏡需要分開處理。

Yaw 可以藉由切換 4、8 或 16 方向 Sprite 解決大部分外觀問題。

Pitch 比較困難，因為你需要的已經不只是不同方向的人物，而是不同高度的視角。例如玩家從角色頭頂往下看時，原本的正面 Sprite 根本沒有繪製頭頂、肩膀與腳部的透視關係。
1.1 鏡頭座標如何計算？
Godot 以 Y 為垂直軸。假設 Camera 圍繞 Focus 轉動，可以將球面座標換算為世界座標：
\[
\begin{aligned}
x &= r\cos(p)\sin(y)\\
z &= r\cos(p)\cos(y)\\
h &= r\sin(p)
\end{aligned}
\]

其中 \(y\) 是 Yaw、\(p\) 是 Pitch、\(r\) 是攝影機距離。
3D Orbit Camera 幾何示意
Yaw — 水平旋轉

45°




Pitch — 垂直角度

38°




概念投影示意，展示 Yaw 與 Pitch 如何共同影響 Camera 相對角色的位置。
1.2 Godot Orbit Camera 範例
這是可以直接用來建立基礎原型的 GDScript。先不加入碰撞與建築遮擋，確保兩種旋轉正確。

extends Camera3D

@export var focus: Node3D
@export var distance := 8.0
@export var smooth_speed := 10.0

var yaw := deg_to_rad(45.0)
var pitch := deg_to_rad(35.0)

func _process(delta: float) -> void:
    if focus == null:
        return

    # 避免正上方、正下方 look_at 奇異點
    pitch = clampf(
        pitch,
        deg_to_rad(-35.0),
        deg_to_rad(85.0)
    )

    var direction := Vector3(
        cos(pitch) * sin(yaw),
        sin(pitch),
        cos(pitch) * cos(yaw)
    )

    var target := focus.global_position
    var desired_position := target + direction * distance

    var weight := 1.0 - exp(-smooth_speed * delta)

    global_position = global_position.lerp(
        desired_position,
        weight
    )

    look_at(target, Vector3.UP)



這個範例的 Pitch 範圍是實驗設定，不是引擎限制。正上方或正下方接近 90° 時，Yaw 的定義會變得不穩定，look_at() 也需要處理 Up Vector 的退化問題。

正式 Camera Director 還需要在運鏡時分別插值位置、旋轉和 FOV，避免目標快速移動時出現突然轉向。

二、Sprite 如何配合兩個角度？
我認為最值得研究的是 Multi-Angle Impostor。

Impostor 在圖形技術中，是利用 2D 圖像近似呈現 3D 物件的方法。我們可以讓角色依照相機角度，切換不同視角預先產生的 Sprite。

不必把它限制在 RO 的八方向。
2.1 從一維方向切換變成二維視角查表
傳統 RO 類型的角色動畫：
               Yaw
      0  45  90  135 ... 315
Idle  A   B   C    D       H
Walk  A   B   C    D       H
Hit   A   B   C    D       H


當加入 Pitch，素材變成：
                   Pitch
             Low   Eye   High   Top
Yaw 0°       [ ]   [ ]    [ ]   [ ]
Yaw 45°      [ ]   [ ]    [ ]   [ ]
Yaw 90°      [ ]   [ ]    [ ]   [ ]
Yaw 135°     [ ]   [ ]    [ ]   [ ]
Yaw 180°     [ ]   [ ]    [ ]   [ ]
Yaw 225°     [ ]   [ ]    [ ]   [ ]
Yaw 270°     [ ]   [ ]    [ ]   [ ]
Yaw 315°     [ ]   [ ]    [ ]   [ ]


例如我們可以先研究下列俯仰層級：
Pitch 區間（示例）	素材類型	主要用途
-35°～0°	Low View	仰拍、BOSS 低角度
0°～25°	Eye View	平視戰鬥
25°～65°	High View	斜俯視探索
65°～85°	Top View	高空俯拍
實際切換不應該直接在這些區間邊界硬切，而應該根據素材的採樣中心角度，選擇最接近的視角，並加入 Hysteresis 防止反覆跳動。
2.2 方向控制器的計算方式
假設：
- Yaw 有 8 組。
- Pitch 有 3 組主要素材。
- 特殊俯視鏡頭另有頂視素材。
方向索引可以用以下概念計算：
# 計算從角色指向攝影機的世界向量
var to_camera: Vector3 = (
    camera.global_position - actor.global_position
).normalized()

# 攝影機相對角色面向的水平角度
var actor_forward := -actor.global_basis.z
var actor_right := actor.global_basis.x

var relative_yaw := atan2(
    to_camera.dot(actor_right),
    to_camera.dot(actor_forward)
)

# 攝影機相對角色的仰角
var horizontal_distance := Vector2(
    to_camera.x,
    to_camera.z
).length()

var relative_pitch := atan2(
    to_camera.y,
    horizontal_distance
)


接著將兩個角度量化成 Direction Index 和 Pitch Index，再決定對應動畫。

例如：

attack_yaw_3_pitch_2

不過這個範例假設角色保持直立，並且角色朝向的局部 Y 軸與世界 Y 軸一致。如果角色會傾倒、翻滾或倒掛，應改用完整的局部座標變換。
2.3 但只有多方向 Sprite 還不夠
這裡至少有四個需要解決的視覺問題。

A. 方向跳變

Camera 從 44° 旋轉到 46°，可能突然切換整個人物的頭部與身體輪廓。

處理方式是加入遲滯閾值、切換時機控制，必要時增加方向數。

B. 動畫不同步

攻擊播放到第 6 幀時，攝影機改變方向，不能讓攻擊動作重新從第 1 幀播放。

需要使用統一的動畫時間，而不是讓每個方向 Sprite 各自控制動畫。

C. 不同視角的人物接地點改變

高角度 Sprite 和低角度 Sprite 的可見腳部位置可能不同。

必須統一 Sprite Anchor，讓換方向時腳底保持在相同的世界位置。

D. 極端 Pitch 缺乏對應圖像

當攝影機幾乎位於角色正上方，8 方向的水平圖像可能全部都不合適。

這時需要額外頂視素材、專用電影鏡頭圖像，或以其他表示方式處理。
2.4 三種進階 Sprite 技術
技術	原理	適合研究的問題
Directional Sprite	切換不同視角的完整角色圖像	最基本的 360° 運鏡
Layered Sprite	頭髮、身體、武器分層顯示	紙娃娃與不同裝備
Multi-View Impostor	從 3D 模型預先渲染多個 Yaw / Pitch 角度	大幅度電影鏡頭
這裡的困難不只是素材數量。

以 Layered Sprite 來說，當攝影機由正面繞到背面，武器原本位於身體前方，可能需要切換到身體後方。

也就是說，紙娃娃不僅需要 Position Anchor，還需要依照方向決定圖層前後順序。

在 Godot 3D 裡，多個半透明 Sprite 的渲染順序又會涉及透明排序，因此不適合只依賴 render_priority 硬排所有部件。

我會研究的候選做法是讓角色共用一張合成完成的動畫貼圖，或將紙娃娃分層先合成到角色專屬 Viewport，再以單一 Sprite3D 顯示。

但後者會增加 Render Target 的成本，手機上需要特別驗證。

三、Camera 與 Sprite 到底要如何同步旋轉？
這裡最重要的決策，是 Billboard 的方式。
Full Billboard：永遠正對攝影機

Sprite 會配合 Camera 的朝向旋轉。

優點是幾乎不會看到圖像側邊的紙片問題。

但角色仍然只是平面。如果攝影機從上面看，會看到一張面向鏡頭的正面圖像，不會自動變成真正的頂視造型。

Y-Axis Locked Billboard：保持角色直立

只讓 Sprite 繞垂直方向調整面向，避免角色隨攝影機俯仰一起傾斜。

這對 RO 類型角色很有用。

缺點是 Camera 的 Pitch 愈高，角色 Sprite 的投影愈容易變形。接近正上方時，這個問題尤其明顯。

View-Dependent Billboard：依視角調整

水平方位由 Directional Sprite 決定；不同 Pitch 使用不同的 Sprite 素材與朝向規則。

這是值得做進階實驗的方案，但它需要自訂 View Resolver，不能只勾選 Godot 的 Billboard 選項就完成。


Godot 的 BaseMaterial3D 提供一般 Billboard 與固定 Y 軸 Billboard 模式，可作為這項研究的基礎。

Godot Engine (4.6) documentation in English




我會特別研究三段式處理：
- 平視附近：使用直立的 Y-Axis Locked Billboard。
- 中高角度：切換 High View 素材，視需要逐步調整 Sprite 面向。
- 接近頂視：切換 Top View，或使用專門為俯視鏡頭製作的視覺代理。
這裡有一個比較進階、但有價值的技巧：不一定需要讓 Sprite 完全跟著 Camera 的 Pitch 旋轉。

可以讓 Sprite 的法線方向僅部分追隨攝影機，使人物依然看起來直立，同時減少側面變薄的程度。

但這是一種風格化的視覺補償，而不是物理正確的 3D 投影。

四、建築遮擋：不只是讓牆壁變透明




















10









360° Camera 最大的實用問題是：攝影機繞到建築後面時，整棟建築可能擋住角色。

這個問題應該區分三個層級。
問題	對應技術	目的
鏡頭撞到建築	Camera Collision	防止鏡頭穿牆
建築擋住角色	Visibility Occlusion	讓角色保持可見
玩家進入室內	Roof / Room Visibility	切換室內與室外呈現
這三件事情不能用一種 Shader 全部處理。

尤其要區分 Godot 的 Occlusion Culling（遮擋剔除） 與我們討論的角色可見性系統。

Occlusion Culling 是效能最佳化機制：把被遮擋的物件從渲染工作中剔除。它並不會自動把擋住玩家的建築變透明。

Godot Engine (4.x) 正體中文 (台灣) 文件



4.1 攝影機碰撞：SpringArm3D
這是處理 Camera 穿牆的第一道防線。
CameraRig (Node3D)
└── YawPivot (Node3D)
    └── PitchPivot (Node3D)
        └── SpringArm3D
            └── Camera3D


概念上：
- YawPivot 負責水平旋轉。
- PitchPivot 負責垂直俯仰。
- SpringArm3D 負責偵測攝影機與地形、牆壁的碰撞。
- Camera3D 負責輸出畫面。
Godot 的 SpringArm3D 會沿著伸展方向進行碰撞檢測，碰到障礙時縮短 Camera 距離。官方也建議使用形狀掃掠，避免只靠單條射線導致攝影機邊緣穿過障礙物。

Godot Engine (latest) documentation in English
+1




但對你的視覺方向，SpringArm 有一個問題：

鏡頭撞到建築後直接靠近玩家，可能讓角色變得非常大，甚至破壞原本的電影構圖。

所以除了 Camera Collision，還需要 Visibility System。
4.2 Visibility System：偵測誰擋住角色
我會使用多條射線偵測。
Camera-to-Actor 可見性偵測
使用角色頭、身體與腳部的不同 Anchor 進行多點遮擋判斷，而不是只有一條射線。
為什麼需要多點偵測？

假設樹枝只擋住人物頭部，使用一條射線可能判斷角色已經完全被遮擋。

但實際上身體和腳部仍然看得見。

因此可以從多個 Anchor 估算可見程度，再決定需要多強的淡出效果。

另外，多條射線最好避免每幀全部執行，除非鏡頭、場景或目標正在快速移動。可以依照移動速度、玩家位置和鏡頭狀態決定檢測頻率。
Godot 實作：偵測遮擋物
先做一個最簡單的單目標範例。

假設建築的遮擋碰撞物位於專用 Collision Layer 4。

extends Node3D

@export var camera: Camera3D
@export var actor_focus: Marker3D

const OCCLUDER_MASK := 1 << 3

func get_first_occluder() -> CollisionObject3D:
    var from := camera.global_position
    var to := actor_focus.global_position

    var query := PhysicsRayQueryParameters3D.create(
        from,
        to,
        OCCLUDER_MASK
    )

    var result := get_world_3d() \
        .direct_space_state.intersect_ray(query)

    if result.is_empty():
        return null

    return result["collider"] as CollisionObject3D



這段只找出第一個遮擋物，適合驗證。正式系統還要支援多個遮擋物、切換緩衝、射線排除與碰撞體對應到實際可淡出的模型。

射線結果來自 Physics Collision，而不是直接從畫面像素判斷遮擋。因此需要正確設置建築 Collision Layer，並且讓每個碰撞物知道自己控制哪組視覺 Mesh。

Godot Engine (4.5) documentation in English



