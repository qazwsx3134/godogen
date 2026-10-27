六、動畫製程：這套技術真正昂貴的地方
這裡先以一個測試角色為例，假設有 6 種動作，每種 8 幀。
Sprite 製作量估算
動畫方向

4 方向8 方向16 方向


動作種類

6




每個動作的影格數

8




[ ] 每個影格另外製作 Normal Map

角色動畫影格
384

顏色與法線影格資產數
384


假設每方向、每動作影格數相同，且素材不共用。實際可以用鏡像、程序動畫與影格重用降低成本。
這也是為什麼我想研究一個混合製程：
3D 輔助製作 → 輸出 2D Sprite → Godot 即時顯示
Blender 建立簡化 3D 角色
角色比例、骨架、動作與材質
從多個方向批次渲染
Color、Normal、Mask 等影格資料
像素化與人工修整
輪廓、色盤、細節、動畫一致性
Godot SpriteFrames / Atlas
方向切換、動畫播放、材質與光照


這和直接在遊戲裡使用 3D 模型不一樣。

Blender 模型只是美術生產工具。遊戲執行時仍可使用 2D Sprite，減少即時角色骨骼、複雜材質與網格動畫的負擔。

但它也不是完全免費的技術優勢。

批次渲染出來的像素動畫，可能缺乏手繪 Pixel Art 的誇張動作和輪廓節奏。因此通常仍需要人工修整，尤其是攻擊、受擊和終結技。
動畫還要考慮鏡頭同步
我會讓一段技能動畫存在三種獨立時間資訊：

Animation Time、Camera Time、VFX Time

然後使用一個共同的演出時間軸來協調。

角色方向切換時，不應重置攻擊動畫，而是保留目前的正規化動畫進度。

如此相機繞到角色背後的時候，攻擊仍會繼續播放，而不會突然從第一幀重來。

七、手機效能：真正的瓶頸可能不在角色多邊形
因為你過去的遊戲主要以手機為目標，我會特別關注 GPU Fill Rate 與透明重疊繪製（Overdraw）。

Pixel Sprite 本身只有少量幾何頂點，不代表一定便宜。

如果角色周圍有大量透明草叢、煙霧、魔法光暈和粒子，即使每個物件只有幾個三角形，GPU 仍可能需要反覆處理同一塊螢幕區域。

Godot 官方也提醒，透明物件需要額外排序，通常不如不透明幾何容易最佳化。

Godot Engine (stable) documentation in English



我會比較三種 Rendering Method
渲染器	優點	限制
Forward+	桌面端高階光影效果較完整	手機負擔可能較高
Mobile	面向行動裝置的 3D 渲染路線	部分高階效果不支援
Compatibility	裝置相容性範圍較廣	部分後製和 3D 功能不同
Godot 官方的渲染器比較顯示，Mobile 支援 Glow 和一般霧效，但不支援 Volumetric Fog、SSAO、SSIL 等功能。

Godot Engine (stable) documentation in English




因此不能把桌面上使用 Forward+ 做出的所有視覺效果，直接假設能在 Mobile Renderer 完全重現。
初步效能預算
以目標 60 FPS 為例：
60 FPS 的單幀預算
16.67 ms


30 FPS 的單幀預算
33.33 ms



這是每幀總時間預算，不是 GPU 單獨可使用的時間；CPU、GPU、呈現同步與系統開銷都需要考慮。
我會優先觀察：
- GPU Frame Time 與實際 FPS。
- Draw Calls、Primitive 數量。
- 透明材質及粒子重疊範圍。
- 相機快速旋轉時的貼圖與 Shader 編譯卡頓。
- 多角色方向切換時的貼圖記憶體。
- 發熱後持續運作的效能，而不只是剛啟動時的 FPS。
尤其電影鏡頭會靠近角色。平常看起來很小的 Sprite，鏡頭拉近後可能暴露像素尺寸、法線精度與動畫幀數不足的問題。

所以品質測試需要同時包含全景、半身與近距離特寫。

八、我認為目前有三個尚未解決的核心矛盾
角色始終是 2D，但鏡頭希望像 3D 一樣自由

可以透過 Directional Sprite 增加視角，但這會提高美術工作量，而且不自動解決俯仰角。



希望角色融入真實光影，但又要保留手繪像素感

Normal Map 和 Stylized Shader 可以改善融合，但必須避免過度平滑的光照破壞原有的像素風格。



