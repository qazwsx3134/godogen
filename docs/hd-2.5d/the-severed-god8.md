
五、建築遮擋的四種視覺處理
這是我認為最值得比較的技術部分。
A. 整體淡出
最易製作










一般建築









淡出示意風格

將擋住玩家的建築整體降低可見度。

缺點是整棟建築突然變淡可能讓玩家失去對場景的空間感。

B. 局部圓形透視（Circular Cutout）

只有角色附近的一小塊牆壁或樹冠被切開，其他區域保持原狀。

適合保留建築輪廓與立體感。

但必須處理圓形邊緣、角色位置、畫面座標以及遮擋判斷。

C. Dither Dissolve（網點溶解）

不使用傳統 Alpha Blending，而是根據規則捨棄部分像素。

例如原本 100% 可見，接著只有約 70%、40%、10% 的像素被保留。

特別值得在像素風 RPG 測試，因為視覺上可以和 Pixel Art 結合。

D. 角色輪廓透視（X-Ray Silhouette）

建築本身保持不透明，但被遮住的角色顯示外框或半透明剪影。

適合戰鬥目標或重要 NPC，不適合每個路人都持續使用，否則畫面會很雜亂。


Godot 4.6 的 BaseMaterial3D 已經提供 X-Ray Stencil Preset，可以顯示被牆壁遮住的角色剪影。但官方同時將 Stencil 功能標示為實驗性，未來 API 可能變動，因此它是值得驗證的選項，而非可以直接假設跨平台穩定的基礎。

Godot Engine (4.6) documentation in English
+1




這四種效果其實可以混合使用：

樹冠採用局部 Cutout，室內屋頂採用 Dither Dissolve，重要戰鬥目標則用 X-Ray Outline 作為補充。

但要避免所有效果同時發生，否則很容易失去畫面的層次。

六、Shader 實作：Dither + 局部 Cutout
如果目標是像素風 2.5D RPG，我會優先研究 Dither Dissolve + Circular Cutout。

這兩種效果可以共享一套 Shader，但由不同的系統決定何時啟動。
- OcclusionResolver 判斷是不是擋到玩家。
- BuildingVisibilityController 判斷玩家是否進入室內。
- Shader 只負責決定哪些像素要被繪製。
6.1 互動比較：遮擋時如何顯示角色

原始透明網點挖洞輪廓




65%

這是各種效果的 2D 概念示意。Dither 僅模擬網點視覺，並非 Godot 真正的逐像素深度渲染。
6.2 Godot Spatial Shader 範例
下面這個 Shader 可以掛在建築的 MeshInstance3D 上。它支援：
- 透過 fade_strength 控制整體溶解。
- 透過 hole_enabled 啟用角色周圍的局部透視。
- 使用世界座標產生固定網點，減少相機旋轉時圖樣跟著滑動的問題。
- 每個物件有自己的淡出程度，不必替每棟建築建立不同的材質。

shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color;

// 每個 Mesh 可有自己的淡出程度
instance uniform float fade_strength = 0.0;
instance uniform float hole_enabled = 0.0;

// 必須先在 Project Settings > Shader Globals 建立
global uniform vec2 focus_screen_uv;

uniform float viewport_aspect = 1.77778;
uniform float hole_radius = 0.12;
uniform float hole_feather = 0.06;

varying vec3 world_pos;

void vertex() {
    world_pos = (
        MODEL_MATRIX * vec4(VERTEX, 1.0)
    ).xyz;
}

void fragment() {
    vec4 tex = texture(albedo_texture, UV);

    // 基本的硬邊透明
    if (tex.a < 0.5) {
        discard;
    }

    // 角色螢幕座標附近的圓形 Cutout
    vec2 diff = SCREEN_UV - focus_screen_uv;
    diff.x *= viewport_aspect;

    float dist = length(diff);

    float hole = 1.0 - smoothstep(
        hole_radius,
        hole_radius + hole_feather,
        dist
    );

    // 合併整體淡出與局部透視
    float dissolve = max(
        fade_strength,
        hole * hole_enabled
    );

    // 固定於世界空間的 Dither
    vec3 cell = floor(world_pos * 28.0);

    float noise = fract(
        sin(dot(
            cell,
            vec3(12.9898, 78.233, 37.719)
        )) * 43758.5453
    );

    if (noise < dissolve) {
        discard;
    }

    ALBEDO = tex.rgb;
    ROUGHNESS = 0.9;
}



