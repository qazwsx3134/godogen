# 遊戲音效：可提交版本

`runtime/` 是遊戲實際引用的 21 個單聲道、44.1 kHz Vorbis 音效，合計 **303,043 bytes（約 303 KB）**；17 個原始音檔合計 10,763,539 bytes，音檔體積減少約 97.18%。這是音檔本體比較，不含 `.import`、文件或 Godot 的執行期解碼記憶體。

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
| 主角主砲 | `cannon_shot`（`gun-shot-real.mp3` 前 1.3 秒） | 每發一聲，保持原音：音高 0.97–1.03、音量 +3 dB ±1.5，最多 4 聲部重疊 |
| 彈殼落地 | `shell_drop`（`gun-shot-ching.mp3`） | 彈殼每次彈跳（>2.5 m/s）一聲，音量依落地速度，音高 0.9–1.25 |
| 主砲彈命中 | `round_impact`（`impact-explosion-grenade.v5.mp3` 前 1.6 秒） | 主角子彈打到任何東西都播（取代悶響／叮聲；敵方子彈仍是悶響／叮聲），音高 0.8–1.2，9 m 內全音量、之後依距離衰減到 110 m |
| 子彈擦身而過 | `bullet_whiz`（`whiz.mp3` 前 1 秒） | 只有敵方子彈從主角 5 m 內飛過、沒打中時，在通過最近點後播；音高 1.6–1.9，-8 dB。主角自己的子彈不播 |
| 敵方腳步 | `enemy_step` | 雪地踩踏聲：Boss 音高 0.5–0.6、scout 1.35–1.6，各自依走路動畫每循環兩下 |
| Boss 說話 | `boss_talk` | 開戰第一次啟動時、之後出招時（至少間隔 6 秒） |
| Boss 生氣 | `boss_angry` | 進入第二型態與死亡表演開始時（低音高） |
| 備用參考 | `mech_walk_sequence` | 完整走路錄音，已壓縮；不自動疊在 IK 步態上造成雙重腳步 |

`default_bus_layout.tres` 為可編輯混音：Master -3 dB，Movement -7、Weapons -3、Impacts -2、Voice -3 dB，Master 有 limiter。所有 3D 腳步、機械、機槍、命中與爆炸都有距離衰減；通訊為 2D 聲音。主砲用使用者提供的 `gun-shot.mp3`；揮刀聲仍使用既有 Synth。

## 重建與驗證

需要可編碼 libvorbis 的 FFmpeg，處理腳本本身只用 Python 標準庫（WSL 沒有 FFmpeg 時，`python3 pip.pyz install --target <dir> imageio-ffmpeg` 附的執行檔有 libvorbis）。注意：重跑會用當下的 FFmpeg 重新編碼全部檔案，版本不同時舊檔的位元組也會變；只加新檔時，可只把新紀錄併進 manifest，保留舊檔：

```bash
python3 tools/process_audio.py --ffmpeg /path/to/ffmpeg
python3 tools/verify_audio.py
godot --headless --path . --editor --quit
godot --headless --fixed-fps 60 --path . --script res://tests/test_audio.gd
```

可選擇用 `FFMPEG_BIN` 指定工具；沒有 FFmpeg 時，`verify_audio.py` 仍能檢查 Ogg/Vorbis 標頭、時長、SHA-256、Git 忽略規則與來源未變更。缺少本機原始錄音的乾淨 checkout 可以正常執行遊戲和驗證輸出；重建音檔需另行取得原始素材。

`tools/apply_audio.gd` 已執行，使用 Godot 保存節點、音量、路由與場景引用，正常啟動不會重建場景。重跑會更新此批音效節點設定，先保留人工調整；已有的混音資源不會被重設。

處理報告量的是 sample peak 與 RMS，不宣稱為 LUFS 或 true-peak 檢測。自動解碼／匯入／事件驗證不能代替耳機、喇叭及手機的實聽；最終混音仍可依作者聽感調整。
