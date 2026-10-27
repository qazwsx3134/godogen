《The Severed Gods》電影式戰鬥鏡頭 × HD-2D 美術技術研究
Godot 4.x｜2D Sprite × 3D Environment × Cinematic Camera × Shader

這次我想聚焦一個核心問題：

如何讓像素角色、立體場景、光影與電影式鏡頭形成統一的視覺語言，同時不犧牲戰鬥資訊的清晰度？

因為你選擇了電影式戰鬥鏡頭，技術上的關鍵不只是把相機移到角色旁邊，而是相機移動之後，角色的 Sprite、地面透視、陰影、光照和攻擊特效依然要自然。
一、先看《The Severed Gods》的視覺特徵
自然環境與角色融合
草地、山丘、岩石、人物與遠方天空形成完整的空間層次。
戰鬥光影演出
高亮度技能光效與較暗的環境形成明顯對比，讓攻擊有視覺重量。

這裡最值得注意的不是像素密度，而是三件事情：
- 空間存在感：角色不是貼在背景上的圖像，而是看起來確實站在地面上。
- 光照一致性：不同美術元素能呈現同一個時間、天氣與環境。
- 動態焦點：平常玩家注意整個戰場，攻擊時注意角色與命中位置。
對於《The Severed Gods》本身，我們能從畫面分析視覺結果，但尚不能確認它實際使用何種渲染架構或電影鏡頭程式。因此下面是針對 Godot 的工程研究，而不是宣稱原作採用了相同技術。

二、電影式戰鬥鏡頭：其實需要兩套思維
我會將電影式鏡頭分為：

Gameplay Camera（玩法鏡頭）：確保玩家看得懂戰鬥。

Cinematic Camera（演出鏡頭）：在關鍵時刻放大戰鬥的戲劇性。

但不一定要真的建立兩個 Camera3D。技術上也能由同一台 Camera 接收不同的鏡頭控制指令。
電影式戰鬥鏡頭狀態
Battle Overview
能看見敵人、角色、部位與技能目標

Attack Focus
把觀眾注意力集中到攻擊者與目標

Break Focus
強調破甲、失衡與敵人的反應

Cinematic Finish
特殊招式、Sever 或 BOSS 戰階段演出



這些鏡頭的差別不只是 Zoom
我認為應該先研究三種鏡頭運動，下面這個示意圖可以切換觀察。

全景攻擊破防終結

戰場全景：讓玩家判斷敵人的部位與隊伍位置。
互動示意：利用 2D 變換模擬取景變化，並非實際的 3D 攝影機輸出。
真正的電影鏡頭至少需要控制六個屬性：
屬性	影響
Camera Position	鏡頭從哪裡觀看
Look-at Target	觀眾注意哪個目標
Field of View	廣角或壓縮透視
Camera Roll	斜角、動態張力
Focus Distance	景深焦點
Transition Curve	鏡頭移動的節奏
這裡有一個技術上的重要區別：

Camera Move、Camera Zoom、Camera Cut 是三種不同的演出工具。

鏡頭不必每次攻擊都動。小攻擊維持穩定，重要攻擊才切換構圖，反而能讓關鍵動作更有份量。

三、角色 Sprite 與電影鏡頭：最大的技術難題
這是我認為整個方案最需要提前驗證的地方。

假設我們使用：
- 3D 地形
- 2D 像素角色
- 可移動的 Camera3D
- 動態光源與景深
當相機繞著角色轉動時，2D Sprite 本身並不會產生真正的側面、背面或立體結構。

所以我們需要決定角色如何面對鏡頭。
三種 Sprite 方案比較
A. 固定朝向 Sprite

角色基本上保持固定的朝向。鏡頭只能在有限範圍內移動，以避免看穿紙片。
適合：固定橫向戰鬥、小幅推進、拉遠、平移。











B. Billboard Sprite

Sprite 自動面向攝影機，可以讓相機較自由地移動。