希望電影式特效華麗，但目標是手機

技能光源、透明粒子、景深與高解析度場景需要按硬體分級，不能把每個效果都當成必備。



這些問題不是靠一個 Shader 就能全部解決，而是需要美術流程、角色架構和 Camera Director 共同配合。

九、接下來我想優先跟你確認角色的「立體感」來源
因為這將決定我們要研究多方向 Sprite、Normal Map，還是使用 3D 輔助的動畫製程。









A. 完整手繪 Pixel Art
最重視每幀的像素造型和美術細節，可以接受動畫方向比較少。









B. 3D 輔助的像素動畫
使用 3D 模型協助製作角色動作，再產生成像素材，重視動畫流暢與製作效率。









C. 2D Sprite + Normal Map 光影
角色仍然平面，但希望光源能更細緻地表現臉部、衣服與武器。









D. 混合製程
主要保留 2D Sprite；有需要時使用 3D 模型輔助特殊運鏡與動畫。


你想深入哪種角色製程？

A. 完整手繪 Pixel Art

B. 3D 輔助產生 2D Pixel Sprite

C. Sprite + Normal Map + Shader

D. 混合製程，依照鏡頭需求使用不同方法


你最想優先解決哪一個問題？

如何讓 2D Sprite 與 3D 場景完美融合

如何降低多方向像素動畫的製作成本

如何讓 360° 電影鏡頭與 Sprite 正確配合

如何在手機維持良好的畫質與 FPS

繼續深入技術研究
我目前比較傾向先研究 D：混合製程，因為它提供比較大的設計彈性。但有一個前提值得保留：我們應該先判斷每個電影鏡頭真正需要呈現哪些角度，再決定需要製作多少方向的角色素材，而不是反過來為了支援 360°，一開始就做出大量可能根本用不到的動畫。
















這個解決方式是不是跟仙境傳說渲染方式很像












處理時間為 29s







對，而且非常接近！你提到的《仙境傳說 Online》（Ragnarok Online，RO）正是我們目前討論的「2D Sprite × 3D 世界」非常典型的案例。

更精確地說，經典 RO 的核心視覺概念就是：

2D 像素人物 + 3D 地圖 + 可旋轉攝影機 + 依角色方向切換 Sprite。




















10









它與我們研究的方向相同，但有個重要差異：

RO 主要解決的是「玩家如何在 3D 地圖中觀看 2D 角色」，而我們還想進一步解決「如何讓攝影機像電影一樣靠近、環繞角色，同時保留像素美術的品質」。

這代表 RO 可以成為我們很好的技術基準，但不需要完全照搬它的鏡頭限制。
1. 經典 RO 的實際渲染架構
研究 RO 的檔案格式後，可以確認它的設計比表面上更接近我們正在討論的方案。
RO 系統	實際技術	Godot 對應
地圖地形	3D 地面網格（GND）	MeshInstance3D
建築與物件	3D 模型	Node3D、MeshInstance3D
人物與怪物	2D Sprite（SPR）	AnimatedSprite3D
動畫	ACT 動畫資料	SpriteFrames、AnimationPlayer
角色方向	8 方向、每 45° 一組	Direction Controller
鏡頭	Orbit Camera	Camera3D + SpringArm3D 或自訂 Camera Rig
光照	地圖預先計算的 Lightmap 等	Baked Lightmap、WorldEnvironment
RO 的地形不只是平面背景，而是真正有高度資料、貼圖與預先計算光影的 3D 網格。角色動畫也確實包含八方向版本。

Ragnarok Research Lab
+2




而且 RO 有個非常值得我們借鏡的細節：它的 ACT 動畫支援 Sprite Anchor，可以讓頭部、裝備、武器相對於身體正確定位。

Ragnarok Research Lab




這其實也是早期的 2D 紙娃娃系統。
2. RO 是怎麼處理相機旋轉的？
它的概念大致是：
Camera3D 改變觀看角度


計算相機與角色面向的相對角度


選擇對應的八方向 Sprite


使用 Billboard 呈現角色


但有個需要修正的認知：經典 RO 並不是完全無限制的 360° 電影鏡頭。

根據 RO 的攝影機技術研究，它使用 Orbit Camera，允許水平和垂直角度調整，但水平旋轉通常受限；部分特殊地圖還會鎖定鏡頭或另外設定可用角度。

Ragnarok Research Lab




