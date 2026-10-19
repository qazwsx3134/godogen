# debt-commission 商業級打磨 Roadmap

日期：2026-10-18。由 Claude（遊戲本體、UI、內容）與 Codex（編輯器、發行／品質）共同盤點。逐項證據見各 TODO 的「證據」欄。
量級：S ≈ 半天到一天，M ≈ 2–4 工程日，L ≈ 1–2 週以上。這是工程量的粗估，不含授權洽談、劇本產量與真人測試排期。
優先度：P0 不做就不能公開發行；P1 達到商業品質的必要項；P2 加分項。

## 已決定（使用者，2026-10-19）

1. **發行路線：私人原型。** 原聲帶與現有角色圖可以留在本機版本；不上傳 itch.io 或其他公開平台。標 P0 的發行關卡（B01 allowlist、B04 真機矩陣、素材授權）降為「改路線時才需要」，其餘照常做。
2. **劇本來源：** 既有章節以 `.dialogue` 為唯一來源，編輯器對它們只做檢視與診斷；新故事以編輯器的 JSON 為唯一來源，提供一次性的「轉成圖編輯來源」。不做 JSON → `.dialogue` 的反向轉換。
3. **美術方向與系統定位（2026-10-19）：** 先維持手繪蠟筆風，不重繪。長期目標是讓創作者用這套系統，自己提供故事與畫作，做出不同的作品；第一章是示範作品。新功能優先考慮「別人的故事與圖也能放進來」，不寫死萬事屋的角色或畫風。

## 待辦總覽（2026-10-19 更新）

細節與證據在下方各里程碑的表格；這裡只列還沒完成的，依「誰來做」分組。

```
等你決定 ──→ K2 故事包的優先順序 ──→ Claude／Codex 才動手
等你做（真人）  C2 試讀、C3 音效、B04/B17 真機
Claude 下一批   K1 → K3 → U1 → B14 → B11 → G6
Codex           A01…A14 編輯器、B01/B02/B03/B08/B13、K4/K5
```

**等你決定**
- K2 故事包、K4 投稿檢查、K5 授權欄位的優先順序（K2 會改故事與素材的載入方式；K4、K5 屬 Codex）。
- 舊的 repo 層級問題（不屬本專案、這輪沒動）：`.claude/` 約 200 個檔案在 `.gitignore` 裡卻仍被追蹤；`prototypes/survivor-series/art_src/` 有 274 張候選圖被它自己的 `.gitignore` 排除卻仍被追蹤。要不要移出版控。

**等你做（真人才能完成）**
- C2 第一章作者試讀與修訂；`BR` 開頭的分支結局台詞是 Claude 寫的，一併試讀（C1）。
- C3 正式音效與配樂（目前是合成佔位音加原聲帶）。
- B04／B17 Android Chrome、iOS Safari 實機：首次點擊、切到背景再回來是否有聲音（B05）、單手操作、遊玩時間、金色氣焰與光束的強度（TODO.md B 段）。

**Claude 下一批（建議順序）**
1. K1 創作者美術規格（S）。
2. K3 署名，與 G5 片尾名單一起（S/M）。
3. U1 銀魂和紙的調查列、回合 HUD、QTE、牌子、toast 樣式統一（S）。
4. B14 最大字級逐畫面截圖驗收（M）。
5. B11 存檔匯出／匯入（M）。
6. G6 拆分 `main.gd`（L，改到哪拆到哪）。
7. B20 `--ep00` 瀏覽器路線失敗、U2 拍 cinema 結算截圖確認（S）。
8. 之後：B06 PWA safe area（真機確認需要才做）、G4 流程圖、G7 多語系、C4 第二章流程（與你一起）。

**Codex**
- 讀 `372b314`、`1346379` 的實際 diff 後回 ACK；特別是 `project.godot` 開 ICU 資料讓 pck +4.8 MB（落在 B02），以及改過的 `tools/browser_check.mjs`、`check_ui_parity.mjs`、`check_gintama_reference.mjs`、`check_reading_chapter1.mjs`。
- 編輯器 A01–A14；發行／品質 B01、B02、B03、B08、B13、B16；創作者 K4、K5。

