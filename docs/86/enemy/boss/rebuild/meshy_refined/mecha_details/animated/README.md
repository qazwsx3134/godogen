# Boss 骨架與動畫

以機甲線條版為基礎，加入 11 根骨頭：`Hull`、`Cannon`、`CoreRotor`，以及左右各四節 `Tail_L_1`–`Tail_L_4`、`Tail_R_1`–`Tail_R_4`。尾部甲片跟隨各節骨頭，長尾核心及側邊導軌在相鄰骨頭間混合權重。

| 動作 | Godot 名稱 | 長度 | 內容 |
|---|---|---:|---|
| 待機 | `idle` | 3.0 秒，循環 | 懸浮、渦輪旋轉、雙尾輕擺 |
| 飛行 | `fly` | 1.8 秒，循環 | 懸浮與較明顯的雙尾擺動 |
| 開火 | `fire` | 1.2 秒，單次 | 主砲後座、機身反應與回復；約 0.33 秒到達最大後座 |

飛行是原地循環，實際位移由遊戲控制。開火是模型動作，光束、命中與傷害需由遊戲提供；GIF 為了方便檢視會重複播放，實際 `fire` 動畫不循環。

## 檔案

- `boss_animated.blend`：保留可編輯分件、骨架與三個 Action。開啟後預設選取 `Boss_Animated_Rig` 和 `idle-loop`；要修改其他動作，可在 Action Editor 選擇 `fly-loop` 或 `fire`。
- `boss_animated.glb`：單一蒙皮網格，內含骨架、三段動畫和貼圖，可匯入 Godot。
- `preview_idle.gif`、`preview_fly.gif`、`preview_fire.gif`：從匯出的 GLB 重新匯入 Blender 後渲染；開火使用近景。
- `boss_animated_albedo.png`、`boss_animated_orm.png`：額外保存的色彩與材質圖；GLB 已內嵌。

## 驗證（2026-11-15）

- Godot 4.7：24,476 三角面、31,344 GPU 頂點、1 個網格／surface、11 根骨頭；所有頂點權重正規化，長尾核心與側邊導軌有混合權重。
- 實際播放驗證兩條尾巴擺動、渦輪旋轉、主砲後座 0.8 m；待機／飛行循環首尾銜接，開火為單次播放，開火中斷切回待機時主砲復位。
- 動畫版與原靜態 GLB 以 0.00001 m 量化後比較 24,476 個三角面的靜止位置，沒有缺少或多出的三角面。
- 模型約長 40 m；尚未接入遊戲場景，也沒有碰撞、武器特效或實機效能驗收。動作仍需由使用者確認視覺效果。

驗證命令：`python3 validate_animation.py`。它在臨時 Godot 專案匯入 GLB，檢查骨架、蒙皮、動畫播放／切換、尺寸及材質。

## 修改與匯出

在此資料夾使用 Blender 5.1；先存檔並備份人工修改。匯出會覆寫 GLB 與貼圖，渲染會清空執行時場景，請使用獨立 Blender 行程。

```text
blender --background boss_animated.blend --python-exit-code 1 --python export_animated.py -- --overwrite
blender --background --python-exit-code 1 --python render_animation.py
python3 encode_preview.py
python3 validate_animation.py
```

預覽渲染預設輸出到 WSL 的 `/tmp/boss-animated-preview-20261115`，`render_animation.py -- --frames-dir <路徑>` 可指定其他目錄；編碼 GIF 需要 Pillow。`build_rig.py` 從上一版重新建立來源，預設拒絕覆寫；使用 `--overwrite` 會丟棄對動畫來源所做的人工編輯。
