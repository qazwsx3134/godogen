# seal-meadow 交接進度

最後更新：2026-10-27（Claude 主 session）。每次 commit、使用者出門或下班時更新這份檔案。

## 一句話現況

M0～M3 的功能都已實作，桌面版 Godot 可以完整玩一輪：點擊戰鬥、範圍揮砍、掉落、背包、村莊、任務、商店、換裝、寵物、精煉、存檔。**還沒有用 iPhone 17 實機測試過**。依照使用者的決定，等一個階段完成後再一起用真機測。

## 怎麼驗證

```bash
cd prototypes/seal-meadow
for t in test_m0 test_m1 test_m1_loot test_m2 test_m3 test_content; do godot --headless --path . -s tests/$t.gd | grep -E "PASSED|FAILED"; done
xvfb-run -a godot --path . --quit-after 600            # 桌面實跑，不要在使用者桌面跳視窗
xvfb-run -a godot --path . -s res://tools/measure_vram.gd   # 貼圖記憶體
godot --headless --path . --fixed-fps 60 -s tests/bot_m1.gd -- clear 5     # 核心指標：揮砍清群
```

所有 suite 最後一次都通過（2026-10-27）。godot-kit 的 `test_kit` 現在遇到 SCRIPT ERROR 會判定失敗，不會再出現「有錯卻顯示通過」。

## 已完成

| 階段 | 內容 | 主要檔案 |
|---|---|---|
| 規劃 | 40 系統文件審閱與修正；D01 橫向、D02 手機 Web、D03 iPhone 17、D07 近戰＋範圍揮砍；D09／D10 暫定（見決策清單） | `design/planning/`、`design/core-loop.md` |
| M0 | Web 匯出、觸控點擊、固定鏡頭、背景暫停、版本化存檔 | kit `game_clock`／`tap_picker_3d`／`save_slots`、`export_presets.cfg` |
| M1 | 單一結算入口（固定 seed 可重播）、範圍揮砍（AP、冷卻、前搖可取消）、掉落與背包（全有或全無）、社群仇恨、怪物分群、經驗曲線 `100×L^1.8`、音效與打擊回饋 | `scripts/combat.gd`、`inventory.gd`、`items.gd`、`sfx.gd`、`tests/bot_m1.gd` |
| M2 | 村長 NPC、商店、3 段任務、兩個裝備欄與紙娃娃外觀（Blender 程序化渲染鐵劍與布衣）、村莊與傳送、小地圖、5 步新手教學、內容檢查 | `scenes/town.tscn`、`npc.tscn`、`portal.tscn`、`scripts/quests.gd`、`shop.gd`、`tutorial.gd`、`tests/test_content.gd` |
| M3 | 寵物（餵食、想吃的食物、飢餓、進化、跟隨）、精煉 +0～+6、兩段式確認、經濟重調（鐵劍 300、布衣 200、水晶 40、紅寶石 160） | `scripts/pet_rules.gd`、`refine.gd`、`pet_follower.gd`、`tests/test_m3.gd` |
| 記憶體 | 貼圖 180 → 59 MB：sprite 改成 VRAM 壓縮、紙娃娃格子 384 → 256 px；陰影 2048 | `assets/sprites/**.import`、`art_src/blender/test_chibi.render.json` |
| 修 bug | HP 回復時列表每幀重建，按鈕被刪掉；訊息紀錄沒有上限，造成記憶體洩漏（25 分鐘從 63 漲到 448 MB），已限制最多 60 行；字型缺「獠」字；Town 子節點用到區域座標 | `scripts/hud.gd`、`scripts/main.gd` |

存檔目前是 v4，v1～v3 的舊存檔都有轉換步驟。

## 還沒做

1. **真機（M0-05、M3-05）**：iPhone 17 Safari 的載入時間、FPS、10～30 分鐘發熱、切背景後回來。需要 HTTPS 網址：用 itch 草稿頁上傳前要先問使用者。模擬器的數字在 `production/qa/m0-baseline.md`。
2. **長時間穩定性**：修好訊息紀錄的洩漏之後，還沒重跑長時間測試。使用者要求不要再讓機器人跑 25 分鐘；如果要測，改用短的定點測試。
3. **平衡**：
   - 機器人從不撤退，6 分鐘死 4～5 次，Lv1 遇到 5 隻一群可能太危險，要靠真人試玩判斷。
   - 收入約 280～600 金／6 分鐘；全部買齊加精煉到 +6 約需 2400 金，大約 4～8 次 session。
   - 寵物進化大約要餵 25～40 次。
4. **M2-06 多人試驗**：依 D08 延後。多人系統 S28～S39 保留為之後可加入的項目，不刪除。
5. **紙娃娃量產**：每個裝備層在 256 px 下一張 2560×1280，約 4.2 MB（壓縮後）。如果要大量換裝，再考慮裁切每層的空白（D05）。
6. **其他原型的 godot-kit 副本是舊版**：這次只用 `sync.sh` 同步了 seal-meadow，其他原型要等使用者同意再同步。
7. 機器人 `bot_m1.gd` 的 `sweeps` 會把被取消的施放也算進去；要拿來當指標前請先改。

## 注意事項

- **改 scene 的方式**：用 Godot 存檔（headless 腳本搭配 `PackedScene.pack`，或 kit 的 `SceneBuilder`）；只有單純的數值或節點列才直接改文字。
- **Blender 位置**：Windows 版 `"/mnt/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"`，路徑要先用 `wslpath -w` 轉換。
- **測試依賴的固定前提**：村莊與草原在同一個 scene，相距 300 m（`TerrainHeight.TOWN_CENTER`），Town 底下的節點要用 `global_position`。
- **生圖要先問**：AI 生圖前要先問使用者，是直接生成還是只給 prompt；程序化的 Blender 建模不需要問。
