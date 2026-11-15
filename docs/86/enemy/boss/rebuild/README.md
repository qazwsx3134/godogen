# Boss 分部位重建稿

依 Meshy 五張截圖調整的後續版本見 [meshy_refined/README.md](meshy_refined/README.md)，包含獨立可編輯來源、遊戲 GLB 與五視角預覽；本頁保留原 v2 的資料。

上一版的圓盤與獨立尖槍和參考圖相差太多。這版重新拆成槍管、身軀與前刃、外圈腳刺、左右尾巴，逐部位建模後組裝成 40 m 的視覺檢查稿；舊版檔案與參考圖均保留。參考側視含透視，俯視深度和部分連接仍需推定。

目前仍是**可編輯的重建稿**：白色環架、側面甲片和尾節仍較規整、圓滑；與參考圖的銳利折面、交錯裝甲及細密機械結構還有差距，尚未經使用者造型驗收。沒有骨架、動畫、遊戲碰撞或遊戲場景接入。

## 檔案與分件

- `boss_v2.blend`：整機可編輯來源，包含以下命名父物件；改完請先存檔。
- `boss_v2.glb`：烘焙後的整機靜態 GLB，1 個網格／surface 和 1 種材質，內嵌色彩及粗糙度／金屬度圖。
- `boss_v2_albedo.png`、`boss_v2_orm.png`：分別為 2048² 色彩、1024² ORM（G 粗糙度、B 金屬度）；GLB 已含這些貼圖。

| 部位 | 來源父物件 | 獨立 GLB／檢視圖 | 零件／三角面 |
|---|---|---|---:|
| 槍管 | `Cannon_Module` | `cannon_v2.glb`、`cannon_three_quarter.png` | 16／1,644 |
| 身軀、白色環架與前刃 | `Body_Module`、`Forward_Yokes` | `body_v2.glb`、`module_body.png` | 113／12,608 |
| 外圈腳刺與支架 | `Leg_And_Spine_Module` | `legs_v2.glb`、`module_legs.png` | 188／3,432 |
| 左右尾巴 | `Tail_Left_Module`、`Tail_Right_Module` | `tails_v2.glb`、`module_tails.png` | 112／4,952 |

分件 GLB 保留多個網格與原材質，供檢視、編輯及組裝；整機 GLB 才是單 surface 烘焙版。四個分件使用相同座標系，在同一原點放置即可還原造型；已重新匯入四個檔案，逐三角面與整機位置比對通過。

`v2_front.png`、`v2_rear.png`、`v2_side.png`、`v2_top.png`、`v2_side_reference.png`、`v2_three_quarter.png` 是重新匯入整機 GLB 後的預覽；`cannon_front.png` 等槍管圖和 `module_*.png` 分別由分件 GLB 產生。

## 實際驗證（2026-11-14）

| 項目 | 結果 |
|---|---|
| 外框 | 寬 14.302 m × 長 40.000 m × 高 9.022 m；最低點離原點平面約 5.5 cm |
| Blender 來源 | 429 零件、12,174 來源頂點、22,636 三角面 |
| 逐零件拓撲 | 開邊、非流形邊與頂點、退化面、游離頂點、翻面、不正常有向體積及檢查範圍內的自相交均為 0 |
| 組裝接合 | BVH epsilon 5 mm、包圍盒容差 10 mm 下為 1 組，含 429／429 個零件；近共面閃爍候選 0 |
| 分件重組 | 重新匯入四個分件後，22,636 個三角面按 0.1 mm 座標精度與整機逐一比對，缺少及多出均為 0 |
| GLB UV | 超界、近零面積與正面積重疊均為 0；UV 面積合計約佔圖集 25.129% |
| 細面貼圖 | 按 UV 三角面面積估算，1,756 面在 2048² 色彩圖、4,390 面在 1024² ORM 不足 1 texel；近距或 mipmap 下可能混色 |
| Godot 4.7 | 整機匯入為 22,636 三角面、25,592 個 GPU 頂點、1 surface；尺寸、索引、UV、法線、退化面、材質通道、貼圖尺寸及背面剔除通過 |
| 體積 | 整機 GLB 2,110,812 bytes；Blender 來源 344,004 bytes |

來源每個零件皆封閉且接合成一組，但零件之間是相交或接觸，**不是頂點焊接的單一水密拓撲**。自相交檢查排除同零件共用頂點的三角面組；近共面篩選與接合容差也不能保證動畫時不露縫或所有相機距離都不閃爍。日後製作可動尾巴與腳刺時，須重查關節覆蓋及動作範圍。

這版面數比舊版 7,328 面高，2048²／1024² 圖集也是為目前較細的幾何暫定；尚未以實際場景、陰影、LOD 和手機設備量測成本。若最終遠距觀看，應先量測輪廓與尖刺閃爍，再按畫面重要性減少短刺、隱藏面和尾節細件，重新檢查接縫與 UV，避免只按百分比整體減面。

## 編輯與重跑

在本資料夾執行以下命令，`blender` 指 Blender 5.1。匯出會覆寫既有 GLB 和圖集，先保存並備份人工修改；所有渲染與匯出命令都應在獨立 Blender 行程執行。

```text
blender --background boss_v2.blend --python-exit-code 1 --python ../audit_boss_source.py
blender --background boss_v2.blend --python-exit-code 1 --python export_modules.py -- --overwrite
blender --background boss_v2.blend --python-exit-code 1 --python export_boss_v2.py -- --overwrite
blender --background --python-exit-code 1 --python audit_boss_v2_uv.py
blender --background --python-exit-code 1 --python validate_modules.py
python3 validate_boss_v2.py
blender --background --python-exit-code 1 --python render_boss_v2.py -- --glb
blender --background --python-exit-code 1 --python render_modules.py
blender --background --python-exit-code 1 --python render_cannon.py -- --glb
```

`export_boss_v2.py` 會複製來源零件、重新展 UV 與烘焙，不會儲存來源；金屬度／粗糙度目前須為 Principled BSDF 的直接數值，使用連結貼圖會明確報錯。`build_boss_v2.py` 是程序化重建工具，不是一般編輯流程；只有指定 `--save-source` 才會寫來源，已存在時另需 `--overwrite`，重建會丟棄人工修改。

目前驗證檔 SHA-256：

```text
boss_v2.blend  b8b7a27a40749d53723dbd8686b10ede04f48cdbfdffd7ce9e454a8d1e14d194
boss_v2.glb    a4924692181bd38e94022644d1ffb88b692cd016f0e43fc7162cf57f65a39862
```
