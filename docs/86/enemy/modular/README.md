# 近戰／坦克敵機共用零件

`enemy_modular_kit.blend` 是可編輯的組裝稿：`Melee_Assembly` 和 `Tank_Assembly` 各有專屬機體與骨架，並連結同一組共用網格。兩台在檔案內左右分開，方便編輯。

```text
共同機身 + 8 條腿（各上段 / 下段）
                  │
          17 個共用網格資料
              ┌───┴───┐
          近戰機組裝   坦克機組裝
              ↓           ↓
         melee GLB     tank GLB
```

17 組網格的原始共同部分共 1,050 三角面，減面後為 886。兩種模型的相同部位原本有不同 UV 圖集：每份共用網格保留 `UV_Melee` 和 `UV_Tank`，兩側物件各自指定原本的材質。編輯共用的網格資料會影響兩台；物件位置、骨架及材質仍可各自調整。

| 版本 | 原始三角面 | 組裝後三角面 |
|---|---:|---:|
| melee | 1,458 | 1,294 |
| tank | 1,324 | 1,160 |

`melee_reassembled.glb` 和 `tank_reassembled.glb` 各為一個蒙皮 mesh／surface、19 根骨頭，分別保留 walk／idle／attack 和 walk／idle／fire。**GLB 沒有跨檔共用網格或貼圖**，所以這份模組化主要讓建模與維護共用；分成多個執行時物件也可能增加繪製次數。此輸出仍以單網格交給遊戲。模型檔案大小沒有明顯下降，因為主要是貼圖和動畫資料。

`scout` 的八足命名和架構相近，但實際座標、比例及幾何不同；它沒有直接替換成這組腿，也未改動 walker-tps 使用的原始 scout。

## 重新匯出

在 Blender 5.1 開啟已保存的 `enemy_modular_kit.blend`，手動執行 `export_assembled.py`。例如從 WSL 執行：

```bash
B="/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
KIT="$(wslpath -w docs/86/enemy/modular/enemy_modular_kit.blend)"
SCRIPT="$(wslpath -w docs/86/enemy/modular/export_assembled.py)"
"$B" -b "$KIT" --python "$SCRIPT" -- --overwrite
```

腳本會複製並合併零件、把顯示用的水平位移歸零、匯出各自 GLB，不儲存或修改 blend。`--overwrite` 會覆寫本資料夾的兩個組裝 GLB；正常開啟與匯入不會自動執行腳本。需要變更共用網格時先備份或查看 diff，並同時檢查兩種 UV、材質及動作。

## 驗證

2026-11-13：Blender 重新讀入保存後的 blend，確認 17 對物件分別連結同一 mesh、兩套 UV、兩個骨架與打包貼圖。Godot 4.7 的 `python3 docs/86/enemy/modular/validate.py` 驗兩個 GLB 的網格、貼圖座標、骨架、權重、循環／攻擊及中斷復位，並對原版和組裝版每段動作在 9 個時間點逐骨比較姿態，皆通過。匯入時沙箱禁止 Godot editor 的偵錯監聽埠，會列 socket 權限錯誤；匯入及驗證仍退出 0。兩台尚未接入 walker-tps，也未做手機實機效能或遊戲實玩。