這是供原型測試的 Shader，不是最終最佳化版本。

特別要注意三件事：
1. 這裡使用 discard 模擬網點溶解，而不是 Alpha Blending，因此仍需要檢查抗鋸齒、陰影與硬體上的實際表現。
2. 當 Shader 用於 Shadow Pass 時，螢幕座標相關計算不一定與主攝影機一致，可能使陰影出現不自然變化。正式版本應單獨設計淡出物件的陰影策略。
3. 世界空間網點不會隨攝影機滑動，但網點的大小、密度和模型尺度需要調整，否則可能產生摩爾紋或明顯的雜訊。
如果只是簡單的整體淡出，也可以優先使用 StandardMaterial3D 的 Alpha Hash 模式；這是比自己寫完整 Shader 更容易驗證的方式。Godot 官方指出 Alpha Hash 可避免部分透明排序問題，且能支援陰影。

Godot Engine (4.6) documentation in English



6.3 如何從 GDScript 控制 Shader？
例如 Camera 偵測某棟建築擋住角色後：
# MeshInstance3D
roof_mesh.set_instance_shader_parameter(
    "fade_strength",
    0.85
)

wall_mesh.set_instance_shader_parameter(
    "hole_enabled",
    1.0
)


Godot 的 Per-instance Uniform 允許多個物件共用 ShaderMaterial，但各自使用不同的參數，這很適合建築、樹木與遮擋系統。

Godot Engine (4.6) documentation in English




角色螢幕座標則可由 Camera3D.unproject_position() 換算：
var screen_pos := camera.unproject_position(
    actor_focus.global_position
)

var viewport_size := camera.get_viewport() \
    .get_visible_rect().size

var uv := screen_pos / viewport_size

RenderingServer.global_shader_parameter_set(
    "focus_screen_uv",
    uv
)


這個方法可以讓建築 Shader 知道：角色目前出現在畫面的哪個位置。

Godot Engine (latest) documentation in English
+1




不過，我不建議讓所有建築都持續執行 Circular Cutout。

比較合理的是先由 CPU 判斷哪些物件確實擋住角色，再啟用那些物件的局部 Shader 效果。

七、樹木遮擋：應該和建築分開處理




















9









樹木比建築更麻煩，因為樹冠通常包含很多不規則的透明邊緣。

如果整棵樹一起淡出，畫面可能很不自然。

我認為可以把樹拆成三個部分。
TreeRoot (Node3D)
│
├── Trunk (MeshInstance3D)
│   └── Opaque Material
│
├── Branches (Node3D)
│   └── MeshInstance3D
│
├── Crown (Node3D)
│   ├── LeafPlane_A
│   ├── LeafPlane_B
│   └── LeafPlane_C
│
├── OcclusionBody (StaticBody3D)
└── WindController


7.1 樹幹與樹冠的遮擋邏輯不同
物件	建議方式	原因
樹幹	保持不透明，必要時顯示角色輪廓	樹幹提供空間感
大型樹枝	局部 Dither / Cutout	避免完全遮蔽角色
樹冠	Camera-to-Actor Cutout	大面積樹葉容易擋住玩家
低矮草叢	一般 Alpha Scissor	通常不需要動態遮擋處理
此外，大量樹葉如果都使用 Alpha Blending，容易造成透明排序和 Overdraw 成本。

對像素風樹葉，我會優先研究 Alpha Scissor 或 Alpha Hash，再根據場景決定哪些樹冠需要局部 Cutout。
7.2 樹葉搖晃應該影響哪一層？
我會讓樹幹保持穩定，只讓葉片與末端枝條產生小幅位移。

