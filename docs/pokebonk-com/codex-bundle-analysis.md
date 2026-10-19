# pokebonk.com：公開 bundle 與 2.5D 實作拆解

## 結論與研究界線

這個版本用 3D 高度場承載 2D 像素角色；角色是 instanced quad，環境多為圓柱 billboard，但沙漠與遺跡也載入 GLB。**「完全沒有模型」這個前提不成立；不建模仍可採用其角色、地形及特效架構，以像素面片替代 GLB 道具。**

本文件研究 Charcher 的 **pokebonk.com**，不沿用另一款 pokebonk.solais.cloud 的數據。快照版本 **0.7.3 / mvekcp7c**，證據 `news-DDcWCXrq-mvekcp7c.js:2592`。只有同站公開 JS/CSS、data JSON、env 素材下載；未啟動 bundle、未登入、未呼叫 API、未開 WebSocket，亦未下載 PMD、portrait、GLB、字型檔或音樂。

以下是**靜態程式研究**；數值為本次 bundle／JSON 快照，不代表伺服器實際發給某帳號的進度、設定或資源。本遊戲未取得線上平衡覆寫；舊遊戲的 `/api/config` 與 211 balance 鍵不適用於本研究。Godot 對應欄是移植設計建議，未製作或執行 Godot 原型，不宣稱兩個渲染器已驗收。

### 來源、定位與重現

所有來源原檔在：
`/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/`

本文的 `檔名:行號` 均指 **raw/pretty** 的格式化快照，不是單行壓縮 JS；主檔與共用檔全文路徑如下。JSON 引用以 `data/` 或 `assets/env/` 區別同名圖集。

| 簡稱 | 完整來源路徑 |
| --- | --- |
| 主程式 | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/pretty/assets/main-DSroRSEE-mvekcp7c.js` |
| 共用資料 | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/pretty/assets/news-DDcWCXrq-mvekcp7c.js` |
| 載入器 | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/pretty/assets/main-PPKBYCbX-mvekcp7c.js` |
| UI CSS | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/pretty/assets/main-Cbxzqrvd-mvekcp7c.css` |
| 原檔雜湊／下載清單 | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/fetch-manifest.json` |
| 離線表格產生工具 | `/Users/peter/repo/godot/godogen/.claude/tasks/pokebonk-com/raw/build-tables.py` |

用本機已安裝 Prettier 3 格式化；AST 只解析 source，不執行遊戲模組。新下載的 common atlas 用 JSON 縮排格式化。工具與第三方內容都留在 gitignored raw。下載 URL 是不帶版本 query 的公開入口；程式在實際遊戲會加資源內容版本 query，因此這是來源快照，不是完整部署封存。

載入器的動態 import 使用反引號，包含主程式與各語系；主程式本體只有 i18n、news、three 三個靜態 import，**未找到另拆的遊戲／地圖 JS chunk**。地圖依 `env/{pack}/atlas.json` 與四張 PNG 非同步載入。preload 的主 CSS、news CSS、700/800/900 字重 CSS 已保存；研究只下載 en、zht 語系，未下載其餘語系及字型二進位。證據：`main-PPKBYCbX-mvekcp7c.js:1`、`main-DSroRSEE-mvekcp7c.js:1`、`main-DSroRSEE-mvekcp7c.js:8492`。

### 資料表索引

- [公開靜態快照清單](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/source-inventory.md)：下載路徑、大小與 SHA-256。
- [精靈動作與切圖](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/sprite-animations.md)：本季 151 種、906 個動作記錄。
- [招式 runtime](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/moves-runtime.md)：919 筆原始招式→710 筆可轉換定義；25 個原型。
- [角色與特性](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/roster-and-abilities.md)：79 個角色入口、310 個不同 kit key。
- [敵人與生成](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/enemies-and-spawning.md)：123 種一般敵池候選及曲線、事件、難度。
- [升級與道具](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/upgrades-and-items.md)：102 個 runtime 道具、21 個維他命、19 個 Lab 項目。
- [環境圖集](/Users/peter/repo/godot/godogen/docs/pokebonk-com/data/environment-atlases.md)：9 個 pack、156 個裁切矩形與六個 biome 定義。

## 1. 精靈：一張圖集、一批面片、每實例帶動畫資料

```text
sprites.json + pmd/{id}.png（本次未下載 PNG）
                    ↓
每物種一個 PlaneGeometry + ShaderMaterial + InstancedMesh
                    ↓
iPos / iSize / iUV / iFx / iTint
       ↓                  ↓
動畫選格、方向列       閃白、溶解、描邊、狀態色
                    ↓
