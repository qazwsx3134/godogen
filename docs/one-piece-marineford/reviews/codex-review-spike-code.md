# luffy-marineford 視覺 spike 程式審查

結論：**需要修正**。未發現 P0；發現 3 項 P1、7 項 P2。既有測試全部通過，但未涵蓋下列邊界及素材整合問題。僅新增本報告，未修改實作、scene、shader 或測試。

以下 `scripts/`、`scenes/`、`shaders/`、`tools/`、`materials/` 路徑均相對於 `prototypes/luffy-marineford/`。分級：P1 為路線／生成的明確錯誤；P2 為視覺規格、量測或編輯維護問題。

## P0

無。

## P1

### 1. 橋口的大步長會把玩家橫向瞬移進橋

- 位置：`scripts/route.gd:56`、`scripts/route.gd:59`；呼叫端 `scripts/main.gd:222`。
- 情境：`clamp_point` 只收到移動後座標，僅在橋口內側不足 1 m 時擋住 Z。以玩家半徑 0.55，`(12, -150.3)` 會停在 `(12, -150)`，但 `(12, -151.1)` 直接變成 `(3.95, -151.1)`，一次橫移 8.05 m。現有 dash 26 m/s 與允許的 0.1 s timestep 足以跨過這個 1 m 判定帶。反向入口也有相同行為；停在橋口時亦未留圓形半徑的縱向距離。
- 建議：讓移動約束取得起點、終點與半徑，對橋口邊界做掃掠／分段碰撞並保留切向滑動；不要依固定 1 m 帶推回。補前後兩個入口、dash／低幀率、大半徑敵人的測試。
- 證據：獨立 Godot 探針重現上述兩個輸出；現有 `test_route.gd` 僅測入口內 0.3 m 的單點。

### 2. 舊的距離回收分支繞過路線約束，且會把前方敵人丟到後方

- 位置：`scripts/horde.gd:244`–247；`scenes/main.tscn:291`。
- 情境：新 `recycle_behind` 分支走 `obstacles.push_out`，但 `dist > recycle_distance` 的舊分支直接寫 `_pos` 後 `continue`，不經 Decor／Route。起點目標 `(0, 0)`、敵人 `(0, -190)` 時，實際回收為 `(0, 55)`，超過後界 `back_z=30`，`route.walkable` 為 false；下一 tick 才被另一回收分支搬到前方。它還會反轉敵人所在側，與「主要從前方來」不一致。
- 建議：啟用路線模式時統一走路線回收策略，所有分支都驗路線、道具與可見性；避免先搬到後方再隔幀修正。保留無路線模式的舊行為即可。
- 證據：對實際 main 的 Horde 執行 `spawn(0, Vector2(0,-190))`，再 `step(0, Vector2.ZERO, 0.55)`，得到 `(0,55)`／`walkable=false`。

### 3. 終點附近的生怪／回收會在鏡頭內、甚至玩家身上出現

- 位置：`scripts/main.gd:323`–327、`scripts/horde.gd:240`–243、`scripts/route.gd:57`。
- 情境：向前 55 m 的候選位置超過終點後，`push_out` 會把所有候選 Z 夾到 `end_z + radius`，不再保有前方距離。玩家 Z=-248 時，探針生成的普通敵人為 `(-3.047178,-251.5)`，距玩家 4.64 m，`is_position_in_frustum=true`。繼續到終點時，重生位置可與玩家重疊，讓玩家看見瞬間出兵／立即接觸傷害。後方回收使用同一個夾取方式。
- 建議：先檢查前方是否還有有效且在鏡頭外的生成區；沒有就停止補兵／延後回收，或用關卡明確的入口。生成與回收都應檢查最小玩家距離、視錐及角色體積，不以 clamp 後的位置直接當有效出生點。

## P2

### 4. 玩家與精英的身分描邊沒有接上

- 位置：`scenes/player.tscn:14`、`materials/sprite_instanced.tres:7`、`scripts/horde.gd:538`；共用預設見 `addons/proto_kit/sprite3d.gdshader:41`。
- 情境：玩家材質沒有設定 `outline`，其預設 alpha 是 0；Horde 的 `use_colors=false`、16-float buffer 也未傳 `instance_color()`，精英無從取得金色描邊。目前看得到的深色線來自原圖與全畫面深度描邊，不能視為「玩家白／精英金」驗收通過。
- 建議：在玩家自有材質保存白色 outline；大量敵人依 kit 的角色色通道接身分，或用獨立批次。若啟用 MultiMesh colors，須在 instance_count 前啟用並同步 buffer stride／搬移處理。一般海兵維持無額外身分描邊。

### 5. density 只切角色，地面與主要地標一直是 40 px/m

- 位置：`scripts/main.gd:128`–133、`shaders/terrain.gdshader:8`、`shaders/toon_solid.gdshader:7`。
- 情境：切到 `033` 或 `020` 時角色是約 30.303 或 50 px/m，路線地面、橋與地標仍用 shader 預設 40 px/m。沒有任何整合程式更新 `px_per_m`。這能比較角色素材，但不是設計文件明訂的全場共用密度版本。
- 建議：選定 SpriteSet 後，把 `1.0 / meters_per_px` 套到遊戲自有的 terrain／solid 材質，保留固定世界尺寸。補三種 density 對應材質值的整合檢查。