但角色可能像一張永遠朝著鏡頭的卡片。尤其側身揮劍或跳躍時，動作的方向感會不自然。
適合：主要維持遠景構圖、不常做近距離側面特寫。











C. 多方向 Sprite（Directional Sprite）

為角色製作正面、斜面、側面、背面等不同方向的動畫，再依照攝影機角度切換。
適合：鏡頭有一定角度變化，角色需要更自然的立體感。











Godot 的 AnimatedSprite3D 支援 Billboard、像素尺寸、光照選項與貼圖過濾控制，可作為這三種方案的共同基礎。

Godot Engine (stable) documentation in English



多方向角色的實際成本
假設一位角色有：
- 8 個方向
- 6 種動作
- 每個動作 8 幀
那麼需要：
\[
8 \times 6 \times 8 = 384 \text{ frames}
\]

而且這還沒有加入額外的武器、服裝和表情。

這是美術工作量會急遽增加的地方。

因此值得思考的是：

電影式鏡頭是否真的需要完整 360° 旋轉？

不一定。

例如電影鏡頭可以只在角色正面與斜側面之間移動，仍然能營造戲劇性。這樣就可能只需要少量方向的 Sprite，而不必一開始製作完整八方向動畫。

這也是固定舞台加上有限角度電影鏡頭具有成本優勢的原因。

四、Godot 的 Cinematic Camera Rig 架構
從系統設計來看，我會避免將鏡頭 Tween 直接寫在每個技能腳本裡。

否則未來新增 50 種技能，就可能出現 50 套難以維護的鏡頭移動程式。

更合理的是建立一套共用的 Camera Director。
BattleScene (Node3D)
│
├── CameraDirector
│   └── CameraRig (Node3D)
│       ├── Camera3D
│       └── ShakePivot
│
├── Stage (Node3D)
│   ├── Terrain
│   ├── Background
│   └── EnvironmentProps
│
├── Actors (Node3D)
│   ├── Heroes
│   └── Enemies
│
├── Lighting
│   ├── DirectionalLight3D
│   └── EffectLights
│
├── VFXDirector
└── BattlePresenter


Camera Director 負責什麼？
它接收演出請求，而不是決定戰鬥結果。

例如：
BattlePresenter
    │
    ├── Request Camera Shot
    │       ├── Target
    │       ├── Duration
    │       ├── FOV
    │       └── Easing
    │
    ├── Request Attack Animation
    │
    └── Request VFX


實作上，我會把鏡頭設定儲存為 Resource，方便每個招式或事件引用。
class_name CameraShotData
extends Resource

@export var duration: float = 0.4
@export var local_offset: Vector3 = Vector3(0, 2, 7)
@export var target_offset: Vector3 = Vector3.ZERO
@export var fov: float = 55.0
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_CUBIC


這些數值只是原型預設值，不是原作數據。

Camera Director 可以根據攻擊者與目標的位置，換算 Camera Rig 的世界座標，再平滑移動到指定構圖。

但還需要處理四個工程問題：
1. 鏡頭中斷：角色死亡或戰鬥結束時，正在播放的鏡頭如何停止？
2. 鏡頭優先權：一般攻擊與 BOSS 終結技同時請求鏡頭時，誰優先？
3. 目標失效：目標被擊殺或部位已破壞時，鏡頭要看哪裡？
4. 安全構圖：移動過程不能讓角色、部位或關鍵 UI 完全離開畫面。
我會優先使用單一主 Camera3D，搭配 CameraDirector 的鏡頭設定資料，而非讓每個技能自行操控 current Camera。

五、Shader 與光影：如何避免角色像是貼上去的？
這部分可以拆成四個視覺問題，每個問題都對應不同技術。
視覺問題	建議研究的技術	Godot 功能
角色沒有接地感	Contact Shadow	QuadMesh、透明貼圖或 Decal
角色不受環境影響	Stylized Lighting	Sprite3D Shaded、自訂 Spatial Shader
背景沒有景深	Depth of Field	CameraAttributesPractical
攻擊不夠有重量	Emission + Glow + Particles	ShaderMaterial、WorldEnvironment、GPUParticles3D
1. 接地陰影







