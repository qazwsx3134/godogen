# 視覺 spike 第二輪：修正驗證

結論：**尚不能全部結案**。原 10 項中，6 項可結案、4 項部分完成；剩餘問題分為 **P1 × 1、P2 × 3**，沒有 P0。本輪限於處理表所列修正及其直接影響，沒有擴張成新一輪全面審查。僅新增本報告，未修改實作或測試。

以下路徑相對於 `prototypes/luffy-marineford/`；編號沿用第一輪。

## 逐項結果

| 原項目 | 結果 | 驗證重點 |
|---|---|---|
| P1-1 橋口橫移 | **部分完成，仍為 P1** | 玩家半徑 0.55 的原直衝情境已修；現有 heavy 半徑 0.7 仍橫移，斜向跨角也未做掃掠 |
| P1-2 放射狀回收越界 | **可結案** | 路線模式下，原 `(0,-190)` 不再被回收到 `(0,55)`；非路線模式保留舊分支 |
| P1-3 終點可見重生 | **部分完成，剩餘 P2** | Z=-248 不生成、不把追兵搬到身上；33～55 m 前方空間的回收仍會在視錐內瞬移 |
| P2-4 身分描邊 | **部分完成，仍為 P2** | 精英 colors／角色值／20-float buffer 正確；玩家白描邊實際仍未啟用 |
| P2-5 全場密度 | **可結案** | 三種 density 各檢查 49 個路線 mesh 材質，全部符合 30.303／40／50 px/m |
| P2-6 門檻隨解析度換算 | **可結案** | 實際 Compatibility 視窗換尺寸與鏡頭，係數正確跟隨；原低解析度情境已覆蓋 |
| P2-7 SHOT 像素 | **可結案** | 1280×720 圖片回報約 73 image px／55 logical，與 billboard 投影相符；保存錯誤有檢查 |
| P2-8 格子與體格混用 | **可結案** | 三密度的影子皆為 0.95×0.55 m；角色身高固定，施法／受傷位置改用 `_k_body` |
| P2-9 punch 收手格 | **可結案** | punch 與加長 hold 的 kick 都實際走過 3 格，沒有負起始 tick |
| P2-10 產生器保存設定 | **部分完成，剩餘 P2** | terrain 確實依保存設定重建；同長度橋段平移未更新橋面，也沒發出不一致警告 |

## 仍需修正

### P1／原 1：橋口在部分半徑仍瞬移，斜向跨角仍漏判

位置：`scripts/route.gd:59`、`:63`–66、`:78`–88；測試缺口 `tests/test_route.gd:20`–32。

**修正後新增的精度問題**：停止位置先寫入 Vector2，再由 `_clamp_x` 用嚴格不等式重新分類。Vector2 座標取整後，停止點可能仍被判為裂縫內，於是 X 又被夾進橋寬。以現有 `data/enemies/heavy.tres:12` 的半徑 0.7 重現：

```text
clamp_move((12,-149), (12,-152), 0.7) → (3.8,-149.3)
clamp_move((12,-231), (12,-228), 0.7) → (3.8,-230.7)

Z 停在邊界 → Vector2 精度取整 → 再次判成裂縫內 → X 橫移 8.2 m
```

半徑 0.4／0.65／0.95 亦重現，0.5／0.55／0.85 的本次數值恰好沒有。現有橋口測試只用 0.55；第 19 行只驗 `clamp_point` 的 X，反而無法察覺點已被送到橋口後再夾 X。

**原問題的斜向缺口**：`clamp_move((5,-149.4), (3.5,-151), 0.55)` 原樣回傳終點。這步長約 2.19 m，落在 dash 能達到的範圍；線段經過 Z=-150 時 X≈4.4375，圓形半徑已伸入橋外裂縫，但因終點 X 已在橋寬內，第 61 行完全跳過入口碰撞。

建議：停止到寬地面後直接採該區域的 X 約束，避免靠重新比較浮點邊界決定區域；分類另留一致的容差。斜向入口須檢查整段圓形掃掠／首次碰撞，再沿邊滑動。補玩家、heavy 半徑與兩端斜向跨角測試。

### P2／原 4：從未設定的 outline_player 讀回 null，玩家仍無白描邊

位置：`scripts/player.gd:110`；預設值見 `addons/proto_kit/sprite3d.gdshader:41`、`:44`。

目前以 `_material.get_shader_parameter("outline_player")` 取得白色，但這個 uniform 沒有在材質設定值。本輪 **headless 與真正 OpenGL Compatibility 視窗** 都讀到 `outline_player=<null>`，接著 `outline` 也為 null，仍使用原本 alpha=0 的預設。實際截圖亦未見新增白邊。這不是只在 dummy renderer 出現的現象。

建議：在玩家自有材質明確保存 `Color(1,1,1,1)`，或讀值為 null 時提供明確 fallback；不要把「shader 宣告的預設」當成「材質已設定值」。測試應驗實際玩家 outline 的非零 alpha。目前新增的角色測試只檢查 Horde `_k_role`，未覆蓋這行。

精英那半已修好：一般兵 role alpha=1、精英=0.75；commit 後 colors 在 offset 12～15、custom 在 16～19，移除首實例後，搬來的精英仍保有正確 role、方向與鏡像。

### P2／原 3：終點回收以 0.6 倍距離放行，仍在畫面中出現

位置：`scripts/horde.gd:250`–257。

原先最危險的「玩家 Z=-248、前方 55 m」已修：`_spawn_one` 回傳 false、count 不增加；追兵停留原位置繼續追。本項因此不再保留原本的貼身生成 P1。

