# UI 與轉場待試方向

- 2026-09-25：新增[三款 UI 改版方案](docs/UI-REDESIGN-OPTIONS.md)與[互動比較頁](docs/ui-options/index.html)：A 月下映畫、B 萬事屋委託簿、C 吐槽分鏡。可比較對話、四選項、選單與標題；待選定風格後套入 Godot。

- 重新設計對話框與常用元件。先試底部滿版、半透明對話層、上緣分隔線，再與目前畫面比較；參考：[圖一](example/image.jpg)、[圖二](example/螢幕擷取畫面%202026-09-24%20021146.jpg)、[圖三](example/螢幕擷取畫面%202026-09-24%20021221.jpg)。
- 試用 shader 做事件或場景轉換；ASCII 與駭客風格是候選方向，需先看可讀性與故事氣質。

第一項已有[底部對話層與素材 Web 試版比較](docs/UI-TRIAL.md)：目前畫面是全寬半透明、無邊框對話層，層內有說話者名稱與快捷列；其他按鈕描邊已淡化，並套入店面、室內與銀時剪影三張素材。是否採用這個版面，仍待 Android Chrome 與 iOS Safari 實機試玩。shader 轉場尚未試作；優先順序與驗收方式見[進度紀錄](../../docs/story-telling-game/STATUS.md)。