這也是為什麼 RO 可以讓角色在 3D 場景中活動，又不用解決所有極端仰角、俯角與近距離特寫的問題。
3. RO 和我們想研究的方式，最大的差別
項目	經典 RO	我們正在研究的方向
角色	2D Pixel Sprite	2D Pixel Sprite
地圖	3D 世界	3D 世界
方向切換	8 方向	8 方向起步，評估額外角度
相機	可調角度的遊戲鏡頭	大範圍電影式運鏡
光照	以較傳統的環境光影為主	動態光源、風格化 Shader
景深	非核心特色	可作為電影演出的手段
戰鬥鏡頭	主要維持遊戲視角	Break、Sever、技能特寫
我認為最有意思的是：

我們可以借鏡 RO 已經驗證過的角色渲染方法，但不必沿用它較保守的光影和鏡頭演出。

例如在 Godot 中，這種角色可以先由以下節點組成：
Character3D
├── AnimatedSprite3D
├── DirectionController
├── AnimationController
├── GroundShadow
├── EquipmentLayers
│   ├── HairSprite3D
│   ├── WeaponSprite3D
│   └── ArmorSprite3D
└── VFXAnchors


其中 AnimatedSprite3D 負責播放圖像，DirectionController 負責依據鏡頭角度選擇動畫，EquipmentLayers 則提供類似 RO 的換裝與紙娃娃效果。

但如果攝影機要靠近人物正面、從背後繞到前面，甚至由地面仰拍，就必須額外測試 Sprite 方向切換、相機俯仰和素材解析度。

Godot 本身已有支援 3D 空間中的 2D Sprite、Billboard 和光照等功能。

Godot Engine (stable) documentation in English



4. 我覺得 RO 讓我們找到一個值得深入的研究方向









經典 RO 的視覺邏輯

透過角色方向切換、3D 環境與遊戲攝影機，讓平面的像素角色看起來能自然地存在於立體世界。











現代 HD-2D 的視覺追求

在相似的混合美術概念上，進一步強調環境光影、景深、後製與戲劇化戰鬥鏡頭。


這讓我們可以把技術研究濃縮成一個問題：

能不能用 RO 的角色渲染邏輯當基礎，再利用 Godot 4 的 Shader、3D 光照與 Camera Director，實現更具電影感的 HD-2D 戰鬥？

我的判斷是技術上可行，但是否能自然地進行大範圍運鏡，仍取決於角色方向素材和相機俯仰角的處理。

而且，RO 的技術還有一個很適合你之前提過的紙娃娃角色系統的地方：它能讓頭髮、身體、武器及裝備以圖層組合，不必每換一件裝備就重新製作整個人物。

我想接著確認一點：你是希望保留 RO 那種可自由旋轉相機的探索體驗，並在戰鬥時加入電影鏡頭；還是比較喜歡《The Severed Gods》的固定舞台戰鬥，只在施放技能時進行大範圍運鏡？

這兩者可以採用相似的角色渲染技術，但 Camera Director 與角色動畫的需求會有顯著差異。
















保留 RO 那種可自由旋轉相機的探索體驗，並在戰鬥時加入電影鏡頭












處理時間為 1m 27s



這樣就有明確的研究基準了：探索時使用 RO 式自由旋轉鏡頭，進入戰鬥演出時由 Camera Director 接管，結束後平順返回玩家視角。我會針對 Godot 的節點架構、角色八方向 Sprite、鏡頭交接和手機效能，拆出可驗證的技術方案，同時保留戰鬥玩法的選擇空間。








整理相機架構


完善轉場算法並整合畫面銜接表現


已搜尋 2 個網站













遊戲技術方向：RO 式自由探索 ×《The Severed Gods》電影式戰鬥
這個組合很值得研究，因為你想保留《仙境傳說 Online》自由探索 3D 世界的感覺，同時又希望戰鬥具有《The Severed Gods》那種強烈的視覺演出。

我會把它定義成一個技術研究目標：

RO 的世界呈現技術 + HD-2D 光影 + 電影式 Camera Director。

但我們先不決定遊戲是即時戰鬥、回合制，或是否使用獨立戰鬥場景。
1. 兩種鏡頭體驗，但世界不必切換









探索模式：RO 式鏡頭

自由旋轉、縮放、跟隨角色，利用 3D 地形建立探索感。










戰鬥演出：電影式鏡頭

