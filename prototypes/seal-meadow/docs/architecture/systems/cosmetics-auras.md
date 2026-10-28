# S35 衣櫥 TDD：單機薄切片草案

狀態：2026-10-29 單機實作基線；[GDD](../../../design/gdd/cosmetics-auras.md) 定義本次範圍及資格。Godot 4.7 Compatibility。

`scripts/cosmetics.gd` 只讀外觀、光環與成就資格表；`player.gd` 擁有已套用欄位及僅在記憶體存在的預覽，外觀解析從實際裝備與覆寫決定 sprite 層，絕不寫裝備或屬性。預覽可包含未解鎖項目，套用時重新驗證兩個欄位；拒絕時不部分更新。

`ui/wardrobe_window.tscn` 保存按鈕、解鎖提示、取消與套用版面；顯示時玩家在視窗右側作即時預覽。關閉或另一面板打開時還原，套用成功由主場景存檔。`scenes/player.tscn` 的裝飾光環為可編輯節點，不控制戰鬥提示或目標圈。

存檔新增外觀欄位，從 v5 升到 v6：舊檔設為原裝／無光環；舊版遊戲遇到 v6 必須拒絕覆寫。驗證器檢查外觀 id 與已領成就資格，無效資料沿用主檔／備份保護。多人、遠距離特效削減與裝扮商城不在此版本。

`tests/test_wardrobe.gd` 對應預覽／取消、解鎖、原子套用、數值不變、遷移、錯誤存檔及場景可編輯；[QA](../../../production/qa/systems/cosmetics-auras.md) 記錄證據與尚未驗證的部分。
