# 遊戲音效：可提交版本

`runtime/` 是遊戲實際引用的 14 個單聲道、44.1 kHz Vorbis 音效，合計 **200,988 bytes（約 201 KB）**；9 個原始音檔合計 10,104,955 bytes，音檔體積減少約 98.01%。這是音檔本體比較，不含 `.import`、文件或 Godot 的執行期解碼記憶體。

原始錄音留在原目錄，沒有覆寫或刪除；各來源目錄有 `.gdignore`，避免重複匯入／打包；本目錄 `.gitignore` 只排除來源音檔及其舊 `.import`。提交 `runtime/*.ogg`、它們的 `.ogg.import`、manifest、署名、忽略規則與處理工具即可，不需要 Git LFS。來源與授權見 [CREDITS](CREDITS.md)，原始包的 License.txt／info.txt 保留。

## 事件與混音

| 事件 | 音檔 | 行為 |
|---|---|---|
| 出擊啟動 | `ai_boot` | 一次播放 |
| scout 發現玩家／通訊 | `ai_radio` | 同時只播一段，全局至少 6 秒間隔，scout 自身亦有頻率限制 |
| scout 機槍 | `scout_gun_a/b/c` | 輪替單發短素材，最多 2 聲部；`scout_gun_burst` 保留供後續點射使用 |
| 命中／刀片命中 | `hit_heavy` | 3D 位置音效，光效結束後允許音效尾段播完 |
| scout 擊毀 | `explosion` | 爆炸尾段約 1.57 秒，最後一台擊毀也不被結算清掉 |
| 足部落腳 | `mech_contact`、`mech_step_a/b` | 交替播放，70 ms 內同時落腳合併觸發，最多 3 聲部 |
| 開始移動 | `mech_servo` | 移動起始機械聲；不把整段錄音錯當循環 |
| 跳躍落地 | `mech_land` | 使用者提供的落地聲 |
| 備用參考 | `mech_walk_sequence` | 完整走路錄音，已壓縮；不自動疊在 IK 步態上造成雙重腳步 |

`default_bus_layout.tres` 為可編輯混音：Master -3 dB，Movement -7、Weapons -3、Impacts -2、Voice -3 dB，Master 有 limiter。所有 3D 腳步、機械、機槍、命中與爆炸都有距離衰減；通訊為 2D 聲音。主砲的低頻發射聲與揮刀聲仍使用既有 Synth，沒有把機槍片段冒充主砲素材。

## 重建與驗證

需要可編碼 libvorbis 的 FFmpeg，處理腳本本身只用 Python 標準庫：

```bash
python3 tools/process_audio.py --ffmpeg /path/to/ffmpeg
python3 tools/verify_audio.py
godot --headless --path . --editor --quit
godot --headless --fixed-fps 60 --path . --script res://tests/test_audio.gd
```

可選擇用 `FFMPEG_BIN` 指定工具；沒有 FFmpeg 時，`verify_audio.py` 仍能檢查 Ogg/Vorbis 標頭、時長、SHA-256、Git 忽略規則與來源未變更。缺少本機原始錄音的乾淨 checkout 可以正常執行遊戲和驗證輸出；重建音檔需另行取得原始素材。

`tools/apply_audio.gd` 已執行，使用 Godot 保存節點、音量、路由與場景引用，正常啟動不會重建場景。重跑會更新此批音效節點設定，先保留人工調整；已有的混音資源不會被重設。

處理報告量的是 sample peak 與 RMS，不宣稱為 LUFS 或 true-peak 檢測。自動解碼／匯入／事件驗證不能代替耳機、喇叭及手機的實聽；最終混音仍可依作者聽感調整。
