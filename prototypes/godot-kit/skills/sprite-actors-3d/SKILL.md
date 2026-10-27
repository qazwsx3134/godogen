---
name: sprite-actors-3d
description: Godot 4.7 裡「2D 角色圖立在 3D 世界」的共用規格與 godot-kit 模組（pokebonk.com／仙境傳說 RO 式）：鏡頭無側傾時，角色永遠是一張面向鏡頭的 2D 圖，依鏡頭相對方向切 1／4／8 方向（鏡像省圖、遲滯防閃），腳底貼地、不排序、可 MultiMesh 大量繪製。含 billboard 公式、方向列、像素密度、錨點、sheets.json 格式、實例資料通道（網頁版 16 bit）、陰影／描邊／閃白／溶解／遮擋、驗收清單，以及 godot-kit 的 sprite3d shader、sprite3d_sheet.gd、sprite_atlas.py。要做 2.5D／HD-2D 遊戲的角色、敵人、NPC、道具看板，換角色美術，或「角色在 3D 裡看起來飄、切腳、轉向閃爍、像紙片歪掉」時先讀。
---

# 2D 角色立在 3D 世界（sprite actors）

程式在 godot-kit（godogen repo 的 `prototypes/godot-kit/`）：shader 與腳本在 `addons/proto_kit/sprite3d*`，圖集工具是 `tools/sprite_atlas.py`，用 `godot-kit/sync.sh <遊戲>` 帶進遊戲（repo 外的遊戲用絕對路徑）。這份 skill 本身就寫齊了資料格式與規則，在別的 repo 也能照做；要看參考實作時才回 godogen 找。

參考與來源：

- **pokebonk.com**：2D 像素精靈立在 3D 高度場地形上，8 方向。拆解在 godogen 的 `docs/pokebonk-com/codex-bundle-analysis.md` 第 1 節。那是**靜態程式拆解**：方向列的意義由公式推得，沒有拿原作圖逐格目視。
- **仙境傳說（Ragnarok Online）**：3D 地圖、可轉的鏡頭，角色是 8 方向的 2D 圖，依鏡頭相對方向換圖；玩家角色由身體、頭、頭飾等圖層疊成。
- **我們自己的移植設計**（不是原作有的功能）：5 列鏡像、方向遲滯、x-ray 剪影、描邊身分色的打包方式。
- 抽出來源：madara-survivor（腳底帶、翻滾、網點挖空、x-ray 往鏡頭推）與 horde-25d（1 texel 描邊、硬邊影子），2026-10-19 合併成 kit 版，兩個原型都已改用。

## 何時用

- 3D 場景（透視鏡頭、地形、高低差、後處理），角色與敵人用 2D 圖。
- 要同畫面幾百隻角色，而且手機網頁版要跑得動。
- 鏡頭角度會換、或鏡頭會繞 Y 轉，角色仍然要看起來對。

整個場景（舞台、光、霧與景深、道具圖卡、運鏡、預警、3D 特效、放置橫向捲軸）怎麼組，見 skill `hd2d-diorama`；這份只管角色圖。

**不要用在**：純 2D 遊戲（用 `Sprite2D`）、角色要被近距離繞著看的 3D 遊戲（用模型）、鏡頭會側傾（roll）的遊戲。

## 一張圖的契約

### 1. 一個遊戲一個角色像素密度

- 每個遊戲定一個 `meters_per_px`（角色素材的一個像素在世界裡多寬），**所有角色共用**；不要每張圖各自縮放去填滿格子。體型差直接畫在圖上。
- 這是**我們的規則**，不是 pokebonk.com 全場的事實：它的角色 0.074 m/px 約等於地面 13.5 px/m，但樹是 0.085、小物 0.05、地標 0.10～0.13 m/px，水面 8 px/m，天空另用螢幕像素量化。地面、道具、特效要不要跟角色同密度，每個遊戲自己決定並寫下來。
- 特效的密度看「它在世界裡多大」，不是圖集格子多大：一個 64 px 的特效畫成 4 m 寬，就只有 16 px/m。硬邊特效要定世界尺寸，柔光、煙、天空可以當例外。
- AI 生的圖來源尺寸不固定：在 manifest 給每個角色一個「遊戲內高度（px）」，工具用同一個比例縮該角色所有格（`sprite_atlas.py` 的 `height_px`）。