### 6. 平地深度差採 d² 的方向合理，但固定係數沒有隨解析度／鏡頭換算

- 位置：`shaders/pixel_outline.gdshader:16`、`shaders/pixel_outline.gdshader:40`–47。
- 推導：平地、透視、鏡頭高 h、俯角 θ、實際渲染高度 H、垂直 FOV 下，令 `f = H / (2 tan(FOV/2))`，相鄰畫素的 view-depth 差近似為 `d² cos(θ) × thickness / (h f)`。所以平方項有依據，但係數同時依賴 H、h、θ、FOV 和 thickness，不能固定成 0.0004。
- 情境：high 在 H=540、thickness=1、d=120 m 時，精確鄰格差約 2.86 m，低於目前門檻 6.26 m；這個基準沒有平地誤描問題。但 H=240 時約 6.64 m，或 pokebonk preset 在 H=540 時約 7.19 m，都超過 6.26 m，尚未進入 160 m fade 區就可能把平地當邊。thickness 加大亦有相同問題。
- 建議：依實際 `VIEWPORT_SIZE` 與鏡頭參數換算係數，或比較扣除平面深度梯度後的跳變。驗至少兩種實際渲染高度與 thickness=1／2；不要以 UI 的 540 邏輯高度代替渲染高度。

### 7. SHOT 的 player_px 同時混用了直立高度與邏輯座標

- 位置：`scripts/main.gd:575`–584；對照 `scripts/main.gd:523` 的 UI 縮放與角色 shader 的 `lean=1`。
- 情境：`head` 用世界 `Vector3.UP * 1.8`，角色實際沿鏡頭 up 的 billboard 方向展開，因此不是同一條投影線段。high 探針：回報線段 46.17，billboard 線段約 54.82（皆為 viewport 邏輯單位）。實際 1280×720 截圖時，函式印的 viewport 卻是 960×540，還少了 4/3 的像素換算；該 billboard 高度約 73 個截圖像素，不能以日誌的 46 px 判斷密度可讀性。
- 建議：把世界直立高度估算另命名；角色投影用真實 billboard 基底、sheet 內容高度與當前變形，並乘邏輯到 render texture 的轉換。另列 logical viewport、輸出圖片尺寸，保存檔案後檢查 `save_png` 回傳值。
- 證據：`/tmp/luffy-review-render.png` 為 1280×720；同次日誌印 `viewport=960x540 player_px=46`。數值探針計算出上述兩種投影。

### 8. 圖集格子大小被當成敵人的影子／施法高度

- 位置：`scripts/horde.gd:523`、`scripts/horde.gd:264`、`scripts/horde.gd:544`；影子見 `addons/proto_kit/sprite3d_shadow.gdshader:18`。
- 情境：`_k_size` 現在是整格 quad 的 `size_m()`，同一份密度裡海兵與中將因此取得相同 `_k_size`。三密度的值分別是 3.168／2.8／2.56 m；共用實例的影子預設寬 0.55 倍，於是只換像素密度就讓影寬由約 1.74 m 變成 1.41 m，施法發射高度也由 1.90 m 變成 1.54 m。角色世界身高固定，但場景中的其他世界尺寸跟著格子 padding 改變。
- 建議：把 quad 格尺寸與角色體格／影子／施法錨點分開。後三者依角色固定的世界規格，不能依 atlas cell。碰撞半徑目前仍取 EnemyDef，跨密度沒有跟著變大，這部分可保留。

### 9. punch 動作播不到收手格

- 位置：`scripts/player.gd:44`、`scripts/player.gd:173`、`scripts/player.gd:279`–281。
- 情境：預設 pose_time=0.2 s，punch 的 tick 只走到 12 以下，但已交付的 punch `d=[6,8,10]`，第三格從 tick=14 才開始。因此正常 punch 永遠省略第三格；kick 把 hold 時間乘 1.6 時，tick 仍減固定 pose_time，前段會變負數，kit 會把它夾到第一格。
- 建議：保存獨立的動作起始 tick／已播 tick，以 sheet 動作長度控制結束；若要維持 0.2 s 的戰鬥節奏，就明確把整段動畫映射到該時長。補一輪 punch 實際走過三格的測試。

### 10. 路線重建工具忽略已存 scene 的 export 調整

- 位置：`tools/build_route.gd:22`–27、`tools/build_route.gd:89`（最後的 save_scene）。
- 情境：每次都建立全新的 Route，按腳本預設值產生 terrain.res；已有 scene 則不覆寫。使用者照 README 在既有 Route 根節點改橋段／路寬／高度後重建 mesh，mesh 仍按舊預設產生，執行時的 clamp／height 卻使用 scene 保存的新 export，造成「看得到的路」與「能走的路」分離。Bridge 的保存尺寸也不會隨 export 自動更新。
- 建議：已有 scene 時從該 scene 讀取設定，再只更新明確擁有的 mesh／橋面幾何，保留人工編輯的地標與材質；或把地形設定抽成 scene 與工具共用的 Resource。驗一次修改 export→重建→開場景／執行的一致性；正常啟動仍不可自動重建。

