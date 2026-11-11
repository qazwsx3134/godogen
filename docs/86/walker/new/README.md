# Walker v2（照使用者提供的三視圖，手機版規格）

參考圖：`three-view.png`（正／側／背）、`top-and-45.png`（俯視、45°）。以側視圖定比例（全高 3.0 m）。腳的左右張開程度，正視圖和俯視圖畫得不一致，取兩者中間。

| Name | Description | Size | Path |
|------|-------------|------|------|
| walker | 四足戰車，15,784 tris，15 個零件，1 種材質（6.7 MB GLB） | 高 3.15m、寬 4.16m、全長 5.38m（含砲管） | `walker.glb` |

## 手機效能

| 項目 | 數值 | 說明 |
|------|------|------|
| Draw call | 15（每台；陰影另計） | 每個零件只有 1 個 surface、共用一種材質 `Walker` |
| 三角面 | 15,784 | 匯入時 `meshes/generate_lods=true`（Godot 預設），遠距離自動降面 |
| 貼圖 | albedo／normal／ORM 各 2K，emission 1K | ORM 照 glTF 慣例：G 粗糙度、B 金屬度 |
| VRAM（ETC2/ASTC） | 約 11.5 MB | albedo 2.7、normal 5.4、ORM 2.7、emission 0.7 MB（已用 headless 匯入實測） |

在遊戲專案裡要設定：
1. 專案設定開啟 `rendering/textures/vram_compression/import_etc2_astc`（手機匯出需要）。
2. GLB 匯出的四張貼圖，在 Import 面板把 `Compress > Mode` 設成 `VRAM Compressed`。`walker_normal` 另外把 `Normal Map` 設成 `Enable`。headless 匯入的預設是 Lossless；編輯器第一次在 3D 用到時可能會自動切換，但不保證，請手動確認。
3. 同時出現很多台時：關掉腳和刀刃這類小零件的投影（`cast_shadow`），或整台只留一個簡化的投影替身。

## 細節

- **砲：**
  - 機匣：藥室外殼（含鋼箍）接錐形藥室，再接往前漸細的砲管。兩側各有一支駐退筒。
  - 砲管：中段有鏽色箍環，後面是排煙器（較粗的一段），前方有夾環。
  - 砲口：喇叭形制退器，兩側開孔，前方有黑色砲膛。砲管下有感測器臂和紅色鏡頭。
  - 機匣外觀：前上方削角，兩側各有兩排螺栓、檢修蓋板和扣具。頂上有兩根立柱夾一支帶環橫桿，後段有機構盒和側面齒輪。
  - 管線：兩條，從機匣接到車體。
  - 後方彈藥箱：側面有梯形導軌和紅燈，頂上有散熱鰭片，背面是 X 形補強加中心螺栓，另有兩個提把。
- **機身：**
  - 頭部：黑色面框和紅色單眼，主眼周圍一圈螺栓，兩側各一顆副鏡頭，頭側有散熱縫。
  - 背甲：飾條上有螺栓，頂上有提把、後段散熱格柵，另有一支鞭狀天線。
  - 機身後方：一對排氣管。
  - 機腹：齒輪箱與散熱片、四條線束、液壓桿，兩側各一個油箱。
  - 髖關節：用叉形支架夾住，每片支架都有螺栓。
  - 刀刃：平行四邊形板，下緣有亮色刃口，另有支架和鉚釘。
- **腳：**
  - 關節：髖和膝是螺栓圓盤，膝蓋旁有致動器盒。
  - 大腿：兩側各一支液壓缸。
  - 小腿：骨形，上下各一道金屬箍，兩側有螺栓，內側有液壓桿。
  - 腳踝：避震彈簧。
  - 腳掌：鏽色六角錐台，凸緣上有一圈螺栓。
- **貼圖烘焙：**
  - 法線圖：所有邊緣都有倒角高光，米白漆和深色金屬上有直線面板接縫。
  - albedo：邊緣掉漆露出底下的金屬，接縫線加深，還有迷彩斑、鏽和髒污。

## 檔案與重建

- `build_walker.py`：Blender 5.1 腳本。流程：建模 → 共用 UV → 用 Cycles 烘四張圖（`walker_albedo`、`walker_normal`、`walker_orm`、`walker_emission`）→ 換成單一材質 → 輸出 `walker.blend`、`walker.glb`。要改形狀就改腳本再重跑，約 1 分鐘。
- `render_check.png`：四視角（`../render_check.py`）；`render_closeup.png`：前左上方的近景（`render_closeup.py`）。

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"; W=$(wslpath -w docs/86/walker/new)
"$B" -b --factory-startup --python "$(wslpath -w docs/86/walker/new/build_walker.py)" -- "$W"
"$B" -b --factory-startup --python "$(wslpath -w docs/86/walker/render_check.py)" -- "$W"
"$B" -b --factory-startup --python "$(wslpath -w docs/86/walker/new/render_closeup.py)" -- "$W"
```

## 在 Godot 裡

節點樹與朝向和 v1 相同（見 `../README.md`）：`Hull` → `Turret`（繞 Y 轉）→ `Cannon`（俯仰）→ `Muzzle`；四條腿各為 `Leg_*_Thigh/Shin/Foot`。機頭朝 +Z（`MODEL_FRONT`）。

- 後方彈藥箱垂到膝蓋的高度，砲塔大角度轉動會撞到後腿。砲塔左右轉動建議限制在 ±30° 以內（估算約 32° 開始碰到後膝），或改成整台車體轉向。

## 已知限制

- 面板接縫是用世界座標的 Y／Z 平面切出來的；斜放的腿上會變成斜線。
- 機艙曲面是凸包做的，輪廓比參考圖略塊狀。
- 參考圖的正視圖裡刀刃往下斜得很陡；這裡照側視和 45° 圖做成接近水平。
- 沒有在實機或 Godot 手機渲染器上看過畫面；上面的效能數字來自匯入結果，不是實測幀率。
