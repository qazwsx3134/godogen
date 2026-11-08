# debt-commission 遊戲評審（game-critic）

日期：2026-11-09｜對象：`prototypes/debt-commission`（萬事屋吐槽 ADV）｜repo HEAD `db3ec71a`

- 流程依已安裝的 `~/.claude/skills/game-critic/SKILL.md`：A（第 1–5 節）與 B（第 6–8 節）全評。repo 內 `prototypes/godot-kit/skills/game-critic/SKILL.md` 有別人未提交的修改，本次沒讀。
- 本次只新增 `reviews/` 下的本報告與 `.done`。沒有改程式、資料、文件，沒有 commit／push。測試在 scratchpad 的 Linux 複本上跑，工作樹沒有被寫入。
- 來源標籤：`[code]` 讀程式或資料檔（附 file:line）｜`[measured]` 本次 session 實跑或量到｜`[doc]` 讀文件｜`[inferred]` 推測，需實測。**表格內引用 `.gd`／`.json`／`.yaml`／`.godot` 者屬 `[code]`，引用 `.md` 者屬 `[doc]`，其餘另標。**

## 前言：評的是哪個版本

| 層 | 內容 | 出處 | 玩家現在玩得到嗎 |
|---|---|---|---|
| 出貨清單 | 功能展示（16 節點，唯一的回合是 2 句的小回合）＋《不是頭痛，是桂》（5 節點，一個三選一） | `data/stories.json:2-10`、`stories/katsura_dog_ears/pack.json`、`data/showcase_story.json:373-400` [code] | 玩得到 |
| 引擎 | 調查、證言回合（testimony）、連擊（combo）、QTE、消音條、牌子、超必殺、結算評價 | `scripts/tsukkomi_round.gd`、`scripts/story_runner.gd` [code] | 在引擎裡，但出貨清單沒有用到 v2 回合 |
| 完整 loop 的內容 | 第一章：96 節點、3 回合、9 個選項槽＋1 個 QTE 槽、2 個結局 | `tests/fixtures/stories/chapter1_story.json`（測試夾具，匯出排除 `tests/*`：`PROGRESS.md:8`）[code][doc] | 玩不到 |

規則：玩法數值取引擎與夾具第一章（凡取自夾具者標「夾具」）；「玩家現在實際會看到什麼」取出貨清單。

---

## 1. 一句話總評與分數

**引擎與工具鏈很紮實（57 組 headless 測試全過），但玩家今天打開遊戲玩不到完整的「調查→吐槽」loop；loop 本身偏容易、失敗成本低，而「找槽點好不好玩」從來沒有真人驗證過——技術在正軌，產品驗證落後。**

| 面向 | 分數 | 一句理由 |
|---|---|---|
| A1 心流 | 4 | 結構合理、有輔助模式；但答對路線全拿 S、錯誤選項是附和／放棄語氣，真正的技能只剩「抓哪一句＋計時＋QTE」；三種玩家都沒量過 |
| A2 隨機 | 6 | 沒有影響玩法的隨機 → 沒有挫折與倫理風險，也沒有變動獎勵；此分數＝「風險低、變化少」 |
| A3 Loop | 3 | 夾具有完整核心閉環；出貨版沒有，外層（章節／評價／結局）沒有內容可裝 |
| A4 回饋 | 6 | 回饋分級做得細（`FEEDBACK` 表、漫畫格、HUD 跳動），但有空格、全部音效是合成佔位音、手感需實機 |
| A5 八角 | 5 | 白帽 14／黑帽 11，健康但拉力弱；單人，驅力 5 不適用 |
| B6 前期驗證 | 4 | 有 placeholder 原型與技術試作；沒有玩法假設的真人驗證、沒有繼續／轉向結論，而外觀與工具先做了 |
| B7 設計文件 | 5 | 規格與契約文件多且大致同步；角色數值表、槽點設計規則、難度曲線、效能預算、時程日期缺，多處過時 |
| B8 QA | 6 | 57/57 headless PASS（本次實跑）；Web E2E 對不上現行內容、無 CI、無實機、README 沒有分層指令 |

---

## 2. 最大的三個問題

**問題 1：打開遊戲，玩不到核心 loop。**
玩家按「開始故事」，新八說「這是故事編輯器的功能展示」。選「玩法」，十來次點擊／選擇之後，遇到一個只有 2 句、答案就寫在選項裡的小回合（`data/showcase_story.json:373-400`）。選桂的短篇：約 5 句台詞後三選一，三個結局裡兩個直接顯示「（尚未寫完）」（`stories/katsura_dog_ears/dog_ears_story.json:38-39, 60-61`），另一個是「OK」（`:17-18`）。有連擊、QTE、評價的第一章還在，但只在 `tests/fixtures/`。 [code]（點擊次數是依節點結構估的 [inferred]）

**問題 2：選字幾乎不會錯，高手與亂點的差別只在「少碎幾副眼鏡」。**
玩家在第一回合按「吐槽！」，看到四個選項：兩個像吐槽（驚嘆號、指出矛盾）、一個附和（「原來是牙膏啊。」）、一個「……（放棄吐槽）」。沒查線索也永遠有一個 weak 選項可選，全程選 weak 同樣拿 S（`tests/test_chapter1.gd:93`），perfect 只多 +20 力量與一級震動、不進評價。玩家很快會發現「挑一個像吐槽的就好」，緊張感只剩 8 秒倒數與最後的 QTE。 [code]；玩家是否真的這樣覺得 [inferred]，需真人。

**問題 3：「找槽點好不好玩」從沒有人類驗證過，力氣卻已經花在外觀與工具上。**
作者想知道好不好玩，但專案裡沒有一份真人試玩紀錄：驗收表全部「待驗」（`docs/SHORT-STORY-ACCEPTANCE.md:22`）；ROADMAP 每個 Phase 的「真人試玩」（`docs/story-telling-game/ROADMAP.md:104, 106`）都沒做；`project.yaml:8` 卻標 `stage: Production`；最新的 Web 包是 10 月 30 日的舊包 [measured: `ls build/web` 的日期]，不含現行兩個故事 [doc: `README.md:69`、`PROGRESS.md:13`]。同時 10/19 起專案定位改成「創作者工具」（`docs/ROADMAP-COMMERCIAL.md:11`），「好玩」要不要當成功標準，沒有寫下來。 [doc][code]

---

## 3. 各面向細節

### 第 1 節 心流（A1，4/10）

**挑戰數值**（引擎＋夾具）