### 2. 錨點在腳底

- 節點原點＝腳底中心。mesh 是 1×1 的 `QuadMesh`，`center_offset = Vector3(0, 0.5, 0)`；節點縮放＝`cell_px × meters_per_px`（`Sprite3DSheet.size_m()`，正方形格）。
- 每格底下留一條透明帶（`foot_px`，存在 sheets.json，shader 的 `foot_gutter` = `foot_px / cell_px`），shader 往下扣掉，腳才會踩在地上。不要在工具和 shader 各加一次。
- 每格四邊至少留 **1 texel 透明邊**，動作伸到最遠時也一樣：描邊畫在角色外圍的透明像素上。描邊半徑改 2 就留 2。
- 腳底線在**所有格、所有方向**都在同一列像素上。`sprite_atlas.py` 有兩種對齊：
  - `trim`：每格裁到有像素的範圍、置中、最低的像素放在腳底線。適合一張張單獨生的姿勢，但**會抹掉跳躍、受擊離地、突進的位移**。
  - `canvas`：同一角色的格共用一張畫布（影片轉出、sprite 工具輸出），整張畫布照同一條腳底線放，位移保留。
- 擊飛、翻滾從身體中間（y = 0.5 格）轉：把旋轉放進實例 basis 繞 Z 的角度，shader 讀回來。

### 3. billboard 的轉法

在 vertex shader 自己算基底（`sprite3d.gdshaderinc` 的 `sprite3d_modelview`），不用 `BaseMaterial3D` 內建的 billboard：

```
right = normalize( 鏡頭 right 的水平分量 )        # (INV_VIEW[0].x, 0, INV_VIEW[0].z)
up    = normalize( mix(世界 Y, 鏡頭 up, lean) )
back  = cross(right, up)
```

| `lean` | 效果 | 用在 |
|---|---|---|
| 0 | 直立、只繞 Y 轉（圓柱 billboard） | 樹、石頭、柵欄、建築看板 |
| 0.35 | 上方往鏡頭的 up 偏一些（pokebonk.com 的角色值） | 平視畫的角色 |
| 1.0 | 和鏡頭的 up 對齊，整張正對鏡頭 | 圖本身已經帶俯視角的角色（madara；圖已經畫了俯視，再讓面片斜躺會被壓扁） |

- **限制**：鏡頭不能側傾。正俯視時鏡頭 right 仍有水平分量、可以畫，但方向選列要用 §4 的退路。
- 8 方向素材只解決「繞 Y 的方位」；俯角換很多時，同一張圖的透視不一定還對，所以要三種俯角截圖驗收。

### 4. 方向依「鏡頭相對角度」選，不依世界角度

角色的面向是世界方向，每幀換算成相對鏡頭的角度再選圖（`Sprite3DSheet.view_angle()`、`direction()`）：

```
f = 鏡頭 forward（-basis.z）的水平分量，正規化   # 正俯視時 f 幾乎為 0，改用鏡頭 up（basis.y）的水平分量
r = f 順時針轉 90°（從上往下看）
d = 角色面向的水平分量，正規化
angle = atan2( dot(d, r), -dot(d, f) )         # 0 ＝ 面向鏡頭，90 ＝ 面向螢幕右
index = posmod( round(angle / (360° / N)), N )  # 用 posmod，負角不會落到 -1
```

f 一定要正規化：沒正規化時，俯角 26° 和 45° 的斜向分界會不一樣。

驗算表（鏡頭朝世界 −Z、無側傾）：d = +Z → 0、+X → 2、−Z → 4、−X → 6。鏡頭繞 Y 轉 90°（朝 −X）後，d = +Z → 6。

8 方向的索引（從上往下看順時針；RO 也是 8 方向）：

```
          4 背對鏡頭
       5          3
   6 面向左   ●   2 面向右
       7          1
          0 面向鏡頭
```