neive.tistory.com


在 2D Sprite + 3D 世界的情境中，我會先用簡單的橢圓形陰影，而不是立即追求複雜的即時陰影。

原因是 Sprite 的透明材質和真實 3D 陰影可能出現不符合角色像素輪廓的結果。

接地陰影可以隨著角色跳躍或擊飛而改變透明度與大小。

例如角色跳起來時，陰影稍微縮小、變淡，玩家就能理解角色與地面的距離。
2. 角色 Shader
對像素角色，我想比較三個設定：
角色光照方案

Unshaded — 完全保留原始像素顏色

Shaded — 接受場景 3D 光照

Hybrid — 保留手繪明暗，增加環境補光與受擊閃光

折衷的風格化光照

透過自訂 Spatial Shader 或材質參數，限制受光範圍，並在命中時加入額外補光和閃白。適合驗證像素角色能否融入場景。


需要特別注意：Sprite3D.shaded 不是完整的角色光照解決方案。若要進一步控制明暗階調、受擊高亮和光照混合，可能要改用 QuadMesh + ShaderMaterial，或透過材質覆寫與專用的 Spatial Shader。
3. Depth of Field
這是塑造 HD-2D 風格的重要元素，但我會對手機效能比較謹慎。

Godot 4 的 Forward+ 與 Mobile 渲染器都支援景深，但採用不同的實作方式；Compatibility 渲染器不支援相同的內建 DOF。

Godot Engine (4.4) documentation in English
+1




電影鏡頭可以在技能演出時調整焦點距離，例如從攻擊者逐漸轉移到 BOSS 的頭部。

不過我不建議平常戰鬥就使用過強的模糊。

因為 Break／Sever 需要玩家清楚辨識特定部位的位置與狀態。
4. 技能光效與角色補光
另一個常被忽略的問題是：角色受到魔法攻擊時，周圍的世界是否也有反應？

假設 BOSS 發射紫色能量光束。

理想情況下，不應該只有紫色粒子出現在前景。地面、附近岩石以及受攻擊角色，也可以在短時間內出現紫色補光。
可以觀察紫色技能光效如何佔據視覺焦點。若在 Godot 重現，可進一步測試局部燈光與角色材質的同步變化。
我會讓 VFXDirector 同時控制：
- 粒子發射。
- 技能軌跡與光暈。
- 附近的短暫 OmniLight3D。
- 角色材質的補光參數。
- 命中時的 Camera Impulse。
這些效果共同發生，才比較容易讓技能融入場景，而不只是像 UI 動畫一樣蓋在畫面上。

Godot 的 Glow、DOF 和部分 Screen-space Effect 需要依渲染器與裝置能力決定是否啟用。特別是自動曝光不適合直接假設在 Mobile Renderer 可用。

Godot Engine (4.6) documentation in English
+1




六、Break／Sever 如何與電影鏡頭整合？
我認為最值得深入的是 Animation Timeline + Camera Direction。

例如同樣是擊中敵人，普通攻擊、破防與部位切斷應該使用不同層級的演出。

以下是我設計的原型演出節奏，並非《The Severed Gods》的實際動畫數據。
攻擊演出時間軸

HitBreakSever

前搖



0.25s


鏡頭推進



0.22s


破甲衝擊



0.16s


敵人失衡



0.38s


鏡頭回位



0.29s




預估總演出時間
1.30s

這是各階段時長的比較示意，不是按絕對時間位置排列的甘特圖。正式演出可允許鏡頭、動作與 VFX 重疊。
真正製作時，鏡頭、動作和粒子不必全部依序執行。

