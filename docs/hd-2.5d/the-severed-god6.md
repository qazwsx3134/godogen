接下來我想確認一個會影響架構的問題
既然你希望像 RO 一樣在 3D 世界中探索，戰鬥發生時，你比較傾向哪一種空間處理？

A. 無縫原地戰鬥：直接在探索地圖中交戰，特殊技能時才加入電影鏡頭。優勢是世界連續性強，但要處理地形障礙與鏡頭遮擋。

B. 進入戰鬥舞台：探索採 RO 形式，遇敵後進入像《The Severed Gods》那樣專門構圖的戰鬥場景。優勢是可以更精準控制光影、BOSS 尺度與演出。

C. 混合型：一般敵人原地交戰，重要 BOSS 或特殊戰鬥使用獨立舞台。

這裡不必立刻定案。我想知道你目前比較偏好哪種玩家體驗，接下來才能準確比較它們在 Godot 中的場景管理、攝影機與角色動畫成本。
















C













你選擇了 C，不過我上一題只有兩個方向，沒有 C 選項。

你是指之前討論過的哪一項？
- C. 斜俯視探索與戰鬥：類似《仙境傳說 Online》，3D 地圖搭配 2D Sprite，並加入電影式戰鬥鏡頭。
- C. 2D Sprite + Normal Map 光影：研究如何透過 Shader 讓像素角色自然融入 3D 場景。
確認後，我們就沿著該方向深入 Godot 的技術實作。
















C. 斜俯視探索與戰鬥：類似《仙境傳說 Online》，3D 地圖搭配 2D Sprite，並加入電影式戰鬥鏡頭。












處理時間為 1m


規劃技術方向



這樣方向就更明確了：以經典《仙境傳說 Online》的斜俯視 3D 地圖＋2D 角色作為探索基礎，戰鬥時再由 Camera Director 介入運鏡。我會重點檢查探索與戰鬥如何無縫共用同一個世界，以及這對角色方向素材、遮擋、操作與效能的影響；暫時不決定戰鬥是即時制還是回合制。








整理鏡頭方案並驗證整合互動


已搜尋 2 個網站













《仙境傳說 Online》×《The Severed Gods》：Godot 2.5D 探索與電影式戰鬥
現在可以把我們正在研究的方向定義得更清楚：

以《仙境傳說 Online》的 3D 地圖與 2D 像素角色建立可探索的世界，再加入《The Severed Gods》風格的戰鬥構圖、Break／Sever 回饋與電影式鏡頭演出。

這個組合在 Godot 4.x 有實作基礎，而且有一項重要優勢：探索與戰鬥可以發生在同一個 3D 世界，不必每次戰鬥都切換到另一個場景。

但這是我們要研究的候選架構，不代表已經決定戰鬥一定採用即時制、回合制，或特定的 Roguelite 玩法。
一、你想要的視覺效果，可以拆成兩種狀態
探索模式：RO 式斜俯視

攝影機保持較遠距離，角色在 3D 地圖中移動，玩家能觀察建築、地形、NPC 與敵人。










戰鬥演出：電影式鏡頭

攝影機靠近攻擊者、繞到敵人側面或低角度拍攝，強調技能、敵人反應與部位破壞。


這兩種畫面不需要兩套角色模型。

它們可以共用同一組：
- 3D 地圖與場景物件。
- 2D 角色 Sprite、動畫與方向資料。
- 角色的世界座標與戰鬥定位點。
- Shader、環境光影與技能特效。
主要變化的是 攝影機構圖、角色朝向與畫面演出控制。
二、我會先研究「單一世界，兩種鏡頭行為」
探索與戰鬥的鏡頭關係
Exploration Camera
斜俯視、跟隨角色、觀察環境

Encounter Focus
發現敵人，調整構圖與視覺焦點

Combat Camera
維持敵我位置和部位資訊清晰

Cinematic Override
攻擊、破防、部位切斷、BOSS 特寫

演出結束後回到 Combat 或 Exploration Camera
這裡最重要的不是切換多少台 Camera3D，而是有一個統一的 CameraDirector 管理鏡頭狀態。

