# godot-assets 進度

## 2026-11-28｜master｜素材庫擴充

- **已完成**。收錄 Kenney Fantasy UI Borders、Pattern Pack、Pattern Pack Pixel 與 Development Essentials，保留檔名、圖集、預覽與包內授權。索引補上 3D 素材目錄、Bfxr 與 Polyfork 的取用方式。 [共用素材索引](README.md)
- **驗證**。讀取四個新素材包的 `License.txt`，均含 CC0。奇幻花邊框與漸層已在配套的 Godot UI 場景匯入並通過功能測試。
- **下一步**。各原型採用時，複製實際用到的檔案及授權，再用目標遊戲的 Theme 比對桌機與手機效果。使用者未另排延期項目。
- **交接**。此次素材都在 `kenney/`，提交識別碼用 `git log -1 -- prototypes/godot-assets` 查閱。各包的版本、來源和適用場景列於 README。

## 2026-11-23｜master｜分類提交

- feat(godot-assets): add shared UI asset library
- 本次整理未重跑遊戲測試；既有驗證與待辦以 README、先前進度及測試檔為準。未 push。
- 下一步：依原專案進度進行人工驗收與後續工作。
