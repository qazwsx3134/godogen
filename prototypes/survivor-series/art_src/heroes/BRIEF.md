# 派工：行人反擊 男女主角原畫（master still）

目標：用 agent-sprite-forge 的 `$generate2dsprite`（`master_still.py generate`）為兩位主角各生成 3 張原畫候選，給 Claude 挑選。只做原畫，不做動畫、不核准（approve）、不做其他素材。

## 輸入
- 參考圖（每張都附上）：`/mnt/d/repo/godot/godogen/prototypes/survivor-series/docs/reference/art-direction-night-market.png`
- 提示詞：`/mnt/d/repo/godot/godogen/prototypes/survivor-series/docs/opt-image-prompts.md` 的「## 1. 男主角」與「## 2. 女主角」兩段 text 區塊，照用；可依 master_still 的格式需求調整措辭，但不改外觀描述。
- 兩位共用：像素風、Q 版略大頭、斜俯視約 50 度、面向右下、透明背景、無陰影。

## 輸出位置
- 男：`/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/man/`
- 女：`/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/woman/`
- 每位 3 張候選＋master_still 產生的並排比較圖（contact sheet）。

## 驗收條件
- 每位有 3 張候選 PNG，透明背景、單一角色、手腳未裁切。
- 男：油頭黑髮、深藍西裝、紅領帶、駝背垂肩、厭世半閉眼。
- 女：酒紅髮、黑短外套、淺藍上衣、白靴、站姿挺直、銳利線條眼。
- 做不到（例如沒有可用的生圖路徑、參考圖附不上）就直說並停下，不要改用 codeart 程式繪圖替代。

## 回報
寫到 `/mnt/d/repo/godot/godogen/prototypes/survivor-series/art_src/heroes/REPORT.md`：
實際用的生成路徑（route_media 回報的 provider/model）、每張候選的完整路徑、比較圖路徑、遇到的問題。≤20 行。
