# 美術、音效與可替換規格

目前房間、角色與 UI 圖示皆為原創程式像素畫，不需要外部商用素材或下載才能遊玩。

| 資源 | 現有實作 | 替換規格 |
| --- | --- | --- |
| 房間 | `ui/pixel_room.gd` 的 `_room` | 144×88 PNG；nearest；背景、家具、角色可拆層 |
| 新手蛋 | `_draw_egg` | 32×32；idle / wobble / crack / glow / hatch 各 4 格 |
| 幼年／成長／3 成熟體 | `_creature` | 每格 64×64、腳底對齊 (32,56)，透明背景 |
| 角色動畫 | 待機、走動、吃、開心、訓練、攻擊、受擊、睡眠、生病、受傷、勝利、失敗、進化 | 13 列 × 4 格；256×832 sprite sheet；6–8 fps，技能及進化不循環 |
| 功能圖示 | `ui/pixel_icon.gd` | 每格 24×24、共 8 格；192×24 sheet |
| 音效 | `ui/sound.gd`：22,050Hz 單聲道短音合成 | WAV 16-bit mono；餵食／清潔／訓練／療護／勝敗／破殼／進化各自命名 |
| 背景音樂 | 原創 8 音柔和循環 | 低干擾 loop；單獨音量控制 |
| 字型 | Noto Sans TC variable | `assets/fonts/OFL.txt`；SIL Open Font License |

檔名使用 `pet_<species>_<animation>.png`，species 為 sprout / bloom / ember / moss / breeze。影格原點與列次序固定後，可用 SpriteFrames 替換繪圖函式，不需要改養成資料。

像素房間使用 144×88 SubViewport，以可容納的整數螢幕倍率放大；UI 文字與觸控區域另用 Control / Container 佈局。主操作約 102×82 設計單位，面板按鈕最小高度 60；小螢幕使用垂直捲動保持入口可達。安全區會依 iOS 回報值轉換為邏輯尺寸。

來源：[Noto Sans TC](https://github.com/google/fonts/tree/main/ofl/notosanstc)。除字型外無第三方音樂或角色素材。
