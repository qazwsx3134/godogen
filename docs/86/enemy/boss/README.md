# Boss 敵機：40 m 低面數模型初版

> 使用者認為此版與參考圖差異過大；後續依槍管、身軀、腳刺和尾巴重做的[分部位重建稿](rebuild/README.md)另存於 `rebuild/`。以下保留初版資料供對照。

依 `boss-threeview.png` 和 `../../boss.jpg` 建立，保留環形砲座、前槍、兩條分節長尾、側翼裝甲和下緣尖刺，供遠距戰鬥視角使用。這是簡化造型：圖中的側面帶透視，與正／背視投影也不完全一致，俯視輪廓、厚度、尾部升角及部分裝甲由這些參考推定，並非逐細節重建。

| 項目 | 目前交付 |
|---|---|
| 尺寸（寬 × 長 × 高） | 約 15.03 × 40.01 × 8.28 m，包含槍尖、尾端及外緣刺 |
| 原點與朝向 | 原點在地面、最低點約高 3.4 cm；Blender 機頭 -Y，Godot 機頭 +Z |
| 模型 | 7,328 三角面；Godot 匯入後 12,340 個頂點，1 個網格、1 個 surface |
| 材質 | 1 組 PBR；1024² 色彩與 512² 粗糙度／金屬度圖集，內嵌於 GLB |
| 模型結構 | Blender 來源 276 個封閉零件，有相交或接觸；不是焊接成單一封閉實體 |
| 目前範圍 | 靜態模型；未綁骨架、動畫、碰撞或接入遊戲 |

## 檔案

- `boss.blend`：可編輯來源。`Boss_40m` 下分成 `Body`、`Rim_Spikes`、`Crown_And_Cannon`、`Forward_Spear` 和 `Tail_L/R`；尾部的空物件提供編輯用旋轉基點，並非遊戲動畫骨架。
- `boss.glb`：遊戲用靜態模型，含烘焙貼圖；一般匯入不需要額外複製 PNG。
- `boss_albedo.png`、`boss_orm.png`：匯出時生成的色彩與資料圖集；ORM 的綠色是粗糙度、藍色是金屬度。
- `preview_front.png`、`preview_rear.png`、`preview_side.png`、`preview_three_quarter.png`：將**匯出的 GLB 重新匯入 Blender**後渲染的檢視圖。
- `MODEL_AUDIT.md`：完整流程、量測結果、限制與後續優化建議。

## 編輯、重烘焙與檢查

在 Blender 5.1 中開啟 `boss.blend`、編輯並存檔。以下命令在本資料夾執行；`blender` 指向 Blender 5.1 的執行檔。建議先備份來源與輸出。

```text
blender --background boss.blend --python-exit-code 1 --python audit_boss_source.py
blender --background boss.blend --python-exit-code 1 --python export_boss.py -- --overwrite
blender --background --python-exit-code 1 --python audit_boss_uv.py
python3 validate_boss.py
blender --background --python-exit-code 1 --python render_boss.py
```

`export_boss.py` 在獨立 Blender 行程中複製可編輯零件，重新展 UV、烘焙並覆寫 GLB 和兩張 PNG；不儲存來源 `.blend`。它採用來源 Principled BSDF 的金屬度與粗糙度數值；若這兩項改用連結貼圖，須先擴充匯出器，避免錯誤烘焙。`render_boss.py` 會清空目前場景並覆寫四張預覽，因此只在獨立行程執行。`validate_boss.py` 在臨時 Godot 4.7 專案中執行匯入與測試。

`build_boss.py` 是最初的程序化建模工具，會清空執行時場景；重新建模會丟失人工修改。它預設拒絕覆寫現有檔案，只有明確指定 `--save-source --overwrite` 才會重建來源；一般調整請直接編輯 `.blend` 並使用上述匯出流程。
