# Taskbar-Hero-like Mobile Idle RPG — Project Specification

這個資料夾是給 **Codex / AI coding agent** 使用的專案規格集。

目標不是 1:1 複製《TBH: Task Bar Hero》，而是保留其核心優點：

- 低干擾、自動戰鬥
- 3 人隊伍與 Build 最佳化
- Loot / Chest / Equipment 成長
- Cube / Rune 類型的長線養成
- 短時間登入也能得到進展

同時針對手機平台重新設計：

- Portrait-first
- Offline progression 為核心，而非附屬功能
- 不依賴背景常駐執行
- 減少 Inventory management friction
- 避免純 RNG 導致長期零成長
- 不做交易市場 / Server Inventory / Anti-cheat
- Local-first save
- 以 Data Driven Godot 架構為主

---

## Codex 讀檔順序

請 Codex 按以下順序閱讀：

1. `AGENTS.md`
2. `docs/00_product_vision.md`
3. `docs/01_design_pillars.md`
4. `docs/02_mobile_game_loop.md`
5. `docs/03_systems_overview.md`
6. `docs/04_godot_architecture.md`
7. `docs/05_data_models.md`
8. `docs/06_combat_system.md`
9. `docs/07_loot_equipment_economy.md`
10. `docs/08_offline_progression.md`
11. `docs/09_ui_ux.md`
12. `docs/10_save_and_persistence.md`
13. `docs/11_mvp_scope.md`
14. `docs/12_roadmap.md`
15. `docs/13_acceptance_criteria.md`
16. `docs/14_codex_execution_plan.md`
17. `docs/15_review_driven_changes.md`
18. `docs/16_implementation_contract.md`
19. `docs/17_reference_ui_contract.md`（本輪使用者六頁 UI 圖稿優先規格）

## 開發入口

- Godot 專案：[`../../prototypes/taskbar-hero/`](../../prototypes/taskbar-hero/README.md)。
- Review 與實作裁定：[`docs/16_implementation_contract.md`](docs/16_implementation_contract.md)。
- 本輪依 `images/` 六張圖製作可編輯 UI；[圖稿實作契約](docs/17_reference_ui_contract.md)、[opt image 素材提示詞](art-prompts/README.md)。完整 MVP 尚未完成，進度見 [`docs/DEV_STATUS.md`](docs/DEV_STATUS.md)。
- 每個畫面與遊戲物件以可編輯 `.tscn`／node 組合；Godot 編輯器可直接調整，執行時保留人工編輯。

---

## 專案一句話

> 一款手機直式、3 人隊伍、自動戰鬥、以 Loot / Build / Offline Progression 為主軸的單機 Idle RPG。

---

## MVP 最重要的驗證問題

MVP 不是要證明內容很多，而是要驗證這 4 件事：

1. 玩家是否會想看底部小隊持續自動冒險。
2. 玩家離線後回來是否有「我不在時真的發生了事情」的感覺。
3. 每 1–5 分鐘是否至少能做一次有意義的成長決策。
4. 即使沒掉神裝，是否仍有其他成長軸持續推進。

---

## 不做的東西

MVP 明確不做：

- Multiplayer
- PvP
- Trading
- Steam Marketplace 類市場
- Guild
- Server authoritative inventory
- Anti-cheat
- Live Ops
- Gacha monetization
- Advertising SDK
- Push notification
- Cloud save
- Social login
- Skin shop

先把單機核心玩法做成立。