- **4 方向**的索引是 0 前、1 右、2 後、3 左，不能拿 8 方向的索引解讀。
- **1 方向**：只畫一列、面向右；角色面向螢幕左半時翻轉（索引 0 右、1 左）。
- **鏡像省圖**：只畫右半邊，左半邊翻轉。

| 方向數 | 實存列（圖集裡畫的） | 索引 → 實存列（＊＝翻轉） |
|---|---|---|
| 8 | 5：前、右前、右、右後、後 | 0→0、1→1、2→2、3→3、4→4、5→3＊、6→2＊、7→1＊ |
| 4 | 3：前、右、後 | 0→0、1→1、2→2、3→1＊ |
| 1 | 1：右 | 0→0、1→0＊ |

  造型左右不對稱（只有一邊有刀）就把 `mirror` 關掉、畫滿全部方向。
- **翻轉怎麼傳**：格號指向實存列的格，翻轉走 `facing` −1（節點的 uniform，或 `INSTANCE_CUSTOM.z` 的正負號）；shader 不知道方向，材質要 `cull_disabled`。
- **遲滯**：保存上一個索引；新角度和「上一個索引的中心角」的環形差（處理 359°↔0°）超過「半個扇區＋6°」才換，可以一次跨好幾格（快速轉身直接跳過去）。1 方向（左右翻）也套用，正對或背對鏡頭走時才不會左右亂翻。
- **面向的來源要有優先序並保存狀態**：攻擊中朝目標 > 移動方向 > 停下時保留最後的面向。不要每幀在移動與瞄準之間搶。
- **鏡頭固定的遊戲也照這個公式算**：同一套素材搬到別的鏡頭角度、或改成可轉鏡頭，都不用改程式。

### 5. 不透明裁切，不排序

- 片段 `alpha < 0.5` 就 `discard`，其餘只寫 `ALBEDO`，**不讀寫 `ALPHA`**：shader 一碰 `ALPHA` 就會走透明管線，失去「不透明、寫深度、不用排序」。
- 只有殘影、x-ray 剪影、淡出這類少數特效用半透明材質。
- 面片之間仍可能互相穿插（兩個角色站得太近、斜坡）；不透明裁切只保證不用排序，不保證不穿插。

### 6. 光照用手動的，不用場景燈

- 角色 `render_mode unshaded`，顏色＝圖 × 手動亮度（`light` uniform）× 色調，跟著場景調色走（pokebonk.com：`0.85 + 0.15 × 場景亮度`）。不讓 2D 圖吃方向光，平面被打光像紙板。
- 不投射陰影：`GeometryInstance3D.cast_shadow = OFF`（`shadows_disabled` 只管「不收」陰影），改用 §7 的影子。
- 距離霧要確認有套到角色（手動霧就在角色 shader 裡算同一條公式），不然遠處的角色會比地形亮。

### 7. 貼地的橢圓影子

- 一片水平的 1×1 平面放在腳底：橢圓（前後壓扁）、中心最濃 alpha 0.38（pokebonk.com；它離地 0.06、kit 預設 0.03）、半透明、不寫深度。`stepped` 改成兩段硬邊（horde-25d 的像素風）。
- **平地**（預設）：影子和本體共用實例；角色被打飛時影子留在 `ground_y`、隨高度縮小。`ground_y` 是整批共用的 uniform。
- **高度場**：`ground_from_instance` 打開，影子另用一個 MultiMesh、每個實例放在該處的地面高度；離地高度放 `INSTANCE_CUSTOM.x`（開 `use_instance_custom`）讓它縮小。單一 actor 用 `air_height`。

## 同一個 shader 裡還有的

| 效果 | 做法 | 參考值 |
|---|---|---|
| 受擊閃白 | `mix(顏色, flash_color, flash)` | flash 1 → 0 約 0.12 秒（由遊戲淡掉） |
| 受擊壓扁 | 寬 ×(1 + 0.35s)、高 ×(1 − 0.3s) | s ＝ flash × `hit_squash`；碰撞半徑不跟著變 |
| 走路彈跳 | 高 ×(1 + b)、寬 ×(1 − 0.6b)，b = sin(相位) × `bob` | 有真正走路動畫時設 `bob` 0 |
| 描邊 | 取上下左右各 1 個圖集 texel（夾在本格內），自己透明、鄰格有像素就畫描邊色 | 身分色：玩家白、精英金、Boss 紅、同伴青 |
| 死亡溶解 | 依 texel 座標 hash 決定哪些像素先消失，前緣一圈發亮 | 前緣寬 0.12 |
| 狀態色 | 實例 tint（中毒綠、凍結藍） | `COLOR.rgb` |