## 里程碑

```
M0 來源與發行界線 ─┬→ M1 作者不丟稿 → M2 能寫完一章 ─┐
                   │                                  ├→ M4 Web 發行候選
                   └→ M3 劇本系統補齊（分支／結局）───┘
M5 內容：第一章定稿 → 第二章起量產（與 M2／M3 並行）
```

| 里程碑 | 目標 | 驗收 |
| --- | --- | --- |
| M0 來源與發行界線 | 路線決定；每個故事有唯一來源；存檔相容政策；出貨素材 allowlist | 素材 manifest 列出每一件素材的授權狀態；`build_web.sh` 只打包 allowlist 裡的素材 |
| M1 作者不丟稿 | 編輯器有 undo/redo、草稿復原、存回檔案、一鍵驗證 | 編輯 → 存檔 → 關閉 → 重開 → 預覽，修改都還在；寫入衝突時拒絕寫入 |
| M2 能寫完一章 | 搜尋、複製子圖、素材縮圖、常用 op 表單、從任一節點試玩 | 用編輯器從零寫一段 30 節點、3 個結局的分支，不必手改 JSON |
| M3 劇本系統補齊 | 複合條件、數值、結局收集、跨章旗標、流程圖畫面 | 第一章的選擇能影響第二章；結局一覽會記下已看過的結局 |
| M4 Web 發行候選 | 第一章完整的 E2E、CI、大小與冷啟動預算、真機測試矩陣、無障礙 | CI 全綠；iOS Safari 和 Android Chrome 的真機清單逐項打勾 |
| M5 內容 | 第一章從草稿 v0.2 定稿；建立第二章起的量產流程 | 作者試讀完成；真人試玩量到遊玩時間 |

## TODO

狀態：☐ 未做｜◐ 進行中｜☑ 完成。負責：C = Claude，X = Codex，U = 使用者。

### M0 來源與發行界線
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| R1 | ☑ | 發行路線：私人原型 | 見上方「已決定」 | — | U |
| B01 | P0 | 建立素材 manifest（路徑、作者、來源、授權、允許用途、核准狀態），並建立公開版的 allowlist | `assets/audio/music/sources.json` 沒有授權欄位；`assets/image/` 沒有來源 manifest；`export_presets.cfg` 設成 all_resources | M | X |
| A01 | P0 | 每個故事只有一個可寫來源：registry 記錄 authoring mode；產物設為唯讀；提供「轉成圖編輯來源」 | `editor.js` 只顯示警告；`story_builder.gd` 重建時會覆蓋 | M | X |
| B10 | ☑ P1 | 存檔相容政策：只改文案的補丁不影響舊檔；結構改版時做映射，或清楚告知玩家並保留舊檔（2026-10-19：`version` 本來就只算結構；結構改版時舊自動檔改名 `<存檔>.<舊 version>` 保留、標題說明一次，手動欄位標「舊版劇本的存檔」） | `main.gd` `_archive_other_version_save`；`tests/test_save_slots.gd` `_test_older_story_structure` | M/L | C |

### M1 作者不丟稿（編輯器）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| A02 | P1 | undo/redo（以命令為單位記錄；連續的文字輸入合併成一步） | `editor.js` 沒有歷史紀錄 | M | X |
| A04 | P1 | 草稿自動存到 localStorage 並能復原；確認存檔真的成功才清掉 dirty；寫入失敗時持續提示 | `editor.js` 匯出後立刻設 `dirty=false` | M | X |
| A03 | P1 | 透過本機專案服務直接存回檔案：原子寫入、以基底 hash 偵測衝突 | 目前只能下載 | M | X |
| A05 | P1 | 一鍵「驗證並存檔」：呼叫 Godot 的 `check_story.gd`，不在 JS 重寫 fingerprint | 目前匯出的 version 是 `s-unset` | M | X |
| A13 | P1 | 錯誤處理：讀檔失敗、儲存空間滿、快速切換故事時的請求競態 | `editor.js` 的 `file.text()` 沒有 catch | M | X |

