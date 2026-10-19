# 派工：madara-survivor 像素風重做（P1）

## 背景
使用者看過上一輪動畫風的圖，覺得透視怪、人物又扁又醜。這輪全部改成**精緻像素風**。
- 參考 HD-2D（Octopath Traveler／Triangle Strategy 的角色 sprite）：細緻明暗、1 px 深色外框、有限色盤。
- 不要動畫賽璐璐風。

## 規則
- **一定要加 `--route codex-cli`**。
- 所有 generate 都用 `--finish pixel`（像素感由 forge 的 pixel finish 產生，不要在 prompt 裡要求邏輯像素格）。
- Codex 的 5 小時額度剩約 3 成：
  - 每個項目照下面寫的張數生成，不要多骰。
  - 額度不夠就先停在已完成的項目，在回報裡寫明。

## 共同風格（每個 prompt 都套用，英文）
```text
detailed HD-2D pixel art game sprite in the style of Octopath Traveler: rich hand-placed shading, crisp 1-pixel dark
outline, limited palette, compact heroic proportions about 4 heads tall, standing upright, front three-quarter view
from slightly above (about 20 degrees), body and face turned toward the lower-right, full body with feet visible on an
invisible ground line, no background, no cast shadow, no text.
```

## 項目

| 資料夾 | class／key／張數 | 描述 |
|---|---|---|
| `madara/` | hero／green／2 | `docs/art-spec.md` 第 1 節的 Madara 描述（紅色分段甲、及腰黑長刺髮遮右眼、白紅團扇、小腿白繃帶），站姿 |
| `genin/` | mob／magenta／2 | 第 2 節；跑步前傾 |
| `masked/` | mob／magenta／2 | 第 3 節 |
| `heavy/` | mob／magenta／2 | 第 4 節 |
| `caster-fire/` | mob／green／2 | 第 5～7 節，火 |
| `caster-water/` | mob／magenta／2 | 第 5～7 節，水 |
| `caster-earth/` | mob／green／2 | 第 5～7 節，土 |
| `elite/` | mob／magenta／2 | 第 8 節 |
| `chakra/` | prop／magenta／1 | 見下 |
| `props/` | prop／magenta／各 1 | 見下 |

- **chakra**：一張圖裡橫排 4 顆查克拉能量球（經驗掉落物），由小到大：
  1. 小顆藍色
  2. 綠色
  3. 紫色
  4. 金色大顆

  每顆都是發光的漩渦狀查克拉火焰球，中心亮，四顆之間留空。
- **props**，三樣各一張：
  - `hoodoo`：風蝕砂岩岩柱，高瘦、層狀紋理、頂部有較寬的帽岩。
  - `boulder`：砂岩大圓石。
  - `shrub`：乾枯的沙漠灌木或風滾草。

  三樣都是正面三分之一俯視。

## 輸出位置
根目錄：`/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1/<資料夾>/`
- 每個資料夾放 `candidate-NN.png`＋`candidates-contact.png`。
- props 的三樣各自建子資料夾：`props/hoodoo/`、`props/boulder/`、`props/shrub/`。

## 驗收
- 透明背景、單一主體、不裁切、朝右下（方向反了就鏡像）。
- 外觀條件和 art-spec 一致。
- 一般忍者的護額不能有村子標誌。
- 做不到就直說並停下，不要用程式繪圖代替。

## 回報
寫到 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1/REPORT.md`，最多 15 行：
- route
- 各資料夾路徑
- 偏差
- 額度狀況

完成後建立 `/Users/peter/repo/godot/godogen/prototypes/madara-survivor/art_src/pixel1/DONE`。