**描邊只畫角色的外輪廓**（透明與不透明的交界）；眼睛、衣紋這些內部線條要畫在原圖上，shader 生不出來。

**全畫面深度描邊會連角色一起描**：角色寫入深度，深度四鄰邊緣也會落在角色外框上。用全畫面描邊的遊戲要二選一：接受角色也被描（在 spike 裡驗沒有雙重描邊、人群沒有連成黑塊），或另做遮罩把角色排除（額外成本，Godot 沒有現成的每材質排除）。

## 遮擋與可讀性

- **道具擋到玩家**：在鏡頭與玩家之間的道具，用 4×4 Bayer 網點 `discard` 挖掉最多 75% 的像素，仍是不透明（`see_through_enabled`、`focus` 每幀設玩家位置）。
- **玩家被人群擋住**：x-ray 剪影只畫在深度測試**失敗**的地方（`depth_test_inverted`），半透明條紋；原點往鏡頭推 0.35 m（`toward_camera`），自己的身體才不會觸發。horde-25d 舊版沒推，會在主角自己身上畫條紋。
- x-ray **不跟著**本體的彈跳、受擊壓扁與翻滾（給不會翻滾的玩家用）；受擊時要驗自己身上不出剪影。
- x-ray 是半透明物，會吃到 Glow 與最後的調色；在霧、閃白、蒸氣裡要驗還看得出來。

## 資料格式：sheets.json

`tools/sprite_atlas.py` 的輸出，`Sprite3DSheet.from_json(路徑, 角色名)` 讀進來：

```json
{
  "atlas": "atlas.png", "cell_px": 96, "columns": 16, "rows": 10, "foot_px": 4, "meters_per_px": 0.025,
  "characters": {
    "luffy": {
      "directions": 8, "mirror": true,
      "anims": {
        "idle":   { "cell": 0,  "n": 3, "d": [40, 6, 6],      "loop": true },
        "walk":   { "cell": 3,  "n": 6, "d": [4, 4, 4, 4, 4, 4], "loop": true },
        "attack": { "cell": 9,  "n": 5, "d": [3, 3, 6, 4, 8],  "loop": false }
      }
    }
  }
}
```

- 整張圖集是 `columns × rows` 個一樣大的正方形格（`cell_px`）。不同大小的來源格，工具都放進同一格大小、腳底線對齊。
- 一個動作是一塊：`cell` 是第一格（左上），橫向是 `n` 個 frame，縱向是實存列（§4 的表）。第 r 列第 f 格 ＝ `cell + r × columns + f`；`columns` 是整張圖集的寬，不是動作的 `n`。
- `d` 是每格停幾個 **tick**（1/60 秒的遊戲時間），不是毫秒、不是固定 FPS；`d` 的長度就是 `n`，工具會檢查每列格數都等於它。
- `loop: false` 停在最後一格；`sprite3d_actor.gd` 的 `finished()` 告訴你播完了。
- 缺的動作退回 `walk`，再沒有就用第一個動作；這只是防呆，驗收時要確認每個需要的動作都在。
- 計時用遊戲時間累積（hit stop、暫停時會停），不用牆上時鐘。

## Godot 的組法

### 少量的角色（玩家、Boss、同伴、NPC）：actor scene

```
Actor (Node3D, addons/proto_kit/sprite3d_actor.gd)
├── Sprite  MeshInstance3D：QuadMesh center_offset (0, 0.5, 0)，sprite3d.gdshader，cast_shadow OFF
├── Shadow  MeshInstance3D：PlaneMesh 1×1，sprite3d_shadow.gdshader
└── Xray    MeshInstance3D（只有玩家）：同一個 QuadMesh，sprite3d_xray.gdshader，render_priority 1
```

