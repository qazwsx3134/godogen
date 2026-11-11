# Scout（量產型敵機，低面數）

參考圖：`scout.png`（側、前、後、俯、底）。前方是雙聯機砲，上方是往後掃的冠刃，冠刃下方有一排脊刺，左右各 4 條刀刃狀的腿，共 8 條。

| Name | Description | Size | Path |
|------|-------------|------|------|
| scout | 1,304 tris，1 個蒙皮 mesh，17 根骨頭，1 種材質，`walk`／`idle` 循環動畫 | 高 2.8m、寬約 4.2m、全長約 4.8m | `scout.glb` |

## 為什麼這樣做（戰場上會有很多台）

```
            主角機 walker                   scout
零件         15 個獨立節點，15 次 draw call     1 個蒙皮 mesh，1 次 draw call
動畫         程式 IK，每隻腳 raycast           Blender 預先做好動畫，AnimationPlayer 播放
三角面       15,784                          1,304
貼圖         2K ×3＋1K（約 11.5 MB VRAM）     1K albedo＋512 ORM，沒有自發光
```

- **剛性蒙皮：** 每個零件 100% 綁在一根骨頭上，機身是 `Body`，每條腿有 `L1_Upper`、`L1_Lower` … `R4_Lower`。沒有權重混合，變形不會糊掉。
- **骨頭朝向：** 都朝上放（bone local Y 等於世界的上方），local Z 轉向腿往外伸的方向，方便在 Godot 用程式補動作：
  - 繞 local Y 轉是腿前後擺。
  - 繞 local X 轉是抬腿。
- **走路動畫：** 交替四腳步態，L1、R2、L3、R4 一組，R1、L2、R3、L4 一組。
- **雙聯機砲（每支約 230 tris，從後往前）：**
  - 深色後膛塊。
  - 六角斷面的機匣，後段頂上有一片翹起的背鰭，外側有一條溝線。
  - 機匣下方有一片下唇。
  - 前端是削角的方形護罩，頂部前緣斜切。
  - 深色砲口環和黑色砲膛。
  - 往前漸細的銀色砲管，前端是黑色砲膛。

## 在 Godot 裡

- 匯入後的節點：`Node3D` → `ScoutRig`（Skeleton3D）→ `Scout`（MeshInstance3D），外加 `AnimationPlayer`。
- 動畫：
  - `walk`：0.8 秒，循環。
  - `idle`：2 秒，循環。
  - Blender 裡的動作名稱是 `walk-loop`、`idle-loop`，Godot 匯入時會去掉後綴，自動設成循環。
- 走路動畫的腳每秒移動約 1.6 m，所以 `AnimationPlayer.speed_scale = 移動速度 / 1.6`，腳看起來才不會打滑。
- 原點在地面，機頭朝 +Z（`MODEL_FRONT`）。
- 砲口照參考圖做成黑色，不發光，所以沒有自發光貼圖，大量出現時每個像素也少取樣一張貼圖。如果之後想讓敵機更醒目，在 `build_scout.py` 把 `sizes` 的第三個值改回 256，再給砲膛一個發光材質。
- 數量很多時：
  - 遠處的機體可以把 `AnimationPlayer` 的播放頻率降低，或直接停播。
  - 之後真的要上百台時，再考慮 MultiMesh 加頂點動畫貼圖（VAT）。目前用不到。

## 重建

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"; W=$(wslpath -w docs/86/enemy/scout)
"$B" -b --factory-startup --python "$(wslpath -w docs/86/enemy/scout/build_scout.py)" -- "$W"   # 建模、烘焙、骨架、動畫、匯出
"$B" -b --factory-startup --python "$(wslpath -w docs/86/enemy/scout/render_scout.py)" -- "$W"  # render_check.png、render_walk.png
```

共用的 Blender 工具在 `docs/86/blender_kit.py`：材質、幾何、UV 圖集、烘焙成單一材質。之後的敵機也用它。walker 的腳本保留自己的一份，沒有改。

## 驗證（2026-11-10）

- **Blender：** 1,304 tris、17 根骨頭；重新匯入後的四視角在 `render_check.png`，走路分格在 `render_walk.png`。
- **Godot 4.7 headless 匯入：** 沒有錯誤。結果是 1 個 MeshInstance3D、1 個 surface、17 根骨頭，`walk` 0.8 秒和 `idle` 2 秒都是循環。
- **步態方向：** 用骨頭位置量。
  - 支撐期：L2 的膝蓋相對身體往後移（z 0.44 → 0.13），高度不變。
  - 擺動期：抬高 0.2 m，同時往前移。
  - R2：剛好相差半個週期。

**沒驗證：** 大量機體同時出現時的幀率（實機與編輯器都還沒測）。

## 已知限制

- 冠刃和腳的造型是低面數的簡化版。參考圖裡的細部（裝甲接縫、小零件、腳掌上的爪）都沒做。
- 參考圖的俯視和前視裡，機砲左右間距不一致，取中間值 ±0.44 m。
- 只有走路和待機兩段動畫，轉向、攻擊、死亡都還沒做。