例如鏡頭開始推進時，角色就已經進入攻擊前搖。技能擊中敵人的同一個瞬間，鏡頭停頓、畫面閃光和音效也一起發生。
我會讓演出採用資料驅動
CinematicSequence
├── CameraTrack
│   ├── FocusAttacker
│   ├── PushIn
│   └── ReturnToOverview
│
├── AnimationTrack
│   ├── Anticipation
│   ├── Attack
│   └── Recovery
│
├── VFXTrack
│   ├── SlashEffect
│   ├── BreakParticles
│   └── ImpactLight
│
└── AudioTrack
    ├── Swing
    ├── Impact
    └── Break


Godot 可以透過 AnimationPlayer 管理可預先製作的時間軸，並搭配 Tween 處理執行時才知道位置的鏡頭運動。

若技能需要根據任意敵人部位動態取景，CameraDirector 則負責把目標的世界座標換算成合適的構圖。

這種設計也方便未來加入不同武器、技能、BOSS 以及 Roguelite 遺物效果，而不必讓每個攻擊重新實作相機系統。

七、我們現在需要解決的技術決策
如果將以上內容整理成工程優先順序，我認為有三個問題還不適合太早定案。
問題	核心取捨
角色使用 Sprite3D 還是多方向 Sprite？	美術製作成本 vs. 鏡頭自由度
使用單一 3D Render 還是多 Viewport 合成？	光影與遮擋一致性 vs. 像素控制精度
電影鏡頭可以移動多少角度？	戰鬥表現力 vs. 人物動畫與部位辨識
因此我會先做一個最小視覺技術驗證，而不急著製作完整遊戲。
最小驗證場景

一個草地戰場、一名像素人物、一隻具有三個部位的 BOSS，搭配一次攻擊、一次 Break 和一次 Sever。

這個場景可以驗證：
- 鏡頭推進時，Sprite 是否仍然自然。
- 角色與地面光影是否一致。
- BOSS 部位在鏡頭切換後是否容易辨識。
- 技能特效與場景能否共同呈現立體感。
- 同一套畫面在手機 Mobile Renderer 的實際效能。

這個實驗最大的價值，是讓我們能用相同素材比較不同技術，避免先投入大量美術資產才發現鏡頭與 Sprite 不相容。
八、下一個值得討論的問題：角色本身要多立體？
在電影式鏡頭的前提下，角色如何被渲染可能比景深和光暈更影響最終品質。

我想讓你從兩個角度選擇下一步要研究什麼。
1. 你比較想研究哪種角色製作技術？

2D Pixel Sprite 放進 3D 世界（保留手繪像素風）

多方向 Sprite（更自然地配合攝影機角度）

3D 模型渲染成 Pixel Art（利用 3D 動畫製作像素素材）

先比較三種技術的實際效果與成本


2. 電影式鏡頭應該有多大的移動自由度？

有限角度：推進、拉遠、小幅側移、仰角

大範圍運鏡：繞著角色或 BOSS 旋轉

尚未決定，想比較視覺效果與成本

繼續研究角色渲染技術
我目前最想驗證的組合是 2D Pixel Sprite + 3D 場景 + 有限角度的電影鏡頭。它能保留像素角色的美感，也具備一定的鏡頭自由度；但這仍是一項待測試的技術假設，而不是最終方案。

技術參考：Godot SpriteBase3D、Environment & Post-processing、CameraAttributesPhysical。
















接下來想研究的角色技術：2D Pixel Sprite 放進 3D 世界。鏡頭自由度：大範圍運鏡。請從 Godot 節點、Shader、動畫製程與效能繼續深入討論，先不要定案遊戲架構。












處理時間為 1m 5s







《The Severed Gods》進階技術研究：2D Pixel Sprite × 3D 世界 × 360° 電影式運鏡
Godot 4.x｜Character Rendering｜Camera System｜Shader｜Animation Pipeline｜Mobile Performance

