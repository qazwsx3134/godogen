# Claude 文件 review：浮空劍域規劃文件

2026-10-24，Claude（Opus 5.5，主導開發）。範圍：`README.md`、`design/game-brief.md`、`design/implementation-plan.md`、`design/mechanism-plan.md`、`design/tuning-draft.json`、`production/session-state/active.md`，並對照目前的 `game/`、`scenes/` 與 `tools/` 現況。程式的缺陷另見 [claude-ro-auto-review.md](claude-ro-auto-review.md)。

## A. 文件與現況不一致（直接修正）

| # | 位置 | 問題 | 處理 |
|---|---|---|---|
| A1 | README、active.md | 兩份都寫「尚無 project.godot／可執行場景／遊戲程式」，實際上已有 project.godot、同步過的 kit、`game/combatant.gd`、`game/field.gd`、`tools/build_field.gd`，以及失敗的 scene 產物 | 改寫現況，明確標出「未建出可玩場景、未驗收」 |
| A2 | brief、README、implementation-plan §1／§10 | 戰鬥呈現寫「暫不定案（三個候選）」，實際上 RO 式 HD 2.5D 已在製作中 | 依使用者的決定（Q1）改寫 |
| A3 | mechanism-plan §7 vs 現況 | 規劃寫「先做純模擬機制驗證，暫不啟動 HD／3D spike」，實際上正在做 3D 戰鬥場 | 依 Q1 決定兩者的先後，修正建置順序 |
| A4 | active.md | 沒有記錄最新的「RO／自動攻擊」指示、Claude 主導與 Codex 協作的分工，以及已知壞檔 | 改寫成交接狀態 |

## B. 規格本身的問題

| # | 位置 | 問題 | 建議 |
|---|---|---|---|
| B1 | §5「固定 250 ms 步進」＋普攻間隔公式 | 間隔會被 250 ms 量化：AGI 10 算出 1818 ms，實際變成 2000 ms；下限 350 ms 無法表示（變成 500 ms）。AGI 和速度強化在相當大的範圍內完全無效 | 步進改 50 ms，或保留 250 ms 但讓攻擊計時器累積餘數，不歸零。主導決定：步進改 **50 ms**，`search_ms`／`retreat_ms` 不變 |
| B2 | §7 自動喝藥 | 預設喝的是 HOT（6 秒回 60），「生效中不自動再喝」；被 Boss 範圍技一次打掉 40% 以上時，HOT 不夠用。瞬補只能手動，還是也能自動？規格沒寫 | 明訂：HP 低於門檻且 HOT 生效中時，自動使用瞬補（若有）。優先序寫進 §7 |
| B3 | §5 盾牌規則 | 「非槌流派裝盾後速度再乘 0.8」，但裝備欄位沒有說單手劍／細劍能不能裝盾 | 在裝備模板寫明各流派可用的副手 |
| B4 | §8 素材買回 | 「10 分鐘內買回」沒說是遊戲時間還是牆上時間；遇到離線或關頁怎麼算 | 用遊戲內 simulation time，離線時暫停計時 |
| B5 | §9 關頁凍結 | Web 上關頁事件不保證能完成寫檔（IndexedDB 是非同步） | 實戰改成每 N 秒自動快照＋事件日誌；關頁只是盡力存，不當成保證 |
| B6 | §2 節奏 vs tuning | 第一守層者建議 L5，累計需要 4,768 EXP；第一層怪給 12～25 EXP，約 260 隻，粗估 30～45 分鐘，超出「20～30 分鐘可挑戰」的假說 | 交給 Codex 量化（任務 C1） |
| B7 | §9 離線 vs tuning | 第一層委託 72 EXP／分，8 小時約 3.4 萬 EXP，足以把角色推到第二層的建議等級 L10 以上；低等衰減能壓多少還沒算 | 交給 Codex 量化（任務 C1） |
| B8 | §6 隊伍 vs 原型 | 規格是「護衛嘲諷、援護低於 45% 才治療並消耗繃帶」，原型則是「補師每 3 秒無條件 +12、全圖有效，盾衛沒有嘲諷」 | 原型改用 tuning 的 utilities；原型數字不當成設計 |
| B9 | §11 vs 原型架構 | 規格要求 domain 純模擬與 UI 分離；原型的 `field.gd` 是 360 行混合了輸入、AI、戰鬥與 HUD 的單一腳本，數字全部寫死 | 主導決定：可玩切片先求手感，但戰鬥規則與數字要先抽成 `domain/`＋讀 tuning 資料，才能接上遠征結算與離線 |
| B10 | §10 資產預算 vs 現況 | 每個角色預算 20 MiB（記憶體），實際上 `player.tscn`／`guardian.tscn` 各 63 MB，原因是把 Image 內嵌進文字 scene | 圖檔先 import，scene 只引用外部 Texture2D；這條規則寫進 §10 |

## C. 指派給 Codex 的文件任務

- **C1 節奏試算**：只寫 `production/reviews/codex-pacing.md`，可附 `tools/pacing_calc.py`。依 tuning-draft 的公式與數字，算出：(1) 新角色從 L1 到 L5（第一 Boss）、L10、L15 需要的擊殺數與時間，分成單人與三人隊兩種情況，列出每種怪的擊殺秒數與假設（移動和搜尋時間）；(2) 8 小時離線委託在第一、二層各會帶來多少等級（含逐分鐘的低等衰減）；(3) 跟 §2「20～30 分鐘」與「離線不應取代實戰」比較，提出 2～3 組數值修正。只改這兩個檔，不改 tuning-draft 本身。

## D. 需要使用者決定的問題

使用者 2026-10-24 的決定，已寫入 brief、README、implementation-plan §1／§12、mechanism-plan、ro-slice.md、active.md：

- Q1 開發先後：先做 RO 戰鬥切片（M0），再接機制閉環。
- Q2 切片中的死亡：結束本輪、不存檔；永久死亡與傳承到 M3。
- Q3 操作模型：RO 式，點敵人追打、點地移動、自動狩獵；AI 隊友不論是否自動都會參戰。

B1（50 ms 步進）、B2（瞬補自動使用）、B3（盾牌副手）、B4（買回計時用遊戲時間）、B5（Web 快照）、B10（scene 不內嵌圖片）已寫入 implementation-plan／tuning。B6、B7 依 C1（[codex-pacing.md](codex-pacing.md)）處理完畢：

- B6 成立：三人隊、每場走路 3 秒時，L1→L5 要 261 隻、36.4 分。採 Codex 方案 B 的 EXP 部分，第一層怪的 base_exp 從 12／18／25 改為 18／27／38，改後 173 隻、24.1 分（Claude 用 pacing_calc 的函式重算確認）。L5～6 時第一層獵犬與第二層甲蟲的每分鐘 EXP 約 268 對 252，跨層落差比原本小。
- B7 撤回：原本的粗估沒有乘 reward_ratio，也沒算逐分鐘衰減。實際上第一層 8 小時是 15,022 EXP（到 L7），約為同時間三人實戰的 36%，不算過強，所以 reward_ratio 維持 0.5。
- C1 提出的缺欄已補進 tuning 的 `commission` 與 §9：每分鐘數值是乘倍率前的基準，EXP／金幣／素材都乘倍率，衰減以區域怪物等級的平均計算。
- 未解：三人隊打第一層普通怪的期望入傷近乎 0（例如獵犬 0.9），第一層幾乎沒有威脅。這要在切片實測與 Boss 試算時一起看，現在不改。B8、B9 由切片實作處理（見 ro-slice.md）。
