# Skybound 圖片 prompt v2：角色動作與手繪奇幻方向

2026-10-25 初版依使用者選擇交付 opt image prompt；2026-10-26 使用者改為指定 Luna max 直接產圖並接入。
目前採用守門者、草地、橡樹及隊長攻擊蓄力／命中；新版跑步候選未通過步態一致性審查，保留原有動作。
實際產圖紀錄與限制見 [Luna 報告](../../release-evidence/2026-10-26/luna-art-report.md)，整合說明見 [接入紀錄](../../integration-2026-10-26.md)。

Art direction：以 `design/game-brief.md` 的 RO 式 HD 2.5D 為基底，加入使用者指定的《救世者之樹》**電腦原版**參考；沒有獨立 art bible，新增的材質與色彩規格是本輪提案。既有 Skybound 定稿仍是角色識別的最高依據。

## 先用哪一份

| Prompt | 附圖 | 產出／接入方式 |
|---|---|---|
| [01 守門者](01-gatekeeper-master.txt) | 可附隊長定稿，只作畫風參考 | Boss 主視覺一張；先選定造型，再製作蓄力／重擊／倒下。現有 Boss 是 3D scene，不能直接丟進角色 atlas 就宣稱已完成替換。 |
| [02 跑步 A](02-captain-walk-a.txt) | 隊長 `master_rgba.png` | 接 `walk_a`。 |
| [03 跑步 B](03-captain-walk-b.txt) | 同一張隊長定稿；可加核准的 A 作補充參考 | 接 `walk_b`；不是把 A 水平翻轉。 |
| [04 攻擊蓄力](04-captain-attack-anticipation.txt) | 同一張隊長定稿 | 額外候選幀；現有 atlas 沒有獨立 anticipation 欄位，需擴充動畫後接入。 |
| [05 攻擊命中](05-captain-attack-impact.txt) | 同一張隊長定稿 | 可替換既有 `attack` 單幀；與 04 組合後才是完整兩階段動作。 |
| [06 草地材質](06-windcourt-ground.txt) | 不需要 | 補充場景手繪材質方向，無透視、可平鋪、opaque albedo；目前 shader 尚未引用此圖。 |
| [07 橡樹](07-windcourt-oak.txt) | 可附隊長作畫風／鏡頭參考 | 補充環境資產提案；要另建有碰撞與遮擋規則的 prop scene，不能用一張全景圖蓋掉地圖。 |

隊長參考圖：[既有定稿](../../../art_src/chars/captain/master/master_rgba.png)。每次只貼一份 prompt、產一張圖；不要把七份合併成拼圖，也不要用一張動作圖作下一張的唯一身份參考。

## 舊 prompt 的問題與本次處理

參考來源：`art_src/chars/captain/master/prompt.txt`、`poses/walk_a/prompt.txt`，以及既有 `selection.json`、`tools/pack_sprites.py` 和實際隊長定稿。

- 舊文同時要求「same pose / exactly reproduce」和「改成 running pose」，且出現重複 `THE ONLY CHANGE`。新版明確分開不可變的身份和可變的關節姿勢。
- 舊主稿寫 3 頭身，但目前採用圖的實際比例並不完全符合。新版以附圖骨架與頭部大小為準，不在動作修改時重新設計比例。
- 舊稿以整個 silhouette 的上下左右邊界鎖定角色；劍與披巾展開時會迫使模型縮小身體。新版鎖頭、軀幹、腳底接觸線和鏡頭尺度，留出動作空間。
- 統一面向畫面右下，移除「正右」和「右下」語意競爭；武器保持原來的解剖側，禁止用鏡像冒充第二步。
- 主路徑採真透明 alpha，不要求模型把邊緣混到洋紅色。當 opt image 不能提供真透明輸出時，才把 OUTPUT 段改成：`Flat pure #FF00FF background; opaque subject, no magenta/pink in the subject, no ground shadow.` 再使用既有去背工具。不能兩種背景指令同時貼。
- 加入小尺寸輪廓驗收；不再把「fine detail」當成越多越好。動作、光效、影子分開，遊戲保留命中與預警控制權。

## 《救世者之樹》參考如何轉譯

參考 [PC 官方 UI guide](https://treeofsavior.com/page/guide/view.php?n=6) 與該頁基本介面的示意圖（2026-10-25 查閱）。官方圖展示角色資訊、目標資訊、小地圖、下方快捷列和訊息區。此處的暖紙色、低彩度植被、筆觸材質與留白，是本輪觀看圖像後的美術判讀，不是官方規格。

- 場景：草地用灰綠／鼠尾草綠，路徑與遺跡用暖石色；用明暗與形體分層，避免全場螢光綠。
- 角色：保留隊長的藍、援護的綠與盾衛的金屬色；只補材質內部筆觸，不全面染成褐色。
- UI：深褐半透明面板、細黃銅邊、象牙色文字，重點是資訊配置。這輪用可編輯 Theme 做底，不冒稱已有真正手繪 UI 貼圖。
- 光效：Boss 紅色危險區保有最高優先級；草木、眼睛、胸口核心不畫成大面積高亮光團。

## 回收圖片與驗收

```text
master 核准 → 每張姿勢獨立產圖 → 比對身份／鏡頭／體積
           → 小尺寸輪廓檢查 → 選 take → atlas → 遊戲場景驗收
```

1. 檢查完整劍尖、披巾、腳與 alpha，放在深／淺背景都沒有洋紅邊或假棋盤。
2. 同畫布疊圖比較頭大小、肩寬及腳底；不能只看包圍盒。把圖縮到約 100 px 高，確認職業和動作仍可辨。
3. 跑步 A/B 的腿真的交換，肩甲和武器側不換；攻擊蓄力與命中有重心差，不是換手持劍。
4. 把新候選放到新的 take 目錄，保留現有選圖。`selection.json` 人工選定後才重新打包；不要自動覆蓋核准稿。
5. `pack_sprites.py` 現支援原生 RGBA，直接保留 alpha。舊洋紅圖仍走 `forge_matte`，可用 `SPRITE_FORGE_SHARED` 指定模組資料夾。這支工具仍需 Pillow；沒有默默改掉既有圖片。
6. 圖集以 idle 決定全角色共同縮放，腳底對齊；若姿勢太寬觸發縮小 WARN，先修圖／cell 配置，不接受身體突然變小。現有每幀 bbox 置中可能造成骨盆橫移，必要時利用 selection 的 `dx` 校正；prompt 不能代替 pack 後的檢查。
7. 跑 `sprites` 測試並開 sprite inspector 看動作。兩張接觸幀只是現階段相容方案，不等於完整流暢跑步動畫；後續可在核准後加入 passing／recoil 幀。

目前實際採用狀態以接入紀錄為準；下列 prompt 是來源規格，生成圖與規格的偏差已記入 Luna 報告。