| 參數 | 值 | 出處 |
|---|---|---|
| 眼鏡 | 5 副；冷場／逾時／揮空／QTE 失誤各 −1；整章只減不加（`scripts/`、`main.gd`、`tools/` 內只有兩處減少、沒有補回；還原只來自快照或檢查點） | `story_runner.gd:11-12`、`tsukkomi_round.gd:258`、`story_runner.gd:988`；整章不回復：`tests/test_chapter_flow.gd:3-4` [code] |
| 選詞時限 | testimony 8 s，**按下「吐槽！」後才開始倒數**；combo 8→6→5→4 s（每接住一句縮短），句子打完自動開始倒數 | 夾具 `chapter1_story.json:728, 1505, 2351-2356`；`tsukkomi_round.gd:37, 91-95`；`main_round.gd:33-34, 76-78, 140-150` [code] |
| QTE | 圓環 1.6 s 縮到靶圈；判定窗 ±0.12 s（輔助模式 ±0.24 s）；2.0 s 沒點算逾時 | 夾具 `chapter1_story.json:2332-2337`；`tsukkomi_round.gd:150-155`；`main_round.gd:241-243`；`settings.gd:17` [code] |
| 力量 | perfect +30、weak +10、上限 100；滿了才能超必殺（只打得到有選項的槽，不含 QTE 槽） | `tsukkomi_round.gd:31, 112-117, 296-303`；`story_runner.gd:13-14` [code] |
| 提示 | 同一句冷場 3 次 → 神樂提示；Game Over 後次數保留 | `tsukkomi_round.gd:35-36, 266-267` [code] |
| Game Over | 眼鏡歸零 → 回到該回合開頭（眼鏡回到回合開頭時的數量，不是 5 副）、評價降一級 | `story_runner.gd:712-745, 770, 316-318`；`tests/test_chapter1.gd:59` [code] |
| 評價 | 5 副 S／4 A／2–3 B／1 C，每次 Game Over 再降一級；**perfect 數不影響評價** | `story_runner.gd:62, 316-318` [code] |
| 輔助 | 選詞時間 ×1.5、QTE 判定窗 ×2 | `settings.gd:16-17` [code] |

**各路線的結算評價**（夾具測試的斷言：`tests/test_chapter1.gd:93`）[code]

| 路線 | perfect | hidden | super | **weak（全程只選 weak）** | gin | timeout | retry（R1 連錯 5 次） | one_fail | two_fails | four_fails |
|---|---|---|---|---|---|---|---|---|---|---|
| 評價 | S | S | S | **S** | S | A | A | A | B | C |

**三種玩家**

| 玩家 | 結果 | 來源 |
|---|---|---|
| 完全不輸入（連「下一句」也不點） | 停在第一句台詞（故事等點擊），不輸也不前進；開 AUTO 也只會走到調查為止（`_auto_step` 只在 story 模式前進），調查要點熱區，到不了回合 | `main.gd:2232-2254, 2297-2307`；`main_investigation.gd:285-343` [code] |
| 只點「下一句」、不答題 | 到不了 R3：調查要點熱區，R1、R2 是 testimony，不按「吐槽！」就不計時也不前進（點「下一句」沒有作用）。只有已答完 R1、R2 的玩家在 R3 停手，combo 才會每次逾時 −1，5 次（≈ 5×8 s ＋ 5 段反應台詞）Game Over，重試後重複 | `main_round.gd:33-34, 43, 140-150, 359-366`；`tests/test_chapter1.gd:59` [code] |
| 隨機但不重複選項 | 期望冷場約 5.9 次／章（對照 5 副眼鏡），隨機拿 S 約 0.2% | 第 2 節計算 [code] |
| 全選 weak | S，但力量最多 90 < 100，超必殺不會出現 | `test_chapter1.gd:93`；9 個選項槽 × 10 = 90 [code] |
| 知道答案的高手 | 0 冷場 → S；perfect 路線可開超必殺 | `test_chapter1.gd:37, 77-78, 93` [code] |
| **普通玩家** | **未量測**：沒有 bot、沒有真人紀錄 | 見第 5 節 |

**發現**

- **[code] 選字不是技能。** 每個選項槽的結構固定：a＝perfect（要線索）、b＝weak（永遠可選）、c＝附和語氣（「原來是牙膏啊。」「沒有毒真是太好了。」「牛奶的名字好可愛。」）、d＝「……（放棄吐槽）」（夾具 `chapter1_story.json:643, 688, 1383, 1420, 1455, 2186, 2222, 2258, 2295`）。看得出 c、d 不是吐槽，所以「找槽點」的推理其實只決定 perfect 或 weak，而兩者同分。[inferred] 需真人確認玩家是否這樣感覺。
- **[code] 「不操作會輸」只在 R3 成立：** 其他地方不操作只會停住、永遠不會輸（調查與 testimony 都在等玩家主動做事）；只有答完 R1、R2 的玩家在 R3 停手，倒數才會自動扣眼鏡。skill 的健康標準（不操作會輸、普通勉強過、高手明顯贏）因此只有最後一段符合；這是「玩家自己掌控節奏」的設計取向，不一定是缺點，但沒有被當成假設寫下來。
- **[code] 真正會失誤的只有三處：** ① 抓哪一句——R1 的 l1、l3 沒有槽點，按「吐槽！」是揮空、扣眼鏡（夾具 `chapter1_story.json:636, 681` 有 `whiff` 無 `slot`；`tsukkomi_round.gd:34`）；② 計時——8 s，combo 後段 4 s；③ QTE ±0.12 s。
- **[inferred] 難度曲線是階梯，不是鋸齒。** R1 基本（2 槽）→ R2 加牌子與隱藏路線（3 槽，時限不變）→ R3 同時加入倒數縮短、QTE、超必殺；舊壓力沒有在新機制出現時降下來。回合之間有反應劇情與 `ch1_twist` 的選擇（`chapter1_story.json:2981`）可喘息。需實測。
- **[code] 第一次可能失敗的位置：** 沿主線（`next` 連結，不含選擇性的對話與廚房）在 R1 之前有 30 句台詞、518 字（標準速度 0.032 s/字，純打字約 17 s，`settings.gd:9`）＋ 4 個線索調查（本次用 python 沿 `chapter1_story.json` 的 `next` 計數）。約 1–2 分鐘後第一次按「吐槽！」[inferred]。
- **[code] 追上機制不靠「刷」：** 提示、回合開頭重試、輔助模式。但提示在選項槽幾乎不會出現（見第 2 節）。
- **[code] 目標與掌控感：** 首次教學各 3 步（`data/tutorials.json:5, 14`）；選單、紀錄、存檔欄位會暫停倒數（`README.md:35` [doc]）。
- 理由小結：結構與輔助都有，但答對路線同分、失敗成本低（Game Over 只回到回合開頭），且沒有任何 bot 或真人數據支撐「剛好」。給 4；若真人試玩的冷場率落在 15–35% 可上調。

### 第 2 節 隨機（A2，6/10）

