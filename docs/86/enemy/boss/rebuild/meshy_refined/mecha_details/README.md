# Boss 機甲線條調整稿

含骨架與待機、飛行、開火動畫的版本見 [animated/README.md](animated/README.md)；本頁保留靜態模型的資料。

以 `../boss_meshy_refined.blend` 為基礎，保留原本的流線輪廓，在前刃、環形外甲、側翼、中央砲座與雙尾加入直線導軌、裝甲接縫、橫向接合與結構肋。新增的 `Mecha_` 物件都是可編輯幾何；接縫與原有零件相交，並非布林切割後的單一水密網格。

- `boss_mecha.blend`：可編輯來源。
- `boss_mecha.glb`：靜態遊戲模型，內嵌貼圖。
- `boss_mecha_albedo.png`、`boss_mecha_orm.png`：額外保存的 2048² 色彩圖與 1024² ORM 圖。
- `mecha_three_quarter.png`、`mecha_top.png`、`mecha_side.png`、`mecha_front.png`、`mecha_underside.png`：重新匯入 GLB 後的預覽。

## 驗證（2026-11-14）

- Blender 來源：607 個網格零件、24,476 三角面。原有來源幾何檢查通過，開邊、非流形邊／頂點、退化面、翻面、檢查範圍內的單零件自相交均為 0；接觸／包容測試為 1 組，近共面候選為 0。
- Godot 4.7 匯入：24,476 三角面、31,344 GPU 頂點、1 網格／surface；尺寸、UV 範圍、索引、法線、退化面、材質與貼圖通道檢查通過。命令：`python3 validate_mecha.py`。
- 約寬 14.30 m × 長 39.99 m × 高 9.06 m。模型仍為靜態資產，沒有骨架、動畫、碰撞或遊戲場景接入；尚未在目標裝置和遊戲光照下驗收。詳細 UV 島重疊檢查未重跑。

## 重新匯出

在此資料夾使用 Blender 5.1；先儲存並備份人工修改。匯出會覆寫 GLB 和貼圖；渲染會清空執行時場景，應在獨立行程執行。

```text
blender --background boss_mecha.blend --python-exit-code 1 --python ../../../audit_boss_source.py
blender --background boss_mecha.blend --python-exit-code 1 --python export_mecha.py -- --overwrite
blender --background --python-exit-code 1 --python render_mecha.py
python3 validate_mecha.py
```

`add_mecha_details.py` 從上一版重新建立本稿，預設拒絕覆寫；加上 `--overwrite` 會丟棄本稿的人工編輯。一般編輯請直接修改 `.blend`，再重新匯出。