### M2 能寫完一章（編輯器）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| A06 | P1 | 全文搜尋（節點 ID、台詞、角色）並能跳轉 | 搜尋不到這個功能 | S | X |
| A07 | P1 | 多選、複製貼上子圖（內部連線重新對應，ID 不衝突） | 目前只能單選 | M | X |
| A09 | P1 | 從任一節點開始試玩（可預設旗標與道具，使用獨立存檔） | `preview.gd` 只能指定故事 | M | X＋C |
| A10 | P1 | 素材面板：背景、立繪、表情的縮圖；表情只列該角色有的 | 目前只有文字下拉 | M | X |
| A11 | P1 | 表單：condition、旗標、道具、bg、char、bgm、se、result，再來是 investigate 與 boke_round 的範本 | 這些 op 目前只能編原始 JSON | L | X |
| A12 | P1 | 200+ 節點的密集圖效能：先量測再改成局部更新 | 每改一個欄位就重建所有卡片 | M | X |
| A14 | P1 | 測試補上 200+ 節點、存檔失敗、多分頁等案例 | `test_core.mjs`、`smoke.mjs` | M | X |
| A08 | P2 | 群組、註解框、折疊（存在 layout sidecar，不改 runner schema） | — | M | X |

### M3 劇本系統補齊（遊戲本體）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| G1 | ☑ P1 | 複合條件：AND／OR、數值比較、持有道具；旗標可以加減 | `story_runner.gd` 的 `condition` 只支援「單一 flag == 值」；`flag` 只能直接設值 | M | C |
| G2 | ☑ P1 | 結局 id 與結局收集：`ending` 欄位、progress 記錄、章節選擇顯示「結局 x/y」，以及章節選擇裡的「結局收集」（看過的顯示結局名，沒看過「？？？」，2026-10-19） | `scenes/ui/chapter_select.tscn`、`ending_row.tscn`；`tests/test_chapter_flow.gd` | M | C |
| G3 | ☑ P1 | 跨章旗標（根層 `carry`）：章末把指定旗標寫進 progress，下一章開始時讀入 | `story_runner.gd` 每次載入都把 flags 重設成 `initial_flags`；progress 只記評價 | M | C |
| G4 | P2 | 流程圖畫面（底特律式）：已走過的節點與分支，未解鎖的顯示問號 | 搜尋不到 | L | C |
| G5 | P2 | 片尾製作名單、CG 鑑賞、音樂鑑賞 | 搜尋不到 | M | C |
| G6 | P1 | 拆分 `main.gd`（3856 行）：調查、回合、存檔、UI 掛載各自成為控制器 | `main.gd` | L | C |
| G7 | P2 | 多語系（`tr()`、把文字抽出來） | 搜尋不到 | L | — |

