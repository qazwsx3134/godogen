# 切片素材來源

本輪沒有生成 AI 圖片，也沒有將參考遊戲截圖當作遊戲素材。

| 本案檔案 | Repo 來源 | 使用方式 |
|---|---|---|
| `sprites/meadow_slime.png`、`briar_boar.png`、`ruin_hound.png` | `prototypes/skybound-blades` 的既有角色動作圖 | 內部切片暫用、五欄動作與色調區分，六種夢靈共用三套圖 |
| `backgrounds/sky.png`、`far.png`、`mid.png`、`ground.png` | `prototypes/erwin-run` 的既有背景層 | 內部切片暫用、UV 視差 |
| `fonts/NotoSansTC.otf` | `prototypes/taskbar-hero/fonts/NotoSansCJKtc-Medium.otf` | kit subset_font.py 字集裁切；授權見 Noto-LICENSE、來源見 Noto-SOURCE.md |
| `fonts/Cubic11.ttf` | Repo 既有 Cubic11 字型 | 早期備選保留，主題使用 Noto；授權見 Cubic_11-LICENSE.md |

上述圖片沿用 repo 內部素材，未在本輪重新確認外部發行授權；正式美術與發行素材清單仍待整理。UI 由可編輯 Godot node、Theme 與 StyleBox 組成；音效以 kit SfxBank 合成，沒有外部音樂檔。
