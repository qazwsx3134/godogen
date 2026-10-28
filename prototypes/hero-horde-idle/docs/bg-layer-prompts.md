# 行軍戰場背景分層：opt image 提示詞

REVIEW 第 2 點：背景要用多層疊加做出景深，物件本身不能帶背景（現在主畫面的 `LowerPatch*` 是從參考圖裁的方塊，連後面的天空與山一起裁進來）。這份是要給 opt image 生的圖層清單；生好放進 `art_src/bg_layers/`（Godot 不匯入），檔名照下表，Claude 再縮到遊戲的像素密度、去背檢查、接進每頁的風景層與行軍視差。

## 怎麼疊

```
 y=100 ┌──────────────────────────────────────┐
       │ 1 sky        天空＋雲（不透明）        │  視差 0（不動）
       │ 2 far        遠山剪影（透明）          │  視差 0.12
       │ 3 mid        中景丘陵＋城鎮（透明）    │  視差 0.35
 y=360 │ 4 props      樹、灌木、岩石…單張去背   │  視差 0.65（程式依種子擺放）
 y=470 ├──────────────────────────────────────┤
       │ 5 ground     地面帶（不透明、可橫向接） │  視差 1.0（跟行軍同速）
 y=525 └──────────────────────────────────────┘  ← 面板從這裡開始蓋住
```

座標是 941×1672 版面；戰場寬 941、可見高度 425（y=100～525）。行軍角色站在 y=470 的地面線上，身高約 35 px。

## 全部圖層共用的描述（每張提示詞前面都加）

> 16-bit JRPG pixel art, crisp hard-edged pixels, no anti-aliasing, limited palette (about 32 colors), soft daylight from the upper left, original high-fantasy countryside, calm warm colors, side view, no text, no UI, no characters

每張圖都要：同一個光源方向（左上）、同一套色盤；第 2～4 層**背景完全透明**，不要天空、不要地平線、不要外框；可橫向接的圖左右兩端要能無縫接上。

## 要生的圖

| # | 檔名 | 尺寸（建議生成） | 透明 | 提示詞（接在共用描述後） |
|---|---|---|---|---|
| 1 | `sky.png` | 1882×530 | 否 | wide sky backdrop only, pale blue gradient to warm horizon, a few soft pixel clouds, nothing on the ground, empty bottom third |
| 2 | `far.png` | 1882×300，左右可接 | 是 | distant blue-grey mountain range silhouette, low contrast, hazy, transparent background, seamless horizontal tile |
| 3 | `mid.png` | 1882×260，左右可接 | 是 | rolling green hills with a small stone castle and a stone aqueduct far away, transparent background above the hills, seamless horizontal tile |
| 4a | `prop_tree_a.png` | 512×512 | 是 | single leafy oak tree, full tree with trunk base, isolated on transparent background |
| 4b | `prop_tree_b.png` | 512×512 | 是 | single tall pine tree, isolated on transparent background |
| 4c | `prop_bush.png` | 512×256 | 是 | low round green bush with small flowers, isolated on transparent background |
| 4d | `prop_rock.png` | 512×256 | 是 | mossy grey boulder cluster, isolated on transparent background |
| 4e | `prop_ruin.png` | 512×512 | 是 | broken stone pillar ruin with ivy, isolated on transparent background |
| 4f | `prop_lamp.png` | 256×512 | 是 | wooden roadside lantern post, isolated on transparent background |
| 4g | `prop_fence.png` | 512×256，左右可接 | 是 | short wooden fence segment, seamless horizontal tile, transparent background |
| 5 | `ground.png` | 1882×110，左右可接 | 否 | side-view ground strip, grass top edge with small tufts over packed dirt path, seamless horizontal tile |

要第二地區、第三地區（霧沼、熔岩）的版本時，同一套檔名加 `_fog`、`_lava` 後綴，提示詞把顏色換成「misty swamp teal and grey」「volcanic red rock and dark basalt」，物件換成枯樹／火山岩。先做第一套確認風格再生後兩套。

## 驗收

- 第 2～4 層邊緣沒有殘留的白邊或天空色（Claude 接圖時會檢查 alpha）。
- 縮到遊戲尺寸後，物件的像素粗細跟行軍角色差不多（Claude 統一縮放，不用自己調）。
- 色調放在 `sky.png` 上看起來是同一張畫。