### M4 Web 發行候選（發行／品質）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| B07 | ☑ P0 | 第一章 Web 完整 E2E：QTE（perfect／early／late）→ 結算 → 評價 → 重新載入後評價與結局仍在（2026-10-19，最終版本 390×844／320×568 連續 3 次通過；其中一次 320 寬第一下偏差 0.433 秒判失敗、重試後命中，是軟體渲染 Chromium 的輸入延遲，路線允許最多 3 次）。Game Over 重試與下一章解鎖由引擎測試 `test_chapter_flow`／`test_chapter1` 涵蓋；目前只有一章，Web 無下一章可解鎖 | `tools/check_reading_chapter1.mjs` | M | C |
| B04 | P0 | 真機測試矩陣（iOS Safari、Android Chrome）：首次點擊、切到背景再回來、來電中斷、網址列伸縮、靜音 | 目前只有 Chromium 模擬 | M | U＋C |
| B08 | P1 | CI 單一品質入口：故事建置一致性、原生關鍵測試、編輯器測試、Web 必要流程 | 沒有 debt-commission 的 workflow | M | X |
| B02 | P1 | 大小與冷啟動預算：量 PCK、字型裁字、移除未使用素材，評估分章下載 | 舊建置約 83 MiB | M | X |
| B03 | P1 | 自訂繁中載入畫面，載入失敗可重試 | 目前用 Godot 預設 shell | M | X |
| B05 | ◐ P1 | 音訊解鎖與回到前景後恢復播放，並取得實際聽到聲音的證據（2026-10-19 查證：Godot 4.7 Web 每次觸控輸入都呼叫 `godot_audio_resume`，切回前景後第一下點擊就恢復，不另加程式；「實際聽到」需真機） | 匯出的 `index.js` `_godot_audio_resume` | S/M | C＋U |
| B06 | P1 | 全螢幕／PWA 與 Web 的 safe area（先在真機確認需要再做） | Web 的 safe area 一律是 0 | M | C |
| B11 | P1 | 玩家可以匯出、匯入存檔 | 只有瀏覽器儲存 | M | C |
| B12 | ☑ P1 | 設定寫入失敗時提示；寫入改成原子操作（2026-10-19：`atomic_file.gd`，失敗時提示「設定無法儲存，這次遊玩仍會套用」） | `scripts/settings.gd`；`tests/test_settings.gd` | S | C |
| B13 | P1 | 錯誤診斷包：版本、故事 hash、node/step、近期錯誤（不收集個資） | 搜尋不到 | M | X |
| B15 | ☑ P1 | 減少搖晃與閃光；QTE 時限延長或輔助模式（2026-10-19：設定「畫面效果」減少＝震動 ×0.2、閃光亮度 1/3；「吐槽輔助」寬鬆＝選詞時間 ×1.5、QTE 判定窗 ×2） | `scripts/settings.gd`、`stage_effects.gd`；`tests/test_settings.gd` | M | C |
| B14 | P1 | 最大字級時不截字、照片上的對比度，逐個場景驗收 | 已有字級設定與對比測試，但沒有逐像素驗收 | M | C |
| B16 | P2 | 色盲：不只靠顏色區分；鍵盤焦點 | `editor.js` 用紅綠線表示狀態 | M/L | X |
| B17 | P2 | 單手真人試玩 | 已有 48 CSS px 的檢查 | S | U |
| B20 | P1 | `browser_check.mjs --ep00` 失敗：「Gintoki alone is on stage」（2026-10-19 在 HEAD 版同樣失敗，不是這輪造成的；未查原因） | `tools/browser_check.mjs --ep00` | S | C |
| U1 | P1 | 銀魂和紙：調查列、回合 HUD、QTE、placard、toast 的樣式統一 | 這些仍由程式依款式上色 | S | C |
| U3 | ☑ P1 | 標題卡只留開始／繼續／讀檔／設定：A–D 風格鈕在四款標題 scene 設為隱藏，換風格改在設定的「介面風格」或目錄；版本字改為「v0.5」（2026-10-19） | `scenes/ui/title_screen_*.tscn`；`tests/test_ui_styles.gd` | S | C |
| B18 | ☑ P1 | 中文禁則：Web 版把「。」「，」排到行首（匯出沒帶 ICU 斷行資料）。`project.godot` 開 `internationalization/locale/include_text_server_data`，pck +4.8 MB（2026-10-19） | 結算台詞、選詞題目的 Web 截圖 | S | C |
| B19 | ☑ P1 | 320×568 回合畫面對話框比畫面寬 23 px（右緣被切）：回合操作列四顆 48 CSS px 按鈕加 17 px 間距放不進窄手機；銀魂款 `RoundBar` 間距改 10。順手修正 `browser_check.mjs` 預設路線沒帶 `?sample=debt`（第一章改為預設後一直失敗）；兩者在 HEAD 版也失敗，修後 `--rounds` 與預設路線通過。`browser_check.mjs` 的點擊會先捲動目錄／設定把列帶進畫面（目錄加了回滾與快速存讀後「回標題」落到捲動區下方，`--slots`、`--choices` 在 HEAD 版因此失敗，修後通過）。`--ep00` 的「Gintoki alone is on stage」在 HEAD 版同樣失敗，未處理（2026-10-19） | `scenes/ui/dialogue_box_gintama.tscn`、`tools/browser_check.mjs` | S | C |
| U2 | ◐ P2 | 其他三款的對話框名牌會浮在結算畫面上面（2026-10-19：預防性修正，`chapter_result.tscn`、`game_over.tscn` 根節點比照銀魂款設 `z_index = 2`；這輪沒重現原問題，也沒拍 cinema 結算截圖驗證） | cinema 結算截圖 | S | C |