可以透過 Vertex Shader 根據：
- 世界座標
- TIME
- 樹葉高度
- 風向
- 頂點權重
產生不同程度的搖晃。

但是角色遮擋碰撞不必跟著每片葉子移動。使用較簡單的樹冠遮擋體積即可，避免大量動態碰撞更新。

另外，對大量重複樹木可以研究 MultiMeshInstance3D，不過 Per-instance Uniform 的使用方式與一般 MeshInstance3D 不同，通常需要搭配 MultiMesh 的自訂資料，不能直接把每棵樹視為獨立的 GeometryInstance3D。

八、室內屋頂：我認為需要獨立的 Room Visibility System
這部分我會和一般建築遮擋明確區分。

因為進入建築物後，問題已經不是「有一個物件擋住玩家」，而是玩家所在的空間發生改變。

例如從屋外走進房屋：
1. 玩家靠近門口。
2. 穿過門檻，進入室內區域。
3. 屋頂逐漸淡出。
4. 前方牆壁視攝影機角度局部隱藏。
5. 玩家離開後，屋頂和牆壁重新顯示。
這個過程不適合完全依賴射線。
8.1 建築最好在模型階段就拆分
BuildingRoot
│
├── Exterior
│   ├── OuterWalls
│   ├── Windows
│   └── Decorations
│
├── Interior
│   ├── Floor
│   ├── Furniture
│   └── InnerWalls
│
├── RoofCutaway
│   ├── RoofMain
│   ├── RoofTrim
│   └── UpperDecorations
│
├── FrontWallCutaway
│   ├── FrontWall
│   └── UpperWall
│
├── Physics
│   └── StaticBody3D
│
├── RoomArea (Area3D)
└── BuildingVisibilityController


尤其是屋頂、牆壁與碰撞體應該分開。

屋頂視覺上消失，不代表屋頂的實體碰撞也要消失。

例如玩家走進房屋後，可能仍然不應該穿過牆壁，也不應該讓原本無法通過的地方變成通道。
8.2 屋頂狀態機
我會把屋頂可見性視為一套獨立狀態機。
Exterior：玩家在室外
屋頂正常顯示

Entering：穿越入口
判斷所屬房間與樓層

Interior：玩家在室內
屋頂隱藏、前方牆壁按鏡頭調整

Leaving：玩家離開
屋頂逐步恢復

最基本的實作可以使用 Area3D.body_entered 和 body_exited。

但實際上還需要處理門檻附近反覆進出的情況。

我會加入 Hysteresis，例如必須確定角色已經離開室內區域一定距離，才恢復屋頂，而不是一碰到 Area3D 邊界就立即切換。
8.3 多樓層建築是另一個難題
如果一棟房屋有兩層樓，當玩家在一樓時：
- 二樓地板是否顯示？
- 二樓家具是否顯示？
- 屋頂是否完全消失？
- Camera 從低角度仰拍時，是否能看到二樓地板底部？
這些會直接影響美術如何拆模型。

我認為至少可以比較兩種模式。
模式	描述	主要代價
Roof Hide	直接隱藏屋頂和指定樓層	較簡單，但室內外切換較明顯
Dynamic Cutaway	根據人物樓層和攝影機角度，動態切除前方結構	更有電影感，但資產與狀態管理複雜
如果攝影機具有大範圍 Pitch，我比較想研究 Dynamic Cutaway。

原因是純粹隱藏整個屋頂，有時會讓建築突然看起來像一個沒有上半部的盒子。

保留一部分屋簷、牆角與外輪廓，通常更能維持建築的完整感。

但它不一定適合所有美術風格。

九、三套系統必須共同知道「實際攝影機位置」
這裡有一個容易出現的工程錯誤。

假設玩家正在觸發電影鏡頭：

Camera Director 希望相機轉到 BOSS 右側，但 SpringArm 因為撞到牆壁，把相機移到比較靠近 BOSS 的地方。

