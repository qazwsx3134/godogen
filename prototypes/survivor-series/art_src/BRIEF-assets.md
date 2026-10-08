# 派工：敵人、交通工具、背景與圖示原畫候選（第四輪）

目標：男女主角原畫已核准，畫風定了。用 agent-sprite-forge 依序生成其餘素材的候選圖，給 Claude 與使用者挑選。只生成候選，不 approve、不做動畫、不做交通工具的其他方向。

根目錄：`/Users/peter/repo/godot/godogen/prototypes/survivor-series/`（以下簡寫 `SS/`）
Python：`/Users/peter/repo/agent-sprite-forge/.venv/bin/python`（系統 Python 套件太舊）

## 共同規則

- **生圖一律加 `--route codex-cli`**（`master_still.py generate --route codex-cli`；直接呼叫 `route_media.py` 時同樣加 `--route codex-cli`）。使用者的 config 裡有幾把 API key 無效或沒額度，預設順序會先試它們而失敗；這次只用 Codex 登入額度，不碰任何 API。

- 提示詞來源：`SS/docs/opt-image-prompts.md`，各素材的 text 區塊照用；可依 master_still 的格式調整措辭，但不改外觀描述。
- 畫風參考（每張都附）：
  - `--style-ref SS/art_src/heroes/man/master-green/master_rgba.png`（`--style-ref-what "the approved hero sprite of this game"`；只學畫風、輪廓線、像素密度、上色與視角，不學他的臉、髮型、服裝或顏色）
  - 美術方向參考圖 `SS/docs/reference/art-direction-night-market.png`；master_still 只收得下一張畫風參考時，以主角 sprite 為優先，在 `--extra` 寫明夜市暖色燈光的調性。
- 角色與交通工具：`--facing right`、`--view "elevated three-quarter overhead view about 50 degrees above the ground, body turned diagonally toward the lower-right"`、`--finish pixel`。
- `--recap` 一律寫一句完整外觀摘要（之後影片 prompt 會以「The same <recap>」開頭），不要寫成「the character in the reference」。
- 去背色 `--key`：設計含紅、粉、紫 → `green`；含綠 → `magenta`；兩者都有 → `blue`。在報告裡寫出每項用了哪個。
- 原始 `generated.png`、`prompt.txt`、`job.json`、`run.json` 全部保留；朝向相反時水平鏡像交付，原始檔不動。
- 每個素材一個資料夾，含候選 PNG（真透明 alpha）與並排比較圖 `candidates-contact.png`。

## 階段一：敵人、交通工具、背景（每項 3 張）

| 素材 | 提示詞段落 | class | 輸出 |
|---|---|---|---|
| 抽菸者 smoker | ## 3 | mob | `SS/art_src/enemies/smoker/` |
| 臭臭胖子 fatty | 第二批「臭臭胖子」 | mob | `SS/art_src/enemies/fatty/` |
| 機車與騎士 motorcycle（朝右下 se） | ## 4 | mob | `SS/art_src/vehicles/motorcycle/` |
| 汽車與駕駛 car（朝右下 se） | ## 5 | mob | `SS/art_src/vehicles/car/` |
| 夜市街區 street_block | ## 6 | — | `SS/art_src/background/street_block/` |

- 背景不是 sprite：用 `$generate2dmap`（或 `route_media.py image`），不透明、5:7（1200×1680；工具不支援就用最接近的直式比例，原圖保留不裁切）。只附美術方向參考圖，不附主角 sprite。
- 交通工具：騎士／駕駛與車是同一張圖；兩個輪子、後照鏡、安全帽都完整不裁切。

階段一完成後寫報告 `SS/art_src/ASSETS-REPORT-1.md`，**然後直接開始階段二**，不用等回覆。

## 階段二：武器與掉落物圖示（每項 2 張）

`icon_{slipper,pearl,firecracker,incense,lantern,cane,gem,coin,rice,vacuum,chest}`，內容見 `opt-image-prompts.md` 第二批「武器與掉落物」的表格（中文描述請翻成英文 subject／identity）。

- `--class prop`、`--facing none`、`--finish pixel`；一張一個物件，置中。
- 遊戲裡只有 24～40 px：要求輪廓粗、細節少、深色外框。
- 輸出：`SS/art_src/icons/<名稱>/`（例：`SS/art_src/icons/slipper/`）；另做一張全部圖示的總覽 `SS/art_src/icons/all-contact.png`。

完成寫 `SS/art_src/ASSETS-REPORT-2.md`。

## 驗收條件

- 每項的候選數量足夠；sprite 是真透明 alpha、單一主體、沒有被裁切、沒有地面陰影、沒有文字或車牌字樣；背景不透明、中央留空。
- 角色與交通工具朝右下，視角跟主角一致。
- 某一項生不出來就在報告寫明原因、跳過繼續做下一項；整條生圖路徑不能用（no-route、登入失效）就停下回報，不要改用 codeart 程式繪圖替代。

## 回報

每份報告 ≤20 行：實際生成路徑（route_media 回報的 provider/model）、每項候選與比較圖的路徑、每項用的 key、與提示詞不符之處、遇到的問題。完成後在對話最後只回一行：`DONE` 或 `BLOCKED：原因`。