**沒有影響玩法的隨機。** `randf` 只出現在三處，全是視覺：`stage_effects.gd:268`（震動方向）、`burst_shape.gd:45-50`、`speed_lines.gd:39-44`（漫畫格圖形）；全 repo 沒有 `shuffle`／`pick_random`；選項順序固定；結果是「（選的選項、持有的線索、已接住的句子）」的確定函數（`tsukkomi_round.gd:160-178, 187-278`）。[code]

所以 `(1-p)^n`、`ln(0.05)/ln(1-p)`（最倒楣 5% 要試幾次）在這裡**不適用**：它假設每次獨立抽籤、選項放回。這裡沒有 p。玩家唯一「靠運氣」的情況是沒線索時猜選項；選錯的選項不會被拿掉，但理性玩家不會重選，所以用「不重複」模型：一個槽有 s 個不會冷場的選項、f 個冷場選項，**最壞冷場次數＝f（確定值）、期望冷場次數＝f/(s+1)**。

**夾具第一章的計算**（s、f 取自選項資料與 `visible_options`〔`tsukkomi_round.gd:98-109`〕：沒有持有線索時，帶 `require` 的 perfect 選項不顯示）

| 回合 | 選項槽 | 有線索：s／f | 無線索：s／f | 最壞冷場（只算選錯） | 期望冷場：有線索／無線索 | 出處（夾具） |
|---|---|---|---|---|---|---|
| R1 證言 | l2、l4 | 2／2 | 1／2 | 2＋2＝4 | 1.33／2.00 | `:643, 688` |
| R2 證言 | l1、l2、l3 | l1 2／2；l2 1／2（沒有 a，改點牌子＝perfect）；l3 3／1 | l1 1／2；l2 1／2；l3 2／1 | 2＋2＋1＝5（l3 在 l1、l2 接住前就做則 6） | 1.92／2.33 | `:1383, 1420, 1455`；`when` 見 `:1480` |
| R3 連擊 | c1–c4 | 每槽 2／2 | c3 1／2，其餘 2／2 | 4×2＝8，另加 QTE | 2.67／3.00 | `:2186, 2222, 2258, 2295` |
| R3 QTE | c5 | 不是選項，是技能判定 | — | 無上限 | — | `:2332-2337` |

說明：R2 l3 的「放棄吐槽」在 l1、l2 都接住時改判 hidden（離開回合、不扣眼鏡），所以算成不冷場（`when`：`chapter1_story.json:1480`）。這份計算不含 R1 l1／l3 的揮空與逾時。

- **整章**：不看內容、隨機不重複地選（持有全部線索），期望冷場 1.33＋1.92＋2.67 ≈ **5.9 次，約等於 5 副眼鏡**，也就是大約在 R3 前後吃一次 Game Over；隨機拿到 S（0 冷場）的機率 ≈ 0.25 × 0.125 × 0.0625 ≈ **0.2%**。 [code]（模型假設與限制如上）
- **R1 只靠選字無法 Game Over**（最壞 4 < 5）；R2 最壞剛好 5；R3 最壞 8，外加 QTE 失誤無上限。 [code]
- **行動前／行動後：** 沒有 output randomness（結果不會被骰子決定）；線索取得與否是確定的 input 條件。 [code]
- **挫折訊號：** 玩家說得出「我哪裡沒做好」——劇情會用台詞說明（逾時：「八秒過去了。新八的嘴還開著。」夾具 `chapter1_story.json:1117`；對沒槽點的句子揮空：登勢解釋「睡著的事，誰都戳不破」`:822`；QTE 太早／太晚各有一句不同台詞 `:2495, :2521`）。但 UI 的 toast 只寫「揮空！眼鏡 −1」（`main_round.gd:325`）。 [code]
- **保底：** 神樂提示（`hint_after`＝3，`tsukkomi_round.gd:35, 266`）。**選項槽只有 2 個冷場選項，不重複選就湊不到 3 次**，要靠逾時、重複選錯，或 QTE／揮空槽才會觸發 [code]；實際觸發率 [inferred]，需 bot＋真人。
- **倫理線：** 沒有真錢、沒有「差一點」假象、沒有離線懲罰（grep `offline|purchase|iap|advert` 在 `main.gd` 與 `scripts/` 為空），機率透明（全確定）。 [code] 沒有越線。
- 給 6：沒有隨機＝沒有風險，但也沒有變動獎勵與重玩變化。不因此扣太多分。

### 第 3 節 Loop（A3，3/10）

```
meta  章節選擇 → 開始故事 → 章節結算 S/A/B/C → 結局收集／流程圖／鑑賞
 │      ▲                                  │
 │      └──── 下一章（出貨版：0 章 ✗）←────┘
 │
 └ 核心（夾具第一章；出貨版沒有）
     調查 4 線索 → 證言 R1 → R2 → R3（連擊＋QTE）→ 結算
        │                │  冷場 −1 眼鏡（整章不回復）→ 歸零 → Game Over
        │                │                       → 回合開頭重試、評價降一級
        └ 線索 → 解鎖 perfect 選項 → 力量 +30／+10，滿 100 → 超必殺
     │
     └ 微（30 秒內）
         讀句(點) → ◀▶ 切句／聽下去 →「吐槽！」→ 8 s 選詞 → 回饋
                                                └→ R3 末句 QTE 1.6 s → 回饋
```

| 層 | 入口／出口 | 閉環？ | 斷點 |
|---|---|---|---|
| 微 | 入：點句子、按「吐槽！」；出：選詞結果＋回饋 | 是（夾具與出貨的 2 句小回合都有） | 失敗後要先點完 2 句反應台詞才回到證言（夾具 `chapter1_story.json:898`：freeze 0.25 s＋2 句）；回饋延遲沒量 |
| 核心 | 入：調查；出：結算。獎勵：線索→perfect→力量→超必殺 | 夾具是；**出貨版否** | 出貨版的回合沒有線索投入與評價；perfect 沒有評價價值 → 獎勵只通到超必殺這一個出口 |
| meta | 章節選擇、評價、結局收集、流程圖、鑑賞、製作名單 | **否**（出貨版） | 本篇 0 章，章節選擇顯示「還在製作中」（`PROGRESS.md:11` [doc]）；沒有下一章（`ROADMAP-COMMERCIAL.md:139` 的 C4 仍是待辦）；結尾沒有勾子：展示回目錄，桂短篇結在「（尚未寫完）」 |

- **[code] 內外層咬合：** 外層（評價、結局、流程圖）的資料都在（`story_runner.gd:290-312`、`scripts/flow_graph.gd`、`scripts/gallery_panel.gd`），但外層只把數字變大、沒有給內層新規則：下一章的新敵人、新機制不存在。
- **[code] 長期目標第一個 session 看得到嗎：** 章節選擇的「結局收集」列出「？？？」（`README.md:26` [doc]）；出貨版只有功能展示的結局，沒有「之後能得到什麼」。
- **[inferred] session 開頭：** 功能展示約十來次點擊／選擇才到第一個回合；第一章夾具約 1–2 分鐘（30 句＋4 線索）。

