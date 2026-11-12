# 86 敵機模型

近戰型和坦克型依各自的三視圖製作，共用 scout 的幾何／烘焙工具、八足骨架命名和交替四腳步態。兩種機體的外殼、武器與部分比例依各自的參考圖重做。

| 型號 | 三角面 | 尺寸（寬 × 高 × 長，含武器） | 骨頭 | 動作 |
|---|---:|---|---:|---|
| [melee](melee/README.md) | 1,458 | 5.25 × 2.78 × 5.45 m | 19 | `walk`、`idle`、`attack` |
| [tank](tank/README.md) | 1,324 | 4.74 × 2.54 × 6.54 m | 19 | `walk`、`idle`、`fire` |

尺寸是 Godot 匯入後、靜止模型的 AABB；播放動作時武器與腳會超出此範圍。原點在地面，機頭朝 Godot +Z（Blender -Y），單位為公尺。參考圖沒有標尺寸，因此這些是依 scout 族群與輪廓選定的製作比例。

## 檔案與使用

- 各資料夾的 `.glb` 可直接匯入 Godot；網格、骨架、動畫及兩張貼圖均包含在檔案中。
- `.blend` 是可編輯來源，兩張貼圖也已打包進檔案；旁邊的 `*_albedo.png`、`*_orm.png` 是額外提供的烘焙圖。ORM 的 G 為粗糙度、B 為金屬度。
- `render_check.png` 是側／前／後／俯／前方 3/4／後方 3/4 六視角；`render_motion.png` 上排是步行、下排是攻擊或開火，均由匯出的 GLB 重新匯入後渲染。
- 每台一個剛性蒙皮網格、一個 surface、一種材質；每個頂點完全由一根骨頭驅動。沒有法線貼圖或自發光貼圖。
- `walk` 0.8 秒、`idle` 2 秒，兩者循環。中斷步行或攻擊切換動作時，腳與武器會回到對應姿勢。移動速度與動畫倍率仍需按實際遊戲調校。
- 模型只有視覺與動畫；碰撞、攻擊命中、砲口發射點和 AI 須由使用它的遊戲提供。走路和攻擊若需同時播放，須以 `AnimationTree` 分層及骨頭過濾控制。

## 建模與重建

`build_enemy.py` 使用 `../blender_kit.py`；先以幾何建立零件與剛性權重、烘成一套 UV 圖集，再建立骨架並輸出 GLB。輸出後只移除不會變動的動畫軌；各動作仍保留其他腳與武器的復位軌，避免中途切換後卡在舊姿勢。

**重跑會覆寫該型號的 `.blend`、`.glb`、烘焙圖及預覽圖；若已手動修改來源，先備份。**原始參考圖 `melee.png`、`tank.png` 不會被修改。

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
BUILD="$(wslpath -w docs/86/enemy/build_enemy.py)"
RENDER="$(wslpath -w docs/86/enemy/render_enemy.py)"
"$B" -b --factory-startup --python-exit-code 1 --python "$BUILD" -- melee
"$B" -b --factory-startup --python-exit-code 1 --python "$BUILD" -- tank
"$B" -b --factory-startup --python-exit-code 1 --python "$RENDER" -- melee
"$B" -b --factory-startup --python-exit-code 1 --python "$RENDER" -- tank
```

## 拓撲與佈線檢查（2026-11-12）

用 `asset-gen/tools/check_topology.py` 讀 `.blend` 量測。每台旁邊的 `topology_wire.png` 是著色加線框圖，`topology_issues.png` 是問題標色圖：紅＝完全埋在別的零件裡、橘＝與別的零件穿插、黃＝細長三角形（最小角 < 12°）、藍＝小於 2 cm²。兩張都是 3/4、側面、俯視三個角度。規則與 pipeline 見 [asset-gen/modeling.md](../../../asset-gen/modeling.md)。

| | melee | tank |
|---|---:|---:|
| 零件（合併前的基本形） | 88 | 86 |
| 三角面（來源就全是三角面，沒有四邊面） | 1,458 | 1,324 |
| 完全埋住的三角面 | 216 | 209 |
| 部分穿插的三角面 | 665 | 637 |
| 細長三角形 | 556 | 468 |
| GPU 頂點（與 Godot 匯入後的數字相同）／Blender 頂點 | 2,612／905（2.9 倍） | 2,406／834（2.9 倍） |
| 破面、退化面 | 0 | 0 |
| 貼圖密度 p10／中位／p90（px/m，1024 圖集） | 66／73／78 | 65／73／77 |

兩台的問題來源相同，都在 `build_enemy.py` 與 `blender_kit.py` 的做法：

1. **約 15% 的三角面完全看不到**：各零件以凸包或掃掠管做好後直接 `join`，沒有刪掉埋在同骨頭其他零件裡的面。合併前對同一根骨頭的零件做「內部面刪除」，可以直接省下約 210 面，外觀不變。不建議整台做布林聯集，那會沿接縫切出新的細長面。
2. **甲板與側甲是凸包的扇形三角形**：`hull_pts` 的凸包把大片平面切成從一點放射的長三角形（線框圖的甲板最明顯）。平板改成擠出輪廓，或在 `obj_from_bm` 前把共面三角形溶回 n-gon，匯出時再三角化。腳與砲管本來就細長，黃色多半屬於這類，可以不管。
3. **頂點被拆成 2.9 倍**：`uv_atlas` 用 `smart_project`（60°）自己切 UV 島，又在 40° 標硬邊，兩套切線不重合，結果幾乎每個面都是獨立的 UV 島。把 UV 縫線改成沿硬邊切，目標比例 ≤ 2.0。

穿插（橘色）在不同骨頭的關節處是必要的，動作時才不會露縫；同一根骨頭內的大面積穿插才是要減少的。這次只做檢查，沒有重建模型。

## 驗證與效能

2026-11-12，Godot 4.7 Compatibility，在臨時專案匯入兩個 GLB：各一個網格／surface、19 根骨頭、正確循環與動作；檢查 UV、法線、退化三角面、頂點權重、地面原點，以及中斷走路／攻擊後復位。

```bash
python3 docs/86/enemy/validate_models.py          # 匯入及資料／動畫檢查
python3 docs/86/enemy/validate_models.py --crowd  # 再量 24／48 台混合動畫機體
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
"$B" -b --factory-startup --python-exit-code 1 --python "$(wslpath -w docs/86/enemy/validate_blends.py)"
```

多機測試使用 Godot 4.7 Compatibility、1280×720、Mesa llvmpipe、陰影關閉，所有機體可見並播放步行：24 台共 24 次 draw call／33,384 個三角面；48 台共 48 次／66,768 個三角面。這是繪製結構量測，**不是手機效能或實際戰場 FPS 測試**；陰影、環境、AI、碰撞及畫面大小都會增加成本。Linux 沒有 `DISPLAY` 時，`--crowd` 需要 `xvfb-run`。

這兩個模型尚未接入 walker-tps，也沒有實機驗證；需在實際遊戲與手機上確認動畫倍率、視覺大小、陰影和同屏數量。