例如玩家在探索時遇到 BOSS：
1. 相機維持斜俯視，玩家可以看清楚周圍地形。
2. BOSS 發出攻擊前兆，相機稍微後退或調整焦點。
3. 玩家使用技能，CameraDirector 暫時接管鏡頭。
4. 攻擊命中 BOSS 手臂並觸發 Break，鏡頭切向受擊部位。
5. 演出完成後，相機回到能繼續操作的角度。
這套邏輯可以支援不同戰鬥模式，而不必提前決定哪一種最好。
三、Godot 場景架構：3D 世界與 2D 角色分離
我會先用以下節點結構作為技術驗證基準，而不是最終專案架構。
WorldScene (Node3D)
│
├── WorldEnvironment
├── DirectionalLight3D
│
├── Map (Node3D)
│   ├── Terrain (MeshInstance3D)
│   ├── NavigationRegion3D
│   ├── Buildings
│   ├── Vegetation
│   └── Props
│
├── Characters (Node3D)
│   ├── Player (CharacterBody3D)
│   │   ├── CollisionShape3D
│   │   ├── NavigationAgent3D
│   │   ├── VisualRoot (Node3D)
│   │   │   ├── AnimatedSprite3D
│   │   │   └── GroundShadow
│   │   └── CombatAnchors
│   │
│   └── Enemies
│
├── CameraDirector (Node)
│   └── CameraRig (Node3D)
│       ├── SpringArm3D
│       │   └── Camera3D
│       └── CameraTargets
│
├── CombatSystem
├── VFXDirector
└── HUD (CanvasLayer)


這裡有四個重要的設計決策。
1. 角色是 CharacterBody3D，但外觀是 AnimatedSprite3D
CharacterBody3D 負責移動、碰撞和世界位置。

AnimatedSprite3D 只負責圖像呈現。

因此，即使角色的 Sprite 因為鏡頭轉動而切換方向，也不會影響角色的碰撞範圍或戰鬥座標。
2. 使用 NavigationRegion3D 處理地圖尋路
因為是 RO 式 3D 地圖，如果採用點擊移動，可以透過 Camera3D 將螢幕觸控座標投射成 3D Ray，再交給 NavigationAgent3D 尋路。

Godot 官方指出，NavigationAgent3D 負責提供路徑，並不會自動移動角色；角色本身仍要在物理更新中根據路徑前進。

Godot Engine (stable) documentation in English
+1




例如：
# 將螢幕點擊轉換為地面上的世界座標
# 在 physics frame 中執行
func select_destination(screen_pos: Vector2) -> void:
    var origin := camera.project_ray_origin(screen_pos)
    var direction := camera.project_ray_normal(screen_pos)

    var query := PhysicsRayQueryParameters3D.create(
        origin,
        origin + direction * 500.0,
        1 # 地面專用 Collision Layer
    )

    var result := get_world_3d().direct_space_state.intersect_ray(query)

    if not result.is_empty():
        navigation_agent.target_position = result.position


這裡省略了輸入事件接收、角色移動、導航網格初始化與碰撞處理。

它的關鍵好處是：無論攝影機旋轉到哪個角度，玩家仍然可以點擊畫面上的地面移動。
3. 使用 SpringArm3D 處理攝影機與地形碰撞
當攝影機環繞玩家時，可能穿進建築或山壁。

SpringArm3D 可以在相機與目標之間進行碰撞檢查，遇到障礙時縮短相機距離。這是 Godot 原生提供的用途。

Godot Engine (stable) documentation in English




但還有另一種情況：建築物沒有碰到攝影機，卻剛好擋住角色。

這時可能要另外使用遮擋偵測，將屋頂或樹木暫時淡化。
4. 角色 Sprite 方向與攝影機方向需要同步
這可以沿用我們之前研究的 RO 式八方向 Sprite。

我會優先驗證 BILLBOARD_FIXED_Y 與方向切換的搭配。前者主要讓角色保持直立並隨相機水平方向調整朝向；後者則負責選擇角色真正的正面、側面或背面素材。