### 第 4 節 每個行動都有回饋（A4，6/10）

符號：✓＝有；缺＝沒有；—＝不需要；需實機＝headless 無法證明（音效同步、手感、延遲）。**所有音效都是合成佔位音**：`data/asset_catalog.json` 的 `sounds` 19 筆全部沒有 `path`（本次檢查 [measured]），`stage_effects.gd:339-342` 退回 `_placeholder`；語音資料夾 `assets/audio/voice/` 不存在（`stage_effects.gd:208-213`）。

| 動詞（入口） | 視覺 | 音效 | 震動 | 結果與進度 | 失敗時說明原因 |
|---|---|---|---|---|---|
| 點句子推進（`main.gd:2232-2254`） | ✓ 補完／翻頁 | ✓ 打字音（`stage_effects.gd:191`，佔位） | — | 缺：沒有章節進度條 | — |
| 長按隱藏 UI（0.5 s：`main.gd:110, 2223-2229`） | ✓ | 缺 | 缺 | — | — ；教學沒提（`tutorials.json` 只有 boke／investigate）→ 缺 |
| 上滑開紀錄（140 px：`main.gd:112, 2203`） | ✓ | 缺 | 缺 | — | 教學沒提 → 缺 |
| AUTO／SKIP／LOG／MENU | ✓ 切換狀態；略讀有 toast「略讀中・點畫面停止」（`main.gd:2362`） | 缺 | 缺 | — | — |
| 選項（`main.gd:1912-1927`） | ✓ 面板收起接下一句 | 缺 | 缺 | 旗標靜默寫入，沒有「記住了」提示 | — |
| 調查：拖曳背景（`main.gd:2218-2220`） | ✓ | — | — | — | — |
| 調查：點中熱區（`main_investigation.gd:309-343`） | ✓ 勾＋toast「取得線索：X」 | ✓ `comedy_pop`（`stage_effects.gd:20`） | ✓ 輕（tier 0） | ✓ 線索小牌、「繼續」解鎖 | — |
| **調查：點空白處**（`main_investigation.gd:291-293`） | **缺** | **缺** | **缺** | **缺** | **缺**（沒點中就直接 return） |
| 調查：對話／移動話題（`:369, :381`） | ✓ 演出／換地點 | 缺 | 缺 | ✓ 聊過的不再出現 | ✓ 不能聊／去時有 toast |
| 證言：◀ ▶ 切句、聽下去（`main_round.gd:251-288`） | ✓ | 缺 | 缺 | ✓「已聽過」；聽下去取得素材時有沒有提示：未驗證 | — |
| 吐槽！（開始選詞，`main_round.gd:140-157`） | ✓ 選項面板＋倒數 | 缺 | 缺 | ✓ 倒數 | 對沒槽點的句子按＝揮空 −1：劇情台詞有說明（`ch1_r1_l1_whiff`），toast 只有「揮空！眼鏡 −1」 |
| 選詞：perfect（`main_round.gd:319-322`） | ✓ 漫畫格＋toast「完美吐槽！吐槽之力 +30」＋HUD 跳動 | ✓ `comedy_don`（`comedy_preset.gd:40` → `comedy_layer.gd:172-173`，佔位）；語音缺 | ✓ tier 1 | ✓ 力量條 | — |
| 選詞：weak（`:322-323`） | ✓ 漫畫格＋toast「普通吐槽！+10」 | ✓ 同上 | ✓ tier 0（`stage_effects.gd:21`） | ✓ | — |
| 選詞：冷場（選錯／放棄／逾時，`:324-333`） | ✓ 凍結 0.25 s、眼鏡碎一副、晃 7 px／0.18 s | ✓ `crow`＋`glass_crack`（`stage_effects.gd:23`） | ✓ tier 1 | ✓ 眼鏡 −1 | 劇情台詞說明（逾時、揮空、QTE 早／晚各一句）；toast 沒有原因 |
| 消音條／伊莉莎白牌子點擊（`:166-177, 188-197`） | 回饋系統只給 toast「完美吐槽！+30」與 HUD；**漫畫格不播**（`_round_action` 的 `show_comic` 預設 false：`:159-162`）；演出由劇情節點決定（夾具 `ch1_r2_placard`：cut-in、晃動）；牌子點擊範圍 ≥ 48 CSS px | 回饋系統本身無音效；只有節點寫了 `se` 才有聲（`ch1_r2_placard` 有 `tsukkomi_hit`，佔位） | ✓ tier 1（結果是 perfect） | ✓ 力量 +30 | 點到沒字的牌子：沒反應（`README.md:39` [doc]）→ 缺 |
| 超必殺（`:213-216`） | 回饋系統：toast「…！全部戳破」；cut-in、光束、閃光、晃動來自劇情節點（夾具 `ch1_r3_super`）；眼鏡氣焰是 HUD 的滿力量狀態 | 來自節點的 `se`：`super_charge`、`beam`（佔位） | tier 1（結果是 perfect；力量歸零，不會觸發 `power_full` 的 tier 2：`main_round.gd:334-354`） | ✓ 力量歸零、剩餘槽全接住 | 力量未滿時按鈕的說明：未驗證 |
| QTE 點擊（`:219-243`） | ✓ 縮圈；命中：節點的 cut-in＋閃光＋晃動（夾具 `ch1_r3_qte_perfect`）；失敗：凍結 | **命中：缺**（`FEEDBACK["perfect"]` 無音效〔`stage_effects.gd:22`〕；`cutin`／`shake`／`flash` 都不出聲〔`stage_effects.gd:137-170`，只有 `se` op 會〕；節點沒寫 `se`；語音檔缺）；失敗：✓ `glass_crack`＋`crow` | ✓ tier 1（命中與失敗都有：`main_round.gd:330-333`） | ✓ | ✓ 太早／太晚各有一句台詞；UI 沒有「早 x ms」數字 |
| Game Over → 重試（`:368-400`） | ✓ 碎眼鏡畫面 | ✓ `glass_shatter` | ✓ tier 2＋晃 18 px／0.35 s | ✓ 回合開頭 | ✓ 無檢查點時 toast（`:372`） |
| 章節結算 → 下一章／回標題 | ✓ 評價＋統計（`story_runner.gd:290-312`） | 佔位 BGM | 缺 | ✓ 最佳評價存檔 | ✓ 顯示剩餘眼鏡與 Game Over 次數 |
| 存檔／讀檔／快速存讀／回上一句（`main_saves.gd:294-388`） | ✓ toast | 缺 | 缺 | ✓ | ✓「存檔失敗，原有資料已保留」「尚無可讀取的快速存檔」 |

**空格即發現**