- 遊戲自己存這個 `.tscn`（AGENTS.md：畫面用 scene）。
- **執行時**每個實例進場時複製自己的材質（含影子），同一個 scene 放很多份也能各播各的、站在不同高度。
- **編輯器裡**腳本不會自己改材質或節點，scene 顯示存檔裡的樣子（預覽格號設在材質的 `frame`）；在編輯器裡設 `sheet` 是製作動作：先把材質複製成這個 actor 自己的一份（共用同一個材質或 `.tres` 的其他 actor 不受影響），再寫入圖集、格數、腳底帶與尺寸（`size_from_sheet`），一起存進 scene。
- **時鐘**：預設在 `_process` 自己走（Engine 時間）。模擬有自己時鐘的遊戲（hit stop、選卡暫停只改自己的 delta）設 `auto_advance = false`，在更新裡呼叫 `step(game_delta)`，攻擊格才會和命中對齊。
- 遊戲端：`actor.facing = 速度方向`、`actor.play(&"attack")`、`actor.finished()`（單次動作整段播完才是 true）、`actor.flash = 1.0`（自己淡掉）、`actor.dissolve`、`actor.outline`。

### 大量的敵人：一個 MultiMesh 一批

- 每張圖集一個 `MultiMeshInstance3D`；平地時影子可以和本體共用實例（madara：一個 ArrayMesh 兩個 surface，兩個 draw call 畫整支軍隊），高度場時影子另一批（§7）。
- 位置、狀態、碰撞放在管理器的陣列裡，不要每隻一個 node 或 `CharacterBody3D`。
- 擊飛、翻滾會讓面片超出原本的範圍，MultiMesh 要設夠大的 `custom_aabb`，不然在畫面邊緣會整批被裁掉。

**實例資料通道**（一個實例只有這兩個 vec4）：

| 通道 | x | y | z | w |
|---|---|---|---|---|
| `INSTANCE_CUSTOM`（`use_custom_data`，材質開 `use_instance_custom`） | 絕對格號（`cell()` 的 x） | 閃白 0～1 | 翻轉 ±1 ×（1＋溶解 0～1） | 走路相位 |
| `COLOR`（`use_colors`，材質開 `use_instance_color`） | 色調 r | 色調 g | 色調 b | 描邊身分：`1 − role/8`（白色＝無描邊） |