深度測試與 alpha discard → 加上腳底橢圓影
```

### 切圖、時長與方向

`sprite[id]` 包含整張圖 `w/h` 與 `anims`。每個動作有 `y/fw/fh/n/rows/d`：動作區在 y 開始；橫向是 frame，縱向是方向。動作名稱在本季包含 walk、idle、attack、hurt、faint、charge。以妙蛙種子為例，PNG metadata 為 704×2176；walk 是 40×40、6 格、8 方向、每格 4 ticks，0.4 秒一循環；idle 的 d=[40,6,6]，不是固定 FPS。證據 `data/sprites.json:2`。

播放器先計算 `sum(d)`，普通動畫用 `floor(t×60)%sum(d)`，逐格扣 d 找 frame；單次 normalized 動畫用 `min(total−1,floor(progress×total))`。UV：u=frame×fw/w；v 依動作 y 與 direction×fh 反轉。方向列用鏡頭地面投影 right/forward，`atan2(dot(dir,right),−dot(dir,forward))` 每 45° 四捨五入；row0 朝鏡頭、row2 螢幕右、row4 背向、row6 左，斜向在中間。這個方向意義由公式推導，未拿 PNG 逐格目視確認。證據 `main-DSroRSEE-mvekcp7c.js:5217`、`:5377`。

`anim(name)` 缺動作退回 walk；無動畫 fallback 為一格靜圖，特定方向翻 u；地鼠／三地鼠走路特例改播 idle、每格 8 ticks。初始化會只量 walk 第一格 alpha>128 的包圍盒，用腳底、頂部及寬度修正角色高度／碰撞近似，而非各格獨立重新定位。證據 `main-DSroRSEE-mvekcp7c.js:5168`、`:5189`。

**Godot 對應**：每物種做可編輯的 actor scene（根 Node3D、MeshInstance3D 或 MultiMeshInstance3D、影子節點），metadata 轉 Resource。CPU 用 tick 累積器挑 frame，把 frame rectangle 傳入 shader；不要把 `d` 當毫秒。小量可用 Sprite3D region／自製動畫腳本；大量敵人以 MultiMesh 分批，UV rectangle 等額外資料超過 INSTANCE_CUSTOM 一個 vec4 時，使用資料貼圖或拆批，不能假設可直接增加任意 Godot instance attribute。

### billboard、錨點、像素與深度

| 項目 | 遊戲實作／bundle 參數 | Godot 4.7 對應（兩渲染器共用） |
| --- | --- | --- |
| 幾何／錨點 | 單位平面 translate(0,.5,0)，以腳為基準；根據 footprint 再修正 y；初始 cap64、滿了×2。`main-DSroRSEE-mvekcp7c.js:5053`、`:5152` | QuadMesh 或 ArrayMesh，vertex 把中心改腳底；角色 script 持有世界座標，不以每個動畫格中心置中 |
| billboard 類型 | right=攝影機 right；up=normalize(mix(worldUp,cameraUp,.35))（公式 main:4988，.35 在 main:5087）。**混合直立朝向**，不是純圓柱或純球面。`main-DSroRSEE-mvekcp7c.js:4980` | spatial vertex shader 算相同 basis；built-in billboard 只適合近似。保留腳底，縮放在 shader 中做 |
| 縮放 | 動畫每來源像素 .074 世界單位；fallback .04，再乘角色 scale。32px≈2.368 單位。`main-DSroRSEE-mvekcp7c.js:4899`、`:5240` | 保持同一 pixels_per_unit／pixel_size 標準；立體地形與 sprite 比例一起定，不用各圖自動填滿同一框 |
| 過濾 | PMD min/mag nearest、不生 mipmap；環境地面另有 mipmap，不能一概禁掉。`main-DSroRSEE-mvekcp7c.js:5105`、`:8510` | actor shader sampler 設 filter_nearest；進口圖片停用有損壓縮，角色不依賴 mipmap。地面保留適當 minification |
| 像素對齊 | actor shader 未找到將世界座標或頂點吸附整數像素的邏輯；像素感主要來自 nearest、圖本身、場景 shader、可選低解析。`main-DSroRSEE-mvekcp7c.js:4980` | 不預設給世界位置四捨五入，否則移動抖動；需要時只在最終低解析畫面處理 |
| 透明／排序 | alpha<.5 discard，存活像素輸出 alpha1；主材質不是透明混合，仍用深度遮擋；renderOrder1，關閉 batch frustumCulled。view z+.25 減少地形切腳。`main-DSroRSEE-mvekcp7c.js:4980`、`:5053` | opaque cutout／alpha scissor shader，保留 depth；避免每個角色全用 alpha blend。z偏移須另行評估比例，不能當普遍關閉深度 |
| squash | fx.w 使寬×(1+.35sq)、高×(1−.3sq)。`main-DSroRSEE-mvekcp7c.js:4980` | shader 每實例 squash，碰撞半徑不用跟著每幀變形 |

### 陰影、描邊與狀態

角色不是靠投影式陰影貼地：`Fo` 用水平 instanced plane，橢圓 z 比例 .6、離地 .06、smooth radial alpha 最大 .38、不寫深度，cap4096。角色根據 terrain.surface 放影子，避免沉水。證據 `main-DSroRSEE-mvekcp7c.js:5273`、`:12255`。

輪廓在角色 fragment 取四鄰近 **一個整張圖 texel**，限制在 frame rectangle 防串格；依 fx.z 指定玩家白、Elite金、Alpha紅、捕捉青、Dominant紫、Summoner綠等。部分輪廓有 .75+.25sin(time×8) 脈動、1.6 增益。hit flash 用 mix 到白；status 用 per-instance tint。死亡以 atlas texel 座標 hash 做 dissolve，邊緣 .12 範圍金色發亮。證據 `main-DSroRSEE-mvekcp7c.js:5006`。

**Godot 對應**：影子用共用橢圓透明材質 MultiMesh，水平貼在 CPU 高度查詢結果；不用開每個敵人的 shadow caster。輪廓／閃白／dissolve 全寫在同一 spatial shader，手動色彩與距離霧保持 cutout；不用每次受擊複製 material。玩家輪廓與全畫面深度邊緣是兩套效果。

## 2. 環境與高台

### 有多少地圖，哪些是面片

共用資料定義 forest/desert/graveyard/volcano/glacier/coast 六個 biome；季節白名單只有 **forest、desert**。兩者另有第4區聖域：森林 sanctum、沙漠 ruins。加 common 共九個環境 pack，不代表九張已開放大地圖。forest size360、desert340；其餘未填時預設280。證據 `news-DDcWCXrq-mvekcp7c.js:289`、`:746`，`main-DSroRSEE-mvekcp7c.js:9310`。

forest atlas 2048×128、22矩形；其他圖集的尺寸、UV與矩形詳見資料表。`Ss` 讀 atlas.json / atlas.png / ground.png / cliff.png / path.png；圖集使用 nearest、不生 mipmap；地面圖片 repeat、anisotropy4、minification 用 mipmap。common atlas 給互動物件。證據 `main-DSroRSEE-mvekcp7c.js:8492`、`:8625`。

`xs` 是圓柱 billboard：right 為攝影機 right 在 XZ 的投影，上向永遠世界 Y；PlaneGeometry 1×1 有 6 段高度以做風吹。底部錨定，風位移按來源像素大小量化，避免風把像素拉得滑動。擋在鏡頭與玩家之間的 props 用 4×4 screen-door discard，最多挖掉 .75，不必半透明排序。樹多用 .085 world/px，小物 .05，地標 .10–.13。證據 `main-DSroRSEE-mvekcp7c.js:8283`、`:8391`。

**例外**：desert_hoodoo、desert_boulder、desert_skull 等，以及 ruins 的柱、拱門、雕像等被 `kind.model` 取代，從面片清單排除，另經 `models/{name}.glb` loader 合併幾何、toon材質、實例化與背面輪廓。GLB不在下載白名單，本次沒有下載、未找到其實際面數／材質貼圖規格。證據 `main-DSroRSEE-mvekcp7c.js:8342`、`:8713`、`:8776`。

**Godot 對應**：樹、花、石採 QuadMesh 圓柱 shader＋MultiMesh，每包一張圖集；高度分段只在需要風時使用。保留 alpha cutout 與遮擋抖動。對 GLB 位置直接設計對應像素面片，碰撞保留簡單圓柱／圓半徑；這是「不建模」方案的替代設計，不能聲稱原作這些也是圖片。

### 地面與懸崖：連續高度場，並非逐塊方塊堆疊

```text
seed → 兩組 noise → 多層 terrace + massif + 路徑緩坡 + pond
                         ↓
            Float32 高度陣列／pathMask
                 ├→ 網格頂點與法線
                 ├→ CPU height/normal/collision/spawn 查詢
                 └→ shader 水深／cliff高度／植栽陰影 mask