這次我們要研究的技術組合是：
- 角色維持 2D Pixel Art，不直接改成 3D 角色。
- 環境使用真正的 3D 空間，包括地形、光照、遮擋與透視。
- 攝影機能大範圍移動，包含環繞角色、低角度仰拍、BOSS 特寫。
- 整體畫面保留類似《The Severed Gods》的 HD-2D 美術感。
我先提出這輪最重要的結論：

Godot 完全可以讓 2D Sprite 存在於 3D 世界，也可以讓 Camera3D 自由移動；真正困難的是如何在不同觀看角度下，讓平面的 Sprite 仍然具有可信的角色外觀。

Shader 可以改善光照、像素邊緣、輪廓與景深，但不能憑空創造角色原本不存在的側面和背面。

所以我們要研究的是一套 View-Dependent Character Rendering（依視角決定角色呈現方式的系統）。

一、先理解大範圍運鏡帶來的問題
從不同攝影機角度觀看同一個 2D Sprite
0°
90°
180°
270°
360°




平面 Sprite 的概念投影示意。實際 3D 相機的透視、Billboard 與背面剔除設定會影響顯示結果。

我們可以把這個問題歸納成三種不同的技術方向：
技術	相機繞到側面時	相機繞到背面時
固定 Sprite	圖像逐漸變窄	看到反面或消失
Billboard	角色始終面向鏡頭	仍是同一張角色圖像
Directional Sprite	切換側面圖像	切換背面圖像
對於真正的大範圍運鏡，前兩種單獨使用都會暴露限制。

所以我認為值得測試一個組合：

AnimatedSprite3D + Directional Sprite + Camera-relative Rotation + Cinematic Camera Director

這不是直接選定遊戲架構，而是目前最能針對你提出的視覺需求進行驗證的候選方案。

二、Godot 節點層：角色應該如何組成？
我會先將角色拆成三個互不干擾的系統：世界位置、視覺呈現與戰鬥定位。
CharacterRoot (Node3D)
│
├── CharacterVisual (Node3D)
│   ├── SpritePivot (Node3D)
│   │   └── AnimatedSprite3D
│   │
│   ├── GroundShadow (MeshInstance3D)
│   └── CharacterVFX (Node3D)
│
├── CombatAnchors (Node3D)
│   ├── HeadAnchor (Marker3D)
│   ├── BodyAnchor (Marker3D)
│   ├── WeaponAnchor (Marker3D)
│   └── FeetAnchor (Marker3D)
│
├── AnimationController
├── DirectionController
└── CharacterState


這個切分有一個非常重要的目的：

角色的世界座標不應該隨 Sprite 面向攝影機而改變。

假設你的角色正在面對 BOSS：
- CharacterRoot 決定角色在戰場中的位置與邏輯朝向。
- SpritePivot 決定角色圖像面向哪個角度。
- AnimatedSprite3D 決定目前播放哪個方向的動畫。
- CombatAnchors 提供技能命中、粒子、鏡頭對焦需要的空間座標。
尤其是 Break／Sever 戰鬥，技能應當根據敵人真正的世界座標選取部位，而不是依賴 Sprite 上的某個像素位置。

否則攝影機旋轉後，就可能出現特效打在錯誤位置的問題。
Godot 的 Sprite3D 關鍵設定
官方文件確認 SpriteBase3D 提供 billboard、pixel_size、alpha_cut、shaded、texture_filter、double_sided 等屬性。

Godot Engine (stable) documentation in English



屬性	原型建議	原因
pixel_size	統一角色世界尺寸	避免像素密度不一致
texture_filter	Nearest	保留清楚像素邊緣
billboard	對照測試 Enabled / Disabled	確認方向切換與旋轉控制是否衝突
alpha_cut	優先測試 Discard	減少透明排序問題
shaded	先比較關閉與開啟	檢查手繪明暗是否被破壞
double_sided	依視覺模式決定	避免錯誤地用背面充當角色背影
注意：billboard 與自行控制 SpritePivot 不應同時任意套用旋轉，否則很容易發生雙重旋轉或角色朝向錯誤。