- **[code] 調查點空白處完全沒有回應**（`main_investigation.gd:291-293`）。找不到線索的玩家得不到任何「你在找，但這裡沒東西」的訊號。
- **[code] perfect 與 weak 的體感差距小：** 同一個漫畫格 preset、同一個 `comedy_don`，差別是 toast 文字、+30／+10、震動一級（`stage_effects.gd:21-22`），而 perfect 的語音沒有素材。[inferred] 需實機。
- **[code] 所有音效是佔位音（19/19），沒有語音。** 「吐槽爽感」目前主要靠漫畫格。
- **[code] QTE 完美命中沒有任何音效**（見上表）：`cutin`／`shake`／`flash` 本身不出聲，要靠劇情節點自己寫 `se`，作者沒寫就靜音；這正是回合裡最該爽的一下。佔位音表其實有 `qte_hit`（`stage_effects.gd:373`），但 QTE 命中的程式路徑沒有呼叫它，第一章夾具的命中節點也沒寫（只有 `phase4_rounds` 夾具引用 1 次）。
- **[code] 只有「選詞」會播漫畫格：** 消音條、牌子、超必殺、QTE、揮空走 `_round_action`，`show_comic` 預設 false（`main_round.gd:159-162`；只有 `_on_boke_option_pressed` 傳 true：`:301`）。這些路徑的爽感完全由劇情節點的演出決定。
- **[code] 長按、上滑沒有教學，也沒有畫面提示**（`data/tutorials.json` 只有兩組）。
- **[doc] iPhone Safari 沒有震動 API**（`README.md:44`），iOS 玩家只有視聽回饋。
- **[code][doc] QTE 時序：** 判定用「處理輸入當下」的 `Time.get_ticks_usec()` 減起點（`qte_ring.gd:41, 48`）。Godot 4.7 的輸入事件沒有時戳可用 [measured: 本次 ClassDB 檢查，`InputEvent`、`InputEventMouse`、`InputEventMouseButton`、`InputEventScreenTouch`、`InputEventFromWindow` 都沒有 time／stamp 屬性或方法]，所以輸入延遲與掉幀必然算進玩家的誤差，只能靠校正旋鈕補償（建議 10）；`ROADMAP-COMMERCIAL.md` B07 記錄過軟體渲染 Chromium 一次偏差 0.433 s。**需實機。**
- **需實機：** 「收到了」≤ 100 ms、「結果」≤ 0.5 s、音效同步、震動強度、漫畫格節奏。本次全部未量。

### 第 5 節 八角框架（A5，5/10）

| # | 驅力 | 分 | 證據 |
|---|---|---|---|
| 1 | 使命感 | 4 | 「替新八吐槽」的角色代入與銀魂同人梗（`ROADMAP.md:7` [doc]）；出貨內容沒有主線 |
| 2 | 成就感 | 5 | S/A/B/C 評價（`story_runner.gd:316-318`）、結局收集「？？？」、流程圖、結算統計；但 perfect 不進評價，出貨版沒有可拿評價的章節 [code] |
| 3 | 創造力與回饋 | 5 | 選詞＋線索、第四面牆（牌子、消音條）、超必殺；但每槽只有一個最佳解，選項不能組合 [code] |
| 4 | 擁有感 | 3 | 線索與人物檔案、鑑賞解鎖、18 格存檔；線索只在章內用，沒有長期累積 [code][doc] |
| 5 | 社交影響 | 不適用 | 單人原型，不硬加社交 |
| 6 | 稀缺性 | 3 | 眼鏡 5 副是整章不回復的預算；8/6/5/4 s 計時（`tsukkomi_round.gd:37`）[code] |
| 7 | 不可預測 | 4 | 沒有隨機；好奇心來自笑點驚喜、隱藏路線（夾具 `chapter1_story.json:2676` 的 `hidden_total`＝1）、「？？？」結局 [code] |
| 8 | 損失與避免 | 4 | 失去眼鏡、評價下降、Game Over；但 Game Over 只回到回合開頭 [code] |

- **白帽（1+2+3）＝14／30，黑帽（6+7+8）＝11／30：** 白帽高於黑帽，不是「停不下來但玩完不開心」的結構。
- **左腦（2+4+6）＝11，右腦（3+7，驅力 5 不適用）＝9：** 偏外在獎勵，右腦（內在樂趣）的長期拉力主要靠笑點，而笑點目前沒有真人驗證。
- 兩邊都偏低：不會玩到不開心，但也沒有「再玩一章」的拉力。

### 第 6 節 前期驗證：玩法與技術可行性（B6，4/10）

- **[doc] 有用 placeholder 先做玩法：** V1 立繪用剪影＋名字＋表情文字（`ROADMAP.md:25, 90`）；Phase 1–3 先驗框架、資料與「調查→吐槽」短循環（`ROADMAP.md:101-104`）。
- **[doc] 假設有寫，但不在 README：** 核心假設「把找矛盾換成找槽點」在 `ROADMAP.md:7, 108-110`（Phase 3 先驗「找槽點是否成立」）；`README.md:1-13` 沒有「要驗證的假設」段落。
- **[doc] 通過條件只有工程面可判定：** `ROADMAP.md:101-106` 的條件是功能能走通；玩家面只寫「真人試玩回饋計時與笑點」（`:104`）、「真人手機試玩一次」（`:106`），沒有數字門檻，例如「不操作會輸、高手會贏、試玩五次願意繼續」。
- **[doc] 繼續／轉向／放棄的結論：缺。** `SHORT-STORY-ACCEPTANCE.md:3, 22` 寫明結果尚未取得、「目前全部待驗」。
- **[doc][code] 順序風險（高）：** 手繪背景與立繪、銀魂和紙 UI、shader 轉場、故事編輯器、人格／記憶系統、外觀包、故事包、流程圖都已完成或進行中（`ROADMAP-COMMERCIAL.md:13-60`、`PROGRESS.md`），玩法的真人驗證還沒做；`project.yaml:8` 標 `Production`。
- **[doc] 方向決定（10/19）：** 私人原型路線、系統定位為創作者工具（`ROADMAP-COMMERCIAL.md:7-11`）。若目標是「創作者系統」，功能展示當預設合理；若目標是「好玩的吐槽遊戲」，缺內容。這個取捨沒有寫成一句話。

**最難的 3 個技術點**

| # | 技術點 | 試作 | 量到的數字 | 判定 |
|---|---|---|---|---|
| 1 | Web 版大小與冷啟動 | 有：Web 匯出、候選包 | [measured] `build/web/index.pck` 72,754,692 B、`index.wasm` 39,509,339 B（2026-10-30 的包）；[doc] 11-04 匯出 pck 76.6 MB，字型 23 MB＋原聲帶 21 MB（`PROGRESS.md:23`）；冷啟動時間、大小預算：無（`ROADMAP-COMMERCIAL.md:112` B02） | 部分：有大小、無預算與冷啟動 |
| 2 | 手機輸入與手感（觸控、QTE 時序、Safe Area、震動） | 只有桌機 Chromium 的觸控模擬（`README.md:198`；320×568、390×844 等） | 無實機數字；[doc] 軟體渲染 Chromium 曾偏差 0.433 s（`ROADMAP-COMMERCIAL.md:109`） | 未驗證 |
| 3 | 劇本資料、存檔相容與兩個大單檔（`story_runner.gd` 2,869 行、`main.gd` 3,012 行） | 有：存檔版本政策 B10、快照往返測試、G6 拆分 | [measured] 57/57 PASS；幀時間／draw call／記憶體：無（`project.yaml:21`） | 邏輯已驗證、效能未驗證 |

