# 像素水族箱

Godot 4.7 的 2.5D HD 像素水族箱。開啟專案會進入養成缸，新檔有一尾長尾幼魚與 60 金幣。

- 點魚查看名稱、食慾和成長，可命名、投餌、收起或送養。餓魚上方會出現飼料圖示。選「投餌」後點水域，魚會轉頭追餌、張嘴啄食，吃到才計一餐。
- 商店購入的魚卵、薄片飼料、沉底顆粒和裝飾都進右下角背包。點背包展開所有道具，再點道具選孵化、投餌、擺放或賣出。相同品項會堆疊。買來的卵放進孵化盤後等 90 秒，幼魚滿 4 分鐘且吃過兩餐即成年。
- 選裝飾後點缸底預覽位置，按旋轉圖示每次轉 30°，再按勾確認。叉號可退出預覽。已擺放的裝飾可從背包移動、收回或賣出。桌面也可用 Q／E 旋轉、Esc 或右鍵取消。
- 魚缸同時有兩尾可育種的同種成魚且有空位時，系統自動配對、產卵，離線也會繼續。成魚首次準備 60 秒，產卵後親魚休息 180 秒。產出的卵直接孵化，子代外觀於孵化時揭曉。育種手札可查圖鑑、家系與孵化進度。
- 孵出首胎後解鎖每顆 18 金的紅蓮燈卵。三尾紅蓮燈會群游。回缸紀錄可以定位新生與成年個體，右上角可放回收起的魚。
- 左下 **−／＋** 調整縮放，放大後可直接拖曳水域。點倍率重設取景。窄直式視窗也能拖曳觀看左右兩側。桌面支援滾輪縮放。

[首版規格](design/SPEC.md) · [執行方案](design/IMPLEMENTATION.md) · [進度](PROGRESS.md) · [手機介面概念](design/ui-concepts/README.md) · [養魚手帳 UI 實作畫面](docs/care-wood-inventory.png) · [育種手札](docs/care-lineage.png) · [紅蓮燈群游](docs/care-cardinal-school.png)

## 開啟

從 repo 根目錄執行。

```bash
godot --path prototypes/pixel-aquarium
```

也可以在 Godot 專案管理員匯入 `project.godot`，按 F5 開啟養成缸。16:9 時水族箱以 640×360 為基準渲染，UI 隨視窗輸出解析度繪製。其他比例會調整取景以鋪滿視窗。可用 390×844 視窗檢視直式操作。

從 Godot 執行 `scenes/aquarium.tscn` 可觀察 12 尾魚的展示缸，包括鬥魚、紅蓮燈、七彩神仙與オイカワ。[12 尾同缸](docs/freshwater-tank.png)

## 編輯場景

| 場景 | 可調整內容 |
|---|---|
| `scenes/care.tscn` | 養成入口。商店、魚卡、背包、布置工具列、聲音設定和音訊播放器均可在編輯器調整 |
| `assets/care_notebook.tres` | 養魚手帳風格的按鈕、選單與分頁。木紋、葉飾與高亮圖樣在 `assets/notebook/` |
| `scenes/breeding_journal.tscn` | 圖鑑、家系卡、育種進度與各分頁的間距 |
| `scenes/item_slot.tscn`、`scenes/hunger_icon.tscn` | 道具按鈕與缸內飢餓圖示 |
| `scenes/egg.tscn`、`scenes/food.tscn` | 孵化盤、卵殼、顆粒與落水漣漪的可編輯場景 |
| `scenes/aquarium.tscn` | `TankView` 為 3D 畫面。開啟 2D 編輯器即可調整 `Controls` 內的魚隻資訊面板、收起清單與縮放列 |
| `scenes/tank.tscn` | `ViewingCamera` 管理透視取景，`TankLamp` 管理硬景受光。`Plants`、`Hardscape` 與 `GlassAndFrame` 可直接移動。`Fish` 下四尾魚各有位置、`swim_span`、`swim_period` 與起始方向 |
| `scenes/betta.tscn` | `Rig` 包含魚身、兩款尾鰭、胸鰭與眼睛。魚實例的 `long_tail`、`silver` 決定尾與銀紋，游動與展鰭由共用腳本處理 |
| `scenes/cardinal.tscn`、`scenes/discus.tscn`、`scenes/pale_chub.tscn` | 三種魚的模型、魚鰭和點選範圍。主缸的魚實例可調整名稱、外觀描述、材質、游動週期和擺尾速度 |

M0 的魚模型使用 Godot Mesh 資源。可編輯的魚身截面、鰭輪廓與像素著色在 `tools/betta_geometry.gd`、`tools/build_betta_assets.gd`。場景製作工具 `tools/build_scenes.gd` 會儲存並重載場景驗證；調整製作工具時在獨立副本產出候選檔再比較。遊戲與編輯器直接載入已儲存的場景。

紅蓮燈、七彩神仙及オイカワ參考了なちゃっと水族館的淡水素材包。Godot 版以獨立的低多邊形網格、像素 Shader 和游動腳本呈現。素材包原作者以 CC0 1.0 發布，原始照片和 three.js 不隨此專案散布。[模型庫](https://cda-social.github.io/aquarium/models-gallery.html) · [原始淡水套件](https://cda-social.github.io/aquarium/kit/freshwater-fish-kit.zip)

介面字型 Noto Sans TC 取自 repo 內的 hero-horde-idle 原型，隨附 [SIL Open Font License](assets/OFL.txt)。

## 音訊與存檔

原創主曲以 68 BPM 合成為約 3 分 18 秒的和聲與旋律兩層，搭配循環水聲、落水、啄食與孵化短音。音量可分總音量、音樂、水聲與音效調整。原始合成腳本為 `tools/render_aquarium_audio.py`，使用 Python 與 libsndfile 輸出 Ogg/Vorbis。

養成存檔是 `user://aquarium_care.dat`，聲音設定是 `user://audio_settings.dat`。存檔使用 Godot Variant 和 godot-kit 的 `atomic_file.gd`，從共用 kit 同步。v4 存檔可讀入 v1 至 v3 的養成進度，並將早期固定裝飾位置轉換為缸底座標。養成規則在 `scripts/care_state.gd`，魚缸和 UI 操作在 `scripts/care.gd`。

## 驗證

```bash
godot --path prototypes/pixel-aquarium --headless --editor --import
godot --path prototypes/pixel-aquarium --headless --fixed-fps 60 --script res://tools/check_care.gd
godot --path prototypes/pixel-aquarium --headless --script res://tools/check_preview.gd
godot --path prototypes/pixel-aquarium --headless --fixed-fps 60 --script res://tools/check_cardinal.gd
godot --path prototypes/pixel-aquarium --headless --fixed-fps 60 --script res://tools/check_touch.gd
godot --path prototypes/pixel-aquarium --resolution 1920x1080 --script res://tools/check_preview.gd -- /tmp/pixel-aquarium-1080
godot --path prototypes/pixel-aquarium --fixed-fps 24 --quit-after 312 --write-movie /tmp/pixel-aquarium-m0.avi res://scenes/aquarium.tscn
```
