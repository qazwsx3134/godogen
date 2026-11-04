# 本機 3D 素材庫索引

素材來源：`D:\repo\godot\model-assets`，WSL 為 `/mnt/d/repo/godot/model-assets`。這份索引放在 repo 內，素材庫本身不會被修改。若兩個資料夾不再保持同一個父目錄，需指定新的素材庫位置重新產生。

- [開啟圖像索引](index.html)：可用中英文搜尋，依分類、素材包、城鎮候選、原始面數與相依檔狀態篩選；直接用瀏覽器開啟即可，不需要伺服器。
- [開啟模型清單 TSV](models.tsv)：可用試算表開啟，或用 `rg` 搜尋；模型與貼圖欄位是相對素材庫根目錄的路徑。
- 索引收錄 **17 個素材包、890 筆 3D 模型**；11 包包含 3D，另外包含 2D／介面與字型。GLB、FBX、OBJ 的同名版本合併為一筆。這是 2026-11-04 的掃描結果，增刪素材後請重新產生。

## 蓬蓬草原的第一批候選

| 素材包 | 方向與候選 | 原始 GLB 三角面 |
|---|---|---:|
| [Mini Forest](../../../model-assets/kenney_mini-forest_1.0/Overview.html) | `building-structure` 木架、`building-roof` 屋頂；可作小屋樣板的起點，但兩者本身不是完整封閉房屋 | 144、324 |
| Mini Forest | `fence` 短柵欄 | 330 |
| [Survival Kit](../../../model-assets/kenney_survival-kit/Overview.html) | `signpost-single` 路牌、`box` 木箱、`barrel` 木桶 | 28、124、412 |
| [Retro Fantasy Kit](../../../model-assets/kenney_retro-fantasy-kit/Overview.html) | `wall-pane-wood-door` 門牆與 `roof` 屋頂；原有像素紋理較深，需與選定風格比較 | 36、88 |
| [Castle Kit](../../../model-assets/kenney_castle-kit/Overview.html) | 牆、門、塔、樹和石頭；適合組合建築或村莊邊界 | 見索引 |

這些是來源模型的統計，包含 GLB 預設場景內的 mesh 實例；修改、倒角及組合後必須重新統計完整物件。`signpost.glb` 44、`building-roof.glb` 324、`wall-pane-wood-door.glb` 36 已另外由 Godot 4.7 的 GLTFDocument 載入並核對。尚未逐件檢驗造型、碰撞、重疊面、貼圖接縫或手機效能。

已由 Survival Kit 的 `signpost-single` 製作第一個[路牌技術樣板](../../prototypes/seal-meadow/design/pipeline/town-signpost-sample.md)：修整交疊與倒角後是 168 tris，Blender 來源及可編輯 Godot scene 均已保存；樣板已放入村莊入口。Castle Kit 的屋頂也用於 1,296 tris 的[商店樣板](../../prototypes/seal-meadow/design/quick-specs/town-slice-2026-11-05.md)。

## 取用與授權

17 個素材包的根目錄 `License.txt` 均列為 CC0。記錄實際使用的套件與來源，並保留授權檔；其他新加入的素材要逐包確認授權，不自動套用這個結論。

GLB 的縮圖卡片列出實際引用的外部圖片或 buffer。這批模型多數引用相對路徑，例如：

```text
signpost.glb
Textures/
└── colormap.png
```

複製 GLB 時要把相依檔一起複製並維持相對路徑，避免匯入後失去材質；不同素材包最好分資料夾，避免同名 `colormap.png` 互相覆蓋。索引只分析 GLB 的相依檔；FBX／OBJ 若另行取用，還要檢查各自材質與貼圖。原始模型與貼圖保留在素材庫，遊戲裡修改副本。

## 重新掃描

在 repo 根目錄執行：

```bash
python3 scripts/index_model_assets.py
python3 scripts/index_model_assets.py --check
```

預設讀取與 repo 同層的 `model-assets`，產生本資料夾的 `index.html` 與 `models.tsv`。若素材庫搬移，以 `--source <素材庫路徑>` 指定位置；`--output <目錄>` 可更改索引位置。輸出不可放進來源素材庫。`--check` 只檢查索引是否過期，不會寫入。

分類與「城鎮候選」是按套件和檔名推測，方便縮小搜尋範圍，不等於人工審核或正式美術定案。未支援讀取或無法解析的模型會保留在清單並標示；上架使用前仍須檢查來源、模型及其相依檔。
