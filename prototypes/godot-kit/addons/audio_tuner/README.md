# Audio Tuner

Godot 4.x 編輯器的音效列表、試聽與混音設定。已在 Godot 4.7 驗證。

## 安裝與試聽

1. 把整個 `audio_tuner` 目錄複製到專案的 `addons/`。
2. 在 **Project Settings → Plugins** 啟用 **Audio Tuner**，再開編輯器底部的 **Audio Tuner** 面板。
3. 清單預設列出場景、資源和腳本中以 `res://` 路徑引用的 WAV、OGG、MP3。用檔名篩選，滑鼠停在項目上可看引用位置。勾 **Include unreferenced** 也會列出未找到引用的已匯入音檔。
4. 選擇音效後調 **Pitch ×**、**Gain dB**，用 **Play / Stop** 試聽。調整後會自動寫入 `res://audio_mix.cfg`，**Apply to game** 立即提交，**Reset clip** 將該音效恢復到 ×1、0 dB。

試聽從音檔本身的音高和音量開始。遊戲中的混音會將設定乘到原有音高、加到原有分貝。從編輯器執行的遊戲會重新讀取已套用的設定，下一次播放該音效時生效。匯出成品啟動時載入隨附的設定。程式即時合成且沒有音檔路徑的聲音無法在清單中按檔案調整。

## 接到遊戲播放

試聽與編輯不需要遊戲程式配合。要讓儲存的設定套到遊戲內，將對應的 2D、3D 或通用播放器呼叫改成：

```gdscript
const AudioMix := preload("res://addons/audio_tuner/mix.gd")

func play_shot() -> void:
    AudioMix.play($ShotSound)

func play_varied_shot() -> void:
    AudioMix.play($ShotSound, randf_range(0.96, 1.04), 3.0)
```

第一種沿用播放器的初始音高與音量。第二種由呼叫端明確提供每次播放的基礎音高、分貝。以程式換 `stream` 的播放器先指定音檔再呼叫。自動播放的音效要改用上述呼叫才會經過混音。匯出時，請在 Export Preset → Resources 的非資源檔案包含篩選填入 `audio_mix.cfg`。既有的 `audio_mix.tres` 可供載入舊設定，下一次 Apply 會把設定寫入 `audio_mix.cfg`。執行遊戲與匯出成品都不需要啟用編輯器插件。
