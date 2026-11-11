# godot-kit 待辦

詳細紀錄在 [PROGRESS.md](PROGRESS.md)。

## 檢視結果（2026-11-11，靜態閱讀，未實作、未跑測試）

每一項的實作方式與驗證方法見 [docs/CODE-IMPROVEMENTS.md](docs/CODE-IMPROVEMENTS.md)。建議順序：K1 → K3 → K2；K4 等 walker-tps 的 A1 做完；K5–K7 改到相關模組時順手做。

- [ ] **K1 補跑 11-06 重構後的測試：** `weighted_choice` 與四個消費模組、`camera_shake`、`scene_loader`、`music`、`save_slots` 改完都沒跑 Godot 測試。
- [ ] **K2 同步只複製用到的模組：** 每個原型帶 13 MB 完整副本；walker-tps 只引用 `scene_builder`、`test_kit`、`screenshot`、`synth`，debt-commission 只引用 `atomic_file`、`synth`、`haptics`。讓 `sync.sh` 接受模組清單，或預設不複製 `vfx/`。
- [ ] **K3 副本漂移：** walker-tps 有 41 個檔、debt-commission 有 13 個檔與 kit 不同；跑 `sync.sh --check` 分類。
- [ ] **K4 沒有任何 AI／戰鬥基礎模組：** 55 支腳本裡沒有狀態機、感知、攔截瞄準、血量元件。等 walker-tps 的 scout AI 改寫完（它的 TODO A1–A8），再把其中純計算的部分抽進來，先抽「攔截點求解」（純數學、好測）。沒有第二個使用者之前不抽狀態機。
- [ ] **K5 帶遊戲規則的模組：** `pet_care`、`gacha`、`march_strip`、`chest_shop` 等沒有第二個使用者的，不再擴充。
- [ ] **K6 API 以 Dictionary 傳參數**（例如 `auto_caster.learn(spell: Dictionary)`）：鍵名打錯不會報錯。新模組或改到時，在入口檢查未知鍵。
- [ ] **K7 文件：** README 786 行；研究文件與未實作的草案留在 `docs/` 並標明未實作。