```

網格 cell 目標 **1.12**，res=round(world/1.12)；森林 res321、沙漠304（均為推算），cell=world/res。水平平面每格分三角形，以高度陣列改 y、重算法線。地形生成先取 FBM（.011頻率4octaves＋.03頻率2octaves擾動），分成平台層；層高 **4.6**，森林 levels5、massifs2。massif 半徑44–50，有螺旋路徑；中央半徑9–18保持可出生平台，周界增加18+noise×8高度，最後3×3權重平滑、connectPlateaus 造可達坡道。不是垂直格牆完全無坡度。證據 `main-DSroRSEE-mvekcp7c.js:9267`、`:9535`、`:10070`。

地形材質另有重要分支：**目前 forest/desert 啟用 TOON_GROUND**，以 texture 中央高 LOD 色取得底色，再用程序 lawn／sand 像素紋理；懸崖是程序石塊、層理、苔蘚、倒角與暗縫，不是只把 cliff.png 直接鋪滿。其他包（含未在 Xs 中的聖域）才走圖片 ground＋XZ兩方向的 cliff triplanar。小路 tPath 依 pathMask threshold .56＋dither切換，岩壁依 slope≈.32切換；uPx=13.5 world texels/unit，材質式 toonLight 用分段明暗。證據 `main-DSroRSEE-mvekcp7c.js:9137`、`:10088`、`:10128`、`:10145`。

樹影會先畫入 world×2 解析度的單通道 mask，再由地形 shader 取樣，切在世界像素格、dither 邊緣、與坡面貼合且重疊不越積越黑。`xs.shadows` 雖有建立，但主 terrain 掛載 env.mesh 並以 shadeTex 套入地面，不能把那個未掛載物件誤認為主要樹影。證據 `main-DSroRSEE-mvekcp7c.js:9349`、`:9982`、`:10179`。

**Godot 對應**：CPU 建立高度網格 ArrayMesh，同一份高度資料提供移動／落地／放置查詢；製作時把主要畫面與地形承載節點存成 .tscn。地形 shader 用 world XZ＋法線判斷草地、路、岩面，兩渲染器都能採同一基本紋理／程序分支。低階手機可把草砂程序與 cliff 紋理離線烘成小圖集、地形分區 MultiMesh／MeshInstance，降低 fragment 噪聲與整圖重建成本。

### 散佈與碰撞

種子 RNG 固定擺放；areaMul=(world/280)^2。目標 trees=round(380×propDensity×areaMul)、big=round(260×areaMul)、small=round(2200×areaMul)；只是嘗試目標，不保證每次都放滿。樹避中央18、大物14、小物6；要求平坦法線 y>.94、不在水邊，pathMask>.3拒絕；大物還查四周法線>.9、避 reserve landmarks。scale隨機 .85–1.2、50%鏡像。樹和大石有簡化圓碰撞，小花草不一定有。證據 `main-DSroRSEE-mvekcp7c.js:9366`、`:9970`。

**Godot 對應**：相同 seed 和拒絕採樣，先放互動點與路徑保留區，再批次放植栽。碰撞用CPU spatial grid＋半徑，毋須每根草建立 StaticBody3D；可編輯 prop scene 留 representative instance 給編輯器預覽。

### 水、熔岩、瀑布

一般關卡水面使用水平 quad／各 pond 圓盤；高度圖轉半精度紋理取得水深，淺深色平滑混合、8px/unit 量化噪聲產生波光與岸邊白沫。水透明 .75–.95，depthWrite=true、renderOrder2；無反射相機或物理流體。熔岩用同一 shader 分支輸出 opaque crust＋亮點。森林 relief 存在時另規劃局部淺池。證據 `main-DSroRSEE-mvekcp7c.js:10190`。

**瀑布找到於標題／選單展示場景 Rc，不是一般 oc 隨機地圖生成器**：兩層6×40分段平面，向外彎曲 sqrt(height progress)，底部寬度增22%；10px/metre圖樣、60–90px/s條紋，背層慢45%，白沫與齒狀邊；透明、寫深度，order3/4。主選單建立 Rc，證據 `main-DSroRSEE-mvekcp7c.js:10732`、`:11027`、`:77188`。**一般遊玩地圖產生瀑布的呼叫未找到**，不能拿標題特效當每張地圖特色。

**Godot 對應**：水深直接用自有 heightmap，不依賴渲染器特有深度重建；水平 ArrayMesh 與兩層瀑布面片加自製 shader 可共用。半精度取樣在 Web 有限制時，改用正規化 RGBA8 高度編碼。透明水寫深度的遮擋次序須依自家 scene 驗收；不需啟用 SSR／折射。

## 3. 相機、光照、霧與最後畫面

| 系統 | 遊戲的數值／路徑 | Godot 對應 |
| --- | --- | --- |
| 相機 | Perspective FOV70、near.1/far600；yaw0、pitch.45rad（約25.8°）、距離9；設定距離4.5–26。`main-DSroRSEE-mvekcp7c.js:4594`、`:52634`、`:77643` | Camera3D perspective；不是等角正交相機。相機 rig scene 留距離、俯角 export |
| 追蹤／防穿 | XZ指數平滑係數18、Y10；視線4點查地形+.8抬升；抬升快22、回落5。速度>8使FOV額外最多+10。`main-DSroRSEE-mvekcp7c.js:54751` | Camera rig script，用同一 height sampler；固定 tick 角色＋render插值，保持相機／方向基準一致 |
| 光 | Hemisphere 初始1.6、Directional初始2.2，太陽(60,120,40)；setSky之後 sun=1.6×biome.light，hemi=1×light；角色手動 light=.85+.15×light。`main-DSroRSEE-mvekcp7c.js:4594`、`:4721` | 地形用自製 toon diffuse，角色用 unshaded手動light。原生 Mobile可加少量真燈，但不讓 Compatibility效果依賴它 |
| 霧 | smoothstep(distance)，共享uniform；setSky把資料 fogNear×1.5、fogFar×1.35；森林首區45/170→67.5/229.5。`main-DSroRSEE-mvekcp7c.js:4721` | shader 手動距離霧可跨兩渲染器；不依賴體積霧 |
| 天空 | 內翻球半徑500；gl_FragCoord以4px格量化、4×4 Bayer、7層色階，FBM雲、太陽、星、日蝕。`main-DSroRSEE-mvekcp7c.js:4606` | Sky shader 或簡化大球，將 screen UV轉固定格；Mobile低階減少FBM octave |
| renderer | AA=false、toneMapping=0；sRGB輸出；透過composer做效果。`main-DSroRSEE-mvekcp7c.js:4582` | 保留像素邊緣；顏色空間另行比對，不能把 Three 顏色常數當已匹配 Godot色調 |

實際 composer：RenderPass → **PixelOutline** → tint/ToonGrade/bloom/vignette 複合 EffectPass。PixelOutline取深度四鄰，depth差 threshold=1+.12×距離、距離<300、strength=.85；grade amount1、冷暗暖亮曲線與22% smoothstep對比；bloom intensity .8／threshold .92／smoothing .2／mipmap radius .7；vignette最後 offset.4、darkness.4。證據 `main-DSroRSEE-mvekcp7c.js:4494`、`:4672`。

**勿誤認啟用效果**：ACES_FILMIC tone effect 和 chromatic aberration 物件有建，但未加入上述 pass；`kick` 的 chromaAmt會衰減，未找到它更新有效 chroma uniform 的路徑。不能只看到建構子就寫「遊戲開了ACES及色差」。`aa/shadows/pixelRatio`亦在預設品質物件出現，不等於 resize用到了它們。證據 `main-DSroRSEE-mvekcp7c.js:4672`、`:4759`、`:4794`。

### 是否低解析渲染再放大

**可選，預設不強制**。settings.pixel=0，pixelScale<=1時getter回1；pixelScale>1用 renderer DPR=1/pixelScale並把canvas image-rendering設pixelated。一般DPR：有bloom desktop≤1.5/mobile≤1.25；沒bloom≤1；saver≤1；再依像素預算cap（有bloom desktop3.7M/mobile1.6M，無bloom2.2M）取較小值，下限.5。證據 `main-DSroRSEE-mvekcp7c.js:4718`、`:4763`、`:57534`。

**Godot移植**：以低解析 SubViewport＋nearest顯示，HUD留高解析 CanvasLayer；這條路兩渲染器都可採。共通底線使用角色輪廓、地形toon、手動霧、tint/vignette；bloom要以自製低解析亮部模糊疊加做共通方案，不把 WorldEnvironment glow 當成所有目標必有。全畫面深度描邊需自行重建正確的投影深度，Godot渲染器深度慣例不同；未驗證前先保留角色局部輪廓，不宣稱直接貼 Three 的 GLSL即可。

## 4. 招式與共用 VFX 引擎

### 幾何、貼圖與生命週期

特效不是919張外部特效圖：`es()`用Canvas2D離線式畫圖邏輯在瀏覽器產生 **512×1088、8×17、每格64×64** atlas，包含柔光、星、煙、岩、像素火水等形狀；各招式再指定draw/trail/boom/cast等hook。證據 `main-DSroRSEE-mvekcp7c.js:5891`、`:22599`。atlas的遊戲執行結果本次未產生，因不執行 bundle。

| 批次 | 幾何／混合／深度 | 容量與時間 | 來源 |
| --- | --- | --- | --- |
| add／norm 粒子 | camera-facing quad，前者additive後者normal alpha；不寫深度，保留depthTest；atlas index著色，size/color/life插值，速度／gravity／drag更新 | 12000／5000；每次spawn給life，例如burst預設.5秒×.6–1.2，尺寸漸零 | `main-DSroRSEE-mvekcp7c.js:7345`、`:8006` |
| ground／groundN | 同上，但平躺XZ，用於波、煙、地面痕跡 | 1500／800；由招式dur決定 | `main-DSroRSEE-mvekcp7c.js:8006` |
| beams | 兩端點展成camera-facing strip；橫向3段明暗、尖端淡出；normal alpha、雙面、不寫深度，非3D cylinder | 512；life<=.06採兩次update短命保護；鏈電約.2秒 | `main-DSroRSEE-mvekcp7c.js:7531` |
| rings | 水平quad，fragment畫像素環、波紋、符文等；normal alpha、不寫深度 | 600；ring預設.45秒，半徑.15R→1.05R；telegraph持續到impact | `main-DSroRSEE-mvekcp7c.js:7686`、`:8041` |
| 靜態billboard pool | 每frame填instance，給軌道球、拾取物等；normal／add兩批 | orbital各512；自身不另開每物件node | `main-DSroRSEE-mvekcp7c.js:8150`、`:52754` |
| 數字 | 字元atlas，每字一quad，camera-facing；不測深度、不寫深度，order50 | 3000字元，約400個text記錄；life.85、vy3.2，前12%放大至1.7、後30%淡出 | `main-DSroRSEE-mvekcp7c.js:7862` |

**Godot共通方案**：製作一張合法自有VFX atlas，在固定容量 CPU pool 更新，MultiMeshInstance3D分blend／depth／朝向批次；短命beam用ArrayMesh quad拼端點（不是假設有Godot內建Line3D）；ring可用QuadMesh fragment距離場。單一INSTANCE_CUSTOM不足的資料用資料貼圖、CPU變換與分批補足。保留手動alpha／明暗，避免依賴GPU compute particle、HDR glow或透明排序修復才能看見形狀。數字用字圖MultiMesh或少量投影至Canvas的Label pool，不給數千個Label3D。

### 按招式型態分組

所有dmg/cd等原型初值見資料表。通用派發 `zp` 在冷卻到時自動施放；特定key的hook可替換通用畫法，不能把下表描述當每個招式完全相同的圖。

| 形態 | 機制與視覺／常見生命週期 | Godot對應 | 來源 |
| --- | --- | --- | --- |
| bolt/barrage/homing/drain/orb/boomerang | projectile池；barrage分批發、homing追蹤、orb命中爆炸、boomerang往返自旋；sprite quad＋trail。原型dur .6–1.6；drain吸血另處理 | CPU彈體結構陣列＋spatial grid命中，與MultiMesh視覺分離 | `main-DSroRSEE-mvekcp7c.js:22637`、`:37990` |
| lob/trap | 拋物線或撒雷，lob life3秒；trap原型14秒，接觸炸；警示環／地面碎片 | 同彈體池，拋物線查height，trap靜止碰撞，不用每顆RigidBody | `main-DSroRSEE-mvekcp7c.js:38049`、`:38323` |
| beam/cone | active期間tick命中；beam strip與亮芯、cone粒子噴流；原型dur .45/1秒。高power beam≥110先蓄力.5秒再發1.3倍dur | shader strip＋錐區域向量測試，傷害tick與畫面life分開 | `main-DSroRSEE-mvekcp7c.js:38087` |
| nova/spin/strike | 範圍環／slash、粒子；nova ring .45與.3秒、粒子.35；strike在前方近敵位置取半徑.75×area，不是逐像素武器碰撞 | 水平環＋弧線quad；CPU球／扇區查詢 | `main-DSroRSEE-mvekcp7c.js:38139` |
| dash | 角色殘像衝線；以線段投影／側距判定敵人；招式dash不是每次都把玩家移動同等距離 | ghost sprite pool＋segment test，與玩家手動閃避分開 | `main-DSroRSEE-mvekcp7c.js:38212`、`:53039` |
| chain | 最近敵串接、不重複、每跳damage×.9；電用閃電折線、其他beam；.2–.38秒＋burst | 線段strip陣列，選敵Set與每跳延遲／life獨立 | `main-DSroRSEE-mvekcp7c.js:38241` |
| smite/meteor | 落點telegraph；smite延遲.22，meteor用dur（預設.7）；柱／斜線beam、碎片、塵與閃光；meteor burst .7、flash .2 | 預告圈、CPU timer、落點mesh pool，傷害在落地時結算 | `main-DSroRSEE-mvekcp7c.js:38277` |
| orbit/aura/trail/vortex/wave | 軌道池、地面持續區、移動渦流與波；orbit每敵.5秒防重打，原型active4秒；trail需移速>1.5才留下 | 把持續區與實際VFX分開；同一池重用，無需每tick建node | `main-DSroRSEE-mvekcp7c.js:37775`、`:38361` |
| weather/buff/random等 | 天候／自身增益／抽其他招式，並非每種都是傷害彈體；25原型完整名稱見表 | Resource定義施放行為與render recipe，避免靠字串到處switch | `main-DSroRSEE-mvekcp7c.js:36598`、`:37398` |

### 命中、死亡、拾取、升級與 Ultimate

- **命中**：combat設flash=1、squash=.6，記slot傷害；角色shader有白閃，但敵人render會將一般命中的強度混入偏紅tint，不能全稱「每次純白」。傷害數字共用字圖，減閃爍、減震與關數字可設定。`main-DSroRSEE-mvekcp7c.js:35840`、`:12230`。
- **死亡**：一般敵 dying=.35秒，faint／normalized dissolve＋星burst；普通8顆、特殊40顆，死亡flash .12秒。Boss／捕捉候選會攔截死亡流程。`main-DSroRSEE-mvekcp7c.js:36279`、`:36326`。
- **拾取**：XP／coin／heal／magnet／bomb／repel／candy等用billboard池；落地彈射初速4–7，進pickupRange後吸向玩家。超過500XP或200coin起先嘗試合併、>260每1.2秒consolidate，限制trail／burst每frame預算；有simple pickup與calmCandies模式。`main-DSroRSEE-mvekcp7c.js:23125`。
- **升級**：先嘗試進化，否則modal暫停、ring半徑5/.5秒、30星burst，再3或4張卡。`main-DSroRSEE-mvekcp7c.js:53931`。
- **Ultimate**：每角色家族／主屬性選def，依進化form／growth tier變化；共用charge與演出框架。fire設無敵active+.6、pose.6，預設hitstop.32＋UI cut-in、色調變化、鏡頭距離+2.6×ultFx、音樂duck；24粒子.35秒內聚、.5秒環、shake.25，.03秒後cast。`main-DSroRSEE-mvekcp7c.js:52475`。
- **鏡頭效果**：shake累積trauma，平方後最大位移係數.3、每秒衰減2；相位為 realTime×26（rad/s）再乘 1.1／1.7／1.3，三軸約 4.6／7.0／5.4 Hz（verifier 更正：不是 26Hz，main:54808）；hitstop是run模擬時間控制而非改全站時鐘。Boss死亡hitstop.5、shake.8。`main-DSroRSEE-mvekcp7c.js:52953`、`:53565`、`:54801`。

**Godot對應**：受擊／死亡／掉落以signal送給視覺池，保留role與slot來源；UI cut-in與卡牌做獨立可編輯Control scene。hitstop用遊戲自己的simulation scale，讓HUD與暫停選單繼續；trauma只加到camera rig子節點。閃光、震動、傷害數字各有獨立設定，低品質減密度不取消傷害判定。

## 5. 機制：資料全集如何變成倖存者

### 角色、屬性與特性

Pokemon1025、moves919、abilities314、items125為資料庫；本季 `maxDex=151` 先過濾 Pokemon，手工 W roster 79個角色入口有角色定位、custom passive、4招kit、解鎖challenge及進化例外。starter為1/4/7。18屬性沿用type chart，但**runtime不是原作倍率**：單屬性克制2→1.35，免疫0→.5，抗性≤.5→.8；雙屬性乘積clamp .4–1.8。遊戲說明UI仍有原作×2/×.5/×0文案，與函式不符，以函式為準。證據 `main-DSroRSEE-mvekcp7c.js:245`、`:316`、`:57405`，`news-DDcWCXrq-mvekcp7c.js:746`、`:2227`。

六圍先正規化：a(stat)=stat/BST×6；evolution+growth為t，o=1+.12t；maxHp=round((70+45a(hp))o)、armor=6a(def)+3a(spd)、physical=.82+.2a(atk)、special=.82+.2a(spa)、moveSpeed=.92+.12a(spe)。基礎crit=.05、critDamage1.75、pickup6。相同來源群的正向乘數以加法疊bonus後乘一次，不是每份一直連乘；減益乘數則直接乘。證據 `main-DSroRSEE-mvekcp7c.js:38476`。

特性不是只照abilities.json文字：roster.passive如photosynthesis/blaze/torrent-shell/mew，經Jp修正、Hp/player/combat hooks執行；photo等為自訂倖存者玩法。例 moxie/speed-boost累積damage上限+.3，chlorophyll日照或swift-swim雨天額外damage×1.2；Mew能學更廣的高power非status池。道具typeBoost每份+.3，Eviolite只在仍可進化時額外armor×1.5/maxHp×1.25。證據 `main-DSroRSEE-mvekcp7c.js:38544`、`:39521`、`:39613`、`:51200`。

**Godot對應**：基礎種族Resource、角色kit Resource、被動事件handler分層；效果資料必須標明add／bonus sum／獨立mul，避免把說明文字當實際公式。18屬性使用明確runtime矩陣，不直接照百科值。

### 招式轉換與可學條件

```text
919招原始資料
   ↓ xp分類：status白名單／手工覆寫／名字regex／type+cls備援
