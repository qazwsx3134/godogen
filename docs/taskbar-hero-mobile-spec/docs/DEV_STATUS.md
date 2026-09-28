# Development Status

## 目前版本：成長與逐波戰鬥

專案：[Taskbar Hero](../../../prototypes/taskbar-hero/README.md)。以最新 [成長／波次契約](18_progression_wave_contract.md) 為準，原 Checkpoint A 的雙單位戰鬥與 v1 限制已由本輪實作取代。

- 七個可編輯頁面、六格底部導覽；預設總覽，怪獸按鈕進詳情，新增裝備頁。
- 六個展開面板共用高度，背包篩選後緊密重排。
- 訓練付金幣立即加一級，只影響主角；新遊戲訓練為四項 Lv.1。
- 四種怪獸可同時出陣，靠自己的 EXP 及裝備成長。檢視怪獸不改變出陣名單。
- 主角／怪獸各六個裝備欄，穿戴、卸下、移交與付費強化可實際操作。
- 每波三名敵人、每關三波，清波後快速行軍並以遠慢近快的視差背景前進；第二波為士兵。
- v2 保存訓練、怪獸 EXP、名單與裝備；v1 遷移保留舊經濟與關卡，損壞／新版存檔保護仍在。
- Noto Sans CJK TC 現成字型已加入。沿用 godot-kit 原子存檔與測試模組，沒有額外商店套件需求。

## 驗證入口

執行 `bash prototypes/taskbar-hero/tools/check.sh`：九組測試各用獨立存檔目錄，除了退出碼也檢查 Godot SCRIPT ERROR 與 PASSED。涵蓋成長、遷移／回復、真實 UI 點擊、戰鬥、波次、600 秒模擬及 scene 編輯持久性。

[本輪畫面對照](../../../prototypes/taskbar-hero/docs/progression-review/index.html) 包含七頁三種尺寸、戰鬥／行軍／下一波狀態。歷史六頁驗收保留在 `docs/reference-ui/`，不是目前版本的測試結果。

## 尚未完成

逐像素 1:1 與完整 MVP 尚未完成。角色／背景仍使用原圖區域作為暫用素材，背景補片及循環接縫可見，沒有完整角色動畫與音訊。使用者選擇稍後自行製作，現有 [opt image 提示詞](../art-prompts/README.md) 可供使用；本輪未呼叫 AI 生圖。

完整章節內容、Boss、寶箱、離線收益、Cube／Rune、付款／廣告 SDK，以及 Android／iOS 實機 Safe Area、效能與耗電尚未驗證。每關波次重新開啟從第一波開始，已推進的關卡由存檔保留。
