# Phido：低面數重新建模

參考 `D:\repo\godot\model-assets\phido\base_basic_pbr.glb` 的多視角輪廓，重新建立箱體、前方凹槽、側面裝甲、紅色感測器、藍色旋轉座、底盤和四隻腳。新網格由幾何零件建成，沒有使用原模型的減面網格。

| | 原始模型 | 重新建模 |
|---|---:|---:|
| 三角面 | 930,148 | 2,904 |
| GLB 大小 | 39,075,460 bytes | 169,152 bytes |
| 貼圖 | 3 張 2048 × 2048 | 1 張 128 × 128 色盤 |
| 尺寸：寬 × 高 × 長 | 1.277 × 1.162 × 1.725 m | 1.264 × 1.175 × 1.692 m |

[正面／側面／斜前對照](comparison.png)：每列左邊原始、右邊重新建模；也可分別看[斜前](view_three_quarter.png)與[斜後](view_back_quarter.png)。重新建模版的輪廓與主要零件依參考重做，表面刮痕、磨損、原始法線貼圖和精細機械細節沒有重現；它使用近似配色及共用的粗糙度／金屬度。

## 檔案

- `phido_lowpoly.glb`：單一 mesh／surface、單一 PBR 材質，嵌入色盤；地面為原點，正面朝 Godot +Z。沒有骨架、動畫或碰撞。
- `phido_lowpoly.blend`：可編輯來源，78 個網格零件與四個 `Leg_*` 腳部樞紐；材質和色盤已打包。調整腳部樞紐可擺放腳的姿勢，並不等於已完成骨架動畫。
- `phido_palette.png`：同一張色盤的外部副本，供重新著色；修改時要同步更新 Blender 內打包的影像。
- `export_phido.py`：從保存的 blend 複製並合併零件，重新輸出單一 mesh，不會儲存修改 blend。
- `build_phido.py`：從程式建立初始模型的製作工具；不是正常執行或匯入的依賴。

## 編輯後重新匯出

Blender 5.1 開啟並儲存 blend，之後執行：

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
MODEL="$(wslpath -w docs/86/phido/lowpoly/phido_lowpoly.blend)"
SCRIPT="$(wslpath -w docs/86/phido/lowpoly/export_phido.py)"
"$B" -b "$MODEL" --python "$SCRIPT" -- --overwrite
```

`--overwrite` 會覆寫同資料夾的 GLB；匯出工具要求全部零件屬於 `Phido` 物件樹、共用一個材質，且總數為 2,000–3,000 三角面。`build_phido.py` 若加 `--overwrite` 則會重新建模並覆寫 blend、GLB 和色盤，**會失去對來源檔的手動編輯**；重建前先保留修改。

## 驗證

2026-11-13：Blender 重新開啟保存的 blend，確認 78 個網格、四個腳部樞紐及已打包色盤；從 blend 的複本測試 `export_phido.py`，輸出 2,904 三角面、單一 surface。重新匯入 GLB 渲染六視角，檢查主要比例與腳部接合。

`python3 docs/86/phido/lowpoly/validate.py`：Godot 4.7 匯入通過，2,904 三角面、4,682 GPU 頂點、單一 surface、色盤材質與 UV 存在、0 退化三角形、原點和尺寸在檢查範圍內。沙箱中的 Godot editor 因無法開啟偵錯監聽埠顯示 socket 權限錯誤；匯入和驗證退出碼均為 0。尚未接入遊戲、測手機效能或製作動畫。
