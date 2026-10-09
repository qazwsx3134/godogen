# 派工：吸塵器加粗、交通工具 4 方向、可拼接地圖素材（第五輪）

使用者已從第四輪挑好圖。這輪做三件事，依序 A → B → C，每件做完更新報告再接下一件，不用等回覆。只生成候選，不 approve、不做動畫。

根目錄 `SS/` = `/Users/peter/repo/godot/godogen/prototypes/survivor-series/`
Python：`/Users/peter/repo/agent-sprite-forge/.venv/bin/python`

## 共同規則（同第四輪）
- 生圖一律 `--route codex-cli`；不碰任何 API。
- 畫風參考 `--style-ref SS/art_src/heroes/man/master-green/master_rgba.png`（只學畫風、輪廓線、像素密度、視角）。
- 原始 generated.png、prompt.txt、job.json、run.json 全留；每項一張並排比較圖。
- 某項做不到就在報告寫明並跳過；整條生圖路徑不能用就停下回報，不改用 codeart。

## A. 吸塵器加粗（edit，2 張）
- 來源：`SS/art_src/icons/vacuum/candidate-02.png`（使用者選定）。
- `master_still.py edit`：THE ONLY CHANGE: make the vacuum cleaner chunkier and stockier — a wider, shorter body, a thicker handle and hose, a thicker dark outline, brighter blue-grey metal with clear highlights — so the silhouette reads at 32 px. Same object, same upright vacuum design, same pixel-art style and framing.
- 輸出 `SS/art_src/icons/vacuum/edit-01.png`、`edit-02.png`；比較圖含原圖與兩張 edit，並附 32 px 預覽。

## B. 交通工具其餘 4 個方向（各方向 2 張）
已核准的朝右下（se）原畫：
- 機車：`SS/art_src/vehicles/motorcycle/master/master_rgba.png`（spec 在同資料夾 `master.json`）
- 汽車：`SS/art_src/vehicles/car/master/master_rgba.png`

要做的方向：`s`（車頭朝畫面下方）、`e`（朝右）、`ne`（朝右上）、`n`（朝畫面上方，看到車尾與騎士／駕駛的背面）。遊戲用 5 張加左右鏡像組成 8 方向。
- 以核准圖為 `--identity-ref`（FIRST，同一台車、同一個人，外觀照抄），`--style-ref` 同上。
- `--facing none`，方向寫在 `--view`，例如 `"elevated three-quarter overhead view about 50 degrees above the ground; the scooter points straight toward the TOP of the image, we see its rear and the rider's back"`。
- 五個方向的車身長度、比例、像素密度一致，輪胎接地點在同一條水平線（`--class mob` 同一框法）。
- 輸出 `SS/art_src/vehicles/<motorcycle|car>/dir-<s|e|ne|n>/candidate-0{1,2}.png`；每台車一張總覽 `SS/art_src/vehicles/<車>/directions-contact.png`（核准的 se 放在中間當基準，其餘方向兩張並排）。

## C. 可拼接的夜市地圖素材（`$generate2dmap`，tile_mode＋prop kit）
使用者要「超級大」的地圖：可能是無限捲動，也可能是很大的有限地圖，所以要用拼的，不能是一整張背景。
- 畫風與材質基準：`SS/art_src/background/street_block/selected.png`（使用者選的 01：斜菱形鋪磚、暖色燈籠濕地反光、紅白條紋遮雨棚攤位）。
- **地面（無縫）**：暖灰褐斜菱形鋪磚加濕地反光，四邊無縫可在兩個軸向無限重複；另做 3～5 種疊加變化（人孔蓋、排水溝蓋、小水窪、裂縫、斑馬線段），讓大面積不重複得太明顯。用 `extract_terrain_tiles.py --edge-policy seamless --strict-qc`，報告附 QC 數字。
- **道具包（透明、同 50 度斜俯視）**：夜市攤位（紅白條紋遮雨棚，至少 2 種）、燈籠串立柱、方形水泥花台、三角錐、黃黑條紋護柱、停放的機車（單台）、水果箱。用 prop kit 流程（`extract_prop_pack.py`），每個道具一個獨立透明 PNG。
- **像素密度**：遊戲內主角約 90 px 高；地磚與道具縮到遊戲尺寸時要跟主角同一像素密度，在報告寫出每個素材的遊戲內尺寸建議。
- **匯出**：`export_godot.py` 輸出 Godot 4 TileSet／資源；另做一張 3×3 拼接預覽圖證明接縫看不出來，再做一張「地面＋散放道具＋主角 se 原畫」的示意圖。
- 輸出根目錄：`SS/art_src/map/`（地面 `map/ground/`、道具 `map/props/`、匯出 `map/godot/`、預覽 `map/preview/`）。
- 不畫角色、敵人、煙霧、文字、招牌字。

## 回報
寫到 `SS/art_src/ASSETS-REPORT-3.md`，每完成一件就更新一次（A、B、C 各一段，全部 ≤30 行）：生成路徑、每項輸出路徑與比較圖、地面無縫 QC 數字、與要求不符之處、問題。全部完成後在對話最後只回一行：`DONE` 或 `BLOCKED：原因`。