兩者分別解決不同問題，不能只開啟 Billboard 就期待角色自然呈現八個方向。

Godot Engine (stable) documentation in English
+1




四、探索鏡頭與電影鏡頭，要不要使用不同的投影方式？
這是目前值得比較的技術。









Orthographic（正交投影）
接近平行透視，遠近物件的畫面尺寸不隨距離改變，容易維持像素角色比例。









Perspective（透視投影）
具有近大遠小的效果，適合利用鏡頭距離和視角突出巨型敵人的壓迫感。


Godot 的 Camera3D 都支援這兩種投影。

Godot Engine (latest) documentation in English



方案	探索	戰鬥特寫	主要風險
A	正交	正交	電影鏡頭的透視張力較少
B	透視	透視	探索時可能較容易出現遠近比例變化
C	正交	透視	轉換時畫面尺寸和構圖可能突然跳變
目前我不會直接選 C。

因為正交與透視不是單純改變 FOV 就能平滑互換。若要從正交切到透視，需要另行設計轉場、攝影機距離與構圖匹配。

反而可以先測試一個 低 FOV、較遠距離的 Perspective Camera，看能不能同時滿足斜俯視探索與電影式運鏡。

如果畫面已經足夠接近 RO 的感覺，就不一定需要兩套投影方式。

五、最需要解決的是角色與 3D 環境的融合
角色渲染與 Shader 的驗證順序
角色貼圖	Nearest Filter、統一 pixel_size
角色方向	8 方向 Sprite + Billboard
透明邊緣	先測試 Alpha Scissor，保留 Depth Test
接地效果	Ground Shadow + 3D 地面
環境光照	Unshaded / Shaded / Hybrid 對照
電影特效	短暫局部燈光、Bloom、Particles

我會優先保護角色本身的 Pixel Art 色彩與輪廓。

因為把 Sprite 完全交給 3D 光源，有時反而會破壞原本手繪的明暗。比較合理的是先測試混合光照：角色保留自己的基礎陰影，場景光源只在有限範圍內改變角色的顏色和亮度。

電影鏡頭則不只是增加特效。在鏡頭靠近角色時，還必須考慮 Sprite 尺寸是否足夠，以及多方向動畫是否能在低角度拍攝下維持自然。

六、手機效能與戰鬥設計要一起考慮
這裡我會保留兩個問題，不急著定案。

第一個是效能。 Godot 官方將 Mobile Renderer 定位為較新的行動裝置 3D 遊戲方案；Compatibility 則更適合較舊或低階設備。

Godot Engine (stable) documentation in English




因此如果之後仍以手機為主要平台，應該直接在實機驗證草地、角色透明材質、動態燈光與技能粒子，而不是只看桌面編輯器的 FPS。

第二個是戰鬥操作。 電影鏡頭如果經常接管畫面，可能讓玩家看不到敵人的下一次攻擊，也可能改變玩家對方向操作的判斷。

所以 CameraDirector 至少需要區分「不影響操作的鏡頭調整」與「短暫接管戰鬥的電影演出」。兩者的觸發條件、持續時間和恢復方式需要不同的設計。

七、下一步我們應該優先確認的問題
現在探索和戰鬥共用 3D 世界的技術路線已經相對明確。下一個會直接影響 CameraDirector 與角色 Sprite 製程的問題，是探索時的攝影機自由度。

A. 探索時固定斜俯視角度

玩家移動時相機跟隨，只有戰鬥演出才大幅度移動。


B. 探索時也能自由旋轉與縮放

接近 RO 的操作概念，玩家自行調整觀看角度，戰鬥時再加入電影運鏡。


C. 探索時有限度旋轉，特殊區域與戰鬥時使用自由鏡頭

在場景構圖、操作穩定性與電影效果之間取平衡。


繼續研究鏡頭與角色整合
就你目前喜歡的 RO 式探索與《The Severed Gods》電影式戰鬥來看，我認為 B 和 C 都值得測試。最大的差異是：B 需要讓角色在一般探索中就能應付更多鏡頭角度，而 C 可以把較昂貴的多角度動畫集中在特定演出。
















