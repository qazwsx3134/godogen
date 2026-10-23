# 目前 UI 方向

- 第一輪 A–E 提案已被使用者否決；原始檔保留作歷史紀錄，不代表已選定。
- 戰鬥畫面的視覺語言偏向 D：簡潔像素框線與文字層次。
- 養成須參考市售 RPG 的資訊架構，重新設計操作與角色資訊層次，不能只替現況換皮。
- 下一輪稿件與研究位於 revision_d/；新版仍待使用者檢視，不能視為已驗收。

- 使用者再次指出 revision_d 配色、風格及英雄詳情布局有廉價感；該版未獲驗收。detail_refinement/ 先只重做單角頁，測試收斂配色、細框、字體層次與非卡片堆疊的布局，其他畫面暫不延伸。

- detail_refinement/hero_detail.png 已產生單張調整稿，before-after.png 為前後比較；仍待使用者檢視，未擴散到其餘畫面。

- 最新回饋：使用者偏好 detail_refinement 的整體配色／布局；技能與職業加成應參考 revision_d 的圖示、簡述及分離數值欄位。detail_refinement_v2/ 僅調整這兩區，尚待檢視。

- detail_refinement_v2/hero_detail.png 已依最新回饋整合：保留後者整體，技能與職業加成採前者的資訊組織。該稿仍待使用者檢視。

- 2026-10-22 已實作進遊戲（Claude）：全部畫面改用 detail_refinement_v2 的墨綠暖白（ui/theme.tres）；版面取 revision_d（養成名冊＋獨立英雄頁、戰鬥下方三團分頁）。招牌技圖示、職業小旗與英雄頁背景之後由 art_src/ui_icons/ 補上。Codex 同時做到一半的 hero_detail 版本（scene、script、產生器、測試、圖示與頭像）原樣保留在 codex_hero_detail_wip/，未併入。