### 第 7 節 設計文件涵蓋度（B7，5/10）

| 類別 | 項目 | 狀態 | 證據與備註 |
|---|---|---|---|
| GDD | 核心玩法 | **有** | `README.md:13`、`ROADMAP.md:23`（劇情→調查→裝傻回合→結算）；loop 圖原本沒有，本報告第 3 節補了一張 |
| GDD | 美術 | **過時** | `docs/ART-SPEC.md:5` 自己註明「直式畫面示意與背景尺寸是舊版資訊」，`art_check.gd` 尺寸提示仍是直式；表情清單 `docs/story-telling-game/EXPRESSIONS.md` 有 id 與批次，可用 |
| GDD | 音效 | **缺** | 沒有音效清單與規格；catalog 19 個 SFX id 無 path；13 首原聲帶授權待查（`docs/ASSET-MANIFEST.md`） |
| GDD | 劇情 | **有** | 第一章草稿 v0.2、桂短篇草稿、人格／記憶（`authoring/`，6 筆已確認）；備註：只到第一章，第二章起缺（`ROADMAP-COMMERCIAL.md:139`） |
| 策劃 | 角色能力 | **缺** | 沒有數值表；眼鏡 5、力量 100、+30／+10 只在程式（`story_runner.gd:11-14`、`tsukkomi_round.gd:31`），文件只寫「5 格」「集滿」（`ROADMAP.md:38-39`） |
| 策劃 | 戰鬥機制 | **有** | `tsukkomi_round.gd:1-27` 規則註解、`IMPLEMENTATION.md` 契約、`ROADMAP.md:27-44`；備註：傷害公式不適用，勝負條件（眼鏡歸零、結算評價）已寫 |
| 策劃 | 技能數 | **有** | 唯一主動技「超必殺」1 個（`ROADMAP.md:39`、`tsukkomi_round.gd:112-117`）；備註：其餘是回合動詞（`README.md:32-44`） |
| 策劃 | AI 邏輯 | **缺** | 備註：不適用傳統 AI；但「槽點怎麼設計、線索如何對應、玩家如何反制」的規則沒寫成文件，只存在各回合 JSON |
| 策劃 | 關卡構建 | **過時** | `ROADMAP.md:65-76` 寫第一章「約 80–100 句」，夾具實際有 222 個 `say` 步驟（另有回合句）[measured: 本次 python 計數]；第一章已退出出貨；沒有難度曲線與「每關教什麼」 |
| TDD | 技術需求 | **有** | `project.yaml:9-15`（Godot 4.7、GDScript、Compatibility）、`README.md:100-114`、`IMPLEMENTATION.md`、第三方套件釘 commit（`README.md:208-223`）；備註：`ROADMAP.md:15-16` 的 9:16／1080×1920 已過時，列入下方清單 |
| TDD | 效能預算 | **缺** | `project.yaml:21`：「Device frame-time, draw-call and memory budgets await measured targets」 |
| 規劃 | 資源與時程 | **缺** | `ROADMAP-COMMERCIAL.md:53-60` 有里程碑與驗收條件、S/M/L 量級，沒有日期；素材沒有工作量估計 |

**文件與程式不一致清單（過時）**

- `stories/katsura_dog_ears/README.md:10-11` 與 `docs/story-telling-game/stories/004-katsura-dog-ears-draft-v0.2.md` 仍寫 timing 節點的 QTE 參數（0.75 s／±0.18 s），`dog_ears_story.json` 的 timing 節點已是三選一（`:159-162`）。 [doc][code]
- `README.md:96` 的範例 `?story=chapter1`：清單裡已沒有這個故事。 [doc][code]
- `README.md:151-182` 的測試指令列了 30 條；`tests/` 實際有 57 個 `test_*.gd`，未列的 27 個：`art_check build_packs chapter1 chapter_flow character_height conditions dialogue_log dialogue_text downloaded_bgm flowchart game_feel interaction investigation_layout investigation_picker katsura_dog_ears parley_stores portrait_controls portrait_reaction reading_convenience reading_scenes save_validation scene_transition settings showcase story_packs text_presentation tutorial` [measured]。
- `docs/story-telling-game/ROADMAP.md:16` 與 `design/game-brief.md:3` 寫手機直式 9:16；`project.godot:26-27` 是 1920×1080 橫向。 [doc][code]
- `docs/ROADMAP-COMMERCIAL.md:139`（C4）寫「`stories.json` 裡只有一個 chapter」，現在是零個。 [doc][code]
- `TODO.md:8, 10` 的 `?sample=transitions` 已搬進夾具；`docs/VERIFICATION.md` 是 2026-09-25 直式外殼的紀錄。 [doc]

**下一個里程碑（第一次真人試玩）之前必補：** 玩法假設與通過條件（README）、數值表（角色能力）、槽點設計規則（AI 邏輯）。試玩後再補：難度曲線、效能預算、時程日期。

### 第 8 節 QA（B8，6/10）

**阻斷性缺陷**

- 沒有 bug 清單：`production/qa/` 只有 `smoke-2026-10-16.md`、`evidence/`、`web-candidate-2026-10-30.json` [measured: `ls`]。
- 沒有已知的當機、存檔遺失、卡死仍開著；曾經的卡死（Game Over 卡以 `next` 收尾會讓 runner 卡在 Game Over，`PROGRESS.md:9`）已改正（`PROGRESS.md:9`），並有 `tests/test_showcase.gd:38-47` 回歸。 [doc][code]
- **已知會擋「現行內容的 Web 驗證」：** `tools/browser_check.mjs` 預設走 `?sample=debt`（`:36`），那是已退出出貨的夾具故事；`PROGRESS.md:24-25` 記載各路線在 HEAD 上就失敗（smoke 停在「Next touch advances」）；`:12-13` 記載 `preview_smoke`、`smoke.mjs`、`project_smoke.mjs` 同樣對不上。 [doc]
- 發布面：路線是私人原型（`ROADMAP-COMMERCIAL.md:9`），所以上述不擋；改走公開發行時全部要補。 [doc]

**流程打通**