## 驗證及邊界

1. `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/luffy-marineford route sprites core:60`：**PASS route、PASS sprites、PASS core**，循序執行；記錄目錄 `/var/folders/y8/00ksqf0156n9lqddlq79vnlc0000gn/T/godot-tests.X38c7D/`。執行前確認只有 madara 的編輯器，沒有其他 Godot 測試。
2. 獨立探針 `/tmp/luffy-review-probe.gd`：直接載入實際 main，重現橋口、回收越界、終點可見生成，並比較兩種角色投影。指令為 `/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/luffy-marineford --log-file /tmp/luffy-review-probe.log --script /tmp/luffy-review-probe.gd -- --density=033`。未寫入遊戲檔；headless 有一條 macOS 憑證環境訊息，未出現 GDScript 錯誤。
3. 實際桌面渲染：`/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/luffy-marineford --rendering-method gl_compatibility --resolution 1280x720 --log-file /tmp/luffy-review-render.log -- --seed=3 --stress=250 --no-hud-perf --shot=/tmp/luffy-review-render.png --shot-delay=1`。Apple M1 Pro／OpenGL 4.1 Metal，成功存圖、已目視檢查，沒有 shader 編譯錯誤。
4. 未跑瀏覽器 WebGL、手機、正式 p95 benchmark 或三情境效能驗收；桌面 Compatibility 成功不能代替這些結果。

### 量測可信度補充

`_record_perf()` 用單調牆上時間差，沒有使用被 clamp 或 hit-stop 縮放的 dt，能記到長幀；暖機後才收樣本。`floor(n*0.95)` 的零起算索引在 n 為 20 的倍數時，比 nearest-rank 高一格，是略保守的定義差異，不是把卡頓藏起來。可以明訂百分位算法，無須因這點否定現有資料。

`in_view` 是**結束當下、固定 y=0.5 的點是否落入視錐**，不是整段樣本裡的可見敵人數，也不測牆／道具遮擋、精靈邊界或飛行高度；其迴圈含 `horde.count` 中尚未回收的死亡實例，而 enemies 用 alive()。把它當幾何估計可接受，但單獨一行不能證明「250 隻實際可見」的效能驗收。後續證據應列採樣期數量範圍並配固定構圖，另補 CPU／瀏覽器／DPR／WebGL renderer 等環境資料。

### 渲染管線核對與參考

目前路徑在結構上成立：

```text
3D opaque → 首次讀屏的深度描邊（priority -100）
          → 其他透明物（0／1）→ Environment 後處理
          → Grade（CanvasLayer 0，2D 首次讀屏）→ HUD（預設 layer 1）
```

Canvas 的首次讀屏會在 2D 繪製階段複製目前畫面，因此此處可取得已完成的 3D（含透明物），HUD 又在之後繪製；不必僅因未用 SubViewport 就判錯。3D 描邊自己仍只讀 opaque 拷貝，因此它必須先於其他透明效果。`-100` 不是引擎最小值（最小 -128），但目前場景與材質其他透明 priority 為 0／1，足以排最前。

- [Godot 讀屏與 2D／3D 拷貝時機](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html)：支持上述兩階段解讀。
- [Godot 深度重建與全螢幕 quad](https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html)：Compatibility 的 NDC z 要映射到 -1..1，這裡的分支正確。z=0 在 clip 範圍內，加上 depth_test_disabled／depth_draw_never，不會因採 reverse-Z 就必須判成錯誤；quad 掛相機且有大 cull margin。
- [Godot Material priority](https://docs.godotengine.org/en/4.7/classes/class_material.html#class-material-property-render-priority)：核對透明物優先序及範圍。
- [Godot 4.7 shader 內建變數註冊](https://github.com/godotengine/godot/blob/4.7/servers/rendering/shader_types.cpp#L456)：sky 階段確實註冊 FRAGCOORD；Bayer 使用小型整數陣列／動態索引，本輪桌面 Compatibility 已編譯成功，沒有證據將它列為 WebGL 不支援。實際瀏覽器仍須驗證。

## 已確認沒問題的項目

目前五列加三鏡像的選列順序、camera-relative 方向與 hysteresis 接法正確；`Horde._remove` 會搬移 `_look`／`_dir`，沒有遺漏方向狀態。現有 hit 僅一格，以 flash／dead 狀態選取不會發生多格動畫時鐘錯位。SpriteSet 的角色選擇、密度值與 quad 尺寸載入通過實際讀取測試；現有主要畫面、HUD、玩家與路線均有可編輯保存 scene，route 產生器不是正常啟動依賴。固定相機的 XZ／Y 分開平滑與沿視線拉遠通過測試；Compatibility 深度重建、目前透明排序、Grade 在 HUD 前的層級亦未發現阻斷錯誤。