探索攝影機選擇：自由旋轉與縮放。請接著深入討論 Godot CameraDirector、8方向 Sprite、遮擋與鏡頭切換，並比較適合的場景節點設計；先不要決定戰鬥規則。












處理時間為 2m 13s



我會以「RO 式自由旋轉／縮放探索鏡頭，加上可切換的電影式鏡頭」為研究範圍，拆解 CameraDirector 的狀態管理、8 方向 Sprite 的角度同步、場景遮擋與鏡頭切換，最後比較不同 Godot 場景樹的優缺點。這次不涉及戰鬥規則的定案。








規劃並比較鏡頭方案架構


完善了切換細節


整理並整合最終實作方案


已搜尋 1 個網站













Godot 技術研究：RO 式自由探索鏡頭 × 8 方向 Sprite × 電影式 CameraDirector
研究範圍：Godot 4.x、3D 地圖、2D Pixel Sprite、自由旋轉與縮放、動態鏡頭切換

你現在選擇的方向，可以理解為：

保留經典《仙境傳說 Online》的探索與角色渲染邏輯，再加入現代 HD-2D 的光影，以及電影式鏡頭調度能力。

這裡有一個架構上的重要觀念：
探索鏡頭、電影鏡頭、角色 Sprite 朝向和場景遮擋，應該是四個彼此協作、但不互相控制內部狀態的系統。

例如相機旋轉時，角色應根據當前觀看角度切換 Sprite，而不是由相機直接命令角色播放 walk_3。同樣地，當攝影機穿過建築附近時，遮擋系統應判斷哪些物件需要淡出，而不是直接將整棟建築刪除。
一、先建立整套系統的關係
技術架構概念
Input / Game Events
滑鼠拖曳、手機手勢、探索目標、鏡頭演出請求

CameraDirector
鏡頭模式、控制權、切換、構圖與目標座標

Camera Rig
Orbit、Zoom、Collision、Shake

Camera State
位置、旋轉、FOV、焦點



Sprite Direction
根據實際相機方向選擇素材

Occlusion
防止穿牆、淡出遮擋物件



這裡我最在意的，是只有 CameraDirector 決定鏡頭的最終狀態。

其他系統只能提出請求，或讀取鏡頭的結果。

如此才能避免探索功能、電影演出和角色方向切換互相干擾。

二、探索鏡頭：使用 Orbit Camera 而不是直接旋轉 Camera3D
RO 類型的探索鏡頭，本質是圍繞某個目標點旋轉。
互動示意：Orbit Camera
水平旋轉 Yaw

45°




俯視角 Pitch

40°




鏡頭距離

8.0




這是 Orbit Camera 的概念示意，並非 Godot 真正的 3D 投影結果。
我會把 Orbit Camera 拆成三層
ExplorationCameraRig (Node3D)
└── YawPivot (Node3D)
    └── PitchPivot (Node3D)
        └── SpringArm3D
            └── Camera3D


節點	職責
ExplorationCameraRig	追蹤玩家位置，決定相機旋轉中心
YawPivot	控制水平 360° 旋轉
PitchPivot	控制上下俯仰角
SpringArm3D	相機與牆壁、地形的碰撞處理
Camera3D	透視、FOV、畫面輸出
這樣做比在 Camera3D 上直接疊加各種 Euler Rotation 更容易理解與維護。

另外，SpringArm3D 有一個容易踩到的細節：

若沒有指定 Shape，Godot 只有在 Camera3D 是 SpringArm3D 的直接子節點時，才會使用攝影機近裁切面的形狀進行碰撞檢測。

如果你把 ShakePivot 插在 SpringArm3D 和 Camera3D 中間，SpringArm 可能退回較不精確的 Raycast 檢測。因此鏡頭震動更適合透過獨立的效果層，或明確設定 SpringArm 的碰撞 Shape 來處理。

Godot Engine (stable) documentation in English
+1




這是我們在設計 Camera Rig 時需要提前考慮的工程限制。

