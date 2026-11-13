# Phido 低面數重建：細化版

根據原模型的正面、側面與俯視輪廓，延續 [2,904 面版本](../lowpoly/README.md)細化側面裝甲框線、正面接縫與固定片、凹槽角落，以及腳底的錐形輪廓。兩個版本各自保留；網格由零件重新建立，沒有沿用原模型的減面網格。

| | 原始模型 | 先前重建 | 細化版 |
|---|---:|---:|---:|
| 三角面 | 930,148 | 2,904 | 2,940 |
| GLB | 39,075,460 bytes | 169,152 bytes | 169,368 bytes |

[外形對照](comparison.png)：每列左邊是原始模型、右邊是細化版；由上到下為正面、側面與斜前。[細化版斜後視圖](view_back_quarter.png)。本版仍是近似的低面數造型，原始刮痕、磨損、法線貼圖與細緻機械構造未完整重現。

## 檔案與編輯

- `phido_lowpoly.glb`：2,940 三角面、單一 mesh／surface 與材質，嵌入 128 × 128 色盤；地面原點，正面朝 Godot +Z。尺寸約 1.264 × 1.175 × 1.700 m（寬 × 高 × 長）。
- `phido_lowpoly.blend`：85 個可編輯網格物件、四個 `Leg_*` 腳部樞紐及打包色盤。沒有骨架動畫；樞紐可用來擺腳部姿勢。
- `phido_palette.png`：色盤外部副本；修改後需在 Blender 中重新載入及打包。
- `export_phido.py`：從保存的來源複製、合併並匯出 GLB，不儲存 blend。要求零件都在 `Phido` 物件樹內、共用一個材質，且總數 2,000–3,000 面。
- `build_phido.py`：只供重新建立初版幾何。以 `--overwrite` 執行會覆寫 blend、GLB 和色盤，先保留人工修改。

在 Blender 5.1 儲存來源後，可以執行以下指令重新匯出：

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
MODEL="$(wslpath -w docs/86/phido/lowpoly_v2/phido_lowpoly.blend)"
SCRIPT="$(wslpath -w docs/86/phido/lowpoly_v2/export_phido.py)"
"$B" -b "$MODEL" --python "$SCRIPT" -- --overwrite
```

## 驗證

2026-11-14，Blender 重新匯入 GLB 並渲染六視角；另開保存的 blend 複本，確認 85 個網格、四個腳部樞紐、已打包色盤，並測試重新匯出為 2,940 面、單一 surface。

`python3 docs/86/phido/lowpoly_v2/validate.py`：Godot 4.7 匯入通過，2,940 三角面、4,682 GPU 頂點、單一 surface，色盤材質與 UV 存在，0 個退化三角形；原點與尺寸通過檢查。沙箱中的 Godot editor 無法開啟偵錯監聽埠而顯示 socket 權限錯誤，匯入和驗證退出碼均為 0。尚未接入遊戲、製作骨架動畫或測手機效能。