在重要攻擊、Break、Sever 或 BOSS 階段變化時改變構圖。


我的重點是：Camera Mode 不需要和 Game Mode 綁死。

例如玩家在野外探索時，也能直接進行戰鬥。一般攻擊維持玩家視角，遇到重要技能才讓 Cinematic Camera 暫時接管。

相反地，即使採用回合制，玩家仍然可以在戰鬥中自由觀察敵人部位，只在關鍵演出時切換鏡頭。
Camera State Machine
Exploration Camera
玩家控制旋轉、縮放與跟隨
Combat Camera
保留戰場資訊、角色與目標
Cinematic Camera
特定技能、破防、終結演出
Return / Restore
平順返回先前鏡頭狀態


這套設計的價值，在於玩家不會覺得自己每次戰鬥都被傳送到另一個不相關的世界。

但是否保留同一個戰鬥場景，我們可以等討論玩法後再決定。
2. Godot 的 Camera Director 怎麼設計？
我會將「產生目標鏡頭」和「真正輸出畫面」分開。
World (Node3D)
│
├── CameraSystem (Node3D)
│   │
│   ├── ExplorationRig
│   │   ├── YawPivot
│   │   │   └── PitchPivot
│   │   │       └── SpringArm3D
│   │   │           └── CameraTarget
│   │
│   ├── CinematicTargets
│   │   ├── AttackShot
│   │   ├── BreakShot
│   │   └── SeverShot
│   │
│   ├── CameraDirector
│   │
│   └── RenderCamera (Camera3D)
│
├── Characters
├── Environment
├── Lighting
└── VFX


這是一種候選結構，不是唯一正確的 Godot 架構。

這裡最重要的兩個節點是：

ExplorationRig

負責 RO 式的玩家鏡頭，包含水平旋轉、俯仰、縮放、追蹤和障礙碰撞。

RenderCamera

是實際負責輸出畫面的 Camera3D。CameraDirector 可以讓它追蹤 ExplorationRig 的目標 Transform，也能在技能演出時移動到電影鏡頭位置。

這樣做的好處，是不需要在多台實際 Camera3D 之間突然切換。

Godot 的 make_current() 可以切換目前生效的攝影機，但不會自動替你完成電影式插值。SpringArm3D 則可以在相機接近牆壁或障礙物時縮短距離，協助避免穿模。

Godot Engine (latest) documentation in English
+1




3. 最容易忽略的細節：切換鏡頭時，不要丟失玩家視角
假設玩家在野外探索，把攝影機轉到角色左後方，然後發動一次特殊攻擊。

理想流程應該是：
1. 記錄目前的探索鏡頭狀態，例如 Yaw、Pitch、Zoom 和追蹤目標。
2. Camera Director 接管畫面，移動到技能演出的 Shot。
3. 播放角色動畫、命中特效與敵人反應。
4. 鏡頭返回探索狀態，而不是突然重設到角色正後方。
這個細節會大幅影響玩家的操作體驗。

更進一步，我甚至不建議一定要「凍結探索相機」：探索用的 Camera Rig 可以持續追蹤移動中的角色，只是暫時不負責畫面輸出。

電影演出結束時，就返回探索鏡頭最新的合理位置。
Camera Director 程式概念
class_name CameraDirector
extends Node

@export var render_camera: Camera3D
@export var exploration_target: Node3D

var active_target: Node3D
var active_fov := 55.0

var blend_from: Transform3D
var blend_from_fov := 55.0
var blend_target: Node3D
var blend_target_fov := 55.0
var blend_weight := 1.0

var transition_tween: Tween


func _ready() -> void:
    active_target = exploration_target
    render_camera.make_current()


func _process(_delta: float) -> void:
    if blend_target != null:
        render_camera.global_transform = \
            blend_from.interpolate_with(
                blend_target.global_transform,
                blend_weight
            )

        render_camera.fov = lerpf(
            blend_from_fov,
            blend_target_fov,
            blend_weight
        )
    elif active_target != null:
        render_camera.global_transform = \
            active_target.global_transform
        render_camera.fov = active_fov