三、CameraDirector：應該是一個「鏡頭調度器」
如果希望同一套系統支援自由探索、劇情演出、BOSS 特寫與特殊視角，我不建議讓所有相機共用同一組操作邏輯。

比較合理的是建立一個 CameraDirector，管理多個 Camera Rig 和鏡頭控制權。
1. 鏡頭狀態設計
這裡的 Mode 是相機系統狀態，不代表要決定任何戰鬥規則。
Camera Mode	控制來源	鏡頭行為
Explore	玩家輸入	自由旋轉、縮放、跟隨
Focus	系統指定目標	鎖定人物或場景物件
Cinematic	預先定義的鏡頭資料	運鏡、特寫、構圖
Transition	CameraDirector	在鏡頭之間插值
Restore	CameraDirector	回復探索鏡頭
我會額外加入一個觀念：相機模式和相機姿態是兩種不同的資料。

Mode 用於決定誰能控制鏡頭，Pose 則表示鏡頭目前的狀態。
class_name CameraPose
extends Resource

@export var position: Vector3
@export var rotation: Vector3
@export var fov: float = 55.0
@export var focus_offset: Vector3
@export var transition_duration: float = 0.5


這是一個簡化的資料格式。在正式的 360° 運鏡中，旋轉插值更適合透過 Quaternion 處理，而不是直接對三個 Euler 角度做線性插值。

另外，CameraPose 應該是鏡頭資料，而不是角色資料。角色不需要知道目前屬於什麼電影鏡頭。
2. 三種 CameraDirector 架構比較
這是目前最值得比較的場景節點設計。
架構 A：相機直接跟隨玩家

簡單型

Player (CharacterBody3D)
├── Visual
└── CameraPivot
    └── SpringArm3D
        └── Camera3D


適合只有探索鏡頭、切換需求少的作品。

限制：相機與玩家節點耦合。劇情攝影機想脫離玩家、追蹤 NPC 或在兩人之間構圖時，需要額外控制。

架構 B：獨立 CameraDirector + 多個 Camera Rig
優先研究

World (Node3D)
├── Characters
│   └── Player
├── Environment
└── CameraSystem
    ├── CameraDirector
    ├── ExplorationRig
    │   └── YawPivot
    │       └── PitchPivot
    │           └── SpringArm3D
    │               └── ExploreCamera
    ├── CinematicRig
    │   └── CinematicCamera
    └── BlendCamera


探索和電影演出各自擁有鏡頭，切換時由 BlendCamera 過渡。

優點：容易分工、獨立測試與調校。代價：需要同步鏡頭狀態，並處理切換過程中的遮擋和 Sprite 朝向。

架構 C：單一 Camera3D + Virtual Camera

高度客製化

World (Node3D)
└── CameraSystem
    ├── CameraDirector
    ├── OutputCamera (Camera3D)
    ├── VirtualCameras
    │   ├── ExplorationProvider
    │   ├── FocusProvider
    │   └── CinematicProvider
    ├── CameraCollisionSolver
    └── CameraEffects


多個虛擬攝影機只計算理想姿態，最後由唯一的 OutputCamera 輸出。

優點：切換一致、擴充性高，也比較容易集中管理鏡頭效果。代價：需要自行處理 Camera Collision，開發成本較高。


要注意，這裡的 Virtual Camera 是我們自行設計的概念，不是 Godot 內建的一種特殊節點。
架構比較總表
評估	A 玩家子節點	B 多鏡頭	C 單輸出鏡頭
自由探索	容易	容易	需自行整合
電影運鏡	較麻煩	容易擴充	最有彈性
SpringArm	原生整合	原生整合	需額外設計
平滑鏡頭切換	需擴充	BlendCamera	統一插值
Sprite 方向同步	容易	要追蹤當前相機	單一輸出來源
除錯難度	低	中	高
維護複雜度	低	中	中～高
以研究優先順序來說，我傾向先驗證 B，因為它可以保留 Godot 的 SpringArm3D 原生行為，同時測試大範圍電影運鏡。

但假設後續需要頻繁切換鏡頭、複雜軌道或大量鏡頭特效，C 值得重新比較。