三、最關鍵的系統：Directional Sprite
讓我們先不考慮 8 方向，而是比較從少到多的方向數量。
角色方向採樣實驗

4 方向8 方向16 方向



相機相對角度 67°

方向誤差 22°

此模型假設素材方向等間距分布，並採最近方向切換；不代表不同方向必須實際製作成完全等距的角色畫面。
4、8、16 方向有什麼差別？
方向數	最大角度誤差	美術成本
4	45°	低
8	22.5°	中
16	11.25°	高
方向愈多，相機繞行時產生的角度跳變通常愈小，但動畫製作成本也會增加。

這裡還有一個容易忽略的設計問題。

假設鏡頭以每秒 180° 環繞角色，8 方向素材平均每 45° 就要切換一次，也就是每 0.25 秒可能出現一次方向改變。

如果 Sprite 姿態差異明顯，玩家會看到角色突然跳變。

因此除了多方向素材，我們還需要設計：
- 方向切換時機。
- 動畫 Frame 同步。
- 切換的 Hysteresis（遲滯閾值）。
- 相機移動速度與方向素材數量的關係。
方向切換的 GDScript
以下是可以作為 Godot 4.x 原型起點的方向計算。
extends Node3D

@export var actor_root: Node3D
@export var camera: Camera3D
@export var sprite: AnimatedSprite3D

const DIRECTION_COUNT := 8
const DIRECTION_STEP := TAU / DIRECTION_COUNT

func _process(_delta: float) -> void:
    var to_camera := camera.global_position \
        - actor_root.global_position
    to_camera.y = 0.0

    if to_camera.length_squared() < 0.0001:
        return

    var camera_direction := to_camera.normalized()
    var facing_direction := -actor_root.global_basis.z
    facing_direction.y = 0.0
    facing_direction = facing_direction.normalized()

    var angle := atan2(
        facing_direction.cross(camera_direction).y,
        facing_direction.dot(camera_direction)
    )

    var direction_index := posmod(
        roundi(angle / DIRECTION_STEP),
        DIRECTION_COUNT
    )

    var animation_name := &"idle_%d" % direction_index

    if sprite.animation != animation_name:
        sprite.play(animation_name)


這段程式有幾個前提：
1. 角色的邏輯正面採 Godot 常用的 -Z 方向。
2. 只處理水平面上的攝影機方位，不處理俯仰角。
3. idle_0 到 idle_7 已經在 SpriteFrames 建立。
4. 各方向的順序必須和程式定義一致。
5. SpritePivot 要另外設定為適當的視覺面向模式。
它還不是正式的 Direction Controller，因為實際上需要保留動畫進度，不能每次切換方向都讓攻擊動畫重新開始。

Godot 的 AnimatedSprite3D 提供 frame、frame_progress 與 set_frame_and_progress()，可以協助保存方向切換前後的動畫進度。

Godot Engine (4.5) 正體中文 (台灣) 文件




我會將這個功能視為優先驗證項目。

四、另一個問題：360° 水平運鏡不等於真正的自由運鏡
即使準備了 8 方向素材，也只解決水平方位角（Yaw）。

電影鏡頭還有俯仰角（Pitch）。

例如：









低角度仰拍
強調英雄氣勢









平視
保持動作可讀性









高角度俯拍
呈現空間與站位

如果攝影機從角色頭頂往下看，單純水平 8 方向 Sprite 無法呈現正確的人物頭頂、肩膀與地面關係。

因此可以比較三種做法：
做法	優點	缺點
限制俯仰角	低成本、維持畫風	運鏡自由度有限
增加高低角度 Sprite	可維持手繪風格	素材量快速增加
隱藏 3D 代理模型	支援更多角度與光影	需要額外 3D 製程
第三種做法值得研究：角色仍然以 Pixel Sprite 顯示，但背後建立簡化的 3D Proxy，用於空間定位、陰影、遮擋與輔助視角判斷。