- 引擎層有：`tests/test_chapter1.gd` 10 條路線走完整章到結算並做快照往返（`:5, 25, 47`）；`tests/test_chapter_flow.gd`（結算→評價→解鎖下一章→結局收集）；`tests/test_showcase.gd`（所有分支＋Game Over→重試→過關＋實際閱讀畫面）。 [code]
- **「啟動→教學→核心 loop→結算→存檔→重開讀檔」對現行出貨內容沒有一條自動化走完：** Web 的 `check_reading_chapter1.mjs`（2026-10-19 連續 3 次通過，`TODO.md:43` [doc]）針對已退出的第一章，且對應的包已不含它。 → 未打通。

**兼容性**

| 目標 | 實際測過 | 判定 |
|---|---|---|
| 桌機瀏覽器（Chromium） | 1280×900 滑鼠、800×450／640×360、390×844／320×568 觸控模擬（`README.md:198` [doc]）；對象是舊包 | 現行內容：未測 |
| Android Chrome／iOS Safari 實機 | 無（B04／B17 未做：`ROADMAP-COMMERCIAL.md:110, 122`） | 未測 |
| 原生 Android／iOS（Safe Area） | 程式有讀取（`README.md:47` [doc]），無實機 | 未測 |
| 匯出版 vs 編輯器差異 | LESSONS 記過多次差異；現行內容沒有匯出版可比 | 未測 |
| 螢幕比例、鍵盤／手把 | 比例有最大字級審計（`tools/text_fit_audit.gd`，舊紀錄）；鍵盤只處理 `ui_accept`／`ui_cancel`（`main.gd:2137-2166`），沒有焦點驗收 | 鍵盤：未測 |

**回歸測試**

- 修過的 bug 有對應測試：Game Over 卡（`test_showcase`）、離螢幕熱區（`test_search_cast`）、立繪動作與漫畫同幀（`test_portrait_reaction`）、震動時鐘（`test_game_feel`）等。 [doc][code]
- **README 沒有 L1／L2／L3 各跑哪些指令**（`README.md` 無相關字樣 [measured: grep]；專案目錄沒有 `AGENTS.md`）；完整測試入口只在 `project.yaml:23`。 → 缺。
- 沒有 CI：`.github/workflows/` 只有 `pixel-monster-ios.yml`，沒有 debt-commission（`ROADMAP-COMMERCIAL.md:111` B08）。 [measured: `ls`][doc]
- 教訓：測試曾因故事搬走而連環失敗（`LESSONS.md` 2026-11-08 條）；現在以 `tests/fixtures/` 隔離。 [doc]

**本次實跑（單元測試，每種一次）** [measured]

```bash
# 從 /mnt/d/repo/godot/godogen/prototypes 執行；Godot 4.7.stable.official.5b4e0cb0f
SCR=/tmp/claude-1000/-mnt-d-repo-godot-godogen/ca69b251-0df2-46de-9645-496dd8759a97/scratchpad
# 1. 複本：rsync 到 scratchpad 的 Linux 檔案系統（避開 /mnt/d 的 5 秒存檔逾時，也不寫工作樹）
rsync -a --exclude='build/' --exclude='art_src/' --exclude='test-results/' --exclude='.cache/' \
  --exclude='docs/*.png' --exclude='.claude/' debt-commission/ $SCR/dc/debt-commission/
rsync -a --exclude='vfx' godot-kit/ $SCR/dc/godot-kit/
# 2. project.yaml:23 的 commands.test（每個 tests/test_*.gd 一組，逐組執行）
TMPDIR=$SCR/logs XDG_DATA_HOME=$SCR/xdg-data XDG_CONFIG_HOME=$SCR/xdg-config TEST_TIMEOUT=300 \
  bash $SCR/dc/godot-kit/tools/run_tests.sh $SCR/dc/debt-commission
```

- 結果：**57 組 PASS、0 組 FAIL**；每組 log 都有 `PASSED`，且沒有 `SCRIPT ERROR`、`Parse Error`、`Failed to load script`、以 `FAIL` 開頭的行；全程約 5 分鐘（02:24:14–02:29:20）。沒有任何一組重跑。 [measured]
- import 步驟的 log 結尾有 `RID allocations ... leaked at exit` 警告：編輯器模式結束時的既有雜訊（`PROGRESS.md:35, 59`、`production/qa/smoke-2026-10-16.md` 都記過），不判為失敗。 [measured][doc]
- log 位置：`/tmp/claude-1000/-mnt-d-repo-godot-godogen/ca69b251-0df2-46de-9645-496dd8759a97/scratchpad/logs/godot-tests.EYUafB/`。
- 這 57/57 只證明邏輯與流程；不證明好玩，也不證明現行內容在 Web 或手機上可玩。

**這次沒跑的冒煙測試：** `node tools/browser_check.mjs --smoke --playwright /home/ronghao/.npm/_npx/705bc6b22212b352/node_modules/playwright`。理由：① `build/web` 是 2026-10-30 的舊包（`ls` 日期），早於 11-04 的拆分與 11-08 的清理，測的不是現行內容；② 預設樣本是已退出的 `debt`（`browser_check.mjs:36`）；③ `PROGRESS.md:24-25` 記載 HEAD 上就失敗。以 [doc] 引用上述紀錄，並列入「未量測」。

---

## 4. 建議（依「影響 × 成本」由高到低）

成本：S＝半天內；M＝數天；L＝一週以上。

**1. 在 README 寫下玩法假設、可判定的通過條件與結論日期（S，影響最大）**
- 改什麼：寫三件事。假設：「玩家能在 8 秒內看出哪個選項才是吐槽，並因為找對槽點而覺得好笑」。通過條件：不操作會輸、高手拿 S、5 位真人試玩至少 3 位願意再玩一章。結論：繼續／轉向／放棄與日期。順便寫明「作品」與「創作者工具」誰優先（`ROADMAP-COMMERCIAL.md:11`），並在驗證完成前把 `project.yaml:8` 的 `stage` 改回 Prototype。
- 改善：B6，並決定其他建議的順序。
- 驗證：README 有該段；`project.yaml` 的 stage 與結論一致。

**2. 把可玩的核心 loop 放回出貨清單（S–M）**
- 改什麼：把第一章（或 R1＋R2 的精簡版）複製進 `data/` 並登記到 `data/stories.json`（匯出排除 `tests/*`，所以不能只留在夾具）。讓「開始故事」預設進它，功能展示放進章節選擇。
- 改善：A3、B6（讓人玩得到）。
- 驗證：`data/stories.json` 有一筆 `kind: "chapter"`；`run_tests.sh` 仍 57/57；章節選擇不再顯示「還在製作中」；新玩家 ≤ 3 分鐘內遇到第一次「吐槽！」。