四、8 方向 Sprite：讓相機與人物解耦
這裡是和經典 RO 最接近的技術。

我們需要區分兩種方向：
- World Facing：人物在世界中真正面向哪裡。
- View Direction：攝影機從人物的哪個方向觀看。
這兩個方向絕對不能混為一談。
鏡頭旋轉時，人物的世界朝向不應改變
例如角色固定面向世界北方。

當相機繞角色旋轉時，角色沒有轉身，只是我們看到的角色方向不同了。
互動示意：8 方向 Sprite 選擇


目前選擇的 Sprite

Direction 0

正面

假設相機角度以角色正前方為 0°，由角色觀看方向決定八方向圖像。這裡沒有改變角色本身的世界旋轉。
Godot 的實作方式
角色的 SpriteFrames 可以建立以下命名：
idle_0 ~ idle_7
walk_0 ~ walk_7
attack_0 ~ attack_7


下列程式示範從角色的世界朝向和目前啟用的 Camera3D 計算相對角度，然後切換 Sprite。

extends Node

@export var actor_root: Node3D
@export var sprite: AnimatedSprite3D

const DIR_COUNT := 8
const STEP := TAU / DIR_COUNT

var current_action: String = "idle"

func _process(_delta: float) -> void:
    # 重要：讀取目前真正輸出的相機
    var camera := get_viewport().get_camera_3d()
    if camera == null or sprite.sprite_frames == null:
        return

    var facing := -actor_root.global_basis.z
    var to_camera := (
        camera.global_position
        - actor_root.global_position
    )

    # 只取水平面方向
    facing.y = 0.0
    to_camera.y = 0.0

    if facing.length_squared() < 0.0001:
        return

    if to_camera.length_squared() < 0.0001:
        return

    facing = facing.normalized()
    to_camera = to_camera.normalized()

    var angle := atan2(
        facing.cross(to_camera).y,
        facing.dot(to_camera)
    )

    var direction_index := posmod(
        roundi(angle / STEP),
        DIR_COUNT
    )

    var animation_name := StringName(
        "%s_%d" % [current_action, direction_index]
    )

    if not sprite.sprite_frames.has_animation(animation_name):
        return

    if sprite.animation == animation_name:
        return

    # 保留目前動畫的播放位置
    var old_frame := sprite.frame
    var old_progress := sprite.frame_progress
    var was_playing := sprite.is_playing()

    sprite.play(animation_name)

    var frame_count := sprite.sprite_frames.get_frame_count(
        animation_name
    )

    sprite.set_frame_and_progress(
        mini(old_frame, frame_count - 1),
        old_progress
    )

    if not was_playing:
        sprite.pause()



這是一個可供原型使用的核心算法，但有幾個前提需要注意。

第一，角色的邏輯正面是 -Z，素材命名順序必須與方向索引一致。第二，這段程式只計算 Yaw，尚未處理相機 Pitch。第三，不同方向若有不同幀數或動畫速度，應依正規化動畫時間做更完整的同步，而不是單純保留幀索引。

Godot 官方的 AnimatedSprite3D 支援 frame_progress 與 set_frame_and_progress()，可用於避免切換方向時意外將動畫重置到第一幀。

Godot Engine (stable) documentation in English



另外需要一個關鍵功能：Hysteresis
例如目前方向是 0，攝影機在 22.5° 附近小幅抖動。

若直接採最近方向選擇，可能不斷出現：

0 → 1 → 0 → 1

角色因此不停切換圖像。

我會增加約 3°～6° 的方向切換遲滯作為測試起點。

也就是超過方向邊界一小段角度後才切換，而不是剛好碰到 22.5° 就立刻更換 Sprite。

這對自由旋轉相機尤其重要。

此外，角色身體、頭髮和武器如果使用紙娃娃圖層，所有部件都應由同一個 Direction Controller 驅動，否則相機快速旋轉時可能出現身體切到背面、武器還停留在正面的錯誤。

五、場景遮擋：這可能比 CameraDirector 更難
自由探索鏡頭不只會遇到牆壁，也會碰到樹木、屋頂、建築物、山壁和前景裝飾。