這不代表要把角色改成真正的 3D 美術，而是讓不可見的 3D 結構支援 2D 畫面的空間行為。

不過要注意，3D Proxy 本身不能補出缺失的角色圖像。如果鏡頭真的需要看見頭頂和背部細節，仍然需要有相應的可見素材或其他替代呈現。

五、Shader：像素角色如何接收 3D 世界的光？
現在進入我認為第二個重要的技術難題。

AnimatedSprite3D 的 shaded 屬性能讓光源影響 Sprite，但預設圖像基本上仍是一個平面。

如果整張 Sprite 共用平面法線，臉部、身體和武器通常不會有真正對應自身幾何形狀的光照差異。
我想比較三個階段
第一階段：Unshaded + 手動環境補光

保留角色的原始像素顏色，透過色彩調整和命中閃光模擬環境反應。

適合先確認角色是否與場景色調一致。

第二階段：Shaded + 階調控制

讓角色接受 3D 光照，再控制過度平滑的亮度變化，形成比較接近像素風的明暗階調。

需要評估環境光是否破壞原本手繪的陰影。

第三階段：Normal Map + 風格化光照

額外為角色建立法線貼圖，使不同像素區域對光產生不同反應。

可以改善平面感，但每個動畫影格的法線也需要保持一致。


一個簡單的 Pixel Lighting Shader
下面是用於 QuadMesh + ShaderMaterial 的 Godot Spatial Shader 概念原型。

它保留貼圖原始顏色，加入階梯式方向光照以及受擊閃白參數。

shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled,
            diffuse_lambert, specular_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float light_steps : hint_range(2.0, 8.0, 1.0) = 4.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ambient_tint : source_color = vec3(1.0);
uniform float ambient_strength : hint_range(0.0, 1.0) = 0.2;

void fragment() {
    vec4 tex = texture(sprite_texture, UV);

    ALBEDO = mix(tex.rgb, vec3(1.0), hit_flash);
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = 0.5;

    // 簡化的環境補色
    EMISSION = tex.rgb * ambient_tint * ambient_strength;
}

void light() {
    float ndotl = max(dot(NORMAL, LIGHT), 0.0);
    float stepped = floor(ndotl * light_steps) / light_steps;

    DIFFUSE_LIGHT +=
        ALBEDO * LIGHT_COLOR * stepped * ATTENUATION;
}



這段是研究用的起點，而非可直接投入正式專案的完整角色材質。

有幾點需要特別注意：
- ALPHA_SCISSOR_THRESHOLD 會讓透明像素使用硬切邊緣，適合測試銳利像素輪廓。
- 如果角色是 Sprite Sheet，必須正確處理每幀 UV，不是直接把整張圖塞進單一 Quad。
- ambient_strength 只是簡化補色，不等於物理正確的環境光。
- 法線目前仍由平面幾何提供，還沒加入真正的角色 Normal Map。
- 如果啟用原本的預設光照模式與自訂 light()，應對照不同渲染器的實際輸出確認一致性。
Godot Spatial Shader 支援 light()、深度繪製模式與透明渲染設定，因此可以用這種方式建立自訂的角色光照模型。

Godot Engine (latest) documentation in English



我認為最值得測試的是 Normal Map
假設角色穿著鎧甲：
- 頭部朝向光源時，臉部更亮。
- 胸甲有獨立的高光方向。
- 武器在揮動時反射附近的技能光。
- 背光時仍保留適當輪廓。
這些效果如果只依靠一張平面 Sprite，通常比較難細緻控制。

但只要為角色加入 Normal Map，就可以讓不同區域擁有不同的表面法線。

工程上可使用第二張貼圖來存放法線資訊，讓 Shader 在切換動畫影格時，同步切換顏色與法線資料。

技術難點是動畫製作成本，而不是 Shader 能不能做到。

如果每個方向、每個影格都需要 Normal Map，就必須思考是否用 Blender 的 3D 模型先產生法線素材，再轉換成像素風。