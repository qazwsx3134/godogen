# 00GameDevs → Godot 原生特效（2026-11-01）

46 份使用者提供的 Three.js 匯出檔均有 Godot 實作與可編輯 scene。遊戲與網頁中的播放不依賴 Three.js，也沒有嵌入原網站 iframe。完整 ID／原檔 SHA-256／預設參數／移植方式見 `addons/proto_kit/vfx/three_sources.json`；原始 JS 留在 repo 根目錄 `vfx-example/three-effect/`。

## 已實作目錄

| 類型 | ID |
|---|---|
| 投射物 | fireball、plasma-bolt、ice-shard、arcane-missile、spiral-gale |
| 光束 | continuous-beam、pulse-beam、charged-beam、arc-ray、radiant-beam、soul-siphon、venom-stream |
| 地面／法陣 | healing-field、burning-ground、frost-field、magic-barrier、arcane-matrix、black-hole |
| 爆發／衝擊 | fire-explosion、energy-burst、shockwave、ice-shatter、flame-surge、thunder-strike、astral-convergence、billowing-airburst |
| 旋風／煙霧 | wind-vortex、dust-devil、fire-vortex、energy-vortex、smoke-column、ground-fog、steam-jet、smoke-puff |
| 特殊演出 | azure-sweep、darkchain-detonation、golden-chain-rain、dimensional-rend、astral-gate、prism-guard、prism-parry |
| 場景物件 | painterly-grass |
| 武器拖影 | weapon-smear |
| 全畫面打擊 | impact-frame |
| 預警 | spell-indicator-circle、spell-indicator-sector |

`vfx/library.gd` 的 3D 目錄現在有 87 種：46 原生效果＋41 個 Scenario billboard。3D 展示頁預設篩選 00GameDevs；切 All sources 能看到全部，切 Scenario sprites 看圖卡。新增 Hit、Stop、速度控制；武器與後製在獨立 demo scene 中使用示範武器／目標，不混進可供遊戲取用的原生效果本體。

## 移植內容與精度

42 種程序效果使用原始 JS 實際產生的幾何、shader 方程、自訂頂點屬性與預設值。原始實例資料攤成三角形，16 個 float 保存在 CUSTOM0～3，其餘最多兩個 float 放 UV2；不使用會壓縮／截斷資料的頂點 COLOR。原資料最大 18 個自訂分量。總共 985,848 個展開頂點、191 個原 shader 部件；另有深度策略 shader variant、預警、拖影與後製 shader。

Three.js 與 Godot 的 front-face 約定不同，三角形由 CCW 改為 Godot 的 CW，並對原 FrontSide 材質保留單面剔除。參照 [Godot ArrayMesh 官方文件](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)。自訂資料與 UV／normal 隨頂點一起換序；沒有重算法線或縮放形狀。原 blend_add、premultiplied alpha、One/One 加法與不混色的 RGB 路徑分別處理。保留透明物件 renderOrder，以及常態／活動階段的深度寫入政策。一般不透明部件移除 ALPHA 輸出以進入 Godot 的 opaque pass；少數原先提早繪製、卻仍有加法／premultiplied 混色的部件採負 render_priority 保留先後。

原 GPU 動畫仍即時計算。少數由 JS 改寫的 scalar／vec4 array／變換／顯示通道保存為 30 Hz AnimationLibrary；在取樣時點對照原 JS 快照，sample 之間的 scalar／變換插值不保證與原連續函式逐像素相同。vec4 array 採離散軌，保留事件 ID 與 GPU 所需 PackedVector4Array 型別；不讓 AnimationPlayer 的連續插值轉成通用 Array。生命週期、uTime、停止時間、opening／retire 別名由原生 script 即時計算；冰晶的連續旋轉直接計算，沒有 5 秒迴圈接縫。自訂 draw-count 變化採離散 30 Hz；一般起始／活動／收尾的 draw range 即時切換。

原 JS 標示 Three.js 0.187.0。本機離線 cache 可用的是 **0.185.1**，已校驗 npm cache integrity 後以它執行原始幾何／參考快照；未改原始匯出碼。此版本差異記錄為驗證邊界，沒有宣稱重現過 0.187.0 renderer。Three 僅用於製作工具，Godot runtime 沒有此依賴。

本次固定的是使用者提供的預設造型。原始全部 defaultOptions／preset 保存在來源索引；尚未為每個 JS setOptions 參數做原生動態重建介面。遊戲可調 root transform、speed、材質與 AnimationLibrary；若要改會改變幾何配置的 quantity／density／seed，需從原始資料重新製作。billowing-airburst 的 reset 重用此次固定的 variation，不會像原 JS 一樣換隨機造型。

Three transmission 改成 Godot screen texture；捕捉順序、透明背景與色彩管線仍需 GPU 外觀比對。shader 本輪以 Compatibility 為基準。幾何展開增加記憶體與未採用 draw range 的頂點工作量；沒有聲稱已完成手機效能驗收。

## 遊戲使用

```gdscript
const Vfx = preload("res://addons/proto_kit/vfx/library.gd")

func play_burst(world_center: Vector3) -> void:
    var fx = Vfx.get_scene("fire-explosion", "3d").instantiate()
    fx.free_on_finish = true
    add_child(fx)
    fx.global_position = world_center
```