### M5 內容
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| C1 | ◐ P1 | 第一章分支（使用者 2026-10-19 要求先加一個分支結局）：已做：薪水袋之後的選擇「自己去鞋櫃拿／叫阿銀拿過來」，兩個結局 `ch1_sadaharu`「這次真的是定春」、`ch1_gintoki`「試毒試到一滴不剩」，結算畫面標出結局名；`BR` 開頭的台詞是 Claude 寫的，待作者試讀。未做：更早、影響更大的分支 | `story_src/chapter1.dialogue` 的 `ch1_twist_gin`；`tests/test_chapter1.gd` 的 gin 路線 | M | U＋C |
| C2 | P1 | 第一章作者試讀與修訂（目前是草稿 v0.2）；補齊缺少的表情圖 | — | M | U |
| C3 | P1 | 正式音效與配樂（依 R1 的結果決定用授權素材或原創） | 目前是合成的 WAV 加上原聲帶 | M | U |
| C4 | P1 | 第二章起的故事大綱與量產流程 | `stories.json` 裡只有一個 chapter | L | U＋C |

### M6 創作者可用（依決定 3；提案，尚未排程）
| ID | 優先 | 項目 | 證據 | 量 | 負責 |
| --- | --- | --- | --- | --- | --- |
| K1 | P1 | 創作者美術規格：背景與立繪的尺寸、透明 PNG、表情命名、取景，附蠟筆風現有圖當範例 | `docs/AUTHORING.md` 只講劇本；圖的規格散在 `asset_catalog.json` 與角色 scene | S | C |
| K2 | P1 | 故事包：一個故事一個資料夾（劇本、自己的素材 catalog、作者資訊），放進去就出現在章節選擇，不改程式 | 目前所有故事共用 `data/asset_catalog.json`，新增故事要改 `data/stories.json` | M/L | C＋X |
| K3 | P1 | 署名：章節選擇與結算顯示作者／畫師，片尾名單（併入 G5） | 搜尋不到作者欄位 | S/M | C |
| K4 | P1 | 投稿檢查：一鍵檢查缺圖、缺表情、尺寸不符與劇本錯誤，產生創作者看得懂的報告 | `check_story.gd` 只查劇本 | M | X |
| K5 | P1 | 創作者素材的授權聲明欄位（與 B01 manifest 共用格式） | `assets/image/` 沒有來源 manifest | S | X＋U |

## 協作方式

- Claude 獨占遊戲本體：`scripts/`、`main.gd`、`scenes/`、`tests/`、`story_src/`、`data/`。Codex 獨占：`tools/story_editor/**`、`docs/STORY-EDITOR.md`、CI 與建置腳本、素材 manifest。
- A01 歸 Codex，可以動 `data/stories.json`（新增 authoring 欄位）與 `tools/story_build/story_builder.gd`、`build_story.gd`；`tools/story_build/dm_source.gd` 歸 Claude（G1 的 `.dialogue` 條件語法）。
- 會跨兩邊的 schema 變更（例如 G1 的條件語法、G2 的結局欄位），由 Claude 先在 `IMPLEMENTATION.md` 定好契約，Codex 再接進編輯器表單。
- 每一項完成時：實作方回報改動檔、測試與實跑結果；對方讀實際 diff 後回 ACK，或附 file:line 的意見。commit 等使用者指示。