尤其是 RO 這種 2D 人物搭配 3D 環境的畫面，遮擋關係會直接影響玩家能否看見角色。

我會將遮擋問題分成兩類：

Camera Collision：避免攝影機穿進牆壁。

Visual Occlusion：攝影機沒有穿牆，但角色被物件擋住。

這兩個問題必須分開處理。
1. 四種遮擋策略
遮擋解決策略

碰撞淡出屋頂改變構圖

Object Fade

當樹冠、屋頂或建築裝飾遮住角色時，逐漸淡出相關 Mesh。適合保留探索視線。
簡化的遮擋示意，實際遮擋與透明度由 3D 場景中的碰撞和材質決定。
2. 使用 SpringArm3D 處理物理碰撞
這部分 Godot 已經提供現成能力。

SpringArm3D 可進行形狀掃掠檢測，碰到障礙時，將子節點攝影機移到碰撞點附近。還能透過 collision_mask 選擇哪些物件會影響相機。

Godot Engine (stable) documentation in English




但我不建議把每棵草、每片樹葉、每個裝飾 Mesh 都設為 Camera Collision。

可以將碰撞層做以下概念性分工：
Physics Layer	類型	是否阻擋相機
World Solid	牆壁、山壁、大型建築	是
Character	玩家、NPC	通常排除
Camera Fade	樹冠、屋頂、前景裝飾	不一定，優先淡出
Interaction	可互動物件	通常否
這些是用途分類，實際使用第幾個 Godot Collision Layer 可以再分配。
3. 讓遮擋物件自動淡出
我會考慮使用 OcclusionController。

每隔一個物理更新週期，檢查相機和角色視覺中心點之間是否存在遮擋物件。
Camera Position
       │
       │ Raycast
       ▼
Occluding Mesh
       │
       │ Raycast 繼續
       ▼
Character Focus Anchor
       │
       ▼
將遮擋物件加入 Fade Set
       │
       ▼
更新材質可見度


Godot 的 PhysicsDirectSpaceState3D.intersect_ray() 支援物理空間射線查詢，並可透過查詢參數排除特定物件。

Godot Engine (stable) documentation in English




但是要特別注意：單次 Raycast 只會回傳一個命中結果。

如果角色前面同時有樹冠與屋頂，就不能只偵測第一個物件。可採多次查詢並排除先前命中的 Collider，或者讓建築、樹冠自行建立更高階的遮擋群組。

我比較傾向後者，因為整棟房子的所有 Mesh 不一定適合各自獨立淡出。
4. Shader 應該如何淡出？
最直覺的方法是修改材質 ALPHA。

但它有個問題：Godot 的透明物件可能遇到深度排序和額外繪製成本。

官方文件也建議，在適合的情況下使用 Alpha Scissor、Alpha Hash 或 Dither，而不是所有效果都採傳統 Alpha Blend。

Godot Engine (stable) documentation in English




我會研究這種 Shader：
shader_type spatial;

render_mode cull_back;

uniform sampler2D albedo_texture : source_color;

instance uniform float camera_visibility :
    hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // 簡化的螢幕空間 Dither
    float noise = fract(
        sin(dot(
            floor(FRAGCOORD.xy),
            vec2(12.9898, 78.233)
        )) * 43758.5453
    );

    if (noise > camera_visibility || tex.a < 0.5) {
        discard;
    }

    ALBEDO = tex.rgb;
}


這是用隨機 Dither 模擬漸隱的原型，不是最終建議的美術版本。

在手機、像素場景與動態運鏡中，這類雜訊可能產生明顯閃爍。因此正式版本可進一步測試固定 Bayer Matrix、物件空間 Dither 或材質內建的透明模式。

另外，這裡使用 instance uniform，因此可以讓多個 Mesh 共用 ShaderMaterial，但個別設定淡出值，而不需要複製大量 Material。Godot 支援在 GeometryInstance3D 上設定 Per-instance Shader Parameter。

Godot Engine (stable) documentation in English