所有原生 scene 位於 `vfx/3d/00gamedevs/<id>.tscn`。只用一個效果可直接 preload 該 scene；所有複製都保留 `vfx/licenses/00gamedevs-MIT.txt`。`library.gd` preload 整個目錄，供工具／展示用，selected-scene 匯出也會帶入依賴。

- `auto_step=true`：由 Godot 遊戲時間推進，遵循 SceneTree 暫停與 time_scale。自己的時鐘則 `auto_step=false`，每幀一次 `step(game_delta)`；不要同時兩邊推。
- `speed`：0.25～2，連動 GPU 與已保存的動畫軌。`free_on_finish=false` 預設保留，完成會發 `finished`；一次性效果可開自動清除。
- `reset()`：重播同一實例；持續效果須遊戲呼叫 `stop()` 後等收尾，或依宿主物件生命週期釋放。burst 的 stop 與來源相同為 no-op。
- `set_direction(direction, travel_speed)`：投射物，方向是父節點座標；視覺速度 speed 不改世界移動速度。
- `set_endpoints(from, to)`：光束，兩點是父節點座標；保留原 4.8 單位基準，零長度隱藏。
- `hit(world_point?, world_normal?)`：投射物接「已確認命中」後呼叫。給世界座標時，真正的 impact mesh 會對齊接觸點與法線；不做碰撞與傷害判定。

原作者多數效果以中心為原點，地面約在 local Y=-1.35。事件要對齊地面時，將 world_center 放到地面上方約 1.35；也可在自己的繼承 scene 調 `%Parts` 的座標原點。`Parts` 對應原作者的 group，會保留這個編輯器調整；命中轉換也包含它。

### 武器拖影

```gdscript
var trail = Vfx.get_scene("weapon-smear", "3d").instantiate()
add_child(trail)
trail.attach_weapon(actual_weapon, Vector3.ZERO, Vector3(0, 1.4, 0))
# 外部時鐘時，先更新武器動作，再 trail.step(delta)。
```

刀根／刀尖是 weapon 本地座標。最多 64 份世界座標歷史、三層原 shader，0.18 秒消退；停手不產生新段。傳送／長幀會清除舊軌跡，不拉出跨場長線。`stop()` 排空、`detach_weapon()` 解除、`reset()` 保留綁定；不生成武器或控制玩家。`weapon_demo.tscn` 只是展示。

### 全畫面打擊

`impact-frame.tscn` 根是 CanvasLayer，可掛在 3D 或 2D viewport；目錄歸在 3D 原生效果。呼叫 `trigger(godot_screen_uv, attack_direction)`，座標為 Godot 左上原點；原 shader 的 bottom-left 轉換在內部完成。已活動時拒絕重複 trigger，七段節奏共 0.4 秒，結束會還原未修改畫面。

`set_subject_mask(texture)` 接收與 viewport／camera／遮擋一致的線性 R channel mask；沒有自動的 setSubjects 選角／相機綁定。不提供 mask 時保留來源的畫面亮度分類模式，不能將它描述為精確指定角色的輪廓。HUD 是否受影響取決於 CanvasLayer 排序；展示只覆蓋預覽 SubViewport。原始 16 次筆觸取樣已展開，降低成本可把 stroke_length 設 0；仍待真機量測。

## 可編輯場景與製作工具

- 42 種：root、`Parts/PartNNN`、`Motion`；Parts 的 transform／材質可調，正在被動畫控制的 transform 請改 Motion 軌或其上層 Parts。幾何與動畫保存於 `ported/<id>/*.res`，Shader 為實際 `.gdshader`。Scene 保存原作者 previewTime（缺少時取可見的演出時點），執行由 reset 回到零；數值測試也驗證預覽狀態沒有污染起始值。
- 拖影：`Layers/Layer0..2`；連續歷史與 mesh 是執行狀態，不存回 scene。
- 後製：`Overlay` 全畫面 Control，文字與遊戲 UI 不由 script 建造。
- `tools/vfx/three_port/` 是已套用的製作工具，正常載入／測試／執行不會再製場景。修改來源前先檢查差異，避免覆蓋人工調整。

重製流程（需要 authoring 專用 Three 0.185.1；runtime 不需要）：

```text
extract.mjs 原始 JS → /tmp/extracted
convert.py /tmp/extracted /tmp/native
build_native.gd -- /tmp/native
build_special.gd
patch_materials.gd -- /tmp/extracted
save_editor_previews.gd -- /tmp/extracted
make_reference.py /tmp/extracted /tmp/native
update_catalog.py
patch_gallery.gd
```

extract.mjs／package.json 放在同一個 authoring package，npm 安裝精確版本；本輪實際用本機已驗證 cache，沒有下載。builder 會跳過既存場景；已製作 scene 是維護來源，非執行前產物。`patch_winding.gd` 是本輪早期資料的單次修正，目前 converter 已處理 CW、新 mesh 會標記，勿無條件反轉已編輯的 mesh。

測試與限制見 [VALIDATION](VALIDATION.md)。原始來源／授權說明見 [SOURCES](SOURCES.md)。