**3. 寫一支最小 bot，給「三種玩家」一個數字基準（S）**
- 改什麼：`tools/` 下用 StoryRunner＋TsukkomiRound（兩者不讀時鐘，`tsukkomi_round.gd:2-5`）寫 headless bot，不進出貨。三種策略：不操作、隨機不重複（含逾時與重複選錯的變體）、知道答案；各 N=1000 局。
- 改善：A1、A2，也提供提示觸發率的實測。
- 驗證指標：每回合冷場數、Game Over 數、評價分布。對照：不操作時 testimony 不前進，R3 combo 停手則逾時扣眼鏡直到 Game Over；隨機不重複的期望冷場 ≈ 5.9／章（第 2 節）；知道答案 S ≥ 99%。

**4. 真人試玩，照 `SHORT-STORY-ACCEPTANCE.md` 的表（M，影響最大但依賴 1、2）**
- 改什麼：5 人、至少 3 人用手機、不提示操作。記錄完成時間、每回合冷場次數（`chapter_result()` 已給 `fails`／`tries`／`game_overs`：`story_runner.gd:290-312`）、卡住處、笑點、想不想繼續。
- 改善：A1、A3、A5、B6。
- 驗證：表格填完；用第 1 項的門檻判定繼續／轉向／放棄。

**5. 讓 perfect 有價值、weak 不是免費安全牌（S）**
- 改什麼：選一個最小改動——評價納入 perfect 比例（例：S＝0 冷場且 perfect ≥ 60%），或 weak 不累積連擊（`tsukkomi_round.gd:250-255` 目前 weak 也 +1 combo）。
- 改善：A1、A5。
- 驗證：bot「全選 weak」評價 ≤ A、「知道答案」S；同步更新 `test_chapter1.gd:93`、`test_chapter_flow.gd` 的斷言。

**6. 補回饋空格（S）**
- 改什麼：(a) 調查點空白給「找不到」回饋，連續落空 3 次給提示小牌（`main_investigation.gd:291-293`）；(b) weak 給固定音效與小震動（`stage_effects.gd:21`）；(c) 冷場 toast 帶原因：逾時／選錯／這句沒有槽點（`main_round.gd:325`）；(d) 長按、上滑加入第一次教學（`data/tutorials.json`）。
- 改善：A4。
- 驗證：用 `last_feedback`（`stage_effects.gd:58`）與 QA 快照加測試；實機對聽（需實機）。

**7. 修文件過時（S）**
- 改什麼：第 7 節「過時清單」逐條；README 的測試段改成「完整：`bash ../godot-kit/tools/run_tests.sh .`」加 L1／L2 對照。
- 改善：B7、B8。
- 驗證：`grep -n` 清單中的字串不再出現；README 的測試清單數量對得上 `ls tests/test_*.gd | wc -l`。

**8. 讓選錯有思考成本（M，需作者決定）**
- 改什麼：把 c 選項從「附和」改成「看似合理但指錯對象」的吐槽；d「放棄吐槽」只留在需要隱藏路線的槽點。
- 改善：A1、A2。
- 驗證：真人試玩各槽的首次冷場率落在 15–35%（建議門檻，可調；由 `stats.fails/tries` 算）；bot 的期望冷場不變（選項數沒變）。

**9. 重匯 Web，並把冒煙測試指向現行內容（M）**
- 改什麼：`tools/browser_check.mjs:36` 的預設樣本改指 showcase；重跑 `bash tools/build_web.sh`；在複本上跑 `--smoke`。
- 改善：B8、B6 的技術風險 1。
- 驗證：`--smoke` 結束碼 0；`build/web/index.pck` 日期更新；記下 pck 大小與冷啟動秒數。

**10. 實機量 QTE 與手感（M，需裝置）**
- 改什麼：Android Chrome、iPhone Safari 各跑一次，記 `m._last_qte_offset`（`main_round.gd:236`）20 次的中位數與最大值，同時看震動、toast、漫畫格節奏。必要時在設定加「QTE 校正（ms）」旋鈕。
- 改善：A1、A4、B8。
- 驗證：|offset| 中位數 < 0.1 s；若 > 0.12 s，放寬判定窗或加校正。

**11. 桂短篇收尾（作者決定）**
- 改什麼：補完或標示「製作中」那兩個「（尚未寫完）」結局；決定時機吐槽（QTE）要不要回來，並同步 README／草稿。
- 改善：A3、B7。
- 驗證：`test_katsura_dog_ears.gd` 加一條斷言：三個結局都不含「尚未寫完」。

**12. 量效能預算（M，後期）**
- 改什麼：目標手機的幀時間、draw call、記憶體，加上 Web 冷啟動秒數（pck 72.8 MB），寫進 `project.yaml:21`。
- 改善：B6、B7。
- 驗證：預算數字存在且有一次實測值；再決定 `performance.enforce` 是否從 warn 升級。

---

## 5. 未量測

| 缺什麼 | 為什麼沒有 | 怎麼取得 |
|---|---|---|
| 三種玩家（不操作／普通／高手）的勝率、存活時間、冷場數 | 專案沒有 bot，README 沒有平衡指令（第 1 節的數字是用程式數值算的上下界，不是量測） | 建議 3（bot）、建議 4（真人） |
| 真人遊玩時間、笑點、卡關處、想不想繼續 | 驗收表全部待驗（`SHORT-STORY-ACCEPTANCE.md:22`） | 建議 4 |
| 第一章完整遊玩時長 | 只有字數（夾具 222 個 `say`；R1 前 30 句 518 字），沒有計時 | 計時試玩 |
| 回饋延遲（收到了 ≤ 100 ms、結果 ≤ 0.5 s）、音效同步、震動強度、漫畫格節奏 | headless 無法證明 | **需實機** A/B |
| QTE 在實機上的偏移分布 | 無實機；只有軟體渲染 Chromium 一筆 0.433 s（`ROADMAP-COMMERCIAL.md:109`） | 建議 10 |
| 現行內容的 Web 版行為與大小 | `build/web` 是舊包；本次未重匯、未跑 `browser_check.mjs --smoke`（理由見第 8 節） | 建議 9 |
| 冷啟動時間、幀時間、draw call、記憶體 | 沒有預算也沒有量測（`project.yaml:21`） | 建議 12 |
| Android Chrome／iOS Safari 實機（觸控大小、Safe Area、單手、切背景） | B04／B17 未做 | 實機 |
| 鍵盤／手把焦點操作 | 程式只處理滑鼠／觸控與 `ui_accept`／`ui_cancel`，沒有驗收 | 手動＋測試 |
| 「聽下去」取得素材時有沒有提示 | 讀過的程式只看到調查熱區有 toast | 玩一次，或看 QA 快照 |
| 神樂提示的實際觸發率 | 理論上選項槽湊不到 3 次（第 2 節）；實際取決於玩家行為 | bot（含逾時與重複選錯的策略）＋真人 |
| 素材授權 | 不屬於「好不好玩」；`docs/ASSET-MANIFEST.md` 多數為「未核准公開／販售」，私人原型路線暫不擋（`ROADMAP-COMMERCIAL.md:9`） | 改走公開發行時再做 |