710個runtime definition（25種arch）
   ↓ roster kit + 自身祖先learnset + 已入Liga同類型kit + 特殊廣池
升級候選（等級、空槽、放逐、重複過濾）
   ↓ 選卡／招式升級
Ep slot → zp timer/active/tick → projectiles / combat / zones / VFX
```

`Sp`以原型定義重建武器：dmg=arch.dmg×clamp(.72+power/260,.85,1.3)，cd=arch.cd×clamp(.88+(power−60)/500,.85,1.15)，priority>0再×.85。status原招式轉special；PP／target不是倖存者消耗制。狀態率若有ailment，clamp((ailmentChance||30)/100×1.6,.15,.8)；無則按type給狀態與.12，status招先.8，最後再套key SPECIAL。drain=clamp(drain/100×.3,.05,.25)，或drain原型.12；crit原始≥1給+.15、flinch/100；weather、buff、count/spread/pulses等另存。手工OVERRIDES與SPECIAL有五批合併，**不能只抄初始gp**。證據 `main-DSroRSEE-mvekcp7c.js:36393`、`:37351`、`:37398`、`:37417`。

原始accuracy僅在「必中special→homing」分類使用，未沿用原作命中率與PP。執行基礎damage另×1.3×mods.dmg×(1+.04(level−1))；area直接乘玩家area，dur/speed乘各自倍率；CD最低.12。真正命中再經combat算屬性、crit、盾、狀態反應、特性、物品：STAB×1.25（adaptability×1.5625），天候增強×1.3、削弱×.75，crit乘玩家critDamage。證據 `main-DSroRSEE-mvekcp7c.js:37737`、`:35695`。

learnset為 `[moveId,level]`；`wp`收自身與祖先的可轉換招式；升級時要求原作learnLevel≤2.6×玩家等級+10（顯示門檻為max(1,ceil((learnLevel−10)/2.6))），並混入本角色四招kit（門檻0/2/4/7）。同屬性且已入Liga的其他角色kit也可共享，normal可通用，但不等於任何角色能學919招。Mew從power≥60非status可轉換招式廣池選。初始優先kit[0]，不是任意抽919招。證據 `news-DDcWCXrq-mvekcp7c.js:2225`、`main-DSroRSEE-mvekcp7c.js:37498`、`:51255`、`:52867`。

**Godot對應**：離線資料轉換出自有MoveDef Resource，含arch、base數值、狀態、FX recipe；runtime只讀轉換結果。自動施法與命中系統分開，格子搜尋共享；技能改級修改slot mods，不改基礎Resource。資料表的710列是可轉換能力，並非每局全池。

### 經驗、選卡與裝備

升級需求 `round(8+5.5L+L^1.8)`；XP乘xpGain與diff.xpMult，while可連升多級，排入pendingLevels逐個選。生存另乘Ne(L)曲線。卡牌newMove/upMove/newVit/upVit，招式最高8、維他命10；一般3選、Lab擴到4選，有reroll/skip/banish。池空時補20%HP、15金並進training的小永久局內增益（此處永久指這局，不是Lab存檔）。證據 `main-DSroRSEE-mvekcp7c.js:39390`、`:39665`、`:51255`、`:53931`。

道具runtime102種，不是items.json125種全進抽池；掉寶先看解鎖／封存、持有上限、稀有度與tags；同屬性tag權重4，非對應tag .35，無tag1；一般max10，特定物品max1等覆寫。稀有度權重受luck、level、stage逐步解鎖，不是固定百分比。例rare-candy直接加2級、max-revive加revive；事件型道具還有擊殺、受擊、CD觸發。證據 `main-DSroRSEE-mvekcp7c.js:39592`、`:51237`、`:51440`。完整數值見表。

**Godot對應**：UpgradeOffer為可序列化資料、卡牌scene只呈現與選擇；池生成與套用分開。裝備mods／事件handler獨立，Lab解鎖只改候選資格。經驗可跨多級，但modal不能重入；pending queue與進化事件共用明確state。

### 進化、Ultimate與Liga

進化不直接照原作evoLevel：若下一階還能進化，需求clamp(round(8+原等級),16,30)；最後一階clamp(round(22+.6×原等級),36,50)，原等級空值用20／34。roster可用evoLevel/evoLevels覆寫；伊布36級分134/135/136支線，鯉魚王40級。無下一階可進化時，24／44級的growth補足最多兩階成長，進化與growth一起影響+12% damage/HP係數與Ultimate tier（`main-DSroRSEE-mvekcp7c.js:39485`）。進化先於正常選卡，演出3.6秒、近距離orbit相機，變種後重算屬性並保留一定HP比例。證據 `main-DSroRSEE-mvekcp7c.js:333`、`:52900`、`:53909`、`:54007`。

Ultimate被動充能95秒一槽，普通擊殺+.004但killRoom最大.024、每秒補.024；Elite+.03、Alpha／特殊+.08、Boss+.2，Ultimate自身slot8擊殺不回能；onHurt傳入值×.35。Lunar blessing充能×1.3、Soul Dew×1.4，active期間不加。基礎dmg=40×(1+.1level)×Bf(run)×(1+.15tier)，Bf按stage為1/1.8/3.2/4，tier=min(2,evoStage+growth)。自動Ult可設定、需附近敵人；不把95秒誤當固定CD。證據 `main-DSroRSEE-mvekcp7c.js:52382`、`:52421`、`:52475`。

Liga是局外角色集合／解鎖，不是已找到的即時PvP。challengeProgress完成者進leagueReady候選，捕捉／joinLeague才增加league與解鎖family；研究點、seen、forms與shiny是另外進度。Alpha支援用Amigo Ball、只在當局作盟友，不加入Liga；一般捕捉與Boss傳說有獨立攔截流程。證據 `main-DSroRSEE-mvekcp7c.js:23899`、`:36279`、`:58020`。

**Godot對應**：進化Resource描述to/threshold/branch，演出只改視覺state，確認後替換種族資料；Ultimate Resource定義cast與可選演出，charge獨立於冷卻。Liga／解鎖／研究／當局盟友分四種存取，不能混用一個captured陣列。

### 敵群、Boss與局長

一般敵由biome types、late types、resident families與stage限制建池：stage1只evoStage0、stage2≤1、stage3只1–2，另補高BST無進化單階。排除legendary/mythical，優先有動畫（主池animated≥24時只留animated）；起初抽3張生成卡。每張cost=1+BST/220，credits按時間曲線累積，不是每隔一秒固定生N隻。完整HP／傷害／數量／難度公式在敵表。證據 `main-DSroRSEE-mvekcp7c.js:40627`、`:40701`、`:40813`。

Boss由boss／shrine互動點啟動；forest每區guardians3候選，再第4區Mew聖域；desert對應守護者與聖域見表。Boss配血先算種族HP×倍率，再以近期每秒輸出樣本第85百分位（最多120個樣本）×目標秒數×(1+.15×tier)×difficulty作HP下限，只提高、不壓低原本HP。守護者目標40/50/60秒、傳說60秒；超過目標時間2.5倍後，每20秒exhaust增傷翻倍。不能只報一個「Boss血量」。證據 `main-DSroRSEE-mvekcp7c.js:45339`、`:45408`、`:48797`、`:53503`。

標準局流程是3一般區＋第4聖域（目前兩區域都有sanctuary）；殺Boss開portal，玩家進portal才前進／完成。**未找到一局固定總分鐘數**；每一般區stageTime≥600啟動finalSwarm，非強制勝利。死亡／主動離開／最終portal結束；過區保留玩家build、重建terrain與敵群。生存mode無固定終點，300秒里程碑、12/24分鐘phase、45分鐘night，另有migration換新seed地圖、保留build。證據 `main-DSroRSEE-mvekcp7c.js:53653`、`:53706`、`:54549`，`news-DDcWCXrq-mvekcp7c.js:1770`。

**Godot對應**：Director用預算／卡片權重／最大敵數三層控量，任務目標觸發Boss，不把本作套成固定10分鐘boss；世界重建與局內build存活生命週期分開。Boss配血若採用必須向設計表明是隨build動態變化，不能跟固定數值表混用。

## 6. 局外成長與伺服器邊界（只讀 source）

profile有stardust、totalStardust、league、starter、unlocked、forms、research、captured、seen、played、shinies、lab、biomes、quests、counters、runs/best/times/kills/medals/endless、daily/weekly/streak、bag、itemsOwned/itemsOff、cosmetics/avatar/frame/title、settings等。這是客戶端schema，不是本次取得的任何玩家存檔。證據 `main-DSroRSEE-mvekcp7c.js:57585`。

| 進度／操作 | bundle的伺服器流程 | Godot對應 |
| --- | --- | --- |
| 載入／偏好 | loadProfile取得profile；savePrefs只送settings、lastSpecies/Biome、avatar/frame/title/skins，400ms debounce | 本地prefs與權威進度分開；偏好變動不整包覆蓋經濟 |
| 開局 | startRun回ticket/seed/ranked，消耗boost；offline ticket不能保存局外進度 | RunTicket＋隨機seed；本地可玩與可計分標記分開 |
| checkpoint | heartbeat15秒、批次cps；keepLive把局內結果暫存localStorage | 自有checkpoint佇列＋本地journal，可重送且去重 |
| 結算 | report傳增量counters/research/seen/league/shinies/forms與run結果；採伺服器回傳profile，失敗還原snap | 進度改變先可回滾，server response才確定入帳 |
| 遷移保存 | pb.live與pb.pending（最多5筆）保留待送；finish成功dropPending；offline無ticket報錯不保存 | 版本化本地待送紀錄＋一次性run id，不直接信任修改客戶端錢包 |
| 局外購買 | Lab、物品解鎖／封存、starter等走專用backend方法 | 每項操作明確API contract；本研究沒有這些server實作 |

證據 `main-DSroRSEE-mvekcp7c.js:57797`、`:57946`、`:76724`、`:76746`、`:76827`；heartbeat `news-DDcWCXrq-mvekcp7c.js:1705`。**未呼叫表中任何路由**。伺服器驗證演算法、資料庫與實際排行榜判定未找到；前端驗證常數只能說明客戶端預期，不能當後端行為保證。

## 7. 手機：邏輯視窗、橫向提示與觸控

派工單所稱 `core/touch.ts` 原始檔／source map未找到；相同功能已在打包後Oi/Fi/Ai/k_定位，不能宣稱取得了原始TS。

| 問題 | 實際程式與參數 | Godot對應 |
| --- | --- | --- |
| 偵測touch | coarse pointer／maxTouchPoints＋沒有fine pointer；localStorage可強制on/off，混用mouse/touch時切換class | Input事件切換呈現模式，不只依OS名稱 |
| 邏輯viewport | 橫向短邊<480時：logicalWidth=min(1100,round(long×480/short))；scale=long/logicalWidth，四位小數，同設initial/min/max，禁止zoom；其他情況device-width | 專案stretch／Control anchors處理邏輯大小；web shell若需viewport設定與Godot畫布尺寸分開，避免只把HUD字縮小 |
| 旋轉 | portrait時html.touch .rotate-hint全屏grid；顯示rotate.png與橫向提示。Ai嘗試fullscreen後screen.orientation.lock('landscape')，catch忽略；**有提示與鎖定嘗試，不保證瀏覽器強制橫向成功** | 原生DisplayServer方向設定；Web顯示可理解的旋轉overlay，容忍iOS／瀏覽器不支援鎖定 |
| 左搖桿 | 左側42%接pointer；半徑46、deadzone .1，超出漂移範圍時重設中心；輸出方向是0或1全速，knob仍類比顯示；可fixedStick | Control scene＋InputEventScreenTouch/Drag，每根finger獨立id；deadzone後是否類比應明訂 |
| 右手 | 拖曳轉鏡頭、雙指pinch zoom；跳、dash、R/E/Q、pause、lock獨立按鈕 | InputMap動作共用鍵盤／手把／觸控，button只轉發動作；camera look不搶搖桿finger |
| 防卡觸控 | pointercancel/lostcapture、blur/pagehide、visibilitychange釋放；紀錄實際touch count補清理 | 所有取消／失焦都清理按住狀態，避免角色出選單後持續走 |

證據 `main-DSroRSEE-mvekcp7c.js:1040`、`:1083`、`:1110`、`:1147`、`:54873`、`:55022`；旋轉CSS `main-Cbxzqrvd-mvekcp7c.css:19077`、`:19122`。

### 品質與持續效能控制

| 品質 | 最大敵數 | 粒子密度 | bloom |
| --- | --- | --- | --- |
| low | 500 | .5 | 關 |
| medium | 900 | .8 | 開 |
| high | 1400 | 1 | 開 |

省電再乘粒子密度.7、FPS cap30與DPR上限1；獨立選項damageNumbers／hideOwnFx／ownFxOpacity／reduceFlashes／pickupFx。每2秒估算play FPS，低於27且敵數>250時，perfCap降為當前有效數×.82、底250；連續3次高於50且接近cap才+50回復；若FPS cap30，門檻改22.5/27.6。這在調整敵數上限，會影響玩法，不只是畫面。證據 `main-DSroRSEE-mvekcp7c.js:52559`、`:52737`、`:54409`、`:77622`。

記憶體也會管理sprite batch：每4秒trim，閒置至少15秒才可被回收，總估計圖像位元組超過mobile200MB／desktop560MB才釋放最舊batch；過區用更緊80MB／300MB與3秒期限。尚未ready用placeholder並等stageSprites loading，背景預載其他敵人。證據 `main-DSroRSEE-mvekcp7c.js:5337`、`:52764`、`:53689`。

**Godot兩渲染器建議**：初版先限制同時可見角色數、atlas常駐量、粒子填充與透明overdraw，保留一套低階共用材質；原生Mobile可提高數量／解析，Web Compatibility保守配置。畫質設定與會改敵群的動態難度應分開，計分模式不宜無聲地沿用原作調cap方式。上述JS數量不是Godot手機可承諾的性能數字。

## 8. 未找到／未驗證清單

| 項目 | 本次能確認到哪裡 |
| --- | --- |
| 原始TypeScript、core/touch.ts、source map | 未找到；只有minified bundle與本地pretty |
| PMD PNG實際尺寸／每張透明邊界與方向目視 | 有JSON metadata與載入路徑；依規則未下載PNG，未驗證圖像內容 |
| GLB面數／UV與授權 | loader及model key已找到；GLB不在白名單，未下載 |
| 一般地圖的程序瀑布生成 | 未找到；只找到標題Rc瀑布與同名招式 |
| 伺服器存檔、反作弊、精確配對／榜單規則 | 未找到server實作；僅讀客戶端schema與request方法 |
| 遠端平衡覆寫 | 未取得；本報告只列bundle/JSON，未套用另一款遊戲api-config |
| 各裝置實際FPS／觸控方向鎖成功率 | 未驗證；source只有預算與相容fallback |
| Godot4.7 Compatibility／Mobile視覺與性能一致性 | 未驗證；本件是研究與移植設計，不含prototype |
| 資產再使用權利與來源完整條款 | 本下載白名單內容中未找到可支持整套重用的授權文件；自有遊戲需自有或另確認授權素材 |

本次沒有改舊遊戲文件、既有 README 或 Claude 實玩筆記；也沒有 commit。
