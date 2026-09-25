# 底部對話層 UI 與素材試版

更新：2026-09-25。這是 [UI 備忘](../TODO.md)第一項的 Web 畫面試版；真人手機試玩後再決定版面細節。轉場 shader 仍是另一項探索。

## 目前畫面

對話層貼齊左右與底邊，底色不透明度為 0.62，沒有四邊框線。台詞和說話者名稱以細暗色字緣維持可讀性；按鈕、選項、HUD 與存讀檔卡片以底色區分狀態，常態框線已移除。沒有素材的角色佔位圖縮短至對話層上緣附近，輪廓線也變淡。

| 畫面 | 目前 Web 截圖 | 素材與觀察 |
| --- | --- | --- |
| 390×844 標題 | [店面背景](preview-assets-title-phone.png) | `yorozuya-background.png` 以維持比例的 cover 方式填滿。 |
| 390×844 對話 | [室內、銀時剪影](preview-assets-dialogue-phone.png) | `yorozuya-inside.png` 是客廳背景；`gintoki.png` 保留透明邊緣，以深藍灰 shader 顯示剪影。 |
| 390×844 裝傻發言 | [HUD、台詞與剪影](preview-assets-phase3-boke-phone.png) | 可檢查照片下的字色、透明對話層及操作區。 |
| 320×568 吐槽選詞 | [窄版四選項](preview-assets-phase3-tsukkomi-narrow.png) | 四個選項仍在對話層上方，懸浮鈕沒有蓋住選項。 |

兩張照片原始尺寸都是 547×365，直式手機 cover 會裁去左右區域；目前中央的店面招牌、客廳窗景與櫃台可辨認。廚房仍用漸層，因為這批沒有對應照片。素材來源是專案內使用者新增的圖片，原檔未修改。

## 前一版對照

| 畫面 | 原版 | 前一版試作 |
| --- | --- | --- |
| 390×844 對話 | [原版](preview-phone.png) | [半透明層與上緣線](preview-dialogue-trial-phone.png) |
| 390×844 裝傻發言 | [原版](preview-phase3-boke-phone.png) | [前一版](preview-phase3-boke-trial-phone.png) |
| 320×568 吐槽選詞 | [原版](preview-phase3-tsukkomi-narrow.png) | [前一版](preview-phase3-tsukkomi-trial-narrow.png) |

目前版本進一步降低對話層不透明度，移除上緣線與其他元件的明顯框線，並放入三張新素材。Web 自動檢查：[主線桌機／手機報告](ui-assets-main-report.json)、[Phase 3 觸控報告](ui-assets-phase3-report.json)、[存讀檔觸控報告](ui-assets-slots-report.json)均通過。Chromium 觸控模擬不能代替 Android Chrome 與 iOS Safari 實機閱讀和操作驗收。