- 用 `Sprite3DSheet.instance_custom()`、`instance_color()` 打包，不要自己算。
- **網頁版（Compatibility）每個分量只有 16 bit**（[Godot 4.7 MultiMesh](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html#class-multimesh-method-set-instance-custom-data)）：格號在 2048 以內才精確（`sprite_atlas.py` 會擋超過的），身分用 round 解碼、只有 0～7。不要把分量當任意精度的整數或 bitfield。
- `use_colors`、`use_custom_data` 要在設 `instance_count` **之前**打開。直接寫 `buffer` 的話，兩個都開時每個實例是 20 個 float（transform 12＋color 4＋custom 4），本體與影子兩批要一致。
- 影子 shader 不讀 `COLOR`，共用實例時身分值不會變成影子透明度。

## 素材管線

1. 角色原畫與動作：照 skill `character-sprite-forge`（Codex 生圖、Claude 挑、影片轉 sprite），或 Scenario 系列 skill（`scenario-identity-library` 讓同一角色各方向一致、`scenario-sprite-animation` 做動作格，會花使用者的 Scenario 點數）。生圖前照 AGENTS.md 先描述批次、等使用者選。
2. 每個方向**同一張畫布、同一條腳底線、同一個光源方向**（一律左上），不然轉向時會跳。
3. 寫 manifest（格式在 `tools/sprite_atlas.py` 檔頭），跑 `uv run --with pillow tools/sprite_atlas.py <manifest> --out <資料夾>`。像素模式（`"pixel"`）用面積平均縮小、**同一角色共用一個色盤**（逐格各自壓色盤，轉向時顏色會跳）、alpha 二值化。
4. 工具會擋：格子放不下（1 texel 邊＋腳底帶）、某列格數和 `d` 不符、條狀圖的尺寸除不盡格子、圖集超過 4096 px 或 2048 格。不會偷偷縮小或切掉。
5. 人工 QC：鏡像後武器有沒有換手、方向之間腳底線有沒有跳。
6. 記憶體：一個角色 96 px 格、5 列 × 17 格約 1632×480、RGBA8 約 3 MiB；同時常駐的角色與敵人加起來才是成本，手機要看總量，不只看單張小於 4096。伸很長的招式（伸縮拳）做成另外的效果物件，不要把整個角色的格子撐大。

## 網頁版（Compatibility）的陷阱

- **圖集用無損匯入**（`compress/mode = Lossless`）：madara 原本被壓成桌面專用的 VRAM 格式，手機 WebGL 讀不了，角色全不見。
- 角色 sampler 用 `filter_nearest`、`repeat_disable`、不生 mipmap；地面貼圖反而要 mipmap。
- 角色在畫面上的像素比素材少時（遠景、低解析），最近點取樣會跳、吃掉細節；比較像素密度時固定世界身高、鏡頭與渲染解析度，在手機實際大小上看。
- 不要對世界座標做像素對齊（四捨五入），移動會抖。2D 像素特效的格點吸附與 22.5° 旋轉（skill `pixel-vfx`）是 2D 的做法，不要套到 3D 角色上。
- 實例資料 16 bit（見上方通道表）。

## 驗收清單

- [ ] `sprite3d_gallery.gd`（xvfb-run，`--rendering-method gl_compatibility`）：三種俯角的一圈 8 方向依序出現、鏡像列的數字是反的、MultiMesh 的描邊身分色／閃白／溶解／翻滾正確。
- [ ] 遊戲裡放一個假人原地轉 360°：邊界不閃、快速轉身直接跳到對的方向、鏡像列武器沒換手。
- [ ] 斜坡與台階上：腳沒有被地形切掉、影子貼著地面。
- [ ] 玩家站在人群後、樹後：剪影或網點挖空出現；沒被擋、受擊、翻滾時自己身上**不出**剪影。
- [ ] 同一角色所有動作的大小一致；不同角色的像素一樣大。
- [ ] 單一 actor 與 MultiMesh 同一格畫出來一樣（同大小、同腳底、同影子）。
- [ ] 畫面邊緣被打飛的敵人沒有整批消失（`custom_aabb`）。
- [ ] 網頁版：角色有出現（沒被 VRAM 壓縮弄不見）、目標數量下的 fps 在使用者手機上量。

## godot-kit 的模組

| 規格 | 模組 |
|---|---|
| billboard、腳底、翻滾、描邊、閃白、溶解、手動光照、網點挖空 | `addons/proto_kit/sprite3d.gdshader`（共用部分在 `sprite3d.gdshaderinc`） |
| 主角剪影、殘影、腳下影子 | `sprite3d_xray`／`sprite3d_ghost`／`sprite3d_shadow.gdshader` |
| 方向（鏡頭相對、正俯視退路、遲滯、鏡像）、動作 tick、實例資料打包、讀 sheets.json | `sprite3d_sheet.gd` |
| 少量角色的 actor | `sprite3d_actor.gd` |
| 圖集與動作資料 | `tools/sprite_atlas.py`（`--self-test` 可跑） |
| 不開遊戲看效果 | `sprite3d_gallery.gd` |

shader 預設值是 madara-survivor 的（`frames` 4×6、`lean` 1、`foot_gutter` 0.047）；遊戲自己的外觀寫在遊戲的材質裡（例：horde-25d 的 `tools/build_scenes.gd` 的 `LOOK`／`ACTOR`），不改 kit。改 kit 照 godot-kit README「維護」：只改 `godot-kit/`、跑 kit 測試、`sync.sh`、再跑每個使用中原型的測試。

**紙娃娃（RO 式圖層）**：身體＋頭＋頭飾分開畫、每格帶錨點疊起來，可以換裝。目前沒有遊戲需要，先不做；要做時，每個圖層一張同排法的圖集，錨點存在動作資料的每一格裡。
