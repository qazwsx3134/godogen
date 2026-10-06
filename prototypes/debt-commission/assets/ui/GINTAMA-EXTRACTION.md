# 銀魂和紙去背素材

2026-10-06 依作者要求，使用內建 `imagegen` 編輯模式，對 [v2 Option A](../../../../docs/story-telling-game/v2/story-telling-ui2.jpeg) 去背並清除固定文字。這是模型輔助的去背／補圖，並非保證逐像素相同的原圖裁切。

最終素材表為 `gintama_reference_cutouts_v2.png`，具有真正的 alpha 透明背景。`v1` 是框角修正前的製作紀錄。以 Godot `Image.get_region()` 分離、`Image.resize()` 正規化後，遊戲使用以下 PNG：

| 素材 | 尺寸 | 內容 |
| --- | --- | --- |
| `gintama_extracted_paper.png` | 1050×290 | 紙框、紙紋、波紋、櫻花、下一句三角；無固定台詞 |
| `gintama_extracted_nameplate.png` | 350×82 | 雲形名牌、金邊、喇叭；無固定名字 |
| `gintama_extracted_log.png` | 195×62 | LOG 按鈕底圖與文件圖示 |
| `gintama_extracted_auto.png` | 195×62 | AUTO 按鈕底圖與播放圖示 |
| `gintama_extracted_skip.png` | 195×62 | SKIP 按鈕底圖與雙播放圖示 |
| `gintama_extracted_menu.png` | 195×62 | MENU 按鈕底圖與齒輪圖示 |

紙框用 `NinePatchRect` 保留四角；波紋、櫻花與邊框在同一張圖片中，不會各自縮放後伸出紙框。`Frame.clip_contents` 額外限制繪製範圍。文字、名字與按鈕標籤仍是獨立 node，可隨劇本更新；沒有自動重建或切圖流程。

## 最終提示詞

下面為提示詞摘要；[完整送出內容](GINTAMA-EXTRACTION-PROMPTS.txt)保留兩次內建 imagegen 呼叫的原文。

初次去背：

```text
background-extraction. Extract ONLY the bottom visual novel UI from the supplied
720x1280 screenshot (y=980 and below). Preserve source colors, textures, outlines
and ornamental detail; extraction and text cleanup, not a redesign.
Create SIX separate transparent RGBA cutouts with clear gaps in three rows:
1. Cream washi dialogue paper, thin double navy/silver rounded frame, pale blue
   seigaiha INSIDE the lower-left edge, pink sakura INSIDE lower-right edge,
   faint blossoms at upper right, blue down-pointing triangle. Remove dialogue
   text and overlaid nameplate, repairing paper/border behind it.
2. Original navy/gold cloud name plaque with curved left flourish, stepped right
   end and speaker icon. Remove only 銀時, leaving blank navy center.
3. Four rounded dark navy/silver buttons in LOG/AUTO/SKIP/MENU order. Preserve
   the original document/play/double-play/gear icons, remove caption words.
Keep each original aspect ratio. True alpha outside silhouettes; no background,
no checkerboard, no added words, no extra ornaments, no protruding waves.
```

框角修正（以初次去背圖為編輯目標、原圖為權威參考）：

```text
precise-object-edit. Correct only extraction errors in the transparent asset
sheet. The paper silhouette must be a SIMPLE rounded rectangle with thin navy
outer and silver/warm inner borders. REMOVE invented stepped/shell corner lobes,
notches, protrusions and outside shadows. Preserve paper, waves, blossoms,
sakura and triangle INSIDE the rectangle. Darken name plaque center to the
original very dark navy; keep cloud flourish, edges and speaker icon. Toolbar
cutouts unchanged. Keep the same three-row layout and alpha background.
Dialogue, names and toolbar captions stay blank. Do not redesign or add shapes.
```
