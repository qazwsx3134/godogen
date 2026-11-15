# Meshy 截圖參考調整稿

加入直線裝甲與機械結構的後續版本見 [mecha_details/README.md](mecha_details/README.md)；本頁保留截圖參考調整稿的資料。

以 `../boss_v2.blend` 為基礎，參照 `../meshy_reference_20261114/` 中的五張截圖，另存可編輯的調整稿。沿用約 40 m 的尺寸與原有分件：加粗前方槍刃、增加重疊側甲與亮銀藍材質、將雙尾矩形片改為尖角鱗片與鋸齒，並增加頂部和底部的放射狀渦輪。

這是依截圖重建的近似稿，不是 Meshy 模型本身。外殼、尾節與機械細節仍比截圖規整、簡化，金屬反光也會隨環境光而改變；尚未經使用者美術驗收。

## 檔案

- `boss_meshy_refined.blend`：可編輯來源，保留機身、砲座、雙尾和外圈尖刺的原分件；新增部件以 `Meshy_` 開頭。
- `boss_meshy_refined.glb`：遊戲用靜態模型；色彩與粗糙度／金屬度貼圖已內嵌。
- `boss_meshy_refined_albedo.png`、`boss_meshy_refined_orm.png`：額外保存的 2048² 色彩圖與 1024² ORM 圖。
- `refined_three_quarter.png`、`refined_top.png`、`refined_side.png`、`refined_front.png`、`refined_underside.png`：**重新匯入 GLB** 後的檢視圖。
- `refine_boss.py` 是這次從 v2 建立調整稿的工具；`export_refined.py`、`render_refined.py` 和 `validate_refined.py` 分別用來重新匯出、渲染及驗證。

## 驗證（2026-11-14）

| 項目 | 結果 |
|---|---|
| 來源幾何 | 501 個網格零件、23,204 三角面；檢查範圍內的開邊、非流形邊／頂點、退化面、翻面和單零件自相交皆為 0 |
| 零件接合 | BVH 接觸／相交及包容測試為 1 組，涵蓋 501 個零件；近共面候選為 0。零件沒有焊接成單一水密實體 |
| 尺寸 | 約寬 14.30 m × 長 39.99 m × 高 9.06 m；最低處約距地 5.4 cm |
| Godot 4.7 GLB 匯入 | 23,204 三角面、28,859 GPU 頂點、1 個網格／surface；尺寸、UV 範圍、索引、法線、退化面及貼圖／材質通道檢查通過 |
| 外觀 | 五張預覽均由匯出的 GLB 重新匯入 Blender 渲染；尚未在遊戲場景、手機或真實光照條件下驗收 |

Meshy 畫面顯示其模型為 15,195 面；這份重建稿是 **23,204 面**，並非相同的網格或面數。它是靜態資產，尚無骨架、動畫、碰撞或遊戲場景接入。Godot 檢查確認 UV 位於圖集範圍內；詳細 UV 島重疊檢查因 Blender 連線中斷未完成。

## 重新匯出

在本資料夾執行，`blender` 指 Blender 5.1。先儲存並備份人工修改；匯出會覆寫 GLB 和兩張貼圖。渲染腳本會清空執行時場景，應在獨立 Blender 行程執行。

```text
blender --background boss_meshy_refined.blend --python-exit-code 1 --python ../../audit_boss_source.py
blender --background boss_meshy_refined.blend --python-exit-code 1 --python export_refined.py -- --overwrite
blender --background --python-exit-code 1 --python render_refined.py
python3 validate_refined.py
```

`refine_boss.py` 會從原 v2 重新建立調整稿，預設拒絕覆寫；傳入 `--overwrite` 會丟棄對調整稿所做的人工編輯。一般修改請直接編輯 `.blend`，再使用匯出工具。