func move_to(
    target: Node3D,
    duration: float,
    target_fov: float
) -> void:
    if transition_tween != null:
        transition_tween.kill()

    blend_from = render_camera.global_transform
    blend_from_fov = render_camera.fov
    blend_target = target
    blend_target_fov = target_fov
    blend_weight = 0.0

    transition_tween = create_tween()
    transition_tween.tween_property(
        self, "blend_weight", 1.0, duration
    ).set_trans(Tween.TRANS_CUBIC) \
     .set_ease(Tween.EASE_IN_OUT)

    await transition_tween.finished

    if blend_target == target:
        active_target = target
        active_fov = target_fov
        blend_target = null


這是精簡原型，尚未處理並發請求識別、節點刪除、鏡頭碰撞及 Cinematic 優先權。正式系統要避免被中斷的非同步請求在稍後反過來覆蓋新鏡頭。

回到探索鏡頭時，只需呼叫：
camera_director.move_to(
    exploration_target,
    0.35,
    55.0
)


正式實作應保存探索時的 FOV，而不是把 55.0 寫死。
SpringArm3D 的一個實作陷阱
前面我們把 CameraTarget 放在 SpringArm3D 底下，讓真正輸出的 Camera3D 留在 CameraDirector。

這種配置可以實作，但要注意：Godot 的 SpringArm3D 只有在 Camera3D 是直接子節點、且沒有指定碰撞 Shape 時，才會使用攝影機的近裁切面形狀進行掃描。

如果子節點只是 Marker3D 或 Node3D，便需要自行設定合適的 Shape3D，例如 SphereShape3D，否則可能退化成較不精確的射線碰撞。

Godot Engine (latest) documentation in English




這在 RO 式旋轉鏡頭經過建築物轉角時相當重要。

4. 角色渲染：我會保留 RO 的技術，但加一層視角控制
這裡是我們先前討論的 Directional Sprite 最需要調整的部分。

角色實際上有三個方向：
方向	誰來決定	作用
Logical Facing	角色控制器或戰鬥 AI	角色真正面對的方向
Visual Facing	Sprite Direction Controller	顯示正面、側面或背面圖像
Camera Facing	Camera3D	玩家從哪個角度觀看角色
這三個方向不能混為一談。

假設角色面朝北方，玩家把攝影機從南側轉到北側：
- 角色的真正朝向沒有改變。
- 攝影機相對角色的方向變了。
- Sprite 應從正面動畫逐漸切換到背面動畫。
- 角色不應該跟著相機一起在世界中轉身。
我會先比較 BILLBOARD_FIXED_Y 與自行控制 Y 軸旋轉兩種方法。

BILLBOARD_FIXED_Y 能讓 Sprite 保持直立，同時朝向攝影機的水平位置；對經典 RO 類型的相機視角相當合適。

Godot Engine (4.3) documentation in English




但如果電影鏡頭從非常低的角度仰拍，角色仍然只是一張直立的平面。

這時可以考慮兩種視覺處理方式：
- 普通探索視角： 使用八方向 Sprite。
- 特殊電影鏡頭： 使用針對該鏡頭製作的高解析度或特定角度動畫。
這個設計不一定要求角色轉為 3D；它也可以只是另一套專門用於特寫的 Pixel Sprite。

而且，這種做法還能避免鏡頭靠近時把原本 64×96 的角色放大到整個畫面，導致像素細節不足。

5. 光影和 Shader 應該配合鏡頭距離
我認為可以把材質分成兩個視覺品質層級，而不必在角色身上永遠啟用所有效果。
探索距離

角色通常較小，重點是輪廓清楚、地面陰影、統一環境色與穩定的像素動畫。

技術重點：AnimatedSprite3D、Nearest Filter、Alpha Cut、Lightmap、接地陰影。












電影特寫距離

當相機靠近角色，表情、服裝輪廓、武器反光、受擊閃白與背景景深才變得明顯。

技術重點：特寫 Sprite、動態補光、Normal Map（選用）、VFX 與 Camera Attributes。












這裡不一定需要真的在執行時更換 Shader。可以先共用一套材質，只讓 Cinematic Director 調整特寫相關參數。

例如：

cinematic_intensity、rim_light_strength、hit_flash、environment_tint

但比較麻煩的是 Sprite 的透明排序。

Godot 官方建議，對於主要只有完全透明或完全不透明像素的材質，可以測試 Alpha Scissor，通常比一般 Alpha Blend 更容易避免深度排序問題。

Godot Engine (4.x) 正體中文 (台灣) 文件




這會直接影響角色紙娃娃、武器、頭髮和 3D 草叢交錯時的畫面正確性。