但回收仍把 clamp 後只剩 33 m 的前方空間視為足夠。重現：目標 `(0,-210)`、追兵 `(0,-180)`，`step(0,...)` 後追兵成為 `(0,-251.5)`。只剩 41.5 m 前方距離，high 鏡頭的 `is_position_in_frustum` 為 true；函式沒有任何可見性判斷，仍會在畫面中瞬移。處理表所述「前方空間不足才留在後方」只解決了最靠近終點的一段。

建議：若意圖是維持 55 m 的前方距離，clamp 後縮短就延後回收；若驗收要求看不到瞬移，還須檢查實際視錐／遮擋或指定隱藏入口。距離比例不能當成不可見的保證。補 Z=-210 這類臨界空間測試，並保留已通過的 Z=-248 案例。

### P2／原 10：橋段平移且長度不變時，橋面錯位而無警告

位置：`tools/build_route.gd:26`–34；保存橋面位置見 `scenes/route.tscn` 的 Bridge。

保存的 Route 設定確實已讀取；這部分修正有效。在 `/tmp` 隔離副本把 `plaza_half` 改成 20、橋段從 `[-150,-230]` 改成 `[-160,-240]` 後，真正執行產生器，重建 terrain 頂點與該 Route.height 的最大差僅約 `1.51e-7 m`。

但橋長仍為 80 m，尺寸檢查通過，**沒有警告**；保存 Bridge 的 Z 仍是 -190，應對齊的新中心卻是 -200。地形裂縫與可走橋段已移動，實際橋面沒移，尾端因此缺 10 m。這仍屬第一輪「保存設定與看得到的路分離」的情境。

建議：接受「人工修改 Bridge」的維護方式，但警告至少同時比對尺寸與預期位置，README 明列這項責任；或只更新產生器擁有的橋面幾何並保留其他人工編輯。不必改回每次啟動自動生成。

## 驗證證據

### 既有測試

循序執行前確認沒有其他 Godot 程序：

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot bash prototypes/godot-kit/tools/run_tests.sh prototypes/luffy-marineford route sprites core:60
```

結果：**PASS route／PASS sprites／PASS core**。記錄：`/var/folders/y8/00ksqf0156n9lqddlq79vnlc0000gn/T/godot-tests.HATB5v/`。這與上述剩餘問題不矛盾：新增測試沒有涵蓋那些半徑、斜向入口、玩家材質值與橋面平移。

### 原情境及修正回歸探針

保留第一輪 `/tmp/luffy-review-probe.gd` 未覆寫，另寫 `/tmp/luffy-review-r2-probe.gd`：舊探針在生成失敗後仍讀 `_pos[0]`，本輪改驗回傳值與 count，避免把未使用的舊陣列槽誤當生成成功。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path prototypes/luffy-marineford --log-file /tmp/luffy-review-r2-probe.log --script /tmp/luffy-review-r2-probe.gd -- --seed=3 --density=033
```

除了上列反例，也實際驗證三密度 shadow world size 均為 `(0.95,0.55)`、body heights 均為普通兵 1.75／精英 2.3；普通／精英 buffer、搬移後 role、punch／kick 三格。另以 `/tmp/luffy-review-r2-density.gd` 分別從三個 QA density 啟動 main，檢查全部 49 個帶 `px_per_m` 的路線材質，每份 mismatches=0。

### 真正 GPU 視窗

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path prototypes/luffy-marineford --rendering-method gl_compatibility --resolution 1280x720 --log-file /tmp/luffy-review-r2-render.log --script /tmp/luffy-review-r2-render.gd -- --seed=3 --density=025
```

Apple M1 Pro／OpenGL 4.1 Metal；無 shader 編譯錯誤。依序切換視窗、等候更新後讀值／存圖：

| 鏡頭 | 真正圖片／render_size | threshold_per_m2 |
|---|---|---:|
| high | 1280×720 | 0.00029130664 |
| high | 426×240 | 0.00087391992 |
| pokebonk | 960×540 | 0.00094158215 |

三值符合係數隨渲染高度與鏡頭改變的推導；已目視檢查 720p 與 240p 圖。回到 high／1280×720 後直接呼叫 `_take_shot`，輸出 `luffy_px=73 image px (55 logical)`，保存檔案也是 1280×720。截圖 `/tmp/luffy-review-r2-shot.png`；其他圖 `/tmp/luffy-review-r2-high-720.png`、`...high-240.png`、`...pokebonk-540.png`。這些是桌面驗證，不代表手機／WebGL 已通過。

### 產生器隔離驗證及未改檔證據

副本 `/tmp/luffy-review-r2-generator/` 中才修改 Route export、保存 scene、執行 `res://tools/build_route.gd` 並讀回 terrain；沒有對原專案跑重建。準備／核對腳本為 `/tmp/luffy-review-r2-generator-prepare.gd`、`/tmp/luffy-review-r2-generator-verify.gd`，生成記錄 `/tmp/luffy-review-r2-generator-build.log`。

本輪開始先記錄 112 個原實作／scene／shader／resource 文字檔的 SHA-256（`/tmp/luffy-review-r2-before.json`）；驗證完成後全部一致。Godot 匯入／測試快取不列為原始碼修改。未跑新一輪 p95 benchmark、未重做手機驗收，也未延伸追查第一輪範圍以外的玩法。

已確認的正常項目：停用路線模式的舊放射狀回收、三密度材質一致性、MultiMesh 20-float 欄位配置與移除搬移、固定影子和體格高度、punch／kick 完整播放、描邊係數隨視窗／鏡頭更新、SHOT 的 billboard 與圖片像素換算，以及 terrain 採用保存 export，均有實際證據支持；沒有在這些已結案部分發現新的阻斷問題。