此時：
- Sprite Direction Resolver 不能只根據預期鏡頭位置選擇素材。
- Occlusion Resolver 不能只根據預期鏡頭位置偵測遮擋。
- VFX Director 也不能忽略實際 Camera 的畫面範圍。
因此正確的概念流程應該是：
Camera Director
    │
    ▼
Desired Camera Transform
    │
    ▼
Camera Collision Resolver
    │
    ▼
Resolved Camera Transform
    │
    ├── Sprite View Resolver
    │      ├── Yaw Direction
    │      ├── Pitch Direction
    │      └── Animation Frame
    │
    ├── Occlusion Resolver
    │      ├── Ray / Shape Queries
    │      ├── Roof Visibility
    │      └── Cutout Shader
    │
    └── Cinematic Presentation
           ├── Screen-space VFX
           ├── Focus
           └── Framing


Sprite 和遮擋系統都應該依據 Camera 最終被解算後的位置。

實作時，攝影機碰撞偵測可在 Physics Step 處理，視覺插值則與渲染幀同步。需要搭配 Godot 的物理插值，避免角色在 _physics_process() 移動，但相機和 Sprite 在 _process() 計算時出現一幀不同步的抖動。

十、手機效能與實際技術取捨
下面是我會採用的原型驗證優先順序，不代表你的遊戲已經決定使用哪些功能。
技術	主要成本	手機開發注意事項
8 方向 Sprite	貼圖記憶體、動畫資產	Atlas、壓縮、共用素材
多 Pitch Sprite	美術工作量、記憶體	依鏡頭需求載入素材
Camera Raycast	CPU Physics Query	控制檢測數量與頻率
Dither Shader	Fragment Processing	避免大面積高頻網點
Circular Cutout	Fragment Processing	只對候選遮擋物啟用
Alpha Blending	Overdraw、透明排序	大量樹葉需特別注意
Interior Visibility	場景狀態與模型管理	卸載或隱藏不需要的視覺物件
Stencil X-Ray	額外 Pass 與相容性	Godot 4.6 屬實驗功能
我會特別注意一件事：

只有玩家視線確實受到阻擋時，才應該支付額外的遮擋特效成本。

而且 Godot 的 CPU Occlusion Culling 和我們自己實作的 Visibility Occlusion 是兩套不同的系統。前者可以降低不需要繪製的場景成本，後者則主要服務玩家的視覺可讀性。

Godot 官方指出，CPU Occlusion Culling 在有大量房間和牆壁的場景中可能有效，但也會增加 CPU 處理成本。

Godot Engine (4.x) 正體中文 (台灣) 文件




十一、我認為目前最值得實驗的三個技術組合
不是直接選定方案，而是先用相同場景比較結果。

實驗 A：RO 升級版 Character Rendering

3D 場景、8 方向 Sprite、三組 Pitch 素材、Orbit Camera。

驗證 360° Yaw 時角色是否自然，以及在高 Pitch 鏡頭下需要多少補充素材。




實驗 B：Dynamic Occlusion

一棟建築、一棵大樹，Camera 能夠自由環繞。

比較 SpringArm、Alpha Fade、Dither Dissolve 和 Circular Cutout，觀察哪種方式最能保留空間感。




實驗 C：Indoor / Outdoor Cutaway

製作一棟有屋頂、牆壁、家具和門口的小房子。

驗證玩家進出室內、Camera 高低角度切換，以及屋頂局部切除與恢復。



我想先跟你討論的問題
你提到 RO，我覺得這帶出一個很重要的方向分歧：

你希望建築內外仍然是同一個完整的 3D 世界，讓攝影機能穿過門口看到室內，還是接受 RO 那種視覺簡化，把屋頂或牆壁直接隱藏來呈現室內？

兩者都能保留 Pixel Sprite 角色，但前者對 Camera Collision、室內建模、遮擋 Shader 和場景管理的要求更高。

我比較想先聽你對這兩種視覺體驗的偏好，再進一步深入 Godot 的 Dynamic Cutaway Shader、Room Visibility、Portal/Volume-based Camera Control，而不是現在就決定建築架構。