另一個值得預先規劃的問題是：如果角色透過 Billboard 面向攝影機，角色產生的即時陰影不一定符合世界中的實際方向。因此我會優先用地面接觸陰影和獨立的簡化陰影幾何驗證，而不是讓每張角色 Sprite 都直接投射完整動態陰影。

6. 戰鬥系統與鏡頭如何配合？
這裡回到《The Severed Gods》最有特色的 Break／Sever。

我會讓電影鏡頭依據 戰鬥事件（Combat Event） 選擇演出，而不是讓每個技能直接操控攝影機。

例如：
事件	鏡頭行為	世界演出
Normal Hit	小幅推近或維持原鏡頭	命中閃光、輕微擊退
Critical Hit	聚焦攻擊者與命中位置	Hit Stop、音效強化
Shield Break	快速聚焦遭破防的部位	破甲、碎片、敵人失衡
Part Sever	部位特寫、切斷瞬間的構圖	部位破壞、姿態改變
Boss Phase	拉遠或低角度仰拍	BOSS 動作、環境變化
關鍵是鏡頭如何找到正確的 BOSS 部位
我會讓敵人每個可破壞部位具有獨立的 Marker3D。
Boss (Node3D)
├── BossVisual
│   └── AnimatedSprite3D
│
├── CombatParts
│   ├── Head
│   │   └── FocusAnchor (Marker3D)
│   ├── LeftArm
│   │   └── FocusAnchor (Marker3D)
│   └── RightLeg
│       └── FocusAnchor (Marker3D)
│
├── CombatLogic
└── AnimationController


例如右手被斬斷：

BodyPartSevered(right_arm) → CameraDirector 對焦 RightArm/FocusAnchor → 播放斷肢動畫與特效 → 返回戰鬥鏡頭。

但這裡有一個 2D Sprite 特有的難題：部位在不同方向動畫中的圖像位置，未必與固定的 3D Marker 完全對齊。

所以我們需要研究類似 RO 的 ACT Anchor 系統，讓攻擊命中點、武器位置和角色方向動畫同步。近距離特寫可以使用逐影格 Anchor 或專用演出資料，不能只依靠一個靜態 Marker。

這會是電影式 Break／Sever 演出能否精準的關鍵。
7. 手機遊戲的鏡頭控制要分開考慮
你之前的 Godot 遊戲主要以手機直立畫面為目標。如果這次仍以 9:16 為主要方向，Camera Director 還要處理畫面構圖。

例如橫向電影鏡頭常能同時容納兩個相隔很遠的角色，但直立螢幕比較容易將其中一個角色裁切掉。
探索構圖
角色偏中心，保留前方地形與可探索空間。

電影構圖
透過前後深度、大小與縱向構圖呈現敵我雙方。


以上為示意構圖，並非遊戲實際畫面。手機上另一個要研究的問題是：電影演出是否中斷玩家操作？

如果是回合制戰鬥，技能執行期間接管鏡頭相對自然。

但如果是即時動作戰鬥，長達兩秒的電影演出可能讓玩家無法看清其他敵人或閃避攻擊。

因此 Camera Director 應支援不同演出強度，甚至能略過非關鍵演出。

這些可以先設計成系統能力，而不用現在決定戰鬥類型。

8. 我建議先驗證的三個技術問題
測試	內容	驗證目標
A. RO Camera	3D 草地、建築、八方向 Sprite、360° 水平旋轉	人物朝向、遮擋與相機碰撞是否自然
B. Cinematic Transition	從探索鏡頭推到角色特寫，再返回	不跳鏡頭、不重置朝向、不暴露紙片感
C. Break／Sever	一隻三部位 BOSS、一次破甲與部位破壞	鏡頭、Sprite、命中點與特效能否同步
手機效能可以從 A 開始就持續記錄，而不是等到全部做好後才最佳化。對 3D 場景，Godot 官方也建議審慎使用透明材質、動態光源及陰影，並考慮烘焙光照。

Godot Engine (stable) documentation in English




我的技術判斷是：探索使用 RO 式八方向 Sprite、3D 地圖與自由 Orbit Camera，有相當明確的實作路徑；真正需要先做實驗的是電影鏡頭靠近角色後的動畫品質，以及 Break／Sever 的部位定位。

另外，若以新款手機為主，Godot 的 Mobile Renderer 值得先測試，但若需要支援更多舊機型，也必須將 Compatibility 的功能差異納入評估。
