# godot-ui 進度

## 2026-11-28｜master｜奇幻介面主題

- **已完成**。加入可編輯的奇幻主題、任務面板、背包格、發現橫幅與主選單。按鈕沿用既有點按動畫，道具格用共用的 `ButtonGroup` 維持單選。場景、Theme、製作工具和測試都收錄在本次提交。 [元件與使用方式](README.md)
- **驗證**。Godot 4.7 的 `godot --headless --editor --import` 成功，`godot --headless --script tests/test_fantasy.gd` 通過，涵蓋預設選取、互斥、按鈕樣式、陰影與接受任務。
- **已知的舊測試問題**。舊展示的 `tests/test_ui.gd` 有時在起始透明斷言停止。以 `--fixed-fps 60` 重跑，提交前工作樹及基準 `ec42cee4` 的乾淨副本皆在第 32 行讀取空的 `last_sfx.stream` 時出錯。奇幻示範的人工畫面驗收仍待做。
- **下一步**。在實際遊戲畫面驗收桌機及手機版面，再依採用的 Theme 檢查文字、焦點和選取狀態。修正舊展示測試的動畫與音效時序另行追蹤。使用者未另排延期項目。
- **交接**。主要入口是 `scenes/fantasy_demo.tscn` 和 `scenes/fantasy_theme.tres`。素材與授權在 `assets/kenney/`，提交識別碼用 `git log -1 -- prototypes/godot-ui` 查閱。共用的單選陷阱已記在原型 LESSONS。

## 2026-11-23｜master｜分類提交

- feat(godot-ui): add reusable UI components
- 本次整理未重跑遊戲測試；既有驗證與待辦以 README、先前進度及測試檔為準。未 push。
- 下一步：依原專案進度進行人工驗收與後續工作。